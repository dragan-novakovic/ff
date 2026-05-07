using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Npgsql;

internal sealed class AntiAbuseStore : IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly NpgsqlDataSource _dataSource;

    public AntiAbuseStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_GATEWAY_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Gateway")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS gateway;

            CREATE TABLE IF NOT EXISTS gateway.sensitive_action_audit (
                audit_id text PRIMARY KEY,
                player_id text NOT NULL,
                action_type text NOT NULL,
                route text NOT NULL,
                idempotency_key text NULL,
                request_fingerprint text NOT NULL,
                decision text NOT NULL,
                reason text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_gateway_sensitive_action_player_created
                ON gateway.sensitive_action_audit (player_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_gateway_sensitive_action_type_created
                ON gateway.sensitive_action_audit (action_type, created_at DESC);

            CREATE TABLE IF NOT EXISTS gateway.action_rate_counters (
                player_id text NOT NULL,
                action_type text NOT NULL,
                window_start timestamptz NOT NULL,
                window_seconds integer NOT NULL,
                request_count integer NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, action_type, window_start)
            );

            CREATE TABLE IF NOT EXISTS gateway.idempotency_audit (
                player_id text NOT NULL,
                action_type text NOT NULL,
                idempotency_key text NOT NULL,
                route text NOT NULL,
                request_fingerprint text NOT NULL,
                first_seen_at timestamptz NOT NULL,
                last_seen_at timestamptz NOT NULL,
                use_count integer NOT NULL,
                PRIMARY KEY (player_id, action_type, idempotency_key)
            );

            CREATE INDEX IF NOT EXISTS ix_gateway_idempotency_key
                ON gateway.idempotency_audit (idempotency_key, last_seen_at DESC);

            CREATE TABLE IF NOT EXISTS gateway.suspicious_action_events (
                event_id text PRIMARY KEY,
                player_id text NOT NULL,
                action_type text NOT NULL,
                severity text NOT NULL,
                rule_id text NOT NULL,
                reason text NOT NULL,
                subject_type text NOT NULL,
                subject_id text NOT NULL,
                route text NOT NULL,
                idempotency_key text NULL,
                request_fingerprint text NOT NULL,
                audit_id text NULL REFERENCES gateway.sensitive_action_audit(audit_id),
                metadata jsonb NOT NULL,
                status text NOT NULL DEFAULT 'open',
                created_at timestamptz NOT NULL,
                reviewed_by text NULL,
                reviewed_at timestamptz NULL,
                resolution text NOT NULL DEFAULT ''
            );

            CREATE INDEX IF NOT EXISTS ix_gateway_suspicious_status_created
                ON gateway.suspicious_action_events (status, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_gateway_suspicious_player_created
                ON gateway.suspicious_action_events (player_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<AntiAbuseDecision> EnforceAsync(AntiAbuseRule rule, AntiAbuseCheck check)
    {
        var playerId = Normalize(check.PlayerId);
        var actionType = Normalize(rule.ActionType);
        var idempotencyKey = NormalizeOptional(check.IdempotencyKey);
        var route = string.IsNullOrWhiteSpace(check.Route) ? "unknown" : check.Route.Trim();
        var subjectType = string.IsNullOrWhiteSpace(check.SubjectType) ? actionType : check.SubjectType.Trim().ToLowerInvariant();
        var subjectId = string.IsNullOrWhiteSpace(check.SubjectId) ? actionType : check.SubjectId.Trim().ToLowerInvariant();
        var now = DateTimeOffset.UtcNow;
        var fingerprint = Fingerprint(route, subjectType, subjectId, check.Metadata);
        var windowStart = FloorToWindow(now, rule.Window);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var decision = "allowed";
        var reason = "Allowed by anti-abuse rules.";
        var severity = "info";
        var statusCode = StatusCodes.Status200OK;
        var idempotentReplay = false;

        if (rule.RequiresIdempotency && idempotencyKey is null)
        {
            decision = "blocked";
            reason = "Idempotency-Key is required for this sensitive action.";
            severity = "high";
            statusCode = StatusCodes.Status400BadRequest;
        }
        else if (idempotencyKey is not null)
        {
            var collision = await ReadIdempotencyCollisionAsync(
                connection,
                transaction,
                playerId,
                actionType,
                idempotencyKey);
            if (collision is not null)
            {
                decision = "blocked";
                reason = "Idempotency key was already used for another player or action.";
                severity = "critical";
                statusCode = StatusCodes.Status409Conflict;
            }
            else
            {
                var existing = await ReadIdempotencyAsync(connection, transaction, playerId, actionType, idempotencyKey);
                if (existing is null)
                {
                    await InsertIdempotencyAsync(connection, transaction, playerId, actionType, idempotencyKey, route, fingerprint, now);
                }
                else
                {
                    await TouchIdempotencyAsync(connection, transaction, playerId, actionType, idempotencyKey, now);
                    if (!string.Equals(existing.RequestFingerprint, fingerprint, StringComparison.Ordinal))
                    {
                        decision = "blocked";
                        reason = "Idempotency key replay used a different request payload.";
                        severity = "critical";
                        statusCode = StatusCodes.Status409Conflict;
                    }
                    else
                    {
                        idempotentReplay = true;
                        decision = "duplicate_allowed";
                        reason = "Idempotency replay matched the original request.";
                    }
                }
            }
        }

        var count = await IncrementRateCounterAsync(
            connection,
            transaction,
            playerId,
            actionType,
            windowStart,
            rule.Window,
            now);

        if (decision is "allowed" && count > rule.MaxRequests)
        {
            decision = "blocked";
            reason = $"Rate limit exceeded for {rule.ActionType}: {count}/{rule.MaxRequests} in {rule.Window.TotalSeconds:N0}s.";
            severity = "high";
            statusCode = StatusCodes.Status429TooManyRequests;
        }
        else if (decision is "duplicate_allowed" && !idempotentReplay)
        {
            decision = "allowed";
            reason = "Allowed by anti-abuse rules.";
        }

        var auditId = $"gateway-audit-{Guid.NewGuid():N}";
        await InsertActionAuditAsync(
            connection,
            transaction,
            auditId,
            playerId,
            actionType,
            route,
            idempotencyKey,
            fingerprint,
            decision,
            reason,
            now);

        string? eventId = null;
        if (decision is "blocked")
        {
            eventId = $"suspicious-{Guid.NewGuid():N}";
            await InsertSuspiciousEventAsync(
                connection,
                transaction,
                eventId,
                playerId,
                actionType,
                severity,
                rule.RuleId,
                reason,
                subjectType,
                subjectId,
                route,
                idempotencyKey,
                fingerprint,
                auditId,
                BuildMetadataJson(rule, check.Metadata, count, fingerprint),
                now);
        }

        await transaction.CommitAsync();

        return decision is "blocked"
            ? AntiAbuseDecision.Blocked(Results.Json(
                new AntiAbuseBlockResponse(
                    Message: reason,
                    RuleId: rule.RuleId,
                    EventId: eventId!,
                    AuditId: auditId,
                    ActionType: rule.ActionType),
                statusCode: statusCode))
            : AntiAbuseDecision.Allowed(auditId);
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private static async Task<int> IncrementRateCounterAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        DateTimeOffset windowStart,
        TimeSpan window,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO gateway.action_rate_counters (
                player_id, action_type, window_start, window_seconds, request_count, updated_at
            )
            VALUES (
                @player_id, @action_type, @window_start, @window_seconds, 1, @updated_at
            )
            ON CONFLICT (player_id, action_type, window_start)
            DO UPDATE SET
                request_count = gateway.action_rate_counters.request_count + 1,
                updated_at = EXCLUDED.updated_at
            RETURNING request_count;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("window_start", windowStart);
        command.Parameters.AddWithValue("window_seconds", (int)window.TotalSeconds);
        command.Parameters.AddWithValue("updated_at", now);
        var value = await command.ExecuteScalarAsync();
        return Convert.ToInt32(value);
    }

    private static async Task<IdempotencyAudit?> ReadIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT request_fingerprint
            FROM gateway.idempotency_audit
            WHERE player_id = @player_id
                AND action_type = @action_type
                AND idempotency_key = @idempotency_key
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new IdempotencyAudit(reader.GetString(0))
            : null;
    }

    private static async Task<string?> ReadIdempotencyCollisionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id
            FROM gateway.idempotency_audit
            WHERE idempotency_key = @idempotency_key
                AND (player_id <> @player_id OR action_type <> @action_type)
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        var value = await command.ExecuteScalarAsync();
        return value as string;
    }

    private static async Task InsertIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        string idempotencyKey,
        string route,
        string fingerprint,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO gateway.idempotency_audit (
                player_id, action_type, idempotency_key, route, request_fingerprint,
                first_seen_at, last_seen_at, use_count
            )
            VALUES (
                @player_id, @action_type, @idempotency_key, @route, @request_fingerprint,
                @first_seen_at, @last_seen_at, 1
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("route", route);
        command.Parameters.AddWithValue("request_fingerprint", fingerprint);
        command.Parameters.AddWithValue("first_seen_at", now);
        command.Parameters.AddWithValue("last_seen_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task TouchIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        string idempotencyKey,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE gateway.idempotency_audit
            SET last_seen_at = @last_seen_at,
                use_count = use_count + 1
            WHERE player_id = @player_id
                AND action_type = @action_type
                AND idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("last_seen_at", now);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task InsertActionAuditAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string auditId,
        string playerId,
        string actionType,
        string route,
        string? idempotencyKey,
        string fingerprint,
        string decision,
        string reason,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO gateway.sensitive_action_audit (
                audit_id, player_id, action_type, route, idempotency_key,
                request_fingerprint, decision, reason, created_at
            )
            VALUES (
                @audit_id, @player_id, @action_type, @route, @idempotency_key,
                @request_fingerprint, @decision, @reason, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("audit_id", auditId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("route", route);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey is null ? DBNull.Value : idempotencyKey);
        command.Parameters.AddWithValue("request_fingerprint", fingerprint);
        command.Parameters.AddWithValue("decision", decision);
        command.Parameters.AddWithValue("reason", reason);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task InsertSuspiciousEventAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId,
        string playerId,
        string actionType,
        string severity,
        string ruleId,
        string reason,
        string subjectType,
        string subjectId,
        string route,
        string? idempotencyKey,
        string fingerprint,
        string auditId,
        string metadataJson,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO gateway.suspicious_action_events (
                event_id, player_id, action_type, severity, rule_id, reason,
                subject_type, subject_id, route, idempotency_key, request_fingerprint,
                audit_id, metadata, status, created_at, resolution
            )
            VALUES (
                @event_id, @player_id, @action_type, @severity, @rule_id, @reason,
                @subject_type, @subject_id, @route, @idempotency_key, @request_fingerprint,
                @audit_id, @metadata::jsonb, 'open', @created_at, ''
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("severity", severity);
        command.Parameters.AddWithValue("rule_id", ruleId);
        command.Parameters.AddWithValue("reason", reason);
        command.Parameters.AddWithValue("subject_type", subjectType);
        command.Parameters.AddWithValue("subject_id", subjectId);
        command.Parameters.AddWithValue("route", route);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey is null ? DBNull.Value : idempotencyKey);
        command.Parameters.AddWithValue("request_fingerprint", fingerprint);
        command.Parameters.AddWithValue("audit_id", auditId);
        command.Parameters.AddWithValue("metadata", metadataJson);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static string BuildMetadataJson(AntiAbuseRule rule, object? metadata, int windowCount, string fingerprint)
    {
        return JsonSerializer.Serialize(new
        {
            Rule = new
            {
                rule.RuleId,
                rule.ActionType,
                rule.Description,
                WindowSeconds = (int)rule.Window.TotalSeconds,
                rule.MaxRequests,
                rule.RequiresIdempotency
            },
            WindowCount = windowCount,
            RequestFingerprint = fingerprint,
            Metadata = metadata
        }, JsonOptions);
    }

    private static string Fingerprint(string route, string subjectType, string subjectId, object? metadata)
    {
        var serialized = JsonSerializer.Serialize(new
        {
            Route = route,
            SubjectType = subjectType,
            SubjectId = subjectId,
            Metadata = metadata
        }, JsonOptions);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(serialized))).ToLowerInvariant();
    }

    private static DateTimeOffset FloorToWindow(DateTimeOffset now, TimeSpan window)
    {
        var seconds = Math.Max(1, (long)window.TotalSeconds);
        var unixSeconds = now.ToUnixTimeSeconds();
        return DateTimeOffset.FromUnixTimeSeconds(unixSeconds - unixSeconds % seconds);
    }

    private static string Normalize(string value)
    {
        return value.Trim().ToLowerInvariant();
    }

    private static string? NormalizeOptional(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToLowerInvariant();
    }

    private sealed record IdempotencyAudit(string RequestFingerprint);
}

internal static class AntiAbuseRules
{
    public static readonly AntiAbuseRule Work = new(
        "rate.player_work.5m",
        "player_work",
        RequiresIdempotency: false,
        Window: TimeSpan.FromMinutes(5),
        MaxRequests: 6,
        Description: "A player may attempt work at most 6 times per 5 minutes.");

    public static readonly AntiAbuseRule Train = new(
        "rate.player_train.5m",
        "player_train",
        RequiresIdempotency: false,
        Window: TimeSpan.FromMinutes(5),
        MaxRequests: 10,
        Description: "A player may attempt training at most 10 times per 5 minutes.");

    public static readonly AntiAbuseRule HospitalRecover = new(
        "idempotency.hospital_recover",
        "hospital_recover",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(10),
        MaxRequests: 6,
        Description: "Hospital recovery requires an Idempotency-Key and allows 6 attempts per 10 minutes.");

    public static readonly AntiAbuseRule InventoryUse = new(
        "idempotency.inventory_item_use",
        "inventory_item_use",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(5),
        MaxRequests: 20,
        Description: "Inventory item use requires an Idempotency-Key and allows 20 attempts per 5 minutes.");

    public static readonly AntiAbuseRule WeaponEquip = new(
        "idempotency.weapon_equip",
        "weapon_equip",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(10),
        MaxRequests: 10,
        Description: "Weapon equip requires an Idempotency-Key and allows 10 attempts per 10 minutes.");

    public static readonly AntiAbuseRule WeaponRepair = new(
        "idempotency.weapon_repair",
        "weapon_repair",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(10),
        MaxRequests: 10,
        Description: "Weapon repair requires an Idempotency-Key and allows 10 attempts per 10 minutes.");

    public static readonly AntiAbuseRule MarketBuy = new(
        "idempotency.market_buy",
        "market_buy",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(5),
        MaxRequests: 30,
        Description: "Market purchases require an Idempotency-Key and allow 30 attempts per 5 minutes.");

    public static readonly AntiAbuseRule MarketSell = new(
        "idempotency.market_sell",
        "market_sell",
        RequiresIdempotency: true,
        Window: TimeSpan.FromHours(1),
        MaxRequests: 40,
        Description: "Market listing creation requires an Idempotency-Key and allows 40 listings per hour.");

    public static readonly AntiAbuseRule MarketCancel = new(
        "idempotency.market_cancel",
        "market_cancel",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(10),
        MaxRequests: 30,
        Description: "Market listing cancellation requires an Idempotency-Key and allows 30 attempts per 10 minutes.");

    public static readonly AntiAbuseRule TradeCreate = new(
        "idempotency.trade_create",
        "trade_create",
        RequiresIdempotency: true,
        Window: TimeSpan.FromHours(1),
        MaxRequests: 60,
        Description: "Trade offer creation requires an Idempotency-Key and allows 60 offers per hour.");

    public static readonly AntiAbuseRule TradeAccept = new(
        "idempotency.trade_accept",
        "trade_accept",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(10),
        MaxRequests: 30,
        Description: "Trade acceptance requires an Idempotency-Key and allows 30 attempts per 10 minutes.");

    public static readonly AntiAbuseRule TradeCancel = new(
        "idempotency.trade_cancel",
        "trade_cancel",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(10),
        MaxRequests: 30,
        Description: "Trade cancellation requires an Idempotency-Key and allows 30 attempts per 10 minutes.");

    public static readonly AntiAbuseRule CombatFight = new(
        "idempotency.combat_fight",
        "combat_fight",
        RequiresIdempotency: true,
        Window: TimeSpan.FromMinutes(5),
        MaxRequests: 20,
        Description: "Combat fights require an Idempotency-Key and allow 20 attempts per 5 minutes.");

    public static AntiAbuseRuleDto[] All { get; } =
    [
        ToDto(Work),
        ToDto(Train),
        ToDto(HospitalRecover),
        ToDto(InventoryUse),
        ToDto(WeaponEquip),
        ToDto(WeaponRepair),
        ToDto(MarketBuy),
        ToDto(MarketSell),
        ToDto(MarketCancel),
        ToDto(TradeCreate),
        ToDto(TradeAccept),
        ToDto(TradeCancel),
        ToDto(CombatFight)
    ];

    private static AntiAbuseRuleDto ToDto(AntiAbuseRule rule)
    {
        return new AntiAbuseRuleDto(
            rule.RuleId,
            rule.ActionType,
            rule.RequiresIdempotency,
            (int)rule.Window.TotalSeconds,
            rule.MaxRequests,
            rule.Description);
    }
}

internal sealed record AntiAbuseRule(
    string RuleId,
    string ActionType,
    bool RequiresIdempotency,
    TimeSpan Window,
    int MaxRequests,
    string Description);

internal sealed record AntiAbuseCheck(
    string PlayerId,
    string Route,
    string SubjectType,
    string SubjectId,
    string? IdempotencyKey,
    object? Metadata);

internal sealed record AntiAbuseDecision(IResult? Error, string? AuditId)
{
    public static AntiAbuseDecision Allowed(string auditId)
    {
        return new AntiAbuseDecision(null, auditId);
    }

    public static AntiAbuseDecision Blocked(IResult error)
    {
        return new AntiAbuseDecision(error, null);
    }
}

internal sealed record AntiAbuseBlockResponse(
    string Message,
    string RuleId,
    string EventId,
    string AuditId,
    string ActionType);

internal sealed record AntiAbuseRuleDto(
    string RuleId,
    string ActionType,
    bool RequiresIdempotency,
    int WindowSeconds,
    int MaxRequests,
    string Description);

internal sealed record AntiAbuseRulesResponse(AntiAbuseRuleDto[] Rules, DateTimeOffset UpdatedAt);

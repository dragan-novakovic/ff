using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Npgsql;

namespace Ff.Admin.Api;

internal sealed class AdminStore : IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly NpgsqlDataSource _dataSource;

    public AdminStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_ADMIN_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Admin")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS admin;

            CREATE TABLE IF NOT EXISTS admin.audit_records (
                audit_id text PRIMARY KEY,
                actor_admin_id text NOT NULL,
                action_type text NOT NULL,
                target_player_id text NULL,
                target_type text NOT NULL,
                target_id text NULL,
                details text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_admin_audit_created_at
                ON admin.audit_records (created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_admin_audit_target_player_created
                ON admin.audit_records (target_player_id, created_at DESC);

            CREATE TABLE IF NOT EXISTS admin.moderation_records (
                record_id text PRIMARY KEY,
                player_id text NOT NULL,
                record_type text NOT NULL,
                reason text NOT NULL,
                active boolean NOT NULL,
                expires_at timestamptz NULL,
                created_by text NOT NULL,
                created_at timestamptz NOT NULL,
                revoked_by text NULL,
                revoked_at timestamptz NULL,
                revocation_reason text NOT NULL DEFAULT ''
            );

            CREATE INDEX IF NOT EXISTS ix_admin_moderation_player_created
                ON admin.moderation_records (player_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_admin_moderation_player_active
                ON admin.moderation_records (player_id, active, expires_at);

            CREATE TABLE IF NOT EXISTS admin.content_moderation_items (
                item_id text PRIMARY KEY,
                source_type text NOT NULL,
                source_id text NOT NULL,
                player_id text NOT NULL,
                content text NOT NULL,
                reason text NOT NULL,
                status text NOT NULL,
                reported_by text NOT NULL,
                created_at timestamptz NOT NULL,
                reviewed_by text NULL,
                reviewed_at timestamptz NULL,
                resolution text NOT NULL DEFAULT '',
                review_action text NOT NULL DEFAULT 'none',
                last_reported_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            ALTER TABLE admin.content_moderation_items
                ADD COLUMN IF NOT EXISTS review_action text NOT NULL DEFAULT 'none',
                ADD COLUMN IF NOT EXISTS last_reported_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP;

            CREATE INDEX IF NOT EXISTS ix_admin_content_queue_status_created
                ON admin.content_moderation_items (status, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_admin_content_queue_player_created
                ON admin.content_moderation_items (player_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_admin_content_queue_source_status
                ON admin.content_moderation_items (source_type, source_id, status);

            CREATE TABLE IF NOT EXISTS admin.content_reports (
                report_id text PRIMARY KEY,
                item_id text NOT NULL REFERENCES admin.content_moderation_items (item_id) ON DELETE CASCADE,
                reporter_player_id text NOT NULL,
                reason text NOT NULL,
                details text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_admin_content_reports_item_created
                ON admin.content_reports (item_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_admin_content_reports_reporter_created
                ON admin.content_reports (reporter_player_id, created_at DESC);

            CREATE TABLE IF NOT EXISTS admin.content_moderation_actions (
                action_id text PRIMARY KEY,
                item_id text NOT NULL REFERENCES admin.content_moderation_items (item_id) ON DELETE CASCADE,
                actor_admin_id text NOT NULL,
                action_type text NOT NULL,
                status text NOT NULL,
                resolution text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_admin_content_actions_item_created
                ON admin.content_moderation_actions (item_id, created_at DESC);

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

    public async Task<PlayerSearchResponseDto> SearchPlayersAsync(string? query, int limit)
    {
        var trimmedQuery = query?.Trim();
        var hasQuery = !string.IsNullOrWhiteSpace(trimmedQuery);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT
                a.player_id,
                a.username,
                a.email,
                a.created_at,
                a.last_login_at,
                p.level,
                p.experience,
                p.strength,
                p.energy,
                p.max_energy,
                p.updated_at,
                w.gold,
                COALESCE(m.active_count, 0)::integer AS active_moderation_count
            FROM identity.accounts a
            LEFT JOIN player.progression p ON p.player_id = a.player_id
            LEFT JOIN economy.wallets w ON w.player_id = a.player_id
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS active_count
                FROM admin.moderation_records m
                WHERE m.player_id = a.player_id
                    AND m.record_type IN ('ban', 'suspension')
                    AND m.active = true
                    AND m.revoked_at IS NULL
                    AND (m.expires_at IS NULL OR m.expires_at > CURRENT_TIMESTAMP)
            ) m ON true
            WHERE @has_query = false
                OR a.player_id ILIKE @query
                OR a.username ILIKE @query
                OR a.email ILIKE @query
            ORDER BY a.created_at DESC, a.player_id ASC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("has_query", hasQuery);
        command.Parameters.AddWithValue("query", hasQuery ? $"%{trimmedQuery}%" : string.Empty);
        command.Parameters.AddWithValue("limit", limit);

        var players = new List<PlayerSearchEntryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            players.Add(new PlayerSearchEntryDto(
                PlayerId: reader.GetString(0),
                Username: reader.GetString(1),
                Email: reader.GetString(2),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(3),
                LastLoginAt: reader.IsDBNull(4) ? null : reader.GetFieldValue<DateTimeOffset>(4),
                Level: reader.IsDBNull(5) ? null : reader.GetInt32(5),
                Experience: reader.IsDBNull(6) ? null : reader.GetInt32(6),
                Strength: reader.IsDBNull(7) ? null : reader.GetInt32(7),
                Energy: reader.IsDBNull(8) ? null : reader.GetInt32(8),
                MaxEnergy: reader.IsDBNull(9) ? null : reader.GetInt32(9),
                PlayerUpdatedAt: reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10),
                WalletGold: reader.IsDBNull(11) ? null : reader.GetInt32(11),
                ActiveModerationCount: reader.GetInt32(12)));
        }

        return new PlayerSearchResponseDto(
            Query: trimmedQuery ?? string.Empty,
            Limit: limit,
            Players: players.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<PlayerSummaryDto?> GetPlayerSummaryAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT
                a.account_id,
                a.player_id,
                a.email,
                a.username,
                a.created_at,
                a.last_login_at,
                p.level,
                p.experience,
                p.strength,
                p.energy,
                p.max_energy,
                p.last_work_date,
                p.last_train_date,
                p.hospital_cooldown_until,
                p.created_at,
                p.updated_at,
                w.gold,
                w.storage_limit,
                w.created_at,
                w.updated_at
            FROM (SELECT @player_id::text AS player_id) requested
            LEFT JOIN identity.accounts a ON a.player_id = requested.player_id
            LEFT JOIN player.progression p ON p.player_id = requested.player_id
            LEFT JOIN economy.wallets w ON w.player_id = requested.player_id;
            """, connection);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        var hasIdentity = !reader.IsDBNull(0);
        var hasProgression = !reader.IsDBNull(6);
        var hasWallet = !reader.IsDBNull(16);
        if (!hasIdentity && !hasProgression && !hasWallet)
        {
            return null;
        }

        var identity = hasIdentity
            ? new PlayerIdentitySummaryDto(
                AccountId: reader.GetString(0),
                PlayerId: reader.GetString(1),
                Email: reader.GetString(2),
                Username: reader.GetString(3),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(4),
                LastLoginAt: reader.IsDBNull(5) ? null : reader.GetFieldValue<DateTimeOffset>(5))
            : null;

        var progression = hasProgression
            ? new PlayerProgressionSummaryDto(
                Level: reader.GetInt32(6),
                Experience: reader.GetInt32(7),
                Strength: reader.GetInt32(8),
                Energy: reader.GetInt32(9),
                MaxEnergy: reader.GetInt32(10),
                LastWorkDate: reader.IsDBNull(11) ? null : reader.GetFieldValue<DateOnly>(11),
                LastTrainDate: reader.IsDBNull(12) ? null : reader.GetFieldValue<DateOnly>(12),
                HospitalCooldownUntil: reader.IsDBNull(13) ? null : reader.GetFieldValue<DateTimeOffset>(13),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(14),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(15))
            : null;

        var wallet = hasWallet
            ? new PlayerWalletSummaryDto(
                Gold: reader.GetInt32(16),
                StorageLimit: reader.GetInt32(17),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(18),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(19))
            : null;

        await reader.CloseAsync();

        var activeModeration = await ReadModerationRecordsAsync(connection, normalizedPlayerId, activeOnly: true, type: null, limit: 20);
        var latestNotes = await ReadModerationRecordsAsync(connection, normalizedPlayerId, activeOnly: false, type: "note", limit: 10);
        var ledger = await ReadEconomyEntriesAsync(connection, normalizedPlayerId, entryType: null, limit: 10);

        return new PlayerSummaryDto(
            PlayerId: normalizedPlayerId,
            Identity: identity,
            Progression: progression,
            Wallet: wallet,
            ActiveModerationRecords: activeModeration.ToArray(),
            LatestNotes: latestNotes.ToArray(),
            LatestLedgerEntries: ledger.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<ModerationRecordListDto> GetModerationRecordsAsync(string playerId, bool activeOnly, int limit)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var records = await ReadModerationRecordsAsync(connection, normalizedPlayerId, activeOnly, type: null, limit);
        return new ModerationRecordListDto(
            PlayerId: normalizedPlayerId,
            Records: records.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<ModerationRecordDto> CreateModerationRecordAsync(
        string actor,
        string playerId,
        CreateModerationRecordRequest request)
    {
        var now = DateTimeOffset.UtcNow;
        var normalizedType = request.Type!.Trim().ToLowerInvariant();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var record = new ModerationRecordDto(
            RecordId: $"mod-{Guid.NewGuid():N}",
            PlayerId: normalizedPlayerId,
            Type: normalizedType,
            Reason: request.Reason!.Trim(),
            Active: normalizedType is "ban" or "suspension",
            ExpiresAt: request.ExpiresAt,
            CreatedBy: actor,
            CreatedAt: now,
            RevokedBy: null,
            RevokedAt: null,
            RevocationReason: string.Empty);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO admin.moderation_records (
                record_id, player_id, record_type, reason, active, expires_at,
                created_by, created_at, revoked_by, revoked_at, revocation_reason
            )
            VALUES (
                @record_id, @player_id, @record_type, @reason, @active, @expires_at,
                @created_by, @created_at, NULL, NULL, ''
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("record_id", record.RecordId);
        command.Parameters.AddWithValue("player_id", record.PlayerId);
        command.Parameters.AddWithValue("record_type", record.Type);
        command.Parameters.AddWithValue("reason", record.Reason);
        command.Parameters.AddWithValue("active", record.Active);
        command.Parameters.AddWithValue("expires_at", (object?)record.ExpiresAt ?? DBNull.Value);
        command.Parameters.AddWithValue("created_by", record.CreatedBy);
        command.Parameters.AddWithValue("created_at", record.CreatedAt);
        await command.ExecuteNonQueryAsync();

        await InsertAuditAsync(
            connection,
            transaction,
            actor,
            $"moderation.{record.Type}.create",
            record.PlayerId,
            "moderation_record",
            record.RecordId,
            new { record.Type, record.Reason, record.ExpiresAt, record.Active });
        await transaction.CommitAsync();
        return record;
    }

    public async Task<ModerationRecordDto?> RevokeModerationRecordAsync(string actor, string recordId, string reason)
    {
        var now = DateTimeOffset.UtcNow;
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using var command = new NpgsqlCommand("""
            UPDATE admin.moderation_records
            SET active = false,
                revoked_by = @revoked_by,
                revoked_at = @revoked_at,
                revocation_reason = @revocation_reason
            WHERE record_id = @record_id
            RETURNING record_id, player_id, record_type, reason, active, expires_at,
                      created_by, created_at, revoked_by, revoked_at, revocation_reason;
            """, connection, transaction);
        command.Parameters.AddWithValue("record_id", recordId.Trim());
        command.Parameters.AddWithValue("revoked_by", actor);
        command.Parameters.AddWithValue("revoked_at", now);
        command.Parameters.AddWithValue("revocation_reason", reason.Trim());

        ModerationRecordDto? record = null;
        await using (var reader = await command.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                record = ReadModerationRecord(reader);
            }
        }

        if (record is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        await InsertAuditAsync(
            connection,
            transaction,
            actor,
            "moderation.record.revoke",
            record.PlayerId,
            "moderation_record",
            record.RecordId,
            new { reason, record.Type, record.RevokedAt });
        await transaction.CommitAsync();
        return record;
    }

    public async Task<AuditRecordListDto> GetAuditRecordsAsync(string? playerId, int limit)
    {
        var normalizedPlayerId = NormalizeOptional(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT audit_id, actor_admin_id, action_type, target_player_id,
                   target_type, target_id, details, created_at
            FROM admin.audit_records
            WHERE @has_player_id = false OR target_player_id = @player_id
            ORDER BY created_at DESC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("has_player_id", normalizedPlayerId is not null);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);

        var records = new List<AuditRecordDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            records.Add(ReadAuditRecord(reader));
        }

        return new AuditRecordListDto(
            PlayerId: normalizedPlayerId,
            Records: records.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<EconomyLedgerAuditResponseDto> GetEconomyLedgerAsync(string? playerId, string? entryType, int limit)
    {
        var normalizedPlayerId = NormalizeOptional(playerId);
        var normalizedEntryType = NormalizeOptional(entryType);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var entries = await ReadEconomyEntriesAsync(connection, normalizedPlayerId, normalizedEntryType, limit);
        return new EconomyLedgerAuditResponseDto(
            PlayerId: normalizedPlayerId,
            EntryType: normalizedEntryType,
            Entries: entries.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<EconomyBalanceDashboardDto> GetEconomyDashboardAsync(int days, int limit)
    {
        var safeDays = Math.Clamp(days, 1, 365);
        var safeLimit = Math.Clamp(limit, 1, 50);
        var to = DateTimeOffset.UtcNow;
        var from = to.AddDays(-safeDays);

        await using var connection = await _dataSource.OpenConnectionAsync();
        var gold = await ReadGoldFlowSummaryAsync(connection, from, to, safeLimit);
        var items = await ReadItemSupplySummaryAsync(connection, safeLimit);
        var wages = await ReadWageSummaryAsync(connection, from, to, safeLimit);
        var prices = await ReadPriceHistorySummaryAsync(connection, from, to, safeLimit);
        var taxes = await ReadTaxSummaryAsync(connection, from, to, safeLimit);
        var factories = await ReadFactoryOutputSummaryAsync(connection, from, to, safeLimit);
        var battles = await ReadBattleRewardSummaryAsync(connection, from, to, safeLimit);

        return new EconomyBalanceDashboardDto(
            Days: safeDays,
            From: from,
            To: to,
            Gold: gold,
            Items: items,
            Wages: wages,
            Prices: prices,
            Taxes: taxes,
            Factories: factories,
            Battles: battles,
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<ContentModerationQueueResponseDto> GetContentModerationQueueAsync(string? status, int limit)
    {
        var normalizedStatus = NormalizeQueueStatus(status);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT i.item_id, i.source_type, i.source_id, i.player_id, i.content, i.reason,
                   i.status, i.reported_by, i.created_at, i.reviewed_by, i.reviewed_at,
                   i.resolution, i.review_action, i.last_reported_at,
                   COALESCE(r.report_count, 0)::integer AS report_count
            FROM admin.content_moderation_items i
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS report_count
                FROM admin.content_reports r
                WHERE r.item_id = i.item_id
            ) r ON true
            WHERE @has_status = false OR i.status = @status
            ORDER BY i.last_reported_at DESC, i.created_at DESC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("has_status", normalizedStatus is not null);
        command.Parameters.AddWithValue("status", normalizedStatus ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);

        var items = new List<ContentModerationItemDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            items.Add(ReadContentItem(reader));
        }

        return new ContentModerationQueueResponseDto(
            Status: normalizedStatus ?? "all",
            Items: items.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<ContentModerationItemDto?> GetContentModerationItemAsync(string itemId)
    {
        var normalizedItemId = NormalizeOptional(itemId);
        if (normalizedItemId is null)
        {
            return null;
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        return await ReadContentItemByIdAsync(connection, transaction: null, normalizedItemId);
    }

    public async Task<ContentModerationItemDto> CreateContentQueueItemAsync(
        string actor,
        CreateContentQueueItemRequest request)
    {
        var now = DateTimeOffset.UtcNow;
        var sourceType = request.SourceType!.Trim().ToLowerInvariant();
        var sourceId = request.SourceId!.Trim();
        var playerId = NormalizePlayerId(request.PlayerId);
        var content = request.Content!.Trim();
        var reason = request.Reason!.Trim();
        var reporterPlayerId = NormalizeOptional(request.ReporterPlayerId) ?? actor;
        var details = NormalizeOptional(request.Details) ?? string.Empty;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var itemId = await FindOpenContentItemIdAsync(connection, transaction, sourceType, sourceId);
        if (itemId is null)
        {
            itemId = $"content-{Guid.NewGuid():N}";
            await using var insertCommand = new NpgsqlCommand("""
                INSERT INTO admin.content_moderation_items (
                    item_id, source_type, source_id, player_id, content, reason,
                    status, reported_by, created_at, reviewed_by, reviewed_at,
                    resolution, review_action, last_reported_at
                )
                VALUES (
                    @item_id, @source_type, @source_id, @player_id, @content, @reason,
                    'open', @reported_by, @created_at, NULL, NULL, '', 'none', @last_reported_at
                );
                """, connection, transaction);
            insertCommand.Parameters.AddWithValue("item_id", itemId);
            insertCommand.Parameters.AddWithValue("source_type", sourceType);
            insertCommand.Parameters.AddWithValue("source_id", sourceId);
            insertCommand.Parameters.AddWithValue("player_id", playerId);
            insertCommand.Parameters.AddWithValue("content", content);
            insertCommand.Parameters.AddWithValue("reason", reason);
            insertCommand.Parameters.AddWithValue("reported_by", actor);
            insertCommand.Parameters.AddWithValue("created_at", now);
            insertCommand.Parameters.AddWithValue("last_reported_at", now);
            await insertCommand.ExecuteNonQueryAsync();
        }
        else
        {
            await using var updateCommand = new NpgsqlCommand("""
                UPDATE admin.content_moderation_items
                SET player_id = @player_id,
                    content = @content,
                    reason = @reason,
                    last_reported_at = @last_reported_at
                WHERE item_id = @item_id;
                """, connection, transaction);
            updateCommand.Parameters.AddWithValue("item_id", itemId);
            updateCommand.Parameters.AddWithValue("player_id", playerId);
            updateCommand.Parameters.AddWithValue("content", content);
            updateCommand.Parameters.AddWithValue("reason", reason);
            updateCommand.Parameters.AddWithValue("last_reported_at", now);
            await updateCommand.ExecuteNonQueryAsync();
        }

        await using var reportCommand = new NpgsqlCommand("""
            INSERT INTO admin.content_reports (
                report_id, item_id, reporter_player_id, reason, details, created_at
            )
            VALUES (
                @report_id, @item_id, @reporter_player_id, @reason, @details, @created_at
            );
            """, connection, transaction);
        reportCommand.Parameters.AddWithValue("report_id", $"report-{Guid.NewGuid():N}");
        reportCommand.Parameters.AddWithValue("item_id", itemId);
        reportCommand.Parameters.AddWithValue("reporter_player_id", reporterPlayerId);
        reportCommand.Parameters.AddWithValue("reason", reason);
        reportCommand.Parameters.AddWithValue("details", details);
        reportCommand.Parameters.AddWithValue("created_at", now);
        await reportCommand.ExecuteNonQueryAsync();

        await InsertAuditAsync(
            connection,
            transaction,
            actor,
            "content.report.create",
            playerId,
            "content_moderation_item",
            itemId,
            new { SourceType = sourceType, SourceId = sourceId, Reason = reason, ReporterPlayerId = reporterPlayerId });
        var item = await ReadContentItemByIdAsync(connection, transaction, itemId)
            ?? throw new InvalidOperationException("Content moderation item was not persisted.");
        await transaction.CommitAsync();
        return item;
    }

    public async Task<ContentModerationItemDto?> ReviewContentQueueItemAsync(
        string actor,
        string itemId,
        ReviewContentQueueItemRequest request)
    {
        var now = DateTimeOffset.UtcNow;
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using var command = new NpgsqlCommand("""
            UPDATE admin.content_moderation_items
            SET status = @status,
                reviewed_by = @reviewed_by,
                reviewed_at = @reviewed_at,
                resolution = @resolution,
                review_action = @review_action
            WHERE item_id = @item_id
            RETURNING item_id, source_type, source_id, player_id, content, reason,
                      status, reported_by, created_at, reviewed_by, reviewed_at,
                      resolution, review_action, last_reported_at,
                      0::integer AS report_count;
            """, connection, transaction);
        command.Parameters.AddWithValue("item_id", itemId.Trim());
        command.Parameters.AddWithValue("status", request.Status!.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("reviewed_by", actor);
        command.Parameters.AddWithValue("reviewed_at", now);
        command.Parameters.AddWithValue("resolution", request.Resolution!.Trim());
        command.Parameters.AddWithValue("review_action", request.Action!.Trim().ToLowerInvariant());

        ContentModerationItemDto? item = null;
        await using (var reader = await command.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                item = ReadContentItem(reader);
            }
        }

        if (item is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        await using var actionCommand = new NpgsqlCommand("""
            INSERT INTO admin.content_moderation_actions (
                action_id, item_id, actor_admin_id, action_type, status, resolution, created_at
            )
            VALUES (
                @action_id, @item_id, @actor_admin_id, @action_type, @status, @resolution, @created_at
            );
            """, connection, transaction);
        actionCommand.Parameters.AddWithValue("action_id", $"content-action-{Guid.NewGuid():N}");
        actionCommand.Parameters.AddWithValue("item_id", item.ItemId);
        actionCommand.Parameters.AddWithValue("actor_admin_id", actor);
        actionCommand.Parameters.AddWithValue("action_type", item.ReviewAction);
        actionCommand.Parameters.AddWithValue("status", item.Status);
        actionCommand.Parameters.AddWithValue("resolution", item.Resolution);
        actionCommand.Parameters.AddWithValue("created_at", now);
        await actionCommand.ExecuteNonQueryAsync();

        await InsertAuditAsync(
            connection,
            transaction,
            actor,
            $"content.queue.review.{item.ReviewAction}",
            item.PlayerId,
            "content_moderation_item",
            item.ItemId,
            new { item.Status, item.Resolution, item.ReviewAction, item.SourceType, item.SourceId });
        item = await ReadContentItemByIdAsync(connection, transaction, item.ItemId) ?? item;
        await transaction.CommitAsync();
        return item;
    }

    public Task<AntiAbuseRuleListDto> GetAntiAbuseRulesAsync()
    {
        return Task.FromResult(new AntiAbuseRuleListDto(AdminAntiAbuseRules.All, DateTimeOffset.UtcNow));
    }

    public async Task<AntiAbuseReviewQueueResponseDto> GetAntiAbuseReviewQueueAsync(
        string? status,
        string? playerId,
        int limit)
    {
        var normalizedStatus = NormalizeAntiAbuseStatus(status) ?? "open";
        var normalizedPlayerId = NormalizeOptional(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT
                e.event_id,
                e.player_id,
                COALESCE(a.username, '') AS username,
                e.action_type,
                e.severity,
                e.rule_id,
                e.reason,
                e.subject_type,
                e.subject_id,
                e.route,
                e.idempotency_key,
                COALESCE(sa.decision, '') AS decision,
                e.audit_id,
                e.metadata::text,
                COALESCE(ledger.recent_ledger_entries, 0)::integer AS recent_ledger_entries,
                COALESCE(fills.recent_market_fills, 0)::integer AS recent_market_fills,
                COALESCE(activity.recent_activity_events, 0)::integer AS recent_activity_events,
                e.status,
                e.created_at,
                e.reviewed_by,
                e.reviewed_at,
                e.resolution
            FROM gateway.suspicious_action_events e
            LEFT JOIN identity.accounts a ON a.player_id = e.player_id
            LEFT JOIN gateway.sensitive_action_audit sa ON sa.audit_id = e.audit_id
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS recent_ledger_entries
                FROM economy.ledger_entries l
                WHERE l.player_id = e.player_id
                    AND l.created_at BETWEEN e.created_at - INTERVAL '15 minutes'
                        AND e.created_at + INTERVAL '15 minutes'
            ) ledger ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS recent_market_fills
                FROM market.fills f
                WHERE f.buyer_id = e.player_id
                    AND f.created_at BETWEEN e.created_at - INTERVAL '15 minutes'
                        AND e.created_at + INTERVAL '15 minutes'
            ) fills ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS recent_activity_events
                FROM notification.player_activity_events n
                WHERE n.player_id = e.player_id
                    AND n.created_at BETWEEN e.created_at - INTERVAL '15 minutes'
                        AND e.created_at + INTERVAL '15 minutes'
            ) activity ON true
            WHERE (@status = 'all' OR e.status = @status)
                AND (@has_player_id = false OR e.player_id = @player_id)
            ORDER BY e.created_at DESC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("status", normalizedStatus);
        command.Parameters.AddWithValue("has_player_id", normalizedPlayerId is not null);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);

        var items = new List<AntiAbuseReviewItemDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            items.Add(ReadAntiAbuseReviewItem(reader));
        }

        return new AntiAbuseReviewQueueResponseDto(
            Status: normalizedStatus,
            PlayerId: normalizedPlayerId,
            Items: items.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<AntiAbuseReviewItemDto?> ReviewAntiAbuseEventAsync(
        string actor,
        string eventId,
        ReviewAntiAbuseEventRequest request)
    {
        var status = NormalizeAntiAbuseReviewStatus(request.Status);
        var resolution = request.Resolution?.Trim();
        if (status is null || string.IsNullOrWhiteSpace(resolution))
        {
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using var command = new NpgsqlCommand("""
            UPDATE gateway.suspicious_action_events
            SET status = @status,
                reviewed_by = @reviewed_by,
                reviewed_at = @reviewed_at,
                resolution = @resolution
            WHERE event_id = @event_id
            RETURNING event_id, player_id, action_type;
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId.Trim());
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("reviewed_by", actor);
        command.Parameters.AddWithValue("reviewed_at", now);
        command.Parameters.AddWithValue("resolution", resolution);

        string? playerId = null;
        string? actionType = null;
        await using (var reader = await command.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                playerId = reader.GetString(1);
                actionType = reader.GetString(2);
            }
        }

        if (playerId is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        await InsertAuditAsync(
            connection,
            transaction,
            actor,
            $"anti_abuse.review.{status}",
            playerId,
            "anti_abuse_event",
            eventId.Trim(),
            new { Status = status, Resolution = resolution, ActionType = actionType });
        await transaction.CommitAsync();

        await using var readConnection = await _dataSource.OpenConnectionAsync();
        return await ReadAntiAbuseEventByIdAsync(readConnection, eventId.Trim());
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private static async Task<AntiAbuseReviewItemDto?> ReadAntiAbuseEventByIdAsync(
        NpgsqlConnection connection,
        string eventId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT
                e.event_id,
                e.player_id,
                COALESCE(a.username, '') AS username,
                e.action_type,
                e.severity,
                e.rule_id,
                e.reason,
                e.subject_type,
                e.subject_id,
                e.route,
                e.idempotency_key,
                COALESCE(sa.decision, '') AS decision,
                e.audit_id,
                e.metadata::text,
                COALESCE(ledger.recent_ledger_entries, 0)::integer AS recent_ledger_entries,
                COALESCE(fills.recent_market_fills, 0)::integer AS recent_market_fills,
                COALESCE(activity.recent_activity_events, 0)::integer AS recent_activity_events,
                e.status,
                e.created_at,
                e.reviewed_by,
                e.reviewed_at,
                e.resolution
            FROM gateway.suspicious_action_events e
            LEFT JOIN identity.accounts a ON a.player_id = e.player_id
            LEFT JOIN gateway.sensitive_action_audit sa ON sa.audit_id = e.audit_id
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS recent_ledger_entries
                FROM economy.ledger_entries l
                WHERE l.player_id = e.player_id
                    AND l.created_at BETWEEN e.created_at - INTERVAL '15 minutes'
                        AND e.created_at + INTERVAL '15 minutes'
            ) ledger ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS recent_market_fills
                FROM market.fills f
                WHERE f.buyer_id = e.player_id
                    AND f.created_at BETWEEN e.created_at - INTERVAL '15 minutes'
                        AND e.created_at + INTERVAL '15 minutes'
            ) fills ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS recent_activity_events
                FROM notification.player_activity_events n
                WHERE n.player_id = e.player_id
                    AND n.created_at BETWEEN e.created_at - INTERVAL '15 minutes'
                        AND e.created_at + INTERVAL '15 minutes'
            ) activity ON true
            WHERE e.event_id = @event_id;
            """, connection);
        command.Parameters.AddWithValue("event_id", eventId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadAntiAbuseReviewItem(reader) : null;
    }

    private static AntiAbuseReviewItemDto ReadAntiAbuseReviewItem(NpgsqlDataReader reader)
    {
        return new AntiAbuseReviewItemDto(
            EventId: reader.GetString(0),
            PlayerId: reader.GetString(1),
            Username: reader.GetString(2),
            ActionType: reader.GetString(3),
            Severity: reader.GetString(4),
            RuleId: reader.GetString(5),
            Reason: reader.GetString(6),
            SubjectType: reader.GetString(7),
            SubjectId: reader.GetString(8),
            Route: reader.GetString(9),
            IdempotencyKey: reader.IsDBNull(10) ? null : reader.GetString(10),
            Decision: reader.GetString(11),
            AuditId: reader.IsDBNull(12) ? null : reader.GetString(12),
            Metadata: reader.GetString(13),
            RecentLedgerEntries: reader.GetInt32(14),
            RecentMarketFills: reader.GetInt32(15),
            RecentActivityEvents: reader.GetInt32(16),
            Status: reader.GetString(17),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(18),
            ReviewedBy: reader.IsDBNull(19) ? null : reader.GetString(19),
            ReviewedAt: reader.IsDBNull(20) ? null : reader.GetFieldValue<DateTimeOffset>(20),
            Resolution: reader.GetString(21));
    }

    private static async Task<List<ModerationRecordDto>> ReadModerationRecordsAsync(
        NpgsqlConnection connection,
        string playerId,
        bool activeOnly,
        string? type,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT record_id, player_id, record_type, reason, active, expires_at,
                   created_by, created_at, revoked_by, revoked_at, revocation_reason
            FROM admin.moderation_records
            WHERE player_id = @player_id
                AND (@has_type = false OR record_type = @record_type)
                AND (
                    @active_only = false OR (
                        active = true
                        AND revoked_at IS NULL
                        AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
                    )
                )
            ORDER BY created_at DESC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("active_only", activeOnly);
        command.Parameters.AddWithValue("has_type", type is not null);
        command.Parameters.AddWithValue("record_type", type ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);

        var records = new List<ModerationRecordDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            records.Add(ReadModerationRecord(reader));
        }

        return records;
    }

    private static async Task<List<EconomyLedgerEntryDto>> ReadEconomyEntriesAsync(
        NpgsqlConnection connection,
        string? playerId,
        string? entryType,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT
                l.ledger_id,
                l.player_id,
                COALESCE(a.username, '') AS username,
                l.entry_type,
                l.gold_delta,
                l.item_id,
                l.item_delta,
                l.description,
                l.created_at
            FROM economy.ledger_entries l
            LEFT JOIN identity.accounts a ON a.player_id = l.player_id
            WHERE (@has_player_id = false OR l.player_id = @player_id)
                AND (@has_entry_type = false OR l.entry_type = @entry_type)
            ORDER BY l.created_at DESC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("has_player_id", playerId is not null);
        command.Parameters.AddWithValue("player_id", playerId ?? string.Empty);
        command.Parameters.AddWithValue("has_entry_type", entryType is not null);
        command.Parameters.AddWithValue("entry_type", entryType ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);

        var entries = new List<EconomyLedgerEntryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(new EconomyLedgerEntryDto(
                LedgerId: reader.GetString(0),
                PlayerId: reader.GetString(1),
                Username: reader.GetString(2),
                EntryType: reader.GetString(3),
                GoldDelta: reader.GetInt32(4),
                ItemId: reader.GetString(5),
                ItemDelta: reader.GetInt32(6),
                Description: reader.GetString(7),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(8)));
        }

        return entries;
    }

    private static async Task<GoldFlowSummaryDto> ReadGoldFlowSummaryAsync(
        NpgsqlConnection connection,
        DateTimeOffset from,
        DateTimeOffset to,
        int limit)
    {
        await using var totalsCommand = new NpgsqlCommand("""
            WITH ledger_window AS (
                SELECT gold_delta
                FROM economy.ledger_entries
                WHERE created_at BETWEEN @from AND @to
            ),
            ledger_totals AS (
                SELECT
                    COUNT(*)::integer AS ledger_entry_count,
                    COALESCE(SUM(CASE WHEN gold_delta > 0 THEN gold_delta ELSE 0 END), 0)::bigint AS gold_created,
                    COALESCE(SUM(CASE WHEN gold_delta < 0 THEN -gold_delta ELSE 0 END), 0)::bigint AS gold_sunk,
                    COALESCE(SUM(gold_delta), 0)::bigint AS net_gold_delta
                FROM ledger_window
            ),
            wallet_totals AS (
                SELECT
                    COALESCE(SUM(gold), 0)::bigint AS total_wallet_gold,
                    COUNT(*)::integer AS wallet_count
                FROM economy.wallets
            )
            SELECT
                wallet_totals.total_wallet_gold,
                wallet_totals.wallet_count,
                ledger_totals.ledger_entry_count,
                ledger_totals.gold_created,
                ledger_totals.gold_sunk,
                ledger_totals.net_gold_delta
            FROM wallet_totals
            CROSS JOIN ledger_totals;
            """, connection);
        totalsCommand.Parameters.AddWithValue("from", from);
        totalsCommand.Parameters.AddWithValue("to", to);

        long totalWalletGold = 0;
        int walletCount = 0;
        int ledgerEntryCount = 0;
        long goldCreated = 0;
        long goldSunk = 0;
        long netGoldDelta = 0;
        await using (var reader = await totalsCommand.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                totalWalletGold = reader.GetInt64(0);
                walletCount = reader.GetInt32(1);
                ledgerEntryCount = reader.GetInt32(2);
                goldCreated = reader.GetInt64(3);
                goldSunk = reader.GetInt64(4);
                netGoldDelta = reader.GetInt64(5);
            }
        }

        var entryTypes = new List<GoldEntryTypeFlowDto>();
        await using var entryCommand = new NpgsqlCommand("""
            SELECT
                entry_type,
                COUNT(*)::integer AS entry_count,
                COALESCE(SUM(CASE WHEN gold_delta > 0 THEN gold_delta ELSE 0 END), 0)::bigint AS gold_created,
                COALESCE(SUM(CASE WHEN gold_delta < 0 THEN -gold_delta ELSE 0 END), 0)::bigint AS gold_sunk,
                COALESCE(SUM(gold_delta), 0)::bigint AS net_gold_delta
            FROM economy.ledger_entries
            WHERE created_at BETWEEN @from AND @to
            GROUP BY entry_type
            ORDER BY ABS(COALESCE(SUM(gold_delta), 0)) DESC, entry_count DESC, entry_type
            LIMIT @limit;
            """, connection);
        entryCommand.Parameters.AddWithValue("from", from);
        entryCommand.Parameters.AddWithValue("to", to);
        entryCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await entryCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                entryTypes.Add(new GoldEntryTypeFlowDto(
                    EntryType: reader.GetString(0),
                    EntryCount: reader.GetInt32(1),
                    GoldCreated: reader.GetInt64(2),
                    GoldSunk: reader.GetInt64(3),
                    NetGoldDelta: reader.GetInt64(4)));
            }
        }

        return new GoldFlowSummaryDto(
            TotalWalletGold: totalWalletGold,
            WalletCount: walletCount,
            LedgerEntryCount: ledgerEntryCount,
            GoldCreated: goldCreated,
            GoldSunk: goldSunk,
            NetGoldDelta: netGoldDelta,
            EntryTypes: entryTypes.ToArray());
    }

    private static async Task<ItemSupplySummaryDto> ReadItemSupplySummaryAsync(
        NpgsqlConnection connection,
        int limit)
    {
        await using var totalsCommand = new NpgsqlCommand("""
            WITH combined AS (
                SELECT item_id, quantity::bigint AS quantity, 'player' AS source
                FROM economy.inventory_items
                WHERE quantity > 0
                UNION ALL
                SELECT item_id, quantity::bigint AS quantity, 'company' AS source
                FROM production.company_inventory
                WHERE quantity > 0
            )
            SELECT
                COUNT(DISTINCT item_id)::integer AS item_kinds,
                COALESCE(SUM(quantity), 0)::bigint AS total_quantity,
                COALESCE(SUM(CASE WHEN source = 'player' THEN quantity ELSE 0 END), 0)::bigint AS player_quantity,
                COALESCE(SUM(CASE WHEN source = 'company' THEN quantity ELSE 0 END), 0)::bigint AS company_quantity
            FROM combined;
            """, connection);

        int itemKinds = 0;
        long totalQuantity = 0;
        long playerQuantity = 0;
        long companyQuantity = 0;
        await using (var reader = await totalsCommand.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                itemKinds = reader.GetInt32(0);
                totalQuantity = reader.GetInt64(1);
                playerQuantity = reader.GetInt64(2);
                companyQuantity = reader.GetInt64(3);
            }
        }

        var topItems = new List<ItemSupplyEntryDto>();
        await using var itemsCommand = new NpgsqlCommand("""
            WITH combined AS (
                SELECT item_id, name, category, quantity::bigint AS quantity, player_id AS holder_id, 'player' AS source
                FROM economy.inventory_items
                WHERE quantity > 0
                UNION ALL
                SELECT item_id, name, category, quantity::bigint AS quantity, company_id AS holder_id, 'company' AS source
                FROM production.company_inventory
                WHERE quantity > 0
            )
            SELECT
                item_id,
                MAX(name) AS name,
                MAX(category) AS category,
                COALESCE(SUM(quantity), 0)::bigint AS total_quantity,
                COALESCE(SUM(CASE WHEN source = 'player' THEN quantity ELSE 0 END), 0)::bigint AS player_quantity,
                COALESCE(SUM(CASE WHEN source = 'company' THEN quantity ELSE 0 END), 0)::bigint AS company_quantity,
                COUNT(DISTINCT source || ':' || holder_id)::integer AS holder_count
            FROM combined
            GROUP BY item_id
            ORDER BY total_quantity DESC, item_id
            LIMIT @limit;
            """, connection);
        itemsCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await itemsCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                topItems.Add(new ItemSupplyEntryDto(
                    ItemId: reader.GetString(0),
                    Name: reader.GetString(1),
                    Category: reader.GetString(2),
                    TotalQuantity: reader.GetInt64(3),
                    PlayerQuantity: reader.GetInt64(4),
                    CompanyQuantity: reader.GetInt64(5),
                    HolderCount: reader.GetInt32(6)));
            }
        }

        return new ItemSupplySummaryDto(
            ItemKinds: itemKinds,
            TotalQuantity: totalQuantity,
            PlayerQuantity: playerQuantity,
            CompanyQuantity: companyQuantity,
            TopItems: topItems.ToArray());
    }

    private static async Task<WageSummaryDto> ReadWageSummaryAsync(
        NpgsqlConnection connection,
        DateTimeOffset from,
        DateTimeOffset to,
        int limit)
    {
        await using var totalsCommand = new NpgsqlCommand("""
            SELECT
                COUNT(*)::integer AS work_record_count,
                COUNT(*) FILTER (WHERE status = 'paid')::integer AS paid_work_record_count,
                COUNT(*) FILTER (WHERE status = 'pending_credit')::integer AS pending_credit_work_record_count,
                COALESCE(SUM(gross_wage_gold), 0)::bigint AS gross_wages,
                COALESCE(SUM(net_wage_gold), 0)::bigint AS net_wages,
                COALESCE(SUM(tax_gold), 0)::bigint AS tax_gold,
                COALESCE(ROUND(AVG(gross_wage_gold)), 0)::integer AS average_gross_wage
            FROM production.company_work_records
            WHERE worked_at BETWEEN @from AND @to
              AND status <> 'cancelled';
            """, connection);
        totalsCommand.Parameters.AddWithValue("from", from);
        totalsCommand.Parameters.AddWithValue("to", to);

        int workRecordCount = 0;
        int paidWorkRecordCount = 0;
        int pendingCreditWorkRecordCount = 0;
        long grossWages = 0;
        long netWages = 0;
        long taxGold = 0;
        int averageGrossWage = 0;
        await using (var reader = await totalsCommand.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                workRecordCount = reader.GetInt32(0);
                paidWorkRecordCount = reader.GetInt32(1);
                pendingCreditWorkRecordCount = reader.GetInt32(2);
                grossWages = reader.GetInt64(3);
                netWages = reader.GetInt64(4);
                taxGold = reader.GetInt64(5);
                averageGrossWage = reader.GetInt32(6);
            }
        }

        var topCompanies = new List<WageCompanySummaryDto>();
        await using var companiesCommand = new NpgsqlCommand("""
            SELECT
                records.company_id,
                COALESCE(companies.name, records.company_id) AS company_name,
                COUNT(*)::integer AS work_record_count,
                COALESCE(SUM(records.gross_wage_gold), 0)::bigint AS gross_wages,
                COALESCE(SUM(records.net_wage_gold), 0)::bigint AS net_wages,
                COALESCE(SUM(records.tax_gold), 0)::bigint AS tax_gold
            FROM production.company_work_records records
            LEFT JOIN production.companies companies ON companies.company_id = records.company_id
            WHERE records.worked_at BETWEEN @from AND @to
              AND records.status <> 'cancelled'
            GROUP BY records.company_id, companies.name
            ORDER BY gross_wages DESC, work_record_count DESC, records.company_id
            LIMIT @limit;
            """, connection);
        companiesCommand.Parameters.AddWithValue("from", from);
        companiesCommand.Parameters.AddWithValue("to", to);
        companiesCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await companiesCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                topCompanies.Add(new WageCompanySummaryDto(
                    CompanyId: reader.GetString(0),
                    CompanyName: reader.GetString(1),
                    WorkRecordCount: reader.GetInt32(2),
                    GrossWages: reader.GetInt64(3),
                    NetWages: reader.GetInt64(4),
                    TaxGold: reader.GetInt64(5)));
            }
        }

        return new WageSummaryDto(
            WorkRecordCount: workRecordCount,
            PaidWorkRecordCount: paidWorkRecordCount,
            PendingCreditWorkRecordCount: pendingCreditWorkRecordCount,
            GrossWages: grossWages,
            NetWages: netWages,
            TaxGold: taxGold,
            AverageGrossWage: averageGrossWage,
            TopCompanies: topCompanies.ToArray());
    }

    private static async Task<MarketPriceHistorySummaryDto> ReadPriceHistorySummaryAsync(
        NpgsqlConnection connection,
        DateTimeOffset from,
        DateTimeOffset to,
        int limit)
    {
        await using var totalsCommand = new NpgsqlCommand("""
            SELECT
                COUNT(*)::integer AS trade_count,
                COALESCE(SUM(quantity), 0)::bigint AS quantity_traded,
                COALESCE(SUM(quantity::bigint * price_per_unit), 0)::bigint AS gold_volume,
                COALESCE(ROUND(SUM(quantity::bigint * price_per_unit)::numeric / NULLIF(SUM(quantity), 0)), 0)::integer AS average_price,
                COALESCE(MIN(price_per_unit), 0)::integer AS min_price,
                COALESCE(MAX(price_per_unit), 0)::integer AS max_price
            FROM market.price_history
            WHERE traded_at BETWEEN @from AND @to;
            """, connection);
        totalsCommand.Parameters.AddWithValue("from", from);
        totalsCommand.Parameters.AddWithValue("to", to);

        int tradeCount = 0;
        long quantityTraded = 0;
        long goldVolume = 0;
        int averagePrice = 0;
        int minPrice = 0;
        int maxPrice = 0;
        await using (var reader = await totalsCommand.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                tradeCount = reader.GetInt32(0);
                quantityTraded = reader.GetInt64(1);
                goldVolume = reader.GetInt64(2);
                averagePrice = reader.GetInt32(3);
                minPrice = reader.GetInt32(4);
                maxPrice = reader.GetInt32(5);
            }
        }

        var topItems = new List<MarketPriceItemSummaryDto>();
        await using var itemsCommand = new NpgsqlCommand("""
            SELECT
                item_id,
                MAX(item_name) AS item_name,
                MAX(category) AS category,
                COUNT(*)::integer AS trade_count,
                COALESCE(SUM(quantity), 0)::bigint AS quantity_traded,
                COALESCE(SUM(quantity::bigint * price_per_unit), 0)::bigint AS gold_volume,
                COALESCE(ROUND(SUM(quantity::bigint * price_per_unit)::numeric / NULLIF(SUM(quantity), 0)), 0)::integer AS average_price,
                COALESCE(MIN(price_per_unit), 0)::integer AS min_price,
                COALESCE(MAX(price_per_unit), 0)::integer AS max_price,
                MAX(traded_at) AS last_traded_at
            FROM market.price_history
            WHERE traded_at BETWEEN @from AND @to
            GROUP BY item_id
            ORDER BY quantity_traded DESC, gold_volume DESC, item_id
            LIMIT @limit;
            """, connection);
        itemsCommand.Parameters.AddWithValue("from", from);
        itemsCommand.Parameters.AddWithValue("to", to);
        itemsCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await itemsCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                topItems.Add(new MarketPriceItemSummaryDto(
                    ItemId: reader.GetString(0),
                    ItemName: reader.GetString(1),
                    Category: reader.GetString(2),
                    TradeCount: reader.GetInt32(3),
                    QuantityTraded: reader.GetInt64(4),
                    GoldVolume: reader.GetInt64(5),
                    AveragePrice: reader.GetInt32(6),
                    MinPrice: reader.GetInt32(7),
                    MaxPrice: reader.GetInt32(8),
                    LastTradedAt: reader.IsDBNull(9) ? null : reader.GetFieldValue<DateTimeOffset>(9)));
            }
        }

        return new MarketPriceHistorySummaryDto(
            TradeCount: tradeCount,
            QuantityTraded: quantityTraded,
            GoldVolume: goldVolume,
            AveragePrice: averagePrice,
            MinPrice: minPrice,
            MaxPrice: maxPrice,
            TopItems: topItems.ToArray());
    }

    private static async Task<TaxSummaryDto> ReadTaxSummaryAsync(
        NpgsqlConnection connection,
        DateTimeOffset from,
        DateTimeOffset to,
        int limit)
    {
        await using var totalsCommand = new NpgsqlCommand("""
            SELECT
                COUNT(*)::integer AS entry_count,
                COALESCE(SUM(gold_delta), 0)::bigint AS tax_collected,
                COALESCE(SUM(gross_amount), 0)::bigint AS taxed_gross_amount,
                COALESCE(ROUND(AVG(tax_rate)), 0)::integer AS average_tax_rate
            FROM world.country_treasury_ledger
            WHERE created_at BETWEEN @from AND @to;
            """, connection);
        totalsCommand.Parameters.AddWithValue("from", from);
        totalsCommand.Parameters.AddWithValue("to", to);

        int entryCount = 0;
        long taxCollected = 0;
        long taxedGrossAmount = 0;
        int averageTaxRate = 0;
        await using (var reader = await totalsCommand.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                entryCount = reader.GetInt32(0);
                taxCollected = reader.GetInt64(1);
                taxedGrossAmount = reader.GetInt64(2);
                averageTaxRate = reader.GetInt32(3);
            }
        }

        var entryTypes = new List<TaxEntryTypeSummaryDto>();
        await using var typesCommand = new NpgsqlCommand("""
            SELECT
                entry_type,
                COUNT(*)::integer AS entry_count,
                COALESCE(SUM(gold_delta), 0)::bigint AS tax_collected,
                COALESCE(SUM(gross_amount), 0)::bigint AS taxed_gross_amount,
                COALESCE(ROUND(AVG(tax_rate)), 0)::integer AS average_tax_rate
            FROM world.country_treasury_ledger
            WHERE created_at BETWEEN @from AND @to
            GROUP BY entry_type
            ORDER BY tax_collected DESC, entry_count DESC, entry_type
            LIMIT @limit;
            """, connection);
        typesCommand.Parameters.AddWithValue("from", from);
        typesCommand.Parameters.AddWithValue("to", to);
        typesCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await typesCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                entryTypes.Add(new TaxEntryTypeSummaryDto(
                    EntryType: reader.GetString(0),
                    EntryCount: reader.GetInt32(1),
                    TaxCollected: reader.GetInt64(2),
                    TaxedGrossAmount: reader.GetInt64(3),
                    AverageTaxRate: reader.GetInt32(4)));
            }
        }

        var countries = new List<CountryTaxSummaryDto>();
        await using var countriesCommand = new NpgsqlCommand("""
            SELECT
                ledger.country_id,
                COALESCE(countries.name, ledger.country_id) AS country_name,
                COALESCE(SUM(ledger.gold_delta), 0)::bigint AS tax_collected,
                COALESCE(SUM(ledger.gross_amount), 0)::bigint AS taxed_gross_amount,
                COALESCE(countries.treasury, 0)::bigint AS treasury,
                COALESCE(policies.income_tax_rate, countries.tax_rate, 0)::integer AS income_tax_rate,
                COALESCE(policies.market_tax_rate, GREATEST(0, countries.tax_rate / 2), 0)::integer AS market_tax_rate,
                COALESCE(policies.production_tax_rate, GREATEST(0, countries.tax_rate / 3), 0)::integer AS production_tax_rate
            FROM world.country_treasury_ledger ledger
            LEFT JOIN world.countries countries ON countries.country_id = ledger.country_id
            LEFT JOIN world.country_tax_policies policies ON policies.country_id = ledger.country_id
            WHERE ledger.created_at BETWEEN @from AND @to
            GROUP BY ledger.country_id, countries.name, countries.treasury,
                     policies.income_tax_rate, policies.market_tax_rate,
                     policies.production_tax_rate, countries.tax_rate
            ORDER BY tax_collected DESC, ledger.country_id
            LIMIT @limit;
            """, connection);
        countriesCommand.Parameters.AddWithValue("from", from);
        countriesCommand.Parameters.AddWithValue("to", to);
        countriesCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await countriesCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                countries.Add(new CountryTaxSummaryDto(
                    CountryId: reader.GetString(0),
                    CountryName: reader.GetString(1),
                    TaxCollected: reader.GetInt64(2),
                    TaxedGrossAmount: reader.GetInt64(3),
                    Treasury: reader.GetInt64(4),
                    IncomeTaxRate: reader.GetInt32(5),
                    MarketTaxRate: reader.GetInt32(6),
                    ProductionTaxRate: reader.GetInt32(7)));
            }
        }

        return new TaxSummaryDto(
            EntryCount: entryCount,
            TaxCollected: taxCollected,
            TaxedGrossAmount: taxedGrossAmount,
            AverageTaxRate: averageTaxRate,
            EntryTypes: entryTypes.ToArray(),
            Countries: countries.ToArray());
    }

    private static async Task<FactoryOutputSummaryDto> ReadFactoryOutputSummaryAsync(
        NpgsqlConnection connection,
        DateTimeOffset from,
        DateTimeOffset to,
        int limit)
    {
        await using var totalsCommand = new NpgsqlCommand("""
            WITH runs AS (
                SELECT 'player' AS owner_type, output_quantity, created_at
                FROM production.production_runs
                WHERE created_at BETWEEN @from AND @to
                UNION ALL
                SELECT 'company' AS owner_type, output_quantity, created_at
                FROM production.company_production_runs
                WHERE created_at BETWEEN @from AND @to
            )
            SELECT
                COUNT(*)::integer AS run_count,
                COUNT(*) FILTER (WHERE owner_type = 'player')::integer AS player_run_count,
                COUNT(*) FILTER (WHERE owner_type = 'company')::integer AS company_run_count,
                COALESCE(SUM(output_quantity), 0)::bigint AS output_quantity
            FROM runs;
            """, connection);
        totalsCommand.Parameters.AddWithValue("from", from);
        totalsCommand.Parameters.AddWithValue("to", to);

        int runCount = 0;
        int playerRunCount = 0;
        int companyRunCount = 0;
        long outputQuantity = 0;
        await using (var reader = await totalsCommand.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                runCount = reader.GetInt32(0);
                playerRunCount = reader.GetInt32(1);
                companyRunCount = reader.GetInt32(2);
                outputQuantity = reader.GetInt64(3);
            }
        }

        var topItems = new List<FactoryOutputItemSummaryDto>();
        await using var itemsCommand = new NpgsqlCommand("""
            WITH runs AS (
                SELECT output_item_id, output_quantity, created_at
                FROM production.production_runs
                WHERE created_at BETWEEN @from AND @to
                UNION ALL
                SELECT output_item_id, output_quantity, created_at
                FROM production.company_production_runs
                WHERE created_at BETWEEN @from AND @to
            )
            SELECT
                output_item_id,
                COUNT(*)::integer AS run_count,
                COALESCE(SUM(output_quantity), 0)::bigint AS output_quantity,
                MAX(created_at) AS last_produced_at
            FROM runs
            GROUP BY output_item_id
            ORDER BY output_quantity DESC, run_count DESC, output_item_id
            LIMIT @limit;
            """, connection);
        itemsCommand.Parameters.AddWithValue("from", from);
        itemsCommand.Parameters.AddWithValue("to", to);
        itemsCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await itemsCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                topItems.Add(new FactoryOutputItemSummaryDto(
                    ItemId: reader.GetString(0),
                    RunCount: reader.GetInt32(1),
                    OutputQuantity: reader.GetInt64(2),
                    LastProducedAt: reader.IsDBNull(3) ? null : reader.GetFieldValue<DateTimeOffset>(3)));
            }
        }

        return new FactoryOutputSummaryDto(
            RunCount: runCount,
            PlayerRunCount: playerRunCount,
            CompanyRunCount: companyRunCount,
            OutputQuantity: outputQuantity,
            TopItems: topItems.ToArray());
    }

    private static async Task<BattleRewardSummaryDto> ReadBattleRewardSummaryAsync(
        NpgsqlConnection connection,
        DateTimeOffset from,
        DateTimeOffset to,
        int limit)
    {
        await using var totalsCommand = new NpgsqlCommand("""
            SELECT
                COUNT(*)::integer AS contribution_count,
                COUNT(DISTINCT battle_id)::integer AS battle_count,
                COUNT(*) FILTER (WHERE won = true)::integer AS won_contribution_count,
                COALESCE(SUM(gold_reward), 0)::bigint AS gold_rewards,
                COALESCE(SUM(experience_reward), 0)::bigint AS experience_rewards,
                COALESCE(SUM(damage), 0)::bigint AS damage,
                COALESCE(SUM(energy_spent), 0)::bigint AS energy_spent
            FROM world.battle_contributions
            WHERE created_at BETWEEN @from AND @to;
            """, connection);
        totalsCommand.Parameters.AddWithValue("from", from);
        totalsCommand.Parameters.AddWithValue("to", to);

        int contributionCount = 0;
        int battleCount = 0;
        int wonContributionCount = 0;
        long goldRewards = 0;
        long experienceRewards = 0;
        long damage = 0;
        long energySpent = 0;
        await using (var reader = await totalsCommand.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                contributionCount = reader.GetInt32(0);
                battleCount = reader.GetInt32(1);
                wonContributionCount = reader.GetInt32(2);
                goldRewards = reader.GetInt64(3);
                experienceRewards = reader.GetInt64(4);
                damage = reader.GetInt64(5);
                energySpent = reader.GetInt64(6);
            }
        }

        var topBattles = new List<BattleRewardByBattleDto>();
        await using var battlesCommand = new NpgsqlCommand("""
            SELECT
                contributions.battle_id,
                COALESCE(battles.name, contributions.battle_id) AS battle_name,
                COUNT(*)::integer AS contribution_count,
                COALESCE(SUM(contributions.gold_reward), 0)::bigint AS gold_rewards,
                COALESCE(SUM(contributions.experience_reward), 0)::bigint AS experience_rewards,
                COALESCE(SUM(contributions.damage), 0)::bigint AS damage,
                MAX(contributions.created_at) AS last_contribution_at
            FROM world.battle_contributions contributions
            LEFT JOIN world.battles battles ON battles.battle_id = contributions.battle_id
            WHERE contributions.created_at BETWEEN @from AND @to
            GROUP BY contributions.battle_id, battles.name
            ORDER BY gold_rewards DESC, damage DESC, contributions.battle_id
            LIMIT @limit;
            """, connection);
        battlesCommand.Parameters.AddWithValue("from", from);
        battlesCommand.Parameters.AddWithValue("to", to);
        battlesCommand.Parameters.AddWithValue("limit", limit);
        await using (var reader = await battlesCommand.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                topBattles.Add(new BattleRewardByBattleDto(
                    BattleId: reader.GetString(0),
                    BattleName: reader.GetString(1),
                    ContributionCount: reader.GetInt32(2),
                    GoldRewards: reader.GetInt64(3),
                    ExperienceRewards: reader.GetInt64(4),
                    Damage: reader.GetInt64(5),
                    LastContributionAt: reader.IsDBNull(6) ? null : reader.GetFieldValue<DateTimeOffset>(6)));
            }
        }

        return new BattleRewardSummaryDto(
            ContributionCount: contributionCount,
            BattleCount: battleCount,
            WonContributionCount: wonContributionCount,
            GoldRewards: goldRewards,
            ExperienceRewards: experienceRewards,
            Damage: damage,
            EnergySpent: energySpent,
            TopBattles: topBattles.ToArray());
    }

    private static async Task InsertAuditAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actor,
        string actionType,
        string? targetPlayerId,
        string targetType,
        string? targetId,
        object details)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO admin.audit_records (
                audit_id, actor_admin_id, action_type, target_player_id,
                target_type, target_id, details, created_at
            )
            VALUES (
                @audit_id, @actor_admin_id, @action_type, @target_player_id,
                @target_type, @target_id, @details, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("audit_id", $"audit-{Guid.NewGuid():N}");
        command.Parameters.AddWithValue("actor_admin_id", actor);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("target_player_id", (object?)targetPlayerId ?? DBNull.Value);
        command.Parameters.AddWithValue("target_type", targetType);
        command.Parameters.AddWithValue("target_id", (object?)targetId ?? DBNull.Value);
        command.Parameters.AddWithValue("details", JsonSerializer.Serialize(details, JsonOptions));
        command.Parameters.AddWithValue("created_at", DateTimeOffset.UtcNow);
        await command.ExecuteNonQueryAsync();
    }

    private static ModerationRecordDto ReadModerationRecord(NpgsqlDataReader reader)
    {
        return new ModerationRecordDto(
            RecordId: reader.GetString(0),
            PlayerId: reader.GetString(1),
            Type: reader.GetString(2),
            Reason: reader.GetString(3),
            Active: reader.GetBoolean(4),
            ExpiresAt: reader.IsDBNull(5) ? null : reader.GetFieldValue<DateTimeOffset>(5),
            CreatedBy: reader.GetString(6),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(7),
            RevokedBy: reader.IsDBNull(8) ? null : reader.GetString(8),
            RevokedAt: reader.IsDBNull(9) ? null : reader.GetFieldValue<DateTimeOffset>(9),
            RevocationReason: reader.GetString(10));
    }

    private static AuditRecordDto ReadAuditRecord(NpgsqlDataReader reader)
    {
        return new AuditRecordDto(
            AuditId: reader.GetString(0),
            ActorAdminId: reader.GetString(1),
            ActionType: reader.GetString(2),
            TargetPlayerId: reader.IsDBNull(3) ? null : reader.GetString(3),
            TargetType: reader.GetString(4),
            TargetId: reader.IsDBNull(5) ? null : reader.GetString(5),
            Details: reader.GetString(6),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(7));
    }

    private static async Task<string?> FindOpenContentItemIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string sourceType,
        string sourceId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT item_id
            FROM admin.content_moderation_items
            WHERE source_type = @source_type
                AND source_id = @source_id
                AND status = 'open'
            ORDER BY created_at DESC
            LIMIT 1
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("source_type", sourceType);
        command.Parameters.AddWithValue("source_id", sourceId);

        var result = await command.ExecuteScalarAsync();
        return result as string;
    }

    private static async Task<ContentModerationItemDto?> ReadContentItemByIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string itemId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT i.item_id, i.source_type, i.source_id, i.player_id, i.content, i.reason,
                   i.status, i.reported_by, i.created_at, i.reviewed_by, i.reviewed_at,
                   i.resolution, i.review_action, i.last_reported_at,
                   COALESCE(r.report_count, 0)::integer AS report_count
            FROM admin.content_moderation_items i
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::integer AS report_count
                FROM admin.content_reports r
                WHERE r.item_id = i.item_id
            ) r ON true
            WHERE i.item_id = @item_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("item_id", itemId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadContentItem(reader) : null;
    }

    private static ContentModerationItemDto ReadContentItem(NpgsqlDataReader reader)
    {
        return new ContentModerationItemDto(
            ItemId: reader.GetString(0),
            SourceType: reader.GetString(1),
            SourceId: reader.GetString(2),
            PlayerId: reader.GetString(3),
            Content: reader.GetString(4),
            Reason: reader.GetString(5),
            Status: reader.GetString(6),
            ReportedBy: reader.GetString(7),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(8),
            ReviewedBy: reader.IsDBNull(9) ? null : reader.GetString(9),
            ReviewedAt: reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10),
            Resolution: reader.GetString(11),
            ReviewAction: reader.GetString(12),
            LastReportedAt: reader.GetFieldValue<DateTimeOffset>(13),
            ReportCount: reader.GetInt32(14));
    }

    private static string NormalizePlayerId(string? playerId)
    {
        return string.IsNullOrWhiteSpace(playerId)
            ? throw new ArgumentException("Player id is required.", nameof(playerId))
            : playerId.Trim();
    }

    private static string? NormalizeOptional(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static string? NormalizeQueueStatus(string? status)
    {
        var normalized = NormalizeOptional(status)?.ToLowerInvariant();
        return normalized is null or "all" ? null : normalized;
    }

    private static string? NormalizeAntiAbuseStatus(string? status)
    {
        var normalized = NormalizeOptional(status)?.ToLowerInvariant();
        return normalized switch
        {
            null => null,
            "all" or "open" or "reviewed" or "confirmed" or "dismissed" => normalized,
            _ => null
        };
    }

    private static string? NormalizeAntiAbuseReviewStatus(string? status)
    {
        return NormalizeOptional(status)?.ToLowerInvariant() switch
        {
            "reviewed" or "confirmed" or "dismissed" => NormalizeOptional(status)!.ToLowerInvariant(),
            _ => null
        };
    }
}

internal sealed class AdminTokenValidator
{
    private readonly string? _adminToken;

    public AdminTokenValidator(IConfiguration configuration)
    {
        _adminToken = configuration["FF_ADMIN_TOKEN"]
            ?? configuration["Admin:Token"];
    }

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_adminToken);

    public bool IsValid(string suppliedToken)
    {
        if (string.IsNullOrWhiteSpace(_adminToken) || string.IsNullOrWhiteSpace(suppliedToken))
        {
            return false;
        }

        var expectedBytes = Encoding.UTF8.GetBytes(_adminToken.Trim());
        var suppliedBytes = Encoding.UTF8.GetBytes(suppliedToken.Trim());
        return expectedBytes.Length == suppliedBytes.Length &&
            CryptographicOperations.FixedTimeEquals(expectedBytes, suppliedBytes);
    }
}

internal sealed record PlayerSearchResponseDto(
    string Query,
    int Limit,
    PlayerSearchEntryDto[] Players,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerSearchEntryDto(
    string PlayerId,
    string Username,
    string Email,
    DateTimeOffset CreatedAt,
    DateTimeOffset? LastLoginAt,
    int? Level,
    int? Experience,
    int? Strength,
    int? Energy,
    int? MaxEnergy,
    DateTimeOffset? PlayerUpdatedAt,
    int? WalletGold,
    int ActiveModerationCount);

internal sealed record PlayerSummaryDto(
    string PlayerId,
    PlayerIdentitySummaryDto? Identity,
    PlayerProgressionSummaryDto? Progression,
    PlayerWalletSummaryDto? Wallet,
    ModerationRecordDto[] ActiveModerationRecords,
    ModerationRecordDto[] LatestNotes,
    EconomyLedgerEntryDto[] LatestLedgerEntries,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerIdentitySummaryDto(
    string AccountId,
    string PlayerId,
    string Email,
    string Username,
    DateTimeOffset CreatedAt,
    DateTimeOffset? LastLoginAt);

internal sealed record PlayerProgressionSummaryDto(
    int Level,
    int Experience,
    int Strength,
    int Energy,
    int MaxEnergy,
    DateOnly? LastWorkDate,
    DateOnly? LastTrainDate,
    DateTimeOffset? HospitalCooldownUntil,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerWalletSummaryDto(
    int Gold,
    int StorageLimit,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record ModerationRecordListDto(
    string PlayerId,
    ModerationRecordDto[] Records,
    DateTimeOffset UpdatedAt);

internal sealed record ModerationRecordDto(
    string RecordId,
    string PlayerId,
    string Type,
    string Reason,
    bool Active,
    DateTimeOffset? ExpiresAt,
    string CreatedBy,
    DateTimeOffset CreatedAt,
    string? RevokedBy,
    DateTimeOffset? RevokedAt,
    string RevocationReason);

internal sealed record AuditRecordListDto(
    string? PlayerId,
    AuditRecordDto[] Records,
    DateTimeOffset UpdatedAt);

internal sealed record AuditRecordDto(
    string AuditId,
    string ActorAdminId,
    string ActionType,
    string? TargetPlayerId,
    string TargetType,
    string? TargetId,
    string Details,
    DateTimeOffset CreatedAt);

internal sealed record EconomyLedgerAuditResponseDto(
    string? PlayerId,
    string? EntryType,
    EconomyLedgerEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record EconomyLedgerEntryDto(
    string LedgerId,
    string PlayerId,
    string Username,
    string EntryType,
    int GoldDelta,
    string ItemId,
    int ItemDelta,
    string Description,
    DateTimeOffset CreatedAt);

internal sealed record EconomyBalanceDashboardDto(
    int Days,
    DateTimeOffset From,
    DateTimeOffset To,
    GoldFlowSummaryDto Gold,
    ItemSupplySummaryDto Items,
    WageSummaryDto Wages,
    MarketPriceHistorySummaryDto Prices,
    TaxSummaryDto Taxes,
    FactoryOutputSummaryDto Factories,
    BattleRewardSummaryDto Battles,
    DateTimeOffset UpdatedAt);

internal sealed record GoldFlowSummaryDto(
    long TotalWalletGold,
    int WalletCount,
    int LedgerEntryCount,
    long GoldCreated,
    long GoldSunk,
    long NetGoldDelta,
    GoldEntryTypeFlowDto[] EntryTypes);

internal sealed record GoldEntryTypeFlowDto(
    string EntryType,
    int EntryCount,
    long GoldCreated,
    long GoldSunk,
    long NetGoldDelta);

internal sealed record ItemSupplySummaryDto(
    int ItemKinds,
    long TotalQuantity,
    long PlayerQuantity,
    long CompanyQuantity,
    ItemSupplyEntryDto[] TopItems);

internal sealed record ItemSupplyEntryDto(
    string ItemId,
    string Name,
    string Category,
    long TotalQuantity,
    long PlayerQuantity,
    long CompanyQuantity,
    int HolderCount);

internal sealed record WageSummaryDto(
    int WorkRecordCount,
    int PaidWorkRecordCount,
    int PendingCreditWorkRecordCount,
    long GrossWages,
    long NetWages,
    long TaxGold,
    int AverageGrossWage,
    WageCompanySummaryDto[] TopCompanies);

internal sealed record WageCompanySummaryDto(
    string CompanyId,
    string CompanyName,
    int WorkRecordCount,
    long GrossWages,
    long NetWages,
    long TaxGold);

internal sealed record MarketPriceHistorySummaryDto(
    int TradeCount,
    long QuantityTraded,
    long GoldVolume,
    int AveragePrice,
    int MinPrice,
    int MaxPrice,
    MarketPriceItemSummaryDto[] TopItems);

internal sealed record MarketPriceItemSummaryDto(
    string ItemId,
    string ItemName,
    string Category,
    int TradeCount,
    long QuantityTraded,
    long GoldVolume,
    int AveragePrice,
    int MinPrice,
    int MaxPrice,
    DateTimeOffset? LastTradedAt);

internal sealed record TaxSummaryDto(
    int EntryCount,
    long TaxCollected,
    long TaxedGrossAmount,
    int AverageTaxRate,
    TaxEntryTypeSummaryDto[] EntryTypes,
    CountryTaxSummaryDto[] Countries);

internal sealed record TaxEntryTypeSummaryDto(
    string EntryType,
    int EntryCount,
    long TaxCollected,
    long TaxedGrossAmount,
    int AverageTaxRate);

internal sealed record CountryTaxSummaryDto(
    string CountryId,
    string CountryName,
    long TaxCollected,
    long TaxedGrossAmount,
    long Treasury,
    int IncomeTaxRate,
    int MarketTaxRate,
    int ProductionTaxRate);

internal sealed record FactoryOutputSummaryDto(
    int RunCount,
    int PlayerRunCount,
    int CompanyRunCount,
    long OutputQuantity,
    FactoryOutputItemSummaryDto[] TopItems);

internal sealed record FactoryOutputItemSummaryDto(
    string ItemId,
    int RunCount,
    long OutputQuantity,
    DateTimeOffset? LastProducedAt);

internal sealed record BattleRewardSummaryDto(
    int ContributionCount,
    int BattleCount,
    int WonContributionCount,
    long GoldRewards,
    long ExperienceRewards,
    long Damage,
    long EnergySpent,
    BattleRewardByBattleDto[] TopBattles);

internal sealed record BattleRewardByBattleDto(
    string BattleId,
    string BattleName,
    int ContributionCount,
    long GoldRewards,
    long ExperienceRewards,
    long Damage,
    DateTimeOffset? LastContributionAt);

internal sealed record ContentModerationQueueResponseDto(
    string Status,
    ContentModerationItemDto[] Items,
    DateTimeOffset UpdatedAt);

internal sealed record ContentModerationItemDto(
    string ItemId,
    string SourceType,
    string SourceId,
    string PlayerId,
    string Content,
    string Reason,
    string Status,
    string ReportedBy,
    DateTimeOffset CreatedAt,
    string? ReviewedBy,
    DateTimeOffset? ReviewedAt,
    string Resolution,
    string ReviewAction,
    DateTimeOffset LastReportedAt,
    int ReportCount);

internal sealed record CreateModerationRecordRequest(
    string? Type,
    string? Reason,
    DateTimeOffset? ExpiresAt);

internal sealed record RevokeModerationRecordRequest(string? Reason);

internal sealed record CreateContentQueueItemRequest(
    string? SourceType,
    string? SourceId,
    string? PlayerId,
    string? Content,
    string? Reason,
    string? ReporterPlayerId,
    string? Details);

internal sealed record ReviewContentQueueItemRequest(
    string? Status,
    string? Resolution,
    string? Action);

internal sealed record AntiAbuseRuleListDto(AntiAbuseRuleDto[] Rules, DateTimeOffset UpdatedAt);

internal sealed record AntiAbuseRuleDto(
    string RuleId,
    string ActionType,
    bool RequiresIdempotency,
    int WindowSeconds,
    int MaxRequests,
    string Description);

internal sealed record AntiAbuseReviewQueueResponseDto(
    string Status,
    string? PlayerId,
    AntiAbuseReviewItemDto[] Items,
    DateTimeOffset UpdatedAt);

internal sealed record AntiAbuseReviewItemDto(
    string EventId,
    string PlayerId,
    string Username,
    string ActionType,
    string Severity,
    string RuleId,
    string Reason,
    string SubjectType,
    string SubjectId,
    string Route,
    string? IdempotencyKey,
    string Decision,
    string? AuditId,
    string Metadata,
    int RecentLedgerEntries,
    int RecentMarketFills,
    int RecentActivityEvents,
    string Status,
    DateTimeOffset CreatedAt,
    string? ReviewedBy,
    DateTimeOffset? ReviewedAt,
    string Resolution);

internal sealed record ReviewAntiAbuseEventRequest(string? Status, string? Resolution);

internal static class AdminAntiAbuseRules
{
    public static AntiAbuseRuleDto[] All { get; } =
    [
        new("rate.player_work.5m", "player_work", false, 300, 6, "A player may attempt work at most 6 times per 5 minutes."),
        new("rate.player_train.5m", "player_train", false, 300, 10, "A player may attempt training at most 10 times per 5 minutes."),
        new("idempotency.hospital_recover", "hospital_recover", true, 600, 6, "Hospital recovery requires an Idempotency-Key and allows 6 attempts per 10 minutes."),
        new("idempotency.inventory_item_use", "inventory_item_use", true, 300, 20, "Inventory item use requires an Idempotency-Key and allows 20 attempts per 5 minutes."),
        new("idempotency.weapon_equip", "weapon_equip", true, 600, 10, "Weapon equip requires an Idempotency-Key and allows 10 attempts per 10 minutes."),
        new("idempotency.weapon_repair", "weapon_repair", true, 600, 10, "Weapon repair requires an Idempotency-Key and allows 10 attempts per 10 minutes."),
        new("idempotency.market_buy", "market_buy", true, 300, 30, "Market purchases require an Idempotency-Key and allow 30 attempts per 5 minutes."),
        new("idempotency.market_sell", "market_sell", true, 3600, 40, "Market listing creation requires an Idempotency-Key and allows 40 listings per hour."),
        new("idempotency.market_cancel", "market_cancel", true, 600, 30, "Market listing cancellation requires an Idempotency-Key and allows 30 attempts per 10 minutes."),
        new("idempotency.trade_create", "trade_create", true, 3600, 60, "Trade offer creation requires an Idempotency-Key and allows 60 offers per hour."),
        new("idempotency.trade_accept", "trade_accept", true, 600, 30, "Trade acceptance requires an Idempotency-Key and allows 30 attempts per 10 minutes."),
        new("idempotency.trade_cancel", "trade_cancel", true, 600, 30, "Trade cancellation requires an Idempotency-Key and allows 30 attempts per 10 minutes."),
        new("idempotency.combat_fight", "combat_fight", true, 300, 20, "Combat fights require an Idempotency-Key and allow 20 attempts per 5 minutes.")
    ];
}

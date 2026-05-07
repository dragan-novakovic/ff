using Npgsql;

internal static class WorldTreasuryEndpoints
{
    public static void MapTreasuryEndpoints(this WebApplication app)
    {
        app.MapGet("/countries/{countryId}/treasury", async (
            string countryId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var token = tokens.Validate(request.Headers.Authorization.ToString());
            if (!token.IsValid)
            {
                return Results.Json(
                    new ErrorResponse("A valid bearer token is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var treasury = await world.GetCountryTreasuryAsync(countryId, token.PlayerId);
            return treasury is null
                ? Results.NotFound(new ErrorResponse("Country was not found."))
                : Results.Ok(treasury);
        }).WithName("GetCountryTreasury");

        app.MapPost("/countries/{countryId}/tax-policy", async (
            string countryId,
            CountryTaxPolicyUpdateRequest policyRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var token = tokens.Validate(request.Headers.Authorization.ToString());
            if (!token.IsValid)
            {
                return Results.Json(
                    new ErrorResponse("A valid bearer token is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var result = await world.UpdateTaxPolicyAsync(countryId, token.PlayerId!, policyRequest);
            return result.Completed
                ? Results.Ok(result)
                : Results.Json(new ErrorResponse(result.Message), statusCode: result.StatusCode);
        }).WithName("UpdateCountryTaxPolicy");

        app.MapGet("/internal/players/{playerId}/citizenship", async (
            string playerId,
            HttpRequest request,
            WorldStore world,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(request, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return Results.Ok(await world.GetPlayerCitizenshipAsync(playerId));
        }).WithName("GetInternalPlayerCitizenship");

        app.MapPost("/countries/{countryId}/treasury/tax-collections", async (
            string countryId,
            CountryTaxCollectionRequest collectionRequest,
            HttpRequest request,
            WorldStore world,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(request, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            if (collectionRequest.Amount <= 0 ||
                collectionRequest.GrossAmount < 0 ||
                collectionRequest.TaxRate < 0 ||
                string.IsNullOrWhiteSpace(collectionRequest.EntryType) ||
                string.IsNullOrWhiteSpace(collectionRequest.IdempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse(
                    "Amount, gross amount, tax rate, entry type, and idempotency key are required."));
            }

            var result = await world.CollectCountryTaxAsync(countryId, collectionRequest);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Country was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(new ErrorResponse(result.Message), statusCode: StatusCodes.Status409Conflict);
        }).WithName("CollectCountryTax");
    }

    private static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
    {
        var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
        return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
            string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
    }
}

internal sealed partial class WorldStore
{
    private const int MaximumTaxRate = 50;

    private async Task InitializeTreasurySchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.country_tax_policies (
                country_id text PRIMARY KEY REFERENCES world.countries(country_id) ON DELETE CASCADE,
                income_tax_rate integer NOT NULL,
                market_tax_rate integer NOT NULL,
                production_tax_rate integer NOT NULL,
                updated_by_player_id text NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT country_tax_policies_income_rate_check
                    CHECK (income_tax_rate >= 0 AND income_tax_rate <= 50),
                CONSTRAINT country_tax_policies_market_rate_check
                    CHECK (market_tax_rate >= 0 AND market_tax_rate <= 50),
                CONSTRAINT country_tax_policies_production_rate_check
                    CHECK (production_tax_rate >= 0 AND production_tax_rate <= 50)
            );

            CREATE TABLE IF NOT EXISTS world.country_policy_authorizations (
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                role text NOT NULL,
                granted_at timestamptz NOT NULL,
                granted_by_player_id text NOT NULL,
                PRIMARY KEY (country_id, player_id)
            );

            CREATE INDEX IF NOT EXISTS ix_world_country_policy_authorizations_player_id
                ON world.country_policy_authorizations (player_id);

            CREATE TABLE IF NOT EXISTS world.country_treasury_ledger (
                ledger_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                entry_type text NOT NULL,
                source_player_id text NOT NULL,
                counterparty_player_id text NOT NULL,
                gold_delta integer NOT NULL,
                gross_amount integer NOT NULL,
                tax_rate integer NOT NULL,
                description text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_country_treasury_ledger_country_created_at
                ON world.country_treasury_ledger (country_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    private async Task SeedTreasuryAsync()
    {
        await InitializeTreasurySchemaAsync();

        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        foreach (var country in WorldCatalog.Countries)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO world.country_tax_policies (
                    country_id, income_tax_rate, market_tax_rate, production_tax_rate,
                    updated_by_player_id, updated_at
                )
                VALUES (
                    @country_id, @income_tax_rate, @market_tax_rate, @production_tax_rate,
                    'system', @updated_at
                )
                ON CONFLICT (country_id) DO NOTHING;
                """, connection);
            command.Parameters.AddWithValue("country_id", country.CountryId);
            command.Parameters.AddWithValue("income_tax_rate", country.TaxRate);
            command.Parameters.AddWithValue("market_tax_rate", Math.Max(1, country.TaxRate / 2));
            command.Parameters.AddWithValue("production_tax_rate", Math.Max(1, country.TaxRate / 3));
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }
    }

    public async Task<CountryTreasuryResponse?> GetCountryTreasuryAsync(
        string countryId,
        string? viewerPlayerId,
        int ledgerLimit = 10)
    {
        var normalizedCountryId = NormalizeId(countryId);
        var normalizedViewerPlayerId = string.IsNullOrWhiteSpace(viewerPlayerId)
            ? null
            : NormalizePlayerId(viewerPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();

        var snapshot = await ReadTreasurySnapshotAsync(connection, null, normalizedCountryId, forUpdate: false);
        if (snapshot is null)
        {
            return null;
        }

        var recentLedger = await ReadRecentTreasuryLedgerAsync(
            connection,
            null,
            normalizedCountryId,
            Math.Clamp(ledgerLimit, 1, 50));
        var authorization = normalizedViewerPlayerId is null
            ? CountryTaxPolicyAuthorizationDto.Denied("Sign in as a citizen to update tax policy.")
            : await DetermineTaxPolicyAuthorizationAsync(
                connection,
                null,
                normalizedCountryId,
                normalizedViewerPlayerId,
                bootstrapIfUnassigned: false);

        return ToTreasuryResponse(snapshot, recentLedger, authorization);
    }

    public async Task<CountryTaxPolicyMutationResult> UpdateTaxPolicyAsync(
        string countryId,
        string playerId,
        CountryTaxPolicyUpdateRequest request)
    {
        var rateValidation = ValidateTaxPolicyRequest(request);
        if (rateValidation is not null)
        {
            return CountryTaxPolicyMutationResult.Failed(rateValidation, StatusCodes.Status400BadRequest);
        }

        var normalizedCountryId = NormalizeId(countryId);
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existing = await ReadTreasurySnapshotAsync(connection, transaction, normalizedCountryId, forUpdate: true);
        if (existing is null)
        {
            await transaction.RollbackAsync();
            return CountryTaxPolicyMutationResult.Failed("Country was not found.", StatusCodes.Status404NotFound);
        }

        var authorization = await DetermineTaxPolicyAuthorizationAsync(
            connection,
            transaction,
            normalizedCountryId,
            normalizedPlayerId,
            bootstrapIfUnassigned: true);
        if (!authorization.CanUpdatePolicy)
        {
            await transaction.RollbackAsync();
            return CountryTaxPolicyMutationResult.Failed(authorization.Message, StatusCodes.Status403Forbidden);
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.country_tax_policies (
                country_id, income_tax_rate, market_tax_rate, production_tax_rate,
                updated_by_player_id, updated_at
            )
            VALUES (
                @country_id, @income_tax_rate, @market_tax_rate, @production_tax_rate,
                @updated_by_player_id, @updated_at
            )
            ON CONFLICT (country_id) DO UPDATE
            SET income_tax_rate = EXCLUDED.income_tax_rate,
                market_tax_rate = EXCLUDED.market_tax_rate,
                production_tax_rate = EXCLUDED.production_tax_rate,
                updated_by_player_id = EXCLUDED.updated_by_player_id,
                updated_at = EXCLUDED.updated_at;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("country_id", normalizedCountryId);
            command.Parameters.AddWithValue("income_tax_rate", request.IncomeTaxRate!.Value);
            command.Parameters.AddWithValue("market_tax_rate", request.MarketTaxRate!.Value);
            command.Parameters.AddWithValue("production_tax_rate", request.ProductionTaxRate!.Value);
            command.Parameters.AddWithValue("updated_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await using (var command = new NpgsqlCommand("""
            UPDATE world.countries
            SET tax_rate = @tax_rate,
                updated_at = @updated_at
            WHERE country_id = @country_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("country_id", normalizedCountryId);
            command.Parameters.AddWithValue("tax_rate", request.IncomeTaxRate.Value);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();

        var treasury = await GetCountryTreasuryAsync(normalizedCountryId, normalizedPlayerId);
        return new CountryTaxPolicyMutationResult(
            Completed: true,
            Message: "Country tax policy was updated.",
            Treasury: treasury,
            StatusCode: StatusCodes.Status200OK);
    }

    public async Task<CountryTaxCollectionResult?> CollectCountryTaxAsync(
        string countryId,
        CountryTaxCollectionRequest request)
    {
        var normalizedCountryId = NormalizeId(countryId);
        var idempotencyKey = request.IdempotencyKey.Trim().ToLowerInvariant();
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existingEntry = await ReadTreasuryLedgerByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (existingEntry is not null)
        {
            if (!string.Equals(existingEntry.CountryId, normalizedCountryId, StringComparison.Ordinal))
            {
                await transaction.RollbackAsync();
                return new CountryTaxCollectionResult(
                    Completed: false,
                    Message: "Idempotency key was already used by another country treasury.",
                    CountryId: normalizedCountryId,
                    Amount: 0,
                    Treasury: 0,
                    Entry: null,
                    UpdatedAt: DateTimeOffset.UtcNow);
            }

            var currentTreasury = await ReadCountryTreasuryBalanceAsync(connection, transaction, normalizedCountryId);
            await transaction.CommitAsync();
            return new CountryTaxCollectionResult(
                Completed: true,
                Message: "Tax collection was already applied.",
                CountryId: normalizedCountryId,
                Amount: existingEntry.GoldDelta,
                Treasury: currentTreasury,
                Entry: existingEntry,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        var snapshot = await ReadTreasurySnapshotAsync(connection, transaction, normalizedCountryId, forUpdate: true);
        if (snapshot is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        var newTreasury = await AddCountryTreasuryAsync(
            connection,
            transaction,
            normalizedCountryId,
            request.Amount,
            now);
        var entry = await AddTreasuryLedgerAsync(
            connection,
            transaction,
            normalizedCountryId,
            request,
            idempotencyKey,
            now);
        await transaction.CommitAsync();

        return new CountryTaxCollectionResult(
            Completed: true,
            Message: $"Collected {request.Amount} gold for {snapshot.Name}.",
            CountryId: normalizedCountryId,
            Amount: request.Amount,
            Treasury: newTreasury,
            Entry: entry,
            UpdatedAt: now);
    }

    private static string? ValidateTaxPolicyRequest(CountryTaxPolicyUpdateRequest request)
    {
        if (request.IncomeTaxRate is null ||
            request.MarketTaxRate is null ||
            request.ProductionTaxRate is null)
        {
            return "Income, market, and production tax rates are required.";
        }

        return ValidateRate(request.IncomeTaxRate.Value, "Income tax")
            ?? ValidateRate(request.MarketTaxRate.Value, "Market tax")
            ?? ValidateRate(request.ProductionTaxRate.Value, "Production tax");
    }

    private static string? ValidateRate(int rate, string name)
    {
        return rate is < 0 or > MaximumTaxRate
            ? $"{name} must be between 0 and {MaximumTaxRate} percent."
            : null;
    }

    private static async Task<CountryTaxPolicyAuthorizationDto> DetermineTaxPolicyAuthorizationAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        string playerId,
        bool bootstrapIfUnassigned)
    {
        await using (var citizenship = new NpgsqlCommand("""
            SELECT status
            FROM world.player_citizenships
            WHERE player_id = @player_id AND country_id = @country_id;
            """, connection, transaction))
        {
            citizenship.Parameters.AddWithValue("player_id", playerId);
            citizenship.Parameters.AddWithValue("country_id", countryId);
            var status = await citizenship.ExecuteScalarAsync() as string;
            if (!string.Equals(status, "active", StringComparison.OrdinalIgnoreCase))
            {
                return CountryTaxPolicyAuthorizationDto.Denied(
                    "Only active citizens of this country can update tax policy.");
            }
        }

        var officeRole = await ReadActiveOfficeRoleAsync(connection, transaction, countryId, playerId);
        if (!string.IsNullOrWhiteSpace(officeRole))
        {
            return CountryTaxPolicyAuthorizationDto.Allowed(
                officeRole,
                "You hold an active elected country office.");
        }

        await using (var roleCommand = new NpgsqlCommand("""
            SELECT role
            FROM world.country_policy_authorizations
            WHERE country_id = @country_id AND player_id = @player_id;
            """, connection, transaction))
        {
            roleCommand.Parameters.AddWithValue("country_id", countryId);
            roleCommand.Parameters.AddWithValue("player_id", playerId);
            var role = await roleCommand.ExecuteScalarAsync() as string;
            if (!string.IsNullOrWhiteSpace(role))
            {
                return CountryTaxPolicyAuthorizationDto.Allowed(
                    role,
                    "You hold the recorded country treasury office.");
            }
        }

        await using (var countCommand = new NpgsqlCommand("""
            SELECT COUNT(*)::bigint
            FROM world.country_policy_authorizations
            WHERE country_id = @country_id;
            """, connection, transaction))
        {
            countCommand.Parameters.AddWithValue("country_id", countryId);
            var authorizationCount = Convert.ToInt64(await countCommand.ExecuteScalarAsync() ?? 0L);
            if (authorizationCount > 0)
            {
                return CountryTaxPolicyAuthorizationDto.Denied(
                    "A recorded country treasury office holder must update tax policy.");
            }
        }

        if (!bootstrapIfUnassigned)
        {
            return CountryTaxPolicyAuthorizationDto.Allowed(
                "citizen-bootstrap-pending",
                "No treasury office holder is recorded yet; the first active citizen to save policy becomes founding treasurer.");
        }

        var now = DateTimeOffset.UtcNow;
        await using (var grant = new NpgsqlCommand("""
            INSERT INTO world.country_policy_authorizations (
                country_id, player_id, role, granted_at, granted_by_player_id
            )
            VALUES (
                @country_id, @player_id, 'founding-treasurer', @granted_at, @granted_by_player_id
            )
            ON CONFLICT (country_id, player_id) DO NOTHING;
            """, connection, transaction))
        {
            grant.Parameters.AddWithValue("country_id", countryId);
            grant.Parameters.AddWithValue("player_id", playerId);
            grant.Parameters.AddWithValue("granted_at", now);
            grant.Parameters.AddWithValue("granted_by_player_id", playerId);
            await grant.ExecuteNonQueryAsync();
        }

        return CountryTaxPolicyAuthorizationDto.Allowed(
            "founding-treasurer",
            "You are now recorded as founding treasurer for this country.");
    }

    private static async Task<string?> ReadActiveOfficeRoleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        string playerId)
    {
        await using (var tableCheck = new NpgsqlCommand(
            "SELECT to_regclass('world.office_terms') IS NOT NULL;",
            connection,
            transaction))
        {
            var hasOfficeTerms = await tableCheck.ExecuteScalarAsync();
            if (hasOfficeTerms is not bool officeTermsExist || !officeTermsExist)
            {
                return null;
            }
        }

        await using var command = new NpgsqlCommand("""
            SELECT office_id, office_name
            FROM world.office_terms
            WHERE country_id = @country_id
              AND player_id = @player_id
              AND status = 'active'
              AND ends_at > @now
            ORDER BY office_id
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("now", DateTimeOffset.UtcNow);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? $"office:{reader.GetString(0)}:{reader.GetString(1)}"
            : null;
    }

    private static async Task<CountryTreasurySnapshot?> ReadTreasurySnapshotAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        bool forUpdate)
    {
        var sql = """
            SELECT c.country_id, c.name, c.code, c.treasury,
                   COALESCE(p.income_tax_rate, c.tax_rate) AS income_tax_rate,
                   COALESCE(p.market_tax_rate, GREATEST(0, c.tax_rate / 2)) AS market_tax_rate,
                   COALESCE(p.production_tax_rate, GREATEST(0, c.tax_rate / 3)) AS production_tax_rate,
                   COALESCE(p.updated_by_player_id, 'system') AS updated_by_player_id,
                   COALESCE(p.updated_at, c.updated_at) AS policy_updated_at,
                   c.updated_at
            FROM world.countries c
            LEFT JOIN world.country_tax_policies p ON p.country_id = c.country_id
            WHERE c.country_id = @country_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE OF c";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        var policy = new CountryTaxPolicyDto(
            CountryId: reader.GetString(0),
            IncomeTaxRate: reader.GetInt32(4),
            MarketTaxRate: reader.GetInt32(5),
            ProductionTaxRate: reader.GetInt32(6),
            UpdatedByPlayerId: reader.GetString(7),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(8));
        return new CountryTreasurySnapshot(
            CountryId: reader.GetString(0),
            Name: reader.GetString(1),
            Code: reader.GetString(2),
            Treasury: reader.GetInt32(3),
            Policy: policy,
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static async Task<int> ReadCountryTreasuryBalanceAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT treasury
            FROM world.countries
            WHERE country_id = @country_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        return (int)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Country treasury was not found."));
    }

    private static async Task<int> AddCountryTreasuryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId,
        int amount,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.countries
            SET treasury = treasury + @amount,
                updated_at = @updated_at
            WHERE country_id = @country_id
            RETURNING treasury;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("amount", amount);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        return (int)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Country treasury update did not return a balance."));
    }

    private static async Task<CountryTreasuryLedgerEntryDto> AddTreasuryLedgerAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId,
        CountryTaxCollectionRequest request,
        string idempotencyKey,
        DateTimeOffset createdAt)
    {
        var entry = new CountryTreasuryLedgerEntryDto(
            LedgerId: string.IsNullOrWhiteSpace(request.LedgerId)
                ? $"tax-{Guid.NewGuid():N}"
                : request.LedgerId.Trim().ToLowerInvariant(),
            CountryId: countryId,
            EntryType: request.EntryType.Trim().ToLowerInvariant(),
            SourcePlayerId: NormalizeOptionalPlayerId(request.SourcePlayerId),
            CounterpartyPlayerId: NormalizeOptionalPlayerId(request.CounterpartyPlayerId),
            GoldDelta: request.Amount,
            GrossAmount: request.GrossAmount,
            TaxRate: request.TaxRate,
            Description: request.Description?.Trim() ?? string.Empty,
            CreatedAt: createdAt);

        await using var command = new NpgsqlCommand("""
            INSERT INTO world.country_treasury_ledger (
                ledger_id, country_id, entry_type, source_player_id, counterparty_player_id,
                gold_delta, gross_amount, tax_rate, description, idempotency_key, created_at
            )
            VALUES (
                @ledger_id, @country_id, @entry_type, @source_player_id, @counterparty_player_id,
                @gold_delta, @gross_amount, @tax_rate, @description, @idempotency_key, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("ledger_id", entry.LedgerId);
        command.Parameters.AddWithValue("country_id", entry.CountryId);
        command.Parameters.AddWithValue("entry_type", entry.EntryType);
        command.Parameters.AddWithValue("source_player_id", entry.SourcePlayerId);
        command.Parameters.AddWithValue("counterparty_player_id", entry.CounterpartyPlayerId);
        command.Parameters.AddWithValue("gold_delta", entry.GoldDelta);
        command.Parameters.AddWithValue("gross_amount", entry.GrossAmount);
        command.Parameters.AddWithValue("tax_rate", entry.TaxRate);
        command.Parameters.AddWithValue("description", entry.Description);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("created_at", entry.CreatedAt);
        await command.ExecuteNonQueryAsync();

        return entry;
    }

    private static async Task<CountryTreasuryLedgerEntryDto?> ReadTreasuryLedgerByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT ledger_id, country_id, entry_type, source_player_id, counterparty_player_id,
                   gold_delta, gross_amount, tax_rate, description, created_at
            FROM world.country_treasury_ledger
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTreasuryLedgerEntry(reader) : null;
    }

    private static async Task<List<CountryTreasuryLedgerEntryDto>> ReadRecentTreasuryLedgerAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT ledger_id, country_id, entry_type, source_player_id, counterparty_player_id,
                   gold_delta, gross_amount, tax_rate, description, created_at
            FROM world.country_treasury_ledger
            WHERE country_id = @country_id
            ORDER BY created_at DESC, ledger_id DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("limit", limit);

        var entries = new List<CountryTreasuryLedgerEntryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(ReadTreasuryLedgerEntry(reader));
        }

        return entries;
    }

    private static CountryTreasuryLedgerEntryDto ReadTreasuryLedgerEntry(NpgsqlDataReader reader)
    {
        return new CountryTreasuryLedgerEntryDto(
            LedgerId: reader.GetString(0),
            CountryId: reader.GetString(1),
            EntryType: reader.GetString(2),
            SourcePlayerId: reader.GetString(3),
            CounterpartyPlayerId: reader.GetString(4),
            GoldDelta: reader.GetInt32(5),
            GrossAmount: reader.GetInt32(6),
            TaxRate: reader.GetInt32(7),
            Description: reader.GetString(8),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static CountryTreasuryResponse ToTreasuryResponse(
        CountryTreasurySnapshot snapshot,
        IReadOnlyCollection<CountryTreasuryLedgerEntryDto> recentLedger,
        CountryTaxPolicyAuthorizationDto authorization)
    {
        return new CountryTreasuryResponse(
            CountryId: snapshot.CountryId,
            Name: snapshot.Name,
            Code: snapshot.Code,
            Treasury: snapshot.Treasury,
            Policy: snapshot.Policy,
            RecentLedger: recentLedger.ToArray(),
            Authorization: authorization,
            UpdatedAt: snapshot.UpdatedAt);
    }

    private static string NormalizeOptionalPlayerId(string? playerId)
    {
        return string.IsNullOrWhiteSpace(playerId)
            ? string.Empty
            : playerId.Trim().ToLowerInvariant();
    }
}

internal sealed record CountryTreasurySnapshot(
    string CountryId,
    string Name,
    string Code,
    int Treasury,
    CountryTaxPolicyDto Policy,
    DateTimeOffset UpdatedAt);

internal sealed record CountryTreasuryResponse(
    string CountryId,
    string Name,
    string Code,
    int Treasury,
    CountryTaxPolicyDto Policy,
    CountryTreasuryLedgerEntryDto[] RecentLedger,
    CountryTaxPolicyAuthorizationDto Authorization,
    DateTimeOffset UpdatedAt);

internal sealed record CountryTaxPolicyDto(
    string CountryId,
    int IncomeTaxRate,
    int MarketTaxRate,
    int ProductionTaxRate,
    string UpdatedByPlayerId,
    DateTimeOffset UpdatedAt);

internal sealed record CountryTaxPolicyAuthorizationDto(
    bool CanUpdatePolicy,
    string? Role,
    string Message)
{
    public static CountryTaxPolicyAuthorizationDto Allowed(string role, string message)
    {
        return new CountryTaxPolicyAuthorizationDto(true, role, message);
    }

    public static CountryTaxPolicyAuthorizationDto Denied(string message)
    {
        return new CountryTaxPolicyAuthorizationDto(false, null, message);
    }
}

internal sealed record CountryTaxPolicyUpdateRequest(
    int? IncomeTaxRate,
    int? MarketTaxRate,
    int? ProductionTaxRate);

internal sealed record CountryTaxPolicyMutationResult(
    bool Completed,
    string Message,
    CountryTreasuryResponse? Treasury,
    int StatusCode)
{
    public static CountryTaxPolicyMutationResult Failed(string message, int statusCode)
    {
        return new CountryTaxPolicyMutationResult(false, message, null, statusCode);
    }
}

internal sealed record CountryTaxCollectionRequest(
    int Amount,
    int GrossAmount,
    int TaxRate,
    string EntryType,
    string? SourcePlayerId,
    string? CounterpartyPlayerId,
    string? Description,
    string IdempotencyKey,
    string? LedgerId = null);

internal sealed record CountryTaxCollectionResult(
    bool Completed,
    string Message,
    string CountryId,
    int Amount,
    int Treasury,
    CountryTreasuryLedgerEntryDto? Entry,
    DateTimeOffset UpdatedAt);

internal sealed record CountryTreasuryLedgerEntryDto(
    string LedgerId,
    string CountryId,
    string EntryType,
    string SourcePlayerId,
    string CounterpartyPlayerId,
    int GoldDelta,
    int GrossAmount,
    int TaxRate,
    string Description,
    DateTimeOffset CreatedAt);

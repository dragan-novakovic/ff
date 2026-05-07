using Npgsql;

internal static class DiplomacyEndpoints
{
    public static void MapDiplomacyEndpoints(this WebApplication app)
    {
        app.MapGet("/players/{playerId}/diplomacy", async (
            string playerId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return Results.Ok(await world.GetPlayerDiplomacyAsync(access.PlayerId!));
        }).WithName("GetPlayerDiplomacy");

        app.MapGet("/countries/{countryId}/diplomacy", async (
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

            var diplomacy = await world.GetCountryDiplomacyAsync(countryId, token.PlayerId);
            return diplomacy is null
                ? Results.NotFound(new ErrorResponse("Country was not found."))
                : Results.Ok(diplomacy);
        }).WithName("GetCountryDiplomacy");

        app.MapGet("/diplomacy/treaties", async (
            string? countryId,
            string? counterpartyCountryId,
            string? status,
            string? treatyType,
            int? limit,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return Results.Ok(await world.GetTreatiesAsync(
                countryId,
                counterpartyCountryId,
                status,
                treatyType,
                limit));
        }).WithName("GetDiplomacyTreaties");

        app.MapGet("/diplomacy/treaties/{treatyId}", async (
            string treatyId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var details = await world.GetTreatyDetailsAsync(treatyId);
            return details is null
                ? Results.NotFound(new ErrorResponse("Treaty was not found."))
                : Results.Ok(details);
        }).WithName("GetDiplomacyTreaty");

        app.MapPost("/players/{playerId}/diplomacy/proposals", async (
            string playerId,
            TreatyProposalRequest proposal,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateTreatyProposal(proposal);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.CreateTreatyProposalAsync(access.PlayerId!, proposal);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Country was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("CreateDiplomacyTreatyProposal");

        app.MapPost("/players/{playerId}/diplomacy/treaties/{treatyId}/ratify", async (
            string playerId,
            string treatyId,
            TreatyRatificationRequest ratification,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(ratification.IdempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Ratification idempotency key is required."));
            }

            var result = await world.RatifyTreatyAsync(access.PlayerId!, treatyId, ratification);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Treaty was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("RatifyDiplomacyTreaty");

        app.MapPost("/players/{playerId}/diplomacy/treaties/{treatyId}/reject", async (
            string playerId,
            string treatyId,
            TreatyRejectionRequest rejection,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(rejection.IdempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Rejection idempotency key is required."));
            }

            var result = await world.RejectTreatyAsync(access.PlayerId!, treatyId, rejection);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Treaty was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("RejectDiplomacyTreaty");

        app.MapPost("/players/{playerId}/diplomacy/treaties/{treatyId}/terminate", async (
            string playerId,
            string treatyId,
            TreatyTerminationRequest termination,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(termination.IdempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Termination idempotency key is required."));
            }

            var result = await world.TerminateTreatyAsync(access.PlayerId!, treatyId, termination);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Treaty was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("TerminateDiplomacyTreaty");

        app.MapGet("/internal/diplomacy/countries/{countryId}/counterparties/{counterpartyCountryId}", async (
            string countryId,
            string counterpartyCountryId,
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

            return Results.Ok(await world.GetDiplomaticRelationshipCheckAsync(countryId, counterpartyCountryId));
        }).WithName("GetInternalDiplomacyRelationshipCheck");
    }

    internal static string? NormalizeTreatyType(string? treatyType)
    {
        var normalized = treatyType?.Trim().ToLowerInvariant().Replace('-', '_');
        return normalized is TreatyTypes.Alliance
            or TreatyTypes.Embargo
            or TreatyTypes.Peace
            or TreatyTypes.MilitaryAccess
            or TreatyTypes.TradeAgreement
            ? normalized
            : null;
    }

    internal static string? NormalizeTreatyStatus(string? status)
    {
        var normalized = status?.Trim().ToLowerInvariant();
        return string.IsNullOrWhiteSpace(normalized)
            ? null
            : normalized is TreatyStatuses.Proposed
                or TreatyStatuses.Active
                or TreatyStatuses.Rejected
                or TreatyStatuses.Terminated
                or TreatyStatuses.Expired
                    ? normalized
                    : null;
    }

    internal static bool RequiresTargetRatification(string treatyType)
    {
        return !string.Equals(treatyType, TreatyTypes.Embargo, StringComparison.Ordinal);
    }

    private static IResult? ValidateBearer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? null
            : Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized);
    }

    private static PlayerAccessResult ValidatePlayerAccess(
        string playerId,
        HttpRequest request,
        DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        if (!token.IsValid)
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
        }

        if (!string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase))
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("You cannot manage another player's diplomacy."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
    {
        var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
        return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
            string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
    }

    private static string? ValidateTreatyProposal(TreatyProposalRequest proposal)
    {
        var treatyType = NormalizeTreatyType(proposal.TreatyType);
        if (treatyType is null)
        {
            return "Treaty type must be alliance, embargo, peace, military_access, or trade_agreement.";
        }

        if (string.IsNullOrWhiteSpace(proposal.TargetCountryId))
        {
            return "Target country is required.";
        }

        if (string.IsNullOrWhiteSpace(proposal.Title) || proposal.Title.Trim().Length < 3)
        {
            return "Treaty title must be at least 3 characters.";
        }

        if (proposal.Title.Length > 120 || proposal.Terms?.Length > 2_000)
        {
            return "Treaty title or terms are too long.";
        }

        if (proposal.DurationDays is <= 0 or > 3_650)
        {
            return "Treaty duration must be between 1 and 3650 days.";
        }

        if (proposal.TreasuryAmount is < 0 or > 1_000_000)
        {
            return "Treasury transfer must be between 0 and 1000000 gold.";
        }

        if (treatyType == TreatyTypes.Embargo && proposal.TreasuryAmount is > 0)
        {
            return "Embargoes cannot include treasury transfers.";
        }

        if (string.IsNullOrWhiteSpace(proposal.IdempotencyKey))
        {
            return "Treaty proposal idempotency key is required.";
        }

        return null;
    }
}

internal sealed partial class WorldStore
{
    private const int DefaultTreatyDurationDays = 90;
    private const int MaximumTreatyDurationDays = 3_650;

    public async Task InitializeDiplomacySchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.diplomacy_treaties (
                treaty_id text PRIMARY KEY,
                initiator_country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                target_country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                treaty_type text NOT NULL,
                status text NOT NULL,
                title text NOT NULL,
                terms text NOT NULL,
                source_law_id text NULL REFERENCES world.laws(law_id) ON DELETE SET NULL,
                proposed_by_player_id text NOT NULL,
                proposed_at timestamptz NOT NULL,
                ratified_by_player_id text NULL,
                ratified_at timestamptz NULL,
                rejected_by_player_id text NULL,
                rejected_at timestamptz NULL,
                rejection_reason text NOT NULL DEFAULT '',
                terminated_by_player_id text NULL,
                terminated_at timestamptz NULL,
                termination_reason text NOT NULL DEFAULT '',
                starts_at timestamptz NULL,
                expires_at timestamptz NULL,
                duration_days integer NOT NULL,
                treasury_amount integer NOT NULL DEFAULT 0,
                treasury_transfer_status text NOT NULL DEFAULT 'not_required',
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT diplomacy_treaties_type_check
                    CHECK (treaty_type IN ('alliance', 'embargo', 'peace', 'military_access', 'trade_agreement')),
                CONSTRAINT diplomacy_treaties_status_check
                    CHECK (status IN ('proposed', 'active', 'rejected', 'terminated', 'expired')),
                CONSTRAINT diplomacy_treaties_duration_check
                    CHECK (duration_days > 0 AND duration_days <= 3650),
                CONSTRAINT diplomacy_treaties_treasury_amount_check
                    CHECK (treasury_amount >= 0),
                CONSTRAINT diplomacy_treaties_transfer_status_check
                    CHECK (treasury_transfer_status IN ('not_required', 'pending', 'transferred', 'failed')),
                CONSTRAINT diplomacy_treaties_distinct_countries_check
                    CHECK (initiator_country_id <> target_country_id)
            );

            CREATE INDEX IF NOT EXISTS ix_world_diplomacy_initiator_status
                ON world.diplomacy_treaties (initiator_country_id, status, updated_at DESC);

            CREATE INDEX IF NOT EXISTS ix_world_diplomacy_target_status
                ON world.diplomacy_treaties (target_country_id, status, updated_at DESC);

            CREATE INDEX IF NOT EXISTS ix_world_diplomacy_active_expiry
                ON world.diplomacy_treaties (status, expires_at);

            CREATE TABLE IF NOT EXISTS world.diplomacy_treaty_events (
                event_id text PRIMARY KEY,
                treaty_id text NOT NULL REFERENCES world.diplomacy_treaties(treaty_id) ON DELETE CASCADE,
                actor_player_id text NOT NULL,
                action text NOT NULL,
                message text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_diplomacy_events_treaty_created
                ON world.diplomacy_treaty_events (treaty_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<PlayerDiplomacyResponse> GetPlayerDiplomacyAsync(string playerId)
    {
        await ExpireDiplomacyTreatiesAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var citizenship = await ReadPlayerCitizenshipAsync(connection, null, normalizedPlayerId);
        if (citizenship is null || !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            return new PlayerDiplomacyResponse(
                normalizedPlayerId,
                citizenship,
                DiplomacyAuthorizationDto.Denied("Join a country before using diplomacy."),
                [],
                [],
                [],
                DateTimeOffset.UtcNow);
        }

        var active = await ReadTreatiesAsync(connection, null, citizenship.CountryId, null, TreatyStatuses.Active, null, 100);
        var pending = await ReadTreatiesAsync(connection, null, citizenship.CountryId, null, TreatyStatuses.Proposed, null, 100);
        var authorization = await DetermineDiplomacyAuthorizationAsync(
            connection,
            null,
            citizenship.CountryId,
            normalizedPlayerId);
        return new PlayerDiplomacyResponse(
            normalizedPlayerId,
            citizenship,
            authorization,
            active.ToArray(),
            pending.ToArray(),
            BuildDiplomaticRelations(citizenship.CountryId, active).ToArray(),
            DateTimeOffset.UtcNow);
    }

    public async Task<CountryDiplomacyResponse?> GetCountryDiplomacyAsync(string countryId, string? viewerPlayerId)
    {
        await ExpireDiplomacyTreatiesAsync();
        var normalizedCountryId = NormalizeId(countryId);
        var normalizedViewerId = string.IsNullOrWhiteSpace(viewerPlayerId) ? null : NormalizePlayerId(viewerPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (!await CountryExistsAsync(connection, null, normalizedCountryId))
        {
            return null;
        }

        var active = await ReadTreatiesAsync(connection, null, normalizedCountryId, null, TreatyStatuses.Active, null, 100);
        var pending = await ReadTreatiesAsync(connection, null, normalizedCountryId, null, TreatyStatuses.Proposed, null, 100);
        var authorization = normalizedViewerId is null
            ? DiplomacyAuthorizationDto.Denied("Sign in to manage diplomacy.")
            : await DetermineDiplomacyAuthorizationAsync(connection, null, normalizedCountryId, normalizedViewerId);
        return new CountryDiplomacyResponse(
            normalizedCountryId,
            authorization,
            active.ToArray(),
            pending.ToArray(),
            BuildDiplomaticRelations(normalizedCountryId, active).ToArray(),
            DateTimeOffset.UtcNow);
    }

    public async Task<TreatyListResponse> GetTreatiesAsync(
        string? countryId,
        string? counterpartyCountryId,
        string? status,
        string? treatyType,
        int? limit)
    {
        await ExpireDiplomacyTreatiesAsync();
        await using var connection = await _dataSource.OpenConnectionAsync();
        var treaties = await ReadTreatiesAsync(
            connection,
            null,
            string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId),
            string.IsNullOrWhiteSpace(counterpartyCountryId) ? null : NormalizeId(counterpartyCountryId),
            DiplomacyEndpoints.NormalizeTreatyStatus(status),
            DiplomacyEndpoints.NormalizeTreatyType(treatyType),
            Math.Clamp(limit ?? 50, 1, 100));
        return new TreatyListResponse(treaties.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<TreatyDetailsResponse?> GetTreatyDetailsAsync(string treatyId)
    {
        await ExpireDiplomacyTreatiesAsync();
        await using var connection = await _dataSource.OpenConnectionAsync();
        var treaty = await ReadTreatyAsync(connection, null, NormalizeId(treatyId));
        if (treaty is null)
        {
            return null;
        }

        var events = await ReadTreatyEventsAsync(connection, null, treaty.TreatyId);
        return new TreatyDetailsResponse(treaty, events.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<DiplomacyMutationResult?> CreateTreatyProposalAsync(
        string playerId,
        TreatyProposalRequest request)
    {
        await ExpireDiplomacyTreatiesAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedTargetCountryId = NormalizeId(request.TargetCountryId!);
        var treatyType = DiplomacyEndpoints.NormalizeTreatyType(request.TreatyType)!;
        var durationDays = Math.Clamp(
            request.DurationDays ?? DefaultTreatyDurationDays,
            1,
            MaximumTreatyDurationDays);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null || !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Join a country before proposing treaties.",
                StatusCodes.Status409Conflict,
                null,
                DiplomacyAuthorizationDto.Denied("Join a country before using diplomacy."));
        }

        var normalizedInitiatorCountryId = string.IsNullOrWhiteSpace(request.InitiatorCountryId)
            ? citizenship.CountryId
            : NormalizeId(request.InitiatorCountryId);
        if (!string.Equals(citizenship.CountryId, normalizedInitiatorCountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "You can only propose treaties for your active country.",
                StatusCodes.Status403Forbidden,
                null,
                DiplomacyAuthorizationDto.Denied("You are not a citizen of the initiating country."));
        }

        if (!await CountryExistsAsync(connection, transaction, normalizedInitiatorCountryId) ||
            !await CountryExistsAsync(connection, transaction, normalizedTargetCountryId))
        {
            await transaction.RollbackAsync();
            return null;
        }

        if (string.Equals(normalizedInitiatorCountryId, normalizedTargetCountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Treaties require two different countries.",
                StatusCodes.Status400BadRequest,
                null,
                null);
        }

        var authorization = await DetermineDiplomacyAuthorizationAsync(
            connection,
            transaction,
            normalizedInitiatorCountryId,
            normalizedPlayerId);
        if (!authorization.CanPropose)
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                null,
                authorization);
        }

        var idempotencyKey = CleanKey(request.IdempotencyKey!);
        var existingByKey = await ReadTreatyByIdempotencyKeyAsync(connection, transaction, idempotencyKey);
        if (existingByKey is not null)
        {
            await transaction.CommitAsync();
            return new DiplomacyMutationResult(
                true,
                "Treaty proposal was already recorded.",
                existingByKey,
                authorization,
                StatusCodes.Status200OK,
                DateTimeOffset.UtcNow);
        }

        var sourceLawId = string.IsNullOrWhiteSpace(request.SourceLawId)
            ? null
            : NormalizeId(request.SourceLawId);
        if (sourceLawId is not null &&
            !await LawAllowsTreatyAsync(connection, transaction, sourceLawId, normalizedInitiatorCountryId))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Source law must be an active law for the initiating country.",
                StatusCodes.Status400BadRequest,
                null,
                authorization);
        }

        var existingOpen = await ReadOpenTreatyBetweenAsync(
            connection,
            transaction,
            normalizedInitiatorCountryId,
            normalizedTargetCountryId,
            treatyType,
            exceptTreatyId: null);
        if (existingOpen is not null)
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                $"A {TreatyDisplayName(treatyType)} treaty is already {existingOpen.Status} between these countries.",
                StatusCodes.Status409Conflict,
                existingOpen,
                authorization);
        }

        var requiresRatification = DiplomacyEndpoints.RequiresTargetRatification(treatyType);
        var treatyId = $"treaty-{treatyType.Replace('_', '-')}-{normalizedInitiatorCountryId}-{normalizedTargetCountryId}-{Guid.NewGuid().ToString("N")[..8]}";
        var title = CleanText(request.Title!, 120);
        var terms = CleanText(request.Terms, 2_000, "No detailed terms were provided.");
        var treasuryAmount = request.TreasuryAmount ?? 0;
        var status = requiresRatification ? TreatyStatuses.Proposed : TreatyStatuses.Active;
        var startsAt = requiresRatification ? (DateTimeOffset?)null : now;
        var expiresAt = requiresRatification ? (DateTimeOffset?)null : now.AddDays(durationDays);
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.diplomacy_treaties (
                treaty_id, initiator_country_id, target_country_id, treaty_type, status,
                title, terms, source_law_id, proposed_by_player_id, proposed_at,
                ratified_by_player_id, ratified_at, starts_at, expires_at, duration_days,
                treasury_amount, treasury_transfer_status, idempotency_key, created_at, updated_at
            )
            VALUES (
                @treaty_id, @initiator_country_id, @target_country_id, @treaty_type, @status,
                @title, @terms, @source_law_id, @proposed_by_player_id, @proposed_at,
                @ratified_by_player_id, @ratified_at, @starts_at, @expires_at, @duration_days,
                @treasury_amount, @treasury_transfer_status, @idempotency_key, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("treaty_id", treatyId);
            command.Parameters.AddWithValue("initiator_country_id", normalizedInitiatorCountryId);
            command.Parameters.AddWithValue("target_country_id", normalizedTargetCountryId);
            command.Parameters.AddWithValue("treaty_type", treatyType);
            command.Parameters.AddWithValue("status", status);
            command.Parameters.AddWithValue("title", title);
            command.Parameters.AddWithValue("terms", terms);
            command.Parameters.AddWithValue("source_law_id", (object?)sourceLawId ?? DBNull.Value);
            command.Parameters.AddWithValue("proposed_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("proposed_at", now);
            command.Parameters.AddWithValue(
                "ratified_by_player_id",
                requiresRatification ? DBNull.Value : normalizedPlayerId);
            command.Parameters.AddWithValue("ratified_at", requiresRatification ? DBNull.Value : now);
            command.Parameters.AddWithValue("starts_at", (object?)startsAt ?? DBNull.Value);
            command.Parameters.AddWithValue("expires_at", (object?)expiresAt ?? DBNull.Value);
            command.Parameters.AddWithValue("duration_days", durationDays);
            command.Parameters.AddWithValue("treasury_amount", treasuryAmount);
            command.Parameters.AddWithValue(
                "treasury_transfer_status",
                treasuryAmount > 0 ? "pending" : "not_required");
            command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await InsertTreatyEventAsync(
            connection,
            transaction,
            treatyId,
            normalizedPlayerId,
            requiresRatification ? "proposed" : "activated",
            requiresRatification
                ? $"Treaty proposal opened by {normalizedInitiatorCountryId}."
                : $"Unilateral {TreatyDisplayName(treatyType)} activated by {normalizedInitiatorCountryId}.",
            now);

        var treaty = await ReadTreatyAsync(connection, transaction, treatyId);
        await transaction.CommitAsync();
        return new DiplomacyMutationResult(
            true,
            requiresRatification
                ? "Treaty proposal is waiting for target country ratification."
                : "Embargo treaty was activated.",
            treaty,
            authorization,
            StatusCodes.Status200OK,
            now);
    }

    public async Task<DiplomacyMutationResult?> RatifyTreatyAsync(
        string playerId,
        string treatyId,
        TreatyRatificationRequest request)
    {
        await ExpireDiplomacyTreatiesAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedTreatyId = NormalizeId(treatyId);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var treaty = await ReadTreatyAsync(connection, transaction, normalizedTreatyId, forUpdate: true);
        if (treaty is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        var authorization = citizenship is null
            ? DiplomacyAuthorizationDto.Denied("Join the target country before ratifying treaties.")
            : await DetermineDiplomacyAuthorizationAsync(connection, transaction, citizenship.CountryId, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(citizenship.CountryId, treaty.TargetCountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Only active citizens of the target country can ratify this treaty.",
                StatusCodes.Status403Forbidden,
                treaty,
                authorization);
        }

        if (!authorization.CanRatify)
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                treaty,
                authorization);
        }

        if (!string.Equals(treaty.Status, TreatyStatuses.Proposed, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Only proposed treaties can be ratified.",
                StatusCodes.Status409Conflict,
                treaty,
                authorization);
        }

        var existingOpen = await ReadOpenTreatyBetweenAsync(
            connection,
            transaction,
            treaty.InitiatorCountryId,
            treaty.TargetCountryId,
            treaty.TreatyType,
            treaty.TreatyId);
        if (existingOpen is not null)
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                $"A {TreatyDisplayName(treaty.TreatyType)} treaty is already {existingOpen.Status} between these countries.",
                StatusCodes.Status409Conflict,
                existingOpen,
                authorization);
        }

        var transferStatus = treaty.TreasuryAmount > 0 ? "transferred" : "not_required";
        if (treaty.TreasuryAmount > 0)
        {
            var transfer = await ApplyTreatyTreasuryTransferAsync(
                connection,
                transaction,
                treaty,
                normalizedPlayerId,
                request.IdempotencyKey!,
                now);
            if (!transfer.Completed)
            {
                await transaction.CommitAsync();
                return DiplomacyMutationResult.Failed(
                    transfer.Message,
                    StatusCodes.Status409Conflict,
                    treaty,
                    authorization);
            }
        }

        await using (var command = new NpgsqlCommand("""
            UPDATE world.diplomacy_treaties
            SET status = 'active',
                ratified_by_player_id = @ratified_by_player_id,
                ratified_at = @ratified_at,
                starts_at = @starts_at,
                expires_at = @expires_at,
                treasury_transfer_status = @treasury_transfer_status,
                updated_at = @updated_at
            WHERE treaty_id = @treaty_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("treaty_id", normalizedTreatyId);
            command.Parameters.AddWithValue("ratified_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("ratified_at", now);
            command.Parameters.AddWithValue("starts_at", now);
            command.Parameters.AddWithValue("expires_at", now.AddDays(treaty.DurationDays));
            command.Parameters.AddWithValue("treasury_transfer_status", transferStatus);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await InsertTreatyEventAsync(
            connection,
            transaction,
            normalizedTreatyId,
            normalizedPlayerId,
            "ratified",
            "Treaty was ratified and activated.",
            now);

        treaty = await ReadTreatyAsync(connection, transaction, normalizedTreatyId);
        await transaction.CommitAsync();
        return new DiplomacyMutationResult(
            true,
            "Treaty ratified and activated.",
            treaty,
            authorization,
            StatusCodes.Status200OK,
            now);
    }

    public async Task<DiplomacyMutationResult?> RejectTreatyAsync(
        string playerId,
        string treatyId,
        TreatyRejectionRequest request)
    {
        await ExpireDiplomacyTreatiesAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedTreatyId = NormalizeId(treatyId);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var treaty = await ReadTreatyAsync(connection, transaction, normalizedTreatyId, forUpdate: true);
        if (treaty is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        var authorization = citizenship is null
            ? DiplomacyAuthorizationDto.Denied("Join the target country before rejecting treaties.")
            : await DetermineDiplomacyAuthorizationAsync(connection, transaction, citizenship.CountryId, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(citizenship.CountryId, treaty.TargetCountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Only active citizens of the target country can reject this treaty.",
                StatusCodes.Status403Forbidden,
                treaty,
                authorization);
        }

        if (!string.Equals(treaty.Status, TreatyStatuses.Proposed, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Only proposed treaties can be rejected.",
                StatusCodes.Status409Conflict,
                treaty,
                authorization);
        }

        if (!authorization.CanRatify)
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                treaty,
                authorization);
        }

        var reason = CleanText(request.Reason, 500, "Rejected by target country.");
        await using (var command = new NpgsqlCommand("""
            UPDATE world.diplomacy_treaties
            SET status = 'rejected',
                rejected_by_player_id = @rejected_by_player_id,
                rejected_at = @rejected_at,
                rejection_reason = @rejection_reason,
                updated_at = @updated_at
            WHERE treaty_id = @treaty_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("treaty_id", normalizedTreatyId);
            command.Parameters.AddWithValue("rejected_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("rejected_at", now);
            command.Parameters.AddWithValue("rejection_reason", reason);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await InsertTreatyEventAsync(
            connection,
            transaction,
            normalizedTreatyId,
            normalizedPlayerId,
            "rejected",
            reason,
            now);

        treaty = await ReadTreatyAsync(connection, transaction, normalizedTreatyId);
        await transaction.CommitAsync();
        return new DiplomacyMutationResult(
            true,
            "Treaty proposal rejected.",
            treaty,
            authorization,
            StatusCodes.Status200OK,
            now);
    }

    public async Task<DiplomacyMutationResult?> TerminateTreatyAsync(
        string playerId,
        string treatyId,
        TreatyTerminationRequest request)
    {
        await ExpireDiplomacyTreatiesAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedTreatyId = NormalizeId(treatyId);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var treaty = await ReadTreatyAsync(connection, transaction, normalizedTreatyId, forUpdate: true);
        if (treaty is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        var authorization = citizenship is null
            ? DiplomacyAuthorizationDto.Denied("Join a treaty country before terminating treaties.")
            : await DetermineDiplomacyAuthorizationAsync(connection, transaction, citizenship.CountryId, normalizedPlayerId);
        var isParticipant = citizenship is not null &&
            (string.Equals(citizenship.CountryId, treaty.InitiatorCountryId, StringComparison.Ordinal) ||
             string.Equals(citizenship.CountryId, treaty.TargetCountryId, StringComparison.Ordinal));
        if (citizenship is null ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase) ||
            !isParticipant)
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Only active citizens of a treaty country can terminate this treaty.",
                StatusCodes.Status403Forbidden,
                treaty,
                authorization);
        }

        if (treaty.TreatyType == TreatyTypes.Embargo &&
            !string.Equals(citizenship.CountryId, treaty.InitiatorCountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Only the embargoing country can lift an embargo.",
                StatusCodes.Status403Forbidden,
                treaty,
                authorization);
        }

        if (!authorization.CanTerminate)
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                treaty,
                authorization);
        }

        if (treaty.Status is not (TreatyStatuses.Active or TreatyStatuses.Proposed))
        {
            await transaction.CommitAsync();
            return DiplomacyMutationResult.Failed(
                "Only active or proposed treaties can be terminated.",
                StatusCodes.Status409Conflict,
                treaty,
                authorization);
        }

        var reason = CleanText(request.Reason, 500, "Terminated by treaty country.");
        await using (var command = new NpgsqlCommand("""
            UPDATE world.diplomacy_treaties
            SET status = 'terminated',
                terminated_by_player_id = @terminated_by_player_id,
                terminated_at = @terminated_at,
                termination_reason = @termination_reason,
                updated_at = @updated_at
            WHERE treaty_id = @treaty_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("treaty_id", normalizedTreatyId);
            command.Parameters.AddWithValue("terminated_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("terminated_at", now);
            command.Parameters.AddWithValue("termination_reason", reason);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await InsertTreatyEventAsync(
            connection,
            transaction,
            normalizedTreatyId,
            normalizedPlayerId,
            "terminated",
            reason,
            now);

        treaty = await ReadTreatyAsync(connection, transaction, normalizedTreatyId);
        await transaction.CommitAsync();
        return new DiplomacyMutationResult(
            true,
            "Treaty terminated.",
            treaty,
            authorization,
            StatusCodes.Status200OK,
            now);
    }

    public async Task<DiplomacyRelationshipCheckResponse> GetDiplomaticRelationshipCheckAsync(
        string countryId,
        string counterpartyCountryId)
    {
        await ExpireDiplomacyTreatiesAsync();
        var normalizedCountryId = NormalizeId(countryId);
        var normalizedCounterpartyId = NormalizeId(counterpartyCountryId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var treaties = await ReadActiveTreatiesBetweenAsync(
            connection,
            null,
            normalizedCountryId,
            normalizedCounterpartyId);
        return new DiplomacyRelationshipCheckResponse(
            normalizedCountryId,
            normalizedCounterpartyId,
            treaties.Any(treaty => treaty.TreatyType == TreatyTypes.Embargo),
            treaties.Any(treaty => treaty.TreatyType == TreatyTypes.Peace),
            treaties.Any(treaty => treaty.TreatyType == TreatyTypes.Alliance),
            treaties.Any(treaty => treaty.TreatyType == TreatyTypes.MilitaryAccess),
            treaties.Any(treaty => treaty.TreatyType == TreatyTypes.TradeAgreement),
            treaties.ToArray(),
            DateTimeOffset.UtcNow);
    }

    private async Task ExpireDiplomacyTreatiesAsync()
    {
        var now = DateTimeOffset.UtcNow;
        await using var command = _dataSource.CreateCommand("""
            UPDATE world.diplomacy_treaties
            SET status = 'expired',
                updated_at = @updated_at
            WHERE status = 'active'
              AND expires_at IS NOT NULL
              AND expires_at <= @updated_at;
            """);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<DiplomacyAuthorizationDto> DetermineDiplomacyAuthorizationAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        string? playerId)
    {
        var congress = await DetermineCongressAuthorizationAsync(connection, transaction, countryId, playerId);
        return congress.CanCreateProposal || congress.CanVote
            ? new DiplomacyAuthorizationDto(
                CanPropose: congress.CanCreateProposal,
                CanRatify: congress.CanVote,
                CanTerminate: congress.CanCreateProposal,
                Role: congress.Role,
                Message: congress.Message)
            : DiplomacyAuthorizationDto.Denied(congress.Message);
    }

    private static async Task<List<TreatyDto>> ReadTreatiesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? countryId,
        string? counterpartyCountryId,
        string? status,
        string? treatyType,
        int limit)
    {
        var conditions = new List<string>();
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            conditions.Add("(t.initiator_country_id = @country_id OR t.target_country_id = @country_id)");
        }
        if (!string.IsNullOrWhiteSpace(counterpartyCountryId))
        {
            conditions.Add("(t.initiator_country_id = @counterparty_country_id OR t.target_country_id = @counterparty_country_id)");
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            conditions.Add("t.status = @status");
        }
        if (!string.IsNullOrWhiteSpace(treatyType))
        {
            conditions.Add("t.treaty_type = @treaty_type");
        }

        var where = conditions.Count == 0 ? string.Empty : $"WHERE {string.Join(" AND ", conditions)}";
        var sql = $"""
            SELECT t.treaty_id,
                   t.initiator_country_id,
                   ic.name,
                   ic.code,
                   t.target_country_id,
                   tc.name,
                   tc.code,
                   t.treaty_type,
                   t.status,
                   t.title,
                   t.terms,
                   t.source_law_id,
                   t.proposed_by_player_id,
                   t.proposed_at,
                   t.ratified_by_player_id,
                   t.ratified_at,
                   t.rejected_by_player_id,
                   t.rejected_at,
                   t.rejection_reason,
                   t.terminated_by_player_id,
                   t.terminated_at,
                   t.termination_reason,
                   t.starts_at,
                   t.expires_at,
                   t.duration_days,
                   t.treasury_amount,
                   t.treasury_transfer_status,
                   t.created_at,
                   t.updated_at
            FROM world.diplomacy_treaties t
            INNER JOIN world.countries ic ON ic.country_id = t.initiator_country_id
            INNER JOIN world.countries tc ON tc.country_id = t.target_country_id
            {where}
            ORDER BY t.updated_at DESC, t.proposed_at DESC
            LIMIT @limit;
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }
        if (!string.IsNullOrWhiteSpace(counterpartyCountryId))
        {
            command.Parameters.AddWithValue("counterparty_country_id", counterpartyCountryId);
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            command.Parameters.AddWithValue("status", status);
        }
        if (!string.IsNullOrWhiteSpace(treatyType))
        {
            command.Parameters.AddWithValue("treaty_type", treatyType);
        }
        command.Parameters.AddWithValue("limit", limit);

        var treaties = new List<TreatyDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            treaties.Add(ReadTreaty(reader));
        }

        return treaties;
    }

    private static async Task<TreatyDto?> ReadTreatyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string treatyId,
        bool forUpdate = false)
    {
        var sql = $"""
            SELECT t.treaty_id,
                   t.initiator_country_id,
                   ic.name,
                   ic.code,
                   t.target_country_id,
                   tc.name,
                   tc.code,
                   t.treaty_type,
                   t.status,
                   t.title,
                   t.terms,
                   t.source_law_id,
                   t.proposed_by_player_id,
                   t.proposed_at,
                   t.ratified_by_player_id,
                   t.ratified_at,
                   t.rejected_by_player_id,
                   t.rejected_at,
                   t.rejection_reason,
                   t.terminated_by_player_id,
                   t.terminated_at,
                   t.termination_reason,
                   t.starts_at,
                   t.expires_at,
                   t.duration_days,
                   t.treasury_amount,
                   t.treasury_transfer_status,
                   t.created_at,
                   t.updated_at
            FROM world.diplomacy_treaties t
            INNER JOIN world.countries ic ON ic.country_id = t.initiator_country_id
            INNER JOIN world.countries tc ON tc.country_id = t.target_country_id
            WHERE t.treaty_id = @treaty_id
            {(forUpdate ? "FOR UPDATE OF t" : string.Empty)};
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("treaty_id", treatyId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTreaty(reader) : null;
    }

    private static async Task<TreatyDto?> ReadTreatyByIdempotencyKeyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT treaty_id
            FROM world.diplomacy_treaties
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        var treatyId = await command.ExecuteScalarAsync() as string;
        return string.IsNullOrWhiteSpace(treatyId)
            ? null
            : await ReadTreatyAsync(connection, transaction, treatyId);
    }

    private static async Task<TreatyDto?> ReadOpenTreatyBetweenAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryAId,
        string countryBId,
        string treatyType,
        string? exceptTreatyId)
    {
        var bilateral = treatyType is not TreatyTypes.Embargo;
        var pairCondition = bilateral
            ? """
              ((initiator_country_id = @country_a_id AND target_country_id = @country_b_id) OR
               (initiator_country_id = @country_b_id AND target_country_id = @country_a_id))
              """
            : "initiator_country_id = @country_a_id AND target_country_id = @country_b_id";
        var exceptCondition = string.IsNullOrWhiteSpace(exceptTreatyId)
            ? string.Empty
            : "AND treaty_id <> @except_treaty_id";
        var sql = $"""
            SELECT treaty_id
            FROM world.diplomacy_treaties
            WHERE treaty_type = @treaty_type
              AND status IN ('proposed', 'active')
              AND {pairCondition}
              {exceptCondition}
            ORDER BY updated_at DESC
            LIMIT 1;
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("country_a_id", countryAId);
        command.Parameters.AddWithValue("country_b_id", countryBId);
        command.Parameters.AddWithValue("treaty_type", treatyType);
        if (!string.IsNullOrWhiteSpace(exceptTreatyId))
        {
            command.Parameters.AddWithValue("except_treaty_id", exceptTreatyId);
        }

        var treatyId = await command.ExecuteScalarAsync() as string;
        return string.IsNullOrWhiteSpace(treatyId)
            ? null
            : await ReadTreatyAsync(connection, transaction, treatyId);
    }

    private static async Task<List<TreatyDto>> ReadActiveTreatiesBetweenAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryAId,
        string countryBId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT treaty_id
            FROM world.diplomacy_treaties
            WHERE status = 'active'
              AND (expires_at IS NULL OR expires_at > @now)
              AND (
                (initiator_country_id = @country_a_id AND target_country_id = @country_b_id) OR
                (initiator_country_id = @country_b_id AND target_country_id = @country_a_id)
              )
            ORDER BY updated_at DESC;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_a_id", countryAId);
        command.Parameters.AddWithValue("country_b_id", countryBId);
        command.Parameters.AddWithValue("now", DateTimeOffset.UtcNow);

        var treatyIds = new List<string>();
        await using (var reader = await command.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                treatyIds.Add(reader.GetString(0));
            }
        }

        var treaties = new List<TreatyDto>();
        foreach (var treatyId in treatyIds)
        {
            var treaty = await ReadTreatyAsync(connection, transaction, treatyId);
            if (treaty is not null)
            {
                treaties.Add(treaty);
            }
        }

        return treaties;
    }

    private static async Task<DiplomacyWarBlockDto?> ReadActiveDiplomaticWarBlockAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string attackerCountryId,
        string defenderCountryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT treaty_id, treaty_type, title, expires_at
            FROM world.diplomacy_treaties
            WHERE status = 'active'
              AND treaty_type IN ('peace', 'alliance')
              AND (expires_at IS NULL OR expires_at > @now)
              AND (
                (initiator_country_id = @attacker_country_id AND target_country_id = @defender_country_id) OR
                (initiator_country_id = @defender_country_id AND target_country_id = @attacker_country_id)
              )
            ORDER BY treaty_type, updated_at DESC
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("attacker_country_id", attackerCountryId);
        command.Parameters.AddWithValue("defender_country_id", defenderCountryId);
        command.Parameters.AddWithValue("now", DateTimeOffset.UtcNow);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new DiplomacyWarBlockDto(
                reader.GetString(0),
                reader.GetString(1),
                reader.GetString(2),
                ReadNullableDateTimeOffset(reader, 3))
            : null;
    }

    private static async Task<List<TreatyEventDto>> ReadTreatyEventsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string treatyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT event_id, treaty_id, actor_player_id, action, message, created_at
            FROM world.diplomacy_treaty_events
            WHERE treaty_id = @treaty_id
            ORDER BY created_at DESC;
            """, connection, transaction);
        command.Parameters.AddWithValue("treaty_id", treatyId);
        var events = new List<TreatyEventDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            events.Add(new TreatyEventDto(
                reader.GetString(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3),
                reader.GetString(4),
                reader.GetFieldValue<DateTimeOffset>(5)));
        }

        return events;
    }

    private static async Task InsertTreatyEventAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string treatyId,
        string actorPlayerId,
        string action,
        string message,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.diplomacy_treaty_events (
                event_id, treaty_id, actor_player_id, action, message, created_at
            )
            VALUES (
                @event_id, @treaty_id, @actor_player_id, @action, @message, @created_at
            )
            ON CONFLICT (event_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", $"treaty-event-{treatyId}-{Guid.NewGuid():N}");
        command.Parameters.AddWithValue("treaty_id", treatyId);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId);
        command.Parameters.AddWithValue("action", action);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<bool> CountryExistsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM world.countries
            WHERE country_id = @country_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task<bool> LawAllowsTreatyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string lawId,
        string countryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM world.laws
            WHERE law_id = @law_id
              AND country_id = @country_id
              AND status = 'active';
            """, connection, transaction);
        command.Parameters.AddWithValue("law_id", lawId);
        command.Parameters.AddWithValue("country_id", countryId);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task<TreatyTreasuryTransferResult> ApplyTreatyTreasuryTransferAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        TreatyDto treaty,
        string actorPlayerId,
        string idempotencyKey,
        DateTimeOffset now)
    {
        await using (var treasury = new NpgsqlCommand("""
            SELECT treasury
            FROM world.countries
            WHERE country_id = @country_id
            FOR UPDATE;
            """, connection, transaction))
        {
            treasury.Parameters.AddWithValue("country_id", treaty.InitiatorCountryId);
            var currentTreasury = Convert.ToInt32(await treasury.ExecuteScalarAsync() ?? 0);
            if (currentTreasury < treaty.TreasuryAmount)
            {
                return new TreatyTreasuryTransferResult(false, "Initiating country treasury does not have enough gold for treaty transfer.");
            }
        }

        await using (var debit = new NpgsqlCommand("""
            UPDATE world.countries
            SET treasury = treasury - @amount,
                updated_at = @updated_at
            WHERE country_id = @country_id;
            """, connection, transaction))
        {
            debit.Parameters.AddWithValue("country_id", treaty.InitiatorCountryId);
            debit.Parameters.AddWithValue("amount", treaty.TreasuryAmount);
            debit.Parameters.AddWithValue("updated_at", now);
            await debit.ExecuteNonQueryAsync();
        }

        await using (var credit = new NpgsqlCommand("""
            UPDATE world.countries
            SET treasury = treasury + @amount,
                updated_at = @updated_at
            WHERE country_id = @country_id;
            """, connection, transaction))
        {
            credit.Parameters.AddWithValue("country_id", treaty.TargetCountryId);
            credit.Parameters.AddWithValue("amount", treaty.TreasuryAmount);
            credit.Parameters.AddWithValue("updated_at", now);
            await credit.ExecuteNonQueryAsync();
        }

        await InsertDiplomacyTreasuryLedgerAsync(
            connection,
            transaction,
            treaty.InitiatorCountryId,
            "diplomacy_treaty_transfer_debit",
            actorPlayerId,
            treaty.TargetCountryId,
            -treaty.TreasuryAmount,
            $"Treaty transfer for {treaty.Title}.",
            $"diplomacy:{treaty.TreatyId}:transfer:{CleanKey(idempotencyKey)}:debit",
            now);
        await InsertDiplomacyTreasuryLedgerAsync(
            connection,
            transaction,
            treaty.TargetCountryId,
            "diplomacy_treaty_transfer_credit",
            actorPlayerId,
            treaty.InitiatorCountryId,
            treaty.TreasuryAmount,
            $"Treaty transfer from {treaty.InitiatorCountryName} for {treaty.Title}.",
            $"diplomacy:{treaty.TreatyId}:transfer:{CleanKey(idempotencyKey)}:credit",
            now);

        return new TreatyTreasuryTransferResult(true, "Treaty treasury transfer completed.");
    }

    private static async Task InsertDiplomacyTreasuryLedgerAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId,
        string entryType,
        string sourcePlayerId,
        string counterpartyId,
        int goldDelta,
        string description,
        string idempotencyKey,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.country_treasury_ledger (
                ledger_id, country_id, entry_type, source_player_id, counterparty_player_id,
                gold_delta, gross_amount, tax_rate, description, idempotency_key, created_at
            )
            VALUES (
                @ledger_id, @country_id, @entry_type, @source_player_id, @counterparty_player_id,
                @gold_delta, @gross_amount, 0, @description, @idempotency_key, @created_at
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("ledger_id", $"diplomacy-ledger-{Guid.NewGuid():N}");
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("entry_type", entryType);
        command.Parameters.AddWithValue("source_player_id", sourcePlayerId);
        command.Parameters.AddWithValue("counterparty_player_id", counterpartyId);
        command.Parameters.AddWithValue("gold_delta", goldDelta);
        command.Parameters.AddWithValue("gross_amount", Math.Abs(goldDelta));
        command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static TreatyDto ReadTreaty(NpgsqlDataReader reader)
    {
        return new TreatyDto(
            TreatyId: reader.GetString(0),
            InitiatorCountryId: reader.GetString(1),
            InitiatorCountryName: reader.GetString(2),
            InitiatorCountryCode: reader.GetString(3),
            TargetCountryId: reader.GetString(4),
            TargetCountryName: reader.GetString(5),
            TargetCountryCode: reader.GetString(6),
            TreatyType: reader.GetString(7),
            Status: reader.GetString(8),
            Title: reader.GetString(9),
            Terms: reader.GetString(10),
            SourceLawId: ReadNullableString(reader, 11),
            ProposedByPlayerId: reader.GetString(12),
            ProposedAt: reader.GetFieldValue<DateTimeOffset>(13),
            RatifiedByPlayerId: ReadNullableString(reader, 14),
            RatifiedAt: ReadNullableDateTimeOffset(reader, 15),
            RejectedByPlayerId: ReadNullableString(reader, 16),
            RejectedAt: ReadNullableDateTimeOffset(reader, 17),
            RejectionReason: reader.GetString(18),
            TerminatedByPlayerId: ReadNullableString(reader, 19),
            TerminatedAt: ReadNullableDateTimeOffset(reader, 20),
            TerminationReason: reader.GetString(21),
            StartsAt: ReadNullableDateTimeOffset(reader, 22),
            ExpiresAt: ReadNullableDateTimeOffset(reader, 23),
            DurationDays: reader.GetInt32(24),
            TreasuryAmount: reader.GetInt32(25),
            TreasuryTransferStatus: reader.GetString(26),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(27),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(28));
    }

    private static List<DiplomaticRelationDto> BuildDiplomaticRelations(string countryId, IEnumerable<TreatyDto> activeTreaties)
    {
        var relations = new List<DiplomaticRelationDto>();
        foreach (var treaty in activeTreaties)
        {
            var isInitiator = string.Equals(countryId, treaty.InitiatorCountryId, StringComparison.Ordinal);
            var counterpartyId = isInitiator ? treaty.TargetCountryId : treaty.InitiatorCountryId;
            var counterpartyName = isInitiator ? treaty.TargetCountryName : treaty.InitiatorCountryName;
            var counterpartyCode = isInitiator ? treaty.TargetCountryCode : treaty.InitiatorCountryCode;
            var relationshipType = treaty.TreatyType switch
            {
                TreatyTypes.Alliance => "allied",
                TreatyTypes.Embargo => isInitiator ? "embargoing" : "embargoed",
                TreatyTypes.Peace => "peace",
                TreatyTypes.MilitaryAccess => "military_access",
                TreatyTypes.TradeAgreement => "trade_partner",
                _ => treaty.TreatyType
            };
            relations.Add(new DiplomaticRelationDto(
                RelationId: $"relation-{countryId}-{counterpartyId}-{treaty.TreatyId}",
                CountryId: countryId,
                CounterpartyCountryId: counterpartyId,
                CounterpartyCountryName: counterpartyName,
                CounterpartyCountryCode: counterpartyCode,
                RelationshipType: relationshipType,
                Direction: isInitiator ? "outbound" : "inbound",
                SourceTreatyId: treaty.TreatyId,
                ActiveUntil: treaty.ExpiresAt));
        }

        return relations;
    }

    private static string TreatyDisplayName(string treatyType)
    {
        return treatyType.Replace('_', ' ');
    }

    private static string CleanText(string? value, int maxLength, string defaultValue = "")
    {
        var cleaned = string.IsNullOrWhiteSpace(value) ? defaultValue : value.Trim();
        return cleaned.Length <= maxLength ? cleaned : cleaned[..maxLength];
    }

    private static string CleanKey(string value)
    {
        return value.Trim().ToLowerInvariant();
    }

    private static string? ReadNullableString(NpgsqlDataReader reader, int ordinal)
    {
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    private static DateTimeOffset? ReadNullableDateTimeOffset(NpgsqlDataReader reader, int ordinal)
    {
        return reader.IsDBNull(ordinal) ? null : reader.GetFieldValue<DateTimeOffset>(ordinal);
    }
}

internal static class TreatyTypes
{
    public const string Alliance = "alliance";
    public const string Embargo = "embargo";
    public const string Peace = "peace";
    public const string MilitaryAccess = "military_access";
    public const string TradeAgreement = "trade_agreement";
}

internal static class TreatyStatuses
{
    public const string Proposed = "proposed";
    public const string Active = "active";
    public const string Rejected = "rejected";
    public const string Terminated = "terminated";
    public const string Expired = "expired";
}

internal sealed record TreatyProposalRequest(
    string? InitiatorCountryId,
    string? TargetCountryId,
    string? TreatyType,
    string? Title,
    string? Terms,
    int? DurationDays,
    int? TreasuryAmount,
    string? SourceLawId,
    string? IdempotencyKey);

internal sealed record TreatyRatificationRequest(string? IdempotencyKey);

internal sealed record TreatyRejectionRequest(string? Reason, string? IdempotencyKey);

internal sealed record TreatyTerminationRequest(string? Reason, string? IdempotencyKey);

internal sealed record PlayerDiplomacyResponse(
    string PlayerId,
    PlayerCitizenshipDto? Citizenship,
    DiplomacyAuthorizationDto Authorization,
    TreatyDto[] ActiveTreaties,
    TreatyDto[] PendingTreaties,
    DiplomaticRelationDto[] Relationships,
    DateTimeOffset UpdatedAt);

internal sealed record CountryDiplomacyResponse(
    string CountryId,
    DiplomacyAuthorizationDto Authorization,
    TreatyDto[] ActiveTreaties,
    TreatyDto[] PendingTreaties,
    DiplomaticRelationDto[] Relationships,
    DateTimeOffset UpdatedAt);

internal sealed record TreatyListResponse(TreatyDto[] Treaties, DateTimeOffset UpdatedAt);

internal sealed record TreatyDetailsResponse(
    TreatyDto Treaty,
    TreatyEventDto[] Events,
    DateTimeOffset UpdatedAt);

internal sealed record DiplomacyAuthorizationDto(
    bool CanPropose,
    bool CanRatify,
    bool CanTerminate,
    string? Role,
    string Message)
{
    public static DiplomacyAuthorizationDto Denied(string message)
    {
        return new DiplomacyAuthorizationDto(false, false, false, null, message);
    }
}

internal sealed record TreatyDto(
    string TreatyId,
    string InitiatorCountryId,
    string InitiatorCountryName,
    string InitiatorCountryCode,
    string TargetCountryId,
    string TargetCountryName,
    string TargetCountryCode,
    string TreatyType,
    string Status,
    string Title,
    string Terms,
    string? SourceLawId,
    string ProposedByPlayerId,
    DateTimeOffset ProposedAt,
    string? RatifiedByPlayerId,
    DateTimeOffset? RatifiedAt,
    string? RejectedByPlayerId,
    DateTimeOffset? RejectedAt,
    string RejectionReason,
    string? TerminatedByPlayerId,
    DateTimeOffset? TerminatedAt,
    string TerminationReason,
    DateTimeOffset? StartsAt,
    DateTimeOffset? ExpiresAt,
    int DurationDays,
    int TreasuryAmount,
    string TreasuryTransferStatus,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record TreatyEventDto(
    string EventId,
    string TreatyId,
    string ActorPlayerId,
    string Action,
    string Message,
    DateTimeOffset CreatedAt);

internal sealed record DiplomaticRelationDto(
    string RelationId,
    string CountryId,
    string CounterpartyCountryId,
    string CounterpartyCountryName,
    string CounterpartyCountryCode,
    string RelationshipType,
    string Direction,
    string SourceTreatyId,
    DateTimeOffset? ActiveUntil);

internal sealed record DiplomacyMutationResult(
    bool Completed,
    string Message,
    TreatyDto? Treaty,
    DiplomacyAuthorizationDto? Authorization,
    int StatusCode,
    DateTimeOffset UpdatedAt)
{
    public static DiplomacyMutationResult Failed(
        string message,
        int statusCode,
        TreatyDto? treaty,
        DiplomacyAuthorizationDto? authorization)
    {
        return new DiplomacyMutationResult(false, message, treaty, authorization, statusCode, DateTimeOffset.UtcNow);
    }
}

internal sealed record DiplomacyRelationshipCheckResponse(
    string CountryId,
    string CounterpartyCountryId,
    bool HasActiveEmbargo,
    bool HasActivePeace,
    bool HasActiveAlliance,
    bool HasMilitaryAccess,
    bool HasTradeAgreement,
    TreatyDto[] Treaties,
    DateTimeOffset UpdatedAt);

internal sealed record DiplomacyWarBlockDto(
    string TreatyId,
    string TreatyType,
    string Title,
    DateTimeOffset? ExpiresAt);

internal sealed record TreatyTreasuryTransferResult(bool Completed, string Message);

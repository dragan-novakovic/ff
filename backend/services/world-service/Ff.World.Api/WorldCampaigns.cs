using Npgsql;

internal static class CampaignEndpoints
{
    private const int DefaultLeaderboardLimit = 25;
    private const int MaxLeaderboardLimit = 100;

    public static void MapCampaignEndpoints(this WebApplication app)
    {
        app.MapGet("/campaigns", async (
            string? countryId,
            string? status,
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

            return Results.Ok(await world.GetCampaignsAsync(countryId, status, ClampLimit(limit)));
        }).WithName("GetCampaigns");

        app.MapGet("/campaigns/{campaignId}", async (
            string campaignId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var details = await world.GetCampaignDetailsAsync(campaignId);
            return details is null
                ? Results.NotFound(new ErrorResponse("Campaign was not found."))
                : Results.Ok(details);
        }).WithName("GetCampaign");

        app.MapPost("/players/{playerId}/campaigns", async (
            string playerId,
            CampaignCreateRequest createRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateCreate(createRequest);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.CreateCampaignAsync(access.PlayerId!, createRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Country was not found."))
                : CampaignMutationResult(result);
        }).WithName("CreateCampaign");

        app.MapGet("/campaigns/{campaignId}/phases", async (
            string campaignId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var response = await world.GetCampaignPhasesAsync(campaignId);
            return response is null
                ? Results.NotFound(new ErrorResponse("Campaign was not found."))
                : Results.Ok(response);
        }).WithName("GetCampaignPhases");

        app.MapPost("/players/{playerId}/campaigns/{campaignId}/phases/{phaseId}/complete", async (
            string playerId,
            string campaignId,
            string phaseId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.CompleteBattlePhaseAsync(access.PlayerId!, campaignId, phaseId);
            return result is null
                ? Results.NotFound(new ErrorResponse("Campaign phase was not found."))
                : CampaignMutationResult(result);
        }).WithName("CompleteCampaignPhase");

        app.MapPost("/players/{playerId}/campaigns/{campaignId}/rewards/claim", async (
            string playerId,
            string campaignId,
            CampaignRewardClaimRequest claimRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(claimRequest.IdempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Campaign reward claim idempotency key is required."));
            }

            var result = await world.ClaimCampaignRewardAsync(access.PlayerId!, campaignId, claimRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Campaign was not found."))
                : CampaignRewardResult(result);
        }).WithName("ClaimCampaignReward");

        app.MapGet("/leaderboards/countries", async (
            string? campaignId,
            string? battleId,
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

            return Results.Ok(await world.GetCountryBattleLeaderboardAsync(
                campaignId,
                battleId,
                ClampLimit(limit)));
        }).WithName("GetCountryBattleLeaderboard");

        app.MapGet("/campaigns/{campaignId}/leaderboards/countries", async (
            string campaignId,
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

            return Results.Ok(await world.GetCountryBattleLeaderboardAsync(
                campaignId,
                battleId: null,
                ClampLimit(limit)));
        }).WithName("GetCampaignCountryLeaderboard");

        app.MapGet("/campaigns/{campaignId}/leaderboards/units", async (
            string campaignId,
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

            return Results.Ok(await world.GetCampaignUnitLeaderboardAsync(campaignId, ClampLimit(limit)));
        }).WithName("GetCampaignUnitLeaderboard");

        app.MapGet("/military-units/{unitId}/divisions", async (
            string unitId,
            string? campaignId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var response = await world.GetUnitDivisionsAsync(unitId, campaignId);
            return response is null
                ? Results.NotFound(new ErrorResponse("Military unit was not found."))
                : Results.Ok(response);
        }).WithName("GetUnitDivisions");

        app.MapPost("/players/{playerId}/military-units/{unitId}/divisions", async (
            string playerId,
            string unitId,
            UnitDivisionCreateRequest createRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateDivision(createRequest);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.CreateUnitDivisionAsync(access.PlayerId!, unitId, createRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit or campaign was not found."))
                : UnitDivisionResult(result);
        }).WithName("CreateUnitDivision");

        app.MapGet("/military-units/{unitId}/deployment-orders", async (
            string unitId,
            string? campaignId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var response = await world.GetDeploymentOrdersAsync(unitId, campaignId);
            return response is null
                ? Results.NotFound(new ErrorResponse("Military unit was not found."))
                : Results.Ok(response);
        }).WithName("GetDeploymentOrders");

        app.MapPost("/players/{playerId}/military-units/{unitId}/deployment-orders", async (
            string playerId,
            string unitId,
            DeploymentOrderCreateRequest orderRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateDeploymentOrder(orderRequest);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.IssueDeploymentOrderAsync(access.PlayerId!, unitId, orderRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit, campaign, division, or target battle was not found."))
                : DeploymentOrderResult(result);
        }).WithName("IssueDeploymentOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/deployment-orders/{orderId}/execute", async (
            string playerId,
            string unitId,
            string orderId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.UpdateDeploymentOrderStatusAsync(access.PlayerId!, unitId, orderId, "executed");
            return result is null
                ? Results.NotFound(new ErrorResponse("Deployment order was not found."))
                : DeploymentOrderResult(result);
        }).WithName("ExecuteDeploymentOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/deployment-orders/{orderId}/cancel", async (
            string playerId,
            string unitId,
            string orderId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.UpdateDeploymentOrderStatusAsync(access.PlayerId!, unitId, orderId, "cancelled");
            return result is null
                ? Results.NotFound(new ErrorResponse("Deployment order was not found."))
                : DeploymentOrderResult(result);
        }).WithName("CancelDeploymentOrder");
    }

    private static IResult CampaignMutationResult(CampaignMutationResult result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static IResult CampaignRewardResult(CampaignRewardClaimResult result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static IResult UnitDivisionResult(UnitDivisionMutationResult result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static IResult DeploymentOrderResult(DeploymentOrderMutationResult result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static string? ValidateCreate(CampaignCreateRequest request)
    {
        var name = request.Name?.Trim() ?? string.Empty;
        if (name.Length is < 4 or > 80)
        {
            return "Campaign name must be between 4 and 80 characters.";
        }

        if (string.IsNullOrWhiteSpace(request.CountryId))
        {
            return "Campaign country is required.";
        }

        if ((request.Description?.Trim().Length ?? 0) > 500)
        {
            return "Campaign description cannot exceed 500 characters.";
        }

        if (request.ObjectiveScore is not null and <= 0)
        {
            return "Campaign objective score must be positive.";
        }

        if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            return "Campaign creation idempotency key is required.";
        }

        return null;
    }

    private static string? ValidateDivision(UnitDivisionCreateRequest request)
    {
        var name = request.Name?.Trim() ?? string.Empty;
        if (name.Length is < 3 or > 64)
        {
            return "Division name must be between 3 and 64 characters.";
        }

        if (string.IsNullOrWhiteSpace(request.CampaignId))
        {
            return "Division campaign is required.";
        }

        if (request.MemberCount is < 1 or > 250)
        {
            return "Division member count must be between 1 and 250.";
        }

        if (request.AssignedStrength is < 1 or > 10_000)
        {
            return "Division assigned strength must be between 1 and 10000.";
        }

        if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            return "Division idempotency key is required.";
        }

        return null;
    }

    private static string? ValidateDeploymentOrder(DeploymentOrderCreateRequest request)
    {
        var title = request.Title?.Trim() ?? string.Empty;
        if (title.Length is < 3 or > 100)
        {
            return "Deployment order title must be between 3 and 100 characters.";
        }

        if ((request.Description?.Trim().Length ?? 0) > 500)
        {
            return "Deployment order description cannot exceed 500 characters.";
        }

        if (request.TroopCommitment is < 1 or > 10_000)
        {
            return "Troop commitment must be between 1 and 10000.";
        }

        if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            return "Deployment order idempotency key is required.";
        }

        return null;
    }

    private static int ClampLimit(int? limit)
    {
        return Math.Clamp(limit ?? DefaultLeaderboardLimit, 1, MaxLeaderboardLimit);
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
                new ErrorResponse("You cannot manage another player's war campaign."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }
}

internal sealed partial class WorldStore
{
    public async Task InitializeCampaignSchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.campaigns (
                campaign_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                name text NOT NULL,
                description text NOT NULL,
                campaign_type text NOT NULL,
                status text NOT NULL,
                objective_score integer NOT NULL,
                current_score integer NOT NULL DEFAULT 0,
                reward_gold integer NOT NULL,
                reward_experience integer NOT NULL,
                reward_prestige integer NOT NULL,
                created_by_player_id text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                started_at timestamptz NOT NULL,
                ends_at timestamptz NULL,
                concluded_at timestamptz NULL,
                winner_country_id text NULL REFERENCES world.countries(country_id),
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_campaigns_country_status
                ON world.campaigns (country_id, status, updated_at DESC);

            ALTER TABLE world.battles
                ADD COLUMN IF NOT EXISTS campaign_id text NULL;

            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint
                    WHERE conname = 'fk_world_battles_campaign'
                ) THEN
                    ALTER TABLE world.battles
                        ADD CONSTRAINT fk_world_battles_campaign
                        FOREIGN KEY (campaign_id)
                        REFERENCES world.campaigns(campaign_id)
                        ON DELETE SET NULL;
                END IF;
            END $$;

            CREATE INDEX IF NOT EXISTS ix_world_battles_campaign_id
                ON world.battles (campaign_id);

            CREATE TABLE IF NOT EXISTS world.campaign_battles (
                campaign_id text NOT NULL REFERENCES world.campaigns(campaign_id) ON DELETE CASCADE,
                battle_id text NOT NULL REFERENCES world.battles(battle_id) ON DELETE CASCADE,
                created_at timestamptz NOT NULL,
                PRIMARY KEY (campaign_id, battle_id)
            );

            CREATE TABLE IF NOT EXISTS world.battle_phases (
                phase_id text PRIMARY KEY,
                campaign_id text NOT NULL REFERENCES world.campaigns(campaign_id) ON DELETE CASCADE,
                battle_id text NOT NULL REFERENCES world.battles(battle_id) ON DELETE CASCADE,
                phase_number integer NOT NULL,
                name text NOT NULL,
                objectives text NOT NULL,
                target_damage integer NOT NULL,
                attacker_damage integer NOT NULL DEFAULT 0,
                defender_damage integer NOT NULL DEFAULT 0,
                status text NOT NULL,
                started_at timestamptz NOT NULL,
                completed_at timestamptz NULL,
                updated_at timestamptz NOT NULL,
                UNIQUE (battle_id, phase_number)
            );

            CREATE INDEX IF NOT EXISTS ix_world_battle_phases_campaign_status
                ON world.battle_phases (campaign_id, status, phase_number);

            CREATE TABLE IF NOT EXISTS world.unit_divisions (
                division_id text PRIMARY KEY,
                unit_id text NOT NULL REFERENCES world.military_units(unit_id) ON DELETE CASCADE,
                campaign_id text NOT NULL REFERENCES world.campaigns(campaign_id) ON DELETE CASCADE,
                name text NOT NULL,
                division_role text NOT NULL,
                status text NOT NULL,
                member_count integer NOT NULL,
                assigned_strength integer NOT NULL,
                created_by_player_id text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_unit_divisions_unit_campaign
                ON world.unit_divisions (unit_id, campaign_id, status);

            CREATE TABLE IF NOT EXISTS world.deployment_orders (
                deployment_order_id text PRIMARY KEY,
                unit_id text NOT NULL REFERENCES world.military_units(unit_id) ON DELETE CASCADE,
                division_id text NULL REFERENCES world.unit_divisions(division_id) ON DELETE SET NULL,
                campaign_id text NULL REFERENCES world.campaigns(campaign_id) ON DELETE SET NULL,
                target_battle_id text NULL REFERENCES world.battles(battle_id) ON DELETE SET NULL,
                issued_by_player_id text NOT NULL,
                order_type text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                troop_commitment integer NOT NULL,
                status text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                executed_at timestamptz NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_deployment_orders_unit_status
                ON world.deployment_orders (unit_id, status, updated_at DESC);

            CREATE TABLE IF NOT EXISTS world.campaign_reward_claims (
                claim_id text PRIMARY KEY,
                campaign_id text NOT NULL REFERENCES world.campaigns(campaign_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                gold_reward integer NOT NULL,
                experience_reward integer NOT NULL,
                prestige_reward integer NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                message text NOT NULL,
                claimed_at timestamptz NOT NULL,
                UNIQUE (campaign_id, player_id)
            );
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task SeedCampaignsAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var unassigned = new List<string>();

        await using (var command = new NpgsqlCommand("""
            SELECT battle_id
            FROM world.battles
            WHERE campaign_id IS NULL
            ORDER BY started_at ASC;
            """, connection, transaction))
        {
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                unassigned.Add(reader.GetString(0));
            }
        }

        foreach (var battleId in unassigned)
        {
            var battle = await ReadBattleAsync(connection, transaction, battleId);
            if (battle is null)
            {
                continue;
            }

            var campaignId = $"campaign-{battle.BattleId}";
            var winnerCountryId = string.Equals(battle.Status, "resolved", StringComparison.OrdinalIgnoreCase)
                ? battle.WinnerCountryId
                : null;
            await InsertCampaignAsync(
                connection,
                transaction,
                new CampaignInsert(
                    CampaignId: campaignId,
                    CountryId: battle.AttackerCountryId,
                    Name: $"{battle.RegionName} Campaign",
                    Description: $"Campaign depth for {battle.Name}.",
                    CampaignType: battle.BattleType,
                    Status: string.Equals(battle.Status, "resolved", StringComparison.OrdinalIgnoreCase) ? "completed" : "active",
                    ObjectiveScore: Math.Max(battle.TargetScore, battle.AttackerScore + battle.DefenderScore),
                    CurrentScore: Math.Min(Math.Max(battle.TargetScore, 1), battle.AttackerScore + battle.DefenderScore),
                    RewardGold: CampaignRewardGold(battle.TargetScore),
                    RewardExperience: CampaignRewardExperience(battle.TargetScore),
                    RewardPrestige: CampaignRewardPrestige(battle.TargetScore),
                    CreatedByPlayerId: "system",
                    IdempotencyKey: $"seed:{campaignId}",
                    StartedAt: battle.StartedAt,
                    EndsAt: battle.EndsAt,
                    ConcludedAt: battle.ResolvedAt,
                    WinnerCountryId: winnerCountryId,
                    CreatedAt: now,
                    UpdatedAt: now));
            await AttachBattleToCampaignAsync(connection, transaction, campaignId, battle.BattleId, now);
            await EnsureBattlePhaseAsync(
                connection,
                transaction,
                campaignId,
                battle.BattleId,
                1,
                "Opening front",
                $"Reach {battle.TargetScore} total damage in {battle.RegionName}.",
                Math.Max(100, battle.TargetScore),
                battle.AttackerScore,
                battle.DefenderScore,
                string.Equals(battle.Status, "resolved", StringComparison.OrdinalIgnoreCase) ? "completed" : "active",
                battle.StartedAt,
                battle.ResolvedAt,
                now);
        }

        await transaction.CommitAsync();
    }

    public async Task<CampaignListResponse> GetCampaignsAsync(string? countryId, string? status, int limit)
    {
        await ResolveDueBattlesAsync();

        var normalizedCountryId = string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId);
        var normalizedStatus = NormalizeCampaignStatus(status);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var campaigns = await ReadCampaignsAsync(connection, null, normalizedCountryId, normalizedStatus, limit);
        return new CampaignListResponse(campaigns.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<CampaignDetailsResponse?> GetCampaignDetailsAsync(string campaignId)
    {
        await ResolveDueBattlesAsync();

        var normalizedCampaignId = NormalizeId(campaignId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var campaign = await ReadCampaignAsync(connection, null, normalizedCampaignId);
        if (campaign is null)
        {
            return null;
        }

        var battles = await ReadCampaignBattlesAsync(connection, null, normalizedCampaignId);
        var phases = await ReadBattlePhasesAsync(connection, null, battleId: null, normalizedCampaignId);
        var countryLeaderboard = await ReadCountryBattleLeaderboardAsync(
            connection,
            null,
            normalizedCampaignId,
            battleId: null,
            limit: 10);
        var unitLeaderboard = await ReadCampaignUnitLeaderboardAsync(
            connection,
            null,
            normalizedCampaignId,
            limit: 10);
        return new CampaignDetailsResponse(
            campaign,
            battles.ToArray(),
            phases.ToArray(),
            new CountryBattleLeaderboardResponse(countryLeaderboard.ToArray(), DateTimeOffset.UtcNow),
            new CampaignUnitLeaderboardResponse(unitLeaderboard.ToArray(), DateTimeOffset.UtcNow),
            DateTimeOffset.UtcNow);
    }

    public async Task<BattlePhaseListResponse?> GetCampaignPhasesAsync(string campaignId)
    {
        var normalizedCampaignId = NormalizeId(campaignId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (await ReadCampaignAsync(connection, null, normalizedCampaignId) is null)
        {
            return null;
        }

        var phases = await ReadBattlePhasesAsync(connection, null, battleId: null, normalizedCampaignId);
        return new BattlePhaseListResponse(normalizedCampaignId, phases.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<CampaignMutationResult?> CreateCampaignAsync(string playerId, CampaignCreateRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedCountryId = NormalizeId(request.CountryId!);
        if (!await CountryExistsAsync(normalizedCountryId))
        {
            return null;
        }

        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey!);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existing = await ReadCampaignByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (existing is not null)
        {
            await transaction.CommitAsync();
            return new CampaignMutationResult(true, "Campaign creation was already recorded.", existing, null, DateTimeOffset.UtcNow);
        }

        var authorization = await DetermineCongressAuthorizationAsync(
            connection,
            transaction,
            normalizedCountryId,
            normalizedPlayerId);
        if (!authorization.CanCreateProposal)
        {
            await transaction.CommitAsync();
            return new CampaignMutationResult(false, authorization.Message, null, null, DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        var objective = Math.Clamp(request.ObjectiveScore ?? 1_000, 100, 100_000);
        var campaignId = $"campaign-{NormalizeCampaignType(request.CampaignType)}-{normalizedCountryId}-{now:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N")[..8]}";
        await InsertCampaignAsync(
            connection,
            transaction,
            new CampaignInsert(
                CampaignId: campaignId,
                CountryId: normalizedCountryId,
                Name: request.Name!.Trim(),
                Description: request.Description?.Trim() ?? string.Empty,
                CampaignType: NormalizeCampaignType(request.CampaignType),
                Status: "active",
                ObjectiveScore: objective,
                CurrentScore: 0,
                RewardGold: CampaignRewardGold(objective),
                RewardExperience: CampaignRewardExperience(objective),
                RewardPrestige: CampaignRewardPrestige(objective),
                CreatedByPlayerId: normalizedPlayerId,
                IdempotencyKey: idempotencyKey,
                StartedAt: now,
                EndsAt: request.EndsAt,
                ConcludedAt: null,
                WinnerCountryId: null,
                CreatedAt: now,
                UpdatedAt: now));

        var campaign = await ReadCampaignAsync(connection, transaction, campaignId);
        await transaction.CommitAsync();
        return new CampaignMutationResult(true, $"Campaign {campaign!.Name} is now active.", campaign, null, now);
    }

    public async Task<CampaignMutationResult?> CompleteBattlePhaseAsync(string playerId, string campaignId, string phaseId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedCampaignId = NormalizeId(campaignId);
        var normalizedPhaseId = NormalizeId(phaseId);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var campaign = await ReadCampaignAsync(connection, transaction, normalizedCampaignId, forUpdate: true);
        var phase = await ReadBattlePhaseAsync(connection, transaction, normalizedPhaseId, forUpdate: true);
        if (campaign is null || phase is null || !string.Equals(phase.CampaignId, normalizedCampaignId, StringComparison.Ordinal))
        {
            await transaction.RollbackAsync();
            return null;
        }

        var authorization = await DetermineCongressAuthorizationAsync(
            connection,
            transaction,
            campaign.CountryId,
            normalizedPlayerId);
        if (!authorization.CanResolve)
        {
            await transaction.CommitAsync();
            return new CampaignMutationResult(false, authorization.Message, campaign, phase, DateTimeOffset.UtcNow);
        }

        if (!string.Equals(phase.Status, "completed", StringComparison.OrdinalIgnoreCase))
        {
            await UpdatePhaseStatusAsync(connection, transaction, normalizedPhaseId, "completed", now, now);
        }

        await CompleteCampaignIfReadyAsync(connection, transaction, normalizedCampaignId, now);
        campaign = await ReadCampaignAsync(connection, transaction, normalizedCampaignId);
        phase = await ReadBattlePhaseAsync(connection, transaction, normalizedPhaseId);
        await transaction.CommitAsync();

        return new CampaignMutationResult(
            true,
            $"{phase!.Name} completed for {campaign!.Name}.",
            campaign,
            phase,
            now);
    }

    public async Task<CampaignRewardClaimResult?> ClaimCampaignRewardAsync(
        string playerId,
        string campaignId,
        CampaignRewardClaimRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedCampaignId = NormalizeId(campaignId);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey!);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existing = await ReadCampaignRewardClaimByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (existing is not null)
        {
            var existingCampaign = await ReadCampaignAsync(connection, transaction, existing.CampaignId);
            await transaction.CommitAsync();
            return new CampaignRewardClaimResult(true, "Campaign reward claim was already recorded.", existingCampaign, existing, DateTimeOffset.UtcNow);
        }

        var campaign = await ReadCampaignAsync(connection, transaction, normalizedCampaignId);
        if (campaign is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        if (!string.Equals(campaign.Status, "completed", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new CampaignRewardClaimResult(false, "Campaign rewards can be claimed after the campaign is completed.", campaign, null, DateTimeOffset.UtcNow);
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(citizenship.CountryId, campaign.CountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new CampaignRewardClaimResult(false, $"Only active citizens of {campaign.CountryName} can claim this campaign reward.", campaign, null, DateTimeOffset.UtcNow);
        }

        var existingForPlayer = await ReadCampaignRewardClaimAsync(connection, transaction, normalizedCampaignId, normalizedPlayerId);
        if (existingForPlayer is not null)
        {
            await transaction.CommitAsync();
            return new CampaignRewardClaimResult(true, "Campaign reward was already claimed.", campaign, existingForPlayer, DateTimeOffset.UtcNow);
        }

        var claim = await InsertCampaignRewardClaimAsync(
            connection,
            transaction,
            normalizedCampaignId,
            normalizedPlayerId,
            campaign.CountryId,
            campaign.Reward.Gold,
            campaign.Reward.Experience,
            campaign.Reward.Prestige,
            idempotencyKey,
            $"Claimed {campaign.Name} rewards.",
            now);
        await transaction.CommitAsync();

        return new CampaignRewardClaimResult(true, claim.Message, campaign, claim, now);
    }

    public async Task<CountryBattleLeaderboardResponse> GetCountryBattleLeaderboardAsync(
        string? campaignId,
        string? battleId,
        int limit)
    {
        var normalizedCampaignId = string.IsNullOrWhiteSpace(campaignId) ? null : NormalizeId(campaignId);
        var normalizedBattleId = string.IsNullOrWhiteSpace(battleId) ? null : NormalizeId(battleId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var entries = await ReadCountryBattleLeaderboardAsync(
            connection,
            null,
            normalizedCampaignId,
            normalizedBattleId,
            limit);
        return new CountryBattleLeaderboardResponse(entries.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<CampaignUnitLeaderboardResponse> GetCampaignUnitLeaderboardAsync(string campaignId, int limit)
    {
        var normalizedCampaignId = NormalizeId(campaignId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var entries = await ReadCampaignUnitLeaderboardAsync(connection, null, normalizedCampaignId, limit);
        return new CampaignUnitLeaderboardResponse(entries.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<UnitDivisionListResponse?> GetUnitDivisionsAsync(string unitId, string? campaignId)
    {
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedCampaignId = string.IsNullOrWhiteSpace(campaignId) ? null : NormalizeId(campaignId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (await ReadMilitaryUnitAsync(connection, null, normalizedUnitId, null) is null)
        {
            return null;
        }

        var divisions = await ReadUnitDivisionsAsync(connection, null, normalizedUnitId, normalizedCampaignId);
        return new UnitDivisionListResponse(normalizedUnitId, divisions.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<UnitDivisionMutationResult?> CreateUnitDivisionAsync(
        string playerId,
        string unitId,
        UnitDivisionCreateRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedCampaignId = NormalizeId(request.CampaignId!);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey!);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existing = await ReadUnitDivisionByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (existing is not null)
        {
            await transaction.CommitAsync();
            return new UnitDivisionMutationResult(true, "Unit division creation was already recorded.", existing, DateTimeOffset.UtcNow);
        }

        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        var campaign = await ReadCampaignAsync(connection, transaction, normalizedCampaignId);
        if (unit is null || campaign is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var role = await ReadUnitRoleAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        if (!CanManageOrders(role))
        {
            await transaction.CommitAsync();
            return new UnitDivisionMutationResult(false, "Only commanders and officers can create divisions.", null, DateTimeOffset.UtcNow);
        }

        if (!string.Equals(unit.CountryId, campaign.CountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new UnitDivisionMutationResult(false, "Unit country must match the campaign country.", null, DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        var divisionId = $"division-{Guid.NewGuid():N}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.unit_divisions (
                division_id, unit_id, campaign_id, name, division_role,
                status, member_count, assigned_strength, created_by_player_id,
                idempotency_key, created_at, updated_at
            )
            VALUES (
                @division_id, @unit_id, @campaign_id, @name, @division_role,
                'forming', @member_count, @assigned_strength, @created_by_player_id,
                @idempotency_key, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("division_id", divisionId);
            command.Parameters.AddWithValue("unit_id", normalizedUnitId);
            command.Parameters.AddWithValue("campaign_id", normalizedCampaignId);
            command.Parameters.AddWithValue("name", request.Name!.Trim());
            command.Parameters.AddWithValue("division_role", NormalizeDivisionRole(request.DivisionRole));
            command.Parameters.AddWithValue("member_count", request.MemberCount);
            command.Parameters.AddWithValue("assigned_strength", request.AssignedStrength);
            command.Parameters.AddWithValue("created_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await TouchUnitAsync(connection, transaction, normalizedUnitId, now);
        var division = await ReadUnitDivisionAsync(connection, transaction, divisionId);
        await transaction.CommitAsync();
        return new UnitDivisionMutationResult(true, $"Division {division!.Name} created.", division, now);
    }

    public async Task<DeploymentOrderListResponse?> GetDeploymentOrdersAsync(string unitId, string? campaignId)
    {
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedCampaignId = string.IsNullOrWhiteSpace(campaignId) ? null : NormalizeId(campaignId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (await ReadMilitaryUnitAsync(connection, null, normalizedUnitId, null) is null)
        {
            return null;
        }

        var orders = await ReadDeploymentOrdersAsync(connection, null, normalizedUnitId, normalizedCampaignId);
        return new DeploymentOrderListResponse(normalizedUnitId, orders.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<DeploymentOrderMutationResult?> IssueDeploymentOrderAsync(
        string playerId,
        string unitId,
        DeploymentOrderCreateRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedCampaignId = string.IsNullOrWhiteSpace(request.CampaignId) ? null : NormalizeId(request.CampaignId!);
        var normalizedDivisionId = string.IsNullOrWhiteSpace(request.DivisionId) ? null : NormalizeId(request.DivisionId!);
        var normalizedBattleId = string.IsNullOrWhiteSpace(request.TargetBattleId) ? null : NormalizeId(request.TargetBattleId!);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey!);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existing = await ReadDeploymentOrderByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (existing is not null)
        {
            await transaction.CommitAsync();
            return new DeploymentOrderMutationResult(true, "Deployment order was already recorded.", existing, DateTimeOffset.UtcNow);
        }

        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        if (unit is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var role = await ReadUnitRoleAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        if (!CanManageOrders(role))
        {
            await transaction.CommitAsync();
            return new DeploymentOrderMutationResult(false, "Only commanders and officers can issue deployment orders.", null, DateTimeOffset.UtcNow);
        }

        if (normalizedCampaignId is not null)
        {
            var campaign = await ReadCampaignAsync(connection, transaction, normalizedCampaignId);
            if (campaign is null)
            {
                await transaction.RollbackAsync();
                return null;
            }

            if (!string.Equals(campaign.CountryId, unit.CountryId, StringComparison.Ordinal))
            {
                await transaction.CommitAsync();
                return new DeploymentOrderMutationResult(false, "Unit country must match the campaign country.", null, DateTimeOffset.UtcNow);
            }
        }

        if (normalizedDivisionId is not null)
        {
            var division = await ReadUnitDivisionAsync(connection, transaction, normalizedDivisionId);
            if (division is null || !string.Equals(division.UnitId, normalizedUnitId, StringComparison.Ordinal))
            {
                await transaction.RollbackAsync();
                return null;
            }

            normalizedCampaignId ??= division.CampaignId;
        }

        if (normalizedBattleId is not null)
        {
            var battle = await ReadBattleAsync(connection, transaction, normalizedBattleId);
            if (battle is null)
            {
                await transaction.RollbackAsync();
                return null;
            }

            if (!string.Equals(battle.AttackerCountryId, unit.CountryId, StringComparison.Ordinal) &&
                !string.Equals(battle.DefenderCountryId, unit.CountryId, StringComparison.Ordinal))
            {
                await transaction.CommitAsync();
                return new DeploymentOrderMutationResult(false, "Unit country is not fighting in the target battle.", null, DateTimeOffset.UtcNow);
            }

            normalizedCampaignId ??= battle.CampaignId;
        }

        var now = DateTimeOffset.UtcNow;
        var orderId = $"deploy-{Guid.NewGuid():N}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.deployment_orders (
                deployment_order_id, unit_id, division_id, campaign_id,
                target_battle_id, issued_by_player_id, order_type, title,
                description, troop_commitment, status, idempotency_key,
                created_at, updated_at, executed_at
            )
            VALUES (
                @deployment_order_id, @unit_id, @division_id, @campaign_id,
                @target_battle_id, @issued_by_player_id, @order_type, @title,
                @description, @troop_commitment, 'issued', @idempotency_key,
                @created_at, @updated_at, NULL
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("deployment_order_id", orderId);
            command.Parameters.AddWithValue("unit_id", normalizedUnitId);
            command.Parameters.AddWithValue("division_id", (object?)normalizedDivisionId ?? DBNull.Value);
            command.Parameters.AddWithValue("campaign_id", (object?)normalizedCampaignId ?? DBNull.Value);
            command.Parameters.AddWithValue("target_battle_id", (object?)normalizedBattleId ?? DBNull.Value);
            command.Parameters.AddWithValue("issued_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("order_type", NormalizeDeploymentOrderType(request.OrderType));
            command.Parameters.AddWithValue("title", request.Title!.Trim());
            command.Parameters.AddWithValue("description", request.Description?.Trim() ?? string.Empty);
            command.Parameters.AddWithValue("troop_commitment", request.TroopCommitment);
            command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await TouchUnitAsync(connection, transaction, normalizedUnitId, now);
        var order = await ReadDeploymentOrderAsync(connection, transaction, orderId);
        await transaction.CommitAsync();
        return new DeploymentOrderMutationResult(true, "Deployment order issued.", order, now);
    }

    public async Task<DeploymentOrderMutationResult?> UpdateDeploymentOrderStatusAsync(
        string playerId,
        string unitId,
        string orderId,
        string status)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedOrderId = NormalizeId(orderId);
        var normalizedStatus = NormalizeDeploymentOrderStatus(status);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        var order = await ReadDeploymentOrderAsync(connection, transaction, normalizedOrderId, forUpdate: true);
        if (unit is null || order is null || !string.Equals(order.UnitId, normalizedUnitId, StringComparison.Ordinal))
        {
            await transaction.RollbackAsync();
            return null;
        }

        var role = await ReadUnitRoleAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        if (!CanManageOrders(role))
        {
            await transaction.CommitAsync();
            return new DeploymentOrderMutationResult(false, "Only commanders and officers can manage deployment orders.", order, DateTimeOffset.UtcNow);
        }

        if (!string.Equals(order.Status, "issued", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new DeploymentOrderMutationResult(false, "Only issued deployment orders can be updated.", order, DateTimeOffset.UtcNow);
        }

        await using (var command = new NpgsqlCommand("""
            UPDATE world.deployment_orders
            SET status = @status,
                updated_at = @updated_at,
                executed_at = CASE WHEN @status = 'executed' THEN @updated_at ELSE executed_at END
            WHERE deployment_order_id = @deployment_order_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("deployment_order_id", normalizedOrderId);
            command.Parameters.AddWithValue("status", normalizedStatus);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        if (order.DivisionId is not null && normalizedStatus == "executed")
        {
            await using var updateDivision = new NpgsqlCommand("""
                UPDATE world.unit_divisions
                SET status = 'deployed',
                    updated_at = @updated_at
                WHERE division_id = @division_id;
                """, connection, transaction);
            updateDivision.Parameters.AddWithValue("division_id", order.DivisionId);
            updateDivision.Parameters.AddWithValue("updated_at", now);
            await updateDivision.ExecuteNonQueryAsync();
        }

        await TouchUnitAsync(connection, transaction, normalizedUnitId, now);
        order = await ReadDeploymentOrderAsync(connection, transaction, normalizedOrderId);
        await transaction.CommitAsync();
        return new DeploymentOrderMutationResult(true, $"Deployment order {normalizedStatus}.", order, now);
    }

    private static async Task<CampaignDto?> ReadCampaignForBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string battleId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT campaign_id
            FROM world.battles
            WHERE battle_id = @battle_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("battle_id", battleId);
        var campaignId = await command.ExecuteScalarAsync() as string;
        return string.IsNullOrWhiteSpace(campaignId)
            ? null
            : await ReadCampaignAsync(connection, transaction, campaignId);
    }

    private static async Task RecordCampaignBattleContributionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string battleId,
        string side,
        string countryId,
        int damage,
        DateTimeOffset now)
    {
        var campaign = await ReadCampaignForBattleAsync(connection, transaction, battleId);
        if (campaign is null || !string.Equals(campaign.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        await using (var updatePhase = new NpgsqlCommand("""
            UPDATE world.battle_phases
            SET attacker_damage = attacker_damage + CASE WHEN @side = 'attacker' THEN @damage ELSE 0 END,
                defender_damage = defender_damage + CASE WHEN @side = 'defender' THEN @damage ELSE 0 END,
                status = CASE
                    WHEN status = 'active'
                     AND attacker_damage + defender_damage + @damage >= target_damage
                    THEN 'completed'
                    ELSE status
                END,
                completed_at = CASE
                    WHEN completed_at IS NULL
                     AND status = 'active'
                     AND attacker_damage + defender_damage + @damage >= target_damage
                    THEN @updated_at
                    ELSE completed_at
                END,
                updated_at = @updated_at
            WHERE battle_id = @battle_id
              AND campaign_id = @campaign_id
              AND status = 'active';
            """, connection, transaction))
        {
            updatePhase.Parameters.AddWithValue("battle_id", battleId);
            updatePhase.Parameters.AddWithValue("campaign_id", campaign.CampaignId);
            updatePhase.Parameters.AddWithValue("side", side);
            updatePhase.Parameters.AddWithValue("damage", damage);
            updatePhase.Parameters.AddWithValue("updated_at", now);
            await updatePhase.ExecuteNonQueryAsync();
        }

        await using (var updateCampaign = new NpgsqlCommand("""
            UPDATE world.campaigns
            SET current_score = LEAST(objective_score, current_score + @damage),
                updated_at = @updated_at
            WHERE campaign_id = @campaign_id
              AND status = 'active';
            """, connection, transaction))
        {
            updateCampaign.Parameters.AddWithValue("campaign_id", campaign.CampaignId);
            updateCampaign.Parameters.AddWithValue("damage", damage);
            updateCampaign.Parameters.AddWithValue("updated_at", now);
            await updateCampaign.ExecuteNonQueryAsync();
        }

        await CompleteCampaignIfReadyAsync(connection, transaction, campaign.CampaignId, now, countryId);
    }

    private static async Task ResolveCampaignsForBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        CountryBattleDto battle,
        string winnerCountryId,
        DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(battle.CampaignId))
        {
            return;
        }

        await using (var completePhases = new NpgsqlCommand("""
            UPDATE world.battle_phases
            SET status = 'completed',
                completed_at = COALESCE(completed_at, @completed_at),
                updated_at = @completed_at
            WHERE campaign_id = @campaign_id
              AND battle_id = @battle_id
              AND status <> 'completed';
            """, connection, transaction))
        {
            completePhases.Parameters.AddWithValue("campaign_id", battle.CampaignId);
            completePhases.Parameters.AddWithValue("battle_id", battle.BattleId);
            completePhases.Parameters.AddWithValue("completed_at", now);
            await completePhases.ExecuteNonQueryAsync();
        }

        await CompleteCampaignIfReadyAsync(connection, transaction, battle.CampaignId, now, winnerCountryId);
    }

    private static async Task CompleteCampaignIfReadyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string campaignId,
        DateTimeOffset now,
        string? winnerCountryId = null)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.campaigns c
            SET status = 'completed',
                current_score = GREATEST(current_score, objective_score),
                concluded_at = COALESCE(concluded_at, @concluded_at),
                winner_country_id = COALESCE(@winner_country_id, winner_country_id, country_id),
                updated_at = @concluded_at
            WHERE c.campaign_id = @campaign_id
              AND c.status = 'active'
              AND (
                  c.current_score >= c.objective_score
                  OR NOT EXISTS (
                      SELECT 1
                      FROM world.battle_phases p
                      WHERE p.campaign_id = c.campaign_id
                        AND p.status <> 'completed'
                  )
              );
            """, connection, transaction);
        command.Parameters.AddWithValue("campaign_id", campaignId);
        command.Parameters.AddWithValue("winner_country_id", (object?)winnerCountryId ?? DBNull.Value);
        command.Parameters.AddWithValue("concluded_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task AttachBattleToCampaignAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string campaignId,
        string battleId,
        DateTimeOffset now)
    {
        await using (var updateBattle = new NpgsqlCommand("""
            UPDATE world.battles
            SET campaign_id = @campaign_id,
                updated_at = @updated_at
            WHERE battle_id = @battle_id;
            """, connection, transaction))
        {
            updateBattle.Parameters.AddWithValue("campaign_id", campaignId);
            updateBattle.Parameters.AddWithValue("battle_id", battleId);
            updateBattle.Parameters.AddWithValue("updated_at", now);
            await updateBattle.ExecuteNonQueryAsync();
        }

        await using var attach = new NpgsqlCommand("""
            INSERT INTO world.campaign_battles (campaign_id, battle_id, created_at)
            VALUES (@campaign_id, @battle_id, @created_at)
            ON CONFLICT (campaign_id, battle_id) DO NOTHING;
            """, connection, transaction);
        attach.Parameters.AddWithValue("campaign_id", campaignId);
        attach.Parameters.AddWithValue("battle_id", battleId);
        attach.Parameters.AddWithValue("created_at", now);
        await attach.ExecuteNonQueryAsync();
    }

    private static async Task<string> CreateCampaignForTerritoryBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId,
        string regionName,
        string battleType,
        string playerId,
        int targetScore,
        DateTimeOffset now)
    {
        var campaignId = $"campaign-{battleType}-{NormalizeId(regionName)}-{now:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N")[..8]}";
        await InsertCampaignAsync(
            connection,
            transaction,
            new CampaignInsert(
                CampaignId: campaignId,
                CountryId: countryId,
                Name: $"{regionName} {Capitalize(battleType)} Campaign",
                Description: $"A persisted {battleType} campaign for control of {regionName}.",
                CampaignType: battleType,
                Status: "active",
                ObjectiveScore: targetScore,
                CurrentScore: 0,
                RewardGold: CampaignRewardGold(targetScore),
                RewardExperience: CampaignRewardExperience(targetScore),
                RewardPrestige: CampaignRewardPrestige(targetScore),
                CreatedByPlayerId: playerId,
                IdempotencyKey: $"territory:{countryId}:{regionName}:{battleType}:{now:O}:{Guid.NewGuid():N}",
                StartedAt: now,
                EndsAt: now.AddHours(24),
                ConcludedAt: null,
                WinnerCountryId: null,
                CreatedAt: now,
                UpdatedAt: now));
        return campaignId;
    }

    private static async Task EnsureBattlePhaseAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string campaignId,
        string battleId,
        int phaseNumber,
        string name,
        string objectives,
        int targetDamage,
        int attackerDamage,
        int defenderDamage,
        string status,
        DateTimeOffset startedAt,
        DateTimeOffset? completedAt,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.battle_phases (
                phase_id, campaign_id, battle_id, phase_number, name,
                objectives, target_damage, attacker_damage, defender_damage,
                status, started_at, completed_at, updated_at
            )
            VALUES (
                @phase_id, @campaign_id, @battle_id, @phase_number, @name,
                @objectives, @target_damage, @attacker_damage, @defender_damage,
                @status, @started_at, @completed_at, @updated_at
            )
            ON CONFLICT (battle_id, phase_number) DO UPDATE
            SET campaign_id = EXCLUDED.campaign_id,
                name = EXCLUDED.name,
                objectives = EXCLUDED.objectives,
                target_damage = EXCLUDED.target_damage,
                attacker_damage = GREATEST(world.battle_phases.attacker_damage, EXCLUDED.attacker_damage),
                defender_damage = GREATEST(world.battle_phases.defender_damage, EXCLUDED.defender_damage),
                status = CASE
                    WHEN world.battle_phases.status = 'completed' THEN 'completed'
                    ELSE EXCLUDED.status
                END,
                completed_at = COALESCE(world.battle_phases.completed_at, EXCLUDED.completed_at),
                updated_at = EXCLUDED.updated_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("phase_id", $"phase-{battleId}-{phaseNumber}");
        command.Parameters.AddWithValue("campaign_id", campaignId);
        command.Parameters.AddWithValue("battle_id", battleId);
        command.Parameters.AddWithValue("phase_number", phaseNumber);
        command.Parameters.AddWithValue("name", name);
        command.Parameters.AddWithValue("objectives", objectives);
        command.Parameters.AddWithValue("target_damage", targetDamage);
        command.Parameters.AddWithValue("attacker_damage", attackerDamage);
        command.Parameters.AddWithValue("defender_damage", defenderDamage);
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("started_at", startedAt);
        command.Parameters.AddWithValue("completed_at", (object?)completedAt ?? DBNull.Value);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task InsertCampaignAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        CampaignInsert campaign)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.campaigns (
                campaign_id, country_id, name, description, campaign_type, status,
                objective_score, current_score, reward_gold, reward_experience,
                reward_prestige, created_by_player_id, idempotency_key, started_at,
                ends_at, concluded_at, winner_country_id, created_at, updated_at
            )
            VALUES (
                @campaign_id, @country_id, @name, @description, @campaign_type, @status,
                @objective_score, @current_score, @reward_gold, @reward_experience,
                @reward_prestige, @created_by_player_id, @idempotency_key, @started_at,
                @ends_at, @concluded_at, @winner_country_id, @created_at, @updated_at
            )
            ON CONFLICT (campaign_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("campaign_id", campaign.CampaignId);
        command.Parameters.AddWithValue("country_id", campaign.CountryId);
        command.Parameters.AddWithValue("name", campaign.Name);
        command.Parameters.AddWithValue("description", campaign.Description);
        command.Parameters.AddWithValue("campaign_type", campaign.CampaignType);
        command.Parameters.AddWithValue("status", campaign.Status);
        command.Parameters.AddWithValue("objective_score", campaign.ObjectiveScore);
        command.Parameters.AddWithValue("current_score", campaign.CurrentScore);
        command.Parameters.AddWithValue("reward_gold", campaign.RewardGold);
        command.Parameters.AddWithValue("reward_experience", campaign.RewardExperience);
        command.Parameters.AddWithValue("reward_prestige", campaign.RewardPrestige);
        command.Parameters.AddWithValue("created_by_player_id", campaign.CreatedByPlayerId);
        command.Parameters.AddWithValue("idempotency_key", campaign.IdempotencyKey);
        command.Parameters.AddWithValue("started_at", campaign.StartedAt);
        command.Parameters.AddWithValue("ends_at", (object?)campaign.EndsAt ?? DBNull.Value);
        command.Parameters.AddWithValue("concluded_at", (object?)campaign.ConcludedAt ?? DBNull.Value);
        command.Parameters.AddWithValue("winner_country_id", (object?)campaign.WinnerCountryId ?? DBNull.Value);
        command.Parameters.AddWithValue("created_at", campaign.CreatedAt);
        command.Parameters.AddWithValue("updated_at", campaign.UpdatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<CampaignDto>> ReadCampaignsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? countryId,
        string status,
        int limit)
    {
        await using var command = new NpgsqlCommand($"""
            SELECT {CampaignSelectColumns}
            FROM world.campaigns c
            INNER JOIN world.countries co ON co.country_id = c.country_id
            LEFT JOIN world.countries wc ON wc.country_id = c.winner_country_id
            WHERE (@country_id = '' OR c.country_id = @country_id)
              AND (@status = 'all' OR c.status = @status)
            ORDER BY
                CASE WHEN c.status = 'active' THEN 0 ELSE 1 END,
                c.updated_at DESC,
                c.started_at DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId ?? string.Empty);
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("limit", Math.Clamp(limit, 1, 100));

        var campaigns = new List<CampaignDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            campaigns.Add(ReadCampaign(reader));
        }

        return campaigns;
    }

    private const string CampaignSelectColumns = """
        c.campaign_id, c.country_id, co.name AS country_name, co.code AS country_code,
        c.name, c.description, c.campaign_type, c.status,
        c.objective_score, c.current_score,
        c.reward_gold, c.reward_experience, c.reward_prestige,
        (SELECT count(*)::int FROM world.campaign_battles cb WHERE cb.campaign_id = c.campaign_id) AS battle_count,
        (SELECT count(*)::int FROM world.battle_phases p WHERE p.campaign_id = c.campaign_id) AS phase_count,
        (SELECT count(*)::int
         FROM world.campaign_battles cb
         INNER JOIN world.battles b ON b.battle_id = cb.battle_id
         WHERE cb.campaign_id = c.campaign_id AND b.status = 'active') AS active_battle_count,
        c.created_by_player_id, c.started_at, c.ends_at, c.concluded_at,
        c.winner_country_id, wc.name AS winner_country_name,
        c.created_at, c.updated_at
        """;

    private static async Task<CampaignDto?> ReadCampaignAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string campaignId,
        bool forUpdate = false)
    {
        var sql = $"""
            SELECT {CampaignSelectColumns}
            FROM world.campaigns c
            INNER JOIN world.countries co ON co.country_id = c.country_id
            LEFT JOIN world.countries wc ON wc.country_id = c.winner_country_id
            WHERE c.campaign_id = @campaign_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE OF c";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("campaign_id", campaignId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCampaign(reader) : null;
    }

    private static async Task<CampaignDto?> ReadCampaignByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand($"""
            SELECT {CampaignSelectColumns}
            FROM world.campaigns c
            INNER JOIN world.countries co ON co.country_id = c.country_id
            LEFT JOIN world.countries wc ON wc.country_id = c.winner_country_id
            WHERE c.idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCampaign(reader) : null;
    }

    private static CampaignDto ReadCampaign(NpgsqlDataReader reader)
    {
        return new CampaignDto(
            CampaignId: reader.GetString(0),
            CountryId: reader.GetString(1),
            CountryName: reader.GetString(2),
            CountryCode: reader.GetString(3),
            Name: reader.GetString(4),
            Description: reader.GetString(5),
            CampaignType: reader.GetString(6),
            Status: reader.GetString(7),
            ObjectiveScore: reader.GetInt32(8),
            CurrentScore: reader.GetInt32(9),
            Reward: new CampaignRewardDto(
                Gold: reader.GetInt32(10),
                Experience: reader.GetInt32(11),
                Prestige: reader.GetInt32(12)),
            BattleCount: reader.GetInt32(13),
            PhaseCount: reader.GetInt32(14),
            ActiveBattleCount: reader.GetInt32(15),
            CreatedByPlayerId: reader.GetString(16),
            StartedAt: reader.GetFieldValue<DateTimeOffset>(17),
            EndsAt: reader.IsDBNull(18) ? null : reader.GetFieldValue<DateTimeOffset>(18),
            ConcludedAt: reader.IsDBNull(19) ? null : reader.GetFieldValue<DateTimeOffset>(19),
            WinnerCountryId: reader.IsDBNull(20) ? null : reader.GetString(20),
            WinnerCountryName: reader.IsDBNull(21) ? null : reader.GetString(21),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(22),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(23));
    }

    private static async Task<List<CountryBattleDto>> ReadCampaignBattlesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string campaignId)
    {
        await using var command = new NpgsqlCommand($"""
            SELECT {BattleSelectColumns}
            FROM world.campaign_battles cb
            INNER JOIN world.battles b ON b.battle_id = cb.battle_id
            INNER JOIN world.regions r ON r.region_id = b.region_id
            INNER JOIN world.countries ac ON ac.country_id = b.attacker_country_id
            INNER JOIN world.countries dc ON dc.country_id = b.defender_country_id
            LEFT JOIN world.countries wc ON wc.country_id = b.winner_country_id
            WHERE cb.campaign_id = @campaign_id
            ORDER BY b.started_at ASC;
            """, connection, transaction);
        command.Parameters.AddWithValue("campaign_id", campaignId);

        var battles = new List<CountryBattleDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            battles.Add(ReadBattle(reader));
        }

        return battles;
    }

    private static async Task<List<BattlePhaseDto>> ReadBattlePhasesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? battleId,
        string? campaignId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT p.phase_id, p.campaign_id, p.battle_id, b.name AS battle_name,
                   p.phase_number, p.name, p.objectives, p.target_damage,
                   p.attacker_damage, p.defender_damage, p.status,
                   p.started_at, p.completed_at, p.updated_at
            FROM world.battle_phases p
            INNER JOIN world.battles b ON b.battle_id = p.battle_id
            WHERE (@battle_id = '' OR p.battle_id = @battle_id)
              AND (@campaign_id = '' OR p.campaign_id = @campaign_id)
            ORDER BY p.phase_number ASC, p.started_at ASC;
            """, connection, transaction);
        command.Parameters.AddWithValue("battle_id", battleId ?? string.Empty);
        command.Parameters.AddWithValue("campaign_id", campaignId ?? string.Empty);

        var phases = new List<BattlePhaseDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            phases.Add(ReadBattlePhase(reader));
        }

        return phases;
    }

    private static async Task<BattlePhaseDto?> ReadBattlePhaseAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string phaseId,
        bool forUpdate = false)
    {
        var sql = """
            SELECT p.phase_id, p.campaign_id, p.battle_id, b.name AS battle_name,
                   p.phase_number, p.name, p.objectives, p.target_damage,
                   p.attacker_damage, p.defender_damage, p.status,
                   p.started_at, p.completed_at, p.updated_at
            FROM world.battle_phases p
            INNER JOIN world.battles b ON b.battle_id = p.battle_id
            WHERE p.phase_id = @phase_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE OF p";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("phase_id", phaseId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadBattlePhase(reader) : null;
    }

    private static BattlePhaseDto ReadBattlePhase(NpgsqlDataReader reader)
    {
        return new BattlePhaseDto(
            PhaseId: reader.GetString(0),
            CampaignId: reader.GetString(1),
            BattleId: reader.GetString(2),
            BattleName: reader.GetString(3),
            PhaseNumber: reader.GetInt32(4),
            Name: reader.GetString(5),
            Objectives: reader.GetString(6),
            TargetDamage: reader.GetInt32(7),
            AttackerDamage: reader.GetInt32(8),
            DefenderDamage: reader.GetInt32(9),
            Status: reader.GetString(10),
            StartedAt: reader.GetFieldValue<DateTimeOffset>(11),
            CompletedAt: reader.IsDBNull(12) ? null : reader.GetFieldValue<DateTimeOffset>(12),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(13));
    }

    private static async Task UpdatePhaseStatusAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string phaseId,
        string status,
        DateTimeOffset? completedAt,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.battle_phases
            SET status = @status,
                completed_at = @completed_at,
                updated_at = @updated_at
            WHERE phase_id = @phase_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("phase_id", phaseId);
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("completed_at", (object?)completedAt ?? DBNull.Value);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<CountryBattleLeaderboardEntryDto>> ReadCountryBattleLeaderboardAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? campaignId,
        string? battleId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT bc.country_id, c.name, c.code,
                   COALESCE(sum(bc.damage), 0)::int AS total_damage,
                   count(*)::int AS contribution_count,
                   count(DISTINCT bc.battle_id)::int AS battle_count,
                   count(DISTINCT CASE WHEN b.winner_country_id = bc.country_id THEN b.battle_id END)::int AS victory_count,
                   max(bc.created_at) AS last_contributed_at
            FROM world.battle_contributions bc
            INNER JOIN world.countries c ON c.country_id = bc.country_id
            INNER JOIN world.battles b ON b.battle_id = bc.battle_id
            LEFT JOIN world.campaign_battles cb ON cb.battle_id = bc.battle_id
            WHERE (@campaign_id = '' OR cb.campaign_id = @campaign_id)
              AND (@battle_id = '' OR bc.battle_id = @battle_id)
            GROUP BY bc.country_id, c.name, c.code
            ORDER BY total_damage DESC, victory_count DESC, contribution_count DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("campaign_id", campaignId ?? string.Empty);
        command.Parameters.AddWithValue("battle_id", battleId ?? string.Empty);
        command.Parameters.AddWithValue("limit", Math.Clamp(limit, 1, 100));

        var entries = new List<CountryBattleLeaderboardEntryDto>();
        var rank = 1;
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(new CountryBattleLeaderboardEntryDto(
                Rank: rank++,
                CountryId: reader.GetString(0),
                CountryName: reader.GetString(1),
                CountryCode: reader.GetString(2),
                TotalDamage: reader.GetInt32(3),
                ContributionCount: reader.GetInt32(4),
                BattleCount: reader.GetInt32(5),
                VictoryCount: reader.GetInt32(6),
                Score: reader.GetInt32(3) + (reader.GetInt32(6) * 100),
                LastContributedAt: reader.IsDBNull(7) ? null : reader.GetFieldValue<DateTimeOffset>(7)));
        }

        return entries;
    }

    private static async Task<List<CampaignUnitLeaderboardEntryDto>> ReadCampaignUnitLeaderboardAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string campaignId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT t.unit_id, u.name AS unit_name, t.country_id, c.name AS country_name, c.code AS country_code,
                   COALESCE(sum(t.total_damage), 0)::int AS total_damage,
                   COALESCE(sum(t.contribution_count), 0)::int AS contribution_count,
                   count(DISTINCT t.battle_id)::int AS battle_count,
                   max(t.member_count)::int AS member_count,
                   max(t.last_contributed_at) AS last_contributed_at
            FROM world.unit_battle_totals t
            INNER JOIN world.military_units u ON u.unit_id = t.unit_id
            INNER JOIN world.countries c ON c.country_id = t.country_id
            INNER JOIN world.campaign_battles cb ON cb.battle_id = t.battle_id
            WHERE cb.campaign_id = @campaign_id
            GROUP BY t.unit_id, u.name, t.country_id, c.name, c.code
            ORDER BY total_damage DESC, contribution_count DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("campaign_id", campaignId);
        command.Parameters.AddWithValue("limit", Math.Clamp(limit, 1, 100));

        var entries = new List<CampaignUnitLeaderboardEntryDto>();
        var rank = 1;
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(new CampaignUnitLeaderboardEntryDto(
                Rank: rank++,
                UnitId: reader.GetString(0),
                UnitName: reader.GetString(1),
                CountryId: reader.GetString(2),
                CountryName: reader.GetString(3),
                CountryCode: reader.GetString(4),
                TotalDamage: reader.GetInt32(5),
                ContributionCount: reader.GetInt32(6),
                BattleCount: reader.GetInt32(7),
                MemberCount: reader.GetInt32(8),
                Score: reader.GetInt32(5) + (reader.GetInt32(7) * 50),
                LastContributedAt: reader.IsDBNull(9) ? null : reader.GetFieldValue<DateTimeOffset>(9)));
        }

        return entries;
    }

    private static async Task<List<UnitDivisionDto>> ReadUnitDivisionsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string unitId,
        string? campaignId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT d.division_id, d.unit_id, u.name AS unit_name,
                   d.campaign_id, c.name AS campaign_name,
                   d.name, d.division_role, d.status,
                   d.member_count, d.assigned_strength,
                   d.created_by_player_id, d.created_at, d.updated_at
            FROM world.unit_divisions d
            INNER JOIN world.military_units u ON u.unit_id = d.unit_id
            INNER JOIN world.campaigns c ON c.campaign_id = d.campaign_id
            WHERE d.unit_id = @unit_id
              AND (@campaign_id = '' OR d.campaign_id = @campaign_id)
            ORDER BY d.updated_at DESC, d.name;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("campaign_id", campaignId ?? string.Empty);

        var divisions = new List<UnitDivisionDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            divisions.Add(ReadUnitDivision(reader));
        }

        return divisions;
    }

    private static async Task<UnitDivisionDto?> ReadUnitDivisionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string divisionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT d.division_id, d.unit_id, u.name AS unit_name,
                   d.campaign_id, c.name AS campaign_name,
                   d.name, d.division_role, d.status,
                   d.member_count, d.assigned_strength,
                   d.created_by_player_id, d.created_at, d.updated_at
            FROM world.unit_divisions d
            INNER JOIN world.military_units u ON u.unit_id = d.unit_id
            INNER JOIN world.campaigns c ON c.campaign_id = d.campaign_id
            WHERE d.division_id = @division_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("division_id", divisionId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadUnitDivision(reader) : null;
    }

    private static async Task<UnitDivisionDto?> ReadUnitDivisionByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT d.division_id, d.unit_id, u.name AS unit_name,
                   d.campaign_id, c.name AS campaign_name,
                   d.name, d.division_role, d.status,
                   d.member_count, d.assigned_strength,
                   d.created_by_player_id, d.created_at, d.updated_at
            FROM world.unit_divisions d
            INNER JOIN world.military_units u ON u.unit_id = d.unit_id
            INNER JOIN world.campaigns c ON c.campaign_id = d.campaign_id
            WHERE d.idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadUnitDivision(reader) : null;
    }

    private static UnitDivisionDto ReadUnitDivision(NpgsqlDataReader reader)
    {
        return new UnitDivisionDto(
            DivisionId: reader.GetString(0),
            UnitId: reader.GetString(1),
            UnitName: reader.GetString(2),
            CampaignId: reader.GetString(3),
            CampaignName: reader.GetString(4),
            Name: reader.GetString(5),
            DivisionRole: reader.GetString(6),
            Status: reader.GetString(7),
            MemberCount: reader.GetInt32(8),
            AssignedStrength: reader.GetInt32(9),
            CreatedByPlayerId: reader.GetString(10),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(11),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(12));
    }

    private static async Task<List<DeploymentOrderDto>> ReadDeploymentOrdersAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string unitId,
        string? campaignId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT deployment_order_id, unit_id, division_id, campaign_id,
                   target_battle_id, issued_by_player_id, order_type, title,
                   description, troop_commitment, status, created_at, updated_at, executed_at
            FROM world.deployment_orders
            WHERE unit_id = @unit_id
              AND (@campaign_id = '' OR campaign_id = @campaign_id)
            ORDER BY
                CASE WHEN status = 'issued' THEN 0 ELSE 1 END,
                updated_at DESC;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("campaign_id", campaignId ?? string.Empty);

        var orders = new List<DeploymentOrderDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            orders.Add(ReadDeploymentOrder(reader));
        }

        return orders;
    }

    private static async Task<DeploymentOrderDto?> ReadDeploymentOrderAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string orderId,
        bool forUpdate = false)
    {
        var sql = """
            SELECT deployment_order_id, unit_id, division_id, campaign_id,
                   target_battle_id, issued_by_player_id, order_type, title,
                   description, troop_commitment, status, created_at, updated_at, executed_at
            FROM world.deployment_orders
            WHERE deployment_order_id = @deployment_order_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("deployment_order_id", orderId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadDeploymentOrder(reader) : null;
    }

    private static async Task<DeploymentOrderDto?> ReadDeploymentOrderByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT deployment_order_id, unit_id, division_id, campaign_id,
                   target_battle_id, issued_by_player_id, order_type, title,
                   description, troop_commitment, status, created_at, updated_at, executed_at
            FROM world.deployment_orders
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadDeploymentOrder(reader) : null;
    }

    private static DeploymentOrderDto ReadDeploymentOrder(NpgsqlDataReader reader)
    {
        return new DeploymentOrderDto(
            DeploymentOrderId: reader.GetString(0),
            UnitId: reader.GetString(1),
            DivisionId: reader.IsDBNull(2) ? null : reader.GetString(2),
            CampaignId: reader.IsDBNull(3) ? null : reader.GetString(3),
            TargetBattleId: reader.IsDBNull(4) ? null : reader.GetString(4),
            IssuedByPlayerId: reader.GetString(5),
            OrderType: reader.GetString(6),
            Title: reader.GetString(7),
            Description: reader.GetString(8),
            TroopCommitment: reader.GetInt32(9),
            Status: reader.GetString(10),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(11),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(12),
            ExecutedAt: reader.IsDBNull(13) ? null : reader.GetFieldValue<DateTimeOffset>(13));
    }

    private static async Task<CampaignRewardClaimDto?> ReadCampaignRewardClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string campaignId,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT claim_id, campaign_id, player_id, country_id,
                   gold_reward, experience_reward, prestige_reward,
                   message, claimed_at
            FROM world.campaign_reward_claims
            WHERE campaign_id = @campaign_id AND player_id = @player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("campaign_id", campaignId);
        command.Parameters.AddWithValue("player_id", playerId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCampaignRewardClaim(reader) : null;
    }

    private static async Task<CampaignRewardClaimDto?> ReadCampaignRewardClaimByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT claim_id, campaign_id, player_id, country_id,
                   gold_reward, experience_reward, prestige_reward,
                   message, claimed_at
            FROM world.campaign_reward_claims
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCampaignRewardClaim(reader) : null;
    }

    private static async Task<CampaignRewardClaimDto> InsertCampaignRewardClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string campaignId,
        string playerId,
        string countryId,
        int goldReward,
        int experienceReward,
        int prestigeReward,
        string idempotencyKey,
        string message,
        DateTimeOffset now)
    {
        var claimId = $"claim-{Guid.NewGuid():N}";
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.campaign_reward_claims (
                claim_id, campaign_id, player_id, country_id,
                gold_reward, experience_reward, prestige_reward,
                idempotency_key, message, claimed_at
            )
            VALUES (
                @claim_id, @campaign_id, @player_id, @country_id,
                @gold_reward, @experience_reward, @prestige_reward,
                @idempotency_key, @message, @claimed_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("claim_id", claimId);
        command.Parameters.AddWithValue("campaign_id", campaignId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("gold_reward", goldReward);
        command.Parameters.AddWithValue("experience_reward", experienceReward);
        command.Parameters.AddWithValue("prestige_reward", prestigeReward);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("claimed_at", now);
        await command.ExecuteNonQueryAsync();
        return new CampaignRewardClaimDto(
            claimId,
            campaignId,
            playerId,
            countryId,
            goldReward,
            experienceReward,
            prestigeReward,
            message,
            now);
    }

    private static CampaignRewardClaimDto ReadCampaignRewardClaim(NpgsqlDataReader reader)
    {
        return new CampaignRewardClaimDto(
            ClaimId: reader.GetString(0),
            CampaignId: reader.GetString(1),
            PlayerId: reader.GetString(2),
            CountryId: reader.GetString(3),
            GoldReward: reader.GetInt32(4),
            ExperienceReward: reader.GetInt32(5),
            PrestigeReward: reader.GetInt32(6),
            Message: reader.GetString(7),
            ClaimedAt: reader.GetFieldValue<DateTimeOffset>(8));
    }

    private static int CampaignRewardGold(int objectiveScore)
    {
        return Math.Clamp(objectiveScore / 50, 5, 500);
    }

    private static int CampaignRewardExperience(int objectiveScore)
    {
        return Math.Clamp(objectiveScore / 10, 25, 2_500);
    }

    private static int CampaignRewardPrestige(int objectiveScore)
    {
        return Math.Clamp(objectiveScore / 100, 1, 100);
    }

    private static string NormalizeCampaignStatus(string? status)
    {
        var normalized = string.IsNullOrWhiteSpace(status)
            ? "active"
            : status.Trim().ToLowerInvariant().Replace('-', '_');
        return normalized is "active" or "completed" or "cancelled" or "all"
            ? normalized
            : "active";
    }

    private static string NormalizeCampaignType(string? campaignType)
    {
        var normalized = string.IsNullOrWhiteSpace(campaignType)
            ? "conquest"
            : campaignType.Trim().ToLowerInvariant().Replace('-', '_').Replace(' ', '_');
        return normalized.Length <= 32 ? normalized : normalized[..32];
    }

    private static string NormalizeDivisionRole(string? divisionRole)
    {
        var normalized = string.IsNullOrWhiteSpace(divisionRole)
            ? "front_line"
            : divisionRole.Trim().ToLowerInvariant().Replace('-', '_').Replace(' ', '_');
        return normalized.Length <= 32 ? normalized : normalized[..32];
    }

    private static string NormalizeDeploymentOrderType(string? orderType)
    {
        var normalized = string.IsNullOrWhiteSpace(orderType)
            ? "deploy"
            : orderType.Trim().ToLowerInvariant().Replace('-', '_').Replace(' ', '_');
        return normalized.Length <= 32 ? normalized : normalized[..32];
    }

    private static string NormalizeDeploymentOrderStatus(string status)
    {
        return string.Equals(status, "cancelled", StringComparison.OrdinalIgnoreCase)
            ? "cancelled"
            : "executed";
    }

    private static string Capitalize(string value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? "War"
            : char.ToUpperInvariant(value[0]) + value[1..].Replace('_', ' ');
    }
}

internal sealed record CampaignInsert(
    string CampaignId,
    string CountryId,
    string Name,
    string Description,
    string CampaignType,
    string Status,
    int ObjectiveScore,
    int CurrentScore,
    int RewardGold,
    int RewardExperience,
    int RewardPrestige,
    string CreatedByPlayerId,
    string IdempotencyKey,
    DateTimeOffset StartedAt,
    DateTimeOffset? EndsAt,
    DateTimeOffset? ConcludedAt,
    string? WinnerCountryId,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignListResponse(CampaignDto[] Campaigns, DateTimeOffset UpdatedAt);

internal sealed record CampaignDetailsResponse(
    CampaignDto Campaign,
    CountryBattleDto[] Battles,
    BattlePhaseDto[] Phases,
    CountryBattleLeaderboardResponse CountryLeaderboard,
    CampaignUnitLeaderboardResponse UnitLeaderboard,
    DateTimeOffset UpdatedAt);

internal sealed record BattlePhaseListResponse(
    string CampaignId,
    BattlePhaseDto[] Phases,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignMutationResult(
    bool Completed,
    string Message,
    CampaignDto? Campaign,
    BattlePhaseDto? Phase,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignRewardClaimResult(
    bool Completed,
    string Message,
    CampaignDto? Campaign,
    CampaignRewardClaimDto? Claim,
    DateTimeOffset UpdatedAt);

internal sealed record CountryBattleLeaderboardResponse(
    CountryBattleLeaderboardEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignUnitLeaderboardResponse(
    CampaignUnitLeaderboardEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record UnitDivisionListResponse(
    string UnitId,
    UnitDivisionDto[] Divisions,
    DateTimeOffset UpdatedAt);

internal sealed record UnitDivisionMutationResult(
    bool Completed,
    string Message,
    UnitDivisionDto? Division,
    DateTimeOffset UpdatedAt);

internal sealed record DeploymentOrderListResponse(
    string UnitId,
    DeploymentOrderDto[] Orders,
    DateTimeOffset UpdatedAt);

internal sealed record DeploymentOrderMutationResult(
    bool Completed,
    string Message,
    DeploymentOrderDto? Order,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignDto(
    string CampaignId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Name,
    string Description,
    string CampaignType,
    string Status,
    int ObjectiveScore,
    int CurrentScore,
    CampaignRewardDto Reward,
    int BattleCount,
    int PhaseCount,
    int ActiveBattleCount,
    string CreatedByPlayerId,
    DateTimeOffset StartedAt,
    DateTimeOffset? EndsAt,
    DateTimeOffset? ConcludedAt,
    string? WinnerCountryId,
    string? WinnerCountryName,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignRewardDto(int Gold, int Experience, int Prestige);

internal sealed record BattlePhaseDto(
    string PhaseId,
    string CampaignId,
    string BattleId,
    string BattleName,
    int PhaseNumber,
    string Name,
    string Objectives,
    int TargetDamage,
    int AttackerDamage,
    int DefenderDamage,
    string Status,
    DateTimeOffset StartedAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset UpdatedAt);

internal sealed record CountryBattleLeaderboardEntryDto(
    int Rank,
    string CountryId,
    string CountryName,
    string CountryCode,
    int TotalDamage,
    int ContributionCount,
    int BattleCount,
    int VictoryCount,
    int Score,
    DateTimeOffset? LastContributedAt);

internal sealed record CampaignUnitLeaderboardEntryDto(
    int Rank,
    string UnitId,
    string UnitName,
    string CountryId,
    string CountryName,
    string CountryCode,
    int TotalDamage,
    int ContributionCount,
    int BattleCount,
    int MemberCount,
    int Score,
    DateTimeOffset? LastContributedAt);

internal sealed record UnitDivisionDto(
    string DivisionId,
    string UnitId,
    string UnitName,
    string CampaignId,
    string CampaignName,
    string Name,
    string DivisionRole,
    string Status,
    int MemberCount,
    int AssignedStrength,
    string CreatedByPlayerId,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record DeploymentOrderDto(
    string DeploymentOrderId,
    string UnitId,
    string? DivisionId,
    string? CampaignId,
    string? TargetBattleId,
    string IssuedByPlayerId,
    string OrderType,
    string Title,
    string Description,
    int TroopCommitment,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ExecutedAt);

internal sealed record CampaignRewardClaimDto(
    string ClaimId,
    string CampaignId,
    string PlayerId,
    string CountryId,
    int GoldReward,
    int ExperienceReward,
    int PrestigeReward,
    string Message,
    DateTimeOffset ClaimedAt);

internal sealed record CampaignCreateRequest(
    string? CountryId,
    string? Name,
    string? Description,
    string? CampaignType,
    int? ObjectiveScore,
    DateTimeOffset? EndsAt,
    string? IdempotencyKey);

internal sealed record CampaignRewardClaimRequest(string? IdempotencyKey);

internal sealed record UnitDivisionCreateRequest(
    string? CampaignId,
    string? Name,
    string? DivisionRole,
    int MemberCount,
    int AssignedStrength,
    string? IdempotencyKey);

internal sealed record DeploymentOrderCreateRequest(
    string? CampaignId,
    string? DivisionId,
    string? TargetBattleId,
    string? OrderType,
    string? Title,
    string? Description,
    int TroopCommitment,
    string? IdempotencyKey);

internal static class CampaignGatewayEndpoints
{
    public static void MapCampaignGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/world/campaigns", async (
            string? countryId,
            string? status,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(
                ("countryId", countryId),
                ("status", status),
                ("limit", limit?.ToString()));
            return await world.GetAsync($"campaigns{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCampaigns");

        app.MapGet("/world/campaigns/{campaignId}", async (
            string campaignId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"campaigns/{Uri.EscapeDataString(campaignId)}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCampaign");

        app.MapPost("/players/{playerId}/campaigns", async (
            string playerId,
            CampaignCreateGatewayRequest createRequest,
            HttpRequest request,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            var result = await world.PostJsonAsync<CampaignCreateForwardRequest, CampaignMutationResultDto>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/campaigns",
                request.Headers.Authorization.ToString(),
                new CampaignCreateForwardRequest(
                    createRequest.CountryId,
                    createRequest.Name,
                    createRequest.Description,
                    createRequest.CampaignType,
                    createRequest.ObjectiveScore,
                    createRequest.EndsAt,
                    idempotencyKey));
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value!;
            if (mutation.Completed && mutation.Campaign is not null)
            {
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    access.PlayerId!,
                    "campaign_created",
                    mutation.Message,
                    mutation.Campaign.CampaignId,
                    $"activity:campaign-created:{access.PlayerId!.ToLowerInvariant()}:{mutation.Campaign.CampaignId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}");
            }

            return MutationResult(mutation);
        }).WithName("CreateGatewayCampaign");

        app.MapPost("/players/{playerId}/campaigns/{campaignId}/phases/{phaseId}/complete", async (
            string playerId,
            string campaignId,
            string phaseId,
            HttpRequest request,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.PostJsonAsync<object, CampaignMutationResultDto>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/campaigns/{Uri.EscapeDataString(campaignId)}/phases/{Uri.EscapeDataString(phaseId)}/complete",
                request.Headers.Authorization.ToString(),
                new { });
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value!;
            if (mutation.Completed)
            {
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    access.PlayerId!,
                    "campaign_phase_completed",
                    mutation.Message,
                    phaseId,
                    $"activity:campaign-phase-completed:{access.PlayerId!.ToLowerInvariant()}:{phaseId.ToLowerInvariant()}");
            }

            return MutationResult(mutation);
        }).WithName("CompleteGatewayCampaignPhase");

        app.MapPost("/players/{playerId}/campaigns/{campaignId}/rewards/claim", async (
            string playerId,
            string campaignId,
            HttpRequest request,
            WorldServiceClient world,
            PlayerServiceClient players,
            EconomyServiceClient economy,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            var result = await world.PostJsonAsync<CampaignRewardClaimForwardRequest, CampaignRewardClaimResultDto>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/campaigns/{Uri.EscapeDataString(campaignId)}/rewards/claim",
                request.Headers.Authorization.ToString(),
                new CampaignRewardClaimForwardRequest(idempotencyKey));
            if (result.Error is not null)
            {
                return result.Error;
            }

            var claim = result.Value!;
            if (claim.Completed && claim.Claim is not null)
            {
                var rewardResult = await ApplyCampaignRewardsAsync(
                    access.PlayerId!,
                    claim.Claim,
                    request.Headers.Authorization.ToString(),
                    players,
                    economy,
                    configuration);
                if (rewardResult is not null)
                {
                    return rewardResult;
                }
            }

            if (claim.Completed)
            {
                var activityKey = claim.Claim?.ClaimId.ToLowerInvariant() ?? idempotencyKey.ToLowerInvariant();
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    access.PlayerId!,
                    "campaign_reward_claimed",
                    claim.Message,
                    campaignId,
                    $"activity:campaign-reward:{access.PlayerId!.ToLowerInvariant()}:{campaignId.ToLowerInvariant()}:{activityKey}");
            }

            return claim.Completed
                ? Results.Ok(claim)
                : Results.Json(claim, statusCode: StatusCodes.Status409Conflict);
        }).WithName("ClaimGatewayCampaignReward");

        app.MapGet("/world/leaderboards/countries", async (
            string? campaignId,
            string? battleId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(
                ("campaignId", campaignId),
                ("battleId", battleId),
                ("limit", limit?.ToString()));
            return await world.GetAsync($"leaderboards/countries{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCountryBattleLeaderboard");

        app.MapGet("/world/campaigns/{campaignId}/leaderboards/countries", async (
            string campaignId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("limit", limit?.ToString()));
            return await world.GetAsync(
                $"campaigns/{Uri.EscapeDataString(campaignId)}/leaderboards/countries{query}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCampaignCountryLeaderboard");

        app.MapGet("/world/campaigns/{campaignId}/leaderboards/units", async (
            string campaignId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("limit", limit?.ToString()));
            return await world.GetAsync(
                $"campaigns/{Uri.EscapeDataString(campaignId)}/leaderboards/units{query}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCampaignUnitLeaderboard");

        app.MapGet("/military-units/{unitId}/divisions", async (
            string unitId,
            string? campaignId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("campaignId", campaignId));
            return await world.GetAsync(
                $"military-units/{Uri.EscapeDataString(unitId)}/divisions{query}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayUnitDivisions");

        app.MapPost("/players/{playerId}/military-units/{unitId}/divisions", async (
            string playerId,
            string unitId,
            UnitDivisionCreateGatewayRequest createRequest,
            HttpRequest request,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            var result = await world.PostJsonAsync<UnitDivisionCreateForwardRequest, UnitDivisionMutationResultDto>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/divisions",
                request.Headers.Authorization.ToString(),
                new UnitDivisionCreateForwardRequest(
                    createRequest.CampaignId,
                    createRequest.Name,
                    createRequest.DivisionRole,
                    createRequest.MemberCount,
                    createRequest.AssignedStrength,
                    idempotencyKey));
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value!;
            if (mutation.Completed && mutation.Division is not null)
            {
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    access.PlayerId!,
                    "division_deployed",
                    mutation.Message,
                    mutation.Division.DivisionId,
                    $"activity:division-created:{access.PlayerId!.ToLowerInvariant()}:{mutation.Division.DivisionId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}");
            }

            return mutation.Completed
                ? Results.Ok(mutation)
                : Results.Json(mutation, statusCode: StatusCodes.Status409Conflict);
        }).WithName("CreateGatewayUnitDivision");

        app.MapGet("/military-units/{unitId}/deployment-orders", async (
            string unitId,
            string? campaignId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("campaignId", campaignId));
            return await world.GetAsync(
                $"military-units/{Uri.EscapeDataString(unitId)}/deployment-orders{query}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayDeploymentOrders");

        app.MapPost("/players/{playerId}/military-units/{unitId}/deployment-orders", async (
            string playerId,
            string unitId,
            DeploymentOrderCreateGatewayRequest orderRequest,
            HttpRequest request,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            var result = await world.PostJsonAsync<DeploymentOrderCreateForwardRequest, DeploymentOrderMutationResultDto>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/deployment-orders",
                request.Headers.Authorization.ToString(),
                new DeploymentOrderCreateForwardRequest(
                    orderRequest.CampaignId,
                    orderRequest.DivisionId,
                    orderRequest.TargetBattleId,
                    orderRequest.OrderType,
                    orderRequest.Title,
                    orderRequest.Description,
                    orderRequest.TroopCommitment,
                    idempotencyKey));
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value!;
            if (mutation.Completed && mutation.Order is not null)
            {
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    access.PlayerId!,
                    "deployment_order_issued",
                    mutation.Message,
                    mutation.Order.DeploymentOrderId,
                    $"activity:deployment-issued:{access.PlayerId!.ToLowerInvariant()}:{mutation.Order.DeploymentOrderId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}");
            }

            return mutation.Completed
                ? Results.Ok(mutation)
                : Results.Json(mutation, statusCode: StatusCodes.Status409Conflict);
        }).WithName("IssueGatewayDeploymentOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/deployment-orders/{orderId}/execute", async (
            string playerId,
            string unitId,
            string orderId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/deployment-orders/{Uri.EscapeDataString(orderId)}/execute",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("ExecuteGatewayDeploymentOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/deployment-orders/{orderId}/cancel", async (
            string playerId,
            string unitId,
            string orderId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/deployment-orders/{Uri.EscapeDataString(orderId)}/cancel",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("CancelGatewayDeploymentOrder");
    }

    private static IResult MutationResult(CampaignMutationResultDto result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static async Task<IResult?> ApplyCampaignRewardsAsync(
        string playerId,
        CampaignRewardClaimDto claim,
        string authorization,
        PlayerServiceClient players,
        EconomyServiceClient economy,
        IConfiguration configuration)
    {
        var escapedPlayerId = Uri.EscapeDataString(playerId);
        var campaignId = claim.CampaignId;
        var rewardKey = $"campaign-reward:{playerId.ToLowerInvariant()}:{claim.ClaimId.ToLowerInvariant()}";
        var message = claim.Message;

        if (claim.ExperienceReward > 0 || claim.GoldReward > 0)
        {
            var progression = await players.PostJsonAsync<CombatResultRequestDto, PlayerActionResponseDto>(
                $"players/{escapedPlayerId}/combat/result",
                authorization,
                new CombatResultRequestDto(
                    EnergyCost: 0,
                    GoldReward: claim.GoldReward,
                    ExperienceReward: claim.ExperienceReward,
                    Message: message,
                    MissionId: $"campaign:{campaignId}",
                    Won: true,
                    RoundsCompleted: 0,
                    AttackerDamage: 0,
                    DefenderDamage: 0,
                    IdempotencyKey: $"{rewardKey}:progression"),
                InternalToken(configuration));
            if (progression.Error is not null)
            {
                return progression.Error;
            }

            var appliedProgression = progression.Value!;
            if (!appliedProgression.Completed)
            {
                return Results.Json(
                    new ErrorResponse(appliedProgression.Message),
                    statusCode: StatusCodes.Status409Conflict);
            }
        }

        if (claim.GoldReward > 0)
        {
            var walletCredit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
                $"players/{escapedPlayerId}/wallet/credit",
                authorization,
                new WalletCreditRequestDto(
                    Amount: claim.GoldReward,
                    EntryType: "campaign_reward",
                    Reason: message,
                    IdempotencyKey: $"{rewardKey}:gold"),
                InternalToken(configuration));
            if (walletCredit.Error is not null)
            {
                return walletCredit.Error;
            }

            var credit = walletCredit.Value!;
            if (!credit.Completed)
            {
                return Results.Json(
                    new ErrorResponse(credit.Message),
                    statusCode: StatusCodes.Status409Conflict);
            }
        }

        return null;
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }

    private static string QueryString(params (string Name, string? Value)[] values)
    {
        var pairs = values
            .Where(value => !string.IsNullOrWhiteSpace(value.Value))
            .Select(value => $"{Uri.EscapeDataString(value.Name)}={Uri.EscapeDataString(value.Value!)}")
            .ToArray();
        return pairs.Length == 0 ? string.Empty : $"?{string.Join("&", pairs)}";
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
                new ErrorResponse("You cannot manage another player's campaign."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }
}

internal sealed record CampaignCreateGatewayRequest(
    string? CountryId,
    string? Name,
    string? Description,
    string? CampaignType,
    int? ObjectiveScore,
    DateTimeOffset? EndsAt);

internal sealed record CampaignCreateForwardRequest(
    string? CountryId,
    string? Name,
    string? Description,
    string? CampaignType,
    int? ObjectiveScore,
    DateTimeOffset? EndsAt,
    string IdempotencyKey);

internal sealed record CampaignRewardClaimForwardRequest(string IdempotencyKey);

internal sealed record UnitDivisionCreateGatewayRequest(
    string? CampaignId,
    string? Name,
    string? DivisionRole,
    int MemberCount,
    int AssignedStrength);

internal sealed record UnitDivisionCreateForwardRequest(
    string? CampaignId,
    string? Name,
    string? DivisionRole,
    int MemberCount,
    int AssignedStrength,
    string IdempotencyKey);

internal sealed record DeploymentOrderCreateGatewayRequest(
    string? CampaignId,
    string? DivisionId,
    string? TargetBattleId,
    string? OrderType,
    string? Title,
    string? Description,
    int TroopCommitment);

internal sealed record DeploymentOrderCreateForwardRequest(
    string? CampaignId,
    string? DivisionId,
    string? TargetBattleId,
    string? OrderType,
    string? Title,
    string? Description,
    int TroopCommitment,
    string IdempotencyKey);

internal sealed record CampaignMutationResultDto(
    bool Completed,
    string Message,
    CampaignSummaryDto? Campaign,
    BattlePhaseDto? Phase,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignRewardClaimResultDto(
    bool Completed,
    string Message,
    CampaignSummaryDto? Campaign,
    CampaignRewardClaimDto? Claim,
    DateTimeOffset UpdatedAt);

internal sealed record UnitDivisionMutationResultDto(
    bool Completed,
    string Message,
    UnitDivisionDto? Division,
    DateTimeOffset UpdatedAt);

internal sealed record DeploymentOrderMutationResultDto(
    bool Completed,
    string Message,
    DeploymentOrderDto? Order,
    DateTimeOffset UpdatedAt);

internal sealed record CampaignSummaryDto(
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

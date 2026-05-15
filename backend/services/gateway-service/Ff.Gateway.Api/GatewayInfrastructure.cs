internal static class InfrastructureGatewayEndpoints
{
    public static void MapInfrastructureGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/world/countries/{countryId}/infrastructure-projects", async (
            string countryId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateInfrastructureBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"countries/{Uri.EscapeDataString(countryId)}/infrastructure-projects",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCountryInfrastructureProjects");

        app.MapPost("/players/{playerId}/world/countries/{countryId}/infrastructure-projects/{projectId}/contribute", async (
            string playerId,
            string countryId,
            string projectId,
            CountryInfrastructureGatewayContributionRequest contributionRequest,
            HttpRequest request,
            EconomyServiceClient economy,
            WorldServiceClient world,
            PlayerServiceClient players,
            IConfiguration configuration,
            DevTokenValidator tokens,
            AntiAbuseStore antiAbuse) =>
        {
            var access = ValidateInfrastructurePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            var goldAmount = Math.Max(0, contributionRequest.GoldAmount);
            var itemQuantity = Math.Max(0, contributionRequest.ItemQuantity);
            if (goldAmount == 0 && itemQuantity == 0)
            {
                return Results.BadRequest(new ErrorResponse("Gold amount or item quantity must be positive."));
            }

            var antiAbuseDecision = await antiAbuse.EnforceAsync(
                AntiAbuseRules.InfrastructureContribute,
                new AntiAbuseCheck(
                    access.PlayerId!,
                    "/players/{playerId}/world/countries/{countryId}/infrastructure-projects/{projectId}/contribute",
                    "infrastructure_project",
                    projectId,
                    idempotencyKey,
                    new
                    {
                        CountryId = countryId,
                        ProjectId = projectId,
                        GoldAmount = goldAmount,
                        ItemQuantity = itemQuantity,
                        contributionRequest.ItemId
                    }));
            if (antiAbuseDecision.Error is not null)
            {
                return antiAbuseDecision.Error;
            }

            var authorization = request.Headers.Authorization.ToString();
            var infrastructure = await world.GetJsonAsync<CountryInfrastructureResponseDto>(
                $"countries/{Uri.EscapeDataString(countryId)}/infrastructure-projects",
                authorization);
            if (infrastructure.Error is not null)
            {
                return infrastructure.Error;
            }

            var project = infrastructure.Value!.Projects.FirstOrDefault(candidate =>
                string.Equals(candidate.ProjectId, projectId, StringComparison.OrdinalIgnoreCase));
            if (project is null)
            {
                return Results.NotFound(new ErrorResponse("Infrastructure project was not found."));
            }

            var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
            var actionId = string.Join(':',
                "infra",
                "contrib",
                access.PlayerId!.ToLowerInvariant(),
                countryId.Trim().ToLowerInvariant(),
                projectId.Trim().ToLowerInvariant(),
                idempotencyKey.ToLowerInvariant());
            var itemId = NormalizeContributionItemId(contributionRequest.ItemId, project.TargetItemId);
            if (itemQuantity > 0 &&
                !string.Equals(itemId, project.TargetItemId, StringComparison.OrdinalIgnoreCase))
            {
                return Results.BadRequest(new ErrorResponse(
                    $"This project needs {project.TargetItemName}, not {contributionRequest.ItemId}."));
            }

            WalletDebitResponseDto? debitResult = null;
            if (goldAmount > 0)
            {
                var debit = await economy.PostJsonAsync<WalletDebitRequestDto, WalletDebitResponseDto>(
                    $"players/{escapedPlayerId}/wallet/debit",
                    authorization,
                    new WalletDebitRequestDto(
                        Amount: goldAmount,
                        EntryType: "infrastructure_contribution",
                        Reason: $"Contributed {goldAmount} gold to {project.Name}.",
                        IdempotencyKey: $"{actionId}:debit"),
                    InternalInfrastructureToken(configuration));
                if (debit.Error is not null)
                {
                    return debit.Error;
                }

                debitResult = debit.Value!;
                if (!debitResult.Completed)
                {
                    return Results.Json(
                        new ErrorResponse(debitResult.Message),
                        statusCode: StatusCodes.Status409Conflict);
                }
            }

            InventoryMutationResponseDto? itemRemovalResult = null;
            if (itemQuantity > 0)
            {
                var inventory = await economy.GetJsonAsync<InventoryResponseDto>(
                    $"players/{escapedPlayerId}/inventory",
                    authorization);
                if (inventory.Error is not null)
                {
                    var refundError = await RefundInfrastructureGoldAsync(
                        economy,
                        authorization,
                        configuration,
                        escapedPlayerId,
                        goldAmount,
                        $"{actionId}:refund",
                        "Refunded infrastructure gold because inventory could not be checked.");
                    return refundError ?? inventory.Error;
                }

                var item = inventory.Value!.Items.FirstOrDefault(candidate =>
                    string.Equals(candidate.ItemId, itemId, StringComparison.OrdinalIgnoreCase));
                if (item is null || item.Quantity < itemQuantity)
                {
                    var refundError = await RefundInfrastructureGoldAsync(
                        economy,
                        authorization,
                        configuration,
                        escapedPlayerId,
                        goldAmount,
                        $"{actionId}:refund",
                        "Refunded infrastructure gold because item contribution could not be reserved.");
                    return refundError ?? Results.Json(
                        new ErrorResponse($"You need {itemQuantity} {project.TargetItemName} to contribute to this project."),
                        statusCode: StatusCodes.Status409Conflict);
                }

                var removal = await economy.PostJsonAsync<InventoryRemovalRequestDto, InventoryMutationResponseDto>(
                    $"players/{escapedPlayerId}/inventory/remove",
                    authorization,
                    new InventoryRemovalRequestDto(
                        ItemId: item.ItemId,
                        ItemName: item.Name,
                        Category: item.Category,
                        Quantity: itemQuantity,
                        Reason: $"Contributed {itemQuantity} {item.Name} to {project.Name}.",
                        IdempotencyKey: $"{actionId}:item-remove"),
                    InternalInfrastructureToken(configuration));
                if (removal.Error is not null)
                {
                    var refundError = await RefundInfrastructureGoldAsync(
                        economy,
                        authorization,
                        configuration,
                        escapedPlayerId,
                        goldAmount,
                        $"{actionId}:refund",
                        "Refunded infrastructure gold because item contribution failed.");
                    return refundError ?? removal.Error;
                }

                itemRemovalResult = removal.Value!;
                if (!itemRemovalResult.Completed)
                {
                    var refundError = await RefundInfrastructureGoldAsync(
                        economy,
                        authorization,
                        configuration,
                        escapedPlayerId,
                        goldAmount,
                        $"{actionId}:refund",
                        itemRemovalResult.Message);
                    return refundError ?? Results.Json(
                        new ErrorResponse(itemRemovalResult.Message),
                        statusCode: StatusCodes.Status409Conflict);
                }
            }

            var worldContribution = await world.PostJsonAsync<
                CountryInfrastructureContributionServiceRequestDto,
                CountryInfrastructureContributionResultDto>(
                $"countries/{Uri.EscapeDataString(countryId)}/infrastructure-projects/{Uri.EscapeDataString(projectId)}/contribute",
                authorization,
                new CountryInfrastructureContributionServiceRequestDto(
                    PlayerId: access.PlayerId!,
                    GoldAmount: goldAmount,
                    ItemId: itemQuantity > 0 ? itemId : null,
                    ItemName: itemQuantity > 0 ? project.TargetItemName : null,
                    ItemCategory: itemQuantity > 0 ? project.TargetItemCategory : null,
                    ItemQuantity: itemQuantity,
                    IdempotencyKey: actionId),
                InternalInfrastructureToken(configuration));
            if (worldContribution.Error is not null)
            {
                var compensationError = await CompensateInfrastructureContributionAsync(
                    economy,
                    authorization,
                    configuration,
                    escapedPlayerId,
                    actionId,
                    goldAmount,
                    itemQuantity,
                    itemRemovalResult,
                    project,
                    "Refunded infrastructure contribution because world service did not accept it.");
                return compensationError ?? worldContribution.Error;
            }

            var contribution = worldContribution.Value!;
            if (!contribution.Completed)
            {
                var compensationError = await CompensateInfrastructureContributionAsync(
                    economy,
                    authorization,
                    configuration,
                    escapedPlayerId,
                    actionId,
                    goldAmount,
                    itemQuantity,
                    itemRemovalResult,
                    project,
                    contribution.Message);
                return compensationError ?? Results.Json(
                    new ErrorResponse(contribution.Message),
                    statusCode: StatusCodes.Status409Conflict);
            }

            var onboarding = await OnboardingGatewayTracker.TrackAsync(
                players,
                access.PlayerId!,
                authorization,
                configuration,
                "infrastructure_contribution",
                $"onboarding:infrastructure:{access.PlayerId!.ToLowerInvariant()}:{project.ProjectId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}");
            if (onboarding.Error is not null)
            {
                return onboarding.Error;
            }

            await AchievementGatewayEndpoints.TrackAsync(
                players,
                access.PlayerId!,
                authorization,
                configuration,
                "infrastructure_contribution",
                $"achievement:infrastructure:{access.PlayerId!.ToLowerInvariant()}:{project.ProjectId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}",
                app.Logger,
                relatedId: project.ProjectId);

            return Results.Ok(new CountryInfrastructureGatewayContributionResponseDto(
                Completed: true,
                Message: contribution.Message,
                Project: contribution.Project,
                Contribution: contribution.Contribution,
                Infrastructure: contribution.Infrastructure,
                Inventory: itemRemovalResult?.Inventory ?? debitResult?.Inventory,
                Onboarding: onboarding.Value,
                UpdatedAt: DateTimeOffset.UtcNow));
        }).WithName("ContributeGatewayCountryInfrastructureProject");
    }

    private static string NormalizeContributionItemId(string? requestedItemId, string targetItemId)
    {
        var itemId = string.IsNullOrWhiteSpace(requestedItemId)
            ? targetItemId
            : requestedItemId;
        return itemId.Trim().ToLowerInvariant();
    }

    private static async Task<IResult?> RefundInfrastructureGoldAsync(
        EconomyServiceClient economy,
        string authorization,
        IConfiguration configuration,
        string escapedPlayerId,
        int goldAmount,
        string idempotencyKey,
        string reason)
    {
        if (goldAmount <= 0)
        {
            return null;
        }

        var refund = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
            $"players/{escapedPlayerId}/wallet/credit",
            authorization,
            new WalletCreditRequestDto(
                Amount: goldAmount,
                EntryType: "infrastructure_refund",
                Reason: reason,
                IdempotencyKey: idempotencyKey),
            InternalInfrastructureToken(configuration));
        return refund.Error;
    }

    private static async Task<IResult?> CompensateInfrastructureContributionAsync(
        EconomyServiceClient economy,
        string authorization,
        IConfiguration configuration,
        string escapedPlayerId,
        string actionId,
        int goldAmount,
        int itemQuantity,
        InventoryMutationResponseDto? itemRemovalResult,
        CountryInfrastructureProjectDto project,
        string reason)
    {
        var refundError = await RefundInfrastructureGoldAsync(
            economy,
            authorization,
            configuration,
            escapedPlayerId,
            goldAmount,
            $"{actionId}:refund",
            reason);
        if (refundError is not null)
        {
            return refundError;
        }

        if (itemRemovalResult is null)
        {
            return null;
        }

        var grant = await economy.PostJsonAsync<InventoryGrantRequestDto, InventoryMutationResponseDto>(
            $"players/{escapedPlayerId}/inventory/grant",
            authorization,
            new InventoryGrantRequestDto(
                ItemId: project.TargetItemId,
                ItemName: project.TargetItemName,
                Category: project.TargetItemCategory,
                Quantity: itemQuantity,
                EntryType: "infrastructure_refund",
                Reason: reason,
                IdempotencyKey: $"{actionId}:item-grant"),
            InternalInfrastructureToken(configuration));
        return grant.Error;
    }

    private static IResult? ValidateInfrastructureBearer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? null
            : Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized);
    }

    private static PlayerAccessResult ValidateInfrastructurePlayerAccess(
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

        if (!string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase) &&
            !token.Roles.Contains("admin", StringComparer.OrdinalIgnoreCase))
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("You cannot access another player profile."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(
            string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase)
                ? token.PlayerId!
                : playerId);
    }

    private static string InternalInfrastructureToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed record CountryInfrastructureGatewayContributionRequest(
    int GoldAmount,
    int ItemQuantity,
    string? ItemId = null);

internal sealed record CountryInfrastructureGatewayContributionResponseDto(
    bool Completed,
    string Message,
    CountryInfrastructureProjectDto? Project,
    CountryInfrastructureContributionDto? Contribution,
    CountryInfrastructureResponseDto? Infrastructure,
    InventoryResponseDto? Inventory,
    OnboardingQuestlineResponseDto? Onboarding,
    DateTimeOffset UpdatedAt);

internal sealed record CountryInfrastructureResponseDto(
    string CountryId,
    string Name,
    string Code,
    CountryInfrastructureProjectDto[] Projects,
    CountryInfrastructureContributionDto[] RecentContributions,
    bool CanContribute,
    string ContributionMessage,
    DateTimeOffset UpdatedAt);

internal sealed record CountryInfrastructureProjectDto(
    string ProjectId,
    string CountryId,
    string ProjectType,
    string Name,
    string Description,
    int Level,
    int TargetGold,
    int ContributedGold,
    string TargetItemId,
    string TargetItemName,
    string TargetItemCategory,
    int TargetItemQuantity,
    int ContributedItemQuantity,
    string BonusType,
    int BonusPercentPerLevel,
    int ActiveBonusPercent,
    int DisplayOrder,
    DateTimeOffset UpdatedAt);

internal sealed record CountryInfrastructureContributionDto(
    string ContributionId,
    string ProjectId,
    string CountryId,
    string PlayerId,
    int GoldAmount,
    string ItemId,
    string ItemName,
    string ItemCategory,
    int ItemQuantity,
    int LevelsCompleted,
    DateTimeOffset CreatedAt);

internal sealed record CountryInfrastructureContributionServiceRequestDto(
    string PlayerId,
    int GoldAmount,
    string? ItemId,
    string? ItemName,
    string? ItemCategory,
    int ItemQuantity,
    string IdempotencyKey);

internal sealed record CountryInfrastructureContributionResultDto(
    bool Completed,
    string Message,
    CountryInfrastructureProjectDto? Project,
    CountryInfrastructureContributionDto? Contribution,
    CountryInfrastructureResponseDto? Infrastructure,
    int StatusCode);

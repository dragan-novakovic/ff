internal static class WorkforceGatewayEndpoints
{
    public static void MapWorkforceGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/workforce/jobs", async (
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await production.GetAsync(
                $"workforce/jobs?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
                request.Headers.Authorization.ToString());
        }).WithName("ListGatewayWorkforceJobs");

        app.MapGet("/companies/{companyId}/jobs", async (
            string companyId,
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await production.GetAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/jobs?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
                request.Headers.Authorization.ToString());
        }).WithName("ListGatewayCompanyJobs");

        app.MapPost("/companies/{companyId}/jobs", async (
            string companyId,
            CompanyJobPostingGatewayRequest requestBody,
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateJobPostingRequest(requestBody);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            return await production.PostJsonForwardAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/jobs",
                request.Headers.Authorization.ToString(),
                ToProductionRequest(access.PlayerId!, requestBody));
        }).WithName("CreateGatewayCompanyJob");

        app.MapPost("/companies/{companyId}/jobs/{jobId}", async (
            string companyId,
            string jobId,
            CompanyJobPostingGatewayRequest requestBody,
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateJobPostingRequest(requestBody);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            return await production.PostJsonForwardAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/jobs/{Uri.EscapeDataString(jobId)}",
                request.Headers.Authorization.ToString(),
                ToProductionRequest(access.PlayerId!, requestBody));
        }).WithName("UpdateGatewayCompanyJob");

        app.MapPost("/companies/{companyId}/jobs/{jobId}/close", async (
            string companyId,
            string jobId,
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await production.PostJsonForwardAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/jobs/{Uri.EscapeDataString(jobId)}/close",
                request.Headers.Authorization.ToString(),
                new CompanyActorRequest(access.PlayerId!));
        }).WithName("CloseGatewayCompanyJob");

        app.MapPost("/players/{playerId}/companies/{companyId}/jobs/{jobId}/work", async (
            string playerId,
            string companyId,
            string jobId,
            HttpRequest request,
            PlayerServiceClient players,
            EconomyServiceClient economy,
            ProductionServiceClient production,
            WorldServiceClient world,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            var authorization = request.Headers.Authorization.ToString();
            var escapedCompanyId = Uri.EscapeDataString(companyId);
            var escapedJobId = Uri.EscapeDataString(jobId);
            var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);

            var jobResult = await production.GetJsonAsync<CompanyJobPostingDto>(
                $"companies/{escapedCompanyId}/jobs/{escapedJobId}?actorPlayerId={escapedPlayerId}",
                authorization);
            if (jobResult.Error is not null)
            {
                return jobResult.Error;
            }

            var job = jobResult.Value!;
            if (!job.IsActive)
            {
                return Results.Json(
                    new ErrorResponse("Company job is not active."),
                    statusCode: StatusCodes.Status409Conflict);
            }

            if (job.RequiredEnergy > 0)
            {
                var stateResult = await players.GetJsonAsync<PlayerStateForEnergyDto>(
                    $"players/{escapedPlayerId}/state",
                    authorization);
                if (stateResult.Error is not null)
                {
                    return stateResult.Error;
                }

                if (stateResult.Value!.Energy < job.RequiredEnergy)
                {
                    return Results.Json(
                        new ErrorResponse($"Not enough energy. Required {job.RequiredEnergy}, available {stateResult.Value.Energy}."),
                        statusCode: StatusCodes.Status409Conflict);
                }
            }

            var taxContextResult = await TreasuryGatewayEndpoints.GetPlayerTaxContextAsync(
                world,
                configuration,
                access.PlayerId!,
                authorization);
            if (taxContextResult.Error is not null)
            {
                return taxContextResult.Error;
            }

            var taxContext = taxContextResult.Value;
            var incomeTaxRate = taxContext?.Treasury.Policy.IncomeTaxRate ?? 0;
            var taxAmount = TreasuryGatewayEndpoints.CalculateTaxAmount(job.WageGold, incomeTaxRate);
            var netWage = Math.Max(0, job.WageGold - taxAmount);

            var begin = await production.PostJsonAsync<CompanyWorkRequestDto, CompanyWorkResultDto>(
                $"companies/{escapedCompanyId}/jobs/{escapedJobId}/work",
                authorization,
                new CompanyWorkRequestDto(
                    ActorPlayerId: access.PlayerId!,
                    IdempotencyKey: idempotencyKey,
                    NetWageGold: netWage,
                    TaxGold: taxAmount));
            if (begin.Error is not null)
            {
                return begin.Error;
            }

            var workResult = begin.Value!;
            var taxCollections = new List<CountryTaxCollectionResponseDto>();
            DailyObjectivesResponseDto? dailyObjectives = null;
            InventoryResponseDto? wallet = null;

            if (string.Equals(workResult.WorkRecord.Status, "pending_credit", StringComparison.OrdinalIgnoreCase))
            {
                if (workResult.WorkRecord.NetWageGold > 0)
                {
                    var credit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
                        $"players/{escapedPlayerId}/wallet/credit",
                        authorization,
                        new WalletCreditRequestDto(
                            Amount: workResult.WorkRecord.NetWageGold,
                            EntryType: "company_wage",
                            Reason: $"Wage for {workResult.Job.Title} at {workResult.Job.CompanyName}.",
                            IdempotencyKey: $"{workResult.WorkRecord.IdempotencyKey}:wage"),
                        InternalToken(configuration));
                    if (credit.Error is not null)
                    {
                        return credit.Error;
                    }

                    if (!credit.Value!.Completed)
                    {
                        return Results.Json(
                            new ErrorResponse(credit.Value.Message),
                            statusCode: StatusCodes.Status409Conflict);
                    }

                    wallet = credit.Value.Inventory;
                }

                if (workResult.WorkRecord.TaxGold > 0 && taxContext is not null)
                {
                    var collection = await TreasuryGatewayEndpoints.CollectCountryTaxAsync(
                        world,
                        configuration,
                        authorization,
                        taxContext.Citizenship.CountryId,
                        workResult.WorkRecord.TaxGold,
                        workResult.WorkRecord.GrossWageGold,
                        incomeTaxRate,
                        "income_tax",
                        access.PlayerId!,
                        workResult.Job.CompanyId,
                        $"Income tax on workforce wage from {workResult.Job.CompanyName}.",
                        $"{workResult.WorkRecord.IdempotencyKey}:income-tax");
                    if (collection.Error is not null)
                    {
                        return collection.Error;
                    }

                    if (collection.Value is not null)
                    {
                        taxCollections.Add(collection.Value);
                    }
                }

                var complete = await production.PostJsonAsync<CompanyWorkCompletionRequestDto, CompanyWorkResultDto>(
                    $"companies/{escapedCompanyId}/jobs/{escapedJobId}/work/{Uri.EscapeDataString(workResult.WorkRecord.WorkId)}/complete",
                    authorization,
                    new CompanyWorkCompletionRequestDto(
                        ActorPlayerId: access.PlayerId!,
                        IdempotencyKey: idempotencyKey));
                if (complete.Error is not null)
                {
                    return complete.Error;
                }

                workResult = complete.Value!;
                var objectiveTrack = await TrackDailyObjectiveAsync(
                    players,
                    access.PlayerId!,
                    authorization,
                    configuration,
                    $"daily-objective:company-work:{workResult.WorkRecord.WorkId}");
                if (objectiveTrack.Error is not null)
                {
                    return objectiveTrack.Error;
                }

                dailyObjectives = objectiveTrack.Value;

                var onboardingTrack = await OnboardingGatewayTracker.TrackAsync(
                    players,
                    access.PlayerId!,
                    authorization,
                    configuration,
                    "company_action",
                    $"onboarding:company-action:{access.PlayerId!.ToLowerInvariant()}:{workResult.WorkRecord.WorkId.ToLowerInvariant()}");
                if (onboardingTrack.Error is not null)
                {
                    return onboardingTrack.Error;
                }
            }
            else
            {
                var inventory = await economy.GetJsonAsync<InventoryResponseDto>(
                    $"players/{escapedPlayerId}/inventory",
                    authorization);
                if (inventory.Error is not null)
                {
                    return inventory.Error;
                }

                wallet = inventory.Value;
            }

            var message = workResult.WorkRecord.TaxGold > 0 && taxContext is not null
                ? $"{workResult.Message} Paid {workResult.WorkRecord.TaxGold} gold income tax to {taxContext.Treasury.Name}."
                : workResult.Message;

            return Results.Ok(new CompanyWorkGatewayResult(
                Completed: workResult.Completed,
                Message: message,
                Job: workResult.Job,
                WorkRecord: workResult.WorkRecord,
                Assets: workResult.Assets,
                Wallet: wallet,
                TaxCollections: taxCollections.ToArray(),
                DailyObjectives: dailyObjectives));
        }).WithName("WorkGatewayCompanyJob");
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
                new ErrorResponse("You cannot access another player profile."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static PlayerAccessResult ValidateBearerPlayer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? PlayerAccessResult.Allowed(token.PlayerId!)
            : PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
    }

    private static string? ValidateJobPostingRequest(CompanyJobPostingGatewayRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return "Job title is required.";
        }

        if (request.WageGold <= 0)
        {
            return "Wage must be positive.";
        }

        if (request.RequiredEnergy < 0)
        {
            return "Required energy cannot be negative.";
        }

        if (request.DailyLimit <= 0)
        {
            return "Daily limit must be positive.";
        }

        if (request.ProductivityReward <= 0)
        {
            return "Productivity reward must be positive.";
        }

        return null;
    }

    private static CompanyJobPostingRequestDto ToProductionRequest(
        string actorPlayerId,
        CompanyJobPostingGatewayRequest request)
    {
        return new CompanyJobPostingRequestDto(
            ActorPlayerId: actorPlayerId,
            Title: request.Title,
            Description: request.Description,
            WageGold: request.WageGold,
            RequiredEnergy: request.RequiredEnergy,
            DailyLimit: request.DailyLimit,
            ProductivityReward: request.ProductivityReward,
            IsActive: request.IsActive);
    }

    private static async Task<ServiceJsonResult<DailyObjectivesResponseDto>> TrackDailyObjectiveAsync(
        PlayerServiceClient players,
        string playerId,
        string authorization,
        IConfiguration configuration,
        string idempotencyKey)
    {
        return await players.PostJsonAsync<DailyObjectiveTrackRequestDto, DailyObjectivesResponseDto>(
            $"players/{Uri.EscapeDataString(playerId)}/daily-objectives/track",
            authorization,
            new DailyObjectiveTrackRequestDto(
                ActionType: "work",
                Quantity: 1,
                IdempotencyKey: idempotencyKey.ToLowerInvariant()),
            InternalToken(configuration));
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed record CompanyJobPostingGatewayRequest(
    string? Title,
    string? Description,
    int WageGold,
    int RequiredEnergy,
    int DailyLimit,
    int ProductivityReward,
    bool? IsActive);

internal sealed record CompanyJobPostingRequestDto(
    string ActorPlayerId,
    string? Title,
    string? Description,
    int WageGold,
    int RequiredEnergy,
    int DailyLimit,
    int ProductivityReward,
    bool? IsActive);

internal sealed record CompanyWorkRequestDto(
    string ActorPlayerId,
    string IdempotencyKey,
    int NetWageGold,
    int TaxGold);

internal sealed record CompanyWorkCompletionRequestDto(
    string ActorPlayerId,
    string IdempotencyKey);

internal sealed record CompanyJobListResponseDto(
    string? CompanyId,
    CompanyJobPostingDto[] Jobs,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyJobPostingDto(
    string JobId,
    string CompanyId,
    string CompanyName,
    string Title,
    string Description,
    int WageGold,
    int RequiredEnergy,
    int DailyLimit,
    int ProductivityReward,
    string Status,
    bool IsActive,
    string CreatedByPlayerId,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ClosedAt,
    int WorkCount,
    int TodayWorkCount);

internal sealed record CompanyWorkResultDto(
    bool Completed,
    string Message,
    CompanyJobPostingDto Job,
    CompanyWorkRecordDto WorkRecord,
    CompanyAssetsDto? Assets);

internal sealed record CompanyWorkGatewayResult(
    bool Completed,
    string Message,
    CompanyJobPostingDto Job,
    CompanyWorkRecordDto WorkRecord,
    CompanyAssetsDto? Assets,
    InventoryResponseDto? Wallet,
    CountryTaxCollectionResponseDto[] TaxCollections,
    DailyObjectivesResponseDto? DailyObjectives);

internal sealed record CompanyWorkRecordDto(
    string WorkId,
    string JobId,
    string CompanyId,
    string PlayerId,
    string IdempotencyKey,
    int GrossWageGold,
    int NetWageGold,
    int TaxGold,
    int RequiredEnergy,
    int ProductivityReward,
    string Status,
    DateOnly WorkDate,
    DateTimeOffset WorkedAt,
    DateTimeOffset? PaidAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyAssetsDto(
    string CompanyId,
    int WalletGold,
    int StorageUsed,
    int StorageLimit,
    InventoryItemDto[] Inventory,
    FactoryDto[] Factories,
    ProductionJobDto[] ProductionJobs,
    CompanyJobPostingDto[] WorkforceJobs,
    CompanyWorkRecordDto[] WorkRecords,
    DateTimeOffset UpdatedAt,
    CompanyUpgradeStateDto? Upgrades = null);

internal sealed record CompanyUpgradeStateDto(
    string CompanyId,
    int HqLevel,
    string Specialization,
    int FactorySlots,
    int UsedFactorySlots,
    int AvailableFactorySlots,
    int StorageUsed,
    int StorageLimit,
    int ProductivityBonusPercent,
    CompanyUpgradeQuoteDto NextHqUpgrade,
    CompanySpecializationOptionDto[] SpecializationOptions,
    bool CanManageUpgrades,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyUpgradeQuoteDto(
    string UpgradeType,
    int CurrentLevel,
    int NextLevel,
    int GoldCost,
    string RequiredItemId,
    string RequiredItemName,
    int RequiredItemQuantity,
    int AvailableGold,
    int AvailableItemQuantity,
    int StorageLimitAfterUpgrade,
    int FactorySlotsAfterUpgrade,
    int ProductivityBonusPercentAfterUpgrade,
    bool CanUpgrade,
    string Message);

internal sealed record CompanySpecializationOptionDto(
    string Specialization,
    string Name,
    string Description,
    string AffectedCategory,
    int ProductivityBonusPercent,
    bool IsSelected,
    int GoldCost,
    string RequiredItemId,
    string RequiredItemName,
    int RequiredItemQuantity);

using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterDev", policy =>
    {
        policy
            .WithOrigins(
                "http://127.0.0.1:8080",
                "http://localhost:8080",
                "http://127.0.0.1:8088",
                "http://localhost:8088")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});
builder.Services.AddHttpClient<IdentityServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_IDENTITY_BASE_URL"]
        ?? builder.Configuration["Services:Identity:BaseUrl"]
        ?? "http://127.0.0.1:5125";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<PlayerServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_PLAYER_BASE_URL"]
        ?? builder.Configuration["Services:Player:BaseUrl"]
        ?? "http://127.0.0.1:5192";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<EconomyServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_ECONOMY_BASE_URL"]
        ?? builder.Configuration["Services:Economy:BaseUrl"]
        ?? "http://127.0.0.1:5141";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<ProductionServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_PRODUCTION_BASE_URL"]
        ?? builder.Configuration["Services:Production:BaseUrl"]
        ?? "http://127.0.0.1:5148";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<ResearchServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_RESEARCH_BASE_URL"]
        ?? builder.Configuration["Services:Research:BaseUrl"]
        ?? "http://127.0.0.1:5268";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<MarketServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_MARKET_BASE_URL"]
        ?? builder.Configuration["Services:Market:BaseUrl"]
        ?? "http://127.0.0.1:5275";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<CombatServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_COMBAT_BASE_URL"]
        ?? builder.Configuration["Services:Combat:BaseUrl"]
        ?? "http://127.0.0.1:8081";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<SocialChatServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_SOCIAL_CHAT_BASE_URL"]
        ?? builder.Configuration["Services:SocialChat:BaseUrl"]
        ?? "http://127.0.0.1:5096";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<WorldServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_WORLD_BASE_URL"]
        ?? builder.Configuration["Services:World:BaseUrl"]
        ?? "http://127.0.0.1:5205";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<NotificationServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_NOTIFICATION_BASE_URL"]
        ?? builder.Configuration["Services:Notification:BaseUrl"]
        ?? "http://127.0.0.1:5210";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddHttpClient<AdminServiceClient>(client =>
{
    var baseUrl = builder.Configuration["FF_ADMIN_BASE_URL"]
        ?? builder.Configuration["Services:Admin:BaseUrl"]
        ?? "http://127.0.0.1:5130";
    client.BaseAddress = new Uri(baseUrl);
});
builder.Services.AddSingleton<DevTokenValidator>();
builder.Services.AddSingleton<AntiAbuseStore>();

var metadata = new ServiceMetadata(
    Service: "gateway-service",
    DisplayName: "API Gateway / BFF",
    Domain: "Client-facing API gateway and backend-for-frontend",
    Description: "Public REST entrypoint for Flutter clients that will verify auth, route requests, and shape mobile-friendly responses.",
    Owns: ["request routing", "API versioning", "client response shaping"],
    Responsibilities: ["Verify OIDC/JWT bearer tokens", "Route auth and profile requests to identity-service", "Route requests to backend services", "Apply client-facing rate limits"]);

var app = builder.Build();
app.UseCors("FlutterDev");

var antiAbuseStore = app.Services.GetRequiredService<AntiAbuseStore>();
await antiAbuseStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/anti-abuse/rules", (HttpRequest request, DevTokenValidator tokens) =>
{
    var access = ValidateBearerPlayer(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(new AntiAbuseRulesResponse(AntiAbuseRules.All, DateTimeOffset.UtcNow));
}).WithName("GetAntiAbuseRules");

app.MapGet("/world/countries", async (
    HttpRequest request,
    WorldServiceClient world,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    return await world.GetAsync("countries", request.Headers.Authorization.ToString());
}).WithName("GetWorldCountries");

app.MapGet("/world/countries/{countryId}", async (
    string countryId,
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
        $"countries/{Uri.EscapeDataString(countryId)}",
        request.Headers.Authorization.ToString());
}).WithName("GetWorldCountry");

app.MapGet("/world/regions", async (
    HttpRequest request,
    WorldServiceClient world,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    var countryId = request.Query["countryId"].ToString();
    var query = string.IsNullOrWhiteSpace(countryId)
        ? string.Empty
        : $"?countryId={Uri.EscapeDataString(countryId)}";
    return await world.GetAsync($"regions{query}", request.Headers.Authorization.ToString());
}).WithName("GetWorldRegions");

app.MapGet("/world/regions/{regionId}", async (
    string regionId,
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
        $"regions/{Uri.EscapeDataString(regionId)}",
        request.Headers.Authorization.ToString());
}).WithName("GetWorldRegion");

app.MapTerritoryGatewayEndpoints();

app.MapPost("/auth/login", async (LoginRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/login", request)).WithName("Login");

app.MapPost("/auth/register", async (RegisterRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/register", request)).WithName("Register");

app.MapPost("/auth/refresh", async (RefreshRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/refresh", request)).WithName("Refresh");

app.MapPost("/auth/logout", async (
    LogoutRequest requestBody,
    HttpRequest request,
    IdentityServiceClient identity) =>
    await identity.PostAsync("auth/logout", requestBody, request.Headers.Authorization.ToString())).WithName("Logout");

app.MapGet("/auth/me", async (
    HttpRequest request,
    IdentityServiceClient identity,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    return await identity.GetAsync("auth/me", request.Headers.Authorization.ToString());
}).WithName("GetCurrentAccount");

app.MapGet("/auth/sessions", async (
    HttpRequest request,
    IdentityServiceClient identity,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    return await identity.GetAsync("auth/sessions", request.Headers.Authorization.ToString());
}).WithName("GetRefreshSessions");

app.MapPost("/auth/sessions/revoke-all", async (
    HttpRequest request,
    IdentityServiceClient identity,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    return await identity.PostAsync("auth/sessions/revoke-all", new { }, request.Headers.Authorization.ToString());
}).WithName("RevokeAllRefreshSessions");

app.MapPost("/auth/password-reset/request", async (PasswordResetRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/password-reset/request", request)).WithName("RequestPasswordReset");

app.MapPost("/auth/password-reset/confirm", async (PasswordResetConfirmRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/password-reset/confirm", request)).WithName("ConfirmPasswordReset");

app.MapPost("/auth/email-verification/request", async (
    HttpRequest request,
    IdentityServiceClient identity,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    return await identity.PostAsync("auth/email-verification/request", new { }, request.Headers.Authorization.ToString());
}).WithName("RequestEmailVerification");

app.MapPost("/auth/email-verification/confirm", async (EmailVerificationConfirmRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/email-verification/confirm", request)).WithName("ConfirmEmailVerification");

app.MapGet("/players/{playerId}", async (
    string playerId,
    HttpRequest request,
    IdentityServiceClient identity,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await identity.GetAsync($"players/{Uri.EscapeDataString(access.PlayerId!)}");
}).WithName("GetPlayer");

app.MapGet("/players/{playerId}/public", GetPublicPlayerProfile)
    .WithName("GetPublicPlayerProfile");

app.MapGet("/public/players/{playerId}", GetPublicPlayerProfile)
    .WithName("GetPublicPlayerProfileAlias");

app.MapGet("/rankings/leaderboard", GetPublicRankings)
    .WithName("GetRankingsLeaderboard");

app.MapGet("/public/rankings", GetPublicRankings)
    .WithName("GetPublicRankingsAlias");

app.MapGet("/rankings/player/{playerId}", GetPublicPlayerRanking)
    .WithName("GetPlayerRanking");

app.MapGet("/players/{playerId}/state", async (
    string playerId,
    HttpRequest request,
    PlayerServiceClient players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await players.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/state",
        request.Headers.Authorization.ToString());
}).WithName("GetPlayerState");

app.MapGet("/players/{playerId}/daily-objectives", async (
    string playerId,
    HttpRequest request,
    PlayerServiceClient players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await players.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/daily-objectives",
        request.Headers.Authorization.ToString());
}).WithName("GetGatewayDailyObjectives");

app.MapPost("/players/{playerId}/daily-objectives/{objectiveId}/claim", async (
    string playerId,
    string objectiveId,
    HttpRequest request,
    PlayerServiceClient players,
    EconomyServiceClient economy,
    WorldServiceClient world,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(objectiveId))
    {
        return Results.BadRequest(new ErrorResponse("Objective is required."));
    }

    var authorization = request.Headers.Authorization.ToString();
    var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
    var objectivesResult = await players.GetJsonAsync<DailyObjectivesResponseDto>(
        $"players/{escapedPlayerId}/daily-objectives",
        authorization);
    if (objectivesResult.Error is not null)
    {
        return objectivesResult.Error;
    }

    var objectives = objectivesResult.Value!;
    var objective = objectives.Objectives.FirstOrDefault(candidate =>
        string.Equals(candidate.ObjectiveId, objectiveId, StringComparison.OrdinalIgnoreCase));
    if (objective is null)
    {
        return Results.NotFound(new ErrorResponse("Daily objective was not found."));
    }

    if (!objective.Completed)
    {
        return Results.Json(
            new ErrorResponse("Daily objective is not complete yet."),
            statusCode: StatusCodes.Status409Conflict);
    }

    if (objective.Claimed)
    {
        return Results.Ok(new DailyObjectiveClaimGatewayResponse(
            Completed: true,
            Message: "Daily objective reward was already claimed.",
            Rewards: PlayerRewardsDto.None,
            State: null,
            Objective: objective,
            Objectives: objectives,
            Wallet: null));
    }

    var claimBase = $"daily-objective:{access.PlayerId!.ToLowerInvariant()}:{objective.ObjectiveId.ToLowerInvariant()}:{objective.ResetDate:yyyy-MM-dd}";
    InventoryResponseDto? wallet = null;
    if (objective.Rewards.Gold > 0)
    {
        var walletCredit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
            $"players/{escapedPlayerId}/wallet/credit",
            authorization,
            new WalletCreditRequestDto(
                Amount: objective.Rewards.Gold,
                EntryType: "daily_objective_reward",
                Reason: $"Daily objective reward: {objective.Title}.",
                IdempotencyKey: $"{claimBase}:gold"),
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

        wallet = credit.Inventory;
    }

    var claim = await players.PostJsonAsync<DailyObjectiveClaimRequestDto, DailyObjectiveClaimResponseDto>(
        $"players/{escapedPlayerId}/daily-objectives/{Uri.EscapeDataString(objective.ObjectiveId)}/claim",
        authorization,
        new DailyObjectiveClaimRequestDto($"{claimBase}:claim"),
        InternalToken(configuration));
    if (claim.Error is not null)
    {
        return claim.Error;
    }

    var claimed = claim.Value!;
    if (!claimed.Completed)
    {
        return Results.Json(
            new ErrorResponse(claimed.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    return Results.Ok(new DailyObjectiveClaimGatewayResponse(
        Completed: true,
        Message: claimed.Message,
        Rewards: claimed.Rewards,
        State: claimed.State,
        Objective: claimed.Objective,
        Objectives: claimed.Objectives,
        Wallet: wallet));
}).WithName("ClaimGatewayDailyObjective");

app.MapGet("/players/{playerId}/onboarding-questline", async (
    string playerId,
    HttpRequest request,
    PlayerServiceClient players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await players.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/onboarding-questline",
        request.Headers.Authorization.ToString());
}).WithName("GetGatewayOnboardingQuestline");

app.MapPost("/players/{playerId}/onboarding-questline/{questId}/claim", async (
    string playerId,
    string questId,
    HttpRequest request,
    PlayerServiceClient players,
    EconomyServiceClient economy,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(questId))
    {
        return Results.BadRequest(new ErrorResponse("Onboarding quest is required."));
    }

    var authorization = request.Headers.Authorization.ToString();
    var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
    var questlineResult = await players.GetJsonAsync<OnboardingQuestlineResponseDto>(
        $"players/{escapedPlayerId}/onboarding-questline",
        authorization);
    if (questlineResult.Error is not null)
    {
        return questlineResult.Error;
    }

    var questline = questlineResult.Value!;
    var quest = questline.Quests.FirstOrDefault(candidate =>
        string.Equals(candidate.QuestId, questId, StringComparison.OrdinalIgnoreCase));
    if (quest is null)
    {
        return Results.NotFound(new ErrorResponse("Onboarding quest was not found."));
    }

    if (quest.Skipped)
    {
        return Results.Json(
            new ErrorResponse("Skipped onboarding quests cannot be claimed."),
            statusCode: StatusCodes.Status409Conflict);
    }

    if (!quest.Completed)
    {
        return Results.Json(
            new ErrorResponse("Onboarding quest is not complete yet."),
            statusCode: StatusCodes.Status409Conflict);
    }

    if (quest.Claimed)
    {
        return Results.Ok(new OnboardingQuestClaimGatewayResponse(
            Completed: true,
            Message: "Onboarding reward was already claimed.",
            Rewards: PlayerRewardsDto.None,
            State: null,
            Quest: quest,
            Questline: questline,
            Wallet: null));
    }

    var claimBase = $"onboarding:{access.PlayerId!.ToLowerInvariant()}:{quest.QuestId.ToLowerInvariant()}";
    InventoryResponseDto? wallet = null;
    if (quest.Rewards.Gold > 0)
    {
        var walletCredit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
            $"players/{escapedPlayerId}/wallet/credit",
            authorization,
            new WalletCreditRequestDto(
                Amount: quest.Rewards.Gold,
                EntryType: "onboarding_reward",
                Reason: $"Onboarding reward: {quest.Title}.",
                IdempotencyKey: $"{claimBase}:gold"),
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

        wallet = credit.Inventory;
    }

    var claim = await players.PostJsonAsync<OnboardingQuestClaimRequestDto, OnboardingQuestClaimResponseDto>(
        $"players/{escapedPlayerId}/onboarding-questline/{Uri.EscapeDataString(quest.QuestId)}/claim",
        authorization,
        new OnboardingQuestClaimRequestDto($"{claimBase}:claim"),
        InternalToken(configuration));
    if (claim.Error is not null)
    {
        return claim.Error;
    }

    var claimed = claim.Value!;
    if (!claimed.Completed)
    {
        return Results.Json(
            new ErrorResponse(claimed.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    if (string.Equals(claimed.Questline.Status, "completed", StringComparison.OrdinalIgnoreCase))
    {
        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "onboarding_complete",
            $"achievement:onboarding-complete:{access.PlayerId!.ToLowerInvariant()}",
            app.Logger);
    }

    return Results.Ok(new OnboardingQuestClaimGatewayResponse(
        Completed: true,
        Message: claimed.Message,
        Rewards: claimed.Rewards,
        State: claimed.State,
        Quest: claimed.Quest,
        Questline: claimed.Questline,
        Wallet: wallet));
}).WithName("ClaimGatewayOnboardingQuest");

app.MapPost("/players/{playerId}/onboarding-questline/{questId}/skip", async (
    string playerId,
    string questId,
    HttpRequest request,
    PlayerServiceClient players,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(questId))
    {
        return Results.BadRequest(new ErrorResponse("Onboarding quest is required."));
    }

    var skipKey = $"onboarding-skip:{access.PlayerId!.ToLowerInvariant()}:{questId.ToLowerInvariant()}";
    var skip = await players.PostJsonAsync<OnboardingQuestSkipRequestDto, OnboardingQuestSkipResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/onboarding-questline/{Uri.EscapeDataString(questId)}/skip",
        request.Headers.Authorization.ToString(),
        new OnboardingQuestSkipRequestDto(skipKey),
        InternalToken(configuration));
    if (skip.Error is not null)
    {
        return skip.Error;
    }

    var result = skip.Value!;
    if (result.Completed &&
        string.Equals(result.Questline.Status, "completed", StringComparison.OrdinalIgnoreCase))
    {
        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            request.Headers.Authorization.ToString(),
            configuration,
            "onboarding_complete",
            $"achievement:onboarding-complete:{access.PlayerId!.ToLowerInvariant()}",
            app.Logger);
    }

    return result.Completed
        ? Results.Ok(result)
        : Results.Json(new ErrorResponse(result.Message), statusCode: StatusCodes.Status409Conflict);
}).WithName("SkipGatewayOnboardingQuest");

app.MapGet("/players/{playerId}/citizenship", async (
    string playerId,
    HttpRequest request,
    WorldServiceClient world,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await world.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/citizenship",
        request.Headers.Authorization.ToString());
}).WithName("GetGatewayPlayerCitizenship");

app.MapPost("/players/{playerId}/citizenship/join", async (
    string playerId,
    CitizenshipRequest citizenshipRequest,
    HttpRequest request,
    WorldServiceClient world,
    PlayerServiceClient players,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(citizenshipRequest.CountryId))
    {
        return Results.BadRequest(new ErrorResponse("Country is required."));
    }

    var authorization = request.Headers.Authorization.ToString();
    var result = await world.PostJsonAsync<CitizenshipRequest, JsonElement>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/citizenship/join",
        authorization,
        citizenshipRequest);
    if (result.Error is not null)
    {
        return result.Error;
    }

    var mutation = result.Value;
    if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
    {
        var onboarding = await OnboardingGatewayTracker.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "choose_country",
            $"onboarding:choose-country:{access.PlayerId!.ToLowerInvariant()}");
        if (onboarding.Error is not null)
        {
            return onboarding.Error;
        }

        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "choose_country",
            $"achievement:choose-country:{access.PlayerId!.ToLowerInvariant()}",
            app.Logger,
            relatedId: citizenshipRequest.CountryId);
    }

    return Results.Json(mutation);
}).WithName("JoinGatewayCountry");

app.MapPost("/players/{playerId}/citizenship/change", async (
    string playerId,
    CitizenshipRequest citizenshipRequest,
    HttpRequest request,
    WorldServiceClient world,
    PlayerServiceClient players,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(citizenshipRequest.CountryId))
    {
        return Results.BadRequest(new ErrorResponse("Country is required."));
    }

    var authorization = request.Headers.Authorization.ToString();
    var result = await world.PostJsonAsync<CitizenshipRequest, JsonElement>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/citizenship/change",
        authorization,
        citizenshipRequest);
    if (result.Error is not null)
    {
        return result.Error;
    }

    var mutation = result.Value;
    if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
    {
        var onboarding = await OnboardingGatewayTracker.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "choose_country",
            $"onboarding:choose-country:{access.PlayerId!.ToLowerInvariant()}");
        if (onboarding.Error is not null)
        {
            return onboarding.Error;
        }

        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "choose_country",
            $"achievement:choose-country:{access.PlayerId!.ToLowerInvariant()}",
            app.Logger,
            relatedId: citizenshipRequest.CountryId);
    }

    return Results.Json(mutation);
}).WithName("ChangeGatewayCountry");

app.MapBattleGatewayEndpoints();
app.MapMilitaryUnitGatewayEndpoints();
app.MapCampaignGatewayEndpoints();
app.MapTreasuryGatewayEndpoints();
app.MapPoliticsGatewayEndpoints();
app.MapLawGatewayEndpoints();
app.MapDiplomacyGatewayEndpoints();
app.MapActivityGatewayEndpoints();
app.MapPushNotificationGatewayEndpoints();
app.MapAchievementGatewayEndpoints();
app.MapRealtimeGatewayEndpoints();
app.MapNewspaperGatewayEndpoints();
app.MapAdminGatewayEndpoints();
app.MapWorkforceGatewayEndpoints();
app.MapResearchGatewayEndpoints();
app.MapResourceLogisticsGatewayEndpoints();

app.MapPost("/players/{playerId}/work", async (
    string playerId,
    HttpRequest request,
    PlayerServiceClient players,
    EconomyServiceClient economy,
    WorldServiceClient world,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.Work,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/work",
            "player_action",
            "work",
            null,
            new { access.PlayerId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var work = await players.PostJsonAsync<object, PlayerActionResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/work",
        authorization,
        new { });
    if (work.Error is not null)
    {
        return work.Error;
    }

    var action = work.Value!;
    var shouldCreditWorkReward = action.Completed ||
        action.Message.Contains("already worked today", StringComparison.OrdinalIgnoreCase);
    var workGoldReward = action.Completed ? action.Rewards.Gold : 25;
    var taxCollections = new List<CountryTaxCollectionResponseDto>();
    DailyObjectivesResponseDto? dailyObjectives = null;
    if (shouldCreditWorkReward && workGoldReward > 0)
    {
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
        var incomeTaxAmount = TreasuryGatewayEndpoints.CalculateTaxAmount(workGoldReward, incomeTaxRate);
        var netWorkReward = Math.Max(0, workGoldReward - incomeTaxAmount);
        var creditReason = incomeTaxAmount > 0 && taxContext is not null
            ? $"{action.Message} Income tax {incomeTaxAmount} gold paid to {taxContext.Treasury.Name}."
            : action.Message;
        var walletCredit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/wallet/credit",
            authorization,
            new WalletCreditRequestDto(
                Amount: netWorkReward,
                EntryType: "work_reward",
                Reason: creditReason,
                IdempotencyKey: $"work:{access.PlayerId!.ToLowerInvariant()}:{DateTimeOffset.UtcNow:yyyy-MM-dd}"),
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

        if (incomeTaxAmount > 0 && taxContext is not null)
        {
            var collection = await TreasuryGatewayEndpoints.CollectCountryTaxAsync(
                world,
                configuration,
                authorization,
                taxContext.Citizenship.CountryId,
                incomeTaxAmount,
                workGoldReward,
                incomeTaxRate,
                "income_tax",
                access.PlayerId!,
                null,
                $"Income tax on work reward for {access.PlayerId}.",
                $"tax:income:{access.PlayerId!.ToLowerInvariant()}:{DateTimeOffset.UtcNow:yyyy-MM-dd}");
            if (collection.Error is not null)
            {
                return collection.Error;
            }

            if (collection.Value is not null)
            {
                taxCollections.Add(collection.Value);
            }
        }

        action = action with { Wallet = credit.Inventory };
        if (incomeTaxAmount > 0 && taxContext is not null)
        {
            action = action with
            {
                Message = $"{action.Message} Paid {incomeTaxAmount} gold income tax to {taxContext.Treasury.Name}.",
                TaxCollections = taxCollections.ToArray()
            };
        }
    }

    if (shouldCreditWorkReward)
    {
        var objectiveTrack = await TrackDailyObjectiveAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "work",
            $"daily-objective:work:{access.PlayerId!.ToLowerInvariant()}:{DateTimeOffset.UtcNow:yyyy-MM-dd}");
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
            "work",
            $"onboarding:work:{access.PlayerId!.ToLowerInvariant()}");
        if (onboardingTrack.Error is not null)
        {
            return onboardingTrack.Error;
        }

        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "work",
            $"achievement:work:{access.PlayerId!.ToLowerInvariant()}:{DateTimeOffset.UtcNow:yyyy-MM-dd}",
            app.Logger);
    }

    return Results.Ok(action with { DailyObjectives = dailyObjectives });
}).WithName("Work");

app.MapPost("/players/{playerId}/train", async (
    string playerId,
    HttpRequest request,
    PlayerServiceClient players,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.Train,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/train",
            "player_action",
            "train",
            null,
            new { access.PlayerId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var train = await players.PostJsonAsync<object, PlayerActionResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/train",
        authorization,
        new { });
    if (train.Error is not null)
    {
        return train.Error;
    }

    var action = train.Value!;
    var shouldTrackTraining = action.Completed ||
        action.Message.Contains("already trained today", StringComparison.OrdinalIgnoreCase);
    DailyObjectivesResponseDto? dailyObjectives = null;
    if (shouldTrackTraining)
    {
        var objectiveTrack = await TrackDailyObjectiveAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "train",
            $"daily-objective:train:{access.PlayerId!.ToLowerInvariant()}:{DateTimeOffset.UtcNow:yyyy-MM-dd}");
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
            "train",
            $"onboarding:train:{access.PlayerId!.ToLowerInvariant()}");
        if (onboardingTrack.Error is not null)
        {
            return onboardingTrack.Error;
        }

        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "train",
            $"achievement:train:{access.PlayerId!.ToLowerInvariant()}:{DateTimeOffset.UtcNow:yyyy-MM-dd}",
            app.Logger);
    }

    return Results.Ok(action with { DailyObjectives = dailyObjectives });
}).WithName("Train");

app.MapPost("/players/{playerId}/hospital/recover", async (
    string playerId,
    HttpRequest request,
    PlayerServiceClient players,
    EconomyServiceClient economy,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
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

    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.HospitalRecover,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/hospital/recover",
            "player_action",
            "hospital_recover",
            idempotencyKey,
            new { access.PlayerId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
    var stateResult = await players.GetJsonAsync<PlayerStateForHospitalDto>(
        $"players/{escapedPlayerId}/state",
        authorization);
    if (stateResult.Error is not null)
    {
        return stateResult.Error;
    }

    var state = stateResult.Value!;
    var actionId = $"hospital:{access.PlayerId!.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}";
    var hospitalGoldCost = Math.Max(0, state.HospitalGoldCost);
    WalletDebitResponseDto? debitResult = null;
    if (hospitalGoldCost > 0)
    {
        var debit = await economy.PostJsonAsync<WalletDebitRequestDto, WalletDebitResponseDto>(
            $"players/{escapedPlayerId}/wallet/debit",
            authorization,
            new WalletDebitRequestDto(
                Amount: hospitalGoldCost,
                EntryType: "hospital_recovery",
                Reason: $"Paid {hospitalGoldCost} gold for hospital energy recovery.",
                IdempotencyKey: $"{actionId}:debit"),
            InternalToken(configuration));
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

    var recovery = await players.PostJsonAsync<HospitalRecoveryRequestDto, PlayerActionResponseDto>(
        $"players/{escapedPlayerId}/hospital/recover",
        authorization,
        new HospitalRecoveryRequestDto(IdempotencyKey: $"{actionId}:recover"),
        InternalToken(configuration));
    if (recovery.Error is not null)
    {
        if (debitResult is not null)
        {
            var refund = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
                $"players/{escapedPlayerId}/wallet/credit",
                authorization,
                new WalletCreditRequestDto(
                    Amount: hospitalGoldCost,
                    EntryType: "hospital_refund",
                    Reason: "Refunded hospital recovery because the player service did not complete recovery.",
                    IdempotencyKey: $"{actionId}:refund"),
                InternalToken(configuration));
            if (refund.Error is not null)
            {
                return refund.Error;
            }
        }

        return recovery.Error;
    }

    var action = recovery.Value!;
    if (!action.Completed)
    {
        if (debitResult is not null)
        {
            var refund = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
                $"players/{escapedPlayerId}/wallet/credit",
                authorization,
                new WalletCreditRequestDto(
                    Amount: hospitalGoldCost,
                    EntryType: "hospital_refund",
                    Reason: action.Message,
                    IdempotencyKey: $"{actionId}:refund"),
                InternalToken(configuration));
            if (refund.Error is not null)
            {
                return refund.Error;
            }
        }

        return Results.Json(action, statusCode: StatusCodes.Status409Conflict);
    }

    var message = hospitalGoldCost > 0
        ? $"{action.Message} Paid {hospitalGoldCost} gold."
        : action.Message;
    var objectiveTrack = await TrackDailyObjectiveAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "hospital_recover",
        $"daily-objective:hospital:{access.PlayerId!.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}");
    if (objectiveTrack.Error is not null)
    {
        return objectiveTrack.Error;
    }

    return Results.Ok(action with
    {
        Message = message,
        Wallet = debitResult?.Inventory,
        DailyObjectives = objectiveTrack.Value
    });
}).WithName("RecoverAtHospital");

app.MapGet("/players/{playerId}/inventory", async (
    string playerId,
    HttpRequest request,
    EconomyServiceClient economy,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await economy.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory",
        request.Headers.Authorization.ToString());
}).WithName("GetInventory");

app.MapGet("/players/{playerId}/ledger", async (
    string playerId,
    HttpRequest request,
    EconomyServiceClient economy,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var limit = request.Query["limit"].ToString();
    var query = string.IsNullOrWhiteSpace(limit)
        ? string.Empty
        : $"?limit={Uri.EscapeDataString(limit)}";
    return await economy.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/ledger{query}",
        request.Headers.Authorization.ToString());
}).WithName("GetPlayerLedger");

app.MapGet("/players/{playerId}/equipment", async (
    string playerId,
    HttpRequest request,
    EconomyServiceClient economy,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await economy.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/equipment",
        request.Headers.Authorization.ToString());
}).WithName("GetEquipment");

app.MapPost("/players/{playerId}/equipment/weapon/equip", async (
    string playerId,
    EquipWeaponGatewayRequest equipRequest,
    HttpRequest request,
    EconomyServiceClient economy,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(equipRequest.ItemId))
    {
        return Results.BadRequest(new ErrorResponse("Item is required."));
    }

    var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
    if (string.IsNullOrWhiteSpace(idempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
    }

    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.WeaponEquip,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/equipment/weapon/equip",
            "item",
            equipRequest.ItemId,
            idempotencyKey,
            new { equipRequest.ItemId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var actionId = $"equip:{access.PlayerId!.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}";
    var equip = await economy.PostJsonAsync<EquipWeaponRequestDto, EquipWeaponResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/equipment/weapon/equip",
        request.Headers.Authorization.ToString(),
        new EquipWeaponRequestDto(
            ItemId: equipRequest.ItemId,
            IdempotencyKey: actionId),
        InternalToken(configuration));
    if (equip.Error is not null)
    {
        return equip.Error;
    }

    var result = equip.Value!;
    return result.Completed
        ? Results.Ok(result)
        : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
}).WithName("EquipWeapon");

app.MapPost("/players/{playerId}/equipment/weapon/repair", async (
    string playerId,
    HttpRequest request,
    EconomyServiceClient economy,
    NotificationServiceClient notifications,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
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

    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.WeaponRepair,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/equipment/weapon/repair",
            "player_action",
            "weapon_repair",
            idempotencyKey,
            new { access.PlayerId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var repair = await economy.PostJsonAsync<RepairWeaponRequestDto, RepairWeaponResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/equipment/weapon/repair",
        request.Headers.Authorization.ToString(),
        new RepairWeaponRequestDto(
            IdempotencyKey: $"repair:{access.PlayerId!.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}"),
        InternalToken(configuration));
    if (repair.Error is not null)
    {
        return repair.Error;
    }

    var result = repair.Value!;
    if (result.Completed)
    {
        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            access.PlayerId!,
            "weapon_repair",
            result.Message,
            result.MaterialItemId,
            $"activity:weapon-repair:{access.PlayerId!.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}");
    }

    return result.Completed
        ? Results.Ok(result)
        : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
}).WithName("RepairWeapon");

app.MapPost("/players/{playerId}/inventory/items/{itemId}/use", async (
    string playerId,
    string itemId,
    HttpRequest request,
    PlayerServiceClient players,
    EconomyServiceClient economy,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var normalizedItemId = itemId.Trim().ToLowerInvariant();
    if (!string.Equals(normalizedItemId, "food", StringComparison.Ordinal))
    {
        return Results.BadRequest(new ErrorResponse("Only food can be used right now."));
    }

    var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
    if (string.IsNullOrWhiteSpace(idempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
    }

    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.InventoryUse,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/inventory/items/{itemId}/use",
            "item",
            normalizedItemId,
            idempotencyKey,
            new { ItemId = normalizedItemId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var stateResult = await players.GetJsonAsync<PlayerStateForEnergyDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/state",
        authorization);
    if (stateResult.Error is not null)
    {
        return stateResult.Error;
    }

    var state = stateResult.Value!;
    if (state.Energy >= state.MaxEnergy)
    {
        var currentInventory = await economy.GetJsonAsync<InventoryResponseDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory",
            authorization);
        if (currentInventory.Error is not null)
        {
            return currentInventory.Error;
        }

        return Results.Ok(new InventoryItemUseResponse(
            Completed: false,
            Message: "Energy is already full.",
            Inventory: currentInventory.Value!,
            PlayerAction: null));
    }

    var actionId = $"food:{access.PlayerId!.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}";
    var removal = await economy.PostJsonAsync<InventoryRemovalRequestDto, InventoryMutationResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory/remove",
        authorization,
        new InventoryRemovalRequestDto(
            ItemId: "food",
            ItemName: "Food",
            Category: "Consumable",
            Quantity: 1,
            Reason: "Used 1 Food to restore energy.",
            IdempotencyKey: $"{actionId}:consume"),
        InternalToken(configuration));
    if (removal.Error is not null)
    {
        return removal.Error;
    }

    var removalResult = removal.Value!;
    if (!removalResult.Completed)
    {
        return Results.Json(
            new ErrorResponse(removalResult.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    var restore = await players.PostJsonAsync<RestoreEnergyRequestDto, PlayerActionResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/energy/restore",
        authorization,
        new RestoreEnergyRequestDto(
            EnergyAmount: 20,
            Message: "Used food to restore energy.",
            IdempotencyKey: $"{actionId}:restore"),
        InternalToken(configuration));
    if (restore.Error is not null)
    {
        return restore.Error;
    }

    var restoreResult = restore.Value!;
    if (!restoreResult.Completed)
    {
        var refund = await economy.PostJsonAsync<InventoryGrantRequestDto, InventoryMutationResponseDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory/grant",
            authorization,
            new InventoryGrantRequestDto(
                ItemId: "food",
                ItemName: "Food",
                Category: "Consumable",
                Quantity: 1,
                EntryType: "food_refund",
                Reason: "Refunded food because energy could not be restored.",
                IdempotencyKey: $"{actionId}:refund"),
            InternalToken(configuration));
        var inventory = refund.Value?.Inventory ?? removalResult.Inventory;
        return Results.Json(
            new InventoryItemUseResponse(
                Completed: false,
                Message: restoreResult.Message,
                Inventory: inventory,
                PlayerAction: restoreResult),
            statusCode: StatusCodes.Status409Conflict);
    }

    return Results.Ok(new InventoryItemUseResponse(
        Completed: true,
        Message: $"{restoreResult.Message} Consumed 1 Food.",
        Inventory: removalResult.Inventory,
        PlayerAction: restoreResult));
}).WithName("UseInventoryItem");

app.MapGet("/players/{playerId}/factories", async (
    string playerId,
    HttpRequest request,
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

    var authorization = request.Headers.Authorization.ToString();
    var portfolioResult = await production.GetJsonAsync<FactoryPortfolioResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/factories",
        authorization);
    if (portfolioResult.Error is not null)
    {
        return portfolioResult.Error;
    }

    var portfolio = portfolioResult.Value!;
    var enrichedFactories = new List<FactoryDto>(portfolio.Factories.Length);
    foreach (var factory in portfolio.Factories)
    {
        var productionRequest = await CreateRegionalProductionStartRequestAsync(
            world,
            configuration,
            access.PlayerId!,
            authorization,
            factory);
        enrichedFactories.Add(factory with
        {
            ResourceEffect = ToProductionBonus(productionRequest)
        });
    }

    return Results.Ok(portfolio with { Factories = enrichedFactories.ToArray() });
}).WithName("GetFactories");

app.MapGet("/players/{playerId}/production-jobs", async (
    string playerId,
    HttpRequest request,
    ProductionServiceClient production,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await production.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/production-jobs",
        request.Headers.Authorization.ToString());
}).WithName("GetProductionJobs");

app.MapGet("/companies", async (
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
        $"companies?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
        request.Headers.Authorization.ToString());
}).WithName("ListCompanies");

app.MapGet("/players/{playerId}/companies", async (
    string playerId,
    HttpRequest request,
    ProductionServiceClient production,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await production.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/companies",
        request.Headers.Authorization.ToString());
}).WithName("ListPlayerCompanies");

app.MapPost("/players/{playerId}/companies", async (
    string playerId,
    CreateCompanyRequest requestBody,
    HttpRequest request,
    ProductionServiceClient production,
    PlayerServiceClient players,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(requestBody.Name))
    {
        return Results.BadRequest(new ErrorResponse("Company name is required."));
    }

    var authorization = request.Headers.Authorization.ToString();
    var result = await production.PostJsonAsync<CreateCompanyRequest, JsonElement>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/companies",
        authorization,
        requestBody);
    if (result.Error is not null)
    {
        return result.Error;
    }

    var mutation = result.Value;
    if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
    {
        var onboarding = await OnboardingGatewayTracker.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "company_action",
            $"onboarding:company-action:{access.PlayerId!.ToLowerInvariant()}");
        if (onboarding.Error is not null)
        {
            return onboarding.Error;
        }

        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "company_action",
            $"achievement:company-action:{access.PlayerId!.ToLowerInvariant()}",
            app.Logger);
    }

    return Results.Json(mutation);
}).WithName("CreateCompany");

app.MapGet("/companies/{companyId}", async (
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
        $"companies/{Uri.EscapeDataString(companyId)}?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
        request.Headers.Authorization.ToString());
}).WithName("GetCompany");

app.MapGet("/companies/{companyId}/members", async (
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
        $"companies/{Uri.EscapeDataString(companyId)}/members?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
        request.Headers.Authorization.ToString());
}).WithName("GetCompanyMembers");

app.MapGet("/companies/{companyId}/assets", async (
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
        $"companies/{Uri.EscapeDataString(companyId)}/assets?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
        request.Headers.Authorization.ToString());
}).WithName("GetCompanyAssets");

app.MapPost("/companies/{companyId}/join", async (
    string companyId,
    HttpRequest request,
    ProductionServiceClient production,
    PlayerServiceClient players,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidateBearerPlayer(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var result = await production.PostJsonAsync<CompanyActorRequest, JsonElement>(
        $"companies/{Uri.EscapeDataString(companyId)}/join",
        authorization,
        new CompanyActorRequest(access.PlayerId!));
    if (result.Error is not null)
    {
        return result.Error;
    }

    var mutation = result.Value;
    if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
    {
        var onboarding = await OnboardingGatewayTracker.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "company_action",
            $"onboarding:company-action:{access.PlayerId!.ToLowerInvariant()}");
        if (onboarding.Error is not null)
        {
            return onboarding.Error;
        }

        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "company_action",
            $"achievement:company-action:{access.PlayerId!.ToLowerInvariant()}",
            app.Logger,
            relatedId: companyId);
    }

    return Results.Json(mutation);
}).WithName("JoinCompany");

app.MapPost("/companies/{companyId}/members/{targetPlayerId}/role", async (
    string companyId,
    string targetPlayerId,
    CompanyMemberRoleUpdateRequest requestBody,
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
        $"companies/{Uri.EscapeDataString(companyId)}/members/{Uri.EscapeDataString(targetPlayerId)}/role",
        request.Headers.Authorization.ToString(),
        new CompanyMemberRoleRequest(access.PlayerId!, requestBody.Role));
}).WithName("UpdateCompanyMemberRole");

app.MapPost("/companies/{companyId}/members/{targetPlayerId}/remove", async (
    string companyId,
    string targetPlayerId,
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
        $"companies/{Uri.EscapeDataString(companyId)}/members/{Uri.EscapeDataString(targetPlayerId)}/remove",
        request.Headers.Authorization.ToString(),
        new CompanyActorRequest(access.PlayerId!));
}).WithName("RemoveCompanyMember");

app.MapPost("/companies/{companyId}/factories/{factoryId}/produce", async (
    string companyId,
    string factoryId,
    HttpRequest request,
    ProductionServiceClient production,
    WorldServiceClient world,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidateBearerPlayer(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var assets = await production.GetJsonAsync<CompanyAssetsGatewayDto>(
        $"companies/{Uri.EscapeDataString(companyId)}/assets?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
        authorization);
    if (assets.Error is not null)
    {
        return assets.Error;
    }

    var factory = assets.Value?.Factories.FirstOrDefault(candidate =>
        string.Equals(candidate.FactoryId, factoryId, StringComparison.OrdinalIgnoreCase));
    if (factory is null)
    {
        return Results.NotFound(new ErrorResponse("Company factory was not found."));
    }

    var productionRequest = await CreateRegionalProductionStartRequestAsync(
        world,
        configuration,
        access.PlayerId!,
        authorization,
        factory);

    return await production.PostJsonForwardAsync(
        $"companies/{Uri.EscapeDataString(companyId)}/factories/{Uri.EscapeDataString(factoryId)}/produce",
        authorization,
        new CompanyProductionStartRequest(
            access.PlayerId!,
            productionRequest.OutputBonusPercent,
            productionRequest.BonusSourceRegionId,
            productionRequest.BonusSourceRegionName,
            productionRequest.BonusResourceName,
            productionRequest.BonusItemId));
}).WithName("StartCompanyProduction");

app.MapPost("/companies/{companyId}/production-jobs/{jobId}/claim", async (
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
        $"companies/{Uri.EscapeDataString(companyId)}/production-jobs/{Uri.EscapeDataString(jobId)}/claim",
        request.Headers.Authorization.ToString(),
        new CompanyActorRequest(access.PlayerId!));
}).WithName("ClaimCompanyProductionJob");

app.MapGet("/companies/{companyId}/upgrades", async (
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
        $"companies/{Uri.EscapeDataString(companyId)}/upgrades?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
        request.Headers.Authorization.ToString());
}).WithName("GetCompanyUpgrades");

app.MapPost("/companies/{companyId}/upgrades/hq", async (
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

    return await production.PostJsonForwardAsync(
        $"companies/{Uri.EscapeDataString(companyId)}/upgrades/hq",
        request.Headers.Authorization.ToString(),
        new CompanyActorRequest(access.PlayerId!));
}).WithName("UpgradeCompanyHq");

app.MapPost("/companies/{companyId}/specialization", async (
    string companyId,
    CompanySpecializationGatewayRequest requestBody,
    HttpRequest request,
    ProductionServiceClient production,
    DevTokenValidator tokens) =>
{
    var access = ValidateBearerPlayer(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(requestBody.Specialization))
    {
        return Results.BadRequest(new ErrorResponse("Specialization is required."));
    }

    return await production.PostJsonForwardAsync(
        $"companies/{Uri.EscapeDataString(companyId)}/specialization",
        request.Headers.Authorization.ToString(),
        new CompanySpecializationRequest(access.PlayerId!, requestBody.Specialization));
}).WithName("SetCompanySpecialization");

app.MapGet("/players/{playerId}/factories/{factoryId}/upgrade-quote", async (
    string playerId,
    string factoryId,
    HttpRequest request,
    ProductionServiceClient production,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await production.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/factories/{Uri.EscapeDataString(factoryId)}/upgrade-quote",
        request.Headers.Authorization.ToString());
}).WithName("GetFactoryUpgradeQuote");

app.MapPost("/players/{playerId}/factories/{factoryId}/upgrade", async (
    string playerId,
    string factoryId,
    HttpRequest request,
    ProductionServiceClient production,
    EconomyServiceClient economy,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
    var escapedFactoryId = Uri.EscapeDataString(factoryId);
    var quoteResult = await production.GetJsonAsync<FactoryUpgradeQuoteDto>(
        $"players/{escapedPlayerId}/factories/{escapedFactoryId}/upgrade-quote",
        authorization);
    if (quoteResult.Error is not null)
    {
        return quoteResult.Error;
    }

    var quote = quoteResult.Value!;
    if (!quote.CanUpgrade)
    {
        return Results.Json(
            new ErrorResponse("Factory cannot be upgraded right now."),
            statusCode: StatusCodes.Status409Conflict);
    }

    var payment = await economy.PostJsonAsync<InventorySpendRequestDto, InventoryMutationResponseDto>(
        $"players/{escapedPlayerId}/inventory/spend",
        authorization,
        new InventorySpendRequestDto(
            ItemId: quote.RequiredItemId,
            ItemName: quote.RequiredItemName,
            Category: "Raw material",
            Quantity: quote.RequiredItemQuantity,
            GoldCost: quote.GoldCost,
            EntryType: "factory_upgrade",
            Reason: $"Paid {quote.GoldCost} gold and used {quote.RequiredItemQuantity} {quote.RequiredItemName} to upgrade {quote.FactoryId} to level {quote.NextLevel}.",
            IdempotencyKey: $"upgrade:{access.PlayerId!.ToLowerInvariant()}:{quote.FactoryId.ToLowerInvariant()}:{quote.NextLevel}"),
        InternalToken(configuration));
    if (payment.Error is not null)
    {
        return payment.Error;
    }

    var inventoryMutation = payment.Value!;
    if (!inventoryMutation.Completed)
    {
        return Results.Json(
            new ErrorResponse(inventoryMutation.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    var upgrade = await production.PostJsonAsync<object, FactoryUpgradeResultDto>(
        $"players/{escapedPlayerId}/factories/{escapedFactoryId}/upgrade",
        authorization,
        new { },
        InternalToken(configuration));
    if (upgrade.Error is not null)
    {
        return upgrade.Error;
    }

    var upgradeResult = upgrade.Value!;
    if (!upgradeResult.Upgraded)
    {
        return Results.Json(
            new FactoryUpgradeGatewayResponse(
                Completed: false,
                Message: upgradeResult.Message,
                Upgrade: upgradeResult,
                Inventory: inventoryMutation.Inventory),
            statusCode: StatusCodes.Status409Conflict);
    }

    return Results.Ok(new FactoryUpgradeGatewayResponse(
        Completed: true,
        Message: $"{upgradeResult.Message} Inventory updated.",
        Upgrade: upgradeResult,
        Inventory: inventoryMutation.Inventory));
}).WithName("UpgradeFactory");

app.MapPost("/players/{playerId}/factories/{factoryId}/produce", async (
    string playerId,
    string factoryId,
    HttpRequest request,
    PlayerServiceClient players,
    ProductionServiceClient production,
    EconomyServiceClient economy,
    WorldServiceClient world,
    IConfiguration configuration,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
    var escapedFactoryId = Uri.EscapeDataString(factoryId);
    var factoriesResult = await production.GetJsonAsync<FactoryPortfolioResponseDto>(
        $"players/{escapedPlayerId}/factories",
        authorization);
    if (factoriesResult.Error is not null)
    {
        return factoriesResult.Error;
    }

    var factory = factoriesResult.Value?.Factories.FirstOrDefault(candidate =>
        string.Equals(candidate.FactoryId, factoryId, StringComparison.OrdinalIgnoreCase));
    if (factory is null)
    {
        return Results.NotFound(new ErrorResponse("Factory was not found."));
    }

    var productionRequest = await CreateRegionalProductionStartRequestAsync(
        world,
        configuration,
        access.PlayerId!,
        authorization,
        factory);
    var productionResult = await production.PostJsonAsync<ProductionStartRequestDto, ProductionResultDto>(
        $"players/{escapedPlayerId}/factories/{escapedFactoryId}/produce",
        authorization,
        productionRequest);
    if (productionResult.Error is not null)
    {
        return productionResult.Error;
    }

    var result = productionResult.Value!;
    if (result.Job is null)
    {
        return Results.Ok(result);
    }

    var inventoryMutation = await economy.PostJsonAsync<InventoryRemovalRequestDto, InventoryMutationResponseDto>(
        $"players/{escapedPlayerId}/inventory/remove",
        authorization,
        new InventoryRemovalRequestDto(
            ItemId: result.Job.InputItemId,
            ItemName: result.Job.InputItemName,
            Category: result.Job.InputItemCategory,
            Quantity: result.Job.InputQuantity,
            Reason: $"Started production job {result.Job.JobId}: {result.Job.InputQuantity} {result.Job.InputItemName} reserved for {result.Job.OutputQuantity} {result.Job.OutputItemName}.",
            IdempotencyKey: $"production-input:{result.Job.JobId.ToLowerInvariant()}"),
        InternalToken(configuration));
    if (inventoryMutation.Error is not null)
    {
        var cancellation = await production.PostJsonAsync<ProductionJobCancellationRequestDto, ProductionJobDto>(
            $"players/{escapedPlayerId}/production-jobs/{Uri.EscapeDataString(result.Job.JobId)}/cancel",
            authorization,
            new ProductionJobCancellationRequestDto("Economy input removal failed while starting production."),
            InternalToken(configuration));
        if (cancellation.Error is not null)
        {
            return Results.Json(
                new ErrorResponse("Production input removal failed and the queued job could not be cancelled. Retry or contact support."),
                statusCode: StatusCodes.Status502BadGateway);
        }

        return inventoryMutation.Error;
    }

    var mutation = inventoryMutation.Value!;
    if (!mutation.Completed)
    {
        var cancellation = await production.PostJsonAsync<ProductionJobCancellationRequestDto, ProductionJobDto>(
            $"players/{escapedPlayerId}/production-jobs/{Uri.EscapeDataString(result.Job.JobId)}/cancel",
            authorization,
            new ProductionJobCancellationRequestDto(mutation.Message),
            InternalToken(configuration));
        if (cancellation.Error is not null)
        {
            return Results.Json(
                new ErrorResponse("Production input removal was rejected and the queued job could not be cancelled. Retry or contact support."),
                statusCode: StatusCodes.Status502BadGateway);
        }

        return Results.Json(
            new ErrorResponse($"{mutation.Message} Production job was cancelled."),
            statusCode: StatusCodes.Status409Conflict);
    }

    var objectiveTrack = await TrackDailyObjectiveAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "production_start",
        $"daily-objective:production-start:{result.Job.JobId.ToLowerInvariant()}");
    if (objectiveTrack.Error is not null)
    {
        return objectiveTrack.Error;
    }

    var onboardingTrack = await OnboardingGatewayTracker.TrackAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "produce",
        $"onboarding:produce:{access.PlayerId!.ToLowerInvariant()}:{result.Job.JobId.ToLowerInvariant()}");
    if (onboardingTrack.Error is not null)
    {
        return onboardingTrack.Error;
    }

    await AchievementGatewayEndpoints.TrackAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "production_start",
        $"achievement:production-start:{result.Job.JobId.ToLowerInvariant()}",
        app.Logger,
        relatedId: result.Job.JobId);

    return Results.Ok(result with
    {
        Message = $"{result.Message} Input inventory reserved.",
        Note = $"{mutation.Message} Claim the job after its cooldown completes.",
        Inventory = mutation.Inventory,
        DailyObjectives = objectiveTrack.Value
    });
}).WithName("Produce");

app.MapPost("/players/{playerId}/production-jobs/{jobId}/claim", async (
    string playerId,
    string jobId,
    HttpRequest request,
    PlayerServiceClient players,
    ProductionServiceClient production,
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

    var authorization = request.Headers.Authorization.ToString();
    var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
    var escapedJobId = Uri.EscapeDataString(jobId);
    var ticketResult = await production.PostJsonAsync<object, ProductionClaimTicketDto>(
        $"players/{escapedPlayerId}/production-jobs/{escapedJobId}/claim/start",
        authorization,
        new { },
        InternalToken(configuration));
    if (ticketResult.Error is not null)
    {
        return ticketResult.Error;
    }

    var ticket = ticketResult.Value!;
    if (ticket.AlreadyClaimed)
    {
        var completedClaim = await production.PostJsonAsync<object, ProductionClaimCompletionDto>(
            $"players/{escapedPlayerId}/production-jobs/{Uri.EscapeDataString(ticket.Job.JobId)}/claim/complete",
            authorization,
            new { },
            InternalToken(configuration));
        if (completedClaim.Error is not null)
        {
            return completedClaim.Error;
        }

        var objectiveTrack = await TrackDailyObjectiveAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "production_claim",
            $"daily-objective:production-claim:{ticket.Job.JobId.ToLowerInvariant()}");
        if (objectiveTrack.Error is not null)
        {
            return objectiveTrack.Error;
        }

        var completed = completedClaim.Value!;
        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "production_claim",
            $"achievement:production-claim:{completed.Job.JobId.ToLowerInvariant()}",
            app.Logger,
            relatedId: completed.Job.JobId);

        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            access.PlayerId!,
            "production_claim",
            completed.Message,
            completed.Job.JobId,
            $"activity:production-claim:{access.PlayerId!.ToLowerInvariant()}:{completed.Job.JobId.ToLowerInvariant()}");

        return Results.Ok(new ProductionClaimGatewayResponse(
            Completed: true,
            Message: completed.Message,
            Claim: completed,
            Inventory: null,
            DailyObjectives: objectiveTrack.Value));
    }

    if (!ticket.ReadyToClaim)
    {
        return Results.Json(
            new ErrorResponse(ticket.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    var job = ticket.Job;
    var inventoryGrant = await economy.PostJsonAsync<InventoryGrantRequestDto, InventoryMutationResponseDto>(
        $"players/{escapedPlayerId}/inventory/grant",
        authorization,
        new InventoryGrantRequestDto(
            ItemId: job.OutputItemId,
            ItemName: job.OutputItemName,
            Category: job.OutputItemCategory,
            Quantity: job.OutputQuantity,
            EntryType: "production_claim",
            Reason: $"Claimed production job {job.JobId}: {job.OutputQuantity} {job.OutputItemName}.",
            IdempotencyKey: $"production-output:{job.JobId.ToLowerInvariant()}"),
        InternalToken(configuration));
    if (inventoryGrant.Error is not null)
    {
        return inventoryGrant.Error;
    }

    var grant = inventoryGrant.Value!;
    if (!grant.Completed)
    {
        return Results.Json(
            new ErrorResponse(grant.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    var completionResult = await production.PostJsonAsync<object, ProductionClaimCompletionDto>(
        $"players/{escapedPlayerId}/production-jobs/{Uri.EscapeDataString(job.JobId)}/claim/complete",
        authorization,
        new { },
        InternalToken(configuration));
    if (completionResult.Error is not null)
    {
        return completionResult.Error;
    }

    var completion = completionResult.Value!;
    var claimMessage = $"{completion.Message} {grant.Message}";
    DailyObjectivesResponseDto? dailyObjectives = null;
    if (completion.Completed)
    {
        var objectiveTrack = await TrackDailyObjectiveAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "production_claim",
            $"daily-objective:production-claim:{job.JobId.ToLowerInvariant()}");
        if (objectiveTrack.Error is not null)
        {
            return objectiveTrack.Error;
        }

        dailyObjectives = objectiveTrack.Value;
        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "production_claim",
            $"achievement:production-claim:{completion.Job.JobId.ToLowerInvariant()}",
            app.Logger,
            relatedId: completion.Job.JobId);

        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            access.PlayerId!,
            "production_claim",
            claimMessage,
            completion.Job.JobId,
            $"activity:production-claim:{access.PlayerId!.ToLowerInvariant()}:{completion.Job.JobId.ToLowerInvariant()}");
    }

    return Results.Ok(new ProductionClaimGatewayResponse(
        Completed: completion.Completed,
        Message: claimMessage,
        Claim: completion,
        Inventory: grant.Inventory,
        DailyObjectives: dailyObjectives));
}).WithName("ClaimProductionJob");

app.MapGet("/market/listings", async (
    HttpRequest request,
    MarketServiceClient market,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    return await market.GetAsync("market/listings", request.Headers.Authorization.ToString());
}).WithName("GetMarketListings");

app.MapGet("/players/{playerId}/market/listings", async (
    string playerId,
    HttpRequest request,
    MarketServiceClient market,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await market.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/market/listings",
        request.Headers.Authorization.ToString());
}).WithName("GetPlayerMarketListings");

app.MapPost("/players/{playerId}/market/listings/{listingId}/buy", async (
    string playerId,
    string listingId,
    HttpRequest request,
    MarketServiceClient market,
    PlayerServiceClient players,
    EconomyServiceClient economy,
    WorldServiceClient world,
    NotificationServiceClient notifications,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.MarketBuy,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/market/listings/{listingId}/buy",
            "market_listing",
            listingId,
            idempotencyKey,
            new { ListingId = listingId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var listingResult = await market.GetJsonAsync<MarketListingDto>(
        $"market/listings/{Uri.EscapeDataString(listingId)}",
        authorization);
    if (listingResult.Error is not null)
    {
        return listingResult.Error;
    }

    var listing = listingResult.Value!;
    if (string.Equals(listing.SellerId, access.PlayerId, StringComparison.OrdinalIgnoreCase))
    {
        return Results.Json(
            new ErrorResponse("You cannot buy your own listing."),
            statusCode: StatusCodes.Status409Conflict);
    }

    var buyerTaxContextResult = await TreasuryGatewayEndpoints.GetPlayerTaxContextAsync(
        world,
        configuration,
        access.PlayerId!,
        authorization);
    if (buyerTaxContextResult.Error is not null)
    {
        return buyerTaxContextResult.Error;
    }

    var sellerTaxContextResult = await TreasuryGatewayEndpoints.GetPlayerTaxContextAsync(
        world,
        configuration,
        listing.SellerId,
        authorization);
    if (sellerTaxContextResult.Error is not null)
    {
        return sellerTaxContextResult.Error;
    }

    var buyerTaxContext = buyerTaxContextResult.Value;
    var sellerTaxContext = sellerTaxContextResult.Value;
    var buyerMarketTaxRate = buyerTaxContext?.Treasury.Policy.MarketTaxRate ?? 0;
    var sellerMarketTaxRate = sellerTaxContext?.Treasury.Policy.MarketTaxRate ?? 0;
    var buyerMarketTaxAmount = TreasuryGatewayEndpoints.CalculateTaxAmount(listing.PricePerUnit, buyerMarketTaxRate);
    var sellerMarketTaxAmount = TreasuryGatewayEndpoints.CalculateTaxAmount(listing.PricePerUnit, sellerMarketTaxRate);

    var reservationId = StableGatewayId("buy", access.PlayerId!, listing.ListingId, idempotencyKey);
    var reservation = await market.PostJsonAsync<PurchaseListingRequestDto, MarketReservationResponseDto>(
        $"market/listings/{Uri.EscapeDataString(listing.ListingId)}/purchase",
        authorization,
        new PurchaseListingRequestDto(
            BuyerId: access.PlayerId!,
            Quantity: 1,
            ReservationId: reservationId),
        InternalToken(configuration));
    if (reservation.Error is not null)
    {
        return reservation.Error;
    }

    var reserved = reservation.Value!;
    if (!reserved.Completed || reserved.Listing is null)
    {
        return Results.Json(
            new ErrorResponse(reserved.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    var reservedListing = reserved.Listing;
    var purchase = await economy.PostJsonAsync<MarketPurchaseRequestDto, MarketPurchaseResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/market/buy",
        authorization,
        new MarketPurchaseRequestDto(
            ListingId: reservedListing.ListingId,
            ItemId: reservedListing.ItemId,
            ItemName: reservedListing.ItemName,
            Category: reservedListing.Category,
            Quantity: 1,
            PricePerUnit: reservedListing.PricePerUnit,
            SellerId: reservedListing.SellerId,
            IdempotencyKey: reservationId,
            BuyerTaxAmount: buyerMarketTaxAmount,
            SellerTaxAmount: sellerMarketTaxAmount));
    if (purchase.Error is not null)
    {
        return purchase.Error;
    }

    var purchaseResult = purchase.Value!;
    if (!purchaseResult.Completed)
    {
        await market.PostJsonAsync<ReservationStatusRequestDto, MarketReservationStatusResponseDto>(
            $"market/listings/{Uri.EscapeDataString(reservedListing.ListingId)}/release",
            authorization,
            new ReservationStatusRequestDto(reservationId),
            InternalToken(configuration));
        return Results.Json(
            new ErrorResponse(purchaseResult.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    await market.PostJsonAsync<ReservationStatusRequestDto, MarketReservationStatusResponseDto>(
        $"market/listings/{Uri.EscapeDataString(reservedListing.ListingId)}/settle",
        authorization,
        new ReservationStatusRequestDto(reservationId),
        InternalToken(configuration));

    var taxCollections = new List<CountryTaxCollectionResponseDto>();
    if (buyerMarketTaxAmount > 0 && buyerTaxContext is not null)
    {
        var collection = await TreasuryGatewayEndpoints.CollectCountryTaxAsync(
            world,
            configuration,
            authorization,
            buyerTaxContext.Citizenship.CountryId,
            buyerMarketTaxAmount,
            purchaseResult.TotalPrice,
            buyerMarketTaxRate,
            "market_purchase_tax",
            access.PlayerId!,
            reservedListing.SellerId,
            $"Market purchase tax on listing {reservedListing.ListingId}.",
            $"tax:market-buy:{reservationId.ToLowerInvariant()}");
        if (collection.Error is not null)
        {
            return collection.Error;
        }

        if (collection.Value is not null)
        {
            taxCollections.Add(collection.Value);
        }
    }

    if (sellerMarketTaxAmount > 0 && sellerTaxContext is not null)
    {
        var collection = await TreasuryGatewayEndpoints.CollectCountryTaxAsync(
            world,
            configuration,
            authorization,
            sellerTaxContext.Citizenship.CountryId,
            sellerMarketTaxAmount,
            purchaseResult.TotalPrice,
            sellerMarketTaxRate,
            "market_sale_tax",
            reservedListing.SellerId,
            access.PlayerId!,
            $"Market sale tax on listing {reservedListing.ListingId}.",
            $"tax:market-sale:{reservationId.ToLowerInvariant()}");
        if (collection.Error is not null)
        {
            return collection.Error;
        }

        if (collection.Value is not null)
        {
            taxCollections.Add(collection.Value);
        }
    }

    if (taxCollections.Count > 0)
    {
        purchaseResult = purchaseResult with { TaxCollections = taxCollections.ToArray() };
    }

    await ActivityGatewayEndpoints.EmitAsync(
        notifications,
        configuration,
        access.PlayerId!,
        "market_buy",
        purchaseResult.Message,
        reservedListing.ListingId,
        $"activity:market-buy:{access.PlayerId!.ToLowerInvariant()}:{reservedListing.ListingId.ToLowerInvariant()}:{reservationId.ToLowerInvariant()}");
    await ActivityGatewayEndpoints.EmitAsync(
        notifications,
        configuration,
        reservedListing.SellerId,
        "market_sale",
        purchaseResult.SellerTaxAmount > 0
            ? $"Sold {purchaseResult.Quantity} {reservedListing.ItemName} for {purchaseResult.TotalPrice} gold ({purchaseResult.SellerTaxAmount} tax)."
            : $"Sold {purchaseResult.Quantity} {reservedListing.ItemName} for {purchaseResult.TotalPrice} gold.",
        reservedListing.ListingId,
        $"activity:market-sale:{reservedListing.SellerId.ToLowerInvariant()}:{reservedListing.ListingId.ToLowerInvariant()}:{reservationId.ToLowerInvariant()}");

    await AchievementGatewayEndpoints.TrackAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "market_trade",
        $"achievement:market-trade:{access.PlayerId!.ToLowerInvariant()}:{reservationId.ToLowerInvariant()}",
        app.Logger,
        relatedId: reservedListing.ListingId);

    return Results.Ok(purchaseResult);
}).WithName("BuyMarketListing");

app.MapPost("/players/{playerId}/market/listings", async (
    string playerId,
    CreatePlayerListingRequest request,
    HttpRequest httpRequest,
    MarketServiceClient market,
    EconomyServiceClient economy,
    NotificationServiceClient notifications,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(request.ItemId) ||
        request.Quantity <= 0 ||
        request.PricePerUnit <= 0)
    {
        return Results.BadRequest(new ErrorResponse("Item, quantity, and price are required."));
    }

    var idempotencyKey = httpRequest.Headers["Idempotency-Key"].ToString().Trim();
    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.MarketSell,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/market/listings",
            "item",
            request.ItemId,
            idempotencyKey,
            new
            {
                request.ItemId,
                request.Quantity,
                request.PricePerUnit
            }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var authorization = httpRequest.Headers.Authorization.ToString();
    var inventoryResult = await economy.GetJsonAsync<InventoryResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory",
        authorization);
    if (inventoryResult.Error is not null)
    {
        return inventoryResult.Error;
    }

    var inventory = inventoryResult.Value!;
    var item = inventory.Items.FirstOrDefault(candidate =>
        string.Equals(candidate.ItemId, request.ItemId, StringComparison.OrdinalIgnoreCase));
    if (item is null || item.Quantity < request.Quantity)
    {
        return Results.Json(
            new ErrorResponse($"Not enough inventory to list {request.Quantity} {request.ItemId}."),
            statusCode: StatusCodes.Status409Conflict);
    }

    var listingId = StableGatewayId("listing", access.PlayerId!, request.ItemId, idempotencyKey);
    var createdListing = await market.PostJsonAsync<CreateMarketListingRequestDto, MarketListingDto>(
        "market/listings",
        authorization,
        new CreateMarketListingRequestDto(
            ListingId: listingId,
            SellerId: access.PlayerId!,
            ItemId: item.ItemId,
            ItemName: item.Name,
            Category: item.Category,
            Quantity: request.Quantity,
            PricePerUnit: request.PricePerUnit),
        InternalToken(configuration));
    if (createdListing.Error is not null)
    {
        return createdListing.Error;
    }

    var removal = await economy.PostJsonAsync<InventoryRemovalRequestDto, InventoryMutationResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory/remove",
        authorization,
        new InventoryRemovalRequestDto(
            ItemId: item.ItemId,
            ItemName: item.Name,
            Category: item.Category,
            Quantity: request.Quantity,
            Reason: $"Listed {request.Quantity} {item.Name} on the market.",
            IdempotencyKey: $"sell:{listingId}"),
        InternalToken(configuration));
    if (removal.Error is not null)
    {
        await market.PostJsonAsync<ReservationStatusRequestDto, MarketListingDto>(
            $"market/listings/{Uri.EscapeDataString(listingId)}/cancel",
            authorization,
            new ReservationStatusRequestDto(string.Empty),
            InternalToken(configuration));
        return removal.Error;
    }

    var inventoryMutation = removal.Value!;
    if (!inventoryMutation.Completed)
    {
        await market.PostJsonAsync<ReservationStatusRequestDto, MarketListingDto>(
            $"market/listings/{Uri.EscapeDataString(listingId)}/cancel",
            authorization,
            new ReservationStatusRequestDto(string.Empty),
            InternalToken(configuration));
        return Results.Json(
            new ErrorResponse(inventoryMutation.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    var activatedListing = await market.PostJsonAsync<object, MarketListingDto>(
        $"market/listings/{Uri.EscapeDataString(listingId)}/activate",
        authorization,
        new { },
        InternalToken(configuration));
    if (activatedListing.Error is not null)
    {
        return activatedListing.Error;
    }

    var activated = activatedListing.Value!;
    var saleMessage = $"Listed {request.Quantity} {item.Name} for {request.PricePerUnit} gold each.";
    await ActivityGatewayEndpoints.EmitAsync(
        notifications,
        configuration,
        access.PlayerId!,
        "market_sale",
        saleMessage,
        activated.ListingId,
        $"activity:market-listing:{access.PlayerId!.ToLowerInvariant()}:{activated.ListingId.ToLowerInvariant()}");

    return Results.Ok(new MarketSellListingResponse(
        Completed: true,
        Message: saleMessage,
        Listing: activated,
        Inventory: inventoryMutation.Inventory));
}).WithName("CreatePlayerMarketListing");

app.MapPost("/players/{playerId}/market/listings/{listingId}/cancel", async (
    string playerId,
    string listingId,
    HttpRequest request,
    MarketServiceClient market,
    EconomyServiceClient economy,
    NotificationServiceClient notifications,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.MarketCancel,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/market/listings/{listingId}/cancel",
            "market_listing",
            listingId,
            idempotencyKey,
            new { ListingId = listingId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var listing = await market.GetJsonAsync<MarketListingDto>(
        $"market/listings/{Uri.EscapeDataString(listingId)}",
        authorization);
    if (listing.Error is not null)
    {
        return listing.Error;
    }

    var currentListing = listing.Value!;
    if (!string.Equals(currentListing.SellerId, access.PlayerId, StringComparison.OrdinalIgnoreCase))
    {
        return Results.Json(
            new ErrorResponse("You cannot cancel another player's listing."),
            statusCode: StatusCodes.Status403Forbidden);
    }

    var cancellation = await market.PostJsonAsync<object, MarketListingDto>(
        $"market/listings/{Uri.EscapeDataString(currentListing.ListingId)}/cancel",
        authorization,
        new { },
        InternalToken(configuration));
    if (cancellation.Error is not null)
    {
        return cancellation.Error;
    }

    var cancelledListing = cancellation.Value!;
    InventoryResponseDto? refundedInventory = null;
    var message = $"Cancelled listing {cancelledListing.ListingId}.";
    if (cancelledListing.Quantity > 0)
    {
        var refund = await economy.PostJsonAsync<InventoryGrantRequestDto, InventoryMutationResponseDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory/grant",
            authorization,
            new InventoryGrantRequestDto(
                ItemId: cancelledListing.ItemId,
                ItemName: cancelledListing.ItemName,
                Category: cancelledListing.Category,
                Quantity: cancelledListing.Quantity,
                EntryType: "market_cancel_refund",
                Reason: $"Refunded {cancelledListing.Quantity} {cancelledListing.ItemName} from cancelled market listing.",
                IdempotencyKey: $"cancel:{cancelledListing.ListingId}:{idempotencyKey.ToLowerInvariant()}"),
            InternalToken(configuration));
        if (refund.Error is not null)
        {
            return refund.Error;
        }

        var refundResult = refund.Value!;
        if (!refundResult.Completed)
        {
            return Results.Json(
                new ErrorResponse(refundResult.Message),
                statusCode: StatusCodes.Status409Conflict);
        }

        refundedInventory = refundResult.Inventory;
        message = $"{message} Refunded {cancelledListing.Quantity} {cancelledListing.ItemName}.";
    }

    await ActivityGatewayEndpoints.EmitAsync(
        notifications,
        configuration,
        access.PlayerId!,
        "market_cancel",
        message,
        cancelledListing.ListingId,
        $"activity:market-cancel:{access.PlayerId!.ToLowerInvariant()}:{cancelledListing.ListingId.ToLowerInvariant()}");

    return Results.Ok(new MarketCancelListingResponse(
        Completed: true,
        Message: message,
        Listing: cancelledListing,
        Inventory: refundedInventory));
}).WithName("CancelPlayerMarketListing");

app.MapAdvancedMarketGatewayEndpoints();

app.MapGet("/combat/missions", async (
    HttpRequest request,
    CombatServiceClient combat,
    DevTokenValidator tokens) =>
{
    var error = ValidateBearer(request, tokens);
    if (error is not null)
    {
        return error;
    }

    return await combat.GetAsync("missions", request.Headers.Authorization.ToString());
}).WithName("GetCombatMissions");

app.MapGet("/players/{playerId}/missions/progress", async (
    string playerId,
    HttpRequest request,
    PlayerServiceClient players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await players.GetAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/missions/progress",
        request.Headers.Authorization.ToString());
}).WithName("GetPlayerMissionProgress");

app.MapPost("/players/{playerId}/combat/missions/{missionId}/fight", async (
    string playerId,
    string missionId,
    HttpRequest request,
    PlayerServiceClient players,
    CombatServiceClient combat,
    EconomyServiceClient economy,
    NotificationServiceClient notifications,
    IConfiguration configuration,
    DevTokenValidator tokens,
    AntiAbuseStore antiAbuse) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var fightKey = request.Headers["Idempotency-Key"].ToString().Trim();
    var antiAbuseDecision = await antiAbuse.EnforceAsync(
        AntiAbuseRules.CombatFight,
        new AntiAbuseCheck(
            access.PlayerId!,
            "/players/{playerId}/combat/missions/{missionId}/fight",
            "combat_mission",
            missionId,
            fightKey,
            new { MissionId = missionId }));
    if (antiAbuseDecision.Error is not null)
    {
        return antiAbuseDecision.Error;
    }

    var playerState = await players.GetJsonAsync<PlayerStateForCombat>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/state",
        authorization);
    if (playerState.Error is not null)
    {
        return playerState.Error;
    }

    var equipment = await economy.GetJsonAsync<EquipmentResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/equipment",
        authorization);
    if (equipment.Error is not null)
    {
        return equipment.Error;
    }

    var progress = await players.GetJsonAsync<MissionProgressResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/missions/progress",
        authorization);
    if (progress.Error is not null)
    {
        return progress.Error;
    }

    var mission = await combat.GetJsonAsync<CombatMissionDto>(
        $"missions/{Uri.EscapeDataString(missionId)}",
        authorization);
    if (mission.Error is not null)
    {
        return mission.Error;
    }

    var state = playerState.Value!;
    var equipmentBeforeFight = equipment.Value!;
    var progressBeforeFight = progress.Value!;
    var weaponBeforeFight = equipmentBeforeFight.Weapon;
    var weaponPower = weaponBeforeFight is { Durability: > 0 }
        ? Math.Max(1, weaponBeforeFight.WeaponPower)
        : 1;
    var missionDto = mission.Value!;
    var missionProgressBeforeFight = progressBeforeFight.Missions.FirstOrDefault(candidate =>
        string.Equals(candidate.MissionId, missionDto.MissionId, StringComparison.OrdinalIgnoreCase));
    if (missionProgressBeforeFight?.CooldownUntil is DateTimeOffset cooldownUntil &&
        cooldownUntil > DateTimeOffset.UtcNow)
    {
        return Results.Json(
            new ErrorResponse($"Mission is on cooldown until {cooldownUntil:O}."),
            statusCode: StatusCodes.Status409Conflict);
    }

    var simulatedAttackerEnergy = Math.Clamp(state.Energy, 0, 100);
    var fight = await combat.PostJsonAsync<FightRequestDto, FightResponseDto>(
        "simulate/fight",
        authorization,
        new FightRequestDto(
            Attacker: new FighterDto(
                Strength: Math.Max(1, state.Strength),
                Energy: simulatedAttackerEnergy,
                WeaponPower: weaponPower),
            Defender: missionDto.Defender,
            Rounds: missionDto.Rounds));
    if (fight.Error is not null)
    {
        return fight.Error;
    }

    var fightResult = fight.Value!;
    var won = string.Equals(fightResult.Winner, "attacker", StringComparison.OrdinalIgnoreCase);
    var energyCost = Math.Max(0, simulatedAttackerEnergy - fightResult.AttackerRemainingEnergy);
    var progression = await players.PostJsonAsync<CombatResultRequestDto, PlayerActionResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/combat/result",
        authorization,
        new CombatResultRequestDto(
            EnergyCost: energyCost,
            GoldReward: won ? missionDto.RewardGold : 0,
            ExperienceReward: won ? missionDto.RewardExperience : 0,
            Message: won
                ? $"Mission complete. You earned {missionDto.RewardGold} gold and {missionDto.RewardExperience} XP."
                : "Mission complete, but you did not win rewards.",
            MissionId: missionDto.MissionId,
            Won: won,
            RoundsCompleted: fightResult.RoundsCompleted,
            AttackerDamage: fightResult.AttackerDamage,
            DefenderDamage: fightResult.DefenderDamage,
            IdempotencyKey: $"combat:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId}:{fightKey.ToLowerInvariant()}:progression"),
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

    if (appliedProgression.Rewards.Gold > 0)
    {
        var walletCredit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/wallet/credit",
            authorization,
            new WalletCreditRequestDto(
                Amount: appliedProgression.Rewards.Gold,
                EntryType: "combat_reward",
                Reason: appliedProgression.Message,
                IdempotencyKey: $"combat:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId}:{fightKey.ToLowerInvariant()}:gold"),
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

        appliedProgression = appliedProgression with { Wallet = credit.Inventory };
    }

    DamageWeaponResponseDto? weaponDamage = null;
    EquipmentResponseDto equipmentAfterFight = equipmentBeforeFight;
    if (weaponBeforeFight is { Durability: > 0 })
    {
        var damage = await economy.PostJsonAsync<DamageWeaponRequestDto, DamageWeaponResponseDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/equipment/weapon/damage",
            authorization,
            new DamageWeaponRequestDto(
                DurabilityDamage: Math.Max(1, fightResult.RoundsCompleted),
                Reason: $"Weapon durability used during mission {missionDto.MissionId}.",
                IdempotencyKey: $"combat-weapon:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId}:{fightKey.ToLowerInvariant()}"),
            InternalToken(configuration));
        if (damage.Error is not null)
        {
            return damage.Error;
        }

        weaponDamage = damage.Value!;
        equipmentAfterFight = weaponDamage.Equipment;
    }

    var objectiveTrack = await TrackDailyObjectiveAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "fight",
        $"daily-objective:fight:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId}:{fightKey.ToLowerInvariant()}");
    if (objectiveTrack.Error is not null)
    {
        return objectiveTrack.Error;
    }

    var onboardingTrack = await OnboardingGatewayTracker.TrackAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "fight",
        $"onboarding:fight:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId}:{fightKey.ToLowerInvariant()}");
    if (onboardingTrack.Error is not null)
    {
        return onboardingTrack.Error;
    }

    await AchievementGatewayEndpoints.TrackAsync(
        players,
        access.PlayerId!,
        authorization,
        configuration,
        "fight",
        $"achievement:fight:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId}:{fightKey.ToLowerInvariant()}",
        app.Logger,
        relatedId: missionDto.MissionId);

    await ActivityGatewayEndpoints.EmitAsync(
        notifications,
        configuration,
        access.PlayerId!,
        "mission_fight",
        appliedProgression.Message,
        missionDto.MissionId,
        $"activity:mission-fight:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId.ToLowerInvariant()}:{fightKey.ToLowerInvariant()}");

    return Results.Ok(new MissionFightResponse(
        Mission: missionDto,
        Fight: fightResult,
        PlayerAction: appliedProgression,
        MissionProgress: appliedProgression.MissionProgress,
        Equipment: equipmentAfterFight,
        WeaponDamage: weaponDamage,
        Message: appliedProgression.Message,
        DailyObjectives: objectiveTrack.Value));
}).WithName("FightMission");

app.MapGet("/messages", async (
    string? fromId,
    string? toId,
    DateTimeOffset? since,
    SocialChatServiceClient socialChat) =>
{
    var query = new List<string>();
    if (!string.IsNullOrWhiteSpace(fromId))
    {
        query.Add($"fromId={Uri.EscapeDataString(fromId.Trim())}");
    }
    if (!string.IsNullOrWhiteSpace(toId))
    {
        query.Add($"toId={Uri.EscapeDataString(toId.Trim())}");
    }
    if (since is not null)
    {
        query.Add($"since={Uri.EscapeDataString(since.Value.ToUniversalTime().ToString("O"))}");
    }

    var path = query.Count == 0
        ? "messages"
        : $"messages?{string.Join("&", query)}";
    return await socialChat.GetAsync(path, authorizationHeader: string.Empty);
}).WithName("GetMessages");

app.MapPost("/messages", async (SendMessageRequest request, SocialChatServiceClient socialChat) =>
{
    if (string.IsNullOrWhiteSpace(request.Content))
    {
        return Results.BadRequest(new ErrorResponse("Message content is required."));
    }

    var sent = await socialChat.PostJsonAsync<SendMessageRequest, MessageDto>(
        "messages",
        authorizationHeader: string.Empty,
        new SendMessageRequest(
            Content: request.Content.Trim(),
            FromId: string.IsNullOrWhiteSpace(request.FromId) ? "anonymous" : request.FromId.Trim(),
            ToId: string.IsNullOrWhiteSpace(request.ToId) ? "global" : request.ToId.Trim()));
    return sent.Error is not null
        ? sent.Error
        : Results.Ok(sent.Value!);
}).WithName("SendMessage");

app.MapPost("/players/{playerId}/messages/{messageId}/report", ReportChatMessage)
    .WithName("ReportChatMessage");

app.Run();

static PlayerAccessResult ValidatePlayerAccess(string playerId, HttpRequest request, DevTokenValidator tokens)
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

static IResult? ValidateBearer(HttpRequest request, DevTokenValidator tokens)
{
    var token = tokens.Validate(request.Headers.Authorization.ToString());
    return token.IsValid
        ? null
        : Results.Json(
            new ErrorResponse("A valid bearer token is required."),
            statusCode: StatusCodes.Status401Unauthorized);
}

static PlayerAccessResult ValidateBearerPlayer(HttpRequest request, DevTokenValidator tokens)
{
    var token = tokens.Validate(request.Headers.Authorization.ToString());
    return token.IsValid
        ? PlayerAccessResult.Allowed(token.PlayerId!)
        : PlayerAccessResult.Denied(Results.Json(
            new ErrorResponse("A valid bearer token is required."),
            statusCode: StatusCodes.Status401Unauthorized));
}

static string InternalToken(IConfiguration configuration)
{
    return configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
}

static async Task<ProductionStartRequestDto> CreateRegionalProductionStartRequestAsync(
    WorldServiceClient world,
    IConfiguration configuration,
    string playerId,
    string authorization,
    FactoryDto factory)
{
    var citizenship = await world.GetJsonAsync<PlayerCitizenshipResponseDto>(
        $"internal/players/{Uri.EscapeDataString(playerId)}/citizenship",
        authorization,
        InternalToken(configuration));
    var playerCitizenship = citizenship.Value?.Citizenship;
    if (citizenship.Error is not null ||
        playerCitizenship is null ||
        !string.Equals(playerCitizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
    {
        return new ProductionStartRequestDto();
    }

    var territory = await world.GetJsonAsync<TerritoryMapResponseDto>(
        $"territory/map?countryId={Uri.EscapeDataString(playerCitizenship.CountryId)}",
        authorization);
    if (territory.Error is not null)
    {
        return new ProductionStartRequestDto();
    }

    var bonus = SelectRegionalProductionBonus(territory.Value, factory);
    return bonus is null
        ? new ProductionStartRequestDto()
        : new ProductionStartRequestDto(
            bonus.ProductionBonusPercent,
            bonus.SourceRegionId,
            bonus.SourceRegionName,
            bonus.ResourceName,
            bonus.ItemId);
}

static ProductionBonusDto? SelectRegionalProductionBonus(TerritoryMapResponseDto? territory, FactoryDto factory)
{
    if (territory?.Regions is null || territory.Regions.Length == 0)
    {
        return null;
    }

    var matchedResource = territory.Regions
        .SelectMany(region => (region.Resources ?? []).Select(resource => new
        {
            Region = region,
            Resource = resource,
            Score = ProductionResourceMatchScore(factory, resource)
        }))
        .Where(candidate => candidate.Score > 0 && candidate.Resource.ProductionBonusPercent > 0)
        .OrderByDescending(candidate => candidate.Score)
        .ThenByDescending(candidate => candidate.Resource.ProductionBonusPercent)
        .ThenByDescending(candidate => candidate.Resource.AbundancePercent)
        .FirstOrDefault();
    if (matchedResource is not null)
    {
        return new ProductionBonusDto(
            matchedResource.Resource.ProductionBonusPercent,
            matchedResource.Region.RegionId,
            matchedResource.Region.Name,
            matchedResource.Resource.Name,
            matchedResource.Resource.ItemId);
    }

    var matchedLegacyBonus = territory.Regions
        .Where(region => region.Bonus is not null)
        .Select(region => new
        {
            Region = region,
            Bonus = region.Bonus!,
            Score = LegacyProductionBonusMatchScore(factory, region.Bonus!)
        })
        .Where(candidate => candidate.Score > 0 && candidate.Bonus.EffectiveProductionBonusPercent > 0)
        .OrderByDescending(candidate => candidate.Score)
        .ThenByDescending(candidate => candidate.Bonus.EffectiveProductionBonusPercent)
        .FirstOrDefault();

    return matchedLegacyBonus is null
        ? null
        : new ProductionBonusDto(
            matchedLegacyBonus.Bonus.EffectiveProductionBonusPercent,
            matchedLegacyBonus.Region.RegionId,
            matchedLegacyBonus.Region.Name,
            matchedLegacyBonus.Region.ResourceFocus,
            string.IsNullOrWhiteSpace(matchedLegacyBonus.Bonus.ResourceType)
                ? factory.InputItemId
                : matchedLegacyBonus.Bonus.ResourceType);
}

static int ProductionResourceMatchScore(FactoryDto factory, RegionResourceGatewayDto resource)
{
    if (string.Equals(resource.ItemId, factory.InputItemId, StringComparison.OrdinalIgnoreCase))
    {
        return 40;
    }

    if (string.Equals(resource.ItemId, factory.OutputItemId, StringComparison.OrdinalIgnoreCase))
    {
        return 30;
    }

    if (string.Equals(resource.Category, factory.Category, StringComparison.OrdinalIgnoreCase))
    {
        return 20;
    }

    return string.Equals(resource.ItemId, "trade_goods", StringComparison.OrdinalIgnoreCase)
        ? 10
        : 0;
}

static int LegacyProductionBonusMatchScore(FactoryDto factory, RegionResourceBonusGatewayDto bonus)
{
    if (string.Equals(bonus.ResourceType, factory.InputItemId, StringComparison.OrdinalIgnoreCase))
    {
        return 30;
    }

    return string.Equals(bonus.ResourceType, factory.OutputItemId, StringComparison.OrdinalIgnoreCase)
        ? 20
        : 10;
}

static ProductionBonusDto? ToProductionBonus(ProductionStartRequestDto request)
{
    return request.OutputBonusPercent.GetValueOrDefault() <= 0
        ? null
        : new ProductionBonusDto(
            request.OutputBonusPercent.GetValueOrDefault(),
            request.BonusSourceRegionId ?? string.Empty,
            request.BonusSourceRegionName ?? "Controlled region",
            request.BonusResourceName ?? "Regional resource",
            request.BonusItemId ?? string.Empty);
}

static async Task<IResult> ReportChatMessage(
    string playerId,
    string messageId,
    ContentReportGatewayRequest reportRequest,
    HttpRequest request,
    SocialChatServiceClient socialChat,
    AdminServiceClient adminService,
    IConfiguration configuration,
    DevTokenValidator tokens)
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var reason = reportRequest.Reason?.Trim();
    if (reason is not { Length: >= 5 and <= 500 })
    {
        return Results.BadRequest(new ErrorResponse("Report reason must be between 5 and 500 characters."));
    }

    var details = reportRequest.Details?.Trim();
    if ((details?.Length ?? 0) > 2_000)
    {
        return Results.BadRequest(new ErrorResponse("Report details must be 2000 characters or fewer."));
    }

    var adminToken = configuration["FF_ADMIN_TOKEN"]
        ?? configuration["Admin:Token"];
    if (string.IsNullOrWhiteSpace(adminToken))
    {
        return Results.Json(
            new ErrorResponse("Content reporting is disabled because FF_ADMIN_TOKEN is not configured."),
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    var message = await socialChat.GetJsonAsync<MessageDto>(
        $"messages/{Uri.EscapeDataString(messageId)}",
        authorizationHeader: string.Empty);
    if (message.Error is not null)
    {
        return message.Error;
    }

    var value = message.Value!;
    var item = await adminService.PostJsonAsync<AdminCreateContentQueueItemRequest, AdminContentModerationItemDto>(
        "admin/moderation/content-queue",
        adminToken.Trim(),
        access.PlayerId!,
        new AdminCreateContentQueueItemRequest(
            SourceType: "chat_message",
            SourceId: value.Id,
            PlayerId: value.FromId,
            Content: value.Content,
            Reason: reason,
            ReporterPlayerId: access.PlayerId!,
            Details: details));
    if (item.Error is not null)
    {
        return item.Error;
    }

    return Results.Ok(new ContentReportGatewayResult(
        Completed: true,
        Message: "Report submitted for moderator review.",
        ItemId: item.Value!.ItemId,
        Status: item.Value.Status,
        ReportCount: item.Value.ReportCount));
}

static string StableGatewayId(string prefix, params string[] parts)
{
    var input = string.Join(':', parts.Select(part => part.Trim().ToLowerInvariant()));
    var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(input))).ToLowerInvariant();
    return $"{prefix}-{hash[..32]}";
}

static async Task<ServiceJsonResult<DailyObjectivesResponseDto>> TrackDailyObjectiveAsync(
    PlayerServiceClient players,
    string playerId,
    string authorization,
    IConfiguration configuration,
    string actionType,
    string idempotencyKey,
    int quantity = 1)
{
    return await players.PostJsonAsync<DailyObjectiveTrackRequestDto, DailyObjectivesResponseDto>(
        $"players/{Uri.EscapeDataString(playerId)}/daily-objectives/track",
        authorization,
        new DailyObjectiveTrackRequestDto(
            ActionType: actionType,
            Quantity: Math.Max(1, quantity),
            IdempotencyKey: idempotencyKey.ToLowerInvariant()),
        InternalToken(configuration));
}

static async Task<IResult> GetPublicPlayerProfile(
    string playerId,
    IdentityServiceClient identity,
    PlayerServiceClient players,
    EconomyServiceClient economy)
{
    var normalizedPlayerId = NormalizePublicPlayerId(playerId);
    if (normalizedPlayerId is null)
    {
        return Results.BadRequest(new ErrorResponse("Player id is required."));
    }

    var escapedPlayerId = Uri.EscapeDataString(normalizedPlayerId);
    var identityResult = await identity.GetJsonAsync<PublicPlayerIdentityDto>($"players/{escapedPlayerId}/public");
    if (identityResult.Error is not null)
    {
        return identityResult.Error;
    }

    var stateTask = players.GetJsonAsync<PublicPlayerStateDto>($"players/{escapedPlayerId}/public-state", string.Empty);
    var equipmentTask = economy.GetJsonAsync<EquipmentResponseDto>($"players/{escapedPlayerId}/equipment", string.Empty);
    await Task.WhenAll(stateTask, equipmentTask);

    var stateResult = stateTask.Result;
    if (stateResult.Error is not null)
    {
        return stateResult.Error;
    }

    var equipmentResult = equipmentTask.Result;
    if (equipmentResult.Error is not null)
    {
        return equipmentResult.Error;
    }

    var rankingResult = await players.GetJsonAsync<PlayerRankingEntryDto>(
        $"players/{escapedPlayerId}/ranking?sortBy=level",
        string.Empty);

    var identityProfile = identityResult.Value!;
    var state = stateResult.Value!;
    var equipment = equipmentResult.Value!;
    return Results.Ok(new PublicPlayerProfileResponse(
        PlayerId: state.PlayerId,
        Username: SafeDisplayName(identityProfile.Username, state.PlayerId),
        Level: state.Level,
        Experience: state.Experience,
        Strength: state.Strength,
        Energy: state.Energy,
        MaxEnergy: state.MaxEnergy,
        Rank: rankingResult.Value?.Rank,
        EquippedWeapon: equipment.Weapon,
        CreatedOn: identityProfile.CreatedOn,
        UpdatedAt: state.UpdatedAt));
}

static async Task<IResult> GetPublicRankings(
    string? sortBy,
    int? limit,
    IdentityServiceClient identity,
    PlayerServiceClient players)
{
    var normalizedSortBy = NormalizeRankingSort(sortBy);
    var safeLimit = ClampRankingLimit(limit);
    var rankingsResult = await players.GetJsonAsync<PlayerRankingsResponseDto>(
        $"players/rankings?sortBy={Uri.EscapeDataString(normalizedSortBy)}&limit={safeLimit}",
        string.Empty);
    if (rankingsResult.Error is not null)
    {
        return rankingsResult.Error;
    }

    var rankings = rankingsResult.Value!;
    var entries = await EnrichRankingEntriesAsync(rankings.Entries, identity);
    return Results.Ok(new RankingsLeaderboardResponse(
        SortBy: rankings.SortBy,
        Limit: rankings.Limit,
        TotalPlayers: rankings.TotalPlayers,
        Entries: entries,
        UpdatedAt: rankings.UpdatedAt));
}

static async Task<IResult> GetPublicPlayerRanking(
    string playerId,
    string? sortBy,
    IdentityServiceClient identity,
    PlayerServiceClient players)
{
    var normalizedPlayerId = NormalizePublicPlayerId(playerId);
    if (normalizedPlayerId is null)
    {
        return Results.BadRequest(new ErrorResponse("Player id is required."));
    }

    var normalizedSortBy = NormalizeRankingSort(sortBy);
    var escapedPlayerId = Uri.EscapeDataString(normalizedPlayerId);
    var rankingResult = await players.GetJsonAsync<PlayerRankingEntryDto>(
        $"players/{escapedPlayerId}/ranking?sortBy={Uri.EscapeDataString(normalizedSortBy)}",
        string.Empty);
    if (rankingResult.Error is not null)
    {
        return rankingResult.Error;
    }

    var enriched = await EnrichRankingEntryAsync(rankingResult.Value!, identity);
    return Results.Ok(enriched);
}

static async Task<PublicRankingEntryDto[]> EnrichRankingEntriesAsync(
    PlayerRankingEntryDto[] entries,
    IdentityServiceClient identity)
{
    var tasks = entries.Select(entry => EnrichRankingEntryAsync(entry, identity));
    return await Task.WhenAll(tasks);
}

static async Task<PublicRankingEntryDto> EnrichRankingEntryAsync(
    PlayerRankingEntryDto entry,
    IdentityServiceClient identity)
{
    var identityResult = await identity.GetJsonAsync<PublicPlayerIdentityDto>(
        $"players/{Uri.EscapeDataString(entry.PlayerId)}/public");
    var username = identityResult.Value?.Username;
    return new PublicRankingEntryDto(
        Rank: entry.Rank,
        PlayerId: entry.PlayerId,
        Username: SafeDisplayName(username, entry.PlayerId),
        Level: entry.Level,
        Experience: entry.Experience,
        Strength: entry.Strength,
        Energy: entry.Energy,
        MaxEnergy: entry.MaxEnergy,
        UpdatedAt: entry.UpdatedAt);
}

static string? NormalizePublicPlayerId(string playerId)
{
    return string.IsNullOrWhiteSpace(playerId)
        ? null
        : playerId.Trim().ToLowerInvariant();
}

static string NormalizeRankingSort(string? sortBy)
{
    var normalized = string.IsNullOrWhiteSpace(sortBy)
        ? "level"
        : sortBy.Trim().ToLowerInvariant();
    return normalized switch
    {
        "experience" or "xp" => "experience",
        "strength" => "strength",
        _ => "level"
    };
}

static int ClampRankingLimit(int? limit)
{
    return Math.Clamp(limit ?? 50, 1, 100);
}

static string SafeDisplayName(string? username, string playerId)
{
    return string.IsNullOrWhiteSpace(username) ? playerId : username.Trim();
}

internal sealed class IdentityServiceClient(HttpClient httpClient)
{
    public Task<IResult> GetAsync(string path)
    {
        return ForwardAsync(() => httpClient.GetAsync(path));
    }

    public Task<IResult> GetAsync(string path, string authorizationHeader)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Get, path, authorizationHeader));
    }

    public Task<ServiceJsonResult<TResponse>> GetJsonAsync<TResponse>(string path)
    {
        return JsonAsync<TResponse>(() => httpClient.GetAsync(path));
    }

    public Task<IResult> PostAsync<TRequest>(string path, TRequest request)
    {
        return ForwardAsync(() => httpClient.PostAsJsonAsync(path, request));
    }

    public Task<IResult> PostAsync<TRequest>(string path, TRequest request, string authorizationHeader)
    {
        return ForwardAsync(() => SendJsonAsync(path, request, authorizationHeader));
    }

    private HttpRequestMessage CreateMessage(HttpMethod method, string path, string authorizationHeader)
    {
        var message = new HttpRequestMessage(method, path);
        if (!string.IsNullOrWhiteSpace(authorizationHeader))
        {
            message.Headers.TryAddWithoutValidation("Authorization", authorizationHeader);
        }

        return message;
    }

    private Task<HttpResponseMessage> SendAsync(HttpMethod method, string path, string authorizationHeader)
    {
        return httpClient.SendAsync(CreateMessage(method, path, authorizationHeader));
    }

    private Task<HttpResponseMessage> SendJsonAsync<TRequest>(
        string path,
        TRequest request,
        string authorizationHeader)
    {
        var message = CreateMessage(HttpMethod.Post, path, authorizationHeader);
        message.Content = JsonContent.Create(request);
        return httpClient.SendAsync(message);
    }

    private static async Task<IResult> ForwardAsync(Func<Task<HttpResponseMessage>> send)
    {
        try
        {
            using var response = await send();
            var content = await response.Content.ReadAsStringAsync();
            var contentType = response.Content.Headers.ContentType?.ToString() ?? "application/json";
            return Results.Content(content, contentType, statusCode: (int)response.StatusCode);
        }
        catch (HttpRequestException)
        {
            return Results.Json(
                new ErrorResponse("Identity service is unavailable."),
                statusCode: StatusCodes.Status502BadGateway);
        }
        catch (TaskCanceledException)
        {
            return Results.Json(
                new ErrorResponse("Identity service request timed out."),
                statusCode: StatusCodes.Status504GatewayTimeout);
        }
    }

    private static async Task<ServiceJsonResult<TResponse>> JsonAsync<TResponse>(Func<Task<HttpResponseMessage>> send)
    {
        try
        {
            using var response = await send();
            if (!response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                var contentType = response.Content.Headers.ContentType?.ToString() ?? "application/json";
                return ServiceJsonResult<TResponse>.Failed(
                    Results.Content(content, contentType, statusCode: (int)response.StatusCode));
            }

            var value = await response.Content.ReadFromJsonAsync<TResponse>();
            return value is null
                ? ServiceJsonResult<TResponse>.Failed(Results.Json(
                    new ErrorResponse("Identity service returned an empty response."),
                    statusCode: StatusCodes.Status502BadGateway))
                : ServiceJsonResult<TResponse>.Succeeded(value);
        }
        catch (HttpRequestException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse("Identity service is unavailable."),
                statusCode: StatusCodes.Status502BadGateway));
        }
        catch (TaskCanceledException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse("Identity service request timed out."),
                statusCode: StatusCodes.Status504GatewayTimeout));
        }
        catch (JsonException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse("Identity service returned an invalid response."),
                statusCode: StatusCodes.Status502BadGateway));
        }
    }
}

internal abstract class ForwardingServiceClient(HttpClient httpClient, string serviceName)
{
    public Task<IResult> GetAsync(string path, string authorizationHeader, string? internalToken = null)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Get, path, authorizationHeader, internalToken));
    }

    public Task<IResult> PostAsync(string path, string authorizationHeader)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Post, path, authorizationHeader));
    }

    public Task<IResult> PostJsonForwardAsync<TRequest>(
        string path,
        string authorizationHeader,
        TRequest body,
        string? internalToken = null)
    {
        return ForwardAsync(() => SendJsonAsync(path, authorizationHeader, body, internalToken));
    }

    public Task<ServiceJsonResult<TResponse>> GetJsonAsync<TResponse>(
        string path,
        string authorizationHeader,
        string? internalToken = null)
    {
        return JsonAsync<TResponse>(() => SendAsync(HttpMethod.Get, path, authorizationHeader, internalToken));
    }

    public Task<ServiceJsonResult<TResponse>> PostJsonAsync<TRequest, TResponse>(
        string path,
        string authorizationHeader,
        TRequest body,
        string? internalToken = null)
    {
        return JsonAsync<TResponse>(() => SendJsonAsync(path, authorizationHeader, body, internalToken));
    }

    private Task<HttpResponseMessage> SendAsync(
        HttpMethod method,
        string path,
        string authorizationHeader,
        string? internalToken = null)
    {
        var message = new HttpRequestMessage(method, path);
        if (!string.IsNullOrWhiteSpace(authorizationHeader))
        {
            message.Headers.TryAddWithoutValidation("Authorization", authorizationHeader);
        }
        if (!string.IsNullOrWhiteSpace(internalToken))
        {
            message.Headers.TryAddWithoutValidation("X-FF-Internal-Token", internalToken);
        }

        return httpClient.SendAsync(message);
    }

    private Task<HttpResponseMessage> SendJsonAsync<TRequest>(
        string path,
        string authorizationHeader,
        TRequest body,
        string? internalToken)
    {
        var message = new HttpRequestMessage(HttpMethod.Post, path);
        if (!string.IsNullOrWhiteSpace(authorizationHeader))
        {
            message.Headers.TryAddWithoutValidation("Authorization", authorizationHeader);
        }
        if (!string.IsNullOrWhiteSpace(internalToken))
        {
            message.Headers.TryAddWithoutValidation("X-FF-Internal-Token", internalToken);
        }

        message.Content = JsonContent.Create(body);
        return httpClient.SendAsync(message);
    }

    private async Task<IResult> ForwardAsync(Func<Task<HttpResponseMessage>> send)
    {
        try
        {
            using var response = await send();
            var content = await response.Content.ReadAsStringAsync();
            var contentType = response.Content.Headers.ContentType?.ToString() ?? "application/json";
            return Results.Content(content, contentType, statusCode: (int)response.StatusCode);
        }
        catch (HttpRequestException)
        {
            return Results.Json(
                new ErrorResponse($"{serviceName} is unavailable."),
                statusCode: StatusCodes.Status502BadGateway);
        }
        catch (TaskCanceledException)
        {
            return Results.Json(
                new ErrorResponse($"{serviceName} request timed out."),
                statusCode: StatusCodes.Status504GatewayTimeout);
        }
    }

    private async Task<ServiceJsonResult<TResponse>> JsonAsync<TResponse>(Func<Task<HttpResponseMessage>> send)
    {
        try
        {
            using var response = await send();
            if (!response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                var contentType = response.Content.Headers.ContentType?.ToString() ?? "application/json";
                return ServiceJsonResult<TResponse>.Failed(
                    Results.Content(content, contentType, statusCode: (int)response.StatusCode));
            }

            var value = await response.Content.ReadFromJsonAsync<TResponse>();
            return value is null
                ? ServiceJsonResult<TResponse>.Failed(Results.Json(
                    new ErrorResponse($"{serviceName} returned an empty response."),
                    statusCode: StatusCodes.Status502BadGateway))
                : ServiceJsonResult<TResponse>.Succeeded(value);
        }
        catch (HttpRequestException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse($"{serviceName} is unavailable."),
                statusCode: StatusCodes.Status502BadGateway));
        }
        catch (TaskCanceledException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse($"{serviceName} request timed out."),
                statusCode: StatusCodes.Status504GatewayTimeout));
        }
        catch (JsonException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse($"{serviceName} returned an invalid response."),
                statusCode: StatusCodes.Status502BadGateway));
        }
    }
}

internal sealed class PlayerServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Player service");

internal sealed class EconomyServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Economy service");

internal sealed class ProductionServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Production service");

internal sealed class MarketServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Market service");

internal sealed class CombatServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Combat service");

internal sealed class SocialChatServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Social chat service");

internal sealed class WorldServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "World service");

internal sealed class NotificationServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Notification service");

internal sealed class DevTokenValidator
{
    private readonly byte[] _secret;
    private readonly TimeSpan _legacyTokenLifetime;
    private static readonly TimeSpan ClockSkew = TimeSpan.FromMinutes(2);

    public DevTokenValidator(IConfiguration configuration)
    {
        var secret = configuration["FF_IDENTITY_TOKEN_SECRET"]
            ?? configuration["Identity:TokenSecret"]
            ?? "ff-development-token-secret-change-me";
        _secret = Encoding.UTF8.GetBytes(secret);

        var lifetimeMinutes = configuration.GetValue(
            "FF_IDENTITY_ACCESS_TOKEN_LIFETIME_MINUTES",
            configuration.GetValue("FF_IDENTITY_TOKEN_LIFETIME_MINUTES", 15));
        _legacyTokenLifetime = TimeSpan.FromMinutes(Math.Clamp(lifetimeMinutes, 1, 24 * 60));
    }

    public TokenValidationResult Validate(string authorizationHeader)
    {
        const string bearerPrefix = "Bearer ";
        if (string.IsNullOrWhiteSpace(authorizationHeader) ||
            authorizationHeader.Contains('\n') ||
            authorizationHeader.Contains('\r') ||
            authorizationHeader.Contains(',') ||
            !authorizationHeader.StartsWith(bearerPrefix, StringComparison.Ordinal))
        {
            return TokenValidationResult.Invalid;
        }

        var token = authorizationHeader[bearerPrefix.Length..].Trim();
        var tokenParts = token.Split('.', 2);
        if (tokenParts.Length != 2 ||
            string.IsNullOrWhiteSpace(tokenParts[0]) ||
            string.IsNullOrWhiteSpace(tokenParts[1]))
        {
            return TokenValidationResult.Invalid;
        }

        try
        {
            var payloadBytes = Base64UrlDecode(tokenParts[0]);
            var expectedSignature = HMACSHA256.HashData(_secret, payloadBytes);
            var actualSignature = Base64UrlDecode(tokenParts[1]);
            if (actualSignature.Length != expectedSignature.Length ||
                !CryptographicOperations.FixedTimeEquals(expectedSignature, actualSignature))
            {
                return TokenValidationResult.Invalid;
            }

            var payloadParts = Encoding.UTF8.GetString(payloadBytes).Split('|', 3);
            if (payloadParts.Length != 3 ||
                string.IsNullOrWhiteSpace(payloadParts[0]) ||
                !long.TryParse(payloadParts[2], out var issuedAtSeconds))
            {
                return TokenValidationResult.Invalid;
            }

            var issuedAt = DateTimeOffset.FromUnixTimeSeconds(issuedAtSeconds);
            var now = DateTimeOffset.UtcNow;
            if (issuedAt - now > ClockSkew)
            {
                return TokenValidationResult.Invalid;
            }

            if (TryReadClaims(payloadParts[1], out var claims))
            {
                if (!string.Equals(claims.Type, "access", StringComparison.Ordinal) ||
                    string.IsNullOrWhiteSpace(claims.AccountId))
                {
                    return TokenValidationResult.Invalid;
                }

                var expiresAt = DateTimeOffset.FromUnixTimeSeconds(claims.ExpiresAt);
                if (now - expiresAt > ClockSkew)
                {
                    return TokenValidationResult.Invalid;
                }

                return TokenValidationResult.Valid(
                    payloadParts[0],
                    claims.AccountId,
                    claims.Roles.Length == 0 ? ["player"] : claims.Roles,
                    claims.EmailVerified);
            }

            if (now - issuedAt > _legacyTokenLifetime)
            {
                return TokenValidationResult.Invalid;
            }

            return TokenValidationResult.Valid(payloadParts[0], payloadParts[1], ["player"], false);
        }
        catch (Exception ex) when (ex is FormatException or JsonException or ArgumentException or OverflowException)
        {
            return TokenValidationResult.Invalid;
        }
    }

    private static bool TryReadClaims(string value, out AccessTokenClaims claims)
    {
        try
        {
            var json = Encoding.UTF8.GetString(Base64UrlDecode(value));
            var parsed = JsonSerializer.Deserialize<AccessTokenClaims>(json);
            if (parsed is not null)
            {
                claims = parsed;
                return true;
            }
        }
        catch (Exception ex) when (ex is FormatException or JsonException or ArgumentException)
        {
        }

        claims = default!;
        return false;
    }

    private static byte[] Base64UrlDecode(string value)
    {
        var base64 = value.Replace('-', '+').Replace('_', '/');
        var padding = base64.Length % 4;
        if (padding > 0)
        {
            base64 = base64.PadRight(base64.Length + 4 - padding, '=');
        }

        return Convert.FromBase64String(base64);
    }
}

internal sealed record PlayerAccessResult(IResult? Error, string? PlayerId)
{
    public static PlayerAccessResult Allowed(string playerId)
    {
        return new PlayerAccessResult(null, playerId);
    }

    public static PlayerAccessResult Denied(IResult error)
    {
        return new PlayerAccessResult(error, null);
    }
}

internal sealed record TokenValidationResult(bool IsValid, string? PlayerId, string? AccountId, string[] Roles, bool EmailVerified)
{
    public static TokenValidationResult Invalid { get; } = new(false, null, null, [], false);

    public static TokenValidationResult Valid(string playerId, string accountId, string[] roles, bool emailVerified)
    {
        return new TokenValidationResult(true, playerId, accountId, roles, emailVerified);
    }
}

internal sealed record AccessTokenClaims(
    [property: JsonPropertyName("accountId")] string AccountId,
    [property: JsonPropertyName("roles")] string[] Roles,
    [property: JsonPropertyName("emailVerified")] bool EmailVerified,
    [property: JsonPropertyName("typ")] string Type,
    [property: JsonPropertyName("exp")] long ExpiresAt,
    [property: JsonPropertyName("jti")] string JwtId);

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record LoginRequest(string? Email, string? Password);

internal sealed record RegisterRequest(string? Email, string? Password, string? Username);

internal sealed record RefreshRequest(string? RefreshToken);

internal sealed record LogoutRequest(string? RefreshToken, bool AllSessions = false);

internal sealed record PasswordResetRequest(string? Email);

internal sealed record PasswordResetConfirmRequest(string? Token, string? Password);

internal sealed record EmailVerificationConfirmRequest(string? Token);

internal sealed record SendMessageRequest(string Content, string FromId, string ToId);

internal sealed record CitizenshipRequest(string? CountryId);

internal sealed record CreateCompanyRequest(string? Name, string? Description);

internal sealed record CompanyActorRequest(string ActorPlayerId);

internal sealed record CompanyMemberRoleUpdateRequest(string? Role);

internal sealed record CompanyMemberRoleRequest(string ActorPlayerId, string? Role);

internal sealed record CompanySpecializationGatewayRequest(string? Specialization);

internal sealed record CompanySpecializationRequest(string ActorPlayerId, string? Specialization);

internal sealed record MessageDto(
    string Id,
    string FromId,
    string ToId,
    string Content,
    DateTimeOffset? CreatedAt = null);

internal sealed record ServiceJsonResult<T>(T? Value, IResult? Error)
{
    public static ServiceJsonResult<T> Succeeded(T value)
    {
        return new ServiceJsonResult<T>(value, null);
    }

    public static ServiceJsonResult<T> Failed(IResult error)
    {
        return new ServiceJsonResult<T>(default, error);
    }
}

internal sealed record PlayerStateForCombat(int Energy, int Strength);

internal sealed record PlayerStateForEnergyDto(int Energy, int MaxEnergy);

internal sealed record PlayerStateForHospitalDto(
    int Energy,
    int MaxEnergy,
    DateTimeOffset? HospitalCooldownUntil,
    int HospitalGoldCost);

internal sealed record PublicPlayerIdentityDto(
    string Uid,
    string Username,
    [property: JsonPropertyName("created_on")] string CreatedOn);

internal sealed record PublicPlayerStateDto(
    string PlayerId,
    int Level,
    int Experience,
    int Energy,
    int MaxEnergy,
    int Strength,
    DateTimeOffset UpdatedAt);

internal sealed record PublicPlayerProfileResponse(
    string PlayerId,
    string Username,
    int Level,
    int Experience,
    int Strength,
    int Energy,
    int MaxEnergy,
    int? Rank,
    EquippedWeaponDto? EquippedWeapon,
    string CreatedOn,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerRankingsResponseDto(
    string SortBy,
    int Limit,
    int TotalPlayers,
    PlayerRankingEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerRankingEntryDto(
    int Rank,
    string PlayerId,
    int Level,
    int Experience,
    int Strength,
    int Energy,
    int MaxEnergy,
    DateTimeOffset UpdatedAt);

internal sealed record RankingsLeaderboardResponse(
    string SortBy,
    int Limit,
    int TotalPlayers,
    PublicRankingEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record PublicRankingEntryDto(
    int Rank,
    string PlayerId,
    string Username,
    int Level,
    int Experience,
    int Strength,
    int Energy,
    int MaxEnergy,
    DateTimeOffset UpdatedAt);

internal sealed record MissionProgressResponseDto(
    string PlayerId,
    MissionProgressDto[] Missions,
    DateTimeOffset UpdatedAt);

internal sealed record MissionProgressDto(
    string MissionId,
    int Attempts,
    int Wins,
    int Losses,
    int TotalRounds,
    bool LastWon,
    string LastResult,
    DateTimeOffset? LastAttemptedAt,
    DateTimeOffset? CooldownUntil,
    DateTimeOffset UpdatedAt);

internal sealed record DailyObjectivesResponseDto(
    string PlayerId,
    DateOnly ResetDate,
    DateTimeOffset ResetAt,
    DailyObjectiveDto[] Objectives,
    DateTimeOffset UpdatedAt);

internal sealed record DailyObjectiveDto(
    string ObjectiveId,
    string ActionType,
    string Title,
    string Description,
    int CurrentCount,
    int TargetCount,
    PlayerRewardsDto Rewards,
    bool Completed,
    bool Claimed,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? ClaimedAt,
    DateOnly ResetDate,
    DateTimeOffset ResetAt,
    int DisplayOrder);

internal sealed record DailyObjectiveTrackRequestDto(
    string ActionType,
    int Quantity,
    string IdempotencyKey);

internal sealed record DailyObjectiveClaimRequestDto(string IdempotencyKey);

internal sealed record DailyObjectiveClaimResponseDto(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    object? State,
    DailyObjectiveDto? Objective,
    DailyObjectivesResponseDto Objectives);

internal sealed record DailyObjectiveClaimGatewayResponse(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    object? State,
    DailyObjectiveDto? Objective,
    DailyObjectivesResponseDto Objectives,
    InventoryResponseDto? Wallet);

internal sealed record InventoryConversionRequestDto(
    string InputItemId,
    int InputQuantity,
    string OutputItemId,
    int OutputQuantity,
    string Reason);

internal sealed record InventoryMutationResponseDto(
    bool Completed,
    string Message,
    ItemChangeDto[] Changes,
    InventoryResponseDto Inventory);

internal sealed record InventoryResponseDto(
    string PlayerId,
    int WalletGold,
    int StorageUsed,
    int StorageLimit,
    InventoryItemDto[] Items,
    DateTimeOffset UpdatedAt);

internal sealed record InventoryItemDto(
    string ItemId,
    string Name,
    string Category,
    int Quantity,
    string Description);

internal sealed record EquipmentResponseDto(
    string PlayerId,
    EquippedWeaponDto? Weapon,
    DateTimeOffset UpdatedAt);

internal sealed record EquippedWeaponDto(
    string ItemId,
    string Name,
    string Category,
    int WeaponPower,
    int Durability,
    int MaxDurability,
    DateTimeOffset EquippedAt,
    DateTimeOffset UpdatedAt);

internal sealed record EquipWeaponGatewayRequest(string ItemId);

internal sealed record EquipWeaponRequestDto(
    string ItemId,
    string IdempotencyKey);

internal sealed record EquipWeaponResponseDto(
    bool Completed,
    string Message,
    EquipmentResponseDto Equipment,
    InventoryResponseDto Inventory);

internal sealed record DamageWeaponRequestDto(
    int DurabilityDamage,
    string Reason,
    string IdempotencyKey);

internal sealed record DamageWeaponResponseDto(
    bool Completed,
    string Message,
    int DurabilityLost,
    EquipmentResponseDto Equipment);

internal sealed record RepairWeaponRequestDto(string IdempotencyKey);

internal sealed record RepairWeaponResponseDto(
    bool Completed,
    string Message,
    int GoldCost,
    string MaterialItemId,
    string MaterialItemName,
    int MaterialQuantity,
    EquipmentResponseDto Equipment,
    InventoryResponseDto Inventory);

internal sealed record ItemChangeDto(
    string ItemId,
    string Name,
    int QuantityDelta,
    int FinalQuantity);

internal sealed record ProductionResultDto(
    bool Completed,
    string FactoryId,
    string Message,
    string ConsumedItemId,
    int ConsumedQuantity,
    string ProducedItemId,
    int ProducedQuantity,
    string Note,
    DateTimeOffset CompletedAt,
    int ProductionCount = 0,
    DateTimeOffset? LastProducedAt = null,
    InventoryResponseDto? Inventory = null,
    ProductionJobDto? Job = null,
    DateTimeOffset? StartedAt = null,
    DateTimeOffset? CompletesAt = null,
    ProductionBonusDto? AppliedBonus = null,
    DailyObjectivesResponseDto? DailyObjectives = null);

internal sealed record ProductionBonusDto(
    int ProductionBonusPercent,
    string SourceRegionId,
    string SourceRegionName,
    string ResourceName,
    string ItemId);

internal sealed record ProductionStartRequestDto(
    int? OutputBonusPercent = null,
    string? BonusSourceRegionId = null,
    string? BonusSourceRegionName = null,
    string? BonusResourceName = null,
    string? BonusItemId = null);

internal sealed record CompanyProductionStartRequest(
    string ActorPlayerId,
    int? OutputBonusPercent = null,
    string? BonusSourceRegionId = null,
    string? BonusSourceRegionName = null,
    string? BonusResourceName = null,
    string? BonusItemId = null);

internal sealed record FactoryDto(
    string FactoryId,
    string Name,
    string Category,
    int Level,
    string InputItemId,
    int InputQuantity,
    string OutputItemId,
    int OutputQuantity,
    bool CanProduce,
    int ProductionCount,
    DateTimeOffset? LastProducedAt,
    DateTimeOffset? CooldownUntil = null,
    int ProductionDurationSeconds = 0,
    string? ActiveJobId = null,
    int QueueDepth = 0,
    int MaxQueueDepth = 0,
    ProductionBonusDto? ResourceEffect = null);

internal sealed record FactoryPortfolioResponseDto(
    string PlayerId,
    FactoryDto[] Factories,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyAssetsGatewayDto(FactoryDto[] Factories);

internal sealed record TerritoryMapResponseDto(
    TerritoryRegionGatewayDto[] Regions,
    DateTimeOffset UpdatedAt);

internal sealed record TerritoryRegionGatewayDto(
    string RegionId,
    string Name,
    string ResourceFocus,
    string OwnerCountryId,
    RegionResourceBonusGatewayDto? Bonus,
    RegionResourceGatewayDto[]? Resources);

internal sealed record RegionResourceBonusGatewayDto(
    string RegionId,
    string ResourceType,
    int ProductionBonusPercent,
    int MarketBonusPercent,
    int DefenseBonusPercent,
    int HospitalCapacity,
    int EffectiveProductionBonusPercent,
    int EffectiveMarketBonusPercent,
    DateTimeOffset UpdatedAt);

internal sealed record RegionResourceGatewayDto(
    string RegionId,
    string ResourceId,
    string ItemId,
    string Name,
    string Category,
    int AbundancePercent,
    int ProductionBonusPercent,
    int MarketBonusPercent,
    string Description,
    DateTimeOffset UpdatedAt);

internal sealed record ProductionJobsResponseDto(
    string PlayerId,
    ProductionJobDto[] Jobs,
    DateTimeOffset UpdatedAt);

internal sealed record ProductionJobDto(
    string JobId,
    string PlayerId,
    string FactoryId,
    string Status,
    string InputItemId,
    string InputItemName,
    string InputItemCategory,
    int InputQuantity,
    string OutputItemId,
    string OutputItemName,
    string OutputItemCategory,
    int OutputQuantity,
    int DurationSeconds,
    DateTimeOffset StartedAt,
    DateTimeOffset CompletesAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? ClaimedAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    bool CanClaim,
    ProductionBonusDto? AppliedBonus = null,
    int ResearchDurationReductionPercent = 0);

internal sealed record ProductionClaimTicketDto(
    bool ReadyToClaim,
    bool AlreadyClaimed,
    string Message,
    ProductionJobDto Job);

internal sealed record ProductionClaimCompletionDto(
    bool Completed,
    bool AlreadyClaimed,
    string Message,
    ProductionJobDto Job,
    int ProductionCount);

internal sealed record ProductionClaimGatewayResponse(
    bool Completed,
    string Message,
    ProductionClaimCompletionDto Claim,
    InventoryResponseDto? Inventory,
    DailyObjectivesResponseDto? DailyObjectives = null);

internal sealed record ProductionJobCancellationRequestDto(string Reason);

internal sealed record FactoryUpgradeQuoteDto(
    string FactoryId,
    int CurrentLevel,
    int NextLevel,
    int GoldCost,
    string RequiredItemId,
    string RequiredItemName,
    int RequiredItemQuantity,
    int OutputQuantityAfterUpgrade,
    bool CanUpgrade);

internal sealed record FactoryUpgradeResultDto(
    bool Upgraded,
    string FactoryId,
    string Message,
    FactoryDto Factory,
    FactoryUpgradeQuoteDto AppliedQuote,
    DateTimeOffset UpgradedAt);

internal sealed record FactoryUpgradeGatewayResponse(
    bool Completed,
    string Message,
    FactoryUpgradeResultDto Upgrade,
    InventoryResponseDto Inventory);

internal sealed record MarketListingDto(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string SellerId,
    string Status = "open",
    DateTimeOffset? CreatedAt = null,
    DateTimeOffset? UpdatedAt = null);

internal sealed record CreatePlayerListingRequest(
    string ItemId,
    int Quantity,
    int PricePerUnit);

internal sealed record CreateMarketListingRequestDto(
    string ListingId,
    string SellerId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit);

internal sealed record PurchaseListingRequestDto(
    string BuyerId,
    int Quantity,
    string ReservationId);

internal sealed record ReservationStatusRequestDto(string ReservationId);

internal sealed record MarketReservationResponseDto(
    bool Completed,
    string Message,
    string ReservationId,
    MarketListingDto? Listing,
    int Quantity,
    int RemainingQuantity);

internal sealed record MarketReservationStatusResponseDto(bool Completed, string Message);

internal sealed record MarketPurchaseRequestDto(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string SellerId,
    string IdempotencyKey,
    int BuyerTaxAmount = 0,
    int SellerTaxAmount = 0);

internal sealed record MarketPurchaseResponseDto(
    bool Completed,
    string Message,
    string ListingId,
    int Quantity,
    int TotalPrice,
    string SellerId,
    InventoryResponseDto Inventory,
    int BuyerTaxAmount = 0,
    int SellerTaxAmount = 0,
    int BuyerTotal = 0,
    int SellerNet = 0,
    CountryTaxCollectionResponseDto[]? TaxCollections = null);

internal sealed record InventoryRemovalRequestDto(
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    string Reason,
    string IdempotencyKey);

internal sealed record InventoryGrantRequestDto(
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record InventorySpendRequestDto(
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int GoldCost,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record InventoryItemUseResponse(
    bool Completed,
    string Message,
    InventoryResponseDto Inventory,
    PlayerActionResponseDto? PlayerAction);

internal sealed record MarketSellListingResponse(
    bool Completed,
    string Message,
    MarketListingDto Listing,
    InventoryResponseDto Inventory);

internal sealed record MarketCancelListingResponse(
    bool Completed,
    string Message,
    MarketListingDto Listing,
    InventoryResponseDto? Inventory);

internal sealed record WalletCreditRequestDto(
    int Amount,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record WalletCreditResponseDto(
    bool Completed,
    string Message,
    int Amount,
    InventoryResponseDto Inventory);

internal sealed record WalletDebitRequestDto(
    int Amount,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record WalletDebitResponseDto(
    bool Completed,
    string Message,
    int Amount,
    InventoryResponseDto Inventory);

internal sealed record CombatMissionDto(
    [property: JsonPropertyName("mission_id")] string MissionId,
    string Name,
    string Description,
    FighterDto Defender,
    int Rounds,
    [property: JsonPropertyName("reward_experience")] int RewardExperience,
    [property: JsonPropertyName("reward_gold")] int RewardGold);

internal sealed record FighterDto(
    int Strength,
    int Energy,
    [property: JsonPropertyName("weapon_power")] int WeaponPower);

internal sealed record FightRequestDto(FighterDto Attacker, FighterDto Defender, int Rounds);

internal sealed record FightResponseDto(
    string Winner,
    [property: JsonPropertyName("rounds_requested")] int RoundsRequested,
    [property: JsonPropertyName("rounds_completed")] int RoundsCompleted,
    [property: JsonPropertyName("attacker_damage")] int AttackerDamage,
    [property: JsonPropertyName("defender_damage")] int DefenderDamage,
    [property: JsonPropertyName("attacker_remaining_energy")] int AttackerRemainingEnergy,
    [property: JsonPropertyName("defender_remaining_energy")] int DefenderRemainingEnergy);

internal sealed record CombatResultRequestDto(
    int EnergyCost,
    int GoldReward,
    int ExperienceReward,
    string Message,
    string MissionId,
    bool Won,
    int RoundsCompleted,
    int AttackerDamage,
    int DefenderDamage,
    string IdempotencyKey);

internal sealed record RestoreEnergyRequestDto(
    int EnergyAmount,
    string Message,
    string IdempotencyKey);

internal sealed record HospitalRecoveryRequestDto(string IdempotencyKey);

internal sealed record PlayerActionResponseDto(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    object? State,
    MissionProgressDto? MissionProgress = null,
    InventoryResponseDto? Wallet = null,
    DailyObjectivesResponseDto? DailyObjectives = null,
    CountryTaxCollectionResponseDto[]? TaxCollections = null);

internal sealed record PlayerRewardsDto(int Gold, int Experience, int Strength, int Energy = 0)
{
    public static PlayerRewardsDto None { get; } = new(0, 0, 0, 0);
}

internal sealed record MissionFightResponse(
    CombatMissionDto Mission,
    FightResponseDto Fight,
    PlayerActionResponseDto PlayerAction,
    MissionProgressDto? MissionProgress,
    EquipmentResponseDto Equipment,
    DamageWeaponResponseDto? WeaponDamage,
    string Message,
    DailyObjectivesResponseDto? DailyObjectives = null);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

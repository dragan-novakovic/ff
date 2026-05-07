using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Ff.Player.Api.Players;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<PlayerProgressionStore>();
builder.Services.AddSingleton<DevTokenValidator>();

var metadata = new ServiceMetadata(
    Service: "player-service",
    DisplayName: "Player Service",
    Domain: "Player profile, progression, and energy state",
    Description: "Owns player profile and progression state such as level, XP, energy, strength, daily counters, and recovery cooldowns.",
    Owns: ["player profiles", "levels and XP", "energy", "strength", "daily status", "hospital recovery", "tutorial state"],
    Responsibilities: ["Serve player profile reads", "Apply progression changes atomically", "Regenerate energy over time", "Own daily player reset state"]);

var app = builder.Build();

var progressionStore = app.Services.GetRequiredService<PlayerProgressionStore>();
await progressionStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/players/rankings", async (
    string? sortBy,
    int? limit,
    PlayerProgressionStore players) =>
    Results.Ok(await players.GetRankingsAsync(sortBy, limit))).WithName("GetPlayerRankings");

app.MapGet("/players/{playerId}/ranking", async (
    string playerId,
    string? sortBy,
    PlayerProgressionStore players) =>
{
    var ranking = await players.GetRankingAsync(playerId, sortBy);
    return ranking is null
        ? Results.NotFound(new ErrorResponse("Player ranking was not found."))
        : Results.Ok(ranking);
}).WithName("GetPlayerRanking");

app.MapGet("/players/{playerId}/public-state", async (
    string playerId,
    PlayerProgressionStore players) =>
    Results.Ok(await players.GetStateAsync(playerId))).WithName("GetPublicPlayerState");

app.MapGet("/players/{playerId}/state", async (
    string playerId,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.GetStateAsync(access.PlayerId!));
}).WithName("GetPlayerState");

app.MapGet("/players/{playerId}/missions/progress", async (
    string playerId,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.GetMissionProgressAsync(access.PlayerId!));
}).WithName("GetMissionProgress");

app.MapGet("/players/{playerId}/daily-objectives", async (
    string playerId,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.GetDailyObjectivesAsync(access.PlayerId!));
}).WithName("GetDailyObjectives");

app.MapPost("/players/{playerId}/daily-objectives/track", async (
    string playerId,
    DailyObjectiveTrackRequest trackRequest,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(trackRequest.ActionType) ||
        trackRequest.Quantity <= 0 ||
        string.IsNullOrWhiteSpace(trackRequest.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Objective action type, quantity, and idempotency key are required."));
    }

    return Results.Ok(await players.TrackDailyObjectiveAsync(access.PlayerId!, trackRequest));
}).WithName("TrackDailyObjective");

app.MapPost("/players/{playerId}/daily-objectives/{objectiveId}/claim", async (
    string playerId,
    string objectiveId,
    DailyObjectiveClaimRequest claimRequest,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(objectiveId) ||
        string.IsNullOrWhiteSpace(claimRequest.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Objective and idempotency key are required."));
    }

    return Results.Ok(await players.ClaimDailyObjectiveAsync(access.PlayerId!, objectiveId, claimRequest));
}).WithName("ClaimDailyObjective");

app.MapGet("/players/{playerId}/achievements", async (
    string playerId,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.GetAchievementsAsync(access.PlayerId!));
}).WithName("GetPlayerAchievements");

app.MapGet("/players/{playerId}/achievements/recent", async (
    string playerId,
    int? limit,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.GetRecentAchievementUnlocksAsync(access.PlayerId!, limit));
}).WithName("GetRecentAchievementUnlocks");

app.MapPost("/players/{playerId}/achievements/track", async (
    string playerId,
    AchievementTrackRequest trackRequest,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(trackRequest.ActionType) ||
        trackRequest.Quantity <= 0 ||
        string.IsNullOrWhiteSpace(trackRequest.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Achievement action type, quantity, and idempotency key are required."));
    }

    return Results.Ok(await players.TrackAchievementAsync(access.PlayerId!, trackRequest));
}).WithName("TrackAchievement");

app.MapPost("/players/{playerId}/achievements/{achievementId}/claim", async (
    string playerId,
    string achievementId,
    AchievementClaimRequest claimRequest,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(achievementId) ||
        string.IsNullOrWhiteSpace(claimRequest.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Achievement and idempotency key are required."));
    }

    return Results.Ok(await players.ClaimAchievementAsync(access.PlayerId!, achievementId, claimRequest));
}).WithName("ClaimAchievement");

app.MapGet("/players/{playerId}/onboarding-questline", async (
    string playerId,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.GetOnboardingQuestlineAsync(access.PlayerId!));
}).WithName("GetOnboardingQuestline");

app.MapPost("/players/{playerId}/onboarding-questline/track", async (
    string playerId,
    OnboardingQuestTrackRequest trackRequest,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(trackRequest.ActionType) ||
        trackRequest.Quantity <= 0 ||
        string.IsNullOrWhiteSpace(trackRequest.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Onboarding action type, quantity, and idempotency key are required."));
    }

    return Results.Ok(await players.TrackOnboardingQuestAsync(access.PlayerId!, trackRequest));
}).WithName("TrackOnboardingQuestline");

app.MapPost("/players/{playerId}/onboarding-questline/{questId}/claim", async (
    string playerId,
    string questId,
    OnboardingQuestClaimRequest claimRequest,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(questId) ||
        string.IsNullOrWhiteSpace(claimRequest.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Onboarding quest and idempotency key are required."));
    }

    return Results.Ok(await players.ClaimOnboardingQuestAsync(access.PlayerId!, questId, claimRequest));
}).WithName("ClaimOnboardingQuestline");

app.MapPost("/players/{playerId}/onboarding-questline/{questId}/skip", async (
    string playerId,
    string questId,
    OnboardingQuestSkipRequest skipRequest,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(questId) ||
        string.IsNullOrWhiteSpace(skipRequest.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Onboarding quest and idempotency key are required."));
    }

    return Results.Ok(await players.SkipOnboardingQuestAsync(access.PlayerId!, questId, skipRequest));
}).WithName("SkipOnboardingQuestline");

app.MapPost("/players/{playerId}/work", async (
    string playerId,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.WorkAsync(access.PlayerId!));
}).WithName("Work");

app.MapPost("/players/{playerId}/train", async (
    string playerId,
    HttpRequest request,
    PlayerProgressionStore players,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await players.TrainAsync(access.PlayerId!));
}).WithName("Train");

app.MapPost("/players/{playerId}/combat/result", async (
    string playerId,
    CombatResultRequest request,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (request.EnergyCost < 0 ||
        request.GoldReward < 0 ||
        request.ExperienceReward < 0 ||
        request.RoundsCompleted < 0 ||
        request.AttackerDamage < 0 ||
        request.DefenderDamage < 0)
    {
        return Results.BadRequest(new ErrorResponse("Combat costs, rewards, rounds, and damage cannot be negative."));
    }

    if (string.IsNullOrWhiteSpace(request.MissionId) ||
        string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Mission and idempotency key are required."));
    }

    return Results.Ok(await players.ApplyCombatResultAsync(access.PlayerId!, request));
}).WithName("ApplyCombatResult");

app.MapPost("/players/{playerId}/energy/restore", async (
    string playerId,
    RestoreEnergyRequest request,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (request.EnergyAmount <= 0 || string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Energy amount and idempotency key are required."));
    }

    return Results.Ok(await players.RestoreEnergyAsync(access.PlayerId!, request));
}).WithName("RestoreEnergy");

app.MapPost("/players/{playerId}/hospital/recover", async (
    string playerId,
    HospitalRecoveryRequest request,
    HttpRequest httpRequest,
    PlayerProgressionStore players,
    DevTokenValidator tokens,
    IConfiguration configuration) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Hospital recovery idempotency key is required."));
    }

    return Results.Ok(await players.RecoverAtHospitalAsync(access.PlayerId!, request));
}).WithName("RecoverAtHospital");

app.Run();

static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
{
    var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
    return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
        string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
}

static PlayerAccessResult ValidatePlayerAccess(string playerId, HttpRequest request, DevTokenValidator tokens)
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
            new ErrorResponse("You cannot access another player state."),
            statusCode: StatusCodes.Status403Forbidden));
    }

    return PlayerAccessResult.Allowed(token.PlayerId!);
}

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
            }
            else if (now - issuedAt > _legacyTokenLifetime)
            {
                return TokenValidationResult.Invalid;
            }

            return TokenValidationResult.Valid(payloadParts[0]);
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

internal sealed record TokenValidationResult(bool IsValid, string? PlayerId)
{
    public static TokenValidationResult Invalid { get; } = new(false, null);

    public static TokenValidationResult Valid(string playerId)
    {
        return new TokenValidationResult(true, playerId);
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

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

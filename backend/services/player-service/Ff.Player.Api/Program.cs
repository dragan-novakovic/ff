using System.Security.Cryptography;
using System.Text;
using Ff.Player.Api.Players;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<PlayerProgressionStore>();
builder.Services.AddSingleton<DevTokenValidator>();

var metadata = new ServiceMetadata(
    Service: "player-service",
    DisplayName: "Player Service",
    Domain: "Player profile, progression, and energy state",
    Description: "Owns player profile and progression state such as level, XP, energy, strength, and daily counters.",
    Owns: ["player profiles", "levels and XP", "energy", "strength", "daily status", "tutorial state"],
    Responsibilities: ["Serve player profile reads", "Apply progression changes atomically", "Own daily player reset state"]);

var app = builder.Build();

var progressionStore = app.Services.GetRequiredService<PlayerProgressionStore>();
await progressionStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

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
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (request.EnergyCost < 0 || request.GoldReward < 0 || request.ExperienceReward < 0)
    {
        return Results.BadRequest(new ErrorResponse("Combat costs and rewards cannot be negative."));
    }

    return Results.Ok(await players.ApplyCombatResultAsync(access.PlayerId!, request));
}).WithName("ApplyCombatResult");

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
    private readonly TimeSpan _tokenLifetime;

    public DevTokenValidator(IConfiguration configuration)
    {
        var secret = configuration["FF_IDENTITY_TOKEN_SECRET"]
            ?? configuration["Identity:TokenSecret"]
            ?? "ff-development-token-secret-change-me";
        _secret = Encoding.UTF8.GetBytes(secret);

        var lifetimeMinutes = configuration.GetValue("FF_IDENTITY_TOKEN_LIFETIME_MINUTES", 10_080);
        _tokenLifetime = TimeSpan.FromMinutes(lifetimeMinutes);
    }

    public TokenValidationResult Validate(string authorizationHeader)
    {
        const string bearerPrefix = "Bearer ";
        if (string.IsNullOrWhiteSpace(authorizationHeader) ||
            !authorizationHeader.StartsWith(bearerPrefix, StringComparison.OrdinalIgnoreCase))
        {
            return TokenValidationResult.Invalid;
        }

        var token = authorizationHeader[bearerPrefix.Length..].Trim();
        var tokenParts = token.Split('.', 2);
        if (tokenParts.Length != 2)
        {
            return TokenValidationResult.Invalid;
        }

        try
        {
            var payloadBytes = Base64UrlDecode(tokenParts[0]);
            var expectedSignature = HMACSHA256.HashData(_secret, payloadBytes);
            var actualSignature = Base64UrlDecode(tokenParts[1]);
            if (!CryptographicOperations.FixedTimeEquals(expectedSignature, actualSignature))
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
            if (DateTimeOffset.UtcNow - issuedAt > _tokenLifetime)
            {
                return TokenValidationResult.Invalid;
            }

            return TokenValidationResult.Valid(payloadParts[0]);
        }
        catch (FormatException)
        {
            return TokenValidationResult.Invalid;
        }
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

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

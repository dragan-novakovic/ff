using System.Collections.Concurrent;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
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
builder.Services.AddSingleton<DevTokenValidator>();

var metadata = new ServiceMetadata(
    Service: "gateway-service",
    DisplayName: "API Gateway / BFF",
    Domain: "Client-facing API gateway and backend-for-frontend",
    Description: "Public REST entrypoint for Flutter clients that will verify auth, route requests, and shape mobile-friendly responses.",
    Owns: ["request routing", "API versioning", "client response shaping"],
    Responsibilities: ["Verify OIDC/JWT bearer tokens", "Route auth and profile requests to identity-service", "Route requests to backend services", "Apply client-facing rate limits"]);

var messages = new ConcurrentQueue<MessageDto>();
messages.Enqueue(new MessageDto("welcome-1", "system", "global", "Welcome to FF. Backend services are connected."));

var app = builder.Build();
app.UseCors("FlutterDev");

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapPost("/auth/login", async (LoginRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/login", request)).WithName("Login");

app.MapPost("/auth/register", async (RegisterRequest request, IdentityServiceClient identity) =>
    await identity.PostAsync("auth/register", request)).WithName("Register");

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

app.MapPost("/players/{playerId}/work", async (
    string playerId,
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
    if (shouldCreditWorkReward && workGoldReward > 0)
    {
        var walletCredit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/wallet/credit",
            authorization,
            new WalletCreditRequestDto(
                Amount: workGoldReward,
                EntryType: "work_reward",
                Reason: action.Message,
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

        action = action with { Wallet = credit.Inventory };
    }

    return Results.Ok(action);
}).WithName("Work");

app.MapPost("/players/{playerId}/train", async (
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

    return await players.PostAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/train",
        request.Headers.Authorization.ToString());
}).WithName("Train");

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

app.MapGet("/players/{playerId}/factories", async (
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
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/factories",
        request.Headers.Authorization.ToString());
}).WithName("GetFactories");

app.MapPost("/players/{playerId}/factories/{factoryId}/produce", async (
    string playerId,
    string factoryId,
    HttpRequest request,
    ProductionServiceClient production,
    EconomyServiceClient economy,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var authorization = request.Headers.Authorization.ToString();
    var productionResult = await production.PostJsonAsync<object, ProductionResultDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/factories/{Uri.EscapeDataString(factoryId)}/produce",
        authorization,
        new { });
    if (productionResult.Error is not null)
    {
        return productionResult.Error;
    }

    var result = productionResult.Value!;
    var inventoryMutation = await economy.PostJsonAsync<InventoryConversionRequestDto, InventoryMutationResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/inventory/convert",
        authorization,
        new InventoryConversionRequestDto(
            InputItemId: result.ConsumedItemId,
            InputQuantity: result.ConsumedQuantity,
            OutputItemId: result.ProducedItemId,
            OutputQuantity: result.ProducedQuantity,
            Reason: result.Message));
    if (inventoryMutation.Error is not null)
    {
        return inventoryMutation.Error;
    }

    var mutation = inventoryMutation.Value!;
    if (!mutation.Completed)
    {
        return Results.Json(
            new ErrorResponse(mutation.Message),
            statusCode: StatusCodes.Status409Conflict);
    }

    return Results.Ok(result with
    {
        Message = $"{result.Message} Inventory updated.",
        Note = mutation.Message,
        Inventory = mutation.Inventory
    });
}).WithName("Produce");

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

app.MapPost("/players/{playerId}/market/listings/{listingId}/buy", async (
    string playerId,
    string listingId,
    HttpRequest request,
    MarketServiceClient market,
    EconomyServiceClient economy,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
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
    var purchase = await economy.PostJsonAsync<MarketPurchaseRequestDto, MarketPurchaseResponseDto>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/market/buy",
        authorization,
        new MarketPurchaseRequestDto(
            ListingId: listing.ListingId,
            ItemId: listing.ItemId,
            ItemName: listing.ItemName,
            Category: listing.Category,
            Quantity: 1,
            PricePerUnit: listing.PricePerUnit));
    if (purchase.Error is not null)
    {
        return purchase.Error;
    }

    return Results.Ok(purchase.Value!);
}).WithName("BuyMarketListing");

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

app.MapPost("/players/{playerId}/combat/missions/{missionId}/fight", async (
    string playerId,
    string missionId,
    HttpRequest request,
    PlayerServiceClient players,
    CombatServiceClient combat,
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
    var playerState = await players.GetJsonAsync<PlayerStateForCombat>(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/state",
        authorization);
    if (playerState.Error is not null)
    {
        return playerState.Error;
    }

    var mission = await combat.GetJsonAsync<CombatMissionDto>(
        $"missions/{Uri.EscapeDataString(missionId)}",
        authorization);
    if (mission.Error is not null)
    {
        return mission.Error;
    }

    var state = playerState.Value!;
    var missionDto = mission.Value!;
    var simulatedAttackerEnergy = Math.Clamp(state.Energy, 0, 100);
    var fight = await combat.PostJsonAsync<FightRequestDto, FightResponseDto>(
        "simulate/fight",
        authorization,
        new FightRequestDto(
            Attacker: new FighterDto(
                Strength: Math.Max(1, state.Strength),
                Energy: simulatedAttackerEnergy,
                WeaponPower: 1),
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
                : "Mission complete, but you did not win rewards."));
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
                IdempotencyKey: $"combat:{access.PlayerId!.ToLowerInvariant()}:{missionDto.MissionId}:{Guid.NewGuid():N}"),
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

    return Results.Ok(new MissionFightResponse(
        Mission: missionDto,
        Fight: fightResult,
        PlayerAction: appliedProgression,
        Message: appliedProgression.Message));
}).WithName("FightMission");

app.MapGet("/messages", (string? fromId, string? toId) =>
{
    var result = messages.AsEnumerable();
    if (!string.IsNullOrWhiteSpace(fromId) && !string.IsNullOrWhiteSpace(toId))
    {
        result = result.Where(message =>
            (message.FromId == fromId && message.ToId == toId) ||
            (message.FromId == toId && message.ToId == fromId));
    }
    else if (!string.IsNullOrWhiteSpace(toId))
    {
        result = result.Where(message => message.ToId == toId);
    }
    else if (!string.IsNullOrWhiteSpace(fromId))
    {
        result = result.Where(message => message.FromId == fromId);
    }

    return Results.Ok(result.ToArray());
}).WithName("GetMessages");

app.MapPost("/messages", (SendMessageRequest request) =>
{
    if (string.IsNullOrWhiteSpace(request.Content))
    {
        return Results.BadRequest(new ErrorResponse("Message content is required."));
    }

    var message = new MessageDto(
        Id: Guid.NewGuid().ToString("N"),
        FromId: string.IsNullOrWhiteSpace(request.FromId) ? "anonymous" : request.FromId.Trim(),
        ToId: string.IsNullOrWhiteSpace(request.ToId) ? "global" : request.ToId.Trim(),
        Content: request.Content.Trim());
    messages.Enqueue(message);

    return Results.Ok(message);
}).WithName("SendMessage");

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
            new ErrorResponse("You cannot access another player profile."),
            statusCode: StatusCodes.Status403Forbidden));
    }

    return PlayerAccessResult.Allowed(token.PlayerId!);
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

static string InternalToken(IConfiguration configuration)
{
    return configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
}

internal sealed class IdentityServiceClient(HttpClient httpClient)
{
    public Task<IResult> GetAsync(string path)
    {
        return ForwardAsync(() => httpClient.GetAsync(path));
    }

    public Task<IResult> PostAsync<TRequest>(string path, TRequest request)
    {
        return ForwardAsync(() => httpClient.PostAsJsonAsync(path, request));
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
}

internal abstract class ForwardingServiceClient(HttpClient httpClient, string serviceName)
{
    public Task<IResult> GetAsync(string path, string authorizationHeader)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Get, path, authorizationHeader));
    }

    public Task<IResult> PostAsync(string path, string authorizationHeader)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Post, path, authorizationHeader));
    }

    public Task<ServiceJsonResult<TResponse>> GetJsonAsync<TResponse>(string path, string authorizationHeader)
    {
        return JsonAsync<TResponse>(() => SendAsync(HttpMethod.Get, path, authorizationHeader));
    }

    public Task<ServiceJsonResult<TResponse>> PostJsonAsync<TRequest, TResponse>(
        string path,
        string authorizationHeader,
        TRequest body,
        string? internalToken = null)
    {
        return JsonAsync<TResponse>(() => SendJsonAsync(path, authorizationHeader, body, internalToken));
    }

    private Task<HttpResponseMessage> SendAsync(HttpMethod method, string path, string authorizationHeader)
    {
        var message = new HttpRequestMessage(method, path);
        if (!string.IsNullOrWhiteSpace(authorizationHeader))
        {
            message.Headers.TryAddWithoutValidation("Authorization", authorizationHeader);
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
    }
}

internal sealed class PlayerServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Player service");

internal sealed class EconomyServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Economy service");

internal sealed class ProductionServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Production service");

internal sealed class MarketServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Market service");

internal sealed class CombatServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Combat service");

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

internal sealed record LoginRequest(string? Email, string? Password);

internal sealed record RegisterRequest(string? Email, string? Password, string? Username);

internal sealed record SendMessageRequest(string Content, string FromId, string ToId);

internal sealed record MessageDto(string Id, string FromId, string ToId, string Content);

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
    InventoryResponseDto? Inventory = null);

internal sealed record MarketListingDto(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string SellerId);

internal sealed record MarketPurchaseRequestDto(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit);

internal sealed record MarketPurchaseResponseDto(
    bool Completed,
    string Message,
    string ListingId,
    int Quantity,
    int TotalPrice,
    InventoryResponseDto Inventory);

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
    string Message);

internal sealed record PlayerActionResponseDto(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    object? State,
    InventoryResponseDto? Wallet = null);

internal sealed record PlayerRewardsDto(int Gold, int Experience, int Strength);

internal sealed record MissionFightResponse(
    CombatMissionDto Mission,
    FightResponseDto Fight,
    PlayerActionResponseDto PlayerAction,
    string Message);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

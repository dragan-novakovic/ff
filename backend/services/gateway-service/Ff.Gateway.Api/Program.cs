using System.Collections.Concurrent;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;

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
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return await players.PostAsync(
        $"players/{Uri.EscapeDataString(access.PlayerId!)}/work",
        request.Headers.Authorization.ToString());
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

internal sealed class PlayerServiceClient(HttpClient httpClient)
{
    public Task<IResult> GetAsync(string path, string authorizationHeader)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Get, path, authorizationHeader));
    }

    public Task<IResult> PostAsync(string path, string authorizationHeader)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Post, path, authorizationHeader));
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
                new ErrorResponse("Player service is unavailable."),
                statusCode: StatusCodes.Status502BadGateway);
        }
        catch (TaskCanceledException)
        {
            return Results.Json(
                new ErrorResponse("Player service request timed out."),
                statusCode: StatusCodes.Status504GatewayTimeout);
        }
    }
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

internal sealed record LoginRequest(string? Email, string? Password);

internal sealed record RegisterRequest(string? Email, string? Password, string? Username);

internal sealed record SendMessageRequest(string Content, string FromId, string ToId);

internal sealed record MessageDto(string Id, string FromId, string ToId, string Content);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

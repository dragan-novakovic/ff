using Ff.Identity.Api.Accounts;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<AccountStore>();
builder.Services.AddSingleton<TokenIssuer>();

var metadata = new ServiceMetadata(
    Service: "identity-service",
    DisplayName: "Identity Service",
    Domain: "Authentication account linkage and account state",
    Description: "Owns account identity metadata and maps auth subjects to internal player IDs without owning game progression state.",
    Owns: ["identity subjects", "player ID mappings", "account state", "ban and suspension state", "login metadata"],
    Responsibilities: ["Link authentication subjects to players", "Track account status", "Expose identity metadata to trusted services"]);

var app = builder.Build();

var accountStore = app.Services.GetRequiredService<AccountStore>();
await accountStore.InitializeAsync();

var seedEmail = builder.Configuration["FF_IDENTITY_SEED_EMAIL"] ?? "demo@ff.local";
var seedPassword = builder.Configuration["FF_IDENTITY_SEED_PASSWORD"];
var seedUsername = builder.Configuration["FF_IDENTITY_SEED_USERNAME"] ?? "demo";
if (app.Environment.IsDevelopment() && string.IsNullOrWhiteSpace(seedPassword))
{
    seedPassword = "secret";
}

if (!string.IsNullOrWhiteSpace(seedEmail) && !string.IsNullOrWhiteSpace(seedPassword))
{
    await accountStore.EnsureSeedAccountAsync(seedEmail, seedPassword, seedUsername);
}

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapPost("/auth/register", async (RegisterRequest request, AccountStore accounts, TokenIssuer tokens) =>
{
    var validationError = ValidateCredentials(request.Email, request.Password);
    if (validationError is not null)
    {
        return Results.BadRequest(new ErrorResponse(validationError));
    }

    var result = await accounts.RegisterAsync(
        request.Email!,
        request.Password!,
        request.Username);

    return result.Status switch
    {
        AccountRegistrationStatus.Created => Results.Ok(ToAuthResponse(result.Account!, tokens)),
        AccountRegistrationStatus.DuplicateEmail => Results.Conflict(new ErrorResponse("An account with that email already exists.")),
        _ => Results.Problem("Account registration failed.", statusCode: StatusCodes.Status500InternalServerError)
    };
}).WithName("Register");

app.MapPost("/auth/login", async (LoginRequest request, AccountStore accounts, TokenIssuer tokens) =>
{
    var validationError = ValidateCredentials(request.Email, request.Password);
    if (validationError is not null)
    {
        return Results.BadRequest(new ErrorResponse(validationError));
    }

    var result = await accounts.LoginAsync(request.Email!, request.Password!);
    return result.Status switch
    {
        AccountLoginStatus.Success => Results.Ok(ToAuthResponse(result.Account!, tokens)),
        AccountLoginStatus.NotFound or AccountLoginStatus.InvalidPassword => Results.Json(
            new ErrorResponse("Invalid email or password."),
            statusCode: StatusCodes.Status401Unauthorized),
        _ => Results.Problem("Account login failed.", statusCode: StatusCodes.Status500InternalServerError)
    };
}).WithName("Login");

app.MapGet("/players/{playerId}", async (string playerId, AccountStore accounts) =>
{
    var account = await accounts.FindByPlayerIdAsync(playerId);
    return account is null
        ? Results.NotFound(new ErrorResponse("Player profile was not found."))
        : Results.Ok(account.ToPlayerDto());
}).WithName("GetPlayer");

app.Run();

static string? ValidateCredentials(string? email, string? password)
{
    if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
    {
        return "Enter a valid email address.";
    }

    if (string.IsNullOrWhiteSpace(password) || password.Length < 5)
    {
        return "Password must contain at least 5 characters.";
    }

    return null;
}

static AuthResponse ToAuthResponse(AccountRecord account, TokenIssuer tokens)
{
    return new AuthResponse(tokens.Issue(account), account.ToPlayerDto());
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

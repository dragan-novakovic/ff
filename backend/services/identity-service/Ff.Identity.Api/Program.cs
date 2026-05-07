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

app.MapPost("/auth/register", async (
    RegisterRequest request,
    HttpRequest httpRequest,
    AccountStore accounts,
    TokenIssuer tokens) =>
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
        AccountRegistrationStatus.Created => Results.Ok(ToAuthResponse(
            result.Account!,
            await accounts.CreateRefreshSessionAsync(
                result.Account!,
                httpRequest.Headers.UserAgent.ToString(),
                RemoteIp(httpRequest)),
            tokens)),
        AccountRegistrationStatus.DuplicateEmail => Results.Conflict(new ErrorResponse("An account with that email already exists.")),
        _ => Results.Problem("Account registration failed.", statusCode: StatusCodes.Status500InternalServerError)
    };
}).WithName("Register");

app.MapPost("/auth/login", async (
    LoginRequest request,
    HttpRequest httpRequest,
    AccountStore accounts,
    TokenIssuer tokens) =>
{
    var validationError = ValidateCredentials(request.Email, request.Password);
    if (validationError is not null)
    {
        return Results.BadRequest(new ErrorResponse(validationError));
    }

    var result = await accounts.LoginAsync(request.Email!, request.Password!);
    return result.Status switch
    {
        AccountLoginStatus.Success => Results.Ok(ToAuthResponse(
            result.Account!,
            await accounts.CreateRefreshSessionAsync(
                result.Account!,
                httpRequest.Headers.UserAgent.ToString(),
                RemoteIp(httpRequest)),
            tokens)),
        AccountLoginStatus.NotFound or AccountLoginStatus.InvalidPassword => Results.Json(
            new ErrorResponse("Invalid email or password."),
            statusCode: StatusCodes.Status401Unauthorized),
        _ => Results.Problem("Account login failed.", statusCode: StatusCodes.Status500InternalServerError)
    };
}).WithName("Login");

app.MapPost("/auth/refresh", async (
    RefreshRequest request,
    HttpRequest httpRequest,
    AccountStore accounts,
    TokenIssuer tokens) =>
{
    if (string.IsNullOrWhiteSpace(request.RefreshToken))
    {
        return Results.BadRequest(new ErrorResponse("Refresh token is required."));
    }

    var result = await accounts.RefreshSessionAsync(
        request.RefreshToken,
        httpRequest.Headers.UserAgent.ToString(),
        RemoteIp(httpRequest));
    return result.Status switch
    {
        RefreshSessionStatus.Success => Results.Ok(ToAuthResponse(result.Account!, result.RefreshSession!, tokens)),
        RefreshSessionStatus.Invalid => Results.Json(
            new ErrorResponse("Refresh session is invalid or expired."),
            statusCode: StatusCodes.Status401Unauthorized),
        _ => Results.Problem("Refresh failed.", statusCode: StatusCodes.Status500InternalServerError)
    };
}).WithName("Refresh");

app.MapPost("/auth/logout", async (
    LogoutRequest request,
    HttpRequest httpRequest,
    AccountStore accounts,
    TokenIssuer tokens) =>
{
    var revoked = 0;
    var access = tokens.Validate(httpRequest.Headers.Authorization.ToString());
    if (request.AllSessions && access.IsValid)
    {
        revoked = await accounts.RevokeAllRefreshSessionsAsync(access.AccountId!);
    }
    else if (!string.IsNullOrWhiteSpace(request.RefreshToken))
    {
        revoked = await accounts.RevokeRefreshTokenAsync(request.RefreshToken) ? 1 : 0;
    }

    return Results.Ok(new SessionRevokeResponse("Signed out.", revoked));
}).WithName("Logout");

app.MapGet("/auth/me", async (HttpRequest httpRequest, AccountStore accounts, TokenIssuer tokens) =>
{
    var access = tokens.Validate(httpRequest.Headers.Authorization.ToString());
    if (!access.IsValid)
    {
        return Results.Json(
            new ErrorResponse("A valid bearer token is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var account = await accounts.FindByAccountIdAsync(access.AccountId!);
    if (account is null)
    {
        return Results.Json(
            new ErrorResponse("Account was not found."),
            statusCode: StatusCodes.Status404NotFound);
    }

    var sessions = await accounts.GetRefreshSessionsAsync(account.AccountId);
    return Results.Ok(new SecurityProfileResponse(
        account.ToPlayerDto(),
        sessions.Select(session => session.ToDto()).ToArray()));
}).WithName("GetCurrentAccount");

app.MapGet("/auth/sessions", async (HttpRequest httpRequest, AccountStore accounts, TokenIssuer tokens) =>
{
    var access = tokens.Validate(httpRequest.Headers.Authorization.ToString());
    if (!access.IsValid)
    {
        return Results.Json(
            new ErrorResponse("A valid bearer token is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var sessions = await accounts.GetRefreshSessionsAsync(access.AccountId!);
    return Results.Ok(sessions.Select(session => session.ToDto()).ToArray());
}).WithName("GetRefreshSessions");

app.MapPost("/auth/sessions/revoke-all", async (
    HttpRequest httpRequest,
    AccountStore accounts,
    TokenIssuer tokens) =>
{
    var access = tokens.Validate(httpRequest.Headers.Authorization.ToString());
    if (!access.IsValid)
    {
        return Results.Json(
            new ErrorResponse("A valid bearer token is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var revoked = await accounts.RevokeAllRefreshSessionsAsync(access.AccountId!);
    return Results.Ok(new SessionRevokeResponse("All refresh sessions were revoked.", revoked));
}).WithName("RevokeAllRefreshSessions");

app.MapPost("/auth/password-reset/request", async (
    PasswordResetRequest request,
    AccountStore accounts,
    IWebHostEnvironment environment,
    ILogger<Program> logger) =>
{
    if (string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@'))
    {
        return Results.BadRequest(new ErrorResponse("Enter a valid email address."));
    }

    var issue = await accounts.CreatePasswordResetTokenAsync(request.Email);
    if (issue is not null && environment.IsDevelopment())
    {
        logger.LogInformation(
            "Development password reset token for account {AccountId}: {Token}",
            issue.Record.AccountId,
            issue.Token);
    }

    return Results.Ok(new AuthMessageResponse(
        "If that account exists, a password reset token has been issued.",
        environment.IsDevelopment() ? issue?.Token : null,
        issue?.Record.ExpiresAt.ToString("O")));
}).WithName("RequestPasswordReset");

app.MapPost("/auth/password-reset/confirm", async (
    PasswordResetConfirmRequest request,
    AccountStore accounts) =>
{
    var passwordError = ValidatePassword(request.Password);
    if (passwordError is not null)
    {
        return Results.BadRequest(new ErrorResponse(passwordError));
    }

    if (string.IsNullOrWhiteSpace(request.Token))
    {
        return Results.BadRequest(new ErrorResponse("Password reset token is required."));
    }

    var status = await accounts.ResetPasswordAsync(request.Token, request.Password!);
    return status switch
    {
        PasswordResetStatus.Success => Results.Ok(new AuthMessageResponse("Password was reset. Please sign in again.")),
        PasswordResetStatus.InvalidToken => Results.Json(
            new ErrorResponse("Password reset token is invalid or expired."),
            statusCode: StatusCodes.Status400BadRequest),
        _ => Results.Problem("Password reset failed.", statusCode: StatusCodes.Status500InternalServerError)
    };
}).WithName("ConfirmPasswordReset");

app.MapPost("/auth/email-verification/request", async (
    HttpRequest httpRequest,
    AccountStore accounts,
    TokenIssuer tokens,
    IWebHostEnvironment environment,
    ILogger<Program> logger) =>
{
    var access = tokens.Validate(httpRequest.Headers.Authorization.ToString());
    if (!access.IsValid)
    {
        return Results.Json(
            new ErrorResponse("A valid bearer token is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var issue = await accounts.CreateEmailVerificationTokenAsync(access.AccountId!);
    if (issue is null)
    {
        return Results.NotFound(new ErrorResponse("Account was not found."));
    }

    if (environment.IsDevelopment())
    {
        logger.LogInformation(
            "Development email verification token for account {AccountId}: {Token}",
            issue.Record.AccountId,
            issue.Token);
    }

    return Results.Ok(new AuthMessageResponse(
        "Email verification token issued.",
        environment.IsDevelopment() ? issue.Token : null,
        issue.Record.ExpiresAt.ToString("O")));
}).WithName("RequestEmailVerification");

app.MapPost("/auth/email-verification/confirm", async (
    EmailVerificationConfirmRequest request,
    AccountStore accounts) =>
{
    if (string.IsNullOrWhiteSpace(request.Token))
    {
        return Results.BadRequest(new ErrorResponse("Email verification token is required."));
    }

    var status = await accounts.VerifyEmailAsync(request.Token);
    return status switch
    {
        EmailVerificationStatus.Success => Results.Ok(new AuthMessageResponse("Email address verified.")),
        EmailVerificationStatus.InvalidToken => Results.Json(
            new ErrorResponse("Email verification token is invalid or expired."),
            statusCode: StatusCodes.Status400BadRequest),
        _ => Results.Problem("Email verification failed.", statusCode: StatusCodes.Status500InternalServerError)
    };
}).WithName("ConfirmEmailVerification");

app.MapGet("/players/{playerId}", async (string playerId, AccountStore accounts) =>
{
    var account = await accounts.FindByPlayerIdAsync(playerId);
    return account is null
        ? Results.NotFound(new ErrorResponse("Player profile was not found."))
        : Results.Ok(account.ToPlayerDto());
}).WithName("GetPlayer");

app.MapGet("/players/{playerId}/public", async (string playerId, AccountStore accounts) =>
{
    var account = await accounts.FindByPlayerIdAsync(playerId);
    return account is null
        ? Results.NotFound(new ErrorResponse("Player profile was not found."))
        : Results.Ok(account.ToPublicPlayerDto());
}).WithName("GetPublicPlayer");

app.Run();

static string? ValidateCredentials(string? email, string? password)
{
    if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
    {
        return "Enter a valid email address.";
    }

    return ValidatePassword(password);
}

static string? ValidatePassword(string? password)
{
    if (string.IsNullOrWhiteSpace(password) || password.Length < 5)
    {
        return "Password must contain at least 5 characters.";
    }

    return null;
}

static AuthResponse ToAuthResponse(AccountRecord account, RefreshSessionIssue refreshSession, TokenIssuer tokens)
{
    var accessToken = tokens.Issue(account);
    return new AuthResponse(
        accessToken.Token,
        refreshSession.RefreshToken,
        accessToken.ExpiresAt.ToString("O"),
        refreshSession.Session.ExpiresAt.ToString("O"),
        account.ToPlayerDto());
}

static string RemoteIp(HttpRequest request)
{
    return request.HttpContext.Connection.RemoteIpAddress?.ToString() ?? string.Empty;
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

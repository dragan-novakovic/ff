using System.Text.Json.Serialization;

namespace Ff.Identity.Api.Accounts;

public sealed record LoginRequest(string? Email, string? Password);

public sealed record RegisterRequest(string? Email, string? Password, string? Username);

public sealed record RefreshRequest(string? RefreshToken);

public sealed record LogoutRequest(string? RefreshToken, bool AllSessions = false);

public sealed record PasswordResetRequest(string? Email);

public sealed record PasswordResetConfirmRequest(string? Token, string? Password);

public sealed record EmailVerificationConfirmRequest(string? Token);

public sealed record AuthResponse(
    string Token,
    string RefreshToken,
    [property: JsonPropertyName("expires_at")] string ExpiresAt,
    [property: JsonPropertyName("refresh_expires_at")] string RefreshExpiresAt,
    PlayerDto User);

public sealed record AuthMessageResponse(
    string Message,
    [property: JsonPropertyName("dev_token")] string? DevToken = null,
    [property: JsonPropertyName("expires_at")] string? ExpiresAt = null);

public sealed record SessionRevokeResponse(string Message, int RevokedSessions);

public sealed record SecurityProfileResponse(PlayerDto User, RefreshSessionDto[] Sessions);

public sealed record RefreshSessionDto(
    string SessionId,
    [property: JsonPropertyName("created_at")] string CreatedAt,
    [property: JsonPropertyName("expires_at")] string ExpiresAt,
    [property: JsonPropertyName("last_seen_at")] string LastSeenAt,
    [property: JsonPropertyName("revoked_at")] string? RevokedAt);

public sealed record ErrorResponse(string Message);

public sealed record PlayerDto(
    string Uid,
    string Email,
    string Username,
    [property: JsonPropertyName("created_on")] string CreatedOn,
    [property: JsonPropertyName("email_verified")] bool EmailVerified,
    string[] Roles,
    [property: JsonPropertyName("first_name")] string FirstName,
    [property: JsonPropertyName("last_name")] string LastName,
    string[] Contacts,
    string[] Groups);

public sealed record PublicPlayerDto(
    string Uid,
    string Username,
    [property: JsonPropertyName("created_on")] string CreatedOn);

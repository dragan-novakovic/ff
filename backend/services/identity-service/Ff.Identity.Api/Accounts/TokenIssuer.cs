using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Configuration;

namespace Ff.Identity.Api.Accounts;

internal sealed class TokenIssuer
{
    private readonly byte[] _secret;
    private readonly TimeSpan _accessTokenLifetime;
    private static readonly TimeSpan ClockSkew = TimeSpan.FromMinutes(2);

    public TokenIssuer(IConfiguration configuration)
    {
        var secret = configuration["FF_IDENTITY_TOKEN_SECRET"]
            ?? configuration["Identity:TokenSecret"]
            ?? "ff-development-token-secret-change-me";
        _secret = Encoding.UTF8.GetBytes(secret);

        var lifetimeMinutes = configuration.GetValue(
            "FF_IDENTITY_ACCESS_TOKEN_LIFETIME_MINUTES",
            configuration.GetValue("FF_IDENTITY_TOKEN_LIFETIME_MINUTES", 15));
        _accessTokenLifetime = TimeSpan.FromMinutes(Math.Clamp(lifetimeMinutes, 1, 24 * 60));
    }

    public IssuedAccessToken Issue(AccountRecord account)
    {
        var now = DateTimeOffset.UtcNow;
        var issuedAt = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var expiresAt = now.Add(_accessTokenLifetime);
        var claims = new AccessTokenClaims(
            AccountId: account.AccountId,
            Roles: account.Roles.Count == 0 ? ["player"] : account.Roles.ToArray(),
            EmailVerified: account.EmailVerifiedAt.HasValue,
            Type: "access",
            ExpiresAt: expiresAt.ToUnixTimeSeconds(),
            JwtId: Guid.NewGuid().ToString("N"));
        var claimsJson = JsonSerializer.Serialize(claims);
        var claimsSegment = Base64Url(Encoding.UTF8.GetBytes(claimsJson));
        var payload = $"{account.PlayerId}|{claimsSegment}|{issuedAt}";
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        var signature = HMACSHA256.HashData(_secret, payloadBytes);

        return new IssuedAccessToken($"{Base64Url(payloadBytes)}.{Base64Url(signature)}", expiresAt);
    }

    public AccessTokenValidationResult Validate(string authorizationHeader)
    {
        const string bearerPrefix = "Bearer ";
        if (string.IsNullOrWhiteSpace(authorizationHeader) ||
            authorizationHeader.Contains('\n') ||
            authorizationHeader.Contains('\r') ||
            authorizationHeader.Contains(',') ||
            !authorizationHeader.StartsWith(bearerPrefix, StringComparison.Ordinal))
        {
            return AccessTokenValidationResult.Invalid;
        }

        var token = authorizationHeader[bearerPrefix.Length..].Trim();
        var tokenParts = token.Split('.', 2);
        if (tokenParts.Length != 2 ||
            string.IsNullOrWhiteSpace(tokenParts[0]) ||
            string.IsNullOrWhiteSpace(tokenParts[1]))
        {
            return AccessTokenValidationResult.Invalid;
        }

        try
        {
            var payloadBytes = Base64UrlDecode(tokenParts[0]);
            var expectedSignature = HMACSHA256.HashData(_secret, payloadBytes);
            var actualSignature = Base64UrlDecode(tokenParts[1]);
            if (actualSignature.Length != expectedSignature.Length ||
                !CryptographicOperations.FixedTimeEquals(expectedSignature, actualSignature))
            {
                return AccessTokenValidationResult.Invalid;
            }

            var payloadParts = Encoding.UTF8.GetString(payloadBytes).Split('|', 3);
            if (payloadParts.Length != 3 ||
                string.IsNullOrWhiteSpace(payloadParts[0]) ||
                !long.TryParse(payloadParts[2], out var issuedAtSeconds))
            {
                return AccessTokenValidationResult.Invalid;
            }

            var now = DateTimeOffset.UtcNow;
            var issuedAt = DateTimeOffset.FromUnixTimeSeconds(issuedAtSeconds);
            if (issuedAt - now > ClockSkew)
            {
                return AccessTokenValidationResult.Invalid;
            }

            if (TryReadClaims(payloadParts[1], out var claims))
            {
                if (!string.Equals(claims.Type, "access", StringComparison.Ordinal) ||
                    string.IsNullOrWhiteSpace(claims.AccountId))
                {
                    return AccessTokenValidationResult.Invalid;
                }

                var expiresAt = DateTimeOffset.FromUnixTimeSeconds(claims.ExpiresAt);
                if (now - expiresAt > ClockSkew)
                {
                    return AccessTokenValidationResult.Invalid;
                }

                return AccessTokenValidationResult.Valid(
                    payloadParts[0],
                    claims.AccountId,
                    claims.Roles.Length == 0 ? ["player"] : claims.Roles,
                    claims.EmailVerified,
                    expiresAt);
            }

            if (now - issuedAt > _accessTokenLifetime)
            {
                return AccessTokenValidationResult.Invalid;
            }

            return AccessTokenValidationResult.Valid(
                payloadParts[0],
                payloadParts[1],
                ["player"],
                false,
                issuedAt.Add(_accessTokenLifetime));
        }
        catch (Exception ex) when (ex is FormatException or JsonException or ArgumentException or OverflowException)
        {
            return AccessTokenValidationResult.Invalid;
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

        claims = default;
        return false;
    }

    private static string Base64Url(byte[] value)
    {
        return Convert.ToBase64String(value)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
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

internal readonly record struct IssuedAccessToken(string Token, DateTimeOffset ExpiresAt);

internal sealed record AccessTokenValidationResult(
    bool IsValid,
    string? PlayerId,
    string? AccountId,
    string[] Roles,
    bool EmailVerified,
    DateTimeOffset? ExpiresAt)
{
    public static AccessTokenValidationResult Invalid { get; } = new(false, null, null, [], false, null);

    public static AccessTokenValidationResult Valid(
        string playerId,
        string accountId,
        string[] roles,
        bool emailVerified,
        DateTimeOffset expiresAt)
    {
        return new AccessTokenValidationResult(true, playerId, accountId, roles, emailVerified, expiresAt);
    }
}

internal sealed record AccessTokenClaims(
    [property: JsonPropertyName("accountId")] string AccountId,
    [property: JsonPropertyName("roles")] string[] Roles,
    [property: JsonPropertyName("emailVerified")] bool EmailVerified,
    [property: JsonPropertyName("typ")] string Type,
    [property: JsonPropertyName("exp")] long ExpiresAt,
    [property: JsonPropertyName("jti")] string JwtId);

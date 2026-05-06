using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace Ff.Identity.Api.Accounts;

internal sealed class TokenIssuer
{
    private readonly byte[] _secret;

    public TokenIssuer(IConfiguration configuration)
    {
        var secret = configuration["FF_IDENTITY_TOKEN_SECRET"]
            ?? configuration["Identity:TokenSecret"]
            ?? "ff-development-token-secret-change-me";
        _secret = Encoding.UTF8.GetBytes(secret);
    }

    public string Issue(AccountRecord account)
    {
        var issuedAt = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{account.PlayerId}|{account.AccountId}|{issuedAt}";
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        var signature = HMACSHA256.HashData(_secret, payloadBytes);

        return $"{Base64Url(payloadBytes)}.{Base64Url(signature)}";
    }

    private static string Base64Url(byte[] value)
    {
        return Convert.ToBase64String(value)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }
}

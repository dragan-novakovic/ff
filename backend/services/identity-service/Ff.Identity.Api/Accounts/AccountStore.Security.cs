using System.Security.Cryptography;
using System.Text;
using Npgsql;

namespace Ff.Identity.Api.Accounts;

internal sealed partial class AccountStore
{
    private const string PasswordResetTokenType = "password_reset";
    private const string EmailVerificationTokenType = "email_verification";

    public async Task<RefreshSessionIssue> CreateRefreshSessionAsync(
        AccountRecord account,
        string? userAgent,
        string? remoteIp)
    {
        var token = NewOpaqueToken("ffr");
        var session = new RefreshSessionRecord
        {
            SessionId = $"session-{Guid.NewGuid():N}",
            AccountId = account.AccountId,
            PlayerId = account.PlayerId,
            CreatedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.Add(_refreshSessionLifetime),
            LastSeenAt = DateTimeOffset.UtcNow,
            UserAgent = NormalizeMetadata(userAgent),
            RemoteIp = NormalizeMetadata(remoteIp)
        };

        await using var command = _dataSource.CreateCommand("""
            INSERT INTO identity.refresh_sessions (
                session_id, account_id, player_id, token_hash, created_at, expires_at,
                last_seen_at, revoked_at, replaced_by_session_id, user_agent, remote_ip
            )
            VALUES (
                @session_id, @account_id, @player_id, @token_hash, @created_at, @expires_at,
                @last_seen_at, NULL, NULL, @user_agent, @remote_ip
            );
            """);
        command.Parameters.AddWithValue("session_id", session.SessionId);
        command.Parameters.AddWithValue("account_id", session.AccountId);
        command.Parameters.AddWithValue("player_id", session.PlayerId);
        command.Parameters.AddWithValue("token_hash", HashToken(token));
        command.Parameters.AddWithValue("created_at", session.CreatedAt);
        command.Parameters.AddWithValue("expires_at", session.ExpiresAt);
        command.Parameters.AddWithValue("last_seen_at", session.LastSeenAt);
        command.Parameters.AddWithValue("user_agent", session.UserAgent);
        command.Parameters.AddWithValue("remote_ip", session.RemoteIp);
        await command.ExecuteNonQueryAsync();

        return new RefreshSessionIssue(token, session);
    }

    public async Task<RefreshSessionRefreshResult> RefreshSessionAsync(
        string refreshToken,
        string? userAgent,
        string? remoteIp)
    {
        var existing = await FindRefreshSessionByTokenAsync(refreshToken);
        if (existing is null || existing.RevokedAt is not null || existing.ExpiresAt <= DateTimeOffset.UtcNow)
        {
            return new RefreshSessionRefreshResult(RefreshSessionStatus.Invalid, null, null);
        }

        var account = await FindByAccountIdAsync(existing.AccountId);
        if (account is null)
        {
            return new RefreshSessionRefreshResult(RefreshSessionStatus.Invalid, null, null);
        }

        await TouchRefreshSessionAsync(existing.SessionId);
        var replacement = await CreateRefreshSessionAsync(account, userAgent, remoteIp);
        await RevokeRefreshSessionByIdAsync(existing.SessionId, replacement.Session.SessionId);

        return new RefreshSessionRefreshResult(RefreshSessionStatus.Success, account, replacement);
    }

    public async Task<bool> RevokeRefreshTokenAsync(string refreshToken)
    {
        var hash = HashToken(refreshToken);
        await using var command = _dataSource.CreateCommand("""
            UPDATE identity.refresh_sessions
            SET revoked_at = COALESCE(revoked_at, @revoked_at)
            WHERE token_hash = @token_hash;
            """);
        command.Parameters.AddWithValue("revoked_at", DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("token_hash", hash);
        return await command.ExecuteNonQueryAsync() > 0;
    }

    public async Task<int> RevokeAllRefreshSessionsAsync(string accountId)
    {
        await using var command = _dataSource.CreateCommand("""
            UPDATE identity.refresh_sessions
            SET revoked_at = COALESCE(revoked_at, @revoked_at)
            WHERE account_id = @account_id
              AND revoked_at IS NULL;
            """);
        command.Parameters.AddWithValue("revoked_at", DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("account_id", accountId);
        return await command.ExecuteNonQueryAsync();
    }

    public async Task<RefreshSessionRecord[]> GetRefreshSessionsAsync(string accountId)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT session_id, account_id, player_id, created_at, expires_at, last_seen_at,
                   revoked_at, replaced_by_session_id, user_agent, remote_ip
            FROM identity.refresh_sessions
            WHERE account_id = @account_id
            ORDER BY created_at DESC
            LIMIT 25;
            """);
        command.Parameters.AddWithValue("account_id", accountId);

        var sessions = new List<RefreshSessionRecord>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            sessions.Add(ReadRefreshSession(reader));
        }

        return sessions.ToArray();
    }

    public async Task<AccountRecord?> FindByAccountIdAsync(string accountId)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT account_id, player_id, email, normalized_email, username,
                   password_salt, password_hash, password_iterations,
                   created_at, last_login_at, first_name, last_name, contacts, groups,
                   email_verified_at, roles
            FROM identity.accounts
            WHERE account_id = @account_id;
            """);
        command.Parameters.AddWithValue("account_id", accountId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadAccount(reader) : null;
    }

    public async Task<AccountTokenIssue?> CreatePasswordResetTokenAsync(string email)
    {
        var account = await FindByNormalizedEmailAsync(NormalizeEmail(email));
        return account is null
            ? null
            : await CreateAccountTokenAsync(account, PasswordResetTokenType);
    }

    public async Task<AccountTokenIssue?> CreateEmailVerificationTokenAsync(string accountId)
    {
        var account = await FindByAccountIdAsync(accountId);
        return account is null
            ? null
            : await CreateAccountTokenAsync(account, EmailVerificationTokenType);
    }

    public async Task<PasswordResetStatus> ResetPasswordAsync(string token, string password)
    {
        var accountToken = await FindAccountTokenAsync(token, PasswordResetTokenType);
        if (accountToken is null)
        {
            return PasswordResetStatus.InvalidToken;
        }

        var passwordHash = PasswordHasher.Hash(password);
        await using var command = _dataSource.CreateCommand("""
            UPDATE identity.accounts
            SET password_salt = @password_salt,
                password_hash = @password_hash,
                password_iterations = @password_iterations
            WHERE account_id = @account_id;

            UPDATE identity.account_tokens
            SET consumed_at = @consumed_at
            WHERE token_id = @token_id;
            """);
        command.Parameters.AddWithValue("password_salt", passwordHash.Salt);
        command.Parameters.AddWithValue("password_hash", passwordHash.Hash);
        command.Parameters.AddWithValue("password_iterations", passwordHash.Iterations);
        command.Parameters.AddWithValue("account_id", accountToken.AccountId);
        command.Parameters.AddWithValue("consumed_at", DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("token_id", accountToken.TokenId);
        await command.ExecuteNonQueryAsync();
        await RevokeAllRefreshSessionsAsync(accountToken.AccountId);

        return PasswordResetStatus.Success;
    }

    public async Task<EmailVerificationStatus> VerifyEmailAsync(string token)
    {
        var accountToken = await FindAccountTokenAsync(token, EmailVerificationTokenType);
        if (accountToken is null)
        {
            return EmailVerificationStatus.InvalidToken;
        }

        await using var command = _dataSource.CreateCommand("""
            UPDATE identity.accounts
            SET email_verified_at = COALESCE(email_verified_at, @verified_at)
            WHERE account_id = @account_id;

            UPDATE identity.account_tokens
            SET consumed_at = @consumed_at
            WHERE token_id = @token_id;
            """);
        command.Parameters.AddWithValue("verified_at", DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("account_id", accountToken.AccountId);
        command.Parameters.AddWithValue("consumed_at", DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("token_id", accountToken.TokenId);
        await command.ExecuteNonQueryAsync();

        return EmailVerificationStatus.Success;
    }

    private async Task<AccountTokenIssue> CreateAccountTokenAsync(AccountRecord account, string tokenType)
    {
        var token = NewOpaqueToken("fft");
        var now = DateTimeOffset.UtcNow;
        var accountToken = new AccountTokenRecord(
            TokenId: $"token-{Guid.NewGuid():N}",
            AccountId: account.AccountId,
            TokenType: tokenType,
            CreatedAt: now,
            ExpiresAt: now.Add(_accountTokenLifetime));

        await using var command = _dataSource.CreateCommand("""
            INSERT INTO identity.account_tokens (
                token_id, account_id, token_hash, token_type, created_at, expires_at, consumed_at
            )
            VALUES (
                @token_id, @account_id, @token_hash, @token_type, @created_at, @expires_at, NULL
            );
            """);
        command.Parameters.AddWithValue("token_id", accountToken.TokenId);
        command.Parameters.AddWithValue("account_id", accountToken.AccountId);
        command.Parameters.AddWithValue("token_hash", HashToken(token));
        command.Parameters.AddWithValue("token_type", accountToken.TokenType);
        command.Parameters.AddWithValue("created_at", accountToken.CreatedAt);
        command.Parameters.AddWithValue("expires_at", accountToken.ExpiresAt);
        await command.ExecuteNonQueryAsync();

        return new AccountTokenIssue(token, accountToken);
    }

    private async Task<AccountTokenRecord?> FindAccountTokenAsync(string token, string tokenType)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT token_id, account_id, token_type, created_at, expires_at
            FROM identity.account_tokens
            WHERE token_hash = @token_hash
              AND token_type = @token_type
              AND consumed_at IS NULL
              AND expires_at > @now;
            """);
        command.Parameters.AddWithValue("token_hash", HashToken(token));
        command.Parameters.AddWithValue("token_type", tokenType);
        command.Parameters.AddWithValue("now", DateTimeOffset.UtcNow);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new AccountTokenRecord(
                TokenId: reader.GetString(0),
                AccountId: reader.GetString(1),
                TokenType: reader.GetString(2),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(3),
                ExpiresAt: reader.GetFieldValue<DateTimeOffset>(4))
            : null;
    }

    private async Task<RefreshSessionRecord?> FindRefreshSessionByTokenAsync(string refreshToken)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT session_id, account_id, player_id, created_at, expires_at, last_seen_at,
                   revoked_at, replaced_by_session_id, user_agent, remote_ip
            FROM identity.refresh_sessions
            WHERE token_hash = @token_hash;
            """);
        command.Parameters.AddWithValue("token_hash", HashToken(refreshToken));

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadRefreshSession(reader) : null;
    }

    private async Task TouchRefreshSessionAsync(string sessionId)
    {
        await using var command = _dataSource.CreateCommand("""
            UPDATE identity.refresh_sessions
            SET last_seen_at = @last_seen_at
            WHERE session_id = @session_id;
            """);
        command.Parameters.AddWithValue("last_seen_at", DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("session_id", sessionId);
        await command.ExecuteNonQueryAsync();
    }

    private async Task RevokeRefreshSessionByIdAsync(string sessionId, string? replacedBySessionId)
    {
        await using var command = _dataSource.CreateCommand("""
            UPDATE identity.refresh_sessions
            SET revoked_at = COALESCE(revoked_at, @revoked_at),
                replaced_by_session_id = @replaced_by_session_id
            WHERE session_id = @session_id;
            """);
        command.Parameters.AddWithValue("revoked_at", DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("replaced_by_session_id", replacedBySessionId is null ? DBNull.Value : replacedBySessionId);
        command.Parameters.AddWithValue("session_id", sessionId);
        await command.ExecuteNonQueryAsync();
    }

    private static RefreshSessionRecord ReadRefreshSession(NpgsqlDataReader reader)
    {
        return new RefreshSessionRecord
        {
            SessionId = reader.GetString(0),
            AccountId = reader.GetString(1),
            PlayerId = reader.GetString(2),
            CreatedAt = reader.GetFieldValue<DateTimeOffset>(3),
            ExpiresAt = reader.GetFieldValue<DateTimeOffset>(4),
            LastSeenAt = reader.GetFieldValue<DateTimeOffset>(5),
            RevokedAt = reader.IsDBNull(6) ? null : reader.GetFieldValue<DateTimeOffset>(6),
            ReplacedBySessionId = reader.IsDBNull(7) ? null : reader.GetString(7),
            UserAgent = reader.GetString(8),
            RemoteIp = reader.GetString(9)
        };
    }

    private static string NewOpaqueToken(string prefix)
    {
        return $"{prefix}_{Base64Url(RandomNumberGenerator.GetBytes(32))}";
    }

    private static string HashToken(string token)
    {
        return Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    }

    private static string Base64Url(byte[] value)
    {
        return Convert.ToBase64String(value)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static string NormalizeMetadata(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= 256 ? trimmed : trimmed[..256];
    }
}

internal sealed record RefreshSessionIssue(string RefreshToken, RefreshSessionRecord Session);

internal sealed record RefreshSessionRefreshResult(
    RefreshSessionStatus Status,
    AccountRecord? Account,
    RefreshSessionIssue? RefreshSession);

internal enum RefreshSessionStatus
{
    Success,
    Invalid
}

internal sealed record AccountTokenIssue(string Token, AccountTokenRecord Record);

internal sealed record AccountTokenRecord(
    string TokenId,
    string AccountId,
    string TokenType,
    DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt);

internal enum PasswordResetStatus
{
    Success,
    InvalidToken
}

internal enum EmailVerificationStatus
{
    Success,
    InvalidToken
}

internal sealed class RefreshSessionRecord
{
    public string SessionId { get; init; } = string.Empty;
    public string AccountId { get; init; } = string.Empty;
    public string PlayerId { get; init; } = string.Empty;
    public DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset ExpiresAt { get; init; }
    public DateTimeOffset LastSeenAt { get; init; }
    public DateTimeOffset? RevokedAt { get; init; }
    public string? ReplacedBySessionId { get; init; }
    public string UserAgent { get; init; } = string.Empty;
    public string RemoteIp { get; init; } = string.Empty;

    public RefreshSessionDto ToDto()
    {
        return new RefreshSessionDto(
            SessionId,
            CreatedAt.ToString("O"),
            ExpiresAt.ToString("O"),
            LastSeenAt.ToString("O"),
            RevokedAt?.ToString("O"));
    }
}

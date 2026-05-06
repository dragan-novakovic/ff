using Microsoft.Extensions.Configuration;
using Npgsql;

namespace Ff.Identity.Api.Accounts;

internal sealed class AccountStore : IDisposable
{
    private readonly NpgsqlDataSource _dataSource;

    public AccountStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_IDENTITY_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Identity")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS identity;

            CREATE TABLE IF NOT EXISTS identity.accounts (
                account_id text PRIMARY KEY,
                player_id text NOT NULL UNIQUE,
                email text NOT NULL,
                normalized_email text NOT NULL UNIQUE,
                username text NOT NULL,
                password_salt text NOT NULL,
                password_hash text NOT NULL,
                password_iterations integer NOT NULL,
                created_at timestamptz NOT NULL,
                last_login_at timestamptz NULL,
                first_name text NOT NULL DEFAULT '',
                last_name text NOT NULL DEFAULT '',
                contacts text[] NOT NULL DEFAULT ARRAY[]::text[],
                groups text[] NOT NULL DEFAULT ARRAY[]::text[]
            );
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<AccountRecord> EnsureSeedAccountAsync(string email, string password, string username)
    {
        var normalizedEmail = NormalizeEmail(email);
        var existing = await FindByNormalizedEmailAsync(normalizedEmail);
        if (existing is not null)
        {
            return existing;
        }

        var account = CreateAccount(email, password, username);
        try
        {
            await InsertAccountAsync(account);
            return account;
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return await FindByNormalizedEmailAsync(normalizedEmail)
                ?? throw new InvalidOperationException("Seed account creation conflicted but the account could not be loaded.");
        }
    }

    public async Task<AccountRegistrationResult> RegisterAsync(string email, string password, string? username)
    {
        var account = CreateAccount(
            email,
            password,
            string.IsNullOrWhiteSpace(username) ? UsernameFromEmail(email) : username.Trim());

        try
        {
            await InsertAccountAsync(account);
            return new AccountRegistrationResult(AccountRegistrationStatus.Created, account);
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return new AccountRegistrationResult(AccountRegistrationStatus.DuplicateEmail, null);
        }
    }

    public async Task<AccountLoginResult> LoginAsync(string email, string password)
    {
        var account = await FindByNormalizedEmailAsync(NormalizeEmail(email));
        if (account is null)
        {
            return new AccountLoginResult(AccountLoginStatus.NotFound, null);
        }

        if (!PasswordHasher.Verify(password, account.PasswordSalt, account.PasswordHash, account.PasswordIterations))
        {
            return new AccountLoginResult(AccountLoginStatus.InvalidPassword, null);
        }

        account.LastLoginAt = DateTimeOffset.UtcNow;
        await using var command = _dataSource.CreateCommand("""
            UPDATE identity.accounts
            SET last_login_at = @last_login_at
            WHERE account_id = @account_id;
            """);
        command.Parameters.AddWithValue("last_login_at", account.LastLoginAt);
        command.Parameters.AddWithValue("account_id", account.AccountId);
        await command.ExecuteNonQueryAsync();

        return new AccountLoginResult(AccountLoginStatus.Success, account);
    }

    public async Task<AccountRecord?> FindByPlayerIdAsync(string playerId)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT account_id, player_id, email, normalized_email, username,
                   password_salt, password_hash, password_iterations,
                   created_at, last_login_at, first_name, last_name, contacts, groups
            FROM identity.accounts
            WHERE player_id = @player_id;
            """);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadAccount(reader) : null;
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task<AccountRecord?> FindByNormalizedEmailAsync(string normalizedEmail)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT account_id, player_id, email, normalized_email, username,
                   password_salt, password_hash, password_iterations,
                   created_at, last_login_at, first_name, last_name, contacts, groups
            FROM identity.accounts
            WHERE normalized_email = @normalized_email;
            """);
        command.Parameters.AddWithValue("normalized_email", normalizedEmail);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadAccount(reader) : null;
    }

    private async Task InsertAccountAsync(AccountRecord account)
    {
        await using var command = _dataSource.CreateCommand("""
            INSERT INTO identity.accounts (
                account_id, player_id, email, normalized_email, username,
                password_salt, password_hash, password_iterations,
                created_at, last_login_at, first_name, last_name, contacts, groups
            )
            VALUES (
                @account_id, @player_id, @email, @normalized_email, @username,
                @password_salt, @password_hash, @password_iterations,
                @created_at, @last_login_at, @first_name, @last_name, @contacts, @groups
            );
            """);
        command.Parameters.AddWithValue("account_id", account.AccountId);
        command.Parameters.AddWithValue("player_id", account.PlayerId);
        command.Parameters.AddWithValue("email", account.Email);
        command.Parameters.AddWithValue("normalized_email", account.NormalizedEmail);
        command.Parameters.AddWithValue("username", account.Username);
        command.Parameters.AddWithValue("password_salt", account.PasswordSalt);
        command.Parameters.AddWithValue("password_hash", account.PasswordHash);
        command.Parameters.AddWithValue("password_iterations", account.PasswordIterations);
        command.Parameters.AddWithValue("created_at", account.CreatedAt);
        command.Parameters.AddWithValue("last_login_at", DBNull.Value);
        command.Parameters.AddWithValue("first_name", account.FirstName);
        command.Parameters.AddWithValue("last_name", account.LastName);
        command.Parameters.AddWithValue("contacts", account.Contacts.ToArray());
        command.Parameters.AddWithValue("groups", account.Groups.ToArray());
        await command.ExecuteNonQueryAsync();
    }

    private static AccountRecord ReadAccount(NpgsqlDataReader reader)
    {
        return new AccountRecord
        {
            AccountId = reader.GetString(0),
            PlayerId = reader.GetString(1),
            Email = reader.GetString(2),
            NormalizedEmail = reader.GetString(3),
            Username = reader.GetString(4),
            PasswordSalt = reader.GetString(5),
            PasswordHash = reader.GetString(6),
            PasswordIterations = reader.GetInt32(7),
            CreatedAt = reader.GetFieldValue<DateTimeOffset>(8),
            LastLoginAt = reader.IsDBNull(9) ? null : reader.GetFieldValue<DateTimeOffset>(9),
            FirstName = reader.GetString(10),
            LastName = reader.GetString(11),
            Contacts = reader.GetFieldValue<string[]>(12).ToList(),
            Groups = reader.GetFieldValue<string[]>(13).ToList()
        };
    }

    private static AccountRecord CreateAccount(string email, string password, string username)
    {
        var passwordHash = PasswordHasher.Hash(password);
        var now = DateTimeOffset.UtcNow;
        var normalizedEmail = email.Trim();

        return new AccountRecord
        {
            AccountId = $"account-{Guid.NewGuid():N}",
            PlayerId = $"player-{Guid.NewGuid():N}",
            Email = normalizedEmail,
            NormalizedEmail = NormalizeEmail(normalizedEmail),
            Username = string.IsNullOrWhiteSpace(username) ? UsernameFromEmail(normalizedEmail) : username.Trim(),
            PasswordSalt = passwordHash.Salt,
            PasswordHash = passwordHash.Hash,
            PasswordIterations = passwordHash.Iterations,
            CreatedAt = now,
            Contacts = ["global", "demo-contact"],
            Groups = []
        };
    }

    private static string NormalizeEmail(string email)
    {
        return email.Trim().ToUpperInvariant();
    }

    private static string UsernameFromEmail(string email)
    {
        var localPart = email.Split('@', 2)[0].Trim();
        return string.IsNullOrWhiteSpace(localPart) ? "player" : localPart;
    }
}

internal sealed class AccountRecord
{
    public string AccountId { get; set; } = string.Empty;
    public string PlayerId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string NormalizedEmail { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string PasswordSalt { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public int PasswordIterations { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? LastLoginAt { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public List<string> Contacts { get; set; } = [];
    public List<string> Groups { get; set; } = [];

    public PlayerDto ToPlayerDto()
    {
        return new PlayerDto(
            Uid: PlayerId,
            Email: Email,
            Username: Username,
            CreatedOn: CreatedAt.ToString("O"),
            FirstName: FirstName,
            LastName: LastName,
            Contacts: Contacts.ToArray(),
            Groups: Groups.ToArray());
    }
}

internal sealed record AccountRegistrationResult(AccountRegistrationStatus Status, AccountRecord? Account);

internal enum AccountRegistrationStatus
{
    Created,
    DuplicateEmail
}

internal sealed record AccountLoginResult(AccountLoginStatus Status, AccountRecord? Account);

internal enum AccountLoginStatus
{
    Success,
    NotFound,
    InvalidPassword
}

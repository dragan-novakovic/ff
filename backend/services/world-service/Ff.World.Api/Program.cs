using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<WorldStore>();
builder.Services.AddSingleton<DevTokenValidator>();

var metadata = new ServiceMetadata(
    Service: "world-service",
    DisplayName: "World Service",
    Domain: "Countries, regions, battles, laws, modifiers, and global time",
    Description: "Owns persistent world state and applies authoritative world changes such as region ownership, battles, and global configuration.",
    Owns: ["countries", "regions", "battles", "battle contributions", "military units", "political parties", "elections", "votes", "office terms", "law proposals", "law votes", "laws", "diplomacy treaties", "region ownership", "laws and modifiers", "global day/time", "world configuration"],
    Responsibilities: ["Serve world configuration", "Apply region ownership changes", "Persist country battles", "Persist military unit state", "Persist political parties and elections", "Persist congress law proposals and votes", "Persist diplomacy treaties", "Execute passed tax and treasury laws", "Expose country/region/battle/politics/diplomacy state"]);

var app = builder.Build();

var worldStore = app.Services.GetRequiredService<WorldStore>();
await worldStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/countries", async (WorldStore world) =>
    Results.Ok(await world.GetCountriesAsync())).WithName("GetCountries");

app.MapGet("/countries/{countryId}", async (string countryId, WorldStore world) =>
{
    var country = await world.GetCountryAsync(countryId);
    return country is null
        ? Results.NotFound(new ErrorResponse("Country was not found."))
        : Results.Ok(country);
}).WithName("GetCountry");

app.MapTreasuryEndpoints();

app.MapGet("/regions", async (string? countryId, WorldStore world) =>
    Results.Ok(await world.GetRegionsAsync(countryId))).WithName("GetRegions");

app.MapGet("/regions/{regionId}", async (string regionId, WorldStore world) =>
{
    var region = await world.GetRegionAsync(regionId);
    return region is null
        ? Results.NotFound(new ErrorResponse("Region was not found."))
        : Results.Ok(region);
}).WithName("GetRegion");

app.MapResourceSiteEndpoints();
app.MapTerritoryEndpoints();
app.MapBattleEndpoints();
app.MapMilitaryUnitEndpoints();
app.MapCampaignEndpoints();
app.MapPoliticsEndpoints();
app.MapLawEndpoints();
app.MapDiplomacyEndpoints();

app.MapGet("/players/{playerId}/citizenship", async (
    string playerId,
    HttpRequest request,
    WorldStore world,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    return Results.Ok(await world.GetPlayerCitizenshipAsync(access.PlayerId!));
}).WithName("GetPlayerCitizenship");

app.MapPost("/players/{playerId}/citizenship/join", async (
    string playerId,
    CitizenshipRequest request,
    HttpRequest httpRequest,
    WorldStore world,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(request.CountryId))
    {
        return Results.BadRequest(new ErrorResponse("Country is required."));
    }

    var result = await world.JoinCountryAsync(access.PlayerId!, request.CountryId);
    if (result is null)
    {
        return Results.NotFound(new ErrorResponse("Country was not found."));
    }

    return result.Completed
        ? Results.Ok(result)
        : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
}).WithName("JoinCountry");

app.MapPost("/players/{playerId}/citizenship/change", async (
    string playerId,
    CitizenshipRequest request,
    HttpRequest httpRequest,
    WorldStore world,
    DevTokenValidator tokens) =>
{
    var access = ValidatePlayerAccess(playerId, httpRequest, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(request.CountryId))
    {
        return Results.BadRequest(new ErrorResponse("Country is required."));
    }

    var result = await world.ChangeCountryAsync(access.PlayerId!, request.CountryId);
    if (result is null)
    {
        return Results.NotFound(new ErrorResponse("Country was not found."));
    }

    return result.Completed
        ? Results.Ok(result)
        : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
}).WithName("ChangeCountry");

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
            new ErrorResponse("You cannot access another player's citizenship."),
            statusCode: StatusCodes.Status403Forbidden));
    }

    return PlayerAccessResult.Allowed(token.PlayerId!);
}

internal sealed partial class WorldStore : IDisposable
{
    private readonly NpgsqlDataSource _dataSource;

    public WorldStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_WORLD_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("World")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS world;

            CREATE TABLE IF NOT EXISTS world.countries (
                country_id text PRIMARY KEY,
                name text NOT NULL,
                code text NOT NULL UNIQUE,
                description text NOT NULL,
                government text NOT NULL,
                treasury integer NOT NULL,
                tax_rate integer NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS world.regions (
                region_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                name text NOT NULL,
                terrain text NOT NULL,
                resource_focus text NOT NULL,
                population integer NOT NULL,
                infrastructure integer NOT NULL,
                is_capital boolean NOT NULL DEFAULT false,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_regions_country_id
                ON world.regions (country_id);

            CREATE TABLE IF NOT EXISTS world.player_citizenships (
                player_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                status text NOT NULL,
                joined_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_player_citizenships_country_id
                ON world.player_citizenships (country_id);
            """;

        await using (var command = _dataSource.CreateCommand(sql))
        {
            await command.ExecuteNonQueryAsync();
        }

        await InitializeBattleSchemaAsync();
        await InitializeTerritorySchemaAsync();
        await InitializeMilitaryUnitSchemaAsync();
        await InitializeCampaignSchemaAsync();
        await InitializePoliticsSchemaAsync();
        await InitializeLawsSchemaAsync();
        await InitializeDiplomacySchemaAsync();
        await InitializeResourceSiteSchemaAsync();
        await SeedCatalogAsync();
        await SeedResourceSitesAsync();
        await SeedTerritoryAsync();
        await SeedTreasuryAsync();
        await SeedBattlesAsync();
        await SeedCampaignsAsync();
        await SeedPoliticsAsync();
        await SeedLawsAsync();
    }

    public async Task<CountryListResponse> GetCountriesAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        var countries = await ReadCountrySummariesAsync(connection);
        return new CountryListResponse(countries.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<CountryDetailsDto?> GetCountryAsync(string countryId)
    {
        var normalizedCountryId = NormalizeId(countryId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var country = await ReadCountryDetailsAsync(connection, normalizedCountryId);
        if (country is null)
        {
            return null;
        }

        var regions = await ReadRegionsAsync(connection, normalizedCountryId);
        return country with { Regions = regions.ToArray() };
    }

    public async Task<RegionListResponse> GetRegionsAsync(string? countryId)
    {
        var normalizedCountryId = string.IsNullOrWhiteSpace(countryId)
            ? null
            : NormalizeId(countryId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var regions = await ReadRegionsAsync(connection, normalizedCountryId);
        return new RegionListResponse(regions.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<RegionDto?> GetRegionAsync(string regionId)
    {
        var normalizedRegionId = NormalizeId(regionId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT region_id, country_id, name, terrain, resource_focus,
                   population, infrastructure, is_capital, updated_at
            FROM world.regions
            WHERE region_id = @region_id;
            """, connection);
        command.Parameters.AddWithValue("region_id", normalizedRegionId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadRegion(reader) : null;
    }

    public async Task<PlayerCitizenshipResponse> GetPlayerCitizenshipAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var citizenship = await ReadPlayerCitizenshipAsync(connection, null, normalizedPlayerId);
        return new PlayerCitizenshipResponse(
            PlayerId: normalizedPlayerId,
            Citizenship: citizenship,
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<CitizenshipMutationResult?> JoinCountryAsync(string playerId, string countryId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedCountryId = NormalizeId(countryId);
        if (!await CountryExistsAsync(normalizedCountryId))
        {
            return null;
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var inserted = false;

        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.player_citizenships (
                player_id, country_id, status, joined_at, updated_at
            )
            VALUES (@player_id, @country_id, 'active', @joined_at, @updated_at)
            ON CONFLICT (player_id) DO NOTHING;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("country_id", normalizedCountryId);
            command.Parameters.AddWithValue("joined_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            inserted = await command.ExecuteNonQueryAsync() > 0;
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        if (!inserted)
        {
            return new CitizenshipMutationResult(
                Completed: false,
                Message: "You already have citizenship. Use change country to move.",
                Citizenship: citizenship,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        return new CitizenshipMutationResult(
            Completed: true,
            Message: $"Joined {citizenship!.CountryName}. Citizenship is now active.",
            Citizenship: citizenship,
            UpdatedAt: now);
    }

    public async Task<CitizenshipMutationResult?> ChangeCountryAsync(string playerId, string countryId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedCountryId = NormalizeId(countryId);
        if (!await CountryExistsAsync(normalizedCountryId))
        {
            return null;
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var existing = await ReadPlayerCitizenshipForUpdateAsync(connection, transaction, normalizedPlayerId);
        if (existing is null)
        {
            await transaction.RollbackAsync();
            return new CitizenshipMutationResult(
                Completed: false,
                Message: "Join a country before changing citizenship.",
                Citizenship: null,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        if (string.Equals(existing.CountryId, normalizedCountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new CitizenshipMutationResult(
                Completed: false,
                Message: $"You are already a citizen of {existing.CountryName}.",
                Citizenship: existing,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("""
            UPDATE world.player_citizenships
            SET country_id = @country_id,
                status = 'active',
                updated_at = @updated_at
            WHERE player_id = @player_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("country_id", normalizedCountryId);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return new CitizenshipMutationResult(
            Completed: true,
            Message: $"Citizenship changed to {citizenship!.CountryName}.",
            Citizenship: citizenship,
            UpdatedAt: now);
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task SeedCatalogAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        foreach (var country in WorldCatalog.Countries)
        {
            await using (var command = new NpgsqlCommand("""
                INSERT INTO world.countries (
                    country_id, name, code, description, government,
                    treasury, tax_rate, created_at, updated_at
                )
                VALUES (
                    @country_id, @name, @code, @description, @government,
                    @treasury, @tax_rate, @created_at, @updated_at
                )
                ON CONFLICT (country_id) DO UPDATE
                SET name = EXCLUDED.name,
                    code = EXCLUDED.code,
                    description = EXCLUDED.description,
                    government = EXCLUDED.government,
                    updated_at = EXCLUDED.updated_at;
                """, connection, transaction))
            {
                command.Parameters.AddWithValue("country_id", country.CountryId);
                command.Parameters.AddWithValue("name", country.Name);
                command.Parameters.AddWithValue("code", country.Code);
                command.Parameters.AddWithValue("description", country.Description);
                command.Parameters.AddWithValue("government", country.Government);
                command.Parameters.AddWithValue("treasury", country.Treasury);
                command.Parameters.AddWithValue("tax_rate", country.TaxRate);
                command.Parameters.AddWithValue("created_at", now);
                command.Parameters.AddWithValue("updated_at", now);
                await command.ExecuteNonQueryAsync();
            }

            foreach (var region in country.Regions)
            {
                await using var command = new NpgsqlCommand("""
                    INSERT INTO world.regions (
                        region_id, country_id, name, terrain, resource_focus,
                        population, infrastructure, is_capital, created_at, updated_at
                    )
                    VALUES (
                        @region_id, @country_id, @name, @terrain, @resource_focus,
                        @population, @infrastructure, @is_capital, @created_at, @updated_at
                    )
                    ON CONFLICT (region_id) DO UPDATE
                    SET name = EXCLUDED.name,
                        terrain = EXCLUDED.terrain,
                        resource_focus = EXCLUDED.resource_focus,
                        population = EXCLUDED.population,
                        infrastructure = EXCLUDED.infrastructure,
                        is_capital = EXCLUDED.is_capital,
                        updated_at = EXCLUDED.updated_at;
                    """, connection, transaction);
                command.Parameters.AddWithValue("region_id", region.RegionId);
                command.Parameters.AddWithValue("country_id", country.CountryId);
                command.Parameters.AddWithValue("name", region.Name);
                command.Parameters.AddWithValue("terrain", region.Terrain);
                command.Parameters.AddWithValue("resource_focus", region.ResourceFocus);
                command.Parameters.AddWithValue("population", region.Population);
                command.Parameters.AddWithValue("infrastructure", region.Infrastructure);
                command.Parameters.AddWithValue("is_capital", region.IsCapital);
                command.Parameters.AddWithValue("created_at", now);
                command.Parameters.AddWithValue("updated_at", now);
                await command.ExecuteNonQueryAsync();
            }
        }

        await transaction.CommitAsync();
    }

    private async Task<bool> CountryExistsAsync(string countryId)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT 1
            FROM world.countries
            WHERE country_id = @country_id;
            """);
        command.Parameters.AddWithValue("country_id", countryId);
        var value = await command.ExecuteScalarAsync();
        return value is not null;
    }

    private static async Task<List<CountrySummaryDto>> ReadCountrySummariesAsync(NpgsqlConnection connection)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.country_id, c.name, c.code, c.description, c.government,
                   c.treasury, c.tax_rate,
                   COUNT(DISTINCT r.region_id)::bigint AS region_count,
                   COUNT(DISTINCT pc.player_id)::bigint AS citizen_count,
                   c.updated_at
            FROM world.countries c
            LEFT JOIN world.regions r ON r.country_id = c.country_id
            LEFT JOIN world.player_citizenships pc ON pc.country_id = c.country_id
            GROUP BY c.country_id, c.name, c.code, c.description, c.government,
                     c.treasury, c.tax_rate, c.updated_at
            ORDER BY c.name;
            """, connection);

        var countries = new List<CountrySummaryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            countries.Add(ReadCountrySummary(reader));
        }

        return countries;
    }

    private static async Task<CountryDetailsDto?> ReadCountryDetailsAsync(NpgsqlConnection connection, string countryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.country_id, c.name, c.code, c.description, c.government,
                   c.treasury, c.tax_rate,
                   COUNT(DISTINCT r.region_id)::bigint AS region_count,
                   COUNT(DISTINCT pc.player_id)::bigint AS citizen_count,
                   c.updated_at
            FROM world.countries c
            LEFT JOIN world.regions r ON r.country_id = c.country_id
            LEFT JOIN world.player_citizenships pc ON pc.country_id = c.country_id
            WHERE c.country_id = @country_id
            GROUP BY c.country_id, c.name, c.code, c.description, c.government,
                     c.treasury, c.tax_rate, c.updated_at;
            """, connection);
        command.Parameters.AddWithValue("country_id", countryId);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        var summary = ReadCountrySummary(reader);
        return new CountryDetailsDto(
            CountryId: summary.CountryId,
            Name: summary.Name,
            Code: summary.Code,
            Description: summary.Description,
            Government: summary.Government,
            Treasury: summary.Treasury,
            TaxRate: summary.TaxRate,
            RegionCount: summary.RegionCount,
            CitizenCount: summary.CitizenCount,
            UpdatedAt: summary.UpdatedAt,
            Regions: []);
    }

    private static async Task<List<RegionDto>> ReadRegionsAsync(NpgsqlConnection connection, string? countryId)
    {
        var sql = string.IsNullOrWhiteSpace(countryId)
            ? """
                SELECT region_id, country_id, name, terrain, resource_focus,
                       population, infrastructure, is_capital, updated_at
                FROM world.regions
                ORDER BY country_id, is_capital DESC, name;
                """
            : """
                SELECT region_id, country_id, name, terrain, resource_focus,
                       population, infrastructure, is_capital, updated_at
                FROM world.regions
                WHERE country_id = @country_id
                ORDER BY is_capital DESC, name;
                """;
        await using var command = new NpgsqlCommand(sql, connection);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }

        var regions = new List<RegionDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            regions.Add(ReadRegion(reader));
        }

        return regions;
    }

    private static async Task<PlayerCitizenshipDto?> ReadPlayerCitizenshipForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT pc.player_id, pc.country_id, c.name, c.code, pc.status,
                   pc.joined_at, pc.updated_at
            FROM world.player_citizenships pc
            INNER JOIN world.countries c ON c.country_id = pc.country_id
            WHERE pc.player_id = @player_id
            FOR UPDATE OF pc;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadPlayerCitizenship(reader) : null;
    }

    private static async Task<PlayerCitizenshipDto?> ReadPlayerCitizenshipAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT pc.player_id, pc.country_id, c.name, c.code, pc.status,
                   pc.joined_at, pc.updated_at
            FROM world.player_citizenships pc
            INNER JOIN world.countries c ON c.country_id = pc.country_id
            WHERE pc.player_id = @player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadPlayerCitizenship(reader) : null;
    }

    private static CountrySummaryDto ReadCountrySummary(NpgsqlDataReader reader)
    {
        return new CountrySummaryDto(
            CountryId: reader.GetString(0),
            Name: reader.GetString(1),
            Code: reader.GetString(2),
            Description: reader.GetString(3),
            Government: reader.GetString(4),
            Treasury: reader.GetInt32(5),
            TaxRate: reader.GetInt32(6),
            RegionCount: Convert.ToInt32(reader.GetInt64(7)),
            CitizenCount: Convert.ToInt32(reader.GetInt64(8)),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static RegionDto ReadRegion(NpgsqlDataReader reader)
    {
        return new RegionDto(
            RegionId: reader.GetString(0),
            CountryId: reader.GetString(1),
            Name: reader.GetString(2),
            Terrain: reader.GetString(3),
            ResourceFocus: reader.GetString(4),
            Population: reader.GetInt32(5),
            Infrastructure: reader.GetInt32(6),
            IsCapital: reader.GetBoolean(7),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(8));
    }

    private static PlayerCitizenshipDto ReadPlayerCitizenship(NpgsqlDataReader reader)
    {
        return new PlayerCitizenshipDto(
            PlayerId: reader.GetString(0),
            CountryId: reader.GetString(1),
            CountryName: reader.GetString(2),
            CountryCode: reader.GetString(3),
            Status: reader.GetString(4),
            JoinedAt: reader.GetFieldValue<DateTimeOffset>(5),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(6));
    }

    private static string NormalizePlayerId(string playerId)
    {
        return playerId.Trim().ToLowerInvariant();
    }

    private static string NormalizeId(string value)
    {
        return value.Trim().ToLowerInvariant();
    }
}

internal static class WorldCatalog
{
    public static CountryTemplate[] Countries { get; } =
    [
        new CountryTemplate(
            CountryId: "freiland",
            Name: "Freiland",
            Code: "FRL",
            Description: "A civic republic with balanced farms, workshops, and frontier settlements.",
            Government: "Civic republic",
            Treasury: 250_000,
            TaxRate: 5,
            Regions:
            [
                new RegionTemplate("freyport", "Freyport", "Coastal city", "Trade", 125_000, 78, true),
                new RegionTemplate("greenmarch", "Greenmarch", "Plains", "Grain", 82_000, 63, false),
                new RegionTemplate("ironvale", "Ironvale", "Highlands", "Iron", 54_000, 58, false)
            ]),
        new CountryTemplate(
            CountryId: "nordheim",
            Name: "Nordheim",
            Code: "NRD",
            Description: "A northern industrial union with strong mining regions and rugged defenses.",
            Government: "Industrial union",
            Treasury: 190_000,
            TaxRate: 6,
            Regions:
            [
                new RegionTemplate("nordvik", "Nordvik", "Frozen harbor", "Shipping", 92_000, 70, true),
                new RegionTemplate("frostforge", "Frostforge", "Mountains", "Steel", 61_000, 66, false),
                new RegionTemplate("pinewatch", "Pinewatch", "Forest", "Timber", 47_000, 52, false)
            ]),
        new CountryTemplate(
            CountryId: "solara",
            Name: "Solara",
            Code: "SLR",
            Description: "A trade federation controlling warm ports, fertile riverlands, and caravan routes.",
            Government: "Trade federation",
            Treasury: 310_000,
            TaxRate: 4,
            Regions:
            [
                new RegionTemplate("sunspire", "Sunspire", "River capital", "Finance", 138_000, 82, true),
                new RegionTemplate("goldenfields", "Goldenfields", "Farmland", "Food", 97_000, 68, false),
                new RegionTemplate("duneway", "Duneway", "Desert route", "Caravans", 41_000, 49, false)
            ])
    ];
}

internal sealed class DevTokenValidator
{
    private readonly byte[] _secret;
    private readonly TimeSpan _legacyTokenLifetime;
    private static readonly TimeSpan ClockSkew = TimeSpan.FromMinutes(2);

    public DevTokenValidator(IConfiguration configuration)
    {
        var secret = configuration["FF_IDENTITY_TOKEN_SECRET"]
            ?? configuration["Identity:TokenSecret"]
            ?? "ff-development-token-secret-change-me";
        _secret = Encoding.UTF8.GetBytes(secret);

        var lifetimeMinutes = configuration.GetValue(
            "FF_IDENTITY_ACCESS_TOKEN_LIFETIME_MINUTES",
            configuration.GetValue("FF_IDENTITY_TOKEN_LIFETIME_MINUTES", 15));
        _legacyTokenLifetime = TimeSpan.FromMinutes(Math.Clamp(lifetimeMinutes, 1, 24 * 60));
    }

    public TokenValidationResult Validate(string authorizationHeader)
    {
        const string bearerPrefix = "Bearer ";
        if (string.IsNullOrWhiteSpace(authorizationHeader) ||
            authorizationHeader.Contains('\n') ||
            authorizationHeader.Contains('\r') ||
            authorizationHeader.Contains(',') ||
            !authorizationHeader.StartsWith(bearerPrefix, StringComparison.Ordinal))
        {
            return TokenValidationResult.Invalid;
        }

        var token = authorizationHeader[bearerPrefix.Length..].Trim();
        var tokenParts = token.Split('.', 2);
        if (tokenParts.Length != 2 ||
            string.IsNullOrWhiteSpace(tokenParts[0]) ||
            string.IsNullOrWhiteSpace(tokenParts[1]))
        {
            return TokenValidationResult.Invalid;
        }

        try
        {
            var payloadBytes = Base64UrlDecode(tokenParts[0]);
            var expectedSignature = HMACSHA256.HashData(_secret, payloadBytes);
            var actualSignature = Base64UrlDecode(tokenParts[1]);
            if (actualSignature.Length != expectedSignature.Length ||
                !CryptographicOperations.FixedTimeEquals(expectedSignature, actualSignature))
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
            var now = DateTimeOffset.UtcNow;
            if (issuedAt - now > ClockSkew)
            {
                return TokenValidationResult.Invalid;
            }

            if (TryReadClaims(payloadParts[1], out var claims))
            {
                if (!string.Equals(claims.Type, "access", StringComparison.Ordinal) ||
                    string.IsNullOrWhiteSpace(claims.AccountId))
                {
                    return TokenValidationResult.Invalid;
                }

                var expiresAt = DateTimeOffset.FromUnixTimeSeconds(claims.ExpiresAt);
                if (now - expiresAt > ClockSkew)
                {
                    return TokenValidationResult.Invalid;
                }
            }
            else if (now - issuedAt > _legacyTokenLifetime)
            {
                return TokenValidationResult.Invalid;
            }

            return TokenValidationResult.Valid(payloadParts[0]);
        }
        catch (Exception ex) when (ex is FormatException or JsonException or ArgumentException or OverflowException)
        {
            return TokenValidationResult.Invalid;
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

        claims = default!;
        return false;
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

internal sealed record AccessTokenClaims(
    [property: JsonPropertyName("accountId")] string AccountId,
    [property: JsonPropertyName("roles")] string[] Roles,
    [property: JsonPropertyName("emailVerified")] bool EmailVerified,
    [property: JsonPropertyName("typ")] string Type,
    [property: JsonPropertyName("exp")] long ExpiresAt,
    [property: JsonPropertyName("jti")] string JwtId);

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record CountryListResponse(CountrySummaryDto[] Countries, DateTimeOffset UpdatedAt);

internal sealed record RegionListResponse(RegionDto[] Regions, DateTimeOffset UpdatedAt);

internal sealed record CountrySummaryDto(
    string CountryId,
    string Name,
    string Code,
    string Description,
    string Government,
    int Treasury,
    int TaxRate,
    int RegionCount,
    int CitizenCount,
    DateTimeOffset UpdatedAt);

internal sealed record CountryDetailsDto(
    string CountryId,
    string Name,
    string Code,
    string Description,
    string Government,
    int Treasury,
    int TaxRate,
    int RegionCount,
    int CitizenCount,
    DateTimeOffset UpdatedAt,
    RegionDto[] Regions);

internal sealed record RegionDto(
    string RegionId,
    string CountryId,
    string Name,
    string Terrain,
    string ResourceFocus,
    int Population,
    int Infrastructure,
    bool IsCapital,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerCitizenshipResponse(
    string PlayerId,
    PlayerCitizenshipDto? Citizenship,
    DateTimeOffset UpdatedAt);

internal sealed record CitizenshipMutationResult(
    bool Completed,
    string Message,
    PlayerCitizenshipDto? Citizenship,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerCitizenshipDto(
    string PlayerId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Status,
    DateTimeOffset JoinedAt,
    DateTimeOffset UpdatedAt);

internal sealed record CitizenshipRequest(string? CountryId);

internal sealed record CountryTemplate(
    string CountryId,
    string Name,
    string Code,
    string Description,
    string Government,
    int Treasury,
    int TaxRate,
    RegionTemplate[] Regions);

internal sealed record RegionTemplate(
    string RegionId,
    string Name,
    string Terrain,
    string ResourceFocus,
    int Population,
    int Infrastructure,
    bool IsCapital);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

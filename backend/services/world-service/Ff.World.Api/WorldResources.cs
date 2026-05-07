using Npgsql;

internal static class ResourceSiteEndpoints
{
    public static void MapResourceSiteEndpoints(this WebApplication app)
    {
        app.MapGet("/resource-sites", async (
            string? countryId,
            string? regionId,
            WorldStore world) =>
        {
            return Results.Ok(await world.ListResourceSitesAsync(countryId, regionId));
        }).WithName("ListResourceSites");

        app.MapGet("/regions/{regionId}/resource-sites", async (
            string regionId,
            WorldStore world) =>
        {
            return Results.Ok(await world.ListResourceSitesAsync(null, regionId));
        }).WithName("ListRegionResourceSites");

        app.MapGet("/resource-sites/{siteId}", async (
            string siteId,
            WorldStore world) =>
        {
            var site = await world.GetResourceSiteAsync(siteId);
            return site is null
                ? Results.NotFound(new ErrorResponse("Resource site was not found."))
                : Results.Ok(site);
        }).WithName("GetResourceSite");

        app.MapPost("/resource-sites/{siteId}/deplete", async (
            string siteId,
            ResourceSiteDepletionRequest request,
            HttpRequest httpRequest,
            WorldStore world,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return ToStoreResult(await world.DepleteResourceSiteAsync(siteId, request));
        }).WithName("DepleteResourceSite");
    }

    private static IResult ToStoreResult<T>(WorldStoreResult<T> result) where T : class
    {
        if (result.StatusCode is >= StatusCodes.Status200OK and < StatusCodes.Status300MultipleChoices)
        {
            return result.StatusCode == StatusCodes.Status200OK
                ? Results.Ok(result.Value)
                : Results.Json(result.Value, statusCode: result.StatusCode);
        }

        return result.StatusCode == StatusCodes.Status404NotFound
            ? Results.NotFound(new ErrorResponse(result.Message ?? "Resource was not found."))
            : Results.Json(
                new ErrorResponse(result.Message ?? "Request failed."),
                statusCode: result.StatusCode);
    }

    private static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
    {
        var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
        return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
            string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
    }
}

internal sealed partial class WorldStore
{
    public async Task InitializeResourceSiteSchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.region_resource_sites (
                site_id text PRIMARY KEY,
                region_id text NOT NULL REFERENCES world.regions(region_id) ON DELETE CASCADE,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                resource_id text NOT NULL,
                resource_name text NOT NULL,
                item_id text NOT NULL,
                item_name text NOT NULL,
                item_category text NOT NULL,
                site_name text NOT NULL,
                terrain text NOT NULL,
                base_yield integer NOT NULL,
                extraction_seconds integer NOT NULL,
                reserve_remaining integer NOT NULL,
                reserve_capacity integer NOT NULL,
                depletion_per_run integer NOT NULL,
                quality_percent integer NOT NULL,
                extraction_count integer NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT region_resource_sites_yield_check CHECK (base_yield > 0),
                CONSTRAINT region_resource_sites_reserve_check CHECK (reserve_remaining >= 0 AND reserve_capacity > 0),
                CONSTRAINT region_resource_sites_quality_check CHECK (quality_percent BETWEEN 1 AND 200)
            );

            CREATE INDEX IF NOT EXISTS ix_region_resource_sites_region
                ON world.region_resource_sites (region_id);

            CREATE INDEX IF NOT EXISTS ix_region_resource_sites_country
                ON world.region_resource_sites (country_id);

            CREATE TABLE IF NOT EXISTS world.resource_site_depletion_events (
                idempotency_key text PRIMARY KEY,
                site_id text NOT NULL REFERENCES world.region_resource_sites(site_id) ON DELETE CASCADE,
                amount integer NOT NULL,
                reason text NOT NULL,
                created_at timestamptz NOT NULL,
                CONSTRAINT resource_site_depletion_amount_check CHECK (amount > 0)
            );
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task SeedResourceSitesAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await using var regions = new NpgsqlCommand("""
            SELECT region_id, country_id, name, terrain, resource_focus, population, infrastructure
            FROM world.regions
            ORDER BY country_id, region_id;
            """, connection, transaction);

        var templates = new List<ResourceSiteSeed>();
        await using (var reader = await regions.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                var regionId = reader.GetString(0);
                var countryId = reader.GetString(1);
                var regionName = reader.GetString(2);
                var terrain = reader.GetString(3);
                var focus = reader.GetString(4);
                var population = reader.GetInt32(5);
                var infrastructure = reader.GetInt32(6);
                var resource = ResourceForFocus(focus);
                var baseYield = Math.Max(4, (int)Math.Ceiling(infrastructure / 8m));
                var reserveCapacity = Math.Max(5_000, (population / 10) + (infrastructure * 120));
                var quality = Math.Clamp(70 + (infrastructure / 3), 80, 125);

                templates.Add(new ResourceSiteSeed(
                    SiteId: $"{regionId}-{resource.ItemId}-site",
                    RegionId: regionId,
                    CountryId: countryId,
                    ResourceId: resource.ResourceId,
                    ResourceName: resource.ResourceName,
                    ItemId: resource.ItemId,
                    ItemName: resource.ItemName,
                    ItemCategory: resource.ItemCategory,
                    SiteName: $"{regionName} {resource.SiteSuffix}",
                    Terrain: terrain,
                    BaseYield: baseYield,
                    ExtractionSeconds: 45,
                    ReserveCapacity: reserveCapacity,
                    DepletionPerRun: baseYield,
                    QualityPercent: quality));
            }
        }

        foreach (var template in templates)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO world.region_resource_sites (
                    site_id, region_id, country_id, resource_id, resource_name,
                    item_id, item_name, item_category, site_name, terrain,
                    base_yield, extraction_seconds, reserve_remaining, reserve_capacity,
                    depletion_per_run, quality_percent, extraction_count, created_at, updated_at
                )
                VALUES (
                    @site_id, @region_id, @country_id, @resource_id, @resource_name,
                    @item_id, @item_name, @item_category, @site_name, @terrain,
                    @base_yield, @extraction_seconds, @reserve_capacity, @reserve_capacity,
                    @depletion_per_run, @quality_percent, 0, @created_at, @updated_at
                )
                ON CONFLICT (site_id) DO UPDATE
                SET country_id = EXCLUDED.country_id,
                    resource_id = EXCLUDED.resource_id,
                    resource_name = EXCLUDED.resource_name,
                    item_id = EXCLUDED.item_id,
                    item_name = EXCLUDED.item_name,
                    item_category = EXCLUDED.item_category,
                    site_name = EXCLUDED.site_name,
                    terrain = EXCLUDED.terrain,
                    base_yield = EXCLUDED.base_yield,
                    extraction_seconds = EXCLUDED.extraction_seconds,
                    reserve_capacity = GREATEST(world.region_resource_sites.reserve_capacity, EXCLUDED.reserve_capacity),
                    reserve_remaining = LEAST(
                        GREATEST(world.region_resource_sites.reserve_remaining, 0),
                        GREATEST(world.region_resource_sites.reserve_capacity, EXCLUDED.reserve_capacity)
                    ),
                    depletion_per_run = EXCLUDED.depletion_per_run,
                    quality_percent = EXCLUDED.quality_percent,
                    updated_at = EXCLUDED.updated_at;
                """, connection, transaction);
            command.Parameters.AddWithValue("site_id", template.SiteId);
            command.Parameters.AddWithValue("region_id", template.RegionId);
            command.Parameters.AddWithValue("country_id", template.CountryId);
            command.Parameters.AddWithValue("resource_id", template.ResourceId);
            command.Parameters.AddWithValue("resource_name", template.ResourceName);
            command.Parameters.AddWithValue("item_id", template.ItemId);
            command.Parameters.AddWithValue("item_name", template.ItemName);
            command.Parameters.AddWithValue("item_category", template.ItemCategory);
            command.Parameters.AddWithValue("site_name", template.SiteName);
            command.Parameters.AddWithValue("terrain", template.Terrain);
            command.Parameters.AddWithValue("base_yield", template.BaseYield);
            command.Parameters.AddWithValue("extraction_seconds", template.ExtractionSeconds);
            command.Parameters.AddWithValue("reserve_capacity", template.ReserveCapacity);
            command.Parameters.AddWithValue("depletion_per_run", template.DepletionPerRun);
            command.Parameters.AddWithValue("quality_percent", template.QualityPercent);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
    }

    public async Task<ResourceSiteListResponse> ListResourceSitesAsync(string? countryId, string? regionId)
    {
        var normalizedCountryId = string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId);
        var normalizedRegionId = string.IsNullOrWhiteSpace(regionId) ? null : NormalizeId(regionId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT site_id, region_id, country_id, resource_id, resource_name,
                   item_id, item_name, item_category, site_name, terrain,
                   base_yield, extraction_seconds, reserve_remaining, reserve_capacity,
                   depletion_per_run, quality_percent, extraction_count, updated_at
            FROM world.region_resource_sites
            WHERE (@country_id::text IS NULL OR country_id = @country_id)
              AND (@region_id::text IS NULL OR region_id = @region_id)
            ORDER BY country_id, region_id, site_name;
            """, connection);
        command.Parameters.AddWithValue("country_id", normalizedCountryId is null ? DBNull.Value : normalizedCountryId);
        command.Parameters.AddWithValue("region_id", normalizedRegionId is null ? DBNull.Value : normalizedRegionId);

        var sites = new List<ResourceSiteDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            sites.Add(ReadResourceSite(reader));
        }

        return new ResourceSiteListResponse(sites.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<ResourceSiteDto?> GetResourceSiteAsync(string siteId)
    {
        var normalizedSiteId = NormalizeId(siteId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        return await ReadResourceSiteAsync(connection, null, normalizedSiteId);
    }

    public async Task<WorldStoreResult<ResourceSiteMutationResponse>> DepleteResourceSiteAsync(
        string siteId,
        ResourceSiteDepletionRequest request)
    {
        var normalizedSiteId = NormalizeId(siteId);
        var idempotencyKey = NormalizeId(request.IdempotencyKey ?? string.Empty);
        var amount = request.Amount;
        if (string.IsNullOrWhiteSpace(normalizedSiteId) ||
            string.IsNullOrWhiteSpace(idempotencyKey) ||
            amount <= 0)
        {
            return WorldStoreResult<ResourceSiteMutationResponse>.BadRequest(
                "Site id, amount, and idempotency key are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var existingSiteId = await ReadDepletionEventSiteAsync(connection, transaction, idempotencyKey);
        if (existingSiteId is not null)
        {
            var site = await ReadResourceSiteAsync(connection, transaction, existingSiteId);
            await transaction.CommitAsync();
            return site is null
                ? WorldStoreResult<ResourceSiteMutationResponse>.NotFound("Resource site was not found.")
                : WorldStoreResult<ResourceSiteMutationResponse>.Ok(new ResourceSiteMutationResponse(
                    Completed: true,
                    Message: "Resource depletion was already recorded.",
                    Site: site,
                    UpdatedAt: DateTimeOffset.UtcNow));
        }

        var current = await ReadResourceSiteForUpdateAsync(connection, transaction, normalizedSiteId);
        if (current is null)
        {
            await transaction.RollbackAsync();
            return WorldStoreResult<ResourceSiteMutationResponse>.NotFound("Resource site was not found.");
        }

        if (current.ReserveRemaining < amount)
        {
            await transaction.RollbackAsync();
            return WorldStoreResult<ResourceSiteMutationResponse>.Conflict(
                $"{current.SiteName} only has {current.ReserveRemaining} reserve remaining.");
        }

        await using (var update = new NpgsqlCommand("""
            UPDATE world.region_resource_sites
            SET reserve_remaining = reserve_remaining - @amount,
                extraction_count = extraction_count + 1,
                updated_at = @updated_at
            WHERE site_id = @site_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("site_id", normalizedSiteId);
            update.Parameters.AddWithValue("amount", amount);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await using (var insertEvent = new NpgsqlCommand("""
            INSERT INTO world.resource_site_depletion_events (
                idempotency_key, site_id, amount, reason, created_at
            )
            VALUES (@idempotency_key, @site_id, @amount, @reason, @created_at);
            """, connection, transaction))
        {
            insertEvent.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            insertEvent.Parameters.AddWithValue("site_id", normalizedSiteId);
            insertEvent.Parameters.AddWithValue("amount", amount);
            insertEvent.Parameters.AddWithValue("reason", string.IsNullOrWhiteSpace(request.Reason)
                ? "Resource extraction claimed."
                : request.Reason.Trim());
            insertEvent.Parameters.AddWithValue("created_at", now);
            await insertEvent.ExecuteNonQueryAsync();
        }

        var updated = await ReadResourceSiteAsync(connection, transaction, normalizedSiteId)
            ?? throw new InvalidOperationException("Updated resource site was not found.");
        await transaction.CommitAsync();

        return WorldStoreResult<ResourceSiteMutationResponse>.Ok(new ResourceSiteMutationResponse(
            Completed: true,
            Message: $"Depleted {amount} {updated.ItemName} reserve from {updated.SiteName}.",
            Site: updated,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    private static async Task<string?> ReadDepletionEventSiteAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT site_id
            FROM world.resource_site_depletion_events
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        return await command.ExecuteScalarAsync() as string;
    }

    private static async Task<ResourceSiteDto?> ReadResourceSiteForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string siteId)
    {
        await using var command = ResourceSiteSelectCommand(connection, transaction, "WHERE site_id = @site_id FOR UPDATE");
        command.Parameters.AddWithValue("site_id", siteId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadResourceSite(reader) : null;
    }

    private static async Task<ResourceSiteDto?> ReadResourceSiteAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string siteId)
    {
        await using var command = ResourceSiteSelectCommand(connection, transaction, "WHERE site_id = @site_id");
        command.Parameters.AddWithValue("site_id", siteId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadResourceSite(reader) : null;
    }

    private static NpgsqlCommand ResourceSiteSelectCommand(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string whereClause)
    {
        return new NpgsqlCommand($"""
            SELECT site_id, region_id, country_id, resource_id, resource_name,
                   item_id, item_name, item_category, site_name, terrain,
                   base_yield, extraction_seconds, reserve_remaining, reserve_capacity,
                   depletion_per_run, quality_percent, extraction_count, updated_at
            FROM world.region_resource_sites
            {whereClause};
            """, connection, transaction);
    }

    private static ResourceSiteDto ReadResourceSite(NpgsqlDataReader reader)
    {
        var reserveRemaining = reader.GetInt32(12);
        var reserveCapacity = reader.GetInt32(13);
        return new ResourceSiteDto(
            SiteId: reader.GetString(0),
            RegionId: reader.GetString(1),
            CountryId: reader.GetString(2),
            ResourceId: reader.GetString(3),
            ResourceName: reader.GetString(4),
            ItemId: reader.GetString(5),
            ItemName: reader.GetString(6),
            ItemCategory: reader.GetString(7),
            SiteName: reader.GetString(8),
            Terrain: reader.GetString(9),
            BaseYield: reader.GetInt32(10),
            ExtractionSeconds: reader.GetInt32(11),
            ReserveRemaining: reserveRemaining,
            ReserveCapacity: reserveCapacity,
            DepletionPerRun: reader.GetInt32(14),
            QualityPercent: reader.GetInt32(15),
            ExtractionCount: reader.GetInt32(16),
            IsDepleted: reserveRemaining <= 0,
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(17));
    }

    private static ResourceFocusMapping ResourceForFocus(string focus)
    {
        var normalized = focus.Trim().ToLowerInvariant();
        return normalized switch
        {
            "grain" or "food" => new ResourceFocusMapping("grain", "Grain", "grain", "Grain", "Raw material", "Granaries"),
            "iron" or "steel" => new ResourceFocusMapping("iron", "Iron Ore", "iron", "Iron", "Raw material", "Mines"),
            "timber" => new ResourceFocusMapping("timber", "Timber", "timber", "Timber", "Raw material", "Timberlands"),
            "shipping" or "trade" or "caravans" => new ResourceFocusMapping("oil", "Fuel", "oil", "Oil", "Raw material", "Fuel Depots"),
            "finance" => new ResourceFocusMapping("gold-ore", "Gold Ore", "gold_ore", "Gold Ore", "Raw material", "Survey Fields"),
            _ => new ResourceFocusMapping("coal", "Coal", "coal", "Coal", "Raw material", "Pits")
        };
    }
}

internal sealed record ResourceSiteListResponse(ResourceSiteDto[] Sites, DateTimeOffset UpdatedAt);

internal sealed record ResourceSiteDto(
    string SiteId,
    string RegionId,
    string CountryId,
    string ResourceId,
    string ResourceName,
    string ItemId,
    string ItemName,
    string ItemCategory,
    string SiteName,
    string Terrain,
    int BaseYield,
    int ExtractionSeconds,
    int ReserveRemaining,
    int ReserveCapacity,
    int DepletionPerRun,
    int QualityPercent,
    int ExtractionCount,
    bool IsDepleted,
    DateTimeOffset UpdatedAt);

internal sealed record ResourceSiteDepletionRequest(int Amount, string? Reason, string? IdempotencyKey);

internal sealed record ResourceSiteMutationResponse(
    bool Completed,
    string Message,
    ResourceSiteDto Site,
    DateTimeOffset UpdatedAt);

internal sealed record ResourceSiteSeed(
    string SiteId,
    string RegionId,
    string CountryId,
    string ResourceId,
    string ResourceName,
    string ItemId,
    string ItemName,
    string ItemCategory,
    string SiteName,
    string Terrain,
    int BaseYield,
    int ExtractionSeconds,
    int ReserveCapacity,
    int DepletionPerRun,
    int QualityPercent);

internal sealed record ResourceFocusMapping(
    string ResourceId,
    string ResourceName,
    string ItemId,
    string ItemName,
    string ItemCategory,
    string SiteSuffix);

internal sealed record WorldStoreResult<T>(T? Value, string? Message, int StatusCode) where T : class
{
    public static WorldStoreResult<T> Ok(T value)
    {
        return new WorldStoreResult<T>(value, null, StatusCodes.Status200OK);
    }

    public static WorldStoreResult<T> NotFound(string message)
    {
        return new WorldStoreResult<T>(null, message, StatusCodes.Status404NotFound);
    }

    public static WorldStoreResult<T> BadRequest(string message)
    {
        return new WorldStoreResult<T>(null, message, StatusCodes.Status400BadRequest);
    }

    public static WorldStoreResult<T> Conflict(string message)
    {
        return new WorldStoreResult<T>(null, message, StatusCodes.Status409Conflict);
    }
}

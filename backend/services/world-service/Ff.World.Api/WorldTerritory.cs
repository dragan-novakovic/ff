using Npgsql;

internal static class TerritoryEndpoints
{
    public static void MapTerritoryEndpoints(this WebApplication app)
    {
        app.MapGet("/territory/map", async (
            string? countryId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var token = tokens.Validate(request.Headers.Authorization.ToString());
            if (!token.IsValid)
            {
                return Results.Json(
                    new ErrorResponse("A valid bearer token is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return Results.Ok(await world.GetTerritoryMapAsync(countryId, token.PlayerId));
        }).WithName("GetTerritoryMap");

        app.MapGet("/territory/regions/{regionId}", async (
            string regionId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var token = tokens.Validate(request.Headers.Authorization.ToString());
            if (!token.IsValid)
            {
                return Results.Json(
                    new ErrorResponse("A valid bearer token is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var region = await world.GetTerritoryRegionAsync(regionId, token.PlayerId);
            return region is null
                ? Results.NotFound(new ErrorResponse("Region was not found."))
                : Results.Ok(region);
        }).WithName("GetTerritoryRegion");

        app.MapGet("/territory/regions/{regionId}/history", async (
            string regionId,
            int? limit,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var history = await world.GetRegionControlHistoryAsync(regionId, limit);
            return history is null
                ? Results.NotFound(new ErrorResponse("Region was not found."))
                : Results.Ok(history);
        }).WithName("GetRegionControlHistory");

        app.MapGet("/territory/regions/{regionId}/bonuses", async (
            string regionId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var bonus = await world.GetRegionBonusAsync(regionId);
            return bonus is null
                ? Results.NotFound(new ErrorResponse("Region was not found."))
                : Results.Ok(bonus);
        }).WithName("GetRegionBonuses");

        app.MapGet("/territory/regions/{regionId}/defense", async (
            string regionId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var defense = await world.GetRegionDefenseAsync(regionId);
            return defense is null
                ? Results.NotFound(new ErrorResponse("Region was not found."))
                : Results.Ok(defense);
        }).WithName("GetRegionDefense");

        app.MapPost("/players/{playerId}/territory/conquests", async (
            string playerId,
            TerritoryBattleStartRequest startRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(startRequest.RegionId))
            {
                return Results.BadRequest(new ErrorResponse("Region is required."));
            }

            var battleType = NormalizeBattleType(startRequest.BattleType);
            if (battleType is null)
            {
                return Results.BadRequest(new ErrorResponse("Battle type must be conquest or resistance."));
            }

            var result = await world.StartTerritoryBattleAsync(
                access.PlayerId!,
                startRequest with { BattleType = battleType });
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Region was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("StartTerritoryBattle");

        app.MapPost("/players/{playerId}/territory/battles/{battleId}/resolve", async (
            string playerId,
            string battleId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.ResolveRegionBattleAsync(access.PlayerId!, battleId);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Battle was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("ResolveTerritoryBattle");
    }

    private static IResult? ValidateBearer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? null
            : Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized);
    }

    private static PlayerAccessResult ValidatePlayerAccess(
        string playerId,
        HttpRequest request,
        DevTokenValidator tokens)
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
                new ErrorResponse("You cannot manage another player's territory actions."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string? NormalizeBattleType(string? battleType)
    {
        var normalized = string.IsNullOrWhiteSpace(battleType)
            ? "conquest"
            : battleType.Trim().ToLowerInvariant().Replace('-', '_');
        return normalized is "conquest" or "resistance" ? normalized : null;
    }
}

internal sealed partial class WorldStore
{
    private const int TerritoryHistoryLimit = 5;

    public async Task InitializeTerritorySchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.region_resource_bonuses (
                region_id text PRIMARY KEY REFERENCES world.regions(region_id) ON DELETE CASCADE,
                resource_type text NOT NULL,
                production_bonus_percent integer NOT NULL,
                market_bonus_percent integer NOT NULL,
                defense_bonus_percent integer NOT NULL,
                hospital_capacity integer NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS world.region_resources (
                region_id text NOT NULL REFERENCES world.regions(region_id) ON DELETE CASCADE,
                resource_id text NOT NULL,
                item_id text NOT NULL,
                name text NOT NULL,
                category text NOT NULL,
                abundance_percent integer NOT NULL,
                production_bonus_percent integer NOT NULL,
                market_bonus_percent integer NOT NULL,
                description text NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (region_id, resource_id),
                CONSTRAINT region_resource_abundance_check CHECK (abundance_percent >= 0 AND abundance_percent <= 100)
            );

            CREATE INDEX IF NOT EXISTS ix_world_region_resources_item
                ON world.region_resources (item_id, production_bonus_percent DESC);

            CREATE TABLE IF NOT EXISTS world.region_defense_systems (
                region_id text PRIMARY KEY REFERENCES world.regions(region_id) ON DELETE CASCADE,
                defense_level integer NOT NULL,
                hospital_level integer NOT NULL,
                garrison_strength integer NOT NULL,
                resistance integer NOT NULL,
                fortification_health integer NOT NULL DEFAULT 0,
                hospital_energy_per_day integer NOT NULL DEFAULT 0,
                hospital_supplies integer NOT NULL DEFAULT 0,
                updated_at timestamptz NOT NULL,
                CONSTRAINT region_defense_level_check CHECK (defense_level >= 0 AND defense_level <= 10),
                CONSTRAINT region_hospital_level_check CHECK (hospital_level >= 0 AND hospital_level <= 10),
                CONSTRAINT region_resistance_check CHECK (resistance >= 0 AND resistance <= 100)
            );

            ALTER TABLE world.region_defense_systems
                ADD COLUMN IF NOT EXISTS fortification_health integer NOT NULL DEFAULT 0;

            ALTER TABLE world.region_defense_systems
                ADD COLUMN IF NOT EXISTS hospital_energy_per_day integer NOT NULL DEFAULT 0;

            ALTER TABLE world.region_defense_systems
                ADD COLUMN IF NOT EXISTS hospital_supplies integer NOT NULL DEFAULT 0;

            CREATE TABLE IF NOT EXISTS world.region_control_history (
                history_id text PRIMARY KEY,
                region_id text NOT NULL REFERENCES world.regions(region_id) ON DELETE CASCADE,
                previous_country_id text NULL REFERENCES world.countries(country_id) ON DELETE SET NULL,
                new_country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                battle_id text NULL REFERENCES world.battles(battle_id) ON DELETE SET NULL,
                changed_by_player_id text NOT NULL,
                reason text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_region_control_history_region_created
                ON world.region_control_history (region_id, created_at DESC);

            ALTER TABLE world.battles
                ADD COLUMN IF NOT EXISTS battle_type text NOT NULL DEFAULT 'skirmish';

            ALTER TABLE world.battles
                ADD COLUMN IF NOT EXISTS initiator_player_id text NOT NULL DEFAULT 'system';

            ALTER TABLE world.battles
                ADD COLUMN IF NOT EXISTS resolution_reason text NOT NULL DEFAULT '';

            CREATE INDEX IF NOT EXISTS ix_world_battles_region_status
                ON world.battles (region_id, status, ends_at);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task SeedTerritoryAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        foreach (var country in WorldCatalog.Countries)
        {
            foreach (var region in country.Regions)
            {
                var bonus = BuildRegionBonusSeed(region);
                await using (var bonusCommand = new NpgsqlCommand("""
                    INSERT INTO world.region_resource_bonuses (
                        region_id, resource_type, production_bonus_percent,
                        market_bonus_percent, defense_bonus_percent,
                        hospital_capacity, updated_at
                    )
                    VALUES (
                        @region_id, @resource_type, @production_bonus_percent,
                        @market_bonus_percent, @defense_bonus_percent,
                        @hospital_capacity, @updated_at
                    )
                    ON CONFLICT (region_id) DO UPDATE
                    SET resource_type = EXCLUDED.resource_type,
                        production_bonus_percent = EXCLUDED.production_bonus_percent,
                        market_bonus_percent = EXCLUDED.market_bonus_percent,
                        defense_bonus_percent = EXCLUDED.defense_bonus_percent,
                        hospital_capacity = EXCLUDED.hospital_capacity,
                        updated_at = EXCLUDED.updated_at;
                    """, connection, transaction))
                {
                    bonusCommand.Parameters.AddWithValue("region_id", region.RegionId);
                    bonusCommand.Parameters.AddWithValue("resource_type", bonus.ResourceType);
                    bonusCommand.Parameters.AddWithValue("production_bonus_percent", bonus.ProductionBonusPercent);
                    bonusCommand.Parameters.AddWithValue("market_bonus_percent", bonus.MarketBonusPercent);
                    bonusCommand.Parameters.AddWithValue("defense_bonus_percent", bonus.DefenseBonusPercent);
                    bonusCommand.Parameters.AddWithValue("hospital_capacity", bonus.HospitalCapacity);
                    bonusCommand.Parameters.AddWithValue("updated_at", now);
                    await bonusCommand.ExecuteNonQueryAsync();
                }

                foreach (var resource in BuildRegionResourceSeeds(region))
                {
                    await using var resourceCommand = new NpgsqlCommand("""
                        INSERT INTO world.region_resources (
                            region_id, resource_id, item_id, name, category, abundance_percent,
                            production_bonus_percent, market_bonus_percent, description, updated_at
                        )
                        VALUES (
                            @region_id, @resource_id, @item_id, @name, @category, @abundance_percent,
                            @production_bonus_percent, @market_bonus_percent, @description, @updated_at
                        )
                        ON CONFLICT (region_id, resource_id) DO UPDATE
                        SET item_id = EXCLUDED.item_id,
                            name = EXCLUDED.name,
                            category = EXCLUDED.category,
                            abundance_percent = EXCLUDED.abundance_percent,
                            production_bonus_percent = EXCLUDED.production_bonus_percent,
                            market_bonus_percent = EXCLUDED.market_bonus_percent,
                            description = EXCLUDED.description,
                            updated_at = EXCLUDED.updated_at;
                        """, connection, transaction);
                    resourceCommand.Parameters.AddWithValue("region_id", region.RegionId);
                    resourceCommand.Parameters.AddWithValue("resource_id", resource.ResourceId);
                    resourceCommand.Parameters.AddWithValue("item_id", resource.ItemId);
                    resourceCommand.Parameters.AddWithValue("name", resource.Name);
                    resourceCommand.Parameters.AddWithValue("category", resource.Category);
                    resourceCommand.Parameters.AddWithValue("abundance_percent", resource.AbundancePercent);
                    resourceCommand.Parameters.AddWithValue("production_bonus_percent", resource.ProductionBonusPercent);
                    resourceCommand.Parameters.AddWithValue("market_bonus_percent", resource.MarketBonusPercent);
                    resourceCommand.Parameters.AddWithValue("description", resource.Description);
                    resourceCommand.Parameters.AddWithValue("updated_at", now);
                    await resourceCommand.ExecuteNonQueryAsync();
                }

                var defense = BuildRegionDefenseSeed(region, bonus);
                await using (var defenseCommand = new NpgsqlCommand("""
                    INSERT INTO world.region_defense_systems (
                        region_id, defense_level, hospital_level,
                        garrison_strength, resistance, fortification_health,
                        hospital_energy_per_day, hospital_supplies, updated_at
                    )
                    VALUES (
                        @region_id, @defense_level, @hospital_level,
                        @garrison_strength, @resistance, @fortification_health,
                        @hospital_energy_per_day, @hospital_supplies, @updated_at
                    )
                    ON CONFLICT (region_id) DO UPDATE
                    SET fortification_health = CASE
                            WHEN world.region_defense_systems.fortification_health <= 0 THEN EXCLUDED.fortification_health
                            ELSE world.region_defense_systems.fortification_health
                        END,
                        hospital_energy_per_day = CASE
                            WHEN world.region_defense_systems.hospital_energy_per_day <= 0 THEN EXCLUDED.hospital_energy_per_day
                            ELSE world.region_defense_systems.hospital_energy_per_day
                        END,
                        hospital_supplies = CASE
                            WHEN world.region_defense_systems.hospital_supplies <= 0 THEN EXCLUDED.hospital_supplies
                            ELSE world.region_defense_systems.hospital_supplies
                        END,
                        updated_at = EXCLUDED.updated_at;
                    """, connection, transaction))
                {
                    defenseCommand.Parameters.AddWithValue("region_id", region.RegionId);
                    defenseCommand.Parameters.AddWithValue("defense_level", defense.DefenseLevel);
                    defenseCommand.Parameters.AddWithValue("hospital_level", defense.HospitalLevel);
                    defenseCommand.Parameters.AddWithValue("garrison_strength", defense.GarrisonStrength);
                    defenseCommand.Parameters.AddWithValue("resistance", 0);
                    defenseCommand.Parameters.AddWithValue("fortification_health", defense.FortificationHealth);
                    defenseCommand.Parameters.AddWithValue("hospital_energy_per_day", defense.HospitalEnergyPerDay);
                    defenseCommand.Parameters.AddWithValue("hospital_supplies", defense.HospitalSupplies);
                    defenseCommand.Parameters.AddWithValue("updated_at", now);
                    await defenseCommand.ExecuteNonQueryAsync();
                }

                await using var historyCommand = new NpgsqlCommand("""
                    INSERT INTO world.region_control_history (
                        history_id, region_id, previous_country_id, new_country_id,
                        battle_id, changed_by_player_id, reason, created_at
                    )
                    VALUES (
                        @history_id, @region_id, NULL, @new_country_id,
                        NULL, 'system', 'Initial world catalog ownership.', @created_at
                    )
                    ON CONFLICT (history_id) DO NOTHING;
                    """, connection, transaction);
                historyCommand.Parameters.AddWithValue("history_id", $"history-{region.RegionId}-initial");
                historyCommand.Parameters.AddWithValue("region_id", region.RegionId);
                historyCommand.Parameters.AddWithValue("new_country_id", country.CountryId);
                historyCommand.Parameters.AddWithValue("created_at", now);
                await historyCommand.ExecuteNonQueryAsync();
            }
        }

        await transaction.CommitAsync();
    }

    public async Task<TerritoryMapResponse> GetTerritoryMapAsync(string? countryId, string? viewerPlayerId)
    {
        await ResolveDueBattlesAsync();

        await using var connection = await _dataSource.OpenConnectionAsync();
        var regions = await ReadTerritoryRegionsAsync(
            connection,
            null,
            string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId),
            string.IsNullOrWhiteSpace(viewerPlayerId) ? null : NormalizePlayerId(viewerPlayerId),
            includeHistory: true);
        return new TerritoryMapResponse(regions.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<TerritoryRegionDto?> GetTerritoryRegionAsync(string regionId, string? viewerPlayerId)
    {
        await ResolveDueBattlesAsync();

        await using var connection = await _dataSource.OpenConnectionAsync();
        return await ReadTerritoryRegionAsync(
            connection,
            null,
            NormalizeId(regionId),
            string.IsNullOrWhiteSpace(viewerPlayerId) ? null : NormalizePlayerId(viewerPlayerId),
            includeHistory: true);
    }

    public async Task<RegionControlHistoryResponse?> GetRegionControlHistoryAsync(string regionId, int? limit)
    {
        var normalizedRegionId = NormalizeId(regionId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (!await RegionExistsAsync(connection, null, normalizedRegionId))
        {
            return null;
        }

        var history = await ReadRegionControlHistoryAsync(
            connection,
            null,
            normalizedRegionId,
            Math.Clamp(limit ?? 25, 1, 100));
        return new RegionControlHistoryResponse(normalizedRegionId, history.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<RegionResourceBonusDto?> GetRegionBonusAsync(string regionId)
    {
        var normalizedRegionId = NormalizeId(regionId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (!await RegionExistsAsync(connection, null, normalizedRegionId))
        {
            return null;
        }

        return await ReadRegionBonusAsync(connection, null, normalizedRegionId);
    }

    public async Task<RegionDefenseSystemDto?> GetRegionDefenseAsync(string regionId)
    {
        var normalizedRegionId = NormalizeId(regionId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (!await RegionExistsAsync(connection, null, normalizedRegionId))
        {
            return null;
        }

        return await ReadRegionDefenseAsync(connection, null, normalizedRegionId);
    }

    public async Task<TerritoryBattleMutationResult?> StartTerritoryBattleAsync(
        string playerId,
        TerritoryBattleStartRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedRegionId = NormalizeId(request.RegionId!);
        var battleType = request.BattleType ?? "conquest";
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var region = await ReadTerritoryRegionBaseAsync(connection, transaction, normalizedRegionId, forUpdate: true);
        if (region is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null || !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                normalizedRegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            return TerritoryBattleMutationResult.Failed(
                "Join a country before starting a territory war.",
                StatusCodes.Status409Conflict,
                null,
                currentRegion);
        }

        if (string.Equals(citizenship.CountryId, region.OwnerCountryId, StringComparison.Ordinal))
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                normalizedRegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            return TerritoryBattleMutationResult.Failed(
                $"{region.OwnerCountryName} already controls {region.Name}.",
                StatusCodes.Status409Conflict,
                null,
                currentRegion);
        }

        var diplomaticWarBlock = await ReadActiveDiplomaticWarBlockAsync(
            connection,
            transaction,
            citizenship.CountryId,
            region.OwnerCountryId);
        if (diplomaticWarBlock is not null)
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                normalizedRegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            var expiresText = diplomaticWarBlock.ExpiresAt is null
                ? string.Empty
                : $" until {diplomaticWarBlock.ExpiresAt:O}";
            return TerritoryBattleMutationResult.Failed(
                $"A {diplomaticWarBlock.TreatyType.Replace('_', ' ')} treaty blocks war between these countries{expiresText}.",
                StatusCodes.Status409Conflict,
                null,
                currentRegion);
        }

        var authorization = await DetermineCongressAuthorizationAsync(
            connection,
            transaction,
            citizenship.CountryId,
            normalizedPlayerId);
        if (!authorization.CanCreateProposal)
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                normalizedRegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            return TerritoryBattleMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                null,
                currentRegion);
        }

        var activeBattle = await ReadActiveRegionBattleAsync(connection, transaction, normalizedRegionId);
        if (activeBattle is not null)
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                normalizedRegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            return TerritoryBattleMutationResult.Failed(
                $"{region.Name} already has an active battle.",
                StatusCodes.Status409Conflict,
                activeBattle,
                currentRegion);
        }

        var defense = await ReadRegionDefenseAsync(connection, transaction, normalizedRegionId);
        var bonus = await ReadRegionBonusAsync(connection, transaction, normalizedRegionId);
        var battleId = $"battle-{battleType}-{normalizedRegionId}-{now:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N")[..8]}";
        var targetScore = Math.Clamp(
            350 + (region.Infrastructure * 4) + (region.Population / 1_000) +
                ((defense?.DefenseLevel ?? 0) * 80) +
                ((defense?.EffectiveDefensePercent ?? bonus?.DefenseBonusPercent ?? 0) * 8) +
                ((defense?.FortificationHealth ?? 0) * 3),
            400,
            2_000);
        var defenderStrength = Math.Clamp(
            8 + ((defense?.DefenseLevel ?? 0) * 3) +
                ((defense?.GarrisonStrength ?? 0) / 100) +
                ((defense?.FortificationHealth ?? 0) / 20),
            8,
            60);
        var description = battleType == "resistance"
            ? $"{citizenship.CountryName} citizens opened a resistance war to reclaim {region.Name} from {region.OwnerCountryName}."
            : $"{citizenship.CountryName} opened a conquest battle to take control of {region.Name} from {region.OwnerCountryName}.";
        var campaignId = await CreateCampaignForTerritoryBattleAsync(
            connection,
            transaction,
            citizenship.CountryId,
            region.Name,
            battleType,
            normalizedPlayerId,
            targetScore,
            now);

        await InsertTerritoryBattleAsync(
            connection,
            transaction,
            battleId,
            campaignId,
            normalizedRegionId,
            citizenship.CountryId,
            region.OwnerCountryId,
            battleType,
            normalizedPlayerId,
            battleType == "resistance"
                ? $"{region.Name} Resistance War"
                : $"Conquest of {region.Name}",
            description,
            targetScore,
            defenderStrength,
            now);
        await AttachBattleToCampaignAsync(connection, transaction, campaignId, battleId, now);
        await EnsureBattlePhaseAsync(
            connection,
            transaction,
            campaignId,
            battleId,
            1,
            "Opening front",
            $"Reach {targetScore} total damage to decide control of {region.Name}.",
            targetScore,
            0,
            0,
            "active",
            now,
            null,
            now);

        var battle = await ReadBattleAsync(connection, transaction, battleId);
        var territoryRegion = await ReadTerritoryRegionAsync(
            connection,
            transaction,
            normalizedRegionId,
            normalizedPlayerId,
            includeHistory: true);
        await transaction.CommitAsync();

        return new TerritoryBattleMutationResult(
            Completed: true,
            Message: $"{battle!.Name} has started.",
            StatusCode: StatusCodes.Status200OK,
            Battle: battle,
            Region: territoryRegion,
            UpdatedAt: now);
    }

    public async Task<TerritoryBattleMutationResult?> ResolveRegionBattleAsync(string playerId, string battleId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedBattleId = NormalizeId(battleId);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var battle = await ReadBattleAsync(connection, transaction, normalizedBattleId, forUpdate: true);
        if (battle is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        var isParticipant = citizenship is not null &&
            (string.Equals(citizenship.CountryId, battle.AttackerCountryId, StringComparison.Ordinal) ||
             string.Equals(citizenship.CountryId, battle.DefenderCountryId, StringComparison.Ordinal));
        if (!isParticipant)
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                battle.RegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            return TerritoryBattleMutationResult.Failed(
                "Only citizens of a battle country can resolve a territory battle.",
                StatusCodes.Status403Forbidden,
                battle,
                currentRegion);
        }

        if (!string.Equals(battle.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                battle.RegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            return new TerritoryBattleMutationResult(
                Completed: true,
                Message: "Battle was already resolved.",
                StatusCode: StatusCodes.Status200OK,
                Battle: battle,
                Region: currentRegion,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        var reachedTarget = battle.AttackerScore >= battle.TargetScore || battle.DefenderScore >= battle.TargetScore;
        if (battle.EndsAt > now && !reachedTarget)
        {
            var currentRegion = await ReadTerritoryRegionAsync(
                connection,
                transaction,
                battle.RegionId,
                normalizedPlayerId,
                includeHistory: true);
            await transaction.CommitAsync();
            return TerritoryBattleMutationResult.Failed(
                "Battle has not reached its score target or end time yet.",
                StatusCodes.Status409Conflict,
                battle,
                currentRegion);
        }

        battle = await ResolveBattleIfNeededAsync(connection, transaction, battle.BattleId, now, normalizedPlayerId)
            ?? await ReadBattleAsync(connection, transaction, battle.BattleId)
            ?? battle;
        var region = await ReadTerritoryRegionAsync(connection, transaction, battle.RegionId, normalizedPlayerId, true);
        await transaction.CommitAsync();

        return new TerritoryBattleMutationResult(
            Completed: true,
            Message: $"Battle resolved. {battle.WinnerCountryName ?? battle.WinnerCountryId ?? "The winner"} controls {battle.RegionName}.",
            StatusCode: StatusCodes.Status200OK,
            Battle: battle,
            Region: region,
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    private static async Task ApplyRegionOwnershipChangeAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        CountryBattleDto battle,
        string winnerCountryId,
        string changedByPlayerId,
        string reason,
        DateTimeOffset now)
    {
        string? previousCountryId;
        await using (var ownerCommand = new NpgsqlCommand("""
            SELECT country_id
            FROM world.regions
            WHERE region_id = @region_id
            FOR UPDATE;
            """, connection, transaction))
        {
            ownerCommand.Parameters.AddWithValue("region_id", battle.RegionId);
            previousCountryId = await ownerCommand.ExecuteScalarAsync() as string;
        }

        await using (var updateRegion = new NpgsqlCommand("""
            UPDATE world.regions
            SET country_id = @country_id,
                updated_at = @updated_at
            WHERE region_id = @region_id;
            """, connection, transaction))
        {
            updateRegion.Parameters.AddWithValue("country_id", winnerCountryId);
            updateRegion.Parameters.AddWithValue("region_id", battle.RegionId);
            updateRegion.Parameters.AddWithValue("updated_at", now);
            await updateRegion.ExecuteNonQueryAsync();
        }

        var changedOwner = !string.Equals(previousCountryId, winnerCountryId, StringComparison.Ordinal);
        await using (var updateDefense = new NpgsqlCommand("""
            UPDATE world.region_defense_systems
            SET defense_level = CASE
                    WHEN @changed_owner THEN GREATEST(1, defense_level - 1)
                    ELSE LEAST(10, defense_level + 1)
                END,
                garrison_strength = CASE
                    WHEN @changed_owner THEN GREATEST(50, garrison_strength / 2)
                    ELSE LEAST(1000, garrison_strength + 25)
                END,
                fortification_health = CASE
                    WHEN @changed_owner THEN GREATEST(25, fortification_health - 30)
                    ELSE LEAST(100, fortification_health + 10)
                END,
                hospital_supplies = CASE
                    WHEN @changed_owner THEN GREATEST(0, hospital_supplies - 50)
                    ELSE LEAST(5000, hospital_supplies + 25)
                END,
                resistance = CASE
                    WHEN @changed_owner THEN 50
                    ELSE GREATEST(0, resistance - 10)
                END,
                updated_at = @updated_at
            WHERE region_id = @region_id;
            """, connection, transaction))
        {
            updateDefense.Parameters.AddWithValue("region_id", battle.RegionId);
            updateDefense.Parameters.AddWithValue("changed_owner", changedOwner);
            updateDefense.Parameters.AddWithValue("updated_at", now);
            await updateDefense.ExecuteNonQueryAsync();
        }

        await using var insertHistory = new NpgsqlCommand("""
            INSERT INTO world.region_control_history (
                history_id, region_id, previous_country_id, new_country_id,
                battle_id, changed_by_player_id, reason, created_at
            )
            VALUES (
                @history_id, @region_id, @previous_country_id, @new_country_id,
                @battle_id, @changed_by_player_id, @reason, @created_at
            )
            ON CONFLICT (history_id) DO NOTHING;
            """, connection, transaction);
        insertHistory.Parameters.AddWithValue("history_id", $"history-{battle.BattleId}");
        insertHistory.Parameters.AddWithValue("region_id", battle.RegionId);
        insertHistory.Parameters.AddWithValue("previous_country_id", (object?)previousCountryId ?? DBNull.Value);
        insertHistory.Parameters.AddWithValue("new_country_id", winnerCountryId);
        insertHistory.Parameters.AddWithValue("battle_id", battle.BattleId);
        insertHistory.Parameters.AddWithValue("changed_by_player_id", changedByPlayerId);
        insertHistory.Parameters.AddWithValue("reason", reason);
        insertHistory.Parameters.AddWithValue("created_at", now);
        await insertHistory.ExecuteNonQueryAsync();
    }

    private static async Task<List<TerritoryRegionDto>> ReadTerritoryRegionsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? countryId,
        string? viewerPlayerId,
        bool includeHistory)
    {
        var sql = string.IsNullOrWhiteSpace(countryId)
            ? """
                SELECT r.region_id, r.country_id, r.name, r.terrain, r.resource_focus,
                       r.population, r.infrastructure, r.is_capital, r.updated_at,
                       c.name, c.code
                FROM world.regions r
                INNER JOIN world.countries c ON c.country_id = r.country_id
                ORDER BY c.name, r.is_capital DESC, r.name;
                """
            : """
                SELECT r.region_id, r.country_id, r.name, r.terrain, r.resource_focus,
                       r.population, r.infrastructure, r.is_capital, r.updated_at,
                       c.name, c.code
                FROM world.regions r
                INNER JOIN world.countries c ON c.country_id = r.country_id
                WHERE r.country_id = @country_id
                ORDER BY r.is_capital DESC, r.name;
                """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }

        var bases = new List<TerritoryRegionBase>();
        await using (var reader = await command.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                bases.Add(ReadTerritoryRegionBase(reader));
            }
        }

        var regions = new List<TerritoryRegionDto>();
        foreach (var region in bases)
        {
            regions.Add(await ToTerritoryRegionDtoAsync(
                connection,
                transaction,
                region,
                viewerPlayerId,
                includeHistory));
        }

        return regions;
    }

    private static async Task<TerritoryRegionDto?> ReadTerritoryRegionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId,
        string? viewerPlayerId,
        bool includeHistory)
    {
        var region = await ReadTerritoryRegionBaseAsync(connection, transaction, regionId, forUpdate: false);
        return region is null
            ? null
            : await ToTerritoryRegionDtoAsync(connection, transaction, region, viewerPlayerId, includeHistory);
    }

    private static async Task<TerritoryRegionDto> ToTerritoryRegionDtoAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        TerritoryRegionBase region,
        string? viewerPlayerId,
        bool includeHistory)
    {
        var bonus = await ReadRegionBonusAsync(connection, transaction, region.RegionId)
            ?? RegionResourceBonusDto.Empty(region.RegionId);
        var resources = await ReadRegionResourcesAsync(connection, transaction, region.RegionId);
        var defense = await ReadRegionDefenseAsync(connection, transaction, region.RegionId)
            ?? RegionDefenseSystemDto.Empty(region.RegionId);
        var activeBattle = await ReadActiveRegionBattleAsync(connection, transaction, region.RegionId);
        var history = includeHistory
            ? await ReadRegionControlHistoryAsync(connection, transaction, region.RegionId, TerritoryHistoryLimit)
            : [];
        var authorization = await DetermineTerritoryAuthorizationAsync(
            connection,
            transaction,
            region,
            activeBattle,
            viewerPlayerId);

        return new TerritoryRegionDto(
            RegionId: region.RegionId,
            Name: region.Name,
            Terrain: region.Terrain,
            ResourceFocus: region.ResourceFocus,
            Population: region.Population,
            Infrastructure: region.Infrastructure,
            IsCapital: region.IsCapital,
            OwnerCountryId: region.OwnerCountryId,
            OwnerCountryName: region.OwnerCountryName,
            OwnerCountryCode: region.OwnerCountryCode,
            Bonus: bonus,
            Resources: resources.ToArray(),
            Defense: defense,
            ActiveConflict: activeBattle,
            RecentHistory: history.ToArray(),
            Authorization: authorization,
            UpdatedAt: region.UpdatedAt);
    }

    private static async Task<TerritoryAuthorizationDto> DetermineTerritoryAuthorizationAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        TerritoryRegionBase region,
        CountryBattleDto? activeBattle,
        string? viewerPlayerId)
    {
        if (string.IsNullOrWhiteSpace(viewerPlayerId))
        {
            return new TerritoryAuthorizationDto(false, false, false, null, "Sign in to start or resolve territory battles.");
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, viewerPlayerId);
        if (citizenship is null || !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            return new TerritoryAuthorizationDto(false, false, false, null, "Join a country to start or resolve territory battles.");
        }

        if (activeBattle is not null)
        {
            var isParticipant =
                string.Equals(citizenship.CountryId, activeBattle.AttackerCountryId, StringComparison.Ordinal) ||
                string.Equals(citizenship.CountryId, activeBattle.DefenderCountryId, StringComparison.Ordinal);
            var canResolve = isParticipant &&
                (activeBattle.EndsAt <= DateTimeOffset.UtcNow ||
                 activeBattle.AttackerScore >= activeBattle.TargetScore ||
                 activeBattle.DefenderScore >= activeBattle.TargetScore);
            return new TerritoryAuthorizationDto(
                false,
                false,
                canResolve,
                isParticipant ? "battle-participant" : null,
                canResolve
                    ? "This active battle can be resolved now."
                    : "An active battle already controls this region's front line.");
        }

        var congress = await DetermineCongressAuthorizationAsync(
            connection,
            transaction,
            citizenship.CountryId,
            viewerPlayerId);
        var canAttack = !string.Equals(citizenship.CountryId, region.OwnerCountryId, StringComparison.Ordinal) &&
            congress.CanCreateProposal;
        var message = string.Equals(citizenship.CountryId, region.OwnerCountryId, StringComparison.Ordinal)
            ? $"{citizenship.CountryName} already controls this region."
            : canAttack
                ? congress.Message
                : congress.Message;
        return new TerritoryAuthorizationDto(
            CanStartConquest: canAttack,
            CanStartResistance: canAttack,
            CanResolveBattle: false,
            Role: congress.Role,
            Message: message);
    }

    private static async Task<TerritoryRegionBase?> ReadTerritoryRegionBaseAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId,
        bool forUpdate)
    {
        var sql = """
            SELECT r.region_id, r.country_id, r.name, r.terrain, r.resource_focus,
                   r.population, r.infrastructure, r.is_capital, r.updated_at,
                   c.name, c.code
            FROM world.regions r
            INNER JOIN world.countries c ON c.country_id = r.country_id
            WHERE r.region_id = @region_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE OF r";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTerritoryRegionBase(reader) : null;
    }

    private static TerritoryRegionBase ReadTerritoryRegionBase(NpgsqlDataReader reader)
    {
        return new TerritoryRegionBase(
            RegionId: reader.GetString(0),
            OwnerCountryId: reader.GetString(1),
            Name: reader.GetString(2),
            Terrain: reader.GetString(3),
            ResourceFocus: reader.GetString(4),
            Population: reader.GetInt32(5),
            Infrastructure: reader.GetInt32(6),
            IsCapital: reader.GetBoolean(7),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(8),
            OwnerCountryName: reader.GetString(9),
            OwnerCountryCode: reader.GetString(10));
    }

    private static async Task<bool> RegionExistsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM world.regions
            WHERE region_id = @region_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task<RegionResourceBonusDto?> ReadRegionBonusAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT region_id, resource_type, production_bonus_percent,
                   market_bonus_percent, defense_bonus_percent,
                   hospital_capacity,
                   GREATEST(
                       production_bonus_percent,
                       COALESCE((
                           SELECT MAX(production_bonus_percent)
                           FROM world.region_resources resources
                           WHERE resources.region_id = bonuses.region_id
                       ), 0)
                   )::integer AS effective_production_bonus_percent,
                   GREATEST(
                       market_bonus_percent,
                       COALESCE((
                           SELECT MAX(market_bonus_percent)
                           FROM world.region_resources resources
                           WHERE resources.region_id = bonuses.region_id
                       ), 0)
                   )::integer AS effective_market_bonus_percent,
                   updated_at
            FROM world.region_resource_bonuses bonuses
            WHERE bonuses.region_id = @region_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new RegionResourceBonusDto(
                RegionId: reader.GetString(0),
                ResourceType: reader.GetString(1),
                ProductionBonusPercent: reader.GetInt32(2),
                MarketBonusPercent: reader.GetInt32(3),
                DefenseBonusPercent: reader.GetInt32(4),
                HospitalCapacity: reader.GetInt32(5),
                EffectiveProductionBonusPercent: reader.GetInt32(6),
                EffectiveMarketBonusPercent: reader.GetInt32(7),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(8))
            : null;
    }

    private static async Task<List<RegionResourceDto>> ReadRegionResourcesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT region_id, resource_id, item_id, name, category, abundance_percent,
                   production_bonus_percent, market_bonus_percent, description, updated_at
            FROM world.region_resources
            WHERE region_id = @region_id
            ORDER BY production_bonus_percent DESC, abundance_percent DESC, name;
            """, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);

        var resources = new List<RegionResourceDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            resources.Add(new RegionResourceDto(
                RegionId: reader.GetString(0),
                ResourceId: reader.GetString(1),
                ItemId: reader.GetString(2),
                Name: reader.GetString(3),
                Category: reader.GetString(4),
                AbundancePercent: reader.GetInt32(5),
                ProductionBonusPercent: reader.GetInt32(6),
                MarketBonusPercent: reader.GetInt32(7),
                Description: reader.GetString(8),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9)));
        }

        return resources;
    }

    private static async Task<RegionDefenseSystemDto?> ReadRegionDefenseAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT defense.region_id, defense.defense_level, defense.hospital_level,
                   defense.garrison_strength, defense.resistance, defense.fortification_health,
                   defense.hospital_energy_per_day, defense.hospital_supplies,
                   (defense.defense_level * 5 + (defense.fortification_health / 10) + COALESCE(bonus.defense_bonus_percent, 0))::integer
                       AS effective_defense_percent,
                   (defense.hospital_energy_per_day + defense.hospital_supplies + COALESCE(bonus.hospital_capacity, 0))::integer
                       AS effective_hospital_capacity,
                   defense.updated_at
            FROM world.region_defense_systems defense
            LEFT JOIN world.region_resource_bonuses bonus ON bonus.region_id = defense.region_id
            WHERE defense.region_id = @region_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new RegionDefenseSystemDto(
                RegionId: reader.GetString(0),
                DefenseLevel: reader.GetInt32(1),
                HospitalLevel: reader.GetInt32(2),
                GarrisonStrength: reader.GetInt32(3),
                Resistance: reader.GetInt32(4),
                FortificationHealth: reader.GetInt32(5),
                HospitalEnergyPerDay: reader.GetInt32(6),
                HospitalSupplies: reader.GetInt32(7),
                EffectiveDefensePercent: reader.GetInt32(8),
                EffectiveHospitalCapacity: reader.GetInt32(9),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(10))
            : null;
    }

    private static async Task<List<RegionControlHistoryDto>> ReadRegionControlHistoryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT h.history_id, h.region_id, r.name,
                   h.previous_country_id, pc.name, pc.code,
                   h.new_country_id, nc.name, nc.code,
                   h.battle_id, b.name,
                   h.changed_by_player_id, h.reason, h.created_at
            FROM world.region_control_history h
            INNER JOIN world.regions r ON r.region_id = h.region_id
            LEFT JOIN world.countries pc ON pc.country_id = h.previous_country_id
            INNER JOIN world.countries nc ON nc.country_id = h.new_country_id
            LEFT JOIN world.battles b ON b.battle_id = h.battle_id
            WHERE h.region_id = @region_id
            ORDER BY h.created_at DESC, h.history_id DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);
        command.Parameters.AddWithValue("limit", limit);

        var history = new List<RegionControlHistoryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            history.Add(new RegionControlHistoryDto(
                HistoryId: reader.GetString(0),
                RegionId: reader.GetString(1),
                RegionName: reader.GetString(2),
                PreviousCountryId: reader.IsDBNull(3) ? null : reader.GetString(3),
                PreviousCountryName: reader.IsDBNull(4) ? null : reader.GetString(4),
                PreviousCountryCode: reader.IsDBNull(5) ? null : reader.GetString(5),
                NewCountryId: reader.GetString(6),
                NewCountryName: reader.GetString(7),
                NewCountryCode: reader.GetString(8),
                BattleId: reader.IsDBNull(9) ? null : reader.GetString(9),
                BattleName: reader.IsDBNull(10) ? null : reader.GetString(10),
                ChangedByPlayerId: reader.GetString(11),
                Reason: reader.GetString(12),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(13)));
        }

        return history;
    }

    private static async Task<CountryBattleDto?> ReadActiveRegionBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string regionId)
    {
        var sql = $"""
            SELECT {BattleSelectColumns}
            FROM world.battles b
            INNER JOIN world.regions r ON r.region_id = b.region_id
            INNER JOIN world.countries ac ON ac.country_id = b.attacker_country_id
            INNER JOIN world.countries dc ON dc.country_id = b.defender_country_id
            LEFT JOIN world.countries wc ON wc.country_id = b.winner_country_id
            WHERE b.region_id = @region_id AND b.status = 'active'
            ORDER BY b.ends_at ASC, b.started_at ASC
            LIMIT 1;
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadBattle(reader) : null;
    }

    private static async Task InsertTerritoryBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string battleId,
        string campaignId,
        string regionId,
        string attackerCountryId,
        string defenderCountryId,
        string battleType,
        string initiatorPlayerId,
        string name,
        string description,
        int targetScore,
        int defenderStrength,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.battles (
                battle_id, region_id, attacker_country_id, defender_country_id,
                name, description, status, attacker_score, defender_score,
                target_score, defender_strength, defender_energy,
                defender_weapon_power, rounds, started_at, ends_at,
                resolved_at, winner_country_id, created_at, updated_at,
                battle_type, campaign_id, initiator_player_id, resolution_reason
            )
            VALUES (
                @battle_id, @region_id, @attacker_country_id, @defender_country_id,
                @name, @description, 'active', 0, 0,
                @target_score, @defender_strength, 100,
                2, 3, @started_at, @ends_at,
                NULL, NULL, @created_at, @updated_at,
                @battle_type, @campaign_id, @initiator_player_id, ''
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("battle_id", battleId);
        command.Parameters.AddWithValue("campaign_id", campaignId);
        command.Parameters.AddWithValue("region_id", regionId);
        command.Parameters.AddWithValue("attacker_country_id", attackerCountryId);
        command.Parameters.AddWithValue("defender_country_id", defenderCountryId);
        command.Parameters.AddWithValue("name", name);
        command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("target_score", targetScore);
        command.Parameters.AddWithValue("defender_strength", defenderStrength);
        command.Parameters.AddWithValue("started_at", now);
        command.Parameters.AddWithValue("ends_at", now.AddHours(24));
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        command.Parameters.AddWithValue("battle_type", battleType);
        command.Parameters.AddWithValue("initiator_player_id", initiatorPlayerId);
        await command.ExecuteNonQueryAsync();
    }

    private static RegionBonusSeed BuildRegionBonusSeed(RegionTemplate region)
    {
        var focus = region.ResourceFocus.Trim();
        var terrain = region.Terrain.Trim().ToLowerInvariant();
        var resources = BuildRegionResourceSeeds(region);
        var production = Math.Clamp((region.Infrastructure / 12) + (region.IsCapital ? 3 : 0), 3, 18);
        if (resources.Length > 0)
        {
            production = Math.Max(production, resources.Max(resource => resource.ProductionBonusPercent));
        }

        var market = focus.ToLowerInvariant() is "trade" or "finance" or "shipping" or "caravans"
            ? 10
            : region.IsCapital ? 6 : 2;
        if (resources.Length > 0)
        {
            market = Math.Max(market, resources.Max(resource => resource.MarketBonusPercent));
        }

        var defense = (terrain.Contains("mountain") || terrain.Contains("highland") ||
                       terrain.Contains("forest") || terrain.Contains("frozen"))
            ? 10
            : 4;
        if (region.IsCapital)
        {
            defense += 3;
        }

        return new RegionBonusSeed(
            ResourceType: focus,
            ProductionBonusPercent: production,
            MarketBonusPercent: market,
            DefenseBonusPercent: defense,
            HospitalCapacity: Math.Clamp(region.Infrastructure * (region.IsCapital ? 18 : 12), 300, 2_000));
    }

    private static RegionDefenseSeed BuildRegionDefenseSeed(RegionTemplate region, RegionBonusSeed bonus)
    {
        var defenseLevel = region.IsCapital ? 4 : 2;
        var hospitalLevel = region.IsCapital ? 4 : 2;
        return new RegionDefenseSeed(
            DefenseLevel: defenseLevel,
            HospitalLevel: hospitalLevel,
            GarrisonStrength: Math.Clamp(region.Infrastructure * 4, 100, 500),
            FortificationHealth: Math.Clamp(45 + region.Infrastructure / 2 + (region.IsCapital ? 15 : 0), 55, 100),
            HospitalEnergyPerDay: Math.Clamp((hospitalLevel * 125) + (bonus.HospitalCapacity / 8), 150, 1_000),
            HospitalSupplies: Math.Clamp(region.Population / 120, 250, 2_500));
    }

    private static RegionResourceSeed[] BuildRegionResourceSeeds(RegionTemplate region)
    {
        var seeds = new List<RegionResourceSeed>
        {
            CreateRegionResourceSeed(region.ResourceFocus, region.Infrastructure, primary: true)
        };

        var terrain = region.Terrain.ToLowerInvariant();
        if (terrain.Contains("plain") || terrain.Contains("farm") || terrain.Contains("river"))
        {
            seeds.Add(CreateRegionResourceSeed("Grain", region.Infrastructure - 8, primary: false));
        }
        else if (terrain.Contains("mountain") || terrain.Contains("highland") || terrain.Contains("frozen"))
        {
            seeds.Add(CreateRegionResourceSeed("Iron", region.Infrastructure - 6, primary: false));
        }
        else if (terrain.Contains("forest"))
        {
            seeds.Add(CreateRegionResourceSeed("Timber", region.Infrastructure - 5, primary: false));
        }
        else if (terrain.Contains("coastal") || terrain.Contains("harbor") || terrain.Contains("city"))
        {
            seeds.Add(CreateRegionResourceSeed("Trade", region.Infrastructure - 4, primary: false));
        }
        else if (terrain.Contains("desert"))
        {
            seeds.Add(CreateRegionResourceSeed("Caravans", region.Infrastructure - 10, primary: false));
        }

        return seeds
            .GroupBy(seed => seed.ResourceId, StringComparer.Ordinal)
            .Select(group => group.OrderByDescending(seed => seed.ProductionBonusPercent).First())
            .ToArray();
    }

    private static RegionResourceSeed CreateRegionResourceSeed(string resourceName, int infrastructure, bool primary)
    {
        var normalized = resourceName.Trim();
        var key = normalized.ToLowerInvariant();
        var itemId = key switch
        {
            "grain" => "grain",
            "food" => "food",
            "iron" or "steel" => "iron",
            "timber" => "wood",
            "trade" or "shipping" or "finance" or "caravans" => "trade_goods",
            _ => key.Replace(' ', '_')
        };
        var category = itemId is "grain" or "iron" or "wood"
            ? "Raw material"
            : itemId == "food" ? "Consumable" : "Strategic";
        var abundance = Math.Clamp(infrastructure + (primary ? 18 : 4), 25, 95);
        var production = key switch
        {
            "grain" => 12,
            "iron" or "steel" => 12,
            "food" => 9,
            "timber" => 8,
            "trade" or "shipping" or "finance" or "caravans" => 4,
            _ => 6
        };
        var market = key is "trade" or "shipping" or "finance" or "caravans"
            ? 12
            : primary ? 5 : 3;

        return new RegionResourceSeed(
            ResourceId: $"resource-{itemId}",
            ItemId: itemId,
            Name: normalized,
            Category: category,
            AbundancePercent: abundance,
            ProductionBonusPercent: production + (primary ? 2 : 0),
            MarketBonusPercent: market,
            Description: $"{normalized} deposits support {category.ToLowerInvariant()} output and regional trade.");
    }
}

internal sealed record TerritoryMapResponse(TerritoryRegionDto[] Regions, DateTimeOffset UpdatedAt);

internal sealed record TerritoryRegionDto(
    string RegionId,
    string Name,
    string Terrain,
    string ResourceFocus,
    int Population,
    int Infrastructure,
    bool IsCapital,
    string OwnerCountryId,
    string OwnerCountryName,
    string OwnerCountryCode,
    RegionResourceBonusDto Bonus,
    RegionResourceDto[] Resources,
    RegionDefenseSystemDto Defense,
    CountryBattleDto? ActiveConflict,
    RegionControlHistoryDto[] RecentHistory,
    TerritoryAuthorizationDto Authorization,
    DateTimeOffset UpdatedAt);

internal sealed record RegionResourceBonusDto(
    string RegionId,
    string ResourceType,
    int ProductionBonusPercent,
    int MarketBonusPercent,
    int DefenseBonusPercent,
    int HospitalCapacity,
    int EffectiveProductionBonusPercent,
    int EffectiveMarketBonusPercent,
    DateTimeOffset UpdatedAt)
{
    public static RegionResourceBonusDto Empty(string regionId)
    {
        return new RegionResourceBonusDto(regionId, "general", 0, 0, 0, 0, 0, 0, DateTimeOffset.UtcNow);
    }
}

internal sealed record RegionResourceDto(
    string RegionId,
    string ResourceId,
    string ItemId,
    string Name,
    string Category,
    int AbundancePercent,
    int ProductionBonusPercent,
    int MarketBonusPercent,
    string Description,
    DateTimeOffset UpdatedAt);

internal sealed record RegionDefenseSystemDto(
    string RegionId,
    int DefenseLevel,
    int HospitalLevel,
    int GarrisonStrength,
    int Resistance,
    int FortificationHealth,
    int HospitalEnergyPerDay,
    int HospitalSupplies,
    int EffectiveDefensePercent,
    int EffectiveHospitalCapacity,
    DateTimeOffset UpdatedAt)
{
    public static RegionDefenseSystemDto Empty(string regionId)
    {
        return new RegionDefenseSystemDto(regionId, 0, 0, 0, 0, 0, 0, 0, 0, 0, DateTimeOffset.UtcNow);
    }
}

internal sealed record RegionControlHistoryDto(
    string HistoryId,
    string RegionId,
    string RegionName,
    string? PreviousCountryId,
    string? PreviousCountryName,
    string? PreviousCountryCode,
    string NewCountryId,
    string NewCountryName,
    string NewCountryCode,
    string? BattleId,
    string? BattleName,
    string ChangedByPlayerId,
    string Reason,
    DateTimeOffset CreatedAt);

internal sealed record RegionControlHistoryResponse(
    string RegionId,
    RegionControlHistoryDto[] History,
    DateTimeOffset UpdatedAt);

internal sealed record TerritoryAuthorizationDto(
    bool CanStartConquest,
    bool CanStartResistance,
    bool CanResolveBattle,
    string? Role,
    string Message);

internal sealed record TerritoryBattleStartRequest(string? RegionId, string? BattleType);

internal sealed record TerritoryBattleMutationResult(
    bool Completed,
    string Message,
    int StatusCode,
    CountryBattleDto? Battle,
    TerritoryRegionDto? Region,
    DateTimeOffset UpdatedAt)
{
    public static TerritoryBattleMutationResult Failed(
        string message,
        int statusCode,
        CountryBattleDto? battle,
        TerritoryRegionDto? region)
    {
        return new TerritoryBattleMutationResult(
            false,
            message,
            statusCode,
            battle,
            region,
            DateTimeOffset.UtcNow);
    }
}

internal sealed record TerritoryRegionBase(
    string RegionId,
    string OwnerCountryId,
    string Name,
    string Terrain,
    string ResourceFocus,
    int Population,
    int Infrastructure,
    bool IsCapital,
    DateTimeOffset UpdatedAt,
    string OwnerCountryName,
    string OwnerCountryCode);

internal sealed record RegionBonusSeed(
    string ResourceType,
    int ProductionBonusPercent,
    int MarketBonusPercent,
    int DefenseBonusPercent,
    int HospitalCapacity);

internal sealed record RegionResourceSeed(
    string ResourceId,
    string ItemId,
    string Name,
    string Category,
    int AbundancePercent,
    int ProductionBonusPercent,
    int MarketBonusPercent,
    string Description);

internal sealed record RegionDefenseSeed(
    int DefenseLevel,
    int HospitalLevel,
    int GarrisonStrength,
    int FortificationHealth,
    int HospitalEnergyPerDay,
    int HospitalSupplies);

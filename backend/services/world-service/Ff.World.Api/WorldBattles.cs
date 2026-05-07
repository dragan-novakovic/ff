using Npgsql;

internal static class BattleEndpoints
{
    public static void MapBattleEndpoints(this WebApplication app)
    {
        app.MapGet("/battles", async (
            string? status,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return Results.Ok(await world.GetBattlesAsync(status));
        }).WithName("GetBattles");

        app.MapGet("/battles/{battleId}", async (
            string battleId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var battle = await world.GetBattleAsync(battleId);
            return battle is null
                ? Results.NotFound(new ErrorResponse("Battle was not found."))
                : Results.Ok(battle);
        }).WithName("GetBattle");

        app.MapGet("/players/{playerId}/battles/{battleId}/participation", async (
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

            var participation = await world.GetPlayerBattleParticipationAsync(access.PlayerId!, battleId);
            return participation is null
                ? Results.NotFound(new ErrorResponse("Battle was not found."))
                : Results.Ok(participation);
        }).WithName("GetPlayerBattleParticipation");

        app.MapPost("/players/{playerId}/battles/{battleId}/contributions", async (
            string playerId,
            string battleId,
            BattleContributionRequest contribution,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateContribution(contribution);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.ContributeToBattleAsync(access.PlayerId!, battleId, contribution);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Battle was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
        }).WithName("ContributeToBattle");
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
                new ErrorResponse("You cannot access another player's battle participation."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string? ValidateContribution(BattleContributionRequest contribution)
    {
        if (contribution.Damage <= 0)
        {
            return "Battle contribution damage must be positive.";
        }

        if (contribution.EnergySpent <= 0 || contribution.RoundsCompleted <= 0)
        {
            return "Battle contribution energy and rounds must be positive.";
        }

        if (contribution.GoldReward < 0 || contribution.ExperienceReward < 0)
        {
            return "Battle contribution rewards cannot be negative.";
        }

        if (string.IsNullOrWhiteSpace(contribution.IdempotencyKey))
        {
            return "Battle contribution idempotency key is required.";
        }

        return null;
    }
}

internal sealed partial class WorldStore
{
    private static readonly TimeSpan SeedBattleDuration = TimeSpan.FromHours(24);
    private static readonly TimeSpan RecentBattleWindow = TimeSpan.FromDays(7);

    public async Task InitializeBattleSchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.battles (
                battle_id text PRIMARY KEY,
                region_id text NOT NULL REFERENCES world.regions(region_id),
                attacker_country_id text NOT NULL REFERENCES world.countries(country_id),
                defender_country_id text NOT NULL REFERENCES world.countries(country_id),
                name text NOT NULL,
                description text NOT NULL,
                status text NOT NULL,
                attacker_score integer NOT NULL DEFAULT 0,
                defender_score integer NOT NULL DEFAULT 0,
                target_score integer NOT NULL,
                defender_strength integer NOT NULL,
                defender_energy integer NOT NULL,
                defender_weapon_power integer NOT NULL,
                rounds integer NOT NULL,
                started_at timestamptz NOT NULL,
                ends_at timestamptz NOT NULL,
                resolved_at timestamptz NULL,
                winner_country_id text NULL REFERENCES world.countries(country_id),
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_battles_status_ends_at
                ON world.battles (status, ends_at);

            CREATE INDEX IF NOT EXISTS ix_world_battles_region_id
                ON world.battles (region_id);

            CREATE TABLE IF NOT EXISTS world.battle_contributions (
                contribution_id text PRIMARY KEY,
                battle_id text NOT NULL REFERENCES world.battles(battle_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                side text NOT NULL,
                damage integer NOT NULL,
                energy_spent integer NOT NULL,
                rounds_completed integer NOT NULL,
                won boolean NOT NULL,
                gold_reward integer NOT NULL,
                experience_reward integer NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                message text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_battle_contributions_battle_created_at
                ON world.battle_contributions (battle_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_world_battle_contributions_player_battle
                ON world.battle_contributions (player_id, battle_id);

            ALTER TABLE world.battles
                ADD COLUMN IF NOT EXISTS battle_type text NOT NULL DEFAULT 'skirmish';

            ALTER TABLE world.battles
                ADD COLUMN IF NOT EXISTS campaign_id text NULL;
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task SeedBattlesAsync()
    {
        await ResolveDueBattlesAsync();

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await InsertResolvedSeedBattleAsync(connection, transaction, now);

        var activeCount = await CountActiveBattlesAsync(connection, transaction);
        if (activeCount == 0)
        {
            var defenderCountryId = await ReadRegionOwnerAsync(connection, transaction, "greenmarch")
                ?? "freiland";
            var attackerCountryId = string.Equals(defenderCountryId, "nordheim", StringComparison.Ordinal)
                ? "solara"
                : "nordheim";

            await InsertBattleAsync(
                connection,
                transaction,
                new BattleSeed(
                    BattleId: $"battle-greenmarch-{now:yyyyMMddHHmmss}",
                    RegionId: "greenmarch",
                    AttackerCountryId: attackerCountryId,
                    DefenderCountryId: defenderCountryId,
                    Name: "Greenmarch Border Clash",
                    Description: "A persisted country battle for control of Greenmarch. Citizens of either side can spend energy to add damage to their country's score.",
                    Status: "active",
                    AttackerScore: 0,
                    DefenderScore: 0,
                    TargetScore: 500,
                    DefenderStrength: 12,
                    DefenderEnergy: 100,
                    DefenderWeaponPower: 2,
                    Rounds: 3,
                    StartedAt: now.AddMinutes(-15),
                    EndsAt: now.Add(SeedBattleDuration),
                    ResolvedAt: null,
                    WinnerCountryId: null,
                    CreatedAt: now,
                    UpdatedAt: now));
        }

        await transaction.CommitAsync();
    }

    public async Task<BattleListResponse> GetBattlesAsync(string? status)
    {
        await ResolveDueBattlesAsync();

        await using var connection = await _dataSource.OpenConnectionAsync();
        var battles = await ReadBattlesAsync(connection, NormalizeBattleStatus(status));
        return new BattleListResponse(battles.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<BattleDetailsResponse?> GetBattleAsync(string battleId)
    {
        await ResolveDueBattlesAsync();

        var normalizedBattleId = NormalizeId(battleId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var battle = await ReadBattleAsync(connection, null, normalizedBattleId);
        if (battle is null)
        {
            return null;
        }

        var contributions = await ReadBattleContributionsAsync(connection, null, normalizedBattleId);
        var campaign = await ReadCampaignForBattleAsync(connection, null, normalizedBattleId);
        var phases = await ReadBattlePhasesAsync(connection, null, normalizedBattleId, campaign?.CampaignId);
        var countryLeaderboard = await ReadCountryBattleLeaderboardAsync(
            connection,
            null,
            campaign?.CampaignId,
            normalizedBattleId,
            limit: 10);
        var unitLeaderboard = await ReadUnitBattleTotalsAsync(
            connection,
            null,
            unitId: null,
            countryId: null,
            battleId: normalizedBattleId,
            limit: 10);
        return new BattleDetailsResponse(
            battle,
            contributions.ToArray(),
            campaign,
            phases.ToArray(),
            new CountryBattleLeaderboardResponse(countryLeaderboard.ToArray(), DateTimeOffset.UtcNow),
            new MilitaryUnitLeaderboardResponse(unitLeaderboard.ToArray(), DateTimeOffset.UtcNow),
            DateTimeOffset.UtcNow);
    }

    public async Task<PlayerBattleParticipationResponse?> GetPlayerBattleParticipationAsync(
        string playerId,
        string battleId)
    {
        await ResolveDueBattlesAsync();

        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedBattleId = NormalizeId(battleId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (await ReadBattleAsync(connection, null, normalizedBattleId) is null)
        {
            return null;
        }

        var participation = await ReadPlayerBattleParticipationAsync(
            connection,
            null,
            normalizedPlayerId,
            normalizedBattleId);
        return new PlayerBattleParticipationResponse(
            normalizedPlayerId,
            normalizedBattleId,
            participation,
            DateTimeOffset.UtcNow);
    }

    public async Task<BattleContributionResult?> ContributeToBattleAsync(
        string playerId,
        string battleId,
        BattleContributionRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedBattleId = NormalizeId(battleId);
        var idempotencyKey = request.IdempotencyKey.Trim().ToLowerInvariant();
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existingContribution = await ReadBattleContributionByIdempotencyAsync(
            connection,
            transaction,
            idempotencyKey);
        if (existingContribution is not null)
        {
            var existingBattle = await ReadBattleAsync(connection, transaction, existingContribution.BattleId);
            var existingParticipation = await ReadPlayerBattleParticipationAsync(
                connection,
                transaction,
                normalizedPlayerId,
                normalizedBattleId);
            await transaction.CommitAsync();

            var isSameContribution =
                string.Equals(existingContribution.PlayerId, normalizedPlayerId, StringComparison.Ordinal) &&
                string.Equals(existingContribution.BattleId, normalizedBattleId, StringComparison.Ordinal);
            return new BattleContributionResult(
                Completed: isSameContribution,
                Message: isSameContribution
                    ? "Battle contribution was already recorded."
                    : "Battle contribution idempotency key was already used.",
                Battle: existingBattle,
                Contribution: isSameContribution ? existingContribution : null,
                Participation: existingParticipation,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        var battle = await ReadBattleAsync(connection, transaction, normalizedBattleId, forUpdate: true);
        if (battle is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        battle = await ResolveBattleIfNeededAsync(connection, transaction, battle.BattleId, now) ?? battle;
        if (!string.Equals(battle.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            var conflict = await BattleConflictAsync(
                connection,
                transaction,
                normalizedPlayerId,
                normalizedBattleId,
                "Battle is already resolved.");
            await transaction.CommitAsync();
            return conflict;
        }

        if (battle.EndsAt <= now)
        {
            battle = await ResolveBattleIfNeededAsync(connection, transaction, battle.BattleId, now) ?? battle;
            await transaction.CommitAsync();
            return new BattleContributionResult(
                Completed: false,
                Message: "Battle has ended.",
                Battle: battle,
                Contribution: null,
                Participation: null,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null || !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new BattleContributionResult(
                Completed: false,
                Message: "Join a battle country before contributing.",
                Battle: battle,
                Contribution: null,
                Participation: null,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        var side = ContributionSide(citizenship.CountryId, battle);
        if (side is null)
        {
            await transaction.CommitAsync();
            return new BattleContributionResult(
                Completed: false,
                Message: "Your country is not fighting in this battle.",
                Battle: battle,
                Contribution: null,
                Participation: null,
                UpdatedAt: DateTimeOffset.UtcNow);
        }

        var contributionId = await InsertContributionAsync(
            connection,
            transaction,
            normalizedBattleId,
            normalizedPlayerId,
            citizenship.CountryId,
            side,
            request,
            idempotencyKey,
            now);
        await AddBattleScoreAsync(connection, transaction, normalizedBattleId, side, request.Damage, now);
        await AddActiveUnitBattleContributionAsync(
            connection,
            transaction,
            contributionId,
            normalizedBattleId,
            normalizedPlayerId,
            citizenship.CountryId,
            side,
            request.Damage,
            request.EnergySpent,
            now);
        await RecordCampaignBattleContributionAsync(
            connection,
            transaction,
            normalizedBattleId,
            side,
            citizenship.CountryId,
            request.Damage,
            now);

        battle = await ResolveBattleIfNeededAsync(connection, transaction, normalizedBattleId, now)
            ?? await ReadBattleAsync(connection, transaction, normalizedBattleId)
            ?? battle;
        var contribution = await ReadBattleContributionByIdempotencyAsync(connection, transaction, idempotencyKey);
        var participation = await ReadPlayerBattleParticipationAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedBattleId);
        await transaction.CommitAsync();

        return new BattleContributionResult(
            Completed: true,
            Message: request.Message,
            Battle: battle,
            Contribution: contribution,
            Participation: participation,
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    private static async Task<BattleContributionResult> BattleConflictAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string battleId,
        string message)
    {
        var battle = await ReadBattleAsync(connection, transaction, battleId);
        var participation = await ReadPlayerBattleParticipationAsync(connection, transaction, playerId, battleId);
        return new BattleContributionResult(
            Completed: false,
            Message: message,
            Battle: battle,
            Contribution: null,
            Participation: participation,
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    private async Task ResolveDueBattlesAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var dueBattleIds = new List<string>();

        await using (var command = new NpgsqlCommand("""
            SELECT battle_id
            FROM world.battles
            WHERE status = 'active'
              AND (ends_at <= @now OR attacker_score >= target_score OR defender_score >= target_score)
            FOR UPDATE;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("now", now);
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                dueBattleIds.Add(reader.GetString(0));
            }
        }

        foreach (var dueBattleId in dueBattleIds)
        {
            await ResolveBattleIfNeededAsync(connection, transaction, dueBattleId, now);
        }

        await transaction.CommitAsync();
    }

    private static async Task<CountryBattleDto?> ResolveBattleIfNeededAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string battleId,
        DateTimeOffset now,
        string changedByPlayerId = "system")
    {
        var battle = await ReadBattleAsync(connection, transaction, battleId, forUpdate: true);
        if (battle is null || !string.Equals(battle.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            return battle;
        }

        var reachedTarget = battle.AttackerScore >= battle.TargetScore ||
            battle.DefenderScore >= battle.TargetScore;
        if (battle.EndsAt > now && !reachedTarget)
        {
            return battle;
        }

        var winnerCountryId = battle.AttackerScore > battle.DefenderScore
            ? battle.AttackerCountryId
            : battle.DefenderCountryId;

        await using (var updateBattle = new NpgsqlCommand("""
            UPDATE world.battles
            SET status = 'resolved',
                winner_country_id = @winner_country_id,
                resolved_at = @resolved_at,
                resolution_reason = @resolution_reason,
                updated_at = @updated_at
            WHERE battle_id = @battle_id;
            """, connection, transaction))
        {
            updateBattle.Parameters.AddWithValue("battle_id", battle.BattleId);
            updateBattle.Parameters.AddWithValue("winner_country_id", winnerCountryId);
            updateBattle.Parameters.AddWithValue("resolved_at", now);
            updateBattle.Parameters.AddWithValue("resolution_reason", "battle_resolution");
            updateBattle.Parameters.AddWithValue("updated_at", now);
            await updateBattle.ExecuteNonQueryAsync();
        }

        await ApplyRegionOwnershipChangeAsync(
            connection,
            transaction,
            battle,
            winnerCountryId,
            changedByPlayerId,
            "battle_resolution",
            now);
        await ResolveCampaignsForBattleAsync(
            connection,
            transaction,
            battle,
            winnerCountryId,
            now);

        return await ReadBattleAsync(connection, transaction, battle.BattleId);
    }

    private static async Task InsertResolvedSeedBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        DateTimeOffset now)
    {
        await InsertBattleAsync(
            connection,
            transaction,
            new BattleSeed(
                BattleId: "battle-freyport-defense",
                RegionId: "freyport",
                AttackerCountryId: "solara",
                DefenderCountryId: "freiland",
                Name: "Freyport Harbor Defense",
                Description: "A recent resolved battle kept as persisted history for the battle log.",
                Status: "resolved",
                AttackerScore: 180,
                DefenderScore: 240,
                TargetScore: 300,
                DefenderStrength: 10,
                DefenderEnergy: 100,
                DefenderWeaponPower: 2,
                Rounds: 3,
                StartedAt: now.AddDays(-2),
                EndsAt: now.AddDays(-1).AddHours(-23),
                ResolvedAt: now.AddDays(-1),
                WinnerCountryId: "freiland",
                CreatedAt: now,
                UpdatedAt: now));
    }

    private static async Task InsertBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        BattleSeed seed)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.battles (
                battle_id, region_id, attacker_country_id, defender_country_id,
                name, description, status, attacker_score, defender_score, target_score,
                defender_strength, defender_energy, defender_weapon_power, rounds,
                started_at, ends_at, resolved_at, winner_country_id, created_at, updated_at
            )
            VALUES (
                @battle_id, @region_id, @attacker_country_id, @defender_country_id,
                @name, @description, @status, @attacker_score, @defender_score, @target_score,
                @defender_strength, @defender_energy, @defender_weapon_power, @rounds,
                @started_at, @ends_at, @resolved_at, @winner_country_id, @created_at, @updated_at
            )
            ON CONFLICT (battle_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("battle_id", seed.BattleId);
        command.Parameters.AddWithValue("region_id", seed.RegionId);
        command.Parameters.AddWithValue("attacker_country_id", seed.AttackerCountryId);
        command.Parameters.AddWithValue("defender_country_id", seed.DefenderCountryId);
        command.Parameters.AddWithValue("name", seed.Name);
        command.Parameters.AddWithValue("description", seed.Description);
        command.Parameters.AddWithValue("status", seed.Status);
        command.Parameters.AddWithValue("attacker_score", seed.AttackerScore);
        command.Parameters.AddWithValue("defender_score", seed.DefenderScore);
        command.Parameters.AddWithValue("target_score", seed.TargetScore);
        command.Parameters.AddWithValue("defender_strength", seed.DefenderStrength);
        command.Parameters.AddWithValue("defender_energy", seed.DefenderEnergy);
        command.Parameters.AddWithValue("defender_weapon_power", seed.DefenderWeaponPower);
        command.Parameters.AddWithValue("rounds", seed.Rounds);
        command.Parameters.AddWithValue("started_at", seed.StartedAt);
        command.Parameters.AddWithValue("ends_at", seed.EndsAt);
        command.Parameters.AddWithValue("resolved_at", (object?)seed.ResolvedAt ?? DBNull.Value);
        command.Parameters.AddWithValue("winner_country_id", (object?)seed.WinnerCountryId ?? DBNull.Value);
        command.Parameters.AddWithValue("created_at", seed.CreatedAt);
        command.Parameters.AddWithValue("updated_at", seed.UpdatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<int> CountActiveBattlesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction)
    {
        await using var command = new NpgsqlCommand("""
            SELECT count(*)::int
            FROM world.battles
            WHERE status = 'active';
            """, connection, transaction);
        return (int)(await command.ExecuteScalarAsync() ?? 0);
    }

    private static async Task<string?> ReadRegionOwnerAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string regionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT country_id
            FROM world.regions
            WHERE region_id = @region_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("region_id", regionId);
        return await command.ExecuteScalarAsync() as string;
    }

    private static async Task<List<CountryBattleDto>> ReadBattlesAsync(
        NpgsqlConnection connection,
        string status)
    {
        var where = status switch
        {
            "active" => "WHERE b.status = 'active'",
            "recent" or "resolved" => "WHERE b.status = 'resolved'",
            "all" => string.Empty,
            _ => "WHERE b.status = 'active' OR (b.status = 'resolved' AND b.resolved_at >= @recent_cutoff)"
        };
        var sql = $"""
            SELECT {BattleSelectColumns}
            FROM world.battles b
            INNER JOIN world.regions r ON r.region_id = b.region_id
            INNER JOIN world.countries ac ON ac.country_id = b.attacker_country_id
            INNER JOIN world.countries dc ON dc.country_id = b.defender_country_id
            LEFT JOIN world.countries wc ON wc.country_id = b.winner_country_id
            {where}
            ORDER BY
                CASE WHEN b.status = 'active' THEN 0 ELSE 1 END,
                b.ends_at ASC,
                b.resolved_at DESC NULLS LAST;
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        if (status is not ("active" or "recent" or "resolved" or "all"))
        {
            command.Parameters.AddWithValue("recent_cutoff", DateTimeOffset.UtcNow.Subtract(RecentBattleWindow));
        }

        var battles = new List<CountryBattleDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            battles.Add(ReadBattle(reader));
        }

        return battles;
    }

    private const string BattleSelectColumns = """
        b.battle_id, b.region_id, r.name AS region_name,
        b.attacker_country_id, ac.name AS attacker_country_name, ac.code AS attacker_country_code,
        b.defender_country_id, dc.name AS defender_country_name, dc.code AS defender_country_code,
        b.name, b.description, b.battle_type, b.campaign_id, b.status,
        b.attacker_score, b.defender_score, b.target_score,
        b.defender_strength, b.defender_energy, b.defender_weapon_power, b.rounds,
        b.started_at, b.ends_at, b.resolved_at,
        b.winner_country_id, wc.name AS winner_country_name,
        b.updated_at
        """;

    private static async Task<CountryBattleDto?> ReadBattleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string battleId,
        bool forUpdate = false)
    {
        var sql = $"""
            SELECT {BattleSelectColumns}
            FROM world.battles b
            INNER JOIN world.regions r ON r.region_id = b.region_id
            INNER JOIN world.countries ac ON ac.country_id = b.attacker_country_id
            INNER JOIN world.countries dc ON dc.country_id = b.defender_country_id
            LEFT JOIN world.countries wc ON wc.country_id = b.winner_country_id
            WHERE b.battle_id = @battle_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE OF b";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("battle_id", battleId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadBattle(reader) : null;
    }

    private static CountryBattleDto ReadBattle(NpgsqlDataReader reader)
    {
        return new CountryBattleDto(
            BattleId: reader.GetString(0),
            RegionId: reader.GetString(1),
            RegionName: reader.GetString(2),
            AttackerCountryId: reader.GetString(3),
            AttackerCountryName: reader.GetString(4),
            AttackerCountryCode: reader.GetString(5),
            DefenderCountryId: reader.GetString(6),
            DefenderCountryName: reader.GetString(7),
            DefenderCountryCode: reader.GetString(8),
            Name: reader.GetString(9),
            Description: reader.GetString(10),
            BattleType: reader.GetString(11),
            CampaignId: reader.IsDBNull(12) ? null : reader.GetString(12),
            Status: reader.GetString(13),
            AttackerScore: reader.GetInt32(14),
            DefenderScore: reader.GetInt32(15),
            TargetScore: reader.GetInt32(16),
            DefenderStrength: reader.GetInt32(17),
            DefenderEnergy: reader.GetInt32(18),
            DefenderWeaponPower: reader.GetInt32(19),
            Rounds: reader.GetInt32(20),
            StartedAt: reader.GetFieldValue<DateTimeOffset>(21),
            EndsAt: reader.GetFieldValue<DateTimeOffset>(22),
            ResolvedAt: reader.IsDBNull(23) ? null : reader.GetFieldValue<DateTimeOffset>(23),
            WinnerCountryId: reader.IsDBNull(24) ? null : reader.GetString(24),
            WinnerCountryName: reader.IsDBNull(25) ? null : reader.GetString(25),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(26));
    }

    private static async Task<List<BattleContributionDto>> ReadBattleContributionsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string battleId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT bc.contribution_id, bc.battle_id, bc.player_id,
                   bc.country_id, c.name, c.code, bc.side,
                   bc.damage, bc.energy_spent, bc.rounds_completed, bc.won,
                   bc.gold_reward, bc.experience_reward, bc.message, bc.created_at
            FROM world.battle_contributions bc
            INNER JOIN world.countries c ON c.country_id = bc.country_id
            WHERE bc.battle_id = @battle_id
            ORDER BY bc.created_at DESC, bc.contribution_id DESC
            LIMIT 50;
            """, connection, transaction);
        command.Parameters.AddWithValue("battle_id", battleId);

        var contributions = new List<BattleContributionDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            contributions.Add(ReadBattleContribution(reader));
        }

        return contributions;
    }

    private static async Task<BattleContributionDto?> ReadBattleContributionByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT bc.contribution_id, bc.battle_id, bc.player_id,
                   bc.country_id, c.name, c.code, bc.side,
                   bc.damage, bc.energy_spent, bc.rounds_completed, bc.won,
                   bc.gold_reward, bc.experience_reward, bc.message, bc.created_at
            FROM world.battle_contributions bc
            INNER JOIN world.countries c ON c.country_id = bc.country_id
            WHERE bc.idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadBattleContribution(reader) : null;
    }

    private static BattleContributionDto ReadBattleContribution(NpgsqlDataReader reader)
    {
        return new BattleContributionDto(
            ContributionId: reader.GetString(0),
            BattleId: reader.GetString(1),
            PlayerId: reader.GetString(2),
            CountryId: reader.GetString(3),
            CountryName: reader.GetString(4),
            CountryCode: reader.GetString(5),
            Side: reader.GetString(6),
            Damage: reader.GetInt32(7),
            EnergySpent: reader.GetInt32(8),
            RoundsCompleted: reader.GetInt32(9),
            Won: reader.GetBoolean(10),
            GoldReward: reader.GetInt32(11),
            ExperienceReward: reader.GetInt32(12),
            Message: reader.GetString(13),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(14));
    }

    private static async Task<PlayerBattleParticipationDto?> ReadPlayerBattleParticipationAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        string battleId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT bc.player_id, bc.battle_id,
                   max(bc.country_id), max(c.name), max(c.code), max(bc.side),
                   count(*)::int,
                   COALESCE(sum(bc.damage), 0)::int,
                   COALESCE(sum(bc.energy_spent), 0)::int,
                   COALESCE(sum(bc.gold_reward), 0)::int,
                   COALESCE(sum(bc.experience_reward), 0)::int,
                   max(bc.created_at)
            FROM world.battle_contributions bc
            INNER JOIN world.countries c ON c.country_id = bc.country_id
            WHERE bc.player_id = @player_id AND bc.battle_id = @battle_id
            GROUP BY bc.player_id, bc.battle_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("battle_id", battleId);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        return new PlayerBattleParticipationDto(
            PlayerId: reader.GetString(0),
            BattleId: reader.GetString(1),
            CountryId: reader.IsDBNull(2) ? null : reader.GetString(2),
            CountryName: reader.IsDBNull(3) ? null : reader.GetString(3),
            CountryCode: reader.IsDBNull(4) ? null : reader.GetString(4),
            Side: reader.IsDBNull(5) ? null : reader.GetString(5),
            ContributionCount: reader.GetInt32(6),
            Damage: reader.GetInt32(7),
            EnergySpent: reader.GetInt32(8),
            GoldReward: reader.GetInt32(9),
            ExperienceReward: reader.GetInt32(10),
            LastContributedAt: reader.IsDBNull(11) ? null : reader.GetFieldValue<DateTimeOffset>(11));
    }

    private static async Task<string> InsertContributionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string battleId,
        string playerId,
        string countryId,
        string side,
        BattleContributionRequest request,
        string idempotencyKey,
        DateTimeOffset now)
    {
        var contributionId = $"contrib-{Guid.NewGuid():N}";
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.battle_contributions (
                contribution_id, battle_id, player_id, country_id, side,
                damage, energy_spent, rounds_completed, won,
                gold_reward, experience_reward, idempotency_key, message, created_at
            )
            VALUES (
                @contribution_id, @battle_id, @player_id, @country_id, @side,
                @damage, @energy_spent, @rounds_completed, @won,
                @gold_reward, @experience_reward, @idempotency_key, @message, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("contribution_id", contributionId);
        command.Parameters.AddWithValue("battle_id", battleId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("side", side);
        command.Parameters.AddWithValue("damage", request.Damage);
        command.Parameters.AddWithValue("energy_spent", request.EnergySpent);
        command.Parameters.AddWithValue("rounds_completed", request.RoundsCompleted);
        command.Parameters.AddWithValue("won", request.Won);
        command.Parameters.AddWithValue("gold_reward", request.GoldReward);
        command.Parameters.AddWithValue("experience_reward", request.ExperienceReward);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("message", request.Message.Trim());
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
        return contributionId;
    }

    private static async Task AddBattleScoreAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string battleId,
        string side,
        int damage,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.battles
            SET attacker_score = attacker_score + CASE WHEN @side = 'attacker' THEN @damage ELSE 0 END,
                defender_score = defender_score + CASE WHEN @side = 'defender' THEN @damage ELSE 0 END,
                updated_at = @updated_at
            WHERE battle_id = @battle_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("battle_id", battleId);
        command.Parameters.AddWithValue("side", side);
        command.Parameters.AddWithValue("damage", damage);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static string? ContributionSide(string countryId, CountryBattleDto battle)
    {
        if (string.Equals(countryId, battle.AttackerCountryId, StringComparison.Ordinal))
        {
            return "attacker";
        }

        return string.Equals(countryId, battle.DefenderCountryId, StringComparison.Ordinal)
            ? "defender"
            : null;
    }

    private static string NormalizeBattleStatus(string? status)
    {
        var normalized = string.IsNullOrWhiteSpace(status)
            ? "current"
            : status.Trim().ToLowerInvariant();
        return normalized is "active" or "recent" or "resolved" or "all"
            ? normalized
            : "current";
    }
}

internal sealed record BattleListResponse(CountryBattleDto[] Battles, DateTimeOffset UpdatedAt);

internal sealed record BattleDetailsResponse(
    CountryBattleDto Battle,
    BattleContributionDto[] Contributions,
    CampaignDto? Campaign,
    BattlePhaseDto[] Phases,
    CountryBattleLeaderboardResponse CountryLeaderboard,
    MilitaryUnitLeaderboardResponse UnitLeaderboard,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerBattleParticipationResponse(
    string PlayerId,
    string BattleId,
    PlayerBattleParticipationDto? Participation,
    DateTimeOffset UpdatedAt);

internal sealed record BattleContributionResult(
    bool Completed,
    string Message,
    CountryBattleDto? Battle,
    BattleContributionDto? Contribution,
    PlayerBattleParticipationDto? Participation,
    DateTimeOffset UpdatedAt);

internal sealed record CountryBattleDto(
    string BattleId,
    string RegionId,
    string RegionName,
    string AttackerCountryId,
    string AttackerCountryName,
    string AttackerCountryCode,
    string DefenderCountryId,
    string DefenderCountryName,
    string DefenderCountryCode,
    string Name,
    string Description,
    string BattleType,
    string? CampaignId,
    string Status,
    int AttackerScore,
    int DefenderScore,
    int TargetScore,
    int DefenderStrength,
    int DefenderEnergy,
    int DefenderWeaponPower,
    int Rounds,
    DateTimeOffset StartedAt,
    DateTimeOffset EndsAt,
    DateTimeOffset? ResolvedAt,
    string? WinnerCountryId,
    string? WinnerCountryName,
    DateTimeOffset UpdatedAt);

internal sealed record BattleContributionDto(
    string ContributionId,
    string BattleId,
    string PlayerId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Side,
    int Damage,
    int EnergySpent,
    int RoundsCompleted,
    bool Won,
    int GoldReward,
    int ExperienceReward,
    string Message,
    DateTimeOffset CreatedAt);

internal sealed record PlayerBattleParticipationDto(
    string PlayerId,
    string BattleId,
    string? CountryId,
    string? CountryName,
    string? CountryCode,
    string? Side,
    int ContributionCount,
    int Damage,
    int EnergySpent,
    int GoldReward,
    int ExperienceReward,
    DateTimeOffset? LastContributedAt);

internal sealed record BattleContributionRequest(
    int Damage,
    int EnergySpent,
    int RoundsCompleted,
    bool Won,
    int GoldReward,
    int ExperienceReward,
    string Message,
    string IdempotencyKey);

internal sealed record BattleSeed(
    string BattleId,
    string RegionId,
    string AttackerCountryId,
    string DefenderCountryId,
    string Name,
    string Description,
    string Status,
    int AttackerScore,
    int DefenderScore,
    int TargetScore,
    int DefenderStrength,
    int DefenderEnergy,
    int DefenderWeaponPower,
    int Rounds,
    DateTimeOffset StartedAt,
    DateTimeOffset EndsAt,
    DateTimeOffset? ResolvedAt,
    string? WinnerCountryId,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

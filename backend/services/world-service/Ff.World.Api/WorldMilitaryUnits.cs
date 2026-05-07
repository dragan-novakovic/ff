using Npgsql;

internal static class MilitaryUnitEndpoints
{
    private const int DefaultLeaderboardLimit = 25;
    private const int MaxLeaderboardLimit = 100;

    public static void MapMilitaryUnitEndpoints(this WebApplication app)
    {
        app.MapGet("/military-units", async (
            string? countryId,
            string? playerId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return Results.Ok(await world.GetMilitaryUnitsAsync(countryId, playerId));
        }).WithName("GetMilitaryUnits");

        app.MapGet("/players/{playerId}/military-units", async (
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

            return Results.Ok(await world.GetMilitaryUnitsAsync(countryId: null, playerId: access.PlayerId));
        }).WithName("GetPlayerMilitaryUnits");

        app.MapPost("/players/{playerId}/military-units", async (
            string playerId,
            MilitaryUnitCreateRequest createRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateCreate(createRequest);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.CreateMilitaryUnitAsync(access.PlayerId!, createRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Country was not found."))
                : MutationResult(result);
        }).WithName("CreateMilitaryUnit");

        app.MapGet("/military-units/leaderboard", async (
            string? countryId,
            string? battleId,
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

            return Results.Ok(await world.GetMilitaryUnitBattleLeaderboardAsync(
                countryId,
                battleId,
                ClampLimit(limit)));
        }).WithName("GetMilitaryUnitLeaderboard");

        app.MapGet("/military-units/battles/{battleId}/leaderboard", async (
            string battleId,
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

            return Results.Ok(await world.GetMilitaryUnitBattleLeaderboardAsync(
                countryId: null,
                battleId,
                ClampLimit(limit)));
        }).WithName("GetBattleMilitaryUnitLeaderboard");

        app.MapGet("/military-units/{unitId}", async (
            string unitId,
            string? playerId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var details = await world.GetMilitaryUnitDetailsAsync(unitId, playerId);
            return details is null
                ? Results.NotFound(new ErrorResponse("Military unit was not found."))
                : Results.Ok(details);
        }).WithName("GetMilitaryUnit");

        app.MapPost("/players/{playerId}/military-units/{unitId}/join", async (
            string playerId,
            string unitId,
            MilitaryUnitJoinRequest joinRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.JoinMilitaryUnitAsync(access.PlayerId!, unitId, joinRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit was not found."))
                : MutationResult(result);
        }).WithName("JoinMilitaryUnit");

        app.MapPost("/players/{playerId}/military-units/{unitId}/leave", async (
            string playerId,
            string unitId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.LeaveMilitaryUnitAsync(access.PlayerId!, unitId);
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit was not found."))
                : MutationResult(result);
        }).WithName("LeaveMilitaryUnit");

        app.MapGet("/military-units/{unitId}/orders", async (
            string unitId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var response = await world.GetMilitaryUnitOrdersAsync(unitId);
            return response is null
                ? Results.NotFound(new ErrorResponse("Military unit was not found."))
                : Results.Ok(response);
        }).WithName("GetMilitaryUnitOrders");

        app.MapPost("/players/{playerId}/military-units/{unitId}/orders", async (
            string playerId,
            string unitId,
            MilitaryUnitOrderRequest orderRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateOrder(orderRequest);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.IssueMilitaryUnitOrderAsync(access.PlayerId!, unitId, orderRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit or target battle was not found."))
                : MutationResult(result);
        }).WithName("IssueMilitaryUnitOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/orders/{orderId}/complete", async (
            string playerId,
            string unitId,
            string orderId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.UpdateMilitaryUnitOrderStatusAsync(access.PlayerId!, unitId, orderId, "completed");
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit order was not found."))
                : MutationResult(result);
        }).WithName("CompleteMilitaryUnitOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/orders/{orderId}/cancel", async (
            string playerId,
            string unitId,
            string orderId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.UpdateMilitaryUnitOrderStatusAsync(access.PlayerId!, unitId, orderId, "cancelled");
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit order was not found."))
                : MutationResult(result);
        }).WithName("CancelMilitaryUnitOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/members/{targetPlayerId}/role", async (
            string playerId,
            string unitId,
            string targetPlayerId,
            MilitaryUnitRoleRequest roleRequest,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.UpdateMilitaryUnitMemberRoleAsync(access.PlayerId!, unitId, targetPlayerId, roleRequest);
            return result is null
                ? Results.NotFound(new ErrorResponse("Military unit member was not found."))
                : MutationResult(result);
        }).WithName("UpdateMilitaryUnitMemberRole");

        app.MapGet("/military-units/{unitId}/battle-contributions", async (
            string unitId,
            string? battleId,
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

            var response = await world.GetMilitaryUnitBattleContributionsAsync(unitId, battleId, ClampLimit(limit));
            return response is null
                ? Results.NotFound(new ErrorResponse("Military unit was not found."))
                : Results.Ok(response);
        }).WithName("GetMilitaryUnitBattleContributions");
    }

    private static IResult MutationResult(MilitaryUnitMutationResult result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static IResult MutationResult(MilitaryUnitOrderMutationResult result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static IResult MutationResult(MilitaryUnitMemberMutationResult result)
    {
        return result.Completed
            ? Results.Ok(result)
            : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
    }

    private static int ClampLimit(int? limit)
    {
        return Math.Clamp(limit ?? DefaultLeaderboardLimit, 1, MaxLeaderboardLimit);
    }

    private static string? ValidateCreate(MilitaryUnitCreateRequest request)
    {
        var name = request.Name?.Trim() ?? string.Empty;
        if (name.Length is < 3 or > 48)
        {
            return "Military unit name must be between 3 and 48 characters.";
        }

        if ((request.Description?.Trim().Length ?? 0) > 280)
        {
            return "Military unit description cannot exceed 280 characters.";
        }

        if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            return "Military unit creation idempotency key is required.";
        }

        return null;
    }

    private static string? ValidateOrder(MilitaryUnitOrderRequest request)
    {
        var title = request.Title?.Trim() ?? string.Empty;
        if (title.Length is < 3 or > 80)
        {
            return "Order title must be between 3 and 80 characters.";
        }

        if ((request.Description?.Trim().Length ?? 0) > 500)
        {
            return "Order description cannot exceed 500 characters.";
        }

        if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            return "Order idempotency key is required.";
        }

        return null;
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

    private static PlayerAccessResult ValidatePlayerAccess(string playerId, HttpRequest request, DevTokenValidator tokens)
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
                new ErrorResponse("You cannot manage another player's military unit membership."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }
}

internal sealed partial class WorldStore
{
    private const string MilitaryUnitSelectColumns = """
        u.unit_id, u.country_id, c.name AS country_name, c.code AS country_code,
        u.name, u.description, u.status, u.created_by_player_id,
        (SELECT count(*)::int
         FROM world.unit_members m
         WHERE m.unit_id = u.unit_id AND m.left_at IS NULL) AS member_count,
        (SELECT COALESCE(sum(t.total_damage), 0)::int
         FROM world.unit_battle_totals t
         WHERE t.unit_id = u.unit_id) AS total_battle_damage,
        (SELECT count(*)::int
         FROM world.unit_orders o
         WHERE o.unit_id = u.unit_id AND o.status = 'active') AS active_order_count,
        (SELECT vm.role
         FROM world.unit_members vm
         WHERE vm.unit_id = u.unit_id
           AND vm.player_id = @viewer_player_id
           AND vm.left_at IS NULL
         LIMIT 1) AS viewer_role,
        u.created_at, u.updated_at
        """;

    private static async Task<List<MilitaryUnitDto>> ReadMilitaryUnitsAsync(
        NpgsqlConnection connection,
        string? countryId,
        string? viewerPlayerId)
    {
        await using var command = new NpgsqlCommand($"""
            SELECT {MilitaryUnitSelectColumns}
            FROM world.military_units u
            INNER JOIN world.countries c ON c.country_id = u.country_id
            WHERE (@country_id = '' OR u.country_id = @country_id)
            ORDER BY
                CASE WHEN u.status = 'active' THEN 0 ELSE 1 END,
                total_battle_damage DESC,
                member_count DESC,
                lower(u.name);
            """, connection);
        command.Parameters.AddWithValue("country_id", countryId ?? string.Empty);
        command.Parameters.AddWithValue("viewer_player_id", viewerPlayerId ?? string.Empty);

        var units = new List<MilitaryUnitDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            units.Add(ReadMilitaryUnit(reader));
        }

        return units;
    }

    private static async Task<MilitaryUnitDto?> ReadMilitaryUnitByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey,
        string? viewerPlayerId)
    {
        await using var command = new NpgsqlCommand($"""
            SELECT {MilitaryUnitSelectColumns}
            FROM world.military_units u
            INNER JOIN world.countries c ON c.country_id = u.country_id
            WHERE u.idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("viewer_player_id", viewerPlayerId ?? string.Empty);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadMilitaryUnit(reader) : null;
    }

    private static async Task<MilitaryUnitDto?> ReadMilitaryUnitAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string unitId,
        string? viewerPlayerId,
        bool forUpdate = false)
    {
        var sql = $"""
            SELECT {MilitaryUnitSelectColumns}
            FROM world.military_units u
            INNER JOIN world.countries c ON c.country_id = u.country_id
            WHERE u.unit_id = @unit_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE OF u";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("viewer_player_id", viewerPlayerId ?? string.Empty);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadMilitaryUnit(reader) : null;
    }

    private static MilitaryUnitDto ReadMilitaryUnit(NpgsqlDataReader reader)
    {
        return new MilitaryUnitDto(
            UnitId: reader.GetString(0),
            CountryId: reader.GetString(1),
            CountryName: reader.GetString(2),
            CountryCode: reader.GetString(3),
            Name: reader.GetString(4),
            Description: reader.GetString(5),
            Status: reader.GetString(6),
            CreatedByPlayerId: reader.GetString(7),
            MemberCount: reader.GetInt32(8),
            TotalBattleDamage: reader.GetInt32(9),
            ActiveOrderCount: reader.GetInt32(10),
            ViewerRole: reader.IsDBNull(11) ? null : reader.GetString(11),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(12),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(13));
    }

    private static async Task<bool> MilitaryUnitNameExistsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string name)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM world.military_units
            WHERE lower(name) = lower(@name)
              AND status <> 'disbanded';
            """, connection, transaction);
        command.Parameters.AddWithValue("name", name);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task InsertUnitMemberAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string unitId,
        string playerId,
        string role,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.unit_members (
                member_id, unit_id, player_id, role, status,
                joined_at, left_at, updated_at
            )
            VALUES (
                @member_id, @unit_id, @player_id, @role, 'active',
                @joined_at, NULL, @updated_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("member_id", $"member-{Guid.NewGuid():N}");
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("role", role);
        command.Parameters.AddWithValue("joined_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<int> CountActiveUnitMembersAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string unitId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT count(*)::int
            FROM world.unit_members
            WHERE unit_id = @unit_id
              AND left_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        return (int)(await command.ExecuteScalarAsync() ?? 0);
    }

    private static async Task TouchUnitAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string unitId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.military_units
            SET updated_at = @updated_at
            WHERE unit_id = @unit_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<ActiveUnitMembership?> ReadActiveUnitMembershipAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT um.unit_id, u.country_id, um.role
            FROM world.unit_members um
            INNER JOIN world.military_units u ON u.unit_id = um.unit_id
            WHERE um.player_id = @player_id
              AND um.left_at IS NULL
              AND um.status = 'active'
              AND u.status = 'active'
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new ActiveUnitMembership(reader.GetString(0), reader.GetString(1), reader.GetString(2))
            : null;
    }

    private static async Task<string?> ReadUnitRoleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string unitId,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT role
            FROM world.unit_members
            WHERE unit_id = @unit_id
              AND player_id = @player_id
              AND left_at IS NULL
              AND status = 'active';
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("player_id", playerId);
        return await command.ExecuteScalarAsync() as string;
    }

    private static async Task<UnitMemberDto?> ReadActiveUnitMemberAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string unitId,
        string playerId,
        bool forUpdate = false)
    {
        var sql = """
            SELECT member_id, unit_id, player_id, role, status,
                   joined_at, left_at, updated_at
            FROM world.unit_members
            WHERE unit_id = @unit_id
              AND player_id = @player_id
              AND left_at IS NULL
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadUnitMember(reader) : null;
    }

    private static async Task<List<UnitMemberDto>> ReadUnitMembersAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string unitId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT member_id, unit_id, player_id, role, status,
                   joined_at, left_at, updated_at
            FROM world.unit_members
            WHERE unit_id = @unit_id
            ORDER BY
                CASE WHEN left_at IS NULL THEN 0 ELSE 1 END,
                CASE role WHEN 'commander' THEN 0 WHEN 'officer' THEN 1 ELSE 2 END,
                joined_at ASC;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);

        var members = new List<UnitMemberDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            members.Add(ReadUnitMember(reader));
        }

        return members;
    }

    private static UnitMemberDto ReadUnitMember(NpgsqlDataReader reader)
    {
        return new UnitMemberDto(
            MemberId: reader.GetString(0),
            UnitId: reader.GetString(1),
            PlayerId: reader.GetString(2),
            Role: reader.GetString(3),
            Status: reader.GetString(4),
            JoinedAt: reader.GetFieldValue<DateTimeOffset>(5),
            LeftAt: reader.IsDBNull(6) ? null : reader.GetFieldValue<DateTimeOffset>(6),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(7));
    }

    private static async Task<List<UnitOrderDto>> ReadUnitOrdersAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string unitId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT order_id, unit_id, issued_by_player_id, order_type, title,
                   description, target_battle_id, status,
                   created_at, updated_at, completed_at
            FROM world.unit_orders
            WHERE unit_id = @unit_id
            ORDER BY
                CASE WHEN status = 'active' THEN 0 ELSE 1 END,
                updated_at DESC,
                created_at DESC;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);

        var orders = new List<UnitOrderDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            orders.Add(ReadUnitOrder(reader));
        }

        return orders;
    }

    private static async Task<UnitOrderDto?> ReadUnitOrderAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string unitId,
        string orderId,
        bool forUpdate = false)
    {
        var sql = """
            SELECT order_id, unit_id, issued_by_player_id, order_type, title,
                   description, target_battle_id, status,
                   created_at, updated_at, completed_at
            FROM world.unit_orders
            WHERE unit_id = @unit_id
              AND order_id = @order_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("order_id", orderId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadUnitOrder(reader) : null;
    }

    private static async Task<UnitOrderDto?> ReadUnitOrderByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT order_id, unit_id, issued_by_player_id, order_type, title,
                   description, target_battle_id, status,
                   created_at, updated_at, completed_at
            FROM world.unit_orders
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadUnitOrder(reader) : null;
    }

    private static UnitOrderDto ReadUnitOrder(NpgsqlDataReader reader)
    {
        return new UnitOrderDto(
            OrderId: reader.GetString(0),
            UnitId: reader.GetString(1),
            IssuedByPlayerId: reader.GetString(2),
            OrderType: reader.GetString(3),
            Title: reader.GetString(4),
            Description: reader.GetString(5),
            TargetBattleId: reader.IsDBNull(6) ? null : reader.GetString(6),
            Status: reader.GetString(7),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(8),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9),
            CompletedAt: reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10));
    }

    private static async Task<List<UnitBattleTotalDto>> ReadUnitBattleTotalsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? unitId,
        string? countryId,
        string? battleId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT t.unit_id, u.name AS unit_name,
                   t.battle_id, b.name AS battle_name,
                   t.country_id, c.name AS country_name, c.code AS country_code,
                   t.side, t.total_damage, t.contribution_count, t.member_count,
                   t.last_contributed_at, t.updated_at
            FROM world.unit_battle_totals t
            INNER JOIN world.military_units u ON u.unit_id = t.unit_id
            INNER JOIN world.battles b ON b.battle_id = t.battle_id
            INNER JOIN world.countries c ON c.country_id = t.country_id
            WHERE (@unit_id = '' OR t.unit_id = @unit_id)
              AND (@country_id = '' OR t.country_id = @country_id)
              AND (@battle_id = '' OR t.battle_id = @battle_id)
            ORDER BY t.total_damage DESC, t.contribution_count DESC, t.updated_at DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId ?? string.Empty);
        command.Parameters.AddWithValue("country_id", countryId ?? string.Empty);
        command.Parameters.AddWithValue("battle_id", battleId ?? string.Empty);
        command.Parameters.AddWithValue("limit", Math.Clamp(limit, 1, 100));

        var totals = new List<UnitBattleTotalDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            totals.Add(ReadUnitBattleTotal(reader));
        }

        return totals;
    }

    private static UnitBattleTotalDto ReadUnitBattleTotal(NpgsqlDataReader reader)
    {
        return new UnitBattleTotalDto(
            UnitId: reader.GetString(0),
            UnitName: reader.GetString(1),
            BattleId: reader.GetString(2),
            BattleName: reader.GetString(3),
            CountryId: reader.GetString(4),
            CountryName: reader.GetString(5),
            CountryCode: reader.GetString(6),
            Side: reader.GetString(7),
            TotalDamage: reader.GetInt32(8),
            ContributionCount: reader.GetInt32(9),
            MemberCount: reader.GetInt32(10),
            LastContributedAt: reader.IsDBNull(11) ? null : reader.GetFieldValue<DateTimeOffset>(11),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(12));
    }

    private static async Task<List<UnitBattleContributionDto>> ReadUnitBattleContributionsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string unitId,
        string? battleId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT uc.unit_contribution_id, uc.unit_id, u.name AS unit_name,
                   uc.battle_id, b.name AS battle_name, uc.battle_contribution_id,
                   uc.player_id, uc.country_id, c.name AS country_name, c.code AS country_code,
                   uc.side, uc.damage, uc.energy_spent, uc.created_at
            FROM world.unit_battle_contributions uc
            INNER JOIN world.military_units u ON u.unit_id = uc.unit_id
            INNER JOIN world.battles b ON b.battle_id = uc.battle_id
            INNER JOIN world.countries c ON c.country_id = uc.country_id
            WHERE uc.unit_id = @unit_id
              AND (@battle_id = '' OR uc.battle_id = @battle_id)
            ORDER BY uc.created_at DESC, uc.damage DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("unit_id", unitId);
        command.Parameters.AddWithValue("battle_id", battleId ?? string.Empty);
        command.Parameters.AddWithValue("limit", Math.Clamp(limit, 1, 100));

        var contributions = new List<UnitBattleContributionDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            contributions.Add(ReadUnitBattleContribution(reader));
        }

        return contributions;
    }

    private static UnitBattleContributionDto ReadUnitBattleContribution(NpgsqlDataReader reader)
    {
        return new UnitBattleContributionDto(
            UnitContributionId: reader.GetString(0),
            UnitId: reader.GetString(1),
            UnitName: reader.GetString(2),
            BattleId: reader.GetString(3),
            BattleName: reader.GetString(4),
            BattleContributionId: reader.GetString(5),
            PlayerId: reader.GetString(6),
            CountryId: reader.GetString(7),
            CountryName: reader.GetString(8),
            CountryCode: reader.GetString(9),
            Side: reader.GetString(10),
            Damage: reader.GetInt32(11),
            EnergySpent: reader.GetInt32(12),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(13));
    }

    private static async Task AddActiveUnitBattleContributionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string battleContributionId,
        string battleId,
        string playerId,
        string countryId,
        string side,
        int damage,
        int energySpent,
        DateTimeOffset now)
    {
        var membership = await ReadActiveUnitMembershipAsync(connection, transaction, playerId);
        if (membership is null || !string.Equals(membership.CountryId, countryId, StringComparison.Ordinal))
        {
            return;
        }

        var inserted = false;
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.unit_battle_contributions (
                unit_contribution_id, unit_id, battle_id, battle_contribution_id,
                player_id, country_id, side, damage, energy_spent, created_at
            )
            VALUES (
                @unit_contribution_id, @unit_id, @battle_id, @battle_contribution_id,
                @player_id, @country_id, @side, @damage, @energy_spent, @created_at
            )
            ON CONFLICT (battle_contribution_id) DO NOTHING;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("unit_contribution_id", $"unit-contrib-{Guid.NewGuid():N}");
            command.Parameters.AddWithValue("unit_id", membership.UnitId);
            command.Parameters.AddWithValue("battle_id", battleId);
            command.Parameters.AddWithValue("battle_contribution_id", battleContributionId);
            command.Parameters.AddWithValue("player_id", playerId);
            command.Parameters.AddWithValue("country_id", countryId);
            command.Parameters.AddWithValue("side", side);
            command.Parameters.AddWithValue("damage", damage);
            command.Parameters.AddWithValue("energy_spent", energySpent);
            command.Parameters.AddWithValue("created_at", now);
            inserted = await command.ExecuteNonQueryAsync() > 0;
        }

        if (!inserted)
        {
            return;
        }

        await using var updateTotals = new NpgsqlCommand("""
            INSERT INTO world.unit_battle_totals (
                unit_id, battle_id, country_id, side, total_damage,
                contribution_count, member_count, last_contributed_at, updated_at
            )
            VALUES (
                @unit_id, @battle_id, @country_id, @side, @damage,
                1,
                (SELECT count(DISTINCT player_id)::int
                 FROM world.unit_battle_contributions
                 WHERE unit_id = @unit_id AND battle_id = @battle_id),
                @last_contributed_at,
                @updated_at
            )
            ON CONFLICT (unit_id, battle_id) DO UPDATE
            SET total_damage = world.unit_battle_totals.total_damage + EXCLUDED.total_damage,
                contribution_count = world.unit_battle_totals.contribution_count + 1,
                member_count = (
                    SELECT count(DISTINCT player_id)::int
                    FROM world.unit_battle_contributions
                    WHERE unit_id = @unit_id AND battle_id = @battle_id
                ),
                last_contributed_at = GREATEST(
                    COALESCE(world.unit_battle_totals.last_contributed_at, EXCLUDED.last_contributed_at),
                    EXCLUDED.last_contributed_at
                ),
                updated_at = EXCLUDED.updated_at;
            """, connection, transaction);
        updateTotals.Parameters.AddWithValue("unit_id", membership.UnitId);
        updateTotals.Parameters.AddWithValue("battle_id", battleId);
        updateTotals.Parameters.AddWithValue("country_id", countryId);
        updateTotals.Parameters.AddWithValue("side", side);
        updateTotals.Parameters.AddWithValue("damage", damage);
        updateTotals.Parameters.AddWithValue("last_contributed_at", now);
        updateTotals.Parameters.AddWithValue("updated_at", now);
        await updateTotals.ExecuteNonQueryAsync();

        await TouchUnitAsync(connection, transaction, membership.UnitId, now);
    }

    private static bool CanManageOrders(string? role)
    {
        return string.Equals(role, UnitRoleCommander, StringComparison.Ordinal) ||
            string.Equals(role, UnitRoleOfficer, StringComparison.Ordinal);
    }

    private static string NormalizeIdempotencyKey(string value)
    {
        return value.Trim().ToLowerInvariant();
    }

    private static string NormalizeOrderType(string? orderType)
    {
        var normalized = string.IsNullOrWhiteSpace(orderType)
            ? "general"
            : orderType.Trim().ToLowerInvariant().Replace(' ', '_');
        return normalized.Length <= 32 ? normalized : normalized[..32];
    }

    private static string NormalizeOrderStatus(string status)
    {
        return string.Equals(status, "cancelled", StringComparison.OrdinalIgnoreCase)
            ? "cancelled"
            : "completed";
    }

    private static string? NormalizeUnitRole(string? role)
    {
        var normalized = string.IsNullOrWhiteSpace(role) ? string.Empty : role.Trim().ToLowerInvariant();
        return normalized switch
        {
            UnitRoleCommander => UnitRoleCommander,
            UnitRoleOfficer => UnitRoleOfficer,
            "member" or UnitRoleSoldier => UnitRoleSoldier,
            _ => null
        };
    }
}

internal sealed record ActiveUnitMembership(string UnitId, string CountryId, string Role);

internal sealed record MilitaryUnitListResponse(MilitaryUnitDto[] Units, DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitDetailsResponse(
    MilitaryUnitDto Unit,
    UnitMemberDto[] Members,
    UnitOrderDto[] Orders,
    UnitBattleTotalDto[] BattleTotals,
    UnitDivisionDto[] Divisions,
    DeploymentOrderDto[] DeploymentOrders,
    DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitOrdersResponse(
    string UnitId,
    UnitOrderDto[] Orders,
    DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitLeaderboardResponse(
    UnitBattleTotalDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitBattleContributionsResponse(
    string UnitId,
    UnitBattleContributionDto[] Contributions,
    DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitMutationResult(
    bool Completed,
    string Message,
    MilitaryUnitDto? Unit,
    DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitOrderMutationResult(
    bool Completed,
    string Message,
    MilitaryUnitDto? Unit,
    UnitOrderDto? Order,
    DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitMemberMutationResult(
    bool Completed,
    string Message,
    MilitaryUnitDto? Unit,
    UnitMemberDto? Member,
    DateTimeOffset UpdatedAt);

internal sealed record MilitaryUnitDto(
    string UnitId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Name,
    string Description,
    string Status,
    string CreatedByPlayerId,
    int MemberCount,
    int TotalBattleDamage,
    int ActiveOrderCount,
    string? ViewerRole,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record UnitMemberDto(
    string MemberId,
    string UnitId,
    string PlayerId,
    string Role,
    string Status,
    DateTimeOffset JoinedAt,
    DateTimeOffset? LeftAt,
    DateTimeOffset UpdatedAt);

internal sealed record UnitOrderDto(
    string OrderId,
    string UnitId,
    string IssuedByPlayerId,
    string OrderType,
    string Title,
    string Description,
    string? TargetBattleId,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? CompletedAt);

internal sealed record UnitBattleTotalDto(
    string UnitId,
    string UnitName,
    string BattleId,
    string BattleName,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Side,
    int TotalDamage,
    int ContributionCount,
    int MemberCount,
    DateTimeOffset? LastContributedAt,
    DateTimeOffset UpdatedAt);

internal sealed record UnitBattleContributionDto(
    string UnitContributionId,
    string UnitId,
    string UnitName,
    string BattleId,
    string BattleName,
    string BattleContributionId,
    string PlayerId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Side,
    int Damage,
    int EnergySpent,
    DateTimeOffset CreatedAt);

internal sealed record MilitaryUnitCreateRequest(
    string? Name,
    string? Description,
    string? IdempotencyKey);

internal sealed record MilitaryUnitJoinRequest(string? IdempotencyKey);

internal sealed record MilitaryUnitOrderRequest(
    string? OrderType,
    string? Title,
    string? Description,
    string? TargetBattleId,
    string? IdempotencyKey);

internal sealed record MilitaryUnitRoleRequest(string? Role);

internal sealed partial class WorldStore
{
    private const string UnitRoleCommander = "commander";
    private const string UnitRoleOfficer = "officer";
    private const string UnitRoleSoldier = "soldier";

    public async Task InitializeMilitaryUnitSchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.military_units (
                unit_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                name text NOT NULL,
                description text NOT NULL,
                status text NOT NULL,
                created_by_player_id text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE UNIQUE INDEX IF NOT EXISTS ux_world_military_units_active_name
                ON world.military_units (lower(name))
                WHERE status <> 'disbanded';

            CREATE INDEX IF NOT EXISTS ix_world_military_units_country_id
                ON world.military_units (country_id);

            CREATE TABLE IF NOT EXISTS world.unit_members (
                member_id text PRIMARY KEY,
                unit_id text NOT NULL REFERENCES world.military_units(unit_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                role text NOT NULL,
                status text NOT NULL,
                joined_at timestamptz NOT NULL,
                left_at timestamptz NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE UNIQUE INDEX IF NOT EXISTS ux_world_unit_members_active_player
                ON world.unit_members (player_id)
                WHERE left_at IS NULL;

            CREATE UNIQUE INDEX IF NOT EXISTS ux_world_unit_members_active_unit_player
                ON world.unit_members (unit_id, player_id)
                WHERE left_at IS NULL;

            CREATE INDEX IF NOT EXISTS ix_world_unit_members_unit_id
                ON world.unit_members (unit_id);

            CREATE TABLE IF NOT EXISTS world.unit_orders (
                order_id text PRIMARY KEY,
                unit_id text NOT NULL REFERENCES world.military_units(unit_id) ON DELETE CASCADE,
                issued_by_player_id text NOT NULL,
                order_type text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                target_battle_id text NULL REFERENCES world.battles(battle_id),
                status text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                completed_at timestamptz NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_unit_orders_unit_status
                ON world.unit_orders (unit_id, status, updated_at DESC);

            CREATE TABLE IF NOT EXISTS world.unit_battle_totals (
                unit_id text NOT NULL REFERENCES world.military_units(unit_id) ON DELETE CASCADE,
                battle_id text NOT NULL REFERENCES world.battles(battle_id) ON DELETE CASCADE,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                side text NOT NULL,
                total_damage integer NOT NULL DEFAULT 0,
                contribution_count integer NOT NULL DEFAULT 0,
                member_count integer NOT NULL DEFAULT 0,
                last_contributed_at timestamptz NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (unit_id, battle_id)
            );

            CREATE INDEX IF NOT EXISTS ix_world_unit_battle_totals_battle_damage
                ON world.unit_battle_totals (battle_id, total_damage DESC);

            CREATE TABLE IF NOT EXISTS world.unit_battle_contributions (
                unit_contribution_id text PRIMARY KEY,
                unit_id text NOT NULL REFERENCES world.military_units(unit_id) ON DELETE CASCADE,
                battle_id text NOT NULL REFERENCES world.battles(battle_id) ON DELETE CASCADE,
                battle_contribution_id text NOT NULL UNIQUE,
                player_id text NOT NULL,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                side text NOT NULL,
                damage integer NOT NULL,
                energy_spent integer NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_unit_battle_contributions_unit_created
                ON world.unit_battle_contributions (unit_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_world_unit_battle_contributions_battle_damage
                ON world.unit_battle_contributions (battle_id, damage DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<MilitaryUnitListResponse> GetMilitaryUnitsAsync(string? countryId, string? playerId)
    {
        var normalizedCountryId = string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId);
        var normalizedPlayerId = string.IsNullOrWhiteSpace(playerId) ? null : NormalizePlayerId(playerId!);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var units = await ReadMilitaryUnitsAsync(connection, normalizedCountryId, normalizedPlayerId);
        return new MilitaryUnitListResponse(units.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<MilitaryUnitDetailsResponse?> GetMilitaryUnitDetailsAsync(string unitId, string? playerId)
    {
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedPlayerId = string.IsNullOrWhiteSpace(playerId) ? null : NormalizePlayerId(playerId!);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var unit = await ReadMilitaryUnitAsync(connection, null, normalizedUnitId, normalizedPlayerId);
        if (unit is null)
        {
            return null;
        }

        var members = await ReadUnitMembersAsync(connection, null, normalizedUnitId);
        var orders = await ReadUnitOrdersAsync(connection, null, normalizedUnitId);
        var totals = await ReadUnitBattleTotalsAsync(
            connection,
            null,
            unitId: normalizedUnitId,
            countryId: null,
            battleId: null,
            limit: 25);
        var divisions = await ReadUnitDivisionsAsync(connection, null, normalizedUnitId, campaignId: null);
        var deploymentOrders = await ReadDeploymentOrdersAsync(connection, null, normalizedUnitId, campaignId: null);
        return new MilitaryUnitDetailsResponse(
            unit,
            members.ToArray(),
            orders.ToArray(),
            totals.ToArray(),
            divisions.ToArray(),
            deploymentOrders.ToArray(),
            DateTimeOffset.UtcNow);
    }

    public async Task<MilitaryUnitMutationResult?> CreateMilitaryUnitAsync(string playerId, MilitaryUnitCreateRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var name = request.Name!.Trim();
        var description = request.Description?.Trim() ?? string.Empty;
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey!);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var existing = await ReadMilitaryUnitByIdempotencyAsync(connection, transaction, idempotencyKey, normalizedPlayerId);
        if (existing is not null)
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(
                true,
                "Military unit creation was already recorded.",
                existing,
                DateTimeOffset.UtcNow);
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null || !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(
                false,
                "Join a country before creating a military unit.",
                null,
                DateTimeOffset.UtcNow);
        }

        if (await ReadActiveUnitMembershipAsync(connection, transaction, normalizedPlayerId) is not null)
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(
                false,
                "Leave your current military unit before creating another.",
                null,
                DateTimeOffset.UtcNow);
        }

        if (await MilitaryUnitNameExistsAsync(connection, transaction, name))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(
                false,
                "A military unit with that name already exists.",
                null,
                DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        var unitId = $"unit-{Guid.NewGuid():N}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.military_units (
                unit_id, country_id, name, description, status,
                created_by_player_id, idempotency_key, created_at, updated_at
            )
            VALUES (
                @unit_id, @country_id, @name, @description, 'active',
                @created_by_player_id, @idempotency_key, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("unit_id", unitId);
            command.Parameters.AddWithValue("country_id", citizenship.CountryId);
            command.Parameters.AddWithValue("name", name);
            command.Parameters.AddWithValue("description", description);
            command.Parameters.AddWithValue("created_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await InsertUnitMemberAsync(connection, transaction, unitId, normalizedPlayerId, UnitRoleCommander, now);
        var unit = await ReadMilitaryUnitAsync(connection, transaction, unitId, normalizedPlayerId);
        await transaction.CommitAsync();

        return new MilitaryUnitMutationResult(
            true,
            $"Created {unit!.Name} for {unit.CountryName}.",
            unit,
            now);
    }

    public async Task<MilitaryUnitMutationResult?> JoinMilitaryUnitAsync(
        string playerId,
        string unitId,
        MilitaryUnitJoinRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedUnitId = NormalizeId(unitId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        if (unit is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        if (!string.Equals(unit.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(false, "Military unit is not accepting members.", unit, DateTimeOffset.UtcNow);
        }

        var activeMembership = await ReadActiveUnitMembershipAsync(connection, transaction, normalizedPlayerId);
        if (activeMembership is not null)
        {
            if (string.Equals(activeMembership.UnitId, normalizedUnitId, StringComparison.Ordinal))
            {
                await transaction.CommitAsync();
                return new MilitaryUnitMutationResult(true, "You are already a member of this military unit.", unit, DateTimeOffset.UtcNow);
            }

            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(false, "Leave your current military unit before joining another.", unit, DateTimeOffset.UtcNow);
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(citizenship.CountryId, unit.CountryId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(false, $"You must be an active citizen of {unit.CountryName} to join.", unit, DateTimeOffset.UtcNow);
        }

        await InsertUnitMemberAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, UnitRoleSoldier, DateTimeOffset.UtcNow);
        unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        await transaction.CommitAsync();

        return new MilitaryUnitMutationResult(true, $"Joined {unit!.Name}.", unit, DateTimeOffset.UtcNow);
    }

    public async Task<MilitaryUnitMutationResult?> LeaveMilitaryUnitAsync(string playerId, string unitId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedUnitId = NormalizeId(unitId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        if (unit is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var membership = await ReadActiveUnitMembershipAsync(connection, transaction, normalizedPlayerId);
        if (membership is null || !string.Equals(membership.UnitId, normalizedUnitId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(false, "You are not an active member of this military unit.", unit, DateTimeOffset.UtcNow);
        }

        var memberCount = await CountActiveUnitMembersAsync(connection, transaction, normalizedUnitId);
        if (string.Equals(membership.Role, UnitRoleCommander, StringComparison.Ordinal) && memberCount > 1)
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMutationResult(false, "Commanders must transfer leadership or be the last member before leaving.", unit, DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("""
            UPDATE world.unit_members
            SET status = 'left',
                left_at = @left_at,
                updated_at = @updated_at
            WHERE unit_id = @unit_id
              AND player_id = @player_id
              AND left_at IS NULL;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("unit_id", normalizedUnitId);
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("left_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        if (memberCount <= 1)
        {
            await using var disband = new NpgsqlCommand("""
                UPDATE world.military_units
                SET status = 'disbanded',
                    updated_at = @updated_at
                WHERE unit_id = @unit_id;
                """, connection, transaction);
            disband.Parameters.AddWithValue("unit_id", normalizedUnitId);
            disband.Parameters.AddWithValue("updated_at", now);
            await disband.ExecuteNonQueryAsync();
        }
        else
        {
            await TouchUnitAsync(connection, transaction, normalizedUnitId, now);
        }

        unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        await transaction.CommitAsync();

        return new MilitaryUnitMutationResult(true, $"Left {unit!.Name}.", unit, now);
    }

    public async Task<MilitaryUnitOrdersResponse?> GetMilitaryUnitOrdersAsync(string unitId)
    {
        var normalizedUnitId = NormalizeId(unitId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (await ReadMilitaryUnitAsync(connection, null, normalizedUnitId, null) is null)
        {
            return null;
        }

        var orders = await ReadUnitOrdersAsync(connection, null, normalizedUnitId);
        return new MilitaryUnitOrdersResponse(normalizedUnitId, orders.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<MilitaryUnitOrderMutationResult?> IssueMilitaryUnitOrderAsync(
        string playerId,
        string unitId,
        MilitaryUnitOrderRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedBattleId = string.IsNullOrWhiteSpace(request.TargetBattleId) ? null : NormalizeId(request.TargetBattleId!);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey!);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var existing = await ReadUnitOrderByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (existing is not null)
        {
            var existingUnit = await ReadMilitaryUnitAsync(connection, transaction, existing.UnitId, normalizedPlayerId);
            await transaction.CommitAsync();
            return new MilitaryUnitOrderMutationResult(true, "Military unit order was already recorded.", existingUnit, existing, DateTimeOffset.UtcNow);
        }

        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        if (unit is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var role = await ReadUnitRoleAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        if (!CanManageOrders(role))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitOrderMutationResult(false, "Only commanders and officers can issue unit orders.", unit, null, DateTimeOffset.UtcNow);
        }

        if (normalizedBattleId is not null)
        {
            var battle = await ReadBattleAsync(connection, transaction, normalizedBattleId);
            if (battle is null)
            {
                await transaction.RollbackAsync();
                return null;
            }

            if (!string.Equals(battle.AttackerCountryId, unit.CountryId, StringComparison.Ordinal) &&
                !string.Equals(battle.DefenderCountryId, unit.CountryId, StringComparison.Ordinal))
            {
                await transaction.CommitAsync();
                return new MilitaryUnitOrderMutationResult(false, "Unit country is not fighting in the target battle.", unit, null, DateTimeOffset.UtcNow);
            }
        }

        var now = DateTimeOffset.UtcNow;
        var orderId = $"order-{Guid.NewGuid():N}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.unit_orders (
                order_id, unit_id, issued_by_player_id, order_type, title,
                description, target_battle_id, status, idempotency_key,
                created_at, updated_at, completed_at
            )
            VALUES (
                @order_id, @unit_id, @issued_by_player_id, @order_type, @title,
                @description, @target_battle_id, 'active', @idempotency_key,
                @created_at, @updated_at, NULL
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("order_id", orderId);
            command.Parameters.AddWithValue("unit_id", normalizedUnitId);
            command.Parameters.AddWithValue("issued_by_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("order_type", NormalizeOrderType(request.OrderType));
            command.Parameters.AddWithValue("title", request.Title!.Trim());
            command.Parameters.AddWithValue("description", request.Description?.Trim() ?? string.Empty);
            command.Parameters.AddWithValue("target_battle_id", (object?)normalizedBattleId ?? DBNull.Value);
            command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await TouchUnitAsync(connection, transaction, normalizedUnitId, now);
        var order = await ReadUnitOrderAsync(connection, transaction, normalizedUnitId, orderId);
        unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        await transaction.CommitAsync();

        return new MilitaryUnitOrderMutationResult(true, "Military unit order issued.", unit, order, now);
    }

    public async Task<MilitaryUnitOrderMutationResult?> UpdateMilitaryUnitOrderStatusAsync(
        string playerId,
        string unitId,
        string orderId,
        string status)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedOrderId = NormalizeId(orderId);
        var normalizedStatus = NormalizeOrderStatus(status);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        var order = await ReadUnitOrderAsync(connection, transaction, normalizedUnitId, normalizedOrderId, forUpdate: true);
        if (unit is null || order is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var role = await ReadUnitRoleAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        if (!CanManageOrders(role))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitOrderMutationResult(false, "Only commanders and officers can manage unit orders.", unit, order, DateTimeOffset.UtcNow);
        }

        if (string.Equals(order.Status, normalizedStatus, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitOrderMutationResult(true, "Military unit order was already updated.", unit, order, DateTimeOffset.UtcNow);
        }

        if (!string.Equals(order.Status, "active", StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitOrderMutationResult(false, "Only active orders can be updated.", unit, order, DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("""
            UPDATE world.unit_orders
            SET status = @status,
                updated_at = @updated_at,
                completed_at = CASE WHEN @status = 'completed' THEN @updated_at ELSE completed_at END
            WHERE order_id = @order_id
              AND unit_id = @unit_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("order_id", normalizedOrderId);
            command.Parameters.AddWithValue("unit_id", normalizedUnitId);
            command.Parameters.AddWithValue("status", normalizedStatus);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await TouchUnitAsync(connection, transaction, normalizedUnitId, now);
        order = await ReadUnitOrderAsync(connection, transaction, normalizedUnitId, normalizedOrderId);
        unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        await transaction.CommitAsync();

        return new MilitaryUnitOrderMutationResult(true, $"Military unit order {normalizedStatus}.", unit, order, now);
    }

    public async Task<MilitaryUnitMemberMutationResult?> UpdateMilitaryUnitMemberRoleAsync(
        string playerId,
        string unitId,
        string targetPlayerId,
        MilitaryUnitRoleRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedTargetPlayerId = NormalizePlayerId(targetPlayerId);
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedRole = NormalizeUnitRole(request.Role);
        if (normalizedRole is null || normalizedRole == UnitRoleCommander)
        {
            return new MilitaryUnitMemberMutationResult(false, "Role must be officer or soldier.", null, null, DateTimeOffset.UtcNow);
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId, forUpdate: true);
        var member = await ReadActiveUnitMemberAsync(connection, transaction, normalizedUnitId, normalizedTargetPlayerId, forUpdate: true);
        if (unit is null || member is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var issuerRole = await ReadUnitRoleAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        if (!string.Equals(issuerRole, UnitRoleCommander, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMemberMutationResult(false, "Only commanders can change unit roles.", unit, member, DateTimeOffset.UtcNow);
        }

        if (string.Equals(member.Role, UnitRoleCommander, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new MilitaryUnitMemberMutationResult(false, "Commander role cannot be changed by this action.", unit, member, DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("""
            UPDATE world.unit_members
            SET role = @role,
                updated_at = @updated_at
            WHERE unit_id = @unit_id
              AND player_id = @player_id
              AND left_at IS NULL;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("unit_id", normalizedUnitId);
            command.Parameters.AddWithValue("player_id", normalizedTargetPlayerId);
            command.Parameters.AddWithValue("role", normalizedRole);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await TouchUnitAsync(connection, transaction, normalizedUnitId, now);
        member = await ReadActiveUnitMemberAsync(connection, transaction, normalizedUnitId, normalizedTargetPlayerId);
        unit = await ReadMilitaryUnitAsync(connection, transaction, normalizedUnitId, normalizedPlayerId);
        await transaction.CommitAsync();

        return new MilitaryUnitMemberMutationResult(true, "Military unit role updated.", unit, member, now);
    }

    public async Task<MilitaryUnitLeaderboardResponse> GetMilitaryUnitBattleLeaderboardAsync(
        string? countryId,
        string? battleId,
        int limit)
    {
        var normalizedCountryId = string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId);
        var normalizedBattleId = string.IsNullOrWhiteSpace(battleId) ? null : NormalizeId(battleId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var entries = await ReadUnitBattleTotalsAsync(
            connection,
            null,
            unitId: null,
            countryId: normalizedCountryId,
            battleId: normalizedBattleId,
            limit);
        return new MilitaryUnitLeaderboardResponse(entries.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<MilitaryUnitBattleContributionsResponse?> GetMilitaryUnitBattleContributionsAsync(
        string unitId,
        string? battleId,
        int limit)
    {
        var normalizedUnitId = NormalizeId(unitId);
        var normalizedBattleId = string.IsNullOrWhiteSpace(battleId) ? null : NormalizeId(battleId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (await ReadMilitaryUnitAsync(connection, null, normalizedUnitId, null) is null)
        {
            return null;
        }

        var contributions = await ReadUnitBattleContributionsAsync(connection, null, normalizedUnitId, normalizedBattleId, limit);
        return new MilitaryUnitBattleContributionsResponse(normalizedUnitId, contributions.ToArray(), DateTimeOffset.UtcNow);
    }
}

internal static class TerritoryGatewayEndpoints
{
    public static void MapTerritoryGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/world/territory/map", async (
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                TerritoryQuery("territory/map", request, "countryId"),
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayTerritoryMap");

        app.MapGet("/world/territory/regions/{regionId}", async (
            string regionId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"territory/regions/{Uri.EscapeDataString(regionId)}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayTerritoryRegion");

        app.MapGet("/world/territory/regions/{regionId}/history", async (
            string regionId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                TerritoryQuery($"territory/regions/{Uri.EscapeDataString(regionId)}/history", request, "limit"),
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayRegionControlHistory");

        app.MapGet("/world/territory/regions/{regionId}/bonuses", async (
            string regionId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"territory/regions/{Uri.EscapeDataString(regionId)}/bonuses",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayRegionBonuses");

        app.MapGet("/world/territory/regions/{regionId}/defense", async (
            string regionId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"territory/regions/{Uri.EscapeDataString(regionId)}/defense",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayRegionDefense");

        app.MapPost("/players/{playerId}/territory/conquests", async (
            string playerId,
            TerritoryBattleStartGatewayRequest startRequest,
            HttpRequest request,
            WorldServiceClient world,
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

            var battleType = string.IsNullOrWhiteSpace(startRequest.BattleType)
                ? "conquest"
                : startRequest.BattleType.Trim().ToLowerInvariant().Replace('-', '_');
            if (battleType is not ("conquest" or "resistance"))
            {
                return Results.BadRequest(new ErrorResponse("Battle type must be conquest or resistance."));
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/territory/conquests",
                request.Headers.Authorization.ToString(),
                new TerritoryBattleStartGatewayRequest(startRequest.RegionId, battleType));
        }).WithName("StartGatewayTerritoryBattle");

        app.MapPost("/players/{playerId}/territory/battles/{battleId}/resolve", async (
            string playerId,
            string battleId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/territory/battles/{Uri.EscapeDataString(battleId)}/resolve",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("ResolveGatewayTerritoryBattle");
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

    private static string TerritoryQuery(string path, HttpRequest request, params string[] allowedKeys)
    {
        var query = allowedKeys
            .Select(key => (Key: key, Value: request.Query[key].ToString()))
            .Where(pair => !string.IsNullOrWhiteSpace(pair.Value))
            .Select(pair => $"{Uri.EscapeDataString(pair.Key)}={Uri.EscapeDataString(pair.Value)}")
            .ToArray();
        return query.Length == 0 ? path : $"{path}?{string.Join('&', query)}";
    }
}

internal sealed record TerritoryBattleStartGatewayRequest(string? RegionId, string? BattleType);

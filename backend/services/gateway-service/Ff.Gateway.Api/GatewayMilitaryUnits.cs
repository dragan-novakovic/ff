using System.Text.Json;

internal static class MilitaryUnitGatewayEndpoints
{
    public static void MapMilitaryUnitGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/military-units", async (
            string? countryId,
            string? playerId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("countryId", countryId), ("playerId", playerId));
            return await world.GetAsync($"military-units{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayMilitaryUnits");

        app.MapGet("/players/{playerId}/military-units", async (
            string playerId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayPlayerMilitaryUnits");

        app.MapPost("/players/{playerId}/military-units", async (
            string playerId,
            MilitaryUnitCreateGatewayRequest createRequest,
            HttpRequest request,
            WorldServiceClient world,
            PlayerServiceClient players,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            var authorization = request.Headers.Authorization.ToString();
            var result = await world.PostJsonAsync<MilitaryUnitCreateForwardRequest, JsonElement>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units",
                authorization,
                new MilitaryUnitCreateForwardRequest(
                    createRequest.Name,
                    createRequest.Description,
                    idempotencyKey));
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value;
            if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
            {
                var onboarding = await OnboardingGatewayTracker.TrackAsync(
                    players,
                    access.PlayerId!,
                    authorization,
                    configuration,
                    "unit_action",
                    $"onboarding:unit-action:{access.PlayerId!.ToLowerInvariant()}");
                if (onboarding.Error is not null)
                {
                    return onboarding.Error;
                }
            }

            return Results.Json(mutation);
        }).WithName("CreateGatewayMilitaryUnit");

        app.MapGet("/military-units/leaderboard", async (
            string? countryId,
            string? battleId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(
                ("countryId", countryId),
                ("battleId", battleId),
                ("limit", limit?.ToString()));
            return await world.GetAsync($"military-units/leaderboard{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayMilitaryUnitLeaderboard");

        app.MapGet("/military-units/battles/{battleId}/leaderboard", async (
            string battleId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("limit", limit?.ToString()));
            return await world.GetAsync(
                $"military-units/battles/{Uri.EscapeDataString(battleId)}/leaderboard{query}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayBattleMilitaryUnitLeaderboard");

        app.MapGet("/military-units/{unitId}", async (
            string unitId,
            string? playerId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("playerId", playerId));
            return await world.GetAsync(
                $"military-units/{Uri.EscapeDataString(unitId)}{query}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayMilitaryUnit");

        app.MapPost("/players/{playerId}/military-units/{unitId}/join", async (
            string playerId,
            string unitId,
            HttpRequest request,
            WorldServiceClient world,
            PlayerServiceClient players,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var authorization = request.Headers.Authorization.ToString();
            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            var result = await world.PostJsonAsync<MilitaryUnitJoinForwardRequest, JsonElement>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/join",
                authorization,
                new MilitaryUnitJoinForwardRequest(idempotencyKey));
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value;
            if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
            {
                var onboarding = await OnboardingGatewayTracker.TrackAsync(
                    players,
                    access.PlayerId!,
                    authorization,
                    configuration,
                    "unit_action",
                    $"onboarding:unit-action:{access.PlayerId!.ToLowerInvariant()}");
                if (onboarding.Error is not null)
                {
                    return onboarding.Error;
                }
            }

            return Results.Json(mutation);
        }).WithName("JoinGatewayMilitaryUnit");

        app.MapPost("/players/{playerId}/military-units/{unitId}/leave", async (
            string playerId,
            string unitId,
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
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/leave",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("LeaveGatewayMilitaryUnit");

        app.MapGet("/military-units/{unitId}/orders", async (
            string unitId,
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
                $"military-units/{Uri.EscapeDataString(unitId)}/orders",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayMilitaryUnitOrders");

        app.MapPost("/players/{playerId}/military-units/{unitId}/orders", async (
            string playerId,
            string unitId,
            MilitaryUnitOrderGatewayRequest orderRequest,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/orders",
                request.Headers.Authorization.ToString(),
                new MilitaryUnitOrderForwardRequest(
                    orderRequest.OrderType,
                    orderRequest.Title,
                    orderRequest.Description,
                    orderRequest.TargetBattleId,
                    idempotencyKey));
        }).WithName("IssueGatewayMilitaryUnitOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/orders/{orderId}/complete", async (
            string playerId,
            string unitId,
            string orderId,
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
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/orders/{Uri.EscapeDataString(orderId)}/complete",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("CompleteGatewayMilitaryUnitOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/orders/{orderId}/cancel", async (
            string playerId,
            string unitId,
            string orderId,
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
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/orders/{Uri.EscapeDataString(orderId)}/cancel",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("CancelGatewayMilitaryUnitOrder");

        app.MapPost("/players/{playerId}/military-units/{unitId}/members/{targetPlayerId}/role", async (
            string playerId,
            string unitId,
            string targetPlayerId,
            MilitaryUnitRoleGatewayRequest roleRequest,
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
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/military-units/{Uri.EscapeDataString(unitId)}/members/{Uri.EscapeDataString(targetPlayerId)}/role",
                request.Headers.Authorization.ToString(),
                roleRequest);
        }).WithName("UpdateGatewayMilitaryUnitMemberRole");

        app.MapGet("/military-units/{unitId}/battle-contributions", async (
            string unitId,
            string? battleId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = QueryString(("battleId", battleId), ("limit", limit?.ToString()));
            return await world.GetAsync(
                $"military-units/{Uri.EscapeDataString(unitId)}/battle-contributions{query}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayMilitaryUnitBattleContributions");
    }

    private static string QueryString(params (string Name, string? Value)[] values)
    {
        var pairs = values
            .Where(value => !string.IsNullOrWhiteSpace(value.Value))
            .Select(value => $"{Uri.EscapeDataString(value.Name)}={Uri.EscapeDataString(value.Value!)}")
            .ToArray();
        return pairs.Length == 0 ? string.Empty : $"?{string.Join("&", pairs)}";
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
                new ErrorResponse("You cannot manage another player's military unit membership."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }
}

internal sealed record MilitaryUnitCreateGatewayRequest(string? Name, string? Description);

internal sealed record MilitaryUnitCreateForwardRequest(
    string? Name,
    string? Description,
    string IdempotencyKey);

internal sealed record MilitaryUnitJoinForwardRequest(string? IdempotencyKey);

internal sealed record MilitaryUnitOrderGatewayRequest(
    string? OrderType,
    string? Title,
    string? Description,
    string? TargetBattleId);

internal sealed record MilitaryUnitOrderForwardRequest(
    string? OrderType,
    string? Title,
    string? Description,
    string? TargetBattleId,
    string IdempotencyKey);

internal sealed record MilitaryUnitRoleGatewayRequest(string? Role);

internal static class PushNotificationGatewayEndpoints
{
    public static void MapPushNotificationGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/players/{playerId}/push-notifications", async (
            string playerId,
            HttpRequest request,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await notifications.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/push",
                request.Headers.Authorization.ToString(),
                InternalToken(configuration));
        }).WithName("GetGatewayPushNotifications");

        app.MapPost("/players/{playerId}/push-notifications/subscriptions", async (
            string playerId,
            PushSubscriptionGatewayRequest body,
            HttpRequest request,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(body.Endpoint) ||
                string.IsNullOrWhiteSpace(body.P256dh) ||
                string.IsNullOrWhiteSpace(body.Auth))
            {
                return Results.BadRequest(new ErrorResponse("Endpoint, p256dh, and auth are required."));
            }

            return await notifications.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/push/subscriptions",
                request.Headers.Authorization.ToString(),
                body with
                {
                    UserAgent = string.IsNullOrWhiteSpace(body.UserAgent)
                        ? request.Headers.UserAgent.ToString()
                        : body.UserAgent
                },
                InternalToken(configuration));
        }).WithName("UpsertGatewayPushSubscription");

        app.MapPost("/players/{playerId}/push-notifications/subscriptions/disable", async (
            string playerId,
            PushSubscriptionDisableGatewayRequest body,
            HttpRequest request,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(body.Endpoint))
            {
                return Results.BadRequest(new ErrorResponse("Endpoint is required."));
            }

            return await notifications.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/push/subscriptions/disable",
                request.Headers.Authorization.ToString(),
                body,
                InternalToken(configuration));
        }).WithName("DisableGatewayPushSubscription");

        app.MapGet("/players/{playerId}/push-notifications/deliveries", async (
            string playerId,
            int? limit,
            HttpRequest request,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var safeLimit = Math.Clamp(limit ?? 25, 1, 100);
            return await notifications.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/push/deliveries?limit={safeLimit}",
                request.Headers.Authorization.ToString(),
                InternalToken(configuration));
        }).WithName("GetGatewayPushDeliveries");
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

        if (!string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase) &&
            !token.Roles.Contains("admin", StringComparer.OrdinalIgnoreCase))
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("You cannot manage another player's push notifications."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(
            string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase)
                ? token.PlayerId!
                : playerId);
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed record PushSubscriptionGatewayRequest(
    string Endpoint,
    string P256dh,
    string Auth,
    string? UserAgent);

internal sealed record PushSubscriptionDisableGatewayRequest(string Endpoint);

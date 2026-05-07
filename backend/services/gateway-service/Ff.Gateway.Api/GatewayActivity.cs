internal static class ActivityGatewayEndpoints
{
    public static void MapActivityGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/players/{playerId}/activity", async (
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

            var safeLimit = Math.Clamp(limit ?? 50, 1, 100);
            return await notifications.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/activity?limit={safeLimit}",
                request.Headers.Authorization.ToString(),
                InternalToken(configuration));
        }).WithName("GetGatewayPlayerActivity");

        app.MapPost("/players/{playerId}/activity/{eventId}/read", async (
            string playerId,
            string eventId,
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

            if (string.IsNullOrWhiteSpace(eventId))
            {
                return Results.BadRequest(new ErrorResponse("Activity event id is required."));
            }

            return await notifications.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/activity/{Uri.EscapeDataString(eventId.Trim())}/read",
                request.Headers.Authorization.ToString(),
                new { },
                InternalToken(configuration));
        }).WithName("MarkGatewayActivityRead");

        app.MapPost("/players/{playerId}/activity/read-all", async (
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

            return await notifications.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/activity/read-all",
                request.Headers.Authorization.ToString(),
                new { },
                InternalToken(configuration));
        }).WithName("MarkAllGatewayActivityRead");
    }

    public static async Task EmitAsync(
        NotificationServiceClient notifications,
        IConfiguration configuration,
        string playerId,
        string type,
        string message,
        string? relatedId,
        string eventId)
    {
        if (string.IsNullOrWhiteSpace(playerId) ||
            string.IsNullOrWhiteSpace(type) ||
            string.IsNullOrWhiteSpace(message) ||
            string.IsNullOrWhiteSpace(eventId))
        {
            return;
        }

        try
        {
            await notifications.PostJsonAsync<ActivityEventRequestDto, ActivityEventDto>(
                "internal/activity-events",
                string.Empty,
                new ActivityEventRequestDto(
                    EventId: eventId,
                    PlayerId: playerId,
                    Type: type,
                    Message: message,
                    RelatedId: relatedId),
                InternalToken(configuration));
        }
        catch
        {
            // Gameplay actions should not be rolled back if the feed is temporarily unavailable.
        }
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
                new ErrorResponse("You cannot access another player's activity feed."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed record ActivityEventRequestDto(
    string EventId,
    string PlayerId,
    string Type,
    string Message,
    string? RelatedId);

internal sealed record ActivityEventDto(
    string EventId,
    string PlayerId,
    string Type,
    string Message,
    bool IsRead,
    DateTimeOffset CreatedAt,
    string? RelatedId);

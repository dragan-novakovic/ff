using Microsoft.Extensions.Logging;

internal static class AchievementGatewayEndpoints
{
    public static void MapAchievementGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/players/{playerId}/achievements", async (
            string playerId,
            HttpRequest request,
            PlayerServiceClient players,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await players.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/achievements",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayPlayerAchievements");

        app.MapGet("/players/{playerId}/achievements/recent", async (
            string playerId,
            int? limit,
            HttpRequest request,
            PlayerServiceClient players,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var safeLimit = Math.Clamp(limit ?? 10, 1, 50);
            return await players.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/achievements/recent?limit={safeLimit}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayRecentAchievementUnlocks");

        app.MapPost("/players/{playerId}/achievements/{achievementId}/claim", async (
            string playerId,
            string achievementId,
            HttpRequest request,
            PlayerServiceClient players,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(achievementId))
            {
                return Results.BadRequest(new ErrorResponse("Achievement is required."));
            }

            var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
            }

            return await players.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/achievements/{Uri.EscapeDataString(achievementId)}/claim",
                request.Headers.Authorization.ToString(),
                new AchievementClaimRequestDto(
                    $"achievement-claim:{access.PlayerId!.ToLowerInvariant()}:{achievementId.Trim().ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}"),
                InternalToken(configuration));
        }).WithName("ClaimGatewayAchievement");
    }

    public static async Task<AchievementsSummaryDto?> TrackAsync(
        PlayerServiceClient players,
        string playerId,
        string authorization,
        IConfiguration configuration,
        string actionType,
        string idempotencyKey,
        ILogger logger,
        int quantity = 1,
        string? relatedId = null)
    {
        if (string.IsNullOrWhiteSpace(playerId) ||
            string.IsNullOrWhiteSpace(actionType) ||
            string.IsNullOrWhiteSpace(idempotencyKey) ||
            quantity <= 0)
        {
            logger.LogWarning(
                "Achievement tracking skipped because the event was invalid for player {PlayerId} and action {ActionType}.",
                playerId,
                actionType);
            return null;
        }

        var result = await players.PostJsonAsync<AchievementTrackRequestDto, AchievementsSummaryDto>(
            $"players/{Uri.EscapeDataString(playerId)}/achievements/track",
            authorization,
            new AchievementTrackRequestDto(
                ActionType: actionType,
                Quantity: Math.Max(1, quantity),
                IdempotencyKey: idempotencyKey.ToLowerInvariant(),
                RelatedId: relatedId),
            InternalToken(configuration));
        if (result.Error is not null)
        {
            logger.LogWarning(
                "Achievement tracking failed for player {PlayerId}, action {ActionType}, event {EventId}.",
                playerId,
                actionType,
                idempotencyKey);
            return null;
        }

        return result.Value;
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
                new ErrorResponse("You cannot access another player's achievements."),
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

internal sealed record AchievementsSummaryDto(
    string PlayerId,
    AchievementProgressDto[] Achievements,
    AchievementUnlockDto[] RecentUnlocks,
    int TotalUnlocked,
    int TotalAvailable,
    int TotalPoints,
    int UnclaimedCount,
    DateTimeOffset UpdatedAt);

internal sealed record AchievementProgressDto(
    string AchievementId,
    string ActionType,
    string Title,
    string Description,
    string Category,
    string MedalName,
    string MedalRarity,
    int Points,
    int CurrentCount,
    int TargetCount,
    bool Unlocked,
    bool Claimed,
    DateTimeOffset? UnlockedAt,
    DateTimeOffset? ClaimedAt,
    int DisplayOrder);

internal sealed record AchievementUnlockDto(
    string AchievementId,
    string Title,
    string Category,
    string MedalName,
    string MedalRarity,
    int Points,
    DateTimeOffset AwardedAt,
    bool Claimed);

internal sealed record AchievementUnlocksResponseDto(
    string PlayerId,
    AchievementUnlockDto[] Unlocks,
    DateTimeOffset UpdatedAt);

internal sealed record AchievementTrackRequestDto(
    string ActionType,
    int Quantity,
    string IdempotencyKey,
    string? RelatedId);

internal sealed record AchievementClaimRequestDto(string IdempotencyKey);

internal sealed record AchievementClaimResponseDto(
    bool Completed,
    string Message,
    AchievementProgressDto? Achievement,
    AchievementsSummaryDto Achievements);

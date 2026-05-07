using System.Text.Json;

internal static class OnboardingGatewayTracker
{
    public static async Task<ServiceJsonResult<OnboardingQuestlineResponseDto>> TrackAsync(
        PlayerServiceClient players,
        string playerId,
        string authorization,
        IConfiguration configuration,
        string actionType,
        string idempotencyKey,
        int quantity = 1)
    {
        return await players.PostJsonAsync<OnboardingQuestTrackRequestDto, OnboardingQuestlineResponseDto>(
            $"players/{Uri.EscapeDataString(playerId)}/onboarding-questline/track",
            authorization,
            new OnboardingQuestTrackRequestDto(
                ActionType: actionType,
                Quantity: Math.Max(1, quantity),
                IdempotencyKey: idempotencyKey.ToLowerInvariant()),
            InternalToken(configuration));
    }

    public static bool IsCompletedMutation(JsonElement payload)
    {
        return payload.ValueKind == JsonValueKind.Object &&
            payload.TryGetProperty("completed", out var completed) &&
            completed.ValueKind is JsonValueKind.True or JsonValueKind.False &&
            completed.GetBoolean();
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed record OnboardingQuestlineResponseDto(
    string PlayerId,
    string Status,
    OnboardingQuestDto? CurrentQuest,
    OnboardingQuestDto[] Quests,
    int CompletedCount,
    int TotalCount,
    int CompletionPercent,
    DateTimeOffset UpdatedAt);

internal sealed record OnboardingQuestDto(
    string QuestId,
    string ActionType,
    string Title,
    string Description,
    string Guidance,
    string? Route,
    int CurrentCount,
    int TargetCount,
    PlayerRewardsDto Rewards,
    bool Completed,
    bool Claimed,
    bool Skipped,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? ClaimedAt,
    DateTimeOffset? SkippedAt,
    int DisplayOrder);

internal sealed record OnboardingQuestTrackRequestDto(
    string ActionType,
    int Quantity,
    string IdempotencyKey);

internal sealed record OnboardingQuestClaimRequestDto(string IdempotencyKey);

internal sealed record OnboardingQuestSkipRequestDto(string IdempotencyKey);

internal sealed record OnboardingQuestClaimResponseDto(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    object? State,
    OnboardingQuestDto? Quest,
    OnboardingQuestlineResponseDto Questline);

internal sealed record OnboardingQuestSkipResponseDto(
    bool Completed,
    string Message,
    OnboardingQuestDto? Quest,
    OnboardingQuestlineResponseDto Questline);

internal sealed record OnboardingQuestClaimGatewayResponse(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    object? State,
    OnboardingQuestDto? Quest,
    OnboardingQuestlineResponseDto Questline,
    InventoryResponseDto? Wallet);

internal sealed record GatewayMutationResponseDto(
    bool Completed,
    string Message);

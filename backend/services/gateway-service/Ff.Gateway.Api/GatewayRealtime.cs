internal static class RealtimeGatewayEndpoints
{
    private const int DefaultLimit = 50;
    private const int MaximumLimit = 100;
    private const int PollAfterSeconds = 8;

    public static void MapRealtimeGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/players/{playerId}/realtime/updates", GetRealtimeUpdates)
            .WithName("GetGatewayRealtimeUpdates");
    }

    private static async Task<IResult> GetRealtimeUpdates(
        string playerId,
        DateTimeOffset? since,
        string? chatToId,
        int? limit,
        HttpRequest request,
        NotificationServiceClient notifications,
        SocialChatServiceClient socialChat,
        ProductionServiceClient production,
        WorldServiceClient world,
        MarketServiceClient market,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var authorization = request.Headers.Authorization.ToString();
        var player = access.PlayerId!;
        var safeLimit = Math.Clamp(limit ?? DefaultLimit, 1, MaximumLimit);
        var sinceUtc = since?.ToUniversalTime();
        var generatedAt = DateTimeOffset.UtcNow;
        var errors = new List<RealtimeUpdateError>();

        var productionResult = await ReadProductionAsync(
            production,
            player,
            authorization,
            sinceUtc,
            generatedAt);
        AddError(errors, productionResult.Error);

        if (productionResult.Section is not null)
        {
            await EmitProductionCompletionActivityAsync(
                notifications,
                configuration,
                player,
                productionResult.Section.CompletedJobs,
                sinceUtc);
        }

        var activityResult = await ReadActivityAsync(
            notifications,
            configuration,
            player,
            authorization,
            safeLimit,
            sinceUtc);
        AddError(errors, activityResult.Error);

        var chatResult = await ReadChatAsync(
            socialChat,
            player,
            NormalizeChatToId(chatToId),
            sinceUtc,
            generatedAt);
        AddError(errors, chatResult.Error);

        var battleResult = await ReadBattlesAsync(world, authorization, sinceUtc, generatedAt);
        AddError(errors, battleResult.Error);

        var marketResult = await ReadMarketAsync(market, player, authorization, sinceUtc, generatedAt);
        AddError(errors, marketResult.Error);

        var changedSections = new List<string>();
        AddChangedSection(changedSections, "activity", activityResult.Section);
        AddChangedSection(changedSections, "chat", chatResult.Section);
        AddChangedSection(changedSections, "production", productionResult.Section);
        AddChangedSection(changedSections, "battles", battleResult.Section);
        AddChangedSection(changedSections, "market", marketResult.Section);

        return Results.Ok(new RealtimeUpdatesResponse(
            PlayerId: player,
            Since: sinceUtc,
            GeneratedAt: generatedAt,
            NextCursor: generatedAt,
            PollAfterSeconds: PollAfterSeconds,
            HasChanges: changedSections.Count > 0,
            ChangedSections: changedSections.ToArray(),
            Activity: activityResult.Section,
            Chat: chatResult.Section,
            Production: productionResult.Section,
            Battles: battleResult.Section,
            Market: marketResult.Section,
            Errors: errors.ToArray()));
    }

    private static async Task<RealtimeSectionReadResult<RealtimeActivitySection>> ReadActivityAsync(
        NotificationServiceClient notifications,
        IConfiguration configuration,
        string playerId,
        string authorization,
        int limit,
        DateTimeOffset? since)
    {
        var result = await notifications.GetJsonAsync<RealtimeActivityFeedDto>(
            $"players/{Uri.EscapeDataString(playerId)}/activity?limit={limit}",
            authorization,
            InternalToken(configuration));
        if (result.Value is null)
        {
            return RealtimeSectionReadResult<RealtimeActivitySection>.Failed(
                "activity",
                "Activity feed is temporarily unavailable.");
        }

        var feed = result.Value;
        return RealtimeSectionReadResult<RealtimeActivitySection>.Succeeded(
            new RealtimeActivitySection(
                HasChanges: since is null || feed.Events.Any(activity => IsAfter(activity.CreatedAt, since)),
                PlayerId: feed.PlayerId,
                Events: feed.Events,
                UnreadCount: feed.UnreadCount,
                UpdatedAt: feed.UpdatedAt));
    }

    private static async Task<RealtimeSectionReadResult<RealtimeChatSection>> ReadChatAsync(
        SocialChatServiceClient socialChat,
        string playerId,
        string toId,
        DateTimeOffset? since,
        DateTimeOffset generatedAt)
    {
        var result = await socialChat.GetJsonAsync<MessageDto[]>(
            BuildChatPath(playerId, toId),
            authorizationHeader: string.Empty);
        if (result.Value is null)
        {
            return RealtimeSectionReadResult<RealtimeChatSection>.Failed(
                "chat",
                "Chat messages are temporarily unavailable.");
        }

        var messages = result.Value;
        var updatedAt = messages
            .Select(message => message.CreatedAt ?? generatedAt)
            .DefaultIfEmpty(generatedAt)
            .Max();

        return RealtimeSectionReadResult<RealtimeChatSection>.Succeeded(
            new RealtimeChatSection(
                HasChanges: since is null || messages.Any(message => IsAfter(message.CreatedAt, since)),
                ToId: toId,
                Messages: messages,
                UpdatedAt: updatedAt));
    }

    private static async Task<RealtimeSectionReadResult<RealtimeProductionSection>> ReadProductionAsync(
        ProductionServiceClient production,
        string playerId,
        string authorization,
        DateTimeOffset? since,
        DateTimeOffset generatedAt)
    {
        var result = await production.GetJsonAsync<ProductionJobsResponseDto>(
            $"players/{Uri.EscapeDataString(playerId)}/production-jobs",
            authorization);
        if (result.Value is null)
        {
            return RealtimeSectionReadResult<RealtimeProductionSection>.Failed(
                "production",
                "Production jobs are temporarily unavailable.");
        }

        var jobs = result.Value.Jobs;
        var completedJobs = jobs
            .Where(job => string.Equals(job.Status, "completed", StringComparison.OrdinalIgnoreCase) && job.CanClaim)
            .ToArray();

        return RealtimeSectionReadResult<RealtimeProductionSection>.Succeeded(
            new RealtimeProductionSection(
                HasChanges: since is null || jobs.Any(job =>
                    IsAfter(job.UpdatedAt, since) ||
                    IsAfter(job.CompletedAt, since)),
                PlayerId: result.Value.PlayerId,
                Jobs: jobs,
                CompletedJobs: completedJobs,
                UpdatedAt: MaxTimestamp(
                    jobs.Select(job => (DateTimeOffset?)job.UpdatedAt)
                        .Append(result.Value.UpdatedAt),
                    generatedAt)));
    }

    private static async Task<RealtimeSectionReadResult<RealtimeBattleSection>> ReadBattlesAsync(
        WorldServiceClient world,
        string authorization,
        DateTimeOffset? since,
        DateTimeOffset generatedAt)
    {
        var result = await world.GetJsonAsync<RealtimeBattleListDto>(
            "battles?status=current",
            authorization);
        if (result.Value is null)
        {
            return RealtimeSectionReadResult<RealtimeBattleSection>.Failed(
                "battles",
                "Battle updates are temporarily unavailable.");
        }

        var battles = result.Value.Battles;
        return RealtimeSectionReadResult<RealtimeBattleSection>.Succeeded(
            new RealtimeBattleSection(
                HasChanges: since is null || battles.Any(battle => IsAfter(battle.UpdatedAt, since)),
                Battles: battles,
                UpdatedAt: MaxTimestamp(
                    battles.Select(battle => (DateTimeOffset?)battle.UpdatedAt)
                        .Append(result.Value.UpdatedAt),
                    generatedAt)));
    }

    private static async Task<RealtimeSectionReadResult<RealtimeMarketSection>> ReadMarketAsync(
        MarketServiceClient market,
        string playerId,
        string authorization,
        DateTimeOffset? since,
        DateTimeOffset generatedAt)
    {
        var listingsResult = await market.GetJsonAsync<RealtimeMarketListingsDto>(
            "market/listings",
            authorization);
        var playerListingsResult = await market.GetJsonAsync<RealtimeSellerMarketListingsDto>(
            $"players/{Uri.EscapeDataString(playerId)}/market/listings",
            authorization);

        if (listingsResult.Value is null && playerListingsResult.Value is null)
        {
            return RealtimeSectionReadResult<RealtimeMarketSection>.Failed(
                "market",
                "Market updates are temporarily unavailable.");
        }

        var listings = listingsResult.Value?.Listings ?? Array.Empty<MarketListingDto>();
        var playerListings = playerListingsResult.Value
            ?? new RealtimeSellerMarketListingsDto(
                SellerId: playerId,
                Listings: Array.Empty<MarketListingDto>(),
                UpdatedAt: generatedAt);
        var timestamps = listings
            .Select(listing => listing.UpdatedAt)
            .Concat(playerListings.Listings.Select(listing => listing.UpdatedAt))
            .Append(listingsResult.Value?.UpdatedAt)
            .Append(playerListings.UpdatedAt);

        return RealtimeSectionReadResult<RealtimeMarketSection>.Succeeded(
            new RealtimeMarketSection(
                HasChanges: since is null || timestamps.Any(timestamp => IsAfter(timestamp, since)),
                Listings: listings,
                PlayerListings: playerListings,
                UpdatedAt: MaxTimestamp(timestamps, generatedAt)));
    }

    private static async Task EmitProductionCompletionActivityAsync(
        NotificationServiceClient notifications,
        IConfiguration configuration,
        string playerId,
        ProductionJobDto[] completedJobs,
        DateTimeOffset? since)
    {
        foreach (var job in completedJobs.Where(job =>
            since is null ||
            IsAfter(job.CompletedAt, since) ||
            IsAfter(job.UpdatedAt, since)))
        {
            await ActivityGatewayEndpoints.EmitAsync(
                notifications,
                configuration,
                playerId,
                "production_completed",
                $"{job.OutputItemName} production is complete and ready to claim.",
                job.JobId,
                $"activity:production-completed:{playerId.ToLowerInvariant()}:{job.JobId.ToLowerInvariant()}");
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
                new ErrorResponse("You cannot subscribe to another player's live updates."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string BuildChatPath(string playerId, string toId)
    {
        return string.Equals(toId, "global", StringComparison.OrdinalIgnoreCase)
            ? "messages?toId=global"
            : $"messages?fromId={Uri.EscapeDataString(playerId)}&toId={Uri.EscapeDataString(toId)}";
    }

    private static string NormalizeChatToId(string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? "global"
            : value.Trim().ToLowerInvariant();
    }

    private static bool IsAfter(DateTimeOffset? timestamp, DateTimeOffset? since)
    {
        return since is null || (timestamp is not null && timestamp.Value > since.Value);
    }

    private static DateTimeOffset MaxTimestamp(IEnumerable<DateTimeOffset?> timestamps, DateTimeOffset fallback)
    {
        return timestamps
            .Where(timestamp => timestamp is not null)
            .Select(timestamp => timestamp!.Value)
            .DefaultIfEmpty(fallback)
            .Max();
    }

    private static void AddError(List<RealtimeUpdateError> errors, RealtimeUpdateError? error)
    {
        if (error is not null)
        {
            errors.Add(error);
        }
    }

    private static void AddChangedSection<T>(List<string> sections, string sectionName, T? section)
        where T : IRealtimeSection
    {
        if (section?.HasChanges == true)
        {
            sections.Add(sectionName);
        }
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal interface IRealtimeSection
{
    bool HasChanges { get; }
}

internal sealed record RealtimeUpdatesResponse(
    string PlayerId,
    DateTimeOffset? Since,
    DateTimeOffset GeneratedAt,
    DateTimeOffset NextCursor,
    int PollAfterSeconds,
    bool HasChanges,
    string[] ChangedSections,
    RealtimeActivitySection? Activity,
    RealtimeChatSection? Chat,
    RealtimeProductionSection? Production,
    RealtimeBattleSection? Battles,
    RealtimeMarketSection? Market,
    RealtimeUpdateError[] Errors);

internal sealed record RealtimeActivitySection(
    bool HasChanges,
    string PlayerId,
    ActivityEventDto[] Events,
    int UnreadCount,
    DateTimeOffset UpdatedAt) : IRealtimeSection;

internal sealed record RealtimeChatSection(
    bool HasChanges,
    string ToId,
    MessageDto[] Messages,
    DateTimeOffset UpdatedAt) : IRealtimeSection;

internal sealed record RealtimeProductionSection(
    bool HasChanges,
    string PlayerId,
    ProductionJobDto[] Jobs,
    ProductionJobDto[] CompletedJobs,
    DateTimeOffset UpdatedAt) : IRealtimeSection;

internal sealed record RealtimeBattleSection(
    bool HasChanges,
    CountryBattleDto[] Battles,
    DateTimeOffset UpdatedAt) : IRealtimeSection;

internal sealed record RealtimeMarketSection(
    bool HasChanges,
    MarketListingDto[] Listings,
    RealtimeSellerMarketListingsDto PlayerListings,
    DateTimeOffset UpdatedAt) : IRealtimeSection;

internal sealed record RealtimeUpdateError(string Section, string Message);

internal sealed record RealtimeActivityFeedDto(
    string PlayerId,
    ActivityEventDto[] Events,
    int UnreadCount,
    DateTimeOffset UpdatedAt);

internal sealed record RealtimeBattleListDto(
    CountryBattleDto[] Battles,
    DateTimeOffset UpdatedAt);

internal sealed record RealtimeMarketListingsDto(
    MarketListingDto[] Listings,
    DateTimeOffset UpdatedAt);

internal sealed record RealtimeSellerMarketListingsDto(
    string SellerId,
    MarketListingDto[] Listings,
    DateTimeOffset UpdatedAt);

internal sealed record RealtimeSectionReadResult<T>(T? Section, RealtimeUpdateError? Error)
    where T : IRealtimeSection
{
    public static RealtimeSectionReadResult<T> Succeeded(T section)
    {
        return new RealtimeSectionReadResult<T>(section, null);
    }

    public static RealtimeSectionReadResult<T> Failed(string section, string message)
    {
        return new RealtimeSectionReadResult<T>(default, new RealtimeUpdateError(section, message));
    }
}

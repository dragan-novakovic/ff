internal static class NewspaperGatewayEndpoints
{
    public static void MapNewspaperGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/players/{playerId}/media/newspapers", async (
            string playerId,
            int? limit,
            HttpRequest request,
            SocialChatServiceClient socialChat,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var safeLimit = Math.Clamp(limit ?? 25, 1, 100);
            return await socialChat.GetAsync(
                $"newspapers?playerId={Uri.EscapeDataString(access.PlayerId!)}&limit={safeLimit}",
                request.Headers.Authorization.ToString());
        }).WithName("ListGatewayNewspapers");

        app.MapPost("/players/{playerId}/media/newspapers", async (
            string playerId,
            CreateNewspaperGatewayRequest createRequest,
            HttpRequest request,
            SocialChatServiceClient socialChat,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateNewspaper(createRequest);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await socialChat.PostJsonAsync<CreateNewspaperGatewayRequest, NewspaperMutationResultDto>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/newspapers",
                request.Headers.Authorization.ToString(),
                createRequest);
            return result.Error is not null
                ? result.Error
                : Results.Ok(result.Value!);
        }).WithName("CreateGatewayNewspaper");

        app.MapGet("/players/{playerId}/media/newspapers/{newspaperId}/articles", async (
            string playerId,
            string newspaperId,
            int? limit,
            HttpRequest request,
            SocialChatServiceClient socialChat,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var safeLimit = Math.Clamp(limit ?? 25, 1, 100);
            return await socialChat.GetAsync(
                $"newspapers/{Uri.EscapeDataString(newspaperId)}/articles?playerId={Uri.EscapeDataString(access.PlayerId!)}&limit={safeLimit}",
                request.Headers.Authorization.ToString());
        }).WithName("ListGatewayNewspaperArticles");

        app.MapPost("/players/{playerId}/media/newspapers/{newspaperId}/articles", PublishArticle)
            .WithName("PublishGatewayNewspaperArticle");

        app.MapGet("/players/{playerId}/media/articles/{articleId}", async (
            string playerId,
            string articleId,
            HttpRequest request,
            SocialChatServiceClient socialChat,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await socialChat.GetAsync(
                $"articles/{Uri.EscapeDataString(articleId)}?playerId={Uri.EscapeDataString(access.PlayerId!)}",
                request.Headers.Authorization.ToString());
        }).WithName("ReadGatewayNewspaperArticle");

        app.MapPost("/players/{playerId}/media/articles/{articleId}/comments", CommentOnArticle)
            .WithName("CommentGatewayNewspaperArticle");

        app.MapPost("/players/{playerId}/media/articles/{articleId}/votes", async (
            string playerId,
            string articleId,
            VoteArticleGatewayRequest voteRequest,
            HttpRequest request,
            SocialChatServiceClient socialChat,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }
            if (voteRequest.Value is not 1 and not -1)
            {
                return Results.BadRequest(new ErrorResponse("Vote value must be 1 or -1."));
            }

            var result = await socialChat.PostJsonAsync<VoteArticleGatewayRequest, ArticleVoteResultDto>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/articles/{Uri.EscapeDataString(articleId)}/votes",
                request.Headers.Authorization.ToString(),
                voteRequest);
            return result.Error is not null
                ? result.Error
                : Results.Ok(result.Value!);
        }).WithName("VoteGatewayNewspaperArticle");

        app.MapPost("/players/{playerId}/media/newspapers/{newspaperId}/subscribe", SubscribeToNewspaper)
            .WithName("SubscribeGatewayNewspaper");

        app.MapPost("/players/{playerId}/media/newspapers/{newspaperId}/report", ReportNewspaper)
            .WithName("ReportGatewayNewspaper");

        app.MapPost("/players/{playerId}/media/articles/{articleId}/report", ReportArticle)
            .WithName("ReportGatewayNewspaperArticle");

        app.MapPost("/players/{playerId}/media/articles/{articleId}/comments/{commentId}/report", ReportArticleComment)
            .WithName("ReportGatewayNewspaperArticleComment");
    }

    private static async Task<IResult> PublishArticle(
        string playerId,
        string newspaperId,
        PublishArticleGatewayRequest articleRequest,
        HttpRequest request,
        SocialChatServiceClient socialChat,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var validation = ValidateArticle(articleRequest);
        if (validation is not null)
        {
            return Results.BadRequest(new ErrorResponse(validation));
        }

        var result = await socialChat.PostJsonAsync<PublishArticleGatewayRequest, ArticlePublicationResultDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/newspapers/{Uri.EscapeDataString(newspaperId)}/articles",
            request.Headers.Authorization.ToString(),
            articleRequest);
        if (result.Error is not null)
        {
            return result.Error;
        }

        var published = result.Value!;
        if (published.Completed)
        {
            await ActivityGatewayEndpoints.EmitAsync(
                notifications,
                configuration,
                access.PlayerId!,
                "newspaper_article_published",
                $"Published \"{published.Article.Title}\" in {published.Article.NewspaperName}.",
                published.Article.ArticleId,
                $"activity:newspaper-article:{access.PlayerId!.ToLowerInvariant()}:{published.Article.ArticleId.ToLowerInvariant()}");

            foreach (var subscriberId in published.SubscriberPlayerIds
                .Where(candidate => !string.IsNullOrWhiteSpace(candidate))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(100))
            {
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    subscriberId,
                    "newspaper_article_published",
                    $"{published.Article.NewspaperName} published \"{published.Article.Title}\".",
                    published.Article.ArticleId,
                    $"activity:newspaper-article-subscriber:{subscriberId.ToLowerInvariant()}:{published.Article.ArticleId.ToLowerInvariant()}");
            }
        }

        return Results.Ok(published);
    }

    private static async Task<IResult> CommentOnArticle(
        string playerId,
        string articleId,
        AddArticleCommentGatewayRequest commentRequest,
        HttpRequest request,
        SocialChatServiceClient socialChat,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var content = commentRequest.Content?.Trim();
        if (content is not { Length: >= 1 and <= 1000 })
        {
            return Results.BadRequest(new ErrorResponse("Comment content must be between 1 and 1000 characters."));
        }

        var result = await socialChat.PostJsonAsync<AddArticleCommentGatewayRequest, ArticleCommentResultDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/articles/{Uri.EscapeDataString(articleId)}/comments",
            request.Headers.Authorization.ToString(),
            new AddArticleCommentGatewayRequest(content));
        if (result.Error is not null)
        {
            return result.Error;
        }

        var commented = result.Value!;
        if (commented.Completed)
        {
            await ActivityGatewayEndpoints.EmitAsync(
                notifications,
                configuration,
                access.PlayerId!,
                "newspaper_article_comment",
                $"Commented on \"{commented.Article.Title}\".",
                commented.Article.ArticleId,
                $"activity:newspaper-comment:{access.PlayerId!.ToLowerInvariant()}:{commented.Comment.CommentId.ToLowerInvariant()}");

            foreach (var recipientId in new[] { commented.Article.AuthorPlayerId, commented.Article.NewspaperOwnerPlayerId }
                .Where(candidate => !string.Equals(candidate, access.PlayerId, StringComparison.OrdinalIgnoreCase))
                .Distinct(StringComparer.OrdinalIgnoreCase))
            {
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    recipientId,
                    "newspaper_article_comment",
                    $"{access.PlayerId} commented on \"{commented.Article.Title}\".",
                    commented.Article.ArticleId,
                    $"activity:newspaper-comment-recipient:{recipientId.ToLowerInvariant()}:{commented.Comment.CommentId.ToLowerInvariant()}");
            }
        }

        return Results.Ok(commented);
    }

    private static async Task<IResult> SubscribeToNewspaper(
        string playerId,
        string newspaperId,
        NewspaperSubscriptionGatewayRequest subscriptionRequest,
        HttpRequest request,
        SocialChatServiceClient socialChat,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var normalizedRequest = new NewspaperSubscriptionGatewayRequest(subscriptionRequest.Subscribe ?? true);
        var result = await socialChat.PostJsonAsync<NewspaperSubscriptionGatewayRequest, NewspaperSubscriptionResultDto>(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/newspapers/{Uri.EscapeDataString(newspaperId)}/subscriptions",
            request.Headers.Authorization.ToString(),
            normalizedRequest);
        if (result.Error is not null)
        {
            return result.Error;
        }

        var subscription = result.Value!;
        if (subscription.Completed && subscription.IsSubscribed)
        {
            await ActivityGatewayEndpoints.EmitAsync(
                notifications,
                configuration,
                access.PlayerId!,
                "newspaper_subscription",
                $"Subscribed to {subscription.Newspaper.Name}.",
                subscription.Newspaper.NewspaperId,
                $"activity:newspaper-subscription:{access.PlayerId!.ToLowerInvariant()}:{subscription.Newspaper.NewspaperId.ToLowerInvariant()}");

            if (!string.Equals(subscription.Newspaper.OwnerPlayerId, access.PlayerId, StringComparison.OrdinalIgnoreCase))
            {
                await ActivityGatewayEndpoints.EmitAsync(
                    notifications,
                    configuration,
                    subscription.Newspaper.OwnerPlayerId,
                    "newspaper_subscription",
                    $"{access.PlayerId} subscribed to {subscription.Newspaper.Name}.",
                    subscription.Newspaper.NewspaperId,
                    $"activity:newspaper-subscription-owner:{subscription.Newspaper.OwnerPlayerId.ToLowerInvariant()}:{subscription.Newspaper.NewspaperId.ToLowerInvariant()}:{access.PlayerId!.ToLowerInvariant()}");
            }
        }

        return Results.Ok(subscription);
    }

    private static async Task<IResult> ReportNewspaper(
        string playerId,
        string newspaperId,
        ContentReportGatewayRequest reportRequest,
        HttpRequest request,
        SocialChatServiceClient socialChat,
        AdminServiceClient adminService,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var validation = ValidateReport(reportRequest);
        if (validation.Error is not null)
        {
            return validation.Error;
        }

        var newspaper = await socialChat.GetJsonAsync<NewspaperDto>(
            $"newspapers/{Uri.EscapeDataString(newspaperId)}?playerId={Uri.EscapeDataString(access.PlayerId!)}",
            request.Headers.Authorization.ToString());
        if (newspaper.Error is not null)
        {
            return newspaper.Error;
        }

        var value = newspaper.Value!;
        return await SubmitContentReportAsync(
            adminService,
            configuration,
            access.PlayerId!,
            new AdminCreateContentQueueItemRequest(
                SourceType: "newspaper",
                SourceId: value.NewspaperId,
                PlayerId: value.OwnerPlayerId,
                Content: $"{value.Name}\n{value.Description}".Trim(),
                Reason: validation.Reason!,
                ReporterPlayerId: access.PlayerId!,
                Details: validation.Details));
    }

    private static async Task<IResult> ReportArticle(
        string playerId,
        string articleId,
        ContentReportGatewayRequest reportRequest,
        HttpRequest request,
        SocialChatServiceClient socialChat,
        AdminServiceClient adminService,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var validation = ValidateReport(reportRequest);
        if (validation.Error is not null)
        {
            return validation.Error;
        }

        var article = await socialChat.GetJsonAsync<NewspaperArticleDto>(
            $"articles/{Uri.EscapeDataString(articleId)}?playerId={Uri.EscapeDataString(access.PlayerId!)}",
            request.Headers.Authorization.ToString());
        if (article.Error is not null)
        {
            return article.Error;
        }

        var value = article.Value!;
        return await SubmitContentReportAsync(
            adminService,
            configuration,
            access.PlayerId!,
            new AdminCreateContentQueueItemRequest(
                SourceType: "article",
                SourceId: value.ArticleId,
                PlayerId: value.AuthorPlayerId,
                Content: $"{value.Title}\n{value.Content}".Trim(),
                Reason: validation.Reason!,
                ReporterPlayerId: access.PlayerId!,
                Details: validation.Details));
    }

    private static async Task<IResult> ReportArticleComment(
        string playerId,
        string articleId,
        string commentId,
        ContentReportGatewayRequest reportRequest,
        HttpRequest request,
        SocialChatServiceClient socialChat,
        AdminServiceClient adminService,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var validation = ValidateReport(reportRequest);
        if (validation.Error is not null)
        {
            return validation.Error;
        }

        var article = await socialChat.GetJsonAsync<NewspaperArticleDto>(
            $"articles/{Uri.EscapeDataString(articleId)}?playerId={Uri.EscapeDataString(access.PlayerId!)}",
            request.Headers.Authorization.ToString());
        if (article.Error is not null)
        {
            return article.Error;
        }

        var value = article.Value!;
        var comment = value.Comments.FirstOrDefault(candidate =>
            string.Equals(candidate.CommentId, commentId, StringComparison.OrdinalIgnoreCase));
        if (comment is null)
        {
            return Results.NotFound(new ErrorResponse("Comment was not found."));
        }

        return await SubmitContentReportAsync(
            adminService,
            configuration,
            access.PlayerId!,
            new AdminCreateContentQueueItemRequest(
                SourceType: "article_comment",
                SourceId: comment.CommentId,
                PlayerId: comment.AuthorPlayerId,
                Content: comment.Content,
                Reason: validation.Reason!,
                ReporterPlayerId: access.PlayerId!,
                Details: string.IsNullOrWhiteSpace(validation.Details)
                    ? $"Article: {value.ArticleId} ({value.Title})"
                    : $"{validation.Details}\nArticle: {value.ArticleId} ({value.Title})"));
    }

    private static async Task<IResult> SubmitContentReportAsync(
        AdminServiceClient adminService,
        IConfiguration configuration,
        string reporterPlayerId,
        AdminCreateContentQueueItemRequest queueRequest)
    {
        var adminToken = configuration["FF_ADMIN_TOKEN"]
            ?? configuration["Admin:Token"];
        if (string.IsNullOrWhiteSpace(adminToken))
        {
            return Results.Json(
                new ErrorResponse("Content reporting is disabled because FF_ADMIN_TOKEN is not configured."),
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }

        var item = await adminService.PostJsonAsync<AdminCreateContentQueueItemRequest, AdminContentModerationItemDto>(
            "admin/moderation/content-queue",
            adminToken.Trim(),
            reporterPlayerId,
            queueRequest);
        if (item.Error is not null)
        {
            return item.Error;
        }

        return Results.Ok(new ContentReportGatewayResult(
            Completed: true,
            Message: "Report submitted for moderator review.",
            ItemId: item.Value!.ItemId,
            Status: item.Value.Status,
            ReportCount: item.Value.ReportCount));
    }

    private static ReportValidationResult ValidateReport(ContentReportGatewayRequest request)
    {
        var reason = request.Reason?.Trim();
        if (reason is not { Length: >= 5 and <= 500 })
        {
            return ReportValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
                "Report reason must be between 5 and 500 characters.")));
        }

        var details = request.Details?.Trim();
        if ((details?.Length ?? 0) > 2_000)
        {
            return ReportValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
                "Report details must be 2000 characters or fewer.")));
        }

        return ReportValidationResult.Valid(reason, details);
    }

    private static string? ValidateNewspaper(CreateNewspaperGatewayRequest request)
    {
        var name = request.Name?.Trim();
        if (name is not { Length: >= 3 and <= 80 })
        {
            return "Newspaper name must be between 3 and 80 characters.";
        }
        if ((request.Description?.Trim().Length ?? 0) > 500)
        {
            return "Newspaper description must be 500 characters or fewer.";
        }

        return null;
    }

    private static string? ValidateArticle(PublishArticleGatewayRequest request)
    {
        var title = request.Title?.Trim();
        if (title is not { Length: >= 3 and <= 140 })
        {
            return "Article title must be between 3 and 140 characters.";
        }

        var content = request.Content?.Trim();
        if (content is not { Length: >= 20 and <= 10_000 })
        {
            return "Article content must be between 20 and 10000 characters.";
        }

        return null;
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
                new ErrorResponse("You cannot manage another player's newspapers."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }
}

internal sealed record CreateNewspaperGatewayRequest(string? Name, string? Description);

internal sealed record PublishArticleGatewayRequest(string? Title, string? Content);

internal sealed record AddArticleCommentGatewayRequest(string? Content);

internal sealed record VoteArticleGatewayRequest(int Value);

internal sealed record NewspaperSubscriptionGatewayRequest(bool? Subscribe);

internal sealed record ContentReportGatewayRequest(string? Reason, string? Details);

internal sealed record ContentReportGatewayResult(
    bool Completed,
    string Message,
    string ItemId,
    string Status,
    int ReportCount);

internal sealed record ReportValidationResult(IResult? Error, string? Reason, string? Details)
{
    public static ReportValidationResult Valid(string reason, string? details)
    {
        return new ReportValidationResult(null, reason, details);
    }

    public static ReportValidationResult Invalid(IResult error)
    {
        return new ReportValidationResult(error, null, null);
    }
}

internal sealed record NewspaperCatalogResponseDto(string? PlayerId, NewspaperDto[] Newspapers, DateTimeOffset UpdatedAt);

internal sealed record NewspaperArticleListResponseDto(string NewspaperId, NewspaperArticleDto[] Articles, DateTimeOffset UpdatedAt);

internal sealed record NewspaperMutationResultDto(bool Completed, string Message, NewspaperDto Newspaper);

internal sealed record ArticlePublicationResultDto(
    bool Completed,
    string Message,
    NewspaperArticleDto Article,
    string[] SubscriberPlayerIds);

internal sealed record ArticleCommentResultDto(
    bool Completed,
    string Message,
    NewspaperCommentDto Comment,
    NewspaperArticleDto Article);

internal sealed record ArticleVoteResultDto(bool Completed, string Message, NewspaperArticleDto Article);

internal sealed record NewspaperSubscriptionResultDto(
    bool Completed,
    string Message,
    NewspaperDto Newspaper,
    bool IsSubscribed);

internal sealed record NewspaperDto(
    string NewspaperId,
    string OwnerPlayerId,
    string Name,
    string Description,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    int SubscriberCount,
    int ArticleCount,
    bool IsSubscribed);

internal sealed record NewspaperArticleDto(
    string ArticleId,
    string NewspaperId,
    string NewspaperName,
    string NewspaperOwnerPlayerId,
    string AuthorPlayerId,
    string Title,
    string Content,
    DateTimeOffset PublishedAt,
    DateTimeOffset UpdatedAt,
    int VoteScore,
    int Upvotes,
    int Downvotes,
    int? PlayerVote,
    int CommentCount,
    NewspaperCommentDto[] Comments);

internal sealed record NewspaperCommentDto(
    string CommentId,
    string ArticleId,
    string AuthorPlayerId,
    string Content,
    DateTimeOffset CreatedAt);

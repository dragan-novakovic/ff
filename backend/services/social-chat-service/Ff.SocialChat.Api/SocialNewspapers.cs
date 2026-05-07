using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Npgsql;

internal static class NewspaperEndpoints
{
    public static void MapNewspaperEndpoints(this WebApplication app)
    {
        app.MapGet("/newspapers", async (
            string? playerId,
            int? limit,
            NewspaperStore store) =>
            ToStoreResult(await store.ListNewspapersAsync(playerId, limit)))
            .WithName("ListNewspapers");

        app.MapPost("/players/{playerId}/newspapers", async (
            string playerId,
            CreateNewspaperRequest request,
            NewspaperStore store) =>
            ToStoreResult(await store.CreateNewspaperAsync(playerId, request)))
            .WithName("CreateNewspaper");

        app.MapGet("/newspapers/{newspaperId}", async (
            string newspaperId,
            string? playerId,
            NewspaperStore store) =>
            ToStoreResult(await store.GetNewspaperAsync(newspaperId, playerId)))
            .WithName("GetNewspaper");

        app.MapGet("/newspapers/{newspaperId}/articles", async (
            string newspaperId,
            string? playerId,
            int? limit,
            NewspaperStore store) =>
            ToStoreResult(await store.ListArticlesAsync(newspaperId, playerId, limit)))
            .WithName("ListNewspaperArticles");

        app.MapPost("/players/{playerId}/newspapers/{newspaperId}/articles", async (
            string playerId,
            string newspaperId,
            PublishArticleRequest request,
            NewspaperStore store) =>
            ToStoreResult(await store.PublishArticleAsync(playerId, newspaperId, request)))
            .WithName("PublishNewspaperArticle");

        app.MapGet("/articles/{articleId}", async (
            string articleId,
            string? playerId,
            NewspaperStore store) =>
            ToStoreResult(await store.GetArticleAsync(articleId, playerId)))
            .WithName("GetNewspaperArticle");

        app.MapPost("/players/{playerId}/articles/{articleId}/comments", async (
            string playerId,
            string articleId,
            AddArticleCommentRequest request,
            NewspaperStore store) =>
            ToStoreResult(await store.AddCommentAsync(playerId, articleId, request)))
            .WithName("CommentOnNewspaperArticle");

        app.MapPost("/players/{playerId}/articles/{articleId}/votes", async (
            string playerId,
            string articleId,
            VoteArticleRequest request,
            NewspaperStore store) =>
            ToStoreResult(await store.VoteArticleAsync(playerId, articleId, request)))
            .WithName("VoteOnNewspaperArticle");

        app.MapPost("/players/{playerId}/newspapers/{newspaperId}/subscriptions", async (
            string playerId,
            string newspaperId,
            NewspaperSubscriptionRequest request,
            NewspaperStore store) =>
            ToStoreResult(await store.SetSubscriptionAsync(playerId, newspaperId, request)))
            .WithName("SetNewspaperSubscription");
    }

    private static IResult ToStoreResult<T>(StoreResult<T> result) where T : class
    {
        if (result.StatusCode is >= StatusCodes.Status200OK and < StatusCodes.Status300MultipleChoices)
        {
            return result.StatusCode == StatusCodes.Status200OK
                ? Results.Ok(result.Value)
                : Results.Json(result.Value, statusCode: result.StatusCode);
        }

        return result.StatusCode == StatusCodes.Status404NotFound
            ? Results.NotFound(new ErrorResponse(result.Message ?? "Resource was not found."))
            : Results.Json(
                new ErrorResponse(result.Message ?? "Request failed."),
                statusCode: result.StatusCode);
    }
}

internal sealed class NewspaperStore : IDisposable
{
    private const int DefaultLimit = 25;
    private const int MaximumLimit = 100;
    private readonly NpgsqlDataSource _dataSource;

    public NewspaperStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_SOCIAL_CHAT_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("SocialChat")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS social_chat;

            CREATE TABLE IF NOT EXISTS social_chat.newspapers (
                newspaper_id text PRIMARY KEY,
                owner_player_id text NOT NULL,
                name text NOT NULL,
                description text NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                moderation_status text NOT NULL DEFAULT 'visible',
                moderated_by text NULL,
                moderated_at timestamptz NULL,
                moderation_reason text NOT NULL DEFAULT '',
                CONSTRAINT newspapers_owner_length CHECK (char_length(owner_player_id) BETWEEN 3 AND 80),
                CONSTRAINT newspapers_name_length CHECK (char_length(name) BETWEEN 3 AND 80),
                CONSTRAINT newspapers_description_length CHECK (char_length(description) <= 500)
            );

            ALTER TABLE social_chat.newspapers
                ADD COLUMN IF NOT EXISTS moderation_status text NOT NULL DEFAULT 'visible',
                ADD COLUMN IF NOT EXISTS moderated_by text NULL,
                ADD COLUMN IF NOT EXISTS moderated_at timestamptz NULL,
                ADD COLUMN IF NOT EXISTS moderation_reason text NOT NULL DEFAULT '';

            CREATE INDEX IF NOT EXISTS ix_social_chat_newspapers_owner_updated
                ON social_chat.newspapers (owner_player_id, updated_at DESC);

            CREATE INDEX IF NOT EXISTS ix_social_chat_newspapers_moderation_status
                ON social_chat.newspapers (moderation_status, updated_at DESC);

            CREATE TABLE IF NOT EXISTS social_chat.articles (
                article_id text PRIMARY KEY,
                newspaper_id text NOT NULL REFERENCES social_chat.newspapers (newspaper_id) ON DELETE CASCADE,
                author_player_id text NOT NULL,
                title text NOT NULL,
                content text NOT NULL,
                published_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                moderation_status text NOT NULL DEFAULT 'visible',
                moderated_by text NULL,
                moderated_at timestamptz NULL,
                moderation_reason text NOT NULL DEFAULT '',
                CONSTRAINT articles_author_length CHECK (char_length(author_player_id) BETWEEN 3 AND 80),
                CONSTRAINT articles_title_length CHECK (char_length(title) BETWEEN 3 AND 140),
                CONSTRAINT articles_content_length CHECK (char_length(content) BETWEEN 20 AND 10000)
            );

            ALTER TABLE social_chat.articles
                ADD COLUMN IF NOT EXISTS moderation_status text NOT NULL DEFAULT 'visible',
                ADD COLUMN IF NOT EXISTS moderated_by text NULL,
                ADD COLUMN IF NOT EXISTS moderated_at timestamptz NULL,
                ADD COLUMN IF NOT EXISTS moderation_reason text NOT NULL DEFAULT '';

            CREATE INDEX IF NOT EXISTS ix_social_chat_articles_newspaper_published
                ON social_chat.articles (newspaper_id, published_at DESC);

            CREATE INDEX IF NOT EXISTS ix_social_chat_articles_moderation_status
                ON social_chat.articles (moderation_status, published_at DESC);

            CREATE TABLE IF NOT EXISTS social_chat.article_comments (
                comment_id text PRIMARY KEY,
                article_id text NOT NULL REFERENCES social_chat.articles (article_id) ON DELETE CASCADE,
                author_player_id text NOT NULL,
                content text NOT NULL,
                created_at timestamptz NOT NULL,
                moderation_status text NOT NULL DEFAULT 'visible',
                moderated_by text NULL,
                moderated_at timestamptz NULL,
                moderation_reason text NOT NULL DEFAULT '',
                CONSTRAINT article_comments_author_length CHECK (char_length(author_player_id) BETWEEN 3 AND 80),
                CONSTRAINT article_comments_content_length CHECK (char_length(content) BETWEEN 1 AND 1000)
            );

            ALTER TABLE social_chat.article_comments
                ADD COLUMN IF NOT EXISTS moderation_status text NOT NULL DEFAULT 'visible',
                ADD COLUMN IF NOT EXISTS moderated_by text NULL,
                ADD COLUMN IF NOT EXISTS moderated_at timestamptz NULL,
                ADD COLUMN IF NOT EXISTS moderation_reason text NOT NULL DEFAULT '';

            CREATE INDEX IF NOT EXISTS ix_social_chat_article_comments_article_created
                ON social_chat.article_comments (article_id, created_at ASC);

            CREATE INDEX IF NOT EXISTS ix_social_chat_article_comments_moderation_status
                ON social_chat.article_comments (moderation_status, created_at DESC);

            CREATE TABLE IF NOT EXISTS social_chat.article_votes (
                article_id text NOT NULL REFERENCES social_chat.articles (article_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                value smallint NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (article_id, player_id),
                CONSTRAINT article_votes_player_length CHECK (char_length(player_id) BETWEEN 3 AND 80),
                CONSTRAINT article_votes_value CHECK (value IN (-1, 1))
            );

            CREATE INDEX IF NOT EXISTS ix_social_chat_article_votes_article
                ON social_chat.article_votes (article_id);

            CREATE TABLE IF NOT EXISTS social_chat.newspaper_subscriptions (
                newspaper_id text NOT NULL REFERENCES social_chat.newspapers (newspaper_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                created_at timestamptz NOT NULL,
                PRIMARY KEY (newspaper_id, player_id),
                CONSTRAINT newspaper_subscriptions_player_length CHECK (char_length(player_id) BETWEEN 3 AND 80)
            );

            CREATE INDEX IF NOT EXISTS ix_social_chat_newspaper_subscriptions_player
                ON social_chat.newspaper_subscriptions (player_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<StoreResult<NewspaperCatalogResponse>> ListNewspapersAsync(string? playerId, int? limit)
    {
        var viewerPlayerId = NormalizeOptionalPlayerId(playerId);
        var safeLimit = Math.Clamp(limit ?? DefaultLimit, 1, MaximumLimit);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT
                n.newspaper_id,
                n.owner_player_id,
                n.name,
                n.description,
                n.created_at,
                n.updated_at,
                (SELECT COUNT(*) FROM social_chat.newspaper_subscriptions s WHERE s.newspaper_id = n.newspaper_id) AS subscriber_count,
                (SELECT COUNT(*) FROM social_chat.articles a WHERE a.newspaper_id = n.newspaper_id AND a.moderation_status <> 'removed') AS article_count,
                EXISTS (
                    SELECT 1
                    FROM social_chat.newspaper_subscriptions s
                    WHERE s.newspaper_id = n.newspaper_id AND s.player_id = @viewer_player_id
                ) AS is_subscribed
            FROM social_chat.newspapers n
            WHERE n.moderation_status <> 'removed'
            ORDER BY n.updated_at DESC, n.created_at DESC, n.newspaper_id ASC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("viewer_player_id", viewerPlayerId ?? string.Empty);
        command.Parameters.AddWithValue("limit", safeLimit);

        var newspapers = new List<NewspaperDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            newspapers.Add(ReadNewspaper(reader));
        }

        return StoreResult<NewspaperCatalogResponse>.Ok(new NewspaperCatalogResponse(
            PlayerId: viewerPlayerId,
            Newspapers: newspapers.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<NewspaperMutationResult>> CreateNewspaperAsync(
        string playerId,
        CreateNewspaperRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        if (normalizedPlayerId is null)
        {
            return StoreResult<NewspaperMutationResult>.BadRequest("Player id is required.");
        }

        var name = request.Name?.Trim();
        if (name is not { Length: >= 3 and <= 80 })
        {
            return StoreResult<NewspaperMutationResult>.BadRequest("Newspaper name must be between 3 and 80 characters.");
        }

        var description = request.Description?.Trim() ?? string.Empty;
        if (description.Length > 500)
        {
            return StoreResult<NewspaperMutationResult>.BadRequest("Newspaper description must be 500 characters or fewer.");
        }

        var now = DateTimeOffset.UtcNow;
        var newspaperId = $"newspaper-{Guid.NewGuid():N}";
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using (var command = new NpgsqlCommand("""
            INSERT INTO social_chat.newspapers (
                newspaper_id, owner_player_id, name, description, created_at, updated_at
            )
            VALUES (
                @newspaper_id, @owner_player_id, @name, @description, @created_at, @updated_at
            );
            """, connection))
        {
            command.Parameters.AddWithValue("newspaper_id", newspaperId);
            command.Parameters.AddWithValue("owner_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("name", name);
            command.Parameters.AddWithValue("description", description);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var newspaper = await GetNewspaperSummaryAsync(connection, newspaperId, normalizedPlayerId);
        return StoreResult<NewspaperMutationResult>.Created(new NewspaperMutationResult(
            Completed: true,
            Message: $"Created newspaper {name}.",
            Newspaper: newspaper!));
    }

    public async Task<StoreResult<NewspaperDto>> GetNewspaperAsync(string newspaperId, string? playerId)
    {
        var normalizedNewspaperId = NormalizeResourceId(newspaperId);
        if (normalizedNewspaperId is null)
        {
            return StoreResult<NewspaperDto>.BadRequest("Newspaper id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var newspaper = await GetNewspaperSummaryAsync(
            connection,
            normalizedNewspaperId,
            NormalizeOptionalPlayerId(playerId));
        return newspaper is null
            ? StoreResult<NewspaperDto>.NotFound("Newspaper was not found.")
            : StoreResult<NewspaperDto>.Ok(newspaper);
    }

    public async Task<StoreResult<NewspaperArticleListResponse>> ListArticlesAsync(
        string newspaperId,
        string? playerId,
        int? limit)
    {
        var normalizedNewspaperId = NormalizeResourceId(newspaperId);
        if (normalizedNewspaperId is null)
        {
            return StoreResult<NewspaperArticleListResponse>.BadRequest("Newspaper id is required.");
        }

        var viewerPlayerId = NormalizeOptionalPlayerId(playerId);
        var safeLimit = Math.Clamp(limit ?? DefaultLimit, 1, MaximumLimit);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var newspaper = await GetNewspaperSummaryAsync(connection, normalizedNewspaperId, viewerPlayerId);
        if (newspaper is null)
        {
            return StoreResult<NewspaperArticleListResponse>.NotFound("Newspaper was not found.");
        }

        var articleIds = new List<string>();
        await using (var command = new NpgsqlCommand("""
            SELECT article_id
            FROM social_chat.articles
            WHERE newspaper_id = @newspaper_id
                AND moderation_status <> 'removed'
            ORDER BY published_at DESC, article_id DESC
            LIMIT @limit;
            """, connection))
        {
            command.Parameters.AddWithValue("newspaper_id", normalizedNewspaperId);
            command.Parameters.AddWithValue("limit", safeLimit);
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                articleIds.Add(reader.GetString(0));
            }
        }

        var articles = new List<NewspaperArticleDto>();
        foreach (var articleId in articleIds)
        {
            var article = await GetArticleInternalAsync(connection, articleId, viewerPlayerId, includeComments: false);
            if (article is not null)
            {
                articles.Add(article);
            }
        }

        return StoreResult<NewspaperArticleListResponse>.Ok(new NewspaperArticleListResponse(
            NewspaperId: normalizedNewspaperId,
            Articles: articles.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ArticlePublicationResult>> PublishArticleAsync(
        string playerId,
        string newspaperId,
        PublishArticleRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedNewspaperId = NormalizeResourceId(newspaperId);
        if (normalizedPlayerId is null || normalizedNewspaperId is null)
        {
            return StoreResult<ArticlePublicationResult>.BadRequest("Player id and newspaper id are required.");
        }

        var title = request.Title?.Trim();
        if (title is not { Length: >= 3 and <= 140 })
        {
            return StoreResult<ArticlePublicationResult>.BadRequest("Article title must be between 3 and 140 characters.");
        }

        var content = request.Content?.Trim();
        if (content is not { Length: >= 20 and <= 10_000 })
        {
            return StoreResult<ArticlePublicationResult>.BadRequest("Article content must be between 20 and 10000 characters.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var newspaper = await GetNewspaperSummaryAsync(connection, normalizedNewspaperId, normalizedPlayerId);
        if (newspaper is null)
        {
            return StoreResult<ArticlePublicationResult>.NotFound("Newspaper was not found.");
        }
        if (!string.Equals(newspaper.OwnerPlayerId, normalizedPlayerId, StringComparison.Ordinal))
        {
            return StoreResult<ArticlePublicationResult>.Forbidden("Only the newspaper owner can publish articles.");
        }

        var now = DateTimeOffset.UtcNow;
        var articleId = $"article-{Guid.NewGuid():N}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO social_chat.articles (
                article_id, newspaper_id, author_player_id, title, content, published_at, updated_at
            )
            VALUES (
                @article_id, @newspaper_id, @author_player_id, @title, @content, @published_at, @updated_at
            );

            UPDATE social_chat.newspapers
            SET updated_at = @updated_at
            WHERE newspaper_id = @newspaper_id;
            """, connection))
        {
            command.Parameters.AddWithValue("article_id", articleId);
            command.Parameters.AddWithValue("newspaper_id", normalizedNewspaperId);
            command.Parameters.AddWithValue("author_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("title", title);
            command.Parameters.AddWithValue("content", content);
            command.Parameters.AddWithValue("published_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var article = await GetArticleInternalAsync(connection, articleId, normalizedPlayerId, includeComments: true);
        var subscribers = await GetSubscriberIdsAsync(connection, normalizedNewspaperId, normalizedPlayerId);
        return StoreResult<ArticlePublicationResult>.Created(new ArticlePublicationResult(
            Completed: true,
            Message: $"Published {title}.",
            Article: article!,
            SubscriberPlayerIds: subscribers));
    }

    public async Task<StoreResult<NewspaperArticleDto>> GetArticleAsync(string articleId, string? playerId)
    {
        var normalizedArticleId = NormalizeResourceId(articleId);
        if (normalizedArticleId is null)
        {
            return StoreResult<NewspaperArticleDto>.BadRequest("Article id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var article = await GetArticleInternalAsync(
            connection,
            normalizedArticleId,
            NormalizeOptionalPlayerId(playerId),
            includeComments: true);
        return article is null
            ? StoreResult<NewspaperArticleDto>.NotFound("Article was not found.")
            : StoreResult<NewspaperArticleDto>.Ok(article);
    }

    public async Task<StoreResult<ArticleCommentResult>> AddCommentAsync(
        string playerId,
        string articleId,
        AddArticleCommentRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedArticleId = NormalizeResourceId(articleId);
        if (normalizedPlayerId is null || normalizedArticleId is null)
        {
            return StoreResult<ArticleCommentResult>.BadRequest("Player id and article id are required.");
        }

        var content = request.Content?.Trim();
        if (content is not { Length: >= 1 and <= 1000 })
        {
            return StoreResult<ArticleCommentResult>.BadRequest("Comment content must be between 1 and 1000 characters.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var existingArticle = await GetArticleInternalAsync(connection, normalizedArticleId, normalizedPlayerId, includeComments: false);
        if (existingArticle is null)
        {
            return StoreResult<ArticleCommentResult>.NotFound("Article was not found.");
        }

        var now = DateTimeOffset.UtcNow;
        var commentId = $"comment-{Guid.NewGuid():N}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO social_chat.article_comments (
                comment_id, article_id, author_player_id, content, created_at
            )
            VALUES (
                @comment_id, @article_id, @author_player_id, @content, @created_at
            );

            UPDATE social_chat.articles
            SET updated_at = @created_at
            WHERE article_id = @article_id;
            """, connection))
        {
            command.Parameters.AddWithValue("comment_id", commentId);
            command.Parameters.AddWithValue("article_id", normalizedArticleId);
            command.Parameters.AddWithValue("author_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("content", content);
            command.Parameters.AddWithValue("created_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var comment = new NewspaperCommentDto(
            CommentId: commentId,
            ArticleId: normalizedArticleId,
            AuthorPlayerId: normalizedPlayerId,
            Content: content,
            CreatedAt: now);
        var article = await GetArticleInternalAsync(connection, normalizedArticleId, normalizedPlayerId, includeComments: true);
        return StoreResult<ArticleCommentResult>.Created(new ArticleCommentResult(
            Completed: true,
            Message: "Comment published.",
            Comment: comment,
            Article: article!));
    }

    public async Task<StoreResult<ArticleVoteResult>> VoteArticleAsync(
        string playerId,
        string articleId,
        VoteArticleRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedArticleId = NormalizeResourceId(articleId);
        if (normalizedPlayerId is null || normalizedArticleId is null)
        {
            return StoreResult<ArticleVoteResult>.BadRequest("Player id and article id are required.");
        }
        if (request.Value is not 1 and not -1)
        {
            return StoreResult<ArticleVoteResult>.BadRequest("Vote value must be 1 or -1.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var existingArticle = await GetArticleInternalAsync(connection, normalizedArticleId, normalizedPlayerId, includeComments: false);
        if (existingArticle is null)
        {
            return StoreResult<ArticleVoteResult>.NotFound("Article was not found.");
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("""
            INSERT INTO social_chat.article_votes (
                article_id, player_id, value, created_at, updated_at
            )
            VALUES (
                @article_id, @player_id, @value, @created_at, @updated_at
            )
            ON CONFLICT (article_id, player_id) DO UPDATE
            SET value = EXCLUDED.value,
                updated_at = EXCLUDED.updated_at;

            UPDATE social_chat.articles
            SET updated_at = @updated_at
            WHERE article_id = @article_id;
            """, connection))
        {
            command.Parameters.AddWithValue("article_id", normalizedArticleId);
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("value", request.Value);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var article = await GetArticleInternalAsync(connection, normalizedArticleId, normalizedPlayerId, includeComments: true);
        return StoreResult<ArticleVoteResult>.Ok(new ArticleVoteResult(
            Completed: true,
            Message: request.Value > 0 ? "Article upvoted." : "Article downvoted.",
            Article: article!));
    }

    public async Task<StoreResult<NewspaperSubscriptionResult>> SetSubscriptionAsync(
        string playerId,
        string newspaperId,
        NewspaperSubscriptionRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedNewspaperId = NormalizeResourceId(newspaperId);
        if (normalizedPlayerId is null || normalizedNewspaperId is null)
        {
            return StoreResult<NewspaperSubscriptionResult>.BadRequest("Player id and newspaper id are required.");
        }

        var subscribe = request.Subscribe ?? true;
        await using var connection = await _dataSource.OpenConnectionAsync();
        var newspaper = await GetNewspaperSummaryAsync(connection, normalizedNewspaperId, normalizedPlayerId);
        if (newspaper is null)
        {
            return StoreResult<NewspaperSubscriptionResult>.NotFound("Newspaper was not found.");
        }

        var now = DateTimeOffset.UtcNow;
        if (subscribe)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO social_chat.newspaper_subscriptions (
                    newspaper_id, player_id, created_at
                )
                VALUES (
                    @newspaper_id, @player_id, @created_at
                )
                ON CONFLICT (newspaper_id, player_id) DO NOTHING;

                UPDATE social_chat.newspapers
                SET updated_at = @created_at
                WHERE newspaper_id = @newspaper_id;
                """, connection);
            command.Parameters.AddWithValue("newspaper_id", normalizedNewspaperId);
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("created_at", now);
            await command.ExecuteNonQueryAsync();
        }
        else
        {
            await using var command = new NpgsqlCommand("""
                DELETE FROM social_chat.newspaper_subscriptions
                WHERE newspaper_id = @newspaper_id AND player_id = @player_id;

                UPDATE social_chat.newspapers
                SET updated_at = @updated_at
                WHERE newspaper_id = @newspaper_id;
                """, connection);
            command.Parameters.AddWithValue("newspaper_id", normalizedNewspaperId);
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var updatedNewspaper = await GetNewspaperSummaryAsync(connection, normalizedNewspaperId, normalizedPlayerId);
        return StoreResult<NewspaperSubscriptionResult>.Ok(new NewspaperSubscriptionResult(
            Completed: true,
            Message: subscribe ? $"Subscribed to {updatedNewspaper!.Name}." : $"Unsubscribed from {updatedNewspaper!.Name}.",
            Newspaper: updatedNewspaper,
            IsSubscribed: subscribe));
    }

    public async Task<ContentModerationActionResult?> ModerateContentAsync(
        string? sourceType,
        string? sourceId,
        string action,
        string actor,
        string reason)
    {
        var target = ResolveModerationTarget(sourceType);
        var normalizedSourceId = NormalizeResourceId(sourceId);
        if (target is null || normalizedSourceId is null)
        {
            return null;
        }

        var status = action == "restore" ? "visible" : "removed";
        var now = DateTimeOffset.UtcNow;
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand($"""
            UPDATE {target.TableName}
            SET moderation_status = @moderation_status,
                moderated_by = @moderated_by,
                moderated_at = @moderated_at,
                moderation_reason = @moderation_reason
            WHERE {target.IdColumn} = @source_id
            RETURNING {target.IdColumn}, {target.PlayerIdColumn}, moderation_status, moderated_at;
            """, connection);
        command.Parameters.AddWithValue("source_id", normalizedSourceId);
        command.Parameters.AddWithValue("moderation_status", status);
        command.Parameters.AddWithValue("moderated_by", actor);
        command.Parameters.AddWithValue("moderated_at", now);
        command.Parameters.AddWithValue("moderation_reason", reason);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        return new ContentModerationActionResult(
            SourceType: target.SourceType,
            SourceId: reader.GetString(0),
            PlayerId: reader.GetString(1),
            Status: reader.GetString(2),
            Action: action,
            ModeratedBy: actor,
            ModeratedAt: reader.GetFieldValue<DateTimeOffset>(3),
            Reason: reason);
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task<NewspaperDto?> GetNewspaperSummaryAsync(
        NpgsqlConnection connection,
        string newspaperId,
        string? viewerPlayerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT
                n.newspaper_id,
                n.owner_player_id,
                n.name,
                n.description,
                n.created_at,
                n.updated_at,
                (SELECT COUNT(*) FROM social_chat.newspaper_subscriptions s WHERE s.newspaper_id = n.newspaper_id) AS subscriber_count,
                (SELECT COUNT(*) FROM social_chat.articles a WHERE a.newspaper_id = n.newspaper_id AND a.moderation_status <> 'removed') AS article_count,
                EXISTS (
                    SELECT 1
                    FROM social_chat.newspaper_subscriptions s
                    WHERE s.newspaper_id = n.newspaper_id AND s.player_id = @viewer_player_id
                ) AS is_subscribed
            FROM social_chat.newspapers n
            WHERE n.newspaper_id = @newspaper_id
                AND n.moderation_status <> 'removed';
            """, connection);
        command.Parameters.AddWithValue("newspaper_id", newspaperId);
        command.Parameters.AddWithValue("viewer_player_id", viewerPlayerId ?? string.Empty);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadNewspaper(reader) : null;
    }

    private async Task<NewspaperArticleDto?> GetArticleInternalAsync(
        NpgsqlConnection connection,
        string articleId,
        string? viewerPlayerId,
        bool includeComments)
    {
        NewspaperArticleDto? article;
        await using (var command = new NpgsqlCommand("""
            SELECT
                a.article_id,
                a.newspaper_id,
                n.name AS newspaper_name,
                n.owner_player_id AS newspaper_owner_player_id,
                a.author_player_id,
                a.title,
                a.content,
                a.published_at,
                a.updated_at,
                COALESCE(SUM(v.value), 0)::int AS vote_score,
                COUNT(v.value) FILTER (WHERE v.value = 1)::int AS upvotes,
                COUNT(v.value) FILTER (WHERE v.value = -1)::int AS downvotes,
                (
                    SELECT pv.value
                    FROM social_chat.article_votes pv
                    WHERE pv.article_id = a.article_id AND pv.player_id = @viewer_player_id
                ) AS player_vote,
                (SELECT COUNT(*) FROM social_chat.article_comments c WHERE c.article_id = a.article_id AND c.moderation_status <> 'removed') AS comment_count
            FROM social_chat.articles a
            INNER JOIN social_chat.newspapers n ON n.newspaper_id = a.newspaper_id
            LEFT JOIN social_chat.article_votes v ON v.article_id = a.article_id
            WHERE a.article_id = @article_id
                AND a.moderation_status <> 'removed'
                AND n.moderation_status <> 'removed'
            GROUP BY a.article_id, n.name, n.owner_player_id;
            """, connection))
        {
            command.Parameters.AddWithValue("article_id", articleId);
            command.Parameters.AddWithValue("viewer_player_id", viewerPlayerId ?? string.Empty);
            await using var reader = await command.ExecuteReaderAsync();
            article = await reader.ReadAsync()
                ? ReadArticle(reader, [])
                : null;
        }

        if (article is null || !includeComments)
        {
            return article;
        }

        var comments = await ReadCommentsAsync(connection, article.ArticleId);
        return article with { Comments = comments };
    }

    private async Task<NewspaperCommentDto[]> ReadCommentsAsync(NpgsqlConnection connection, string articleId)
    {
        var comments = new List<NewspaperCommentDto>();
        await using var command = new NpgsqlCommand("""
            SELECT comment_id, article_id, author_player_id, content, created_at
            FROM social_chat.article_comments
            WHERE article_id = @article_id
                AND moderation_status <> 'removed'
            ORDER BY created_at ASC, comment_id ASC
            LIMIT 200;
            """, connection);
        command.Parameters.AddWithValue("article_id", articleId);

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            comments.Add(new NewspaperCommentDto(
                CommentId: reader.GetString(0),
                ArticleId: reader.GetString(1),
                AuthorPlayerId: reader.GetString(2),
                Content: reader.GetString(3),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(4)));
        }

        return comments.ToArray();
    }

    private async Task<string[]> GetSubscriberIdsAsync(
        NpgsqlConnection connection,
        string newspaperId,
        string excludingPlayerId)
    {
        var subscribers = new List<string>();
        await using var command = new NpgsqlCommand("""
            SELECT player_id
            FROM social_chat.newspaper_subscriptions
            WHERE newspaper_id = @newspaper_id AND player_id <> @excluding_player_id
            ORDER BY created_at ASC
            LIMIT 100;
            """, connection);
        command.Parameters.AddWithValue("newspaper_id", newspaperId);
        command.Parameters.AddWithValue("excluding_player_id", excludingPlayerId);

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            subscribers.Add(reader.GetString(0));
        }

        return subscribers.ToArray();
    }

    private static NewspaperDto ReadNewspaper(NpgsqlDataReader reader)
    {
        return new NewspaperDto(
            NewspaperId: reader.GetString(0),
            OwnerPlayerId: reader.GetString(1),
            Name: reader.GetString(2),
            Description: reader.GetString(3),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(4),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(5),
            SubscriberCount: Convert.ToInt32(reader.GetValue(6)),
            ArticleCount: Convert.ToInt32(reader.GetValue(7)),
            IsSubscribed: reader.GetBoolean(8));
    }

    private static NewspaperArticleDto ReadArticle(
        NpgsqlDataReader reader,
        NewspaperCommentDto[] comments)
    {
        return new NewspaperArticleDto(
            ArticleId: reader.GetString(0),
            NewspaperId: reader.GetString(1),
            NewspaperName: reader.GetString(2),
            NewspaperOwnerPlayerId: reader.GetString(3),
            AuthorPlayerId: reader.GetString(4),
            Title: reader.GetString(5),
            Content: reader.GetString(6),
            PublishedAt: reader.GetFieldValue<DateTimeOffset>(7),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(8),
            VoteScore: Convert.ToInt32(reader.GetValue(9)),
            Upvotes: Convert.ToInt32(reader.GetValue(10)),
            Downvotes: Convert.ToInt32(reader.GetValue(11)),
            PlayerVote: reader.IsDBNull(12) ? null : Convert.ToInt32(reader.GetValue(12)),
            CommentCount: Convert.ToInt32(reader.GetValue(13)),
            Comments: comments);
    }

    private static string? NormalizePlayerId(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is { Length: >= 3 and <= 80 } ? normalized : null;
    }

    private static string? NormalizeOptionalPlayerId(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : NormalizePlayerId(value);
    }

    private static string? NormalizeResourceId(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is { Length: >= 3 and <= 160 } ? normalized : null;
    }

    private static ModerationTarget? ResolveModerationTarget(string? sourceType)
    {
        return sourceType?.Trim().ToLowerInvariant() switch
        {
            "newspaper" => new ModerationTarget(
                SourceType: "newspaper",
                TableName: "social_chat.newspapers",
                IdColumn: "newspaper_id",
                PlayerIdColumn: "owner_player_id"),
            "article" or "newspaper_article" => new ModerationTarget(
                SourceType: "article",
                TableName: "social_chat.articles",
                IdColumn: "article_id",
                PlayerIdColumn: "author_player_id"),
            "article_comment" or "newspaper_comment" => new ModerationTarget(
                SourceType: "article_comment",
                TableName: "social_chat.article_comments",
                IdColumn: "comment_id",
                PlayerIdColumn: "author_player_id"),
            _ => null
        };
    }

    private sealed record ModerationTarget(
        string SourceType,
        string TableName,
        string IdColumn,
        string PlayerIdColumn);
}

internal sealed record StoreResult<T>(T? Value, int StatusCode, string? Message = null) where T : class
{
    public static StoreResult<T> Ok(T value)
    {
        return new StoreResult<T>(value, StatusCodes.Status200OK);
    }

    public static StoreResult<T> Created(T value)
    {
        return new StoreResult<T>(value, StatusCodes.Status201Created);
    }

    public static StoreResult<T> BadRequest(string message)
    {
        return new StoreResult<T>(default, StatusCodes.Status400BadRequest, message);
    }

    public static StoreResult<T> Forbidden(string message)
    {
        return new StoreResult<T>(default, StatusCodes.Status403Forbidden, message);
    }

    public static StoreResult<T> NotFound(string message)
    {
        return new StoreResult<T>(default, StatusCodes.Status404NotFound, message);
    }
}

internal sealed record CreateNewspaperRequest(string? Name, string? Description);

internal sealed record PublishArticleRequest(string? Title, string? Content);

internal sealed record AddArticleCommentRequest(string? Content);

internal sealed record VoteArticleRequest(int Value);

internal sealed record NewspaperSubscriptionRequest(bool? Subscribe);

internal sealed record NewspaperCatalogResponse(string? PlayerId, NewspaperDto[] Newspapers, DateTimeOffset UpdatedAt);

internal sealed record NewspaperArticleListResponse(string NewspaperId, NewspaperArticleDto[] Articles, DateTimeOffset UpdatedAt);

internal sealed record NewspaperMutationResult(bool Completed, string Message, NewspaperDto Newspaper);

internal sealed record ArticlePublicationResult(
    bool Completed,
    string Message,
    NewspaperArticleDto Article,
    string[] SubscriberPlayerIds);

internal sealed record ArticleCommentResult(
    bool Completed,
    string Message,
    NewspaperCommentDto Comment,
    NewspaperArticleDto Article);

internal sealed record ArticleVoteResult(bool Completed, string Message, NewspaperArticleDto Article);

internal sealed record NewspaperSubscriptionResult(
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

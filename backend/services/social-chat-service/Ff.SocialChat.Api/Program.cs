using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<ChatStore>();
builder.Services.AddSingleton<NewspaperStore>();

var metadata = new ServiceMetadata(
    Service: "social-chat-service",
    DisplayName: "Social Chat Service",
    Domain: "Contacts, conversations, channels, media, and unread counts",
    Description: "Combines social graph, chat ownership, and player media for the MVP split, including persisted DMs, groups, global channels, newspapers, articles, comments, votes, subscriptions, and moderation metadata.",
    Owns: ["contacts", "direct conversations", "group channels", "global channels", "newspapers", "articles", "comments", "votes", "subscriptions", "unread counts", "moderation metadata"],
    Responsibilities: ["Serve contact and conversation metadata", "Persist chat messages", "Persist player newspapers and articles", "Persist content moderation state", "Support realtime fan-out later"]);

var app = builder.Build();

var chatStore = app.Services.GetRequiredService<ChatStore>();
await chatStore.InitializeAsync();
var newspaperStore = app.Services.GetRequiredService<NewspaperStore>();
await newspaperStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/messages", async (
    string? fromId,
    string? toId,
    DateTimeOffset? since,
    ChatStore chat) =>
    Results.Ok(await chat.GetMessagesAsync(fromId, toId, since))).WithName("GetMessages");

app.MapGet("/messages/{messageId}", async (string messageId, ChatStore chat) =>
{
    var message = await chat.GetMessageAsync(messageId);
    return message is null
        ? Results.NotFound(new ErrorResponse("Message was not found."))
        : Results.Ok(message);
}).WithName("GetMessage");

app.MapPost("/messages", async (SendMessageRequest request, ChatStore chat) =>
{
    var validation = ValidateMessage(request);
    return validation is not null
        ? Results.BadRequest(new ErrorResponse(validation))
        : Results.Ok(await chat.SendMessageAsync(request));
}).WithName("SendMessage");

app.MapPost("/internal/moderation/content/{sourceType}/{sourceId}/action", async (
    string sourceType,
    string sourceId,
    SocialContentModerationActionRequest request,
    HttpRequest httpRequest,
    ChatStore chat,
    NewspaperStore newspapers,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var action = NormalizeModerationAction(request.Action);
    if (action is null)
    {
        return Results.BadRequest(new ErrorResponse("Moderation action must be remove or restore."));
    }

    if (string.IsNullOrWhiteSpace(request.Actor) || string.IsNullOrWhiteSpace(request.Reason))
    {
        return Results.BadRequest(new ErrorResponse("Moderation actor and reason are required."));
    }

    var result = sourceType.Trim().ToLowerInvariant() == "chat_message"
        ? await chat.ModerateMessageAsync(sourceId, action, request.Actor.Trim(), request.Reason.Trim())
        : await newspapers.ModerateContentAsync(sourceType, sourceId, action, request.Actor.Trim(), request.Reason.Trim());
    return result is null
        ? Results.NotFound(new ErrorResponse("Moderated content was not found."))
        : Results.Ok(result);
}).WithName("ModerateSocialContent");

app.MapNewspaperEndpoints();

app.Run();

static string? ValidateMessage(SendMessageRequest request)
{
    if (string.IsNullOrWhiteSpace(request.Content))
    {
        return "Message content is required.";
    }

    if (request.Content.Trim().Length > 2_000)
    {
        return "Message content must be 2000 characters or fewer.";
    }

    if (!string.IsNullOrWhiteSpace(request.FromId) && request.FromId.Trim().Length > 120)
    {
        return "Sender id must be 120 characters or fewer.";
    }

    if (!string.IsNullOrWhiteSpace(request.ToId) && request.ToId.Trim().Length > 120)
    {
        return "Recipient id must be 120 characters or fewer.";
    }

    return null;
}

static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
{
    var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
    return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
        string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
}

static string? NormalizeModerationAction(string? action)
{
    return action?.Trim().ToLowerInvariant() switch
    {
        "remove" or "removed" => "remove",
        "restore" or "restored" => "restore",
        _ => null
    };
}

internal sealed class ChatStore : IDisposable
{
    private readonly NpgsqlDataSource _dataSource;

    public ChatStore(IConfiguration configuration)
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

            CREATE TABLE IF NOT EXISTS social_chat.messages (
                message_id text PRIMARY KEY,
                from_id text NOT NULL,
                to_id text NOT NULL,
                content text NOT NULL,
                created_at timestamptz NOT NULL,
                moderation_status text NOT NULL DEFAULT 'visible',
                moderated_by text NULL,
                moderated_at timestamptz NULL,
                moderation_reason text NOT NULL DEFAULT ''
            );

            ALTER TABLE social_chat.messages
                ADD COLUMN IF NOT EXISTS moderation_status text NOT NULL DEFAULT 'visible',
                ADD COLUMN IF NOT EXISTS moderated_by text NULL,
                ADD COLUMN IF NOT EXISTS moderated_at timestamptz NULL,
                ADD COLUMN IF NOT EXISTS moderation_reason text NOT NULL DEFAULT '';

            CREATE INDEX IF NOT EXISTS ix_social_chat_messages_to_created
                ON social_chat.messages (to_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_social_chat_messages_conversation_created
                ON social_chat.messages (from_id, to_id, created_at DESC);

            CREATE INDEX IF NOT EXISTS ix_social_chat_messages_moderation_status
                ON social_chat.messages (moderation_status, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
        await SeedWelcomeMessageAsync();
    }

    public async Task<MessageDto[]> GetMessagesAsync(
        string? fromId,
        string? toId,
        DateTimeOffset? since)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT message_id, from_id, to_id, content, created_at
            FROM social_chat.messages
            WHERE
                (
                    @has_conversation_filter = false OR
                    ((from_id = @from_id AND to_id = @to_id) OR (from_id = @to_id AND to_id = @from_id))
                )
                AND (@has_to_filter = false OR to_id = @to_only_id)
                AND (@has_from_filter = false OR from_id = @from_only_id)
                AND (@has_since_filter = false OR created_at > @since)
                AND moderation_status <> 'removed'
            ORDER BY created_at ASC
            LIMIT 200;
            """, connection);

        var normalizedFromId = NormalizeOptionalId(fromId);
        var normalizedToId = NormalizeOptionalId(toId);
        var hasConversationFilter = normalizedFromId is not null && normalizedToId is not null;
        command.Parameters.AddWithValue("has_conversation_filter", hasConversationFilter);
        command.Parameters.AddWithValue("from_id", normalizedFromId ?? string.Empty);
        command.Parameters.AddWithValue("to_id", normalizedToId ?? string.Empty);
        command.Parameters.AddWithValue("has_to_filter", !hasConversationFilter && normalizedToId is not null);
        command.Parameters.AddWithValue("to_only_id", normalizedToId ?? string.Empty);
        command.Parameters.AddWithValue("has_from_filter", !hasConversationFilter && normalizedFromId is not null);
        command.Parameters.AddWithValue("from_only_id", normalizedFromId ?? string.Empty);
        command.Parameters.AddWithValue("has_since_filter", since is not null);
        command.Parameters.AddWithValue("since", since?.ToUniversalTime() ?? DateTimeOffset.UnixEpoch);

        var messages = new List<MessageDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            messages.Add(ReadMessage(reader));
        }

        return messages.ToArray();
    }

    public async Task<MessageDto?> GetMessageAsync(string? messageId)
    {
        var normalizedMessageId = NormalizeResourceId(messageId);
        if (normalizedMessageId is null)
        {
            return null;
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT message_id, from_id, to_id, content, created_at
            FROM social_chat.messages
            WHERE message_id = @message_id
                AND moderation_status <> 'removed';
            """, connection);
        command.Parameters.AddWithValue("message_id", normalizedMessageId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadMessage(reader) : null;
    }

    public async Task<MessageDto> SendMessageAsync(SendMessageRequest request)
    {
        var now = DateTimeOffset.UtcNow;
        var message = new MessageDto(
            Id: Guid.NewGuid().ToString("N"),
            FromId: NormalizeOptionalId(request.FromId) ?? "anonymous",
            ToId: NormalizeOptionalId(request.ToId) ?? "global",
            Content: request.Content.Trim(),
            CreatedAt: now);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO social_chat.messages (message_id, from_id, to_id, content, created_at)
            VALUES (@message_id, @from_id, @to_id, @content, @created_at);
            """, connection);
        command.Parameters.AddWithValue("message_id", message.Id);
        command.Parameters.AddWithValue("from_id", message.FromId);
        command.Parameters.AddWithValue("to_id", message.ToId);
        command.Parameters.AddWithValue("content", message.Content);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();

        return message;
    }

    public async Task<ContentModerationActionResult?> ModerateMessageAsync(
        string? messageId,
        string action,
        string actor,
        string reason)
    {
        var normalizedMessageId = NormalizeResourceId(messageId);
        if (normalizedMessageId is null)
        {
            return null;
        }

        var status = action == "restore" ? "visible" : "removed";
        var now = DateTimeOffset.UtcNow;
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            UPDATE social_chat.messages
            SET moderation_status = @moderation_status,
                moderated_by = @moderated_by,
                moderated_at = @moderated_at,
                moderation_reason = @moderation_reason
            WHERE message_id = @message_id
            RETURNING message_id, from_id, to_id, moderation_status, moderated_at;
            """, connection);
        command.Parameters.AddWithValue("message_id", normalizedMessageId);
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
            SourceType: "chat_message",
            SourceId: reader.GetString(0),
            PlayerId: reader.GetString(1),
            Status: reader.GetString(3),
            Action: action,
            ModeratedBy: actor,
            ModeratedAt: reader.GetFieldValue<DateTimeOffset>(4),
            Reason: reason);
    }

    private async Task SeedWelcomeMessageAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO social_chat.messages (message_id, from_id, to_id, content, created_at)
            VALUES ('welcome-1', 'system', 'global', 'Welcome to FF. Backend services are connected.', @created_at)
            ON CONFLICT (message_id) DO NOTHING;
            """, connection);
        command.Parameters.AddWithValue("created_at", DateTimeOffset.UtcNow);
        await command.ExecuteNonQueryAsync();
    }

    private static MessageDto ReadMessage(NpgsqlDataReader reader)
    {
        return new MessageDto(
            Id: reader.GetString(0),
            FromId: reader.GetString(1),
            ToId: reader.GetString(2),
            Content: reader.GetString(3),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(4));
    }

    private static string? NormalizeOptionalId(string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim();
    }

    private static string? NormalizeResourceId(string? value)
    {
        var normalized = value?.Trim();
        return normalized is { Length: >= 3 and <= 160 } ? normalized : null;
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record SendMessageRequest(string Content, string FromId, string ToId);

internal sealed record MessageDto(
    string Id,
    string FromId,
    string ToId,
    string Content,
    DateTimeOffset CreatedAt);

internal sealed record SocialContentModerationActionRequest(
    string? Action,
    string? Actor,
    string? Reason);

internal sealed record ContentModerationActionResult(
    string SourceType,
    string SourceId,
    string PlayerId,
    string Status,
    string Action,
    string ModeratedBy,
    DateTimeOffset ModeratedAt,
    string Reason);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

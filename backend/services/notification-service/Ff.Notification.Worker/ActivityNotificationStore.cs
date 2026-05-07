using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Npgsql;

namespace Ff.Notification.Worker;

internal sealed class ActivityNotificationStore : IDisposable
{
    private const int DefaultLimit = 50;
    private const int MaximumLimit = 100;
    private readonly NpgsqlDataSource _dataSource;

    public ActivityNotificationStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_NOTIFICATION_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Notification")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS notification;

            CREATE TABLE IF NOT EXISTS notification.player_activity_events (
                event_id text PRIMARY KEY,
                player_id text NOT NULL,
                event_type text NOT NULL,
                message text NOT NULL,
                is_read boolean NOT NULL DEFAULT false,
                related_id text NULL,
                created_at timestamptz NOT NULL,
                read_at timestamptz NULL,
                CONSTRAINT player_activity_events_event_id_length CHECK (char_length(event_id) BETWEEN 3 AND 160),
                CONSTRAINT player_activity_events_player_id_length CHECK (char_length(player_id) BETWEEN 3 AND 80),
                CONSTRAINT player_activity_events_type_length CHECK (char_length(event_type) BETWEEN 3 AND 80),
                CONSTRAINT player_activity_events_message_length CHECK (char_length(message) BETWEEN 1 AND 500)
            );

            CREATE INDEX IF NOT EXISTS player_activity_events_player_created_idx
            ON notification.player_activity_events (player_id, created_at DESC, event_id DESC);

            CREATE INDEX IF NOT EXISTS player_activity_events_player_unread_idx
            ON notification.player_activity_events (player_id, is_read)
            WHERE is_read = false;
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<StoreResult<ActivityFeedResponse>> ListAsync(string playerId, int? limit)
    {
        var normalizedPlayerId = NormalizeId(playerId);
        if (normalizedPlayerId is null)
        {
            return StoreResult<ActivityFeedResponse>.BadRequest("Player id is required.");
        }

        var safeLimit = Math.Clamp(limit ?? DefaultLimit, 1, MaximumLimit);
        await using var connection = await _dataSource.OpenConnectionAsync();

        var events = new List<ActivityEventDto>();
        await using (var command = new NpgsqlCommand("""
            SELECT event_id, player_id, event_type, message, is_read, created_at, related_id
            FROM notification.player_activity_events
            WHERE player_id = @player_id
            ORDER BY created_at DESC, event_id DESC
            LIMIT @limit;
            """, connection))
        {
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("limit", safeLimit);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                events.Add(ReadActivityEvent(reader));
            }
        }

        var unreadCount = await CountUnreadAsync(connection, normalizedPlayerId);
        return StoreResult<ActivityFeedResponse>.Ok(new ActivityFeedResponse(
            PlayerId: normalizedPlayerId,
            Events: events.ToArray(),
            UnreadCount: unreadCount,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ActivityEventDto>> CreateAsync(CreateActivityEventRequest request)
    {
        var validation = ValidateCreate(request);
        if (validation is not null)
        {
            return StoreResult<ActivityEventDto>.BadRequest(validation);
        }

        var eventId = NormalizeEventId(request.EventId)
            ?? $"activity-{Guid.NewGuid():N}";
        var playerId = NormalizeId(request.PlayerId)!;
        var type = NormalizeType(request.Type)!;
        var message = request.Message.Trim();
        var relatedId = NormalizeOptional(request.RelatedId);
        var createdAt = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO notification.player_activity_events (
                event_id, player_id, event_type, message, is_read, related_id, created_at
            )
            VALUES (
                @event_id, @player_id, @event_type, @message, false, @related_id, @created_at
            )
            ON CONFLICT (event_id) DO UPDATE
            SET event_id = EXCLUDED.event_id
            RETURNING event_id, player_id, event_type, message, is_read, created_at, related_id;
            """, connection);

        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("event_type", type);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("related_id", relatedId is null ? DBNull.Value : relatedId);
        command.Parameters.AddWithValue("created_at", createdAt);

        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return StoreResult<ActivityEventDto>.Ok(ReadActivityEvent(reader));
        }

        return StoreResult<ActivityEventDto>.Conflict("Activity event could not be created.");
    }

    public async Task<StoreResult<ActivityReadResult>> MarkReadAsync(string playerId, string eventId)
    {
        var normalizedPlayerId = NormalizeId(playerId);
        var normalizedEventId = NormalizeEventId(eventId);
        if (normalizedPlayerId is null || normalizedEventId is null)
        {
            return StoreResult<ActivityReadResult>.BadRequest("Player id and event id are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var readAt = DateTimeOffset.UtcNow;

        ActivityEventDto? updatedEvent;
        await using (var command = new NpgsqlCommand("""
            UPDATE notification.player_activity_events
            SET is_read = true,
                read_at = COALESCE(read_at, @read_at)
            WHERE player_id = @player_id AND event_id = @event_id
            RETURNING event_id, player_id, event_type, message, is_read, created_at, related_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("event_id", normalizedEventId);
            command.Parameters.AddWithValue("read_at", readAt);

            await using var reader = await command.ExecuteReaderAsync();
            updatedEvent = await reader.ReadAsync() ? ReadActivityEvent(reader) : null;
        }

        if (updatedEvent is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ActivityReadResult>.NotFound("Activity event was not found.");
        }

        var unreadCount = await CountUnreadAsync(connection, normalizedPlayerId, transaction);
        await transaction.CommitAsync();
        return StoreResult<ActivityReadResult>.Ok(new ActivityReadResult(
            Completed: true,
            Message: "Activity event marked read.",
            Event: updatedEvent,
            UnreadCount: unreadCount,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ActivityReadAllResult>> MarkAllReadAsync(string playerId)
    {
        var normalizedPlayerId = NormalizeId(playerId);
        if (normalizedPlayerId is null)
        {
            return StoreResult<ActivityReadAllResult>.BadRequest("Player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var readAt = DateTimeOffset.UtcNow;

        int markedReadCount;
        await using (var command = new NpgsqlCommand("""
            UPDATE notification.player_activity_events
            SET is_read = true,
                read_at = COALESCE(read_at, @read_at)
            WHERE player_id = @player_id AND is_read = false;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("read_at", readAt);
            markedReadCount = await command.ExecuteNonQueryAsync();
        }

        var unreadCount = await CountUnreadAsync(connection, normalizedPlayerId, transaction);
        await transaction.CommitAsync();
        return StoreResult<ActivityReadAllResult>.Ok(new ActivityReadAllResult(
            Completed: true,
            Message: markedReadCount == 0
                ? "No unread activity events."
                : $"Marked {markedReadCount} activity events read.",
            MarkedReadCount: markedReadCount,
            UnreadCount: unreadCount,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private static string? ValidateCreate(CreateActivityEventRequest request)
    {
        if (NormalizeId(request.PlayerId) is null)
        {
            return "Player id is required.";
        }
        if (NormalizeType(request.Type) is null)
        {
            return "Activity type is required.";
        }
        if (string.IsNullOrWhiteSpace(request.Message) || request.Message.Trim().Length > 500)
        {
            return "Activity message is required and must be 500 characters or fewer.";
        }
        if (request.EventId is not null && NormalizeEventId(request.EventId) is null)
        {
            return "Activity event id must be between 3 and 160 characters.";
        }
        if (request.RelatedId is not null && request.RelatedId.Trim().Length > 160)
        {
            return "Related id must be 160 characters or fewer.";
        }

        return null;
    }

    private async Task<int> CountUnreadAsync(
        NpgsqlConnection connection,
        string playerId,
        NpgsqlTransaction? transaction = null)
    {
        await using var command = new NpgsqlCommand("""
            SELECT COUNT(*)
            FROM notification.player_activity_events
            WHERE player_id = @player_id AND is_read = false;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        var count = await command.ExecuteScalarAsync();
        return Convert.ToInt32(count);
    }

    private static ActivityEventDto ReadActivityEvent(NpgsqlDataReader reader)
    {
        return new ActivityEventDto(
            EventId: reader.GetString(0),
            PlayerId: reader.GetString(1),
            Type: reader.GetString(2),
            Message: reader.GetString(3),
            IsRead: reader.GetBoolean(4),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(5),
            RelatedId: reader.IsDBNull(6) ? null : reader.GetString(6));
    }

    private static string? NormalizeId(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is { Length: >= 3 and <= 80 } ? normalized : null;
    }

    private static string? NormalizeType(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is { Length: >= 3 and <= 80 } &&
            normalized.All(character => char.IsLetterOrDigit(character) || character is '_' or '-' or '.' or ':')
                ? normalized
                : null;
    }

    private static string? NormalizeEventId(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is { Length: >= 3 and <= 160 } ? normalized : null;
    }

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }
}

internal sealed record StoreResult<T>(T? Value, int StatusCode, string? Message = null) where T : class
{
    public static StoreResult<T> Ok(T value)
    {
        return new StoreResult<T>(value, StatusCodes.Status200OK);
    }

    public static StoreResult<T> BadRequest(string message)
    {
        return new StoreResult<T>(default, StatusCodes.Status400BadRequest, message);
    }

    public static StoreResult<T> NotFound(string message)
    {
        return new StoreResult<T>(default, StatusCodes.Status404NotFound, message);
    }

    public static StoreResult<T> Conflict(string message)
    {
        return new StoreResult<T>(default, StatusCodes.Status409Conflict, message);
    }
}

internal sealed record CreateActivityEventRequest(
    string? EventId,
    string PlayerId,
    string Type,
    string Message,
    string? RelatedId);

internal sealed record ActivityFeedResponse(
    string PlayerId,
    ActivityEventDto[] Events,
    int UnreadCount,
    DateTimeOffset UpdatedAt);

internal sealed record ActivityEventDto(
    string EventId,
    string PlayerId,
    string Type,
    string Message,
    bool IsRead,
    DateTimeOffset CreatedAt,
    string? RelatedId);

internal sealed record ActivityReadResult(
    bool Completed,
    string Message,
    ActivityEventDto Event,
    int UnreadCount,
    DateTimeOffset UpdatedAt);

internal sealed record ActivityReadAllResult(
    bool Completed,
    string Message,
    int MarkedReadCount,
    int UnreadCount,
    DateTimeOffset UpdatedAt);

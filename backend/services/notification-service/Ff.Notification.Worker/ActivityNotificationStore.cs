using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Npgsql;
using System.Security.Cryptography;
using System.Text;

namespace Ff.Notification.Worker;

internal sealed class ActivityNotificationStore : IDisposable
{
    private const int DefaultLimit = 50;
    private const int MaximumLimit = 100;
    private const int PushBatchLimit = 25;
    private const int PushAttemptLimit = 5;
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

            CREATE TABLE IF NOT EXISTS notification.push_subscriptions (
                subscription_id text PRIMARY KEY,
                player_id text NOT NULL,
                endpoint text NOT NULL UNIQUE,
                p256dh text NOT NULL,
                auth text NOT NULL,
                user_agent text NULL,
                is_enabled boolean NOT NULL DEFAULT true,
                failure_count integer NOT NULL DEFAULT 0,
                last_error text NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                disabled_at timestamptz NULL,
                CONSTRAINT push_subscriptions_player_id_length CHECK (char_length(player_id) BETWEEN 3 AND 80),
                CONSTRAINT push_subscriptions_endpoint_length CHECK (char_length(endpoint) BETWEEN 20 AND 2048),
                CONSTRAINT push_subscriptions_key_length CHECK (char_length(p256dh) BETWEEN 20 AND 512),
                CONSTRAINT push_subscriptions_auth_length CHECK (char_length(auth) BETWEEN 8 AND 256)
            );

            CREATE INDEX IF NOT EXISTS push_subscriptions_player_enabled_idx
            ON notification.push_subscriptions (player_id, is_enabled, updated_at DESC);

            CREATE TABLE IF NOT EXISTS notification.push_delivery_outbox (
                delivery_id text PRIMARY KEY,
                event_id text NOT NULL,
                player_id text NOT NULL,
                subscription_id text NOT NULL REFERENCES notification.push_subscriptions(subscription_id),
                endpoint text NOT NULL,
                title text NOT NULL,
                body text NOT NULL,
                related_id text NULL,
                url text NOT NULL,
                tag text NOT NULL,
                status text NOT NULL,
                attempts integer NOT NULL DEFAULT 0,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                delivered_at timestamptz NULL,
                last_error text NULL,
                CONSTRAINT push_delivery_status_check CHECK (status IN ('pending', 'sending', 'retrying', 'delivered', 'failed', 'abandoned'))
            );

            CREATE INDEX IF NOT EXISTS push_delivery_outbox_pending_idx
            ON notification.push_delivery_outbox (status, created_at)
            WHERE status IN ('pending', 'retrying');

            CREATE INDEX IF NOT EXISTS push_delivery_outbox_player_created_idx
            ON notification.push_delivery_outbox (player_id, created_at DESC);
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
        await using var transaction = await connection.BeginTransactionAsync();
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
            """, connection, transaction);

        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("event_type", type);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("related_id", relatedId is null ? DBNull.Value : relatedId);
        command.Parameters.AddWithValue("created_at", createdAt);

        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var activityEvent = ReadActivityEvent(reader);
            await reader.DisposeAsync();
            await EnqueuePushDeliveriesAsync(connection, transaction, activityEvent);
            await transaction.CommitAsync();
            return StoreResult<ActivityEventDto>.Ok(activityEvent);
        }

        await transaction.RollbackAsync();
        return StoreResult<ActivityEventDto>.Conflict("Activity event could not be created.");
    }

    public async Task<StoreResult<PushNotificationSettingsResponse>> GetPushSubscriptionsAsync(
        string playerId,
        string? vapidPublicKey)
    {
        var normalizedPlayerId = NormalizeId(playerId);
        if (normalizedPlayerId is null)
        {
            return StoreResult<PushNotificationSettingsResponse>.BadRequest("Player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var subscriptions = await ReadPushSubscriptionsAsync(connection, normalizedPlayerId);
        return StoreResult<PushNotificationSettingsResponse>.Ok(new PushNotificationSettingsResponse(
            PlayerId: normalizedPlayerId,
            IsConfigured: !string.IsNullOrWhiteSpace(vapidPublicKey),
            VapidPublicKey: string.IsNullOrWhiteSpace(vapidPublicKey) ? null : vapidPublicKey.Trim(),
            Subscriptions: subscriptions,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<PushSubscriptionMutationResponse>> UpsertPushSubscriptionAsync(
        string playerId,
        PushSubscriptionUpsertRequest request,
        string? vapidPublicKey)
    {
        var normalizedPlayerId = NormalizeId(playerId);
        var validation = ValidatePushSubscription(normalizedPlayerId, request);
        if (validation is not null)
        {
            return StoreResult<PushSubscriptionMutationResponse>.BadRequest(validation);
        }

        var now = DateTimeOffset.UtcNow;
        var endpoint = request.Endpoint.Trim();
        var subscriptionId = CreateSubscriptionId(endpoint);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO notification.push_subscriptions (
                subscription_id, player_id, endpoint, p256dh, auth, user_agent,
                is_enabled, failure_count, last_error, created_at, updated_at, disabled_at
            )
            VALUES (
                @subscription_id, @player_id, @endpoint, @p256dh, @auth, @user_agent,
                true, 0, NULL, @created_at, @updated_at, NULL
            )
            ON CONFLICT (endpoint) DO UPDATE
            SET player_id = EXCLUDED.player_id,
                p256dh = EXCLUDED.p256dh,
                auth = EXCLUDED.auth,
                user_agent = EXCLUDED.user_agent,
                is_enabled = true,
                failure_count = 0,
                last_error = NULL,
                updated_at = EXCLUDED.updated_at,
                disabled_at = NULL
            RETURNING subscription_id, player_id, endpoint, user_agent, is_enabled, failure_count, last_error,
                      created_at, updated_at, disabled_at;
            """, connection);

        command.Parameters.AddWithValue("subscription_id", subscriptionId);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId!);
        command.Parameters.AddWithValue("endpoint", endpoint);
        command.Parameters.AddWithValue("p256dh", request.P256dh.Trim());
        command.Parameters.AddWithValue("auth", request.Auth.Trim());
        command.Parameters.AddWithValue("user_agent", NormalizeOptional(request.UserAgent) is { } userAgent ? userAgent : DBNull.Value);
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return StoreResult<PushSubscriptionMutationResponse>.Conflict("Push subscription could not be saved.");
        }

        var subscription = ReadPushSubscription(reader);
        return StoreResult<PushSubscriptionMutationResponse>.Ok(new PushSubscriptionMutationResponse(
            Completed: true,
            Message: "Push notifications are enabled for this browser.",
            IsConfigured: !string.IsNullOrWhiteSpace(vapidPublicKey),
            Subscription: subscription,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<PushSubscriptionMutationResponse>> DisablePushSubscriptionAsync(
        string playerId,
        PushSubscriptionDisableRequest request)
    {
        var normalizedPlayerId = NormalizeId(playerId);
        var endpoint = NormalizeEndpoint(request.Endpoint);
        if (normalizedPlayerId is null || endpoint is null)
        {
            return StoreResult<PushSubscriptionMutationResponse>.BadRequest("Player id and endpoint are required.");
        }

        var now = DateTimeOffset.UtcNow;
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            UPDATE notification.push_subscriptions
            SET is_enabled = false,
                updated_at = @updated_at,
                disabled_at = COALESCE(disabled_at, @updated_at)
            WHERE player_id = @player_id AND endpoint = @endpoint
            RETURNING subscription_id, player_id, endpoint, user_agent, is_enabled, failure_count, last_error,
                      created_at, updated_at, disabled_at;
            """, connection);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId);
        command.Parameters.AddWithValue("endpoint", endpoint);
        command.Parameters.AddWithValue("updated_at", now);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return StoreResult<PushSubscriptionMutationResponse>.NotFound("Push subscription was not found.");
        }

        return StoreResult<PushSubscriptionMutationResponse>.Ok(new PushSubscriptionMutationResponse(
            Completed: true,
            Message: "Push notifications are disabled for this browser.",
            IsConfigured: true,
            Subscription: ReadPushSubscription(reader),
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<PushDeliveryListResponse>> ListPushDeliveriesAsync(string playerId, int? limit)
    {
        var normalizedPlayerId = NormalizeId(playerId);
        if (normalizedPlayerId is null)
        {
            return StoreResult<PushDeliveryListResponse>.BadRequest("Player id is required.");
        }

        var safeLimit = Math.Clamp(limit ?? DefaultLimit, 1, MaximumLimit);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var deliveries = new List<PushDeliveryDto>();
        await using var command = new NpgsqlCommand("""
            SELECT delivery_id, event_id, player_id, subscription_id, title, body, related_id,
                   url, tag, status, attempts, created_at, updated_at, delivered_at, last_error
            FROM notification.push_delivery_outbox
            WHERE player_id = @player_id
            ORDER BY created_at DESC, delivery_id DESC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId);
        command.Parameters.AddWithValue("limit", safeLimit);

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            deliveries.Add(ReadPushDelivery(reader));
        }

        return StoreResult<PushDeliveryListResponse>.Ok(new PushDeliveryListResponse(
            PlayerId: normalizedPlayerId,
            Deliveries: deliveries.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<PushDeliveryAttempt[]> ClaimPendingPushDeliveriesAsync(int limit = PushBatchLimit)
    {
        var safeLimit = Math.Clamp(limit, 1, 100);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            WITH next_deliveries AS (
                SELECT d.delivery_id, d.subscription_id
                FROM notification.push_delivery_outbox d
                JOIN notification.push_subscriptions s ON s.subscription_id = d.subscription_id
                WHERE d.status IN ('pending', 'retrying')
                  AND d.attempts < @attempt_limit
                  AND s.is_enabled = true
                ORDER BY d.created_at ASC, d.delivery_id ASC
                FOR UPDATE OF d SKIP LOCKED
                LIMIT @limit
            )
            UPDATE notification.push_delivery_outbox d
            SET status = 'sending',
                attempts = d.attempts + 1,
                updated_at = @updated_at
            FROM next_deliveries n
            JOIN notification.push_subscriptions s ON s.subscription_id = n.subscription_id
            WHERE d.delivery_id = n.delivery_id
            RETURNING d.delivery_id, d.event_id, d.player_id, d.subscription_id, d.endpoint,
                      d.title, d.body, d.related_id, d.url, d.tag, d.attempts,
                      s.p256dh, s.auth;
            """, connection);
        command.Parameters.AddWithValue("attempt_limit", PushAttemptLimit);
        command.Parameters.AddWithValue("limit", safeLimit);
        command.Parameters.AddWithValue("updated_at", DateTimeOffset.UtcNow);

        var deliveries = new List<PushDeliveryAttempt>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            deliveries.Add(new PushDeliveryAttempt(
                DeliveryId: reader.GetString(0),
                EventId: reader.GetString(1),
                PlayerId: reader.GetString(2),
                SubscriptionId: reader.GetString(3),
                Endpoint: reader.GetString(4),
                Title: reader.GetString(5),
                Body: reader.GetString(6),
                RelatedId: reader.IsDBNull(7) ? null : reader.GetString(7),
                Url: reader.GetString(8),
                Tag: reader.GetString(9),
                Attempts: reader.GetInt32(10),
                P256dh: reader.GetString(11),
                Auth: reader.GetString(12)));
        }

        return deliveries.ToArray();
    }

    public async Task MarkPushDeliveryDeliveredAsync(string deliveryId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            UPDATE notification.push_delivery_outbox
            SET status = 'delivered',
                delivered_at = @now,
                updated_at = @now,
                last_error = NULL
            WHERE delivery_id = @delivery_id;
            """, connection);
        command.Parameters.AddWithValue("delivery_id", deliveryId);
        command.Parameters.AddWithValue("now", DateTimeOffset.UtcNow);
        await command.ExecuteNonQueryAsync();
    }

    public async Task MarkPushDeliveryFailedAsync(
        PushDeliveryAttempt delivery,
        string message,
        bool disableSubscription)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var terminalStatus = disableSubscription || delivery.Attempts >= PushAttemptLimit
            ? "failed"
            : "retrying";

        await using (var command = new NpgsqlCommand("""
            UPDATE notification.push_delivery_outbox
            SET status = @status,
                updated_at = @updated_at,
                last_error = @last_error
            WHERE delivery_id = @delivery_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("delivery_id", delivery.DeliveryId);
            command.Parameters.AddWithValue("status", terminalStatus);
            command.Parameters.AddWithValue("last_error", message.Length > 500 ? message[..500] : message);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await using (var command = new NpgsqlCommand("""
            UPDATE notification.push_subscriptions
            SET failure_count = failure_count + 1,
                last_error = @last_error,
                is_enabled = CASE WHEN @disable THEN false ELSE is_enabled END,
                disabled_at = CASE WHEN @disable THEN COALESCE(disabled_at, @updated_at) ELSE disabled_at END,
                updated_at = @updated_at
            WHERE subscription_id = @subscription_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("subscription_id", delivery.SubscriptionId);
            command.Parameters.AddWithValue("last_error", message.Length > 500 ? message[..500] : message);
            command.Parameters.AddWithValue("disable", disableSubscription);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
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

    private static async Task EnqueuePushDeliveriesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        ActivityEventDto activityEvent)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO notification.push_delivery_outbox (
                delivery_id, event_id, player_id, subscription_id, endpoint, title, body,
                related_id, url, tag, status, attempts, created_at, updated_at
            )
            SELECT
                @event_id || ':' || subscription_id,
                @event_id,
                @player_id,
                subscription_id,
                endpoint,
                @title,
                @body,
                @related_id,
                @url,
                @tag,
                'pending',
                0,
                @created_at,
                @created_at
            FROM notification.push_subscriptions
            WHERE player_id = @player_id AND is_enabled = true
            ON CONFLICT (delivery_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", activityEvent.EventId);
        command.Parameters.AddWithValue("player_id", activityEvent.PlayerId);
        command.Parameters.AddWithValue("title", TitleForActivityType(activityEvent.Type));
        command.Parameters.AddWithValue("body", activityEvent.Message);
        command.Parameters.AddWithValue("related_id", activityEvent.RelatedId is null ? DBNull.Value : activityEvent.RelatedId);
        command.Parameters.AddWithValue("url", $"/activity?eventId={Uri.EscapeDataString(activityEvent.EventId)}");
        command.Parameters.AddWithValue("tag", activityEvent.EventId);
        command.Parameters.AddWithValue("created_at", activityEvent.CreatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<PushSubscriptionDto[]> ReadPushSubscriptionsAsync(
        NpgsqlConnection connection,
        string playerId)
    {
        var subscriptions = new List<PushSubscriptionDto>();
        await using var command = new NpgsqlCommand("""
            SELECT subscription_id, player_id, endpoint, user_agent, is_enabled, failure_count, last_error,
                   created_at, updated_at, disabled_at
            FROM notification.push_subscriptions
            WHERE player_id = @player_id
            ORDER BY updated_at DESC, subscription_id DESC;
            """, connection);
        command.Parameters.AddWithValue("player_id", playerId);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            subscriptions.Add(ReadPushSubscription(reader));
        }

        return subscriptions.ToArray();
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

    private static PushSubscriptionDto ReadPushSubscription(NpgsqlDataReader reader)
    {
        return new PushSubscriptionDto(
            SubscriptionId: reader.GetString(0),
            PlayerId: reader.GetString(1),
            Endpoint: reader.GetString(2),
            UserAgent: reader.IsDBNull(3) ? null : reader.GetString(3),
            IsEnabled: reader.GetBoolean(4),
            FailureCount: reader.GetInt32(5),
            LastError: reader.IsDBNull(6) ? null : reader.GetString(6),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(7),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(8),
            DisabledAt: reader.IsDBNull(9) ? null : reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static PushDeliveryDto ReadPushDelivery(NpgsqlDataReader reader)
    {
        return new PushDeliveryDto(
            DeliveryId: reader.GetString(0),
            EventId: reader.GetString(1),
            PlayerId: reader.GetString(2),
            SubscriptionId: reader.GetString(3),
            Title: reader.GetString(4),
            Body: reader.GetString(5),
            RelatedId: reader.IsDBNull(6) ? null : reader.GetString(6),
            Url: reader.GetString(7),
            Tag: reader.GetString(8),
            Status: reader.GetString(9),
            Attempts: reader.GetInt32(10),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(11),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(12),
            DeliveredAt: reader.IsDBNull(13) ? null : reader.GetFieldValue<DateTimeOffset>(13),
            LastError: reader.IsDBNull(14) ? null : reader.GetString(14));
    }

    private static string? ValidatePushSubscription(string? normalizedPlayerId, PushSubscriptionUpsertRequest request)
    {
        if (normalizedPlayerId is null)
        {
            return "Player id is required.";
        }
        if (NormalizeEndpoint(request.Endpoint) is null)
        {
            return "Push endpoint must be an absolute URL.";
        }
        if (string.IsNullOrWhiteSpace(request.P256dh) || request.P256dh.Trim().Length is < 20 or > 512)
        {
            return "Push p256dh key is required.";
        }
        if (string.IsNullOrWhiteSpace(request.Auth) || request.Auth.Trim().Length is < 8 or > 256)
        {
            return "Push auth secret is required.";
        }

        return null;
    }

    private static string? NormalizeEndpoint(string? value)
    {
        var normalized = value?.Trim();
        if (normalized is null || normalized.Length is < 20 or > 2048)
        {
            return null;
        }

        return Uri.TryCreate(normalized, UriKind.Absolute, out var uri) &&
            uri.Scheme is "https" or "http"
                ? normalized
                : null;
    }

    private static string CreateSubscriptionId(string endpoint)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(endpoint));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private static string TitleForActivityType(string type)
    {
        if (type.Contains("battle", StringComparison.OrdinalIgnoreCase) ||
            type.Contains("campaign", StringComparison.OrdinalIgnoreCase))
        {
            return "Battle update";
        }
        if (type.Contains("production", StringComparison.OrdinalIgnoreCase))
        {
            return "Production update";
        }
        if (type.Contains("market", StringComparison.OrdinalIgnoreCase) ||
            type.Contains("trade", StringComparison.OrdinalIgnoreCase))
        {
            return "Market update";
        }
        if (type.Contains("achievement", StringComparison.OrdinalIgnoreCase))
        {
            return "Achievement unlocked";
        }

        return "FF update";
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

internal sealed record PushSubscriptionUpsertRequest(
    string Endpoint,
    string P256dh,
    string Auth,
    string? UserAgent);

internal sealed record PushSubscriptionDisableRequest(string Endpoint);

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

internal sealed record PushNotificationSettingsResponse(
    string PlayerId,
    bool IsConfigured,
    string? VapidPublicKey,
    PushSubscriptionDto[] Subscriptions,
    DateTimeOffset UpdatedAt);

internal sealed record PushSubscriptionMutationResponse(
    bool Completed,
    string Message,
    bool IsConfigured,
    PushSubscriptionDto Subscription,
    DateTimeOffset UpdatedAt);

internal sealed record PushSubscriptionDto(
    string SubscriptionId,
    string PlayerId,
    string Endpoint,
    string? UserAgent,
    bool IsEnabled,
    int FailureCount,
    string? LastError,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? DisabledAt);

internal sealed record PushDeliveryListResponse(
    string PlayerId,
    PushDeliveryDto[] Deliveries,
    DateTimeOffset UpdatedAt);

internal sealed record PushDeliveryDto(
    string DeliveryId,
    string EventId,
    string PlayerId,
    string SubscriptionId,
    string Title,
    string Body,
    string? RelatedId,
    string Url,
    string Tag,
    string Status,
    int Attempts,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? DeliveredAt,
    string? LastError);

internal sealed record PushDeliveryAttempt(
    string DeliveryId,
    string EventId,
    string PlayerId,
    string SubscriptionId,
    string Endpoint,
    string Title,
    string Body,
    string? RelatedId,
    string Url,
    string Tag,
    int Attempts,
    string P256dh,
    string Auth);

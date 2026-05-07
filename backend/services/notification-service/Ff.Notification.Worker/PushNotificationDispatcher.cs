using System.Net;
using System.Text.Json;
using WebPush;

namespace Ff.Notification.Worker;

internal sealed class PushNotificationDispatcher(
    ActivityNotificationStore store,
    IConfiguration configuration,
    ILogger<PushNotificationDispatcher> logger) : BackgroundService
{
    private readonly TimeSpan _interval = TimeSpan.FromSeconds(
        Math.Clamp(configuration.GetValue("FF_PUSH_DELIVERY_INTERVAL_SECONDS", 15), 5, 300));

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await DispatchPendingAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Push notification dispatch loop failed.");
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }

    private async Task DispatchPendingAsync(CancellationToken cancellationToken)
    {
        var publicKey = configuration["FF_PUSH_VAPID_PUBLIC_KEY"];
        var privateKey = configuration["FF_PUSH_VAPID_PRIVATE_KEY"];
        var subject = configuration["FF_PUSH_VAPID_SUBJECT"] ?? "mailto:admin@ff.local";
        if (string.IsNullOrWhiteSpace(publicKey) || string.IsNullOrWhiteSpace(privateKey))
        {
            return;
        }

        var vapid = new VapidDetails(subject, publicKey.Trim(), privateKey.Trim());
        using var client = new WebPushClient();
        var deliveries = await store.ClaimPendingPushDeliveriesAsync();
        foreach (var delivery in deliveries)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                var subscription = new PushSubscription(
                    delivery.Endpoint,
                    delivery.P256dh,
                    delivery.Auth);
                var payload = JsonSerializer.Serialize(new
                {
                    title = delivery.Title,
                    body = delivery.Body,
                    icon = "/icons/Icon-192.png",
                    badge = "/icons/Icon-192.png",
                    tag = delivery.Tag,
                    data = new
                    {
                        url = delivery.Url,
                        eventId = delivery.EventId,
                        relatedId = delivery.RelatedId
                    }
                });
                await client.SendNotificationAsync(subscription, payload, vapid, cancellationToken);
                await store.MarkPushDeliveryDeliveredAsync(delivery.DeliveryId);
            }
            catch (WebPushException ex)
            {
                var disable = ex.StatusCode is HttpStatusCode.Gone or HttpStatusCode.NotFound;
                await store.MarkPushDeliveryFailedAsync(
                    delivery,
                    $"Push service rejected delivery: {(int)ex.StatusCode} {ex.Message}",
                    disable);
            }
            catch (Exception ex)
            {
                await store.MarkPushDeliveryFailedAsync(
                    delivery,
                    $"Push delivery failed: {ex.Message}",
                    disableSubscription: false);
            }
        }
    }
}

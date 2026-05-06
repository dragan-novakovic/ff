namespace Ff.Notification.Worker;

public sealed class Worker(ILogger<Worker> logger) : BackgroundService
{
    private const string ServiceName = "notification-service";
    private const string ServiceDomain = "processes user notifications for battles, market sales, messages, production completion, and daily events";
    private static readonly TimeSpan HeartbeatInterval = TimeSpan.FromMinutes(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("{ServiceName} started: {ServiceDomain}", ServiceName, ServiceDomain);

        using var heartbeat = new PeriodicTimer(HeartbeatInterval);

        try
        {
            while (await heartbeat.WaitForNextTickAsync(stoppingToken))
            {
                logger.LogInformation("{ServiceName} heartbeat at {Timestamp:O}", ServiceName, DateTimeOffset.UtcNow);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Normal shutdown path for hosted services.
        }

        logger.LogInformation("{ServiceName} stopping", ServiceName);
    }
}

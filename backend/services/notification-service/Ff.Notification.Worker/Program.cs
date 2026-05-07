using Ff.Notification.Worker;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<ActivityNotificationStore>();
builder.Services.AddHostedService<PushNotificationDispatcher>();

var metadata = new ServiceMetadata(
    Service: "notification-service",
    DisplayName: "Notification Service",
    Domain: "Persisted player activity feed and notifications",
    Description: "Owns persisted player activity events, browser push subscriptions, and delivery state created by gameplay services.",
    Owns: ["activity events", "notification read state", "push subscriptions", "push delivery outbox"],
    Responsibilities: ["Persist player activity feed entries", "Serve notification counts", "Mark notifications read", "Dispatch web push notifications"]);

var app = builder.Build();

var activityStore = app.Services.GetRequiredService<ActivityNotificationStore>();
await activityStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/players/{playerId}/activity", async (
    string playerId,
    int? limit,
    HttpRequest request,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(request, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.ListAsync(playerId, limit);
    return ToStoreResult(result);
}).WithName("GetPlayerActivity");

app.MapPost("/players/{playerId}/activity/{eventId}/read", async (
    string playerId,
    string eventId,
    HttpRequest request,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(request, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.MarkReadAsync(playerId, eventId);
    return ToStoreResult(result);
}).WithName("MarkActivityRead");

app.MapPost("/players/{playerId}/activity/read-all", async (
    string playerId,
    HttpRequest request,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(request, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.MarkAllReadAsync(playerId);
    return ToStoreResult(result);
}).WithName("MarkAllActivityRead");

app.MapPost("/internal/activity-events", async (
    CreateActivityEventRequest request,
    HttpRequest httpRequest,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.CreateAsync(request);
    return ToStoreResult(result);
}).WithName("CreateInternalActivityEvent");

app.MapGet("/players/{playerId}/push", async (
    string playerId,
    HttpRequest request,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(request, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.GetPushSubscriptionsAsync(
        playerId,
        configuration["FF_PUSH_VAPID_PUBLIC_KEY"]);
    return ToStoreResult(result);
}).WithName("GetPlayerPushNotifications");

app.MapPost("/players/{playerId}/push/subscriptions", async (
    string playerId,
    PushSubscriptionUpsertRequest request,
    HttpRequest httpRequest,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.UpsertPushSubscriptionAsync(
        playerId,
        request with
        {
            UserAgent = string.IsNullOrWhiteSpace(request.UserAgent)
                ? httpRequest.Headers.UserAgent.ToString()
                : request.UserAgent
        },
        configuration["FF_PUSH_VAPID_PUBLIC_KEY"]);
    return ToStoreResult(result);
}).WithName("UpsertPlayerPushSubscription");

app.MapPost("/players/{playerId}/push/subscriptions/disable", async (
    string playerId,
    PushSubscriptionDisableRequest request,
    HttpRequest httpRequest,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.DisablePushSubscriptionAsync(playerId, request);
    return ToStoreResult(result);
}).WithName("DisablePlayerPushSubscription");

app.MapGet("/players/{playerId}/push/deliveries", async (
    string playerId,
    int? limit,
    HttpRequest request,
    ActivityNotificationStore store,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(request, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    var result = await store.ListPushDeliveriesAsync(playerId, limit);
    return ToStoreResult(result);
}).WithName("GetPlayerPushDeliveries");

app.Run();

static IResult ToStoreResult<T>(StoreResult<T> result) where T : class
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

static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
{
    var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
    return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
        string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

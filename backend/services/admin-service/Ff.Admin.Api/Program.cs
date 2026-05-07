using Ff.Admin.Api;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<AdminStore>();
builder.Services.AddSingleton<AdminTokenValidator>();

var metadata = new ServiceMetadata(
    Service: "admin-service",
    DisplayName: "Admin / Moderation Service",
    Domain: "Operations tooling, moderation, audit views, and support workflows",
    Description: "Owns administrative API surfaces for trusted operations such as user lookup, bans, compensation, and audit views.",
    Owns: ["admin API surface", "moderation operations", "audit views", "support workflows"],
    Responsibilities: ["Expose protected operational metadata later", "Coordinate bans and compensation", "Provide economy and player inspection views"]);

var app = builder.Build();

var adminStore = app.Services.GetRequiredService<AdminStore>();
await adminStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

var admin = app.MapGroup("/admin");

admin.MapGet("/players/search", async (
    string? query,
    int? limit,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.SearchPlayersAsync(query, ClampLimit(limit, 25, 100)));
}).WithName("AdminSearchPlayers");

admin.MapGet("/players/{playerId}/summary", async (
    string playerId,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var summary = await store.GetPlayerSummaryAsync(playerId);
    return summary is null
        ? Results.NotFound(new ErrorResponse("Player summary was not found."))
        : Results.Ok(summary);
}).WithName("AdminGetPlayerSummary");

admin.MapGet("/players/{playerId}/moderation-records", async (
    string playerId,
    bool? activeOnly,
    int? limit,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.GetModerationRecordsAsync(
            playerId,
            activeOnly: activeOnly ?? false,
            limit: ClampLimit(limit, 50, 200)));
}).WithName("AdminGetPlayerModerationRecords");

admin.MapPost("/players/{playerId}/moderation-records", async (
    string playerId,
    CreateModerationRecordRequest moderationRequest,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var validation = ValidateModerationRequest(moderationRequest);
    if (validation.Error is not null)
    {
        return validation.Error;
    }

    var record = await store.CreateModerationRecordAsync(
        access.Actor!,
        playerId,
        validation.Request!);
    return Results.Ok(record);
}).WithName("AdminCreateModerationRecord");

admin.MapPost("/moderation-records/{recordId}/revoke", async (
    string recordId,
    RevokeModerationRecordRequest revokeRequest,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    if (string.IsNullOrWhiteSpace(revokeRequest.Reason))
    {
        return Results.BadRequest(new ErrorResponse("Revocation reason is required."));
    }

    var record = await store.RevokeModerationRecordAsync(
        access.Actor!,
        recordId,
        revokeRequest.Reason.Trim());
    return record is null
        ? Results.NotFound(new ErrorResponse("Moderation record was not found."))
        : Results.Ok(record);
}).WithName("AdminRevokeModerationRecord");

admin.MapGet("/audit", async (
    string? playerId,
    int? limit,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.GetAuditRecordsAsync(playerId, ClampLimit(limit, 50, 200)));
}).WithName("AdminGetAuditRecords");

admin.MapGet("/economy/ledger", async (
    string? playerId,
    string? entryType,
    int? limit,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.GetEconomyLedgerAsync(playerId, entryType, ClampLimit(limit, 50, 200)));
}).WithName("AdminGetEconomyLedger");

admin.MapGet("/economy/dashboard", async (
    int? days,
    int? limit,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.GetEconomyDashboardAsync(
            days: Math.Clamp(days ?? 30, 1, 365),
            limit: ClampLimit(limit, 10, 50)));
}).WithName("AdminGetEconomyDashboard");

admin.MapGet("/moderation/content-queue", async (
    string? status,
    int? limit,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.GetContentModerationQueueAsync(status, ClampLimit(limit, 50, 200)));
}).WithName("AdminGetContentModerationQueue");

admin.MapGet("/moderation/content-queue/{itemId}", async (
    string itemId,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var item = await store.GetContentModerationItemAsync(itemId);
    return item is null
        ? Results.NotFound(new ErrorResponse("Content moderation item was not found."))
        : Results.Ok(item);
}).WithName("AdminGetContentModerationQueueItem");

admin.MapPost("/moderation/content-queue", async (
    CreateContentQueueItemRequest queueRequest,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var validation = ValidateContentQueueRequest(queueRequest);
    if (validation.Error is not null)
    {
        return validation.Error;
    }

    return Results.Ok(await store.CreateContentQueueItemAsync(access.Actor!, validation.Request!));
}).WithName("AdminCreateContentModerationQueueItem");

admin.MapPost("/moderation/content-queue/{itemId}/review", async (
    string itemId,
    ReviewContentQueueItemRequest reviewRequest,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var validation = ValidateContentReviewRequest(reviewRequest);
    if (validation.Error is not null)
    {
        return validation.Error;
    }

    var item = await store.ReviewContentQueueItemAsync(access.Actor!, itemId, validation.Request!);
    return item is null
        ? Results.NotFound(new ErrorResponse("Content moderation item was not found."))
        : Results.Ok(item);
}).WithName("AdminReviewContentModerationQueueItem");

admin.MapGet("/anti-abuse/rules", async (
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.GetAntiAbuseRulesAsync());
}).WithName("AdminGetAntiAbuseRules");

admin.MapGet("/anti-abuse/review-queue", async (
    string? status,
    string? playerId,
    int? limit,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    return access.Error is not null
        ? access.Error
        : Results.Ok(await store.GetAntiAbuseReviewQueueAsync(
            NormalizeAntiAbuseQueueStatus(status),
            playerId,
            ClampLimit(limit, 50, 200)));
}).WithName("AdminGetAntiAbuseReviewQueue");

admin.MapPost("/anti-abuse/review-queue/{eventId}/review", async (
    string eventId,
    ReviewAntiAbuseEventRequest reviewRequest,
    HttpRequest request,
    AdminStore store,
    AdminTokenValidator tokens) =>
{
    var access = RequireAdmin(request, tokens);
    if (access.Error is not null)
    {
        return access.Error;
    }

    var validation = ValidateAntiAbuseReviewRequest(reviewRequest);
    if (validation.Error is not null)
    {
        return validation.Error;
    }

    var item = await store.ReviewAntiAbuseEventAsync(access.Actor!, eventId, validation.Request!);
    return item is null
        ? Results.NotFound(new ErrorResponse("Anti-abuse review event was not found."))
        : Results.Ok(item);
}).WithName("AdminReviewAntiAbuseEvent");

app.Run();

static AdminAccessResult RequireAdmin(HttpRequest request, AdminTokenValidator tokens)
{
    if (!tokens.IsConfigured)
    {
        return AdminAccessResult.Denied(Results.Json(
            new ErrorResponse("Admin tools are disabled because FF_ADMIN_TOKEN is not configured."),
            statusCode: StatusCodes.Status503ServiceUnavailable));
    }

    var suppliedToken = request.Headers["X-FF-Admin-Token"].ToString();
    if (string.IsNullOrWhiteSpace(suppliedToken))
    {
        return AdminAccessResult.Denied(Results.Json(
            new ErrorResponse("X-FF-Admin-Token header is required."),
            statusCode: StatusCodes.Status401Unauthorized));
    }

    if (!tokens.IsValid(suppliedToken))
    {
        return AdminAccessResult.Denied(Results.Json(
            new ErrorResponse("Admin token is invalid."),
            statusCode: StatusCodes.Status403Forbidden));
    }

    var actor = request.Headers["X-FF-Admin-Actor"].ToString().Trim();
    return AdminAccessResult.Allowed(string.IsNullOrWhiteSpace(actor) ? "direct-admin" : actor);
}

static int ClampLimit(int? limit, int defaultValue, int max)
{
    return Math.Clamp(limit ?? defaultValue, 1, max);
}

static ModerationValidationResult ValidateModerationRequest(CreateModerationRecordRequest request)
{
    var type = NormalizeModerationType(request.Type);
    if (type is null)
    {
        return ModerationValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Moderation type must be ban, suspension, or note.")));
    }

    var reason = request.Reason?.Trim();
    if (string.IsNullOrWhiteSpace(reason))
    {
        return ModerationValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Moderation reason is required.")));
    }

    if (type == "suspension" && request.ExpiresAt is null)
    {
        return ModerationValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Suspensions require an expiresAt timestamp.")));
    }

    if (request.ExpiresAt is not null && request.ExpiresAt <= DateTimeOffset.UtcNow)
    {
        return ModerationValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Moderation expiration must be in the future.")));
    }

    return ModerationValidationResult.Valid(request with { Type = type, Reason = reason });
}

static ContentQueueValidationResult ValidateContentQueueRequest(CreateContentQueueItemRequest request)
{
    var sourceType = NormalizeSourceType(request.SourceType);
    if (sourceType is null ||
        string.IsNullOrWhiteSpace(request.SourceId) ||
        string.IsNullOrWhiteSpace(request.PlayerId) ||
        string.IsNullOrWhiteSpace(request.Content) ||
        string.IsNullOrWhiteSpace(request.Reason))
    {
        return ContentQueueValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Source type must be newspaper, article, article_comment, or chat_message; source id, player id, content, and reason are required.")));
    }

    if (request.SourceId.Trim().Length > 160 || request.PlayerId.Trim().Length > 120)
    {
        return ContentQueueValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Source id must be 160 characters or fewer and player id must be 120 characters or fewer.")));
    }

    if (request.Content.Trim().Length > 10_000 ||
        request.Reason.Trim().Length is < 5 or > 500 ||
        (request.Details?.Trim().Length ?? 0) > 2_000)
    {
        return ContentQueueValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Report content must be 10000 characters or fewer, reason must be 5-500 characters, and details must be 2000 characters or fewer.")));
    }

    return ContentQueueValidationResult.Valid(request with
    {
        SourceType = sourceType,
        SourceId = request.SourceId.Trim(),
        PlayerId = request.PlayerId.Trim(),
        Content = request.Content.Trim(),
        Reason = request.Reason.Trim(),
        ReporterPlayerId = request.ReporterPlayerId?.Trim(),
        Details = request.Details?.Trim()
    });
}

static ContentReviewValidationResult ValidateContentReviewRequest(ReviewContentQueueItemRequest request)
{
    var status = NormalizeReviewStatus(request.Status);
    var action = NormalizeReviewAction(request.Action);
    if (status is null)
    {
        return ContentReviewValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Review status must be resolved, dismissed, or removed.")));
    }
    if (action is null)
    {
        return ContentReviewValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Review action must be none, remove, or restore.")));
    }

    if (string.IsNullOrWhiteSpace(request.Resolution))
    {
        return ContentReviewValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Review resolution is required.")));
    }

    return ContentReviewValidationResult.Valid(request with
    {
        Status = status,
        Resolution = request.Resolution.Trim(),
        Action = action
    });
}

static string? NormalizeModerationType(string? type)
{
    return type?.Trim().ToLowerInvariant() switch
    {
        "ban" or "banned" => "ban",
        "suspend" or "suspension" or "suspended" => "suspension",
        "note" or "mod_note" or "moderation_note" => "note",
        _ => null
    };
}

static AntiAbuseReviewValidationResult ValidateAntiAbuseReviewRequest(ReviewAntiAbuseEventRequest request)
{
    var status = NormalizeAntiAbuseReviewStatus(request.Status);
    if (status is null)
    {
        return AntiAbuseReviewValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Anti-abuse review status must be reviewed, confirmed, or dismissed.")));
    }

    if (string.IsNullOrWhiteSpace(request.Resolution) || request.Resolution.Trim().Length > 2_000)
    {
        return AntiAbuseReviewValidationResult.Invalid(Results.BadRequest(new ErrorResponse(
            "Review resolution is required and must be 2000 characters or fewer.")));
    }

    return AntiAbuseReviewValidationResult.Valid(request with
    {
        Status = status,
        Resolution = request.Resolution.Trim()
    });
}

static string? NormalizeAntiAbuseQueueStatus(string? status)
{
    return string.IsNullOrWhiteSpace(status)
        ? "open"
        : status.Trim().ToLowerInvariant() switch
        {
            "all" or "open" or "reviewed" or "confirmed" or "dismissed" => status.Trim().ToLowerInvariant(),
            _ => "open"
        };
}

static string? NormalizeAntiAbuseReviewStatus(string? status)
{
    return status?.Trim().ToLowerInvariant() switch
    {
        "reviewed" => "reviewed",
        "confirmed" => "confirmed",
        "dismissed" => "dismissed",
        _ => null
    };
}

static string? NormalizeReviewStatus(string? status)
{
    return status?.Trim().ToLowerInvariant() switch
    {
        "resolved" => "resolved",
        "dismissed" => "dismissed",
        "removed" => "removed",
        _ => null
    };
}

static string? NormalizeReviewAction(string? action)
{
    return string.IsNullOrWhiteSpace(action)
        ? "none"
        : action.Trim().ToLowerInvariant() switch
        {
            "none" or "review" or "mark_reviewed" => "none",
            "remove" or "removed" => "remove",
            "restore" or "restored" => "restore",
            _ => null
        };
}

static string? NormalizeSourceType(string? sourceType)
{
    return sourceType?.Trim().ToLowerInvariant() switch
    {
        "newspaper" => "newspaper",
        "article" or "newspaper_article" => "article",
        "article_comment" or "newspaper_comment" => "article_comment",
        "chat_message" or "message" => "chat_message",
        _ => null
    };
}

internal sealed record AdminAccessResult(IResult? Error, string? Actor)
{
    public static AdminAccessResult Allowed(string actor)
    {
        return new AdminAccessResult(null, actor);
    }

    public static AdminAccessResult Denied(IResult error)
    {
        return new AdminAccessResult(error, null);
    }
}

internal sealed record ModerationValidationResult(IResult? Error, CreateModerationRecordRequest? Request)
{
    public static ModerationValidationResult Valid(CreateModerationRecordRequest request)
    {
        return new ModerationValidationResult(null, request);
    }

    public static ModerationValidationResult Invalid(IResult error)
    {
        return new ModerationValidationResult(error, null);
    }
}

internal sealed record ContentQueueValidationResult(IResult? Error, CreateContentQueueItemRequest? Request)
{
    public static ContentQueueValidationResult Valid(CreateContentQueueItemRequest request)
    {
        return new ContentQueueValidationResult(null, request);
    }

    public static ContentQueueValidationResult Invalid(IResult error)
    {
        return new ContentQueueValidationResult(error, null);
    }
}

internal sealed record ContentReviewValidationResult(IResult? Error, ReviewContentQueueItemRequest? Request)
{
    public static ContentReviewValidationResult Valid(ReviewContentQueueItemRequest request)
    {
        return new ContentReviewValidationResult(null, request);
    }

    public static ContentReviewValidationResult Invalid(IResult error)
    {
        return new ContentReviewValidationResult(error, null);
    }
}

internal sealed record AntiAbuseReviewValidationResult(IResult? Error, ReviewAntiAbuseEventRequest? Request)
{
    public static AntiAbuseReviewValidationResult Valid(ReviewAntiAbuseEventRequest request)
    {
        return new AntiAbuseReviewValidationResult(null, request);
    }

    public static AntiAbuseReviewValidationResult Invalid(IResult error)
    {
        return new AntiAbuseReviewValidationResult(error, null);
    }
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

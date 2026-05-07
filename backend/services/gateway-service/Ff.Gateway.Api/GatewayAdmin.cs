using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

internal static class GatewayAdminEndpoints
{
    public static void MapAdminGatewayEndpoints(this WebApplication app)
    {
        var admin = app.MapGroup("/admin");

        admin.MapGet("/players/search", async (
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(WithQuery("admin/players/search", request), access.AdminToken!, access.Actor!);
        }).WithName("GatewayAdminSearchPlayers");

        admin.MapGet("/players/{playerId}/summary", async (
            string playerId,
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(
                    $"admin/players/{Uri.EscapeDataString(playerId)}/summary",
                    access.AdminToken!,
                    access.Actor!);
        }).WithName("GatewayAdminGetPlayerSummary");

        admin.MapGet("/players/{playerId}/moderation-records", async (
            string playerId,
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(
                    WithQuery($"admin/players/{Uri.EscapeDataString(playerId)}/moderation-records", request),
                    access.AdminToken!,
                    access.Actor!);
        }).WithName("GatewayAdminGetPlayerModerationRecords");

        admin.MapPost("/players/{playerId}/moderation-records", async (
            string playerId,
            AdminCreateModerationRecordRequest moderationRequest,
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.PostJsonAsync(
                    $"admin/players/{Uri.EscapeDataString(playerId)}/moderation-records",
                    access.AdminToken!,
                    access.Actor!,
                    moderationRequest);
        }).WithName("GatewayAdminCreateModerationRecord");

        admin.MapPost("/moderation-records/{recordId}/revoke", async (
            string recordId,
            AdminRevokeModerationRecordRequest revokeRequest,
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.PostJsonAsync(
                    $"admin/moderation-records/{Uri.EscapeDataString(recordId)}/revoke",
                    access.AdminToken!,
                    access.Actor!,
                    revokeRequest);
        }).WithName("GatewayAdminRevokeModerationRecord");

        admin.MapGet("/audit", async (
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(WithQuery("admin/audit", request), access.AdminToken!, access.Actor!);
        }).WithName("GatewayAdminGetAuditRecords");

        admin.MapGet("/economy/ledger", async (
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(WithQuery("admin/economy/ledger", request), access.AdminToken!, access.Actor!);
        }).WithName("GatewayAdminGetEconomyLedger");

        admin.MapGet("/economy/dashboard", async (
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(WithQuery("admin/economy/dashboard", request), access.AdminToken!, access.Actor!);
        }).WithName("GatewayAdminGetEconomyDashboard");

        admin.MapGet("/moderation/content-queue", async (
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(
                    WithQuery("admin/moderation/content-queue", request),
                    access.AdminToken!,
                    access.Actor!);
        }).WithName("GatewayAdminGetContentModerationQueue");

        admin.MapGet("/moderation/content-queue/{itemId}", async (
            string itemId,
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(
                    $"admin/moderation/content-queue/{Uri.EscapeDataString(itemId)}",
                    access.AdminToken!,
                    access.Actor!);
        }).WithName("GatewayAdminGetContentModerationQueueItem");

        admin.MapPost("/moderation/content-queue", async (
            AdminCreateContentQueueItemRequest queueRequest,
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.PostJsonAsync(
                    "admin/moderation/content-queue",
                    access.AdminToken!,
                    access.Actor!,
                    queueRequest);
        }).WithName("GatewayAdminCreateContentModerationQueueItem");

        admin.MapPost("/moderation/content-queue/{itemId}/review", async (
            string itemId,
            AdminReviewContentQueueItemRequest reviewRequest,
            HttpRequest request,
            AdminServiceClient adminService,
            SocialChatServiceClient socialChat,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var action = NormalizeReviewAction(reviewRequest.Action);
            if (action is null)
            {
                return Results.BadRequest(new ErrorResponse("Review action must be none, remove, or restore."));
            }

            var normalizedReview = reviewRequest with { Action = action };
            if (action is "remove" or "restore")
            {
                var itemResult = await adminService.GetJsonAsync<AdminContentModerationItemDto>(
                    $"admin/moderation/content-queue/{Uri.EscapeDataString(itemId)}",
                    access.AdminToken!,
                    access.Actor!);
                if (itemResult.Error is not null)
                {
                    return itemResult.Error;
                }

                var item = itemResult.Value!;
                var socialResult = await socialChat.PostJsonAsync<SocialContentModerationActionRequest, SocialContentModerationActionResult>(
                    $"internal/moderation/content/{Uri.EscapeDataString(item.SourceType)}/{Uri.EscapeDataString(item.SourceId)}/action",
                    string.Empty,
                    new SocialContentModerationActionRequest(
                        Action: action,
                        Actor: access.Actor!,
                        Reason: normalizedReview.Resolution ?? "Moderation review action."),
                    InternalToken(configuration));
                if (socialResult.Error is not null)
                {
                    return socialResult.Error;
                }
            }

            return await adminService.PostJsonAsync(
                $"admin/moderation/content-queue/{Uri.EscapeDataString(itemId)}/review",
                access.AdminToken!,
                access.Actor!,
                normalizedReview);
        }).WithName("GatewayAdminReviewContentModerationQueueItem");

        admin.MapGet("/anti-abuse/rules", async (
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync("admin/anti-abuse/rules", access.AdminToken!, access.Actor!);
        }).WithName("GatewayAdminGetAntiAbuseRules");

        admin.MapGet("/anti-abuse/review-queue", async (
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.GetAsync(
                    WithQuery("admin/anti-abuse/review-queue", request),
                    access.AdminToken!,
                    access.Actor!);
        }).WithName("GatewayAdminGetAntiAbuseReviewQueue");

        admin.MapPost("/anti-abuse/review-queue/{eventId}/review", async (
            string eventId,
            AdminReviewAntiAbuseEventRequest reviewRequest,
            HttpRequest request,
            AdminServiceClient adminService,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = RequireAdmin(request, configuration, tokens);
            return access.Error is not null
                ? access.Error
                : await adminService.PostJsonAsync(
                    $"admin/anti-abuse/review-queue/{Uri.EscapeDataString(eventId)}/review",
                    access.AdminToken!,
                    access.Actor!,
                    reviewRequest);
        }).WithName("GatewayAdminReviewAntiAbuseEvent");
    }

    private static AdminGatewayAccess RequireAdmin(
        HttpRequest request,
        IConfiguration configuration,
        DevTokenValidator tokens)
    {
        var configuredToken = configuration["FF_ADMIN_TOKEN"]
            ?? configuration["Admin:Token"];
        if (string.IsNullOrWhiteSpace(configuredToken))
        {
            return AdminGatewayAccess.Denied(Results.Json(
                new ErrorResponse("Admin tools are disabled because FF_ADMIN_TOKEN is not configured."),
                statusCode: StatusCodes.Status503ServiceUnavailable));
        }

        var suppliedToken = request.Headers["X-FF-Admin-Token"].ToString().Trim();
        if (string.IsNullOrWhiteSpace(suppliedToken))
        {
            return AdminGatewayAccess.Denied(Results.Json(
                new ErrorResponse("X-FF-Admin-Token header is required."),
                statusCode: StatusCodes.Status401Unauthorized));
        }

        if (!TokenEquals(configuredToken.Trim(), suppliedToken))
        {
            return AdminGatewayAccess.Denied(Results.Json(
                new ErrorResponse("Admin token is invalid."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        var token = tokens.Validate(request.Headers.Authorization.ToString());
        var actor = token.IsValid
            ? token.PlayerId!
            : request.Headers["X-FF-Admin-Actor"].ToString().Trim();
        if (string.IsNullOrWhiteSpace(actor))
        {
            actor = "gateway-admin";
        }

        return AdminGatewayAccess.Allowed(configuredToken.Trim(), actor);
    }

    private static bool TokenEquals(string expected, string supplied)
    {
        var expectedBytes = Encoding.UTF8.GetBytes(expected);
        var suppliedBytes = Encoding.UTF8.GetBytes(supplied);
        return expectedBytes.Length == suppliedBytes.Length &&
            CryptographicOperations.FixedTimeEquals(expectedBytes, suppliedBytes);
    }

    private static string WithQuery(string path, HttpRequest request)
    {
        return request.QueryString.HasValue
            ? $"{path}{request.QueryString.Value}"
            : path;
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }

    private static string? NormalizeReviewAction(string? action)
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
}

internal sealed class AdminServiceClient(HttpClient httpClient)
{
    public Task<IResult> GetAsync(string path, string adminToken, string actor)
    {
        return ForwardAsync(() => SendAsync(HttpMethod.Get, path, adminToken, actor));
    }

    public Task<ServiceJsonResult<TResponse>> GetJsonAsync<TResponse>(string path, string adminToken, string actor)
    {
        return JsonAsync<TResponse>(() => SendAsync(HttpMethod.Get, path, adminToken, actor));
    }

    public Task<IResult> PostJsonAsync<TRequest>(string path, string adminToken, string actor, TRequest request)
    {
        return ForwardAsync(() =>
        {
            var message = CreateMessage(HttpMethod.Post, path, adminToken, actor);
            message.Content = JsonContent.Create(request);
            return httpClient.SendAsync(message);
        });
    }

    public Task<ServiceJsonResult<TResponse>> PostJsonAsync<TRequest, TResponse>(
        string path,
        string adminToken,
        string actor,
        TRequest request)
    {
        return JsonAsync<TResponse>(() =>
        {
            var message = CreateMessage(HttpMethod.Post, path, adminToken, actor);
            message.Content = JsonContent.Create(request);
            return httpClient.SendAsync(message);
        });
    }

    private static HttpRequestMessage CreateMessage(HttpMethod method, string path, string adminToken, string actor)
    {
        var message = new HttpRequestMessage(method, path);
        message.Headers.TryAddWithoutValidation("X-FF-Admin-Token", adminToken);
        message.Headers.TryAddWithoutValidation("X-FF-Admin-Actor", actor);
        return message;
    }

    private Task<HttpResponseMessage> SendAsync(HttpMethod method, string path, string adminToken, string actor)
    {
        return httpClient.SendAsync(CreateMessage(method, path, adminToken, actor));
    }

    private static async Task<IResult> ForwardAsync(Func<Task<HttpResponseMessage>> send)
    {
        try
        {
            using var response = await send();
            var content = await response.Content.ReadAsStringAsync();
            var contentType = response.Content.Headers.ContentType?.ToString() ?? "application/json";
            return Results.Content(content, contentType, statusCode: (int)response.StatusCode);
        }
        catch (HttpRequestException)
        {
            return Results.Json(
                new ErrorResponse("Admin service is unavailable."),
                statusCode: StatusCodes.Status502BadGateway);
        }
        catch (TaskCanceledException)
        {
            return Results.Json(
                new ErrorResponse("Admin service request timed out."),
                statusCode: StatusCodes.Status504GatewayTimeout);
        }
    }

    private static async Task<ServiceJsonResult<TResponse>> JsonAsync<TResponse>(Func<Task<HttpResponseMessage>> send)
    {
        try
        {
            using var response = await send();
            if (!response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                var contentType = response.Content.Headers.ContentType?.ToString() ?? "application/json";
                return ServiceJsonResult<TResponse>.Failed(
                    Results.Content(content, contentType, statusCode: (int)response.StatusCode));
            }

            var value = await response.Content.ReadFromJsonAsync<TResponse>();
            return value is null
                ? ServiceJsonResult<TResponse>.Failed(Results.Json(
                    new ErrorResponse("Admin service returned an empty response."),
                    statusCode: StatusCodes.Status502BadGateway))
                : ServiceJsonResult<TResponse>.Succeeded(value);
        }
        catch (HttpRequestException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse("Admin service is unavailable."),
                statusCode: StatusCodes.Status502BadGateway));
        }
        catch (TaskCanceledException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse("Admin service request timed out."),
                statusCode: StatusCodes.Status504GatewayTimeout));
        }
        catch (JsonException)
        {
            return ServiceJsonResult<TResponse>.Failed(Results.Json(
                new ErrorResponse("Admin service returned an invalid response."),
                statusCode: StatusCodes.Status502BadGateway));
        }
    }
}

internal sealed record AdminGatewayAccess(IResult? Error, string? AdminToken, string? Actor)
{
    public static AdminGatewayAccess Allowed(string adminToken, string actor)
    {
        return new AdminGatewayAccess(null, adminToken, actor);
    }

    public static AdminGatewayAccess Denied(IResult error)
    {
        return new AdminGatewayAccess(error, null, null);
    }
}

internal sealed record AdminCreateModerationRecordRequest(
    string? Type,
    string? Reason,
    DateTimeOffset? ExpiresAt);

internal sealed record AdminRevokeModerationRecordRequest(string? Reason);

internal sealed record AdminCreateContentQueueItemRequest(
    string? SourceType,
    string? SourceId,
    string? PlayerId,
    string? Content,
    string? Reason,
    string? ReporterPlayerId,
    string? Details);

internal sealed record AdminReviewContentQueueItemRequest(
    string? Status,
    string? Resolution,
    string? Action);

internal sealed record AdminReviewAntiAbuseEventRequest(string? Status, string? Resolution);

internal sealed record AdminContentModerationItemDto(
    string ItemId,
    string SourceType,
    string SourceId,
    string PlayerId,
    string Content,
    string Reason,
    string Status,
    string ReportedBy,
    DateTimeOffset CreatedAt,
    string? ReviewedBy,
    DateTimeOffset? ReviewedAt,
    string Resolution,
    string ReviewAction,
    DateTimeOffset LastReportedAt,
    int ReportCount);

internal sealed record SocialContentModerationActionRequest(
    string Action,
    string Actor,
    string Reason);

internal sealed record SocialContentModerationActionResult(
    string SourceType,
    string SourceId,
    string PlayerId,
    string Status,
    string Action,
    string ModeratedBy,
    DateTimeOffset ModeratedAt,
    string Reason);

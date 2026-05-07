using System.Text.Json;

internal static class ResourceLogisticsGatewayEndpoints
{
    public static void MapResourceLogisticsGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/resource-sites", async (
            string? countryId,
            string? regionId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var query = new List<string>();
            if (!string.IsNullOrWhiteSpace(countryId))
            {
                query.Add($"countryId={Uri.EscapeDataString(countryId.Trim())}");
            }
            if (!string.IsNullOrWhiteSpace(regionId))
            {
                query.Add($"regionId={Uri.EscapeDataString(regionId.Trim())}");
            }

            var suffix = query.Count == 0 ? string.Empty : $"?{string.Join('&', query)}";
            return await world.GetAsync(
                $"resource-sites{suffix}",
                request.Headers.Authorization.ToString());
        }).WithName("ListGatewayResourceSites");

        app.MapGet("/regions/{regionId}/resource-sites", async (
            string regionId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.GetAsync(
                $"regions/{Uri.EscapeDataString(regionId)}/resource-sites",
                request.Headers.Authorization.ToString());
        }).WithName("ListGatewayRegionResourceSites");

        app.MapGet("/companies/{companyId}/resource-logistics", async (
            string companyId,
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await production.GetAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/resource-logistics?actorPlayerId={Uri.EscapeDataString(access.PlayerId!)}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCompanyResourceLogistics");

        app.MapPost("/companies/{companyId}/resource-extractions", async (
            string companyId,
            ResourceExtractionGatewayRequest body,
            HttpRequest request,
            WorldServiceClient world,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = ResolveIdempotencyKey(request, body.IdempotencyKey);
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency key is required."));
            }

            if (string.IsNullOrWhiteSpace(body.SiteId))
            {
                return Results.BadRequest(new ErrorResponse("Resource site is required."));
            }

            var siteResult = await world.GetJsonAsync<ResourceSiteGatewayDto>(
                $"resource-sites/{Uri.EscapeDataString(body.SiteId.Trim())}",
                request.Headers.Authorization.ToString());
            if (siteResult.Error is not null)
            {
                return siteResult.Error;
            }

            var site = siteResult.Value!;
            if (site.IsDepleted)
            {
                return Results.Json(
                    new ErrorResponse($"{site.SiteName} has no reserve remaining."),
                    statusCode: StatusCodes.Status409Conflict);
            }

            var requestedRuns = Math.Clamp(body.RequestedRuns <= 0 ? 1 : body.RequestedRuns, 1, 10);
            return await production.PostJsonForwardAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/resource-extractions",
                request.Headers.Authorization.ToString(),
                new CompanyExtractionStartGatewayRequest(
                    ActorPlayerId: access.PlayerId!,
                    SiteId: site.SiteId,
                    RegionId: site.RegionId,
                    RegionName: site.SiteName,
                    CountryId: site.CountryId,
                    ResourceId: site.ResourceId,
                    ResourceName: site.ResourceName,
                    ItemId: site.ItemId,
                    ItemName: site.ItemName,
                    ItemCategory: site.ItemCategory,
                    BaseYield: site.BaseYield,
                    ExtractionSeconds: site.ExtractionSeconds,
                    RequestedRuns: requestedRuns,
                    AvailableReserve: site.ReserveRemaining,
                    IdempotencyKey: idempotencyKey));
        }).WithName("StartGatewayCompanyResourceExtraction");

        app.MapPost("/companies/{companyId}/resource-extractions/{jobId}/claim", async (
            string companyId,
            string jobId,
            HttpRequest request,
            WorldServiceClient world,
            ProductionServiceClient production,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var claim = await production.PostJsonAsync<CompanyActorRequest, ExtractionClaimGatewayDto>(
                $"companies/{Uri.EscapeDataString(companyId)}/resource-extractions/{Uri.EscapeDataString(jobId)}/claim",
                request.Headers.Authorization.ToString(),
                new CompanyActorRequest(access.PlayerId!));
            if (claim.Error is not null)
            {
                return claim.Error;
            }

            ResourceSiteMutationGatewayDto? depletion = null;
            if (claim.Value!.Completed &&
                !claim.Value.AlreadyClaimed &&
                claim.Value.DepletionAmount > 0)
            {
                var depletionResult = await world.PostJsonAsync<ResourceSiteDepletionGatewayRequest, ResourceSiteMutationGatewayDto>(
                    $"resource-sites/{Uri.EscapeDataString(claim.Value.Extraction.SiteId)}/deplete",
                    request.Headers.Authorization.ToString(),
                    new ResourceSiteDepletionGatewayRequest(
                        Amount: claim.Value.DepletionAmount,
                        Reason: $"Company extraction job {claim.Value.Extraction.JobId} claimed.",
                        IdempotencyKey: $"resource-depletion:{claim.Value.Extraction.JobId}"),
                    InternalToken(configuration));
                if (depletionResult.Error is not null)
                {
                    return depletionResult.Error;
                }

                depletion = depletionResult.Value;
            }

            return Results.Ok(new ExtractionClaimWithResourceGatewayDto(
                Completed: claim.Value.Completed,
                AlreadyClaimed: claim.Value.AlreadyClaimed,
                Message: claim.Value.Message,
                Extraction: claim.Value.Extraction,
                Assets: claim.Value.Assets,
                DepletionAmount: claim.Value.DepletionAmount,
                ResourceDepletion: depletion,
                UpdatedAt: DateTimeOffset.UtcNow));
        }).WithName("ClaimGatewayCompanyResourceExtraction");

        app.MapPost("/companies/{companyId}/shipments", async (
            string companyId,
            CompanyShipmentGatewayRequest body,
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var idempotencyKey = ResolveIdempotencyKey(request, body.IdempotencyKey);
            if (string.IsNullOrWhiteSpace(idempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Idempotency key is required."));
            }

            if (body.Quantity <= 0 ||
                string.IsNullOrWhiteSpace(body.ItemId) ||
                string.IsNullOrWhiteSpace(body.OriginRegionId) ||
                string.IsNullOrWhiteSpace(body.DestinationRegionId))
            {
                return Results.BadRequest(new ErrorResponse("Item, quantity, origin, and destination are required."));
            }

            return await production.PostJsonForwardAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/shipments",
                request.Headers.Authorization.ToString(),
                body with
                {
                    ActorPlayerId = access.PlayerId!,
                    IdempotencyKey = idempotencyKey
                });
        }).WithName("DispatchGatewayCompanyShipment");

        app.MapPost("/companies/{companyId}/shipments/{shipmentId}/deliver", async (
            string companyId,
            string shipmentId,
            HttpRequest request,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await production.PostJsonForwardAsync(
                $"companies/{Uri.EscapeDataString(companyId)}/shipments/{Uri.EscapeDataString(shipmentId)}/deliver",
                request.Headers.Authorization.ToString(),
                new CompanyActorRequest(access.PlayerId!));
        }).WithName("DeliverGatewayCompanyShipment");
    }

    private static PlayerAccessResult ValidateBearerPlayer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        if (!token.IsValid)
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string ResolveIdempotencyKey(HttpRequest request, string? bodyValue)
    {
        var headerValue = request.Headers["Idempotency-Key"].ToString();
        var key = string.IsNullOrWhiteSpace(bodyValue) ? headerValue : bodyValue;
        return key.Trim().ToLowerInvariant();
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed record ResourceExtractionGatewayRequest(
    string SiteId,
    int RequestedRuns,
    string? IdempotencyKey);

internal sealed record CompanyExtractionStartGatewayRequest(
    string ActorPlayerId,
    string SiteId,
    string RegionId,
    string RegionName,
    string CountryId,
    string ResourceId,
    string ResourceName,
    string ItemId,
    string ItemName,
    string? ItemCategory,
    int BaseYield,
    int ExtractionSeconds,
    int RequestedRuns,
    int AvailableReserve,
    string IdempotencyKey);

internal sealed record CompanyShipmentGatewayRequest(
    string? ActorPlayerId,
    string ItemId,
    string ItemName,
    string? ItemCategory,
    int Quantity,
    string OriginRegionId,
    string OriginRegionName,
    string DestinationRegionId,
    string DestinationRegionName,
    int DurationSeconds,
    string? IdempotencyKey);

internal sealed record ResourceSiteGatewayDto(
    string SiteId,
    string RegionId,
    string CountryId,
    string ResourceId,
    string ResourceName,
    string ItemId,
    string ItemName,
    string ItemCategory,
    string SiteName,
    string Terrain,
    int BaseYield,
    int ExtractionSeconds,
    int ReserveRemaining,
    int ReserveCapacity,
    int DepletionPerRun,
    int QualityPercent,
    int ExtractionCount,
    bool IsDepleted,
    DateTimeOffset UpdatedAt);

internal sealed record ResourceSiteDepletionGatewayRequest(
    int Amount,
    string Reason,
    string IdempotencyKey);

internal sealed record ResourceSiteMutationGatewayDto(
    bool Completed,
    string Message,
    ResourceSiteGatewayDto Site,
    DateTimeOffset UpdatedAt);

internal sealed record ExtractionClaimGatewayDto(
    bool Completed,
    bool AlreadyClaimed,
    string Message,
    CompanyExtractionGatewayDto Extraction,
    JsonElement Assets,
    int DepletionAmount,
    DateTimeOffset UpdatedAt);

internal sealed record ExtractionClaimWithResourceGatewayDto(
    bool Completed,
    bool AlreadyClaimed,
    string Message,
    CompanyExtractionGatewayDto Extraction,
    JsonElement Assets,
    int DepletionAmount,
    ResourceSiteMutationGatewayDto? ResourceDepletion,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyExtractionGatewayDto(
    string JobId,
    string CompanyId,
    string ActorPlayerId,
    string SiteId,
    string RegionId,
    string RegionName,
    string CountryId,
    string ResourceId,
    string ResourceName,
    string ItemId,
    string ItemName,
    string ItemCategory,
    int RequestedRuns,
    int BaseYield,
    int YieldQuantity,
    string Status,
    int DurationSeconds,
    DateTimeOffset StartedAt,
    DateTimeOffset CompletesAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? ClaimedAt,
    string IdempotencyKey,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    bool CanClaim);

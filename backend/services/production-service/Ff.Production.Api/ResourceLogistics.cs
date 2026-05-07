using Npgsql;

internal static class ResourceLogisticsEndpoints
{
    public static void MapResourceLogisticsEndpoints(this WebApplication app)
    {
        app.MapGet("/companies/{companyId}/resource-logistics", async (
            string companyId,
            string? actorPlayerId,
            ProductionStore production) =>
        {
            if (string.IsNullOrWhiteSpace(actorPlayerId))
            {
                return Results.BadRequest(new ErrorResponse("Actor player id is required."));
            }

            return ToStoreResult(await production.GetResourceLogisticsAsync(companyId, actorPlayerId));
        }).WithName("GetCompanyResourceLogistics");

        app.MapPost("/companies/{companyId}/resource-extractions", async (
            string companyId,
            CompanyExtractionStartRequest request,
            ProductionStore production) =>
        {
            return ToStoreResult(await production.StartResourceExtractionAsync(companyId, request));
        }).WithName("StartCompanyResourceExtraction");

        app.MapPost("/companies/{companyId}/resource-extractions/{jobId}/claim", async (
            string companyId,
            string jobId,
            CompanyActorRequest request,
            ProductionStore production) =>
        {
            return ToStoreResult(await production.ClaimResourceExtractionAsync(companyId, jobId, request.ActorPlayerId));
        }).WithName("ClaimCompanyResourceExtraction");

        app.MapPost("/companies/{companyId}/shipments", async (
            string companyId,
            CompanyShipmentDispatchRequest request,
            ProductionStore production) =>
        {
            return ToStoreResult(await production.DispatchCompanyShipmentAsync(companyId, request));
        }).WithName("DispatchCompanyShipment");

        app.MapPost("/companies/{companyId}/shipments/{shipmentId}/deliver", async (
            string companyId,
            string shipmentId,
            CompanyActorRequest request,
            ProductionStore production) =>
        {
            return ToStoreResult(await production.DeliverCompanyShipmentAsync(companyId, shipmentId, request.ActorPlayerId));
        }).WithName("DeliverCompanyShipment");
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

internal sealed partial class ProductionStore
{
    private const int MaxExtractionQueueDepth = 3;
    private const int MaxExtractionRuns = 10;
    private const int MinimumShipmentSeconds = 30;
    private const int MaximumShipmentSeconds = 24 * 60 * 60;

    public async Task InitializeResourceLogisticsAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS production.company_extraction_jobs (
                job_id text PRIMARY KEY,
                company_id text NOT NULL REFERENCES production.companies(company_id) ON DELETE CASCADE,
                actor_player_id text NOT NULL,
                site_id text NOT NULL,
                region_id text NOT NULL,
                region_name text NOT NULL,
                country_id text NOT NULL,
                resource_id text NOT NULL,
                resource_name text NOT NULL,
                item_id text NOT NULL,
                item_name text NOT NULL,
                item_category text NOT NULL,
                requested_runs integer NOT NULL,
                base_yield integer NOT NULL,
                yield_quantity integer NOT NULL,
                status text NOT NULL,
                duration_seconds integer NOT NULL,
                started_at timestamptz NOT NULL,
                completes_at timestamptz NOT NULL,
                completed_at timestamptz NULL,
                claimed_at timestamptz NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT company_extraction_jobs_runs_check CHECK (requested_runs > 0),
                CONSTRAINT company_extraction_jobs_yield_check CHECK (base_yield > 0 AND yield_quantity > 0),
                CONSTRAINT company_extraction_jobs_status_check CHECK (status IN ('queued', 'running', 'completed', 'claimed', 'cancelled'))
            );

            CREATE INDEX IF NOT EXISTS company_extraction_jobs_company_status_idx
                ON production.company_extraction_jobs (company_id, status, completes_at);

            CREATE INDEX IF NOT EXISTS company_extraction_jobs_site_idx
                ON production.company_extraction_jobs (site_id, status);

            CREATE TABLE IF NOT EXISTS production.company_shipments (
                shipment_id text PRIMARY KEY,
                company_id text NOT NULL REFERENCES production.companies(company_id) ON DELETE CASCADE,
                actor_player_id text NOT NULL,
                item_id text NOT NULL,
                item_name text NOT NULL,
                item_category text NOT NULL,
                quantity integer NOT NULL,
                origin_region_id text NOT NULL,
                origin_region_name text NOT NULL,
                destination_region_id text NOT NULL,
                destination_region_name text NOT NULL,
                status text NOT NULL,
                duration_seconds integer NOT NULL,
                dispatched_at timestamptz NOT NULL,
                arrives_at timestamptz NOT NULL,
                delivered_at timestamptz NULL,
                last_error text NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT company_shipments_quantity_check CHECK (quantity > 0),
                CONSTRAINT company_shipments_status_check CHECK (status IN ('in_transit', 'delivered', 'cancelled'))
            );

            CREATE INDEX IF NOT EXISTS company_shipments_company_status_idx
                ON production.company_shipments (company_id, status, arrives_at);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<StoreResult<ResourceLogisticsDashboardResponse>> GetResourceLogisticsAsync(
        string companyId,
        string actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var role = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (role is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<ResourceLogisticsDashboardResponse>.Forbidden("You must be a company member to view resource logistics.")
                : StoreResult<ResourceLogisticsDashboardResponse>.NotFound("Company was not found.");
        }

        await AdvanceExtractionJobsAsync(connection, transaction, normalizedCompanyId, now);
        await AdvanceShipmentsAsync(connection, transaction, normalizedCompanyId, now);
        var extractions = await ReadExtractionJobsAsync(connection, transaction, normalizedCompanyId, now);
        var shipments = await ReadShipmentsAsync(connection, transaction, normalizedCompanyId, now);
        var inTransit = shipments
            .Where(shipment => string.Equals(shipment.Status, "in_transit", StringComparison.OrdinalIgnoreCase))
            .Sum(shipment => shipment.Quantity);
        var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<ResourceLogisticsDashboardResponse>.Ok(new ResourceLogisticsDashboardResponse(
            CompanyId: normalizedCompanyId,
            Extractions: extractions.ToArray(),
            Shipments: shipments.ToArray(),
            InTransitQuantity: inTransit,
            Assets: assets!,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ExtractionMutationResponse>> StartResourceExtractionAsync(
        string companyId,
        CompanyExtractionStartRequest request)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        var siteId = NormalizeId(request.SiteId);
        var regionId = NormalizeId(request.RegionId);
        var countryId = NormalizeId(request.CountryId);
        var resourceId = NormalizeId(request.ResourceId);
        var itemId = NormalizeId(request.ItemId);
        var idempotencyKey = NormalizeId(request.IdempotencyKey);
        var requestedRuns = Math.Clamp(request.RequestedRuns <= 0 ? 1 : request.RequestedRuns, 1, MaxExtractionRuns);
        var baseYield = request.BaseYield;
        var durationSeconds = Math.Clamp(request.ExtractionSeconds, 5, MaximumShipmentSeconds);
        var yieldQuantity = checked(baseYield * requestedRuns);

        if (string.IsNullOrWhiteSpace(normalizedActorId) ||
            string.IsNullOrWhiteSpace(siteId) ||
            string.IsNullOrWhiteSpace(regionId) ||
            string.IsNullOrWhiteSpace(countryId) ||
            string.IsNullOrWhiteSpace(resourceId) ||
            string.IsNullOrWhiteSpace(itemId) ||
            string.IsNullOrWhiteSpace(request.RegionName) ||
            string.IsNullOrWhiteSpace(request.ResourceName) ||
            string.IsNullOrWhiteSpace(request.ItemName) ||
            string.IsNullOrWhiteSpace(idempotencyKey) ||
            baseYield <= 0)
        {
            return StoreResult<ExtractionMutationResponse>.BadRequest(
                "Actor, site, resource, item, and idempotency key are required.");
        }

        if (request.AvailableReserve > 0 && yieldQuantity > request.AvailableReserve)
        {
            return StoreResult<ExtractionMutationResponse>.Conflict(
                $"{request.ResourceName} reserve only has {request.AvailableReserve} units available.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var role = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (role is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<ExtractionMutationResponse>.Forbidden("You must be a company member to start extraction.")
                : StoreResult<ExtractionMutationResponse>.NotFound("Company was not found.");
        }

        if (!CanManageCompany(role))
        {
            await transaction.RollbackAsync();
            return StoreResult<ExtractionMutationResponse>.Forbidden("Only company owners and managers can start extraction.");
        }

        await AdvanceExtractionJobsAsync(connection, transaction, normalizedCompanyId, now);
        var existing = await ReadExtractionJobByIdempotencyAsync(connection, transaction, idempotencyKey, now);
        if (existing is not null)
        {
            var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
            await transaction.CommitAsync();
            return StoreResult<ExtractionMutationResponse>.Ok(new ExtractionMutationResponse(
                Completed: string.Equals(existing.Status, "claimed", StringComparison.OrdinalIgnoreCase),
                Message: "Resource extraction request was already recorded.",
                Extraction: existing,
                Assets: assets!,
                UpdatedAt: DateTimeOffset.UtcNow));
        }

        var queueDepth = await ReadExtractionQueueDepthForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            siteId);
        if (queueDepth >= MaxExtractionQueueDepth)
        {
            await transaction.RollbackAsync();
            return StoreResult<ExtractionMutationResponse>.Conflict(
                "This resource site extraction queue is full. Claim completed extraction before starting more.");
        }

        var latestCompletesAt = await ReadLatestExtractionCompletesAtAsync(
            connection,
            transaction,
            normalizedCompanyId,
            siteId);
        var startedAt = latestCompletesAt is not null && latestCompletesAt > now
            ? latestCompletesAt.Value
            : now;
        var completesAt = startedAt.AddSeconds(durationSeconds);
        var status = startedAt > now ? "queued" : "running";
        var jobId = $"xjob-{Guid.NewGuid():N}";

        await using (var insert = new NpgsqlCommand("""
            INSERT INTO production.company_extraction_jobs (
                job_id, company_id, actor_player_id, site_id, region_id, region_name,
                country_id, resource_id, resource_name, item_id, item_name, item_category,
                requested_runs, base_yield, yield_quantity, status, duration_seconds,
                started_at, completes_at, idempotency_key, created_at, updated_at
            )
            VALUES (
                @job_id, @company_id, @actor_player_id, @site_id, @region_id, @region_name,
                @country_id, @resource_id, @resource_name, @item_id, @item_name, @item_category,
                @requested_runs, @base_yield, @yield_quantity, @status, @duration_seconds,
                @started_at, @completes_at, @idempotency_key, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("job_id", jobId);
            insert.Parameters.AddWithValue("company_id", normalizedCompanyId);
            insert.Parameters.AddWithValue("actor_player_id", normalizedActorId);
            insert.Parameters.AddWithValue("site_id", siteId);
            insert.Parameters.AddWithValue("region_id", regionId);
            insert.Parameters.AddWithValue("region_name", request.RegionName.Trim());
            insert.Parameters.AddWithValue("country_id", countryId);
            insert.Parameters.AddWithValue("resource_id", resourceId);
            insert.Parameters.AddWithValue("resource_name", request.ResourceName.Trim());
            insert.Parameters.AddWithValue("item_id", itemId);
            insert.Parameters.AddWithValue("item_name", request.ItemName.Trim());
            insert.Parameters.AddWithValue("item_category", string.IsNullOrWhiteSpace(request.ItemCategory) ? "Raw material" : request.ItemCategory.Trim());
            insert.Parameters.AddWithValue("requested_runs", requestedRuns);
            insert.Parameters.AddWithValue("base_yield", baseYield);
            insert.Parameters.AddWithValue("yield_quantity", yieldQuantity);
            insert.Parameters.AddWithValue("status", status);
            insert.Parameters.AddWithValue("duration_seconds", durationSeconds);
            insert.Parameters.AddWithValue("started_at", startedAt);
            insert.Parameters.AddWithValue("completes_at", completesAt);
            insert.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            insert.Parameters.AddWithValue("created_at", now);
            insert.Parameters.AddWithValue("updated_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var extraction = await ReadExtractionJobAsync(connection, transaction, normalizedCompanyId, jobId, now)
            ?? throw new InvalidOperationException("Created extraction job was not found.");
        var updatedAssets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<ExtractionMutationResponse>.Accepted(new ExtractionMutationResponse(
            Completed: false,
            Message: $"{request.ResourceName.Trim()} extraction started at {request.RegionName.Trim()} and completes at {completesAt:O}.",
            Extraction: extraction,
            Assets: updatedAssets!,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ExtractionClaimResponse>> ClaimResourceExtractionAsync(
        string companyId,
        string jobId,
        string? actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedJobId = NormalizeId(jobId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<ExtractionClaimResponse>.BadRequest("Actor player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var role = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (role is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<ExtractionClaimResponse>.Forbidden("You must be a company member to claim extraction.")
                : StoreResult<ExtractionClaimResponse>.NotFound("Company was not found.");
        }

        await AdvanceExtractionJobsAsync(connection, transaction, normalizedCompanyId, now);
        var job = await ReadExtractionJobForUpdateAsync(connection, transaction, normalizedCompanyId, normalizedJobId, now);
        if (job is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ExtractionClaimResponse>.NotFound("Resource extraction job was not found.");
        }

        if (string.Equals(job.Status, "claimed", StringComparison.OrdinalIgnoreCase))
        {
            var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
            await transaction.CommitAsync();
            return StoreResult<ExtractionClaimResponse>.Ok(new ExtractionClaimResponse(
                Completed: true,
                AlreadyClaimed: true,
                Message: "Resource extraction job was already claimed.",
                Extraction: job,
                Assets: assets!,
                DepletionAmount: 0,
                UpdatedAt: DateTimeOffset.UtcNow));
        }

        if (job.CompletesAt > now)
        {
            await transaction.RollbackAsync();
            return StoreResult<ExtractionClaimResponse>.Conflict(
                $"Resource extraction is still running until {job.CompletesAt:O}.");
        }

        if (!string.Equals(job.Status, "completed", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.RollbackAsync();
            return StoreResult<ExtractionClaimResponse>.Conflict(
                $"Resource extraction cannot be claimed from status '{job.Status}'.");
        }

        var storageError = await GrantCompanyInventoryAsync(
            connection,
            transaction,
            normalizedCompanyId,
            job.ItemId,
            job.ItemName,
            job.ItemCategory,
            job.YieldQuantity,
            $"Resource extraction from {job.RegionName}.",
            now);
        if (storageError is not null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ExtractionClaimResponse>.Conflict(storageError);
        }

        await using (var update = new NpgsqlCommand("""
            UPDATE production.company_extraction_jobs
            SET status = 'claimed',
                completed_at = COALESCE(completed_at, completes_at),
                claimed_at = COALESCE(claimed_at, @claimed_at),
                updated_at = @updated_at
            WHERE company_id = @company_id AND job_id = @job_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("company_id", normalizedCompanyId);
            update.Parameters.AddWithValue("job_id", normalizedJobId);
            update.Parameters.AddWithValue("claimed_at", now);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var claimedJob = (await ReadExtractionJobAsync(connection, transaction, normalizedCompanyId, normalizedJobId, now))!;
        var assetsAfterClaim = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<ExtractionClaimResponse>.Ok(new ExtractionClaimResponse(
            Completed: true,
            AlreadyClaimed: false,
            Message: $"Claimed {job.YieldQuantity} {job.ItemName} into company inventory.",
            Extraction: claimedJob,
            Assets: assetsAfterClaim!,
            DepletionAmount: job.YieldQuantity,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ShipmentMutationResponse>> DispatchCompanyShipmentAsync(
        string companyId,
        CompanyShipmentDispatchRequest request)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        var itemId = NormalizeId(request.ItemId);
        var originRegionId = NormalizeId(request.OriginRegionId);
        var destinationRegionId = NormalizeId(request.DestinationRegionId);
        var idempotencyKey = NormalizeId(request.IdempotencyKey);
        var quantity = request.Quantity;
        var durationSeconds = Math.Clamp(
            request.DurationSeconds <= 0 ? 60 : request.DurationSeconds,
            MinimumShipmentSeconds,
            MaximumShipmentSeconds);

        if (string.IsNullOrWhiteSpace(normalizedActorId) ||
            string.IsNullOrWhiteSpace(itemId) ||
            string.IsNullOrWhiteSpace(originRegionId) ||
            string.IsNullOrWhiteSpace(destinationRegionId) ||
            string.IsNullOrWhiteSpace(request.ItemName) ||
            string.IsNullOrWhiteSpace(request.OriginRegionName) ||
            string.IsNullOrWhiteSpace(request.DestinationRegionName) ||
            string.IsNullOrWhiteSpace(idempotencyKey) ||
            quantity <= 0)
        {
            return StoreResult<ShipmentMutationResponse>.BadRequest(
                "Actor, item, regions, quantity, and idempotency key are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var role = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (role is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<ShipmentMutationResponse>.Forbidden("You must be a company member to dispatch shipments.")
                : StoreResult<ShipmentMutationResponse>.NotFound("Company was not found.");
        }

        if (!CanManageCompany(role))
        {
            await transaction.RollbackAsync();
            return StoreResult<ShipmentMutationResponse>.Forbidden("Only company owners and managers can dispatch shipments.");
        }

        await AdvanceShipmentsAsync(connection, transaction, normalizedCompanyId, now);
        var existing = await ReadShipmentByIdempotencyAsync(connection, transaction, idempotencyKey, now);
        if (existing is not null)
        {
            var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
            await transaction.CommitAsync();
            return StoreResult<ShipmentMutationResponse>.Ok(new ShipmentMutationResponse(
                Completed: string.Equals(existing.Status, "delivered", StringComparison.OrdinalIgnoreCase),
                Message: "Shipment request was already recorded.",
                Shipment: existing,
                Assets: assets!,
                UpdatedAt: DateTimeOffset.UtcNow));
        }

        var available = await ReadCompanyInventoryQuantityForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            itemId);
        if (available < quantity)
        {
            await transaction.RollbackAsync();
            return StoreResult<ShipmentMutationResponse>.Conflict(
                $"Not enough company {request.ItemName}. Required {quantity}, available {available}.");
        }

        await SpendCompanyInventoryAsync(connection, transaction, normalizedCompanyId, itemId, quantity, now);
        var shipmentId = $"ship-{Guid.NewGuid():N}";
        var arrivesAt = now.AddSeconds(durationSeconds);
        await using (var insert = new NpgsqlCommand("""
            INSERT INTO production.company_shipments (
                shipment_id, company_id, actor_player_id, item_id, item_name, item_category,
                quantity, origin_region_id, origin_region_name, destination_region_id,
                destination_region_name, status, duration_seconds, dispatched_at, arrives_at,
                idempotency_key, created_at, updated_at
            )
            VALUES (
                @shipment_id, @company_id, @actor_player_id, @item_id, @item_name, @item_category,
                @quantity, @origin_region_id, @origin_region_name, @destination_region_id,
                @destination_region_name, 'in_transit', @duration_seconds, @dispatched_at, @arrives_at,
                @idempotency_key, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("shipment_id", shipmentId);
            insert.Parameters.AddWithValue("company_id", normalizedCompanyId);
            insert.Parameters.AddWithValue("actor_player_id", normalizedActorId);
            insert.Parameters.AddWithValue("item_id", itemId);
            insert.Parameters.AddWithValue("item_name", request.ItemName.Trim());
            insert.Parameters.AddWithValue("item_category", string.IsNullOrWhiteSpace(request.ItemCategory) ? ToItemCategory(itemId, "Material") : request.ItemCategory.Trim());
            insert.Parameters.AddWithValue("quantity", quantity);
            insert.Parameters.AddWithValue("origin_region_id", originRegionId);
            insert.Parameters.AddWithValue("origin_region_name", request.OriginRegionName.Trim());
            insert.Parameters.AddWithValue("destination_region_id", destinationRegionId);
            insert.Parameters.AddWithValue("destination_region_name", request.DestinationRegionName.Trim());
            insert.Parameters.AddWithValue("duration_seconds", durationSeconds);
            insert.Parameters.AddWithValue("dispatched_at", now);
            insert.Parameters.AddWithValue("arrives_at", arrivesAt);
            insert.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            insert.Parameters.AddWithValue("created_at", now);
            insert.Parameters.AddWithValue("updated_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var shipment = await ReadShipmentAsync(connection, transaction, normalizedCompanyId, shipmentId, now)
            ?? throw new InvalidOperationException("Created shipment was not found.");
        var updatedAssets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<ShipmentMutationResponse>.Accepted(new ShipmentMutationResponse(
            Completed: false,
            Message: $"Dispatched {quantity} {request.ItemName.Trim()} to {request.DestinationRegionName.Trim()}. It arrives at {arrivesAt:O}.",
            Shipment: shipment,
            Assets: updatedAssets!,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ShipmentMutationResponse>> DeliverCompanyShipmentAsync(
        string companyId,
        string shipmentId,
        string? actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedShipmentId = NormalizeId(shipmentId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<ShipmentMutationResponse>.BadRequest("Actor player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var role = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (role is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<ShipmentMutationResponse>.Forbidden("You must be a company member to deliver shipments.")
                : StoreResult<ShipmentMutationResponse>.NotFound("Company was not found.");
        }

        await AdvanceShipmentsAsync(connection, transaction, normalizedCompanyId, now);
        var shipment = await ReadShipmentForUpdateAsync(connection, transaction, normalizedCompanyId, normalizedShipmentId, now);
        if (shipment is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ShipmentMutationResponse>.NotFound("Shipment was not found.");
        }

        if (string.Equals(shipment.Status, "delivered", StringComparison.OrdinalIgnoreCase))
        {
            var deliveredAssets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
            await transaction.CommitAsync();
            return StoreResult<ShipmentMutationResponse>.Ok(new ShipmentMutationResponse(
                Completed: true,
                Message: "Shipment was already delivered.",
                Shipment: shipment,
                Assets: deliveredAssets!,
                UpdatedAt: DateTimeOffset.UtcNow));
        }

        if (shipment.ArrivesAt > now)
        {
            await transaction.RollbackAsync();
            return StoreResult<ShipmentMutationResponse>.Conflict(
                $"Shipment is still in transit until {shipment.ArrivesAt:O}.");
        }

        var delivered = await DeliverShipmentAsync(connection, transaction, shipment, now);
        if (delivered.Error is not null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ShipmentMutationResponse>.Conflict(delivered.Error);
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var updatedShipment = await ReadShipmentAsync(connection, transaction, normalizedCompanyId, normalizedShipmentId, now)
            ?? throw new InvalidOperationException("Delivered shipment was not found.");
        var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<ShipmentMutationResponse>.Ok(new ShipmentMutationResponse(
            Completed: true,
            Message: $"Delivered {updatedShipment.Quantity} {updatedShipment.ItemName} to {updatedShipment.DestinationRegionName}.",
            Shipment: updatedShipment,
            Assets: assets!,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    private static async Task AdvanceExtractionJobsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE production.company_extraction_jobs
            SET status = CASE
                    WHEN completes_at <= @now THEN 'completed'
                    WHEN started_at <= @now THEN 'running'
                    ELSE status
                END,
                completed_at = CASE
                    WHEN completes_at <= @now THEN COALESCE(completed_at, completes_at)
                    ELSE completed_at
                END,
                updated_at = @now
            WHERE company_id = @company_id
              AND status IN ('queued', 'running')
              AND (started_at <= @now OR completes_at <= @now);
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("now", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task AdvanceShipmentsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        DateTimeOffset now)
    {
        var dueShipments = new List<CompanyShipmentDto>();
        await using (var command = new NpgsqlCommand("""
            SELECT shipment_id, company_id, actor_player_id, item_id, item_name, item_category,
                   quantity, origin_region_id, origin_region_name, destination_region_id,
                   destination_region_name, status, duration_seconds, dispatched_at, arrives_at,
                   delivered_at, last_error, created_at, updated_at
            FROM production.company_shipments
            WHERE company_id = @company_id
              AND status = 'in_transit'
              AND arrives_at <= @now
            ORDER BY arrives_at, shipment_id
            FOR UPDATE SKIP LOCKED;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("company_id", companyId);
            command.Parameters.AddWithValue("now", now);
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                dueShipments.Add(ReadShipment(reader, now));
            }
        }

        foreach (var shipment in dueShipments)
        {
            await DeliverShipmentAsync(connection, transaction, shipment, now);
        }
    }

    private static async Task<ShipmentDeliveryResult> DeliverShipmentAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        CompanyShipmentDto shipment,
        DateTimeOffset now)
    {
        var storageError = await GrantCompanyInventoryAsync(
            connection,
            transaction,
            shipment.CompanyId,
            shipment.ItemId,
            shipment.ItemName,
            shipment.ItemCategory,
            shipment.Quantity,
            $"Shipment delivered from {shipment.OriginRegionName} to {shipment.DestinationRegionName}.",
            now);
        if (storageError is not null)
        {
            await using var errorUpdate = new NpgsqlCommand("""
                UPDATE production.company_shipments
                SET last_error = @last_error,
                    updated_at = @updated_at
                WHERE company_id = @company_id AND shipment_id = @shipment_id;
                """, connection, transaction);
            errorUpdate.Parameters.AddWithValue("company_id", shipment.CompanyId);
            errorUpdate.Parameters.AddWithValue("shipment_id", shipment.ShipmentId);
            errorUpdate.Parameters.AddWithValue("last_error", storageError);
            errorUpdate.Parameters.AddWithValue("updated_at", now);
            await errorUpdate.ExecuteNonQueryAsync();
            return new ShipmentDeliveryResult(storageError);
        }

        await using var update = new NpgsqlCommand("""
            UPDATE production.company_shipments
            SET status = 'delivered',
                delivered_at = COALESCE(delivered_at, @delivered_at),
                last_error = NULL,
                updated_at = @updated_at
            WHERE company_id = @company_id AND shipment_id = @shipment_id;
            """, connection, transaction);
        update.Parameters.AddWithValue("company_id", shipment.CompanyId);
        update.Parameters.AddWithValue("shipment_id", shipment.ShipmentId);
        update.Parameters.AddWithValue("delivered_at", now);
        update.Parameters.AddWithValue("updated_at", now);
        await update.ExecuteNonQueryAsync();
        return new ShipmentDeliveryResult(null);
    }

    private static async Task<int> ReadExtractionQueueDepthForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string siteId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT COUNT(*)
            FROM production.company_extraction_jobs
            WHERE company_id = @company_id
              AND site_id = @site_id
              AND status IN ('queued', 'running', 'completed');
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("site_id", siteId);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private static async Task<DateTimeOffset?> ReadLatestExtractionCompletesAtAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string siteId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT MAX(completes_at)
            FROM production.company_extraction_jobs
            WHERE company_id = @company_id
              AND site_id = @site_id
              AND status IN ('queued', 'running');
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("site_id", siteId);
        var result = await command.ExecuteScalarAsync();
        return result is DBNull or null ? null : (DateTimeOffset)result;
    }

    private static async Task<List<CompanyExtractionJobDto>> ReadExtractionJobsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        DateTimeOffset now)
    {
        await using var command = ExtractionSelectCommand(
            connection,
            transaction,
            "WHERE company_id = @company_id AND status <> 'cancelled' ORDER BY completes_at DESC, created_at DESC");
        command.Parameters.AddWithValue("company_id", companyId);

        var jobs = new List<CompanyExtractionJobDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            jobs.Add(ReadExtractionJob(reader, now));
        }

        return jobs;
    }

    private static async Task<CompanyExtractionJobDto?> ReadExtractionJobAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string jobId,
        DateTimeOffset now)
    {
        await using var command = ExtractionSelectCommand(
            connection,
            transaction,
            "WHERE company_id = @company_id AND job_id = @job_id");
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("job_id", jobId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadExtractionJob(reader, now) : null;
    }

    private static async Task<CompanyExtractionJobDto?> ReadExtractionJobForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string jobId,
        DateTimeOffset now)
    {
        await using var command = ExtractionSelectCommand(
            connection,
            transaction,
            "WHERE company_id = @company_id AND job_id = @job_id FOR UPDATE");
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("job_id", jobId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadExtractionJob(reader, now) : null;
    }

    private static async Task<CompanyExtractionJobDto?> ReadExtractionJobByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey,
        DateTimeOffset now)
    {
        await using var command = ExtractionSelectCommand(
            connection,
            transaction,
            "WHERE idempotency_key = @idempotency_key");
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadExtractionJob(reader, now) : null;
    }

    private static NpgsqlCommand ExtractionSelectCommand(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string whereClause)
    {
        return new NpgsqlCommand($"""
            SELECT job_id, company_id, actor_player_id, site_id, region_id, region_name,
                   country_id, resource_id, resource_name, item_id, item_name, item_category,
                   requested_runs, base_yield, yield_quantity, status, duration_seconds,
                   started_at, completes_at, completed_at, claimed_at, idempotency_key,
                   created_at, updated_at
            FROM production.company_extraction_jobs
            {whereClause};
            """, connection, transaction);
    }

    private static CompanyExtractionJobDto ReadExtractionJob(NpgsqlDataReader reader, DateTimeOffset now)
    {
        var status = reader.GetString(15);
        var completesAt = reader.GetFieldValue<DateTimeOffset>(18);
        DateTimeOffset? claimedAt = reader.IsDBNull(20) ? null : reader.GetFieldValue<DateTimeOffset>(20);
        return new CompanyExtractionJobDto(
            JobId: reader.GetString(0),
            CompanyId: reader.GetString(1),
            ActorPlayerId: reader.GetString(2),
            SiteId: reader.GetString(3),
            RegionId: reader.GetString(4),
            RegionName: reader.GetString(5),
            CountryId: reader.GetString(6),
            ResourceId: reader.GetString(7),
            ResourceName: reader.GetString(8),
            ItemId: reader.GetString(9),
            ItemName: reader.GetString(10),
            ItemCategory: reader.GetString(11),
            RequestedRuns: reader.GetInt32(12),
            BaseYield: reader.GetInt32(13),
            YieldQuantity: reader.GetInt32(14),
            Status: status,
            DurationSeconds: reader.GetInt32(16),
            StartedAt: reader.GetFieldValue<DateTimeOffset>(17),
            CompletesAt: completesAt,
            CompletedAt: reader.IsDBNull(19) ? null : reader.GetFieldValue<DateTimeOffset>(19),
            ClaimedAt: claimedAt,
            IdempotencyKey: reader.GetString(21),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(22),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(23),
            CanClaim: claimedAt is null &&
                completesAt <= now &&
                string.Equals(status, "completed", StringComparison.OrdinalIgnoreCase));
    }

    private static async Task<List<CompanyShipmentDto>> ReadShipmentsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        DateTimeOffset now)
    {
        await using var command = ShipmentSelectCommand(
            connection,
            transaction,
            "WHERE company_id = @company_id AND status <> 'cancelled' ORDER BY arrives_at DESC, created_at DESC");
        command.Parameters.AddWithValue("company_id", companyId);

        var shipments = new List<CompanyShipmentDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            shipments.Add(ReadShipment(reader, now));
        }

        return shipments;
    }

    private static async Task<CompanyShipmentDto?> ReadShipmentAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string shipmentId,
        DateTimeOffset now)
    {
        await using var command = ShipmentSelectCommand(
            connection,
            transaction,
            "WHERE company_id = @company_id AND shipment_id = @shipment_id");
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("shipment_id", shipmentId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadShipment(reader, now) : null;
    }

    private static async Task<CompanyShipmentDto?> ReadShipmentForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string shipmentId,
        DateTimeOffset now)
    {
        await using var command = ShipmentSelectCommand(
            connection,
            transaction,
            "WHERE company_id = @company_id AND shipment_id = @shipment_id FOR UPDATE");
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("shipment_id", shipmentId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadShipment(reader, now) : null;
    }

    private static async Task<CompanyShipmentDto?> ReadShipmentByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey,
        DateTimeOffset now)
    {
        await using var command = ShipmentSelectCommand(
            connection,
            transaction,
            "WHERE idempotency_key = @idempotency_key");
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadShipment(reader, now) : null;
    }

    private static NpgsqlCommand ShipmentSelectCommand(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string whereClause)
    {
        return new NpgsqlCommand($"""
            SELECT shipment_id, company_id, actor_player_id, item_id, item_name, item_category,
                   quantity, origin_region_id, origin_region_name, destination_region_id,
                   destination_region_name, status, duration_seconds, dispatched_at, arrives_at,
                   delivered_at, last_error, created_at, updated_at
            FROM production.company_shipments
            {whereClause};
            """, connection, transaction);
    }

    private static CompanyShipmentDto ReadShipment(NpgsqlDataReader reader, DateTimeOffset now)
    {
        var status = reader.GetString(11);
        var arrivesAt = reader.GetFieldValue<DateTimeOffset>(14);
        return new CompanyShipmentDto(
            ShipmentId: reader.GetString(0),
            CompanyId: reader.GetString(1),
            ActorPlayerId: reader.GetString(2),
            ItemId: reader.GetString(3),
            ItemName: reader.GetString(4),
            ItemCategory: reader.GetString(5),
            Quantity: reader.GetInt32(6),
            OriginRegionId: reader.GetString(7),
            OriginRegionName: reader.GetString(8),
            DestinationRegionId: reader.GetString(9),
            DestinationRegionName: reader.GetString(10),
            Status: status,
            DurationSeconds: reader.GetInt32(12),
            DispatchedAt: reader.GetFieldValue<DateTimeOffset>(13),
            ArrivesAt: arrivesAt,
            DeliveredAt: reader.IsDBNull(15) ? null : reader.GetFieldValue<DateTimeOffset>(15),
            LastError: reader.IsDBNull(16) ? null : reader.GetString(16),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(17),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(18),
            CanDeliver: string.Equals(status, "in_transit", StringComparison.OrdinalIgnoreCase) && arrivesAt <= now);
    }
}

internal sealed record CompanyExtractionStartRequest(
    string? ActorPlayerId,
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
    string? IdempotencyKey);

internal sealed record CompanyShipmentDispatchRequest(
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

internal sealed record ResourceLogisticsDashboardResponse(
    string CompanyId,
    CompanyExtractionJobDto[] Extractions,
    CompanyShipmentDto[] Shipments,
    int InTransitQuantity,
    CompanyAssetsDto Assets,
    DateTimeOffset UpdatedAt);

internal sealed record ExtractionMutationResponse(
    bool Completed,
    string Message,
    CompanyExtractionJobDto Extraction,
    CompanyAssetsDto Assets,
    DateTimeOffset UpdatedAt);

internal sealed record ExtractionClaimResponse(
    bool Completed,
    bool AlreadyClaimed,
    string Message,
    CompanyExtractionJobDto Extraction,
    CompanyAssetsDto Assets,
    int DepletionAmount,
    DateTimeOffset UpdatedAt);

internal sealed record ShipmentMutationResponse(
    bool Completed,
    string Message,
    CompanyShipmentDto Shipment,
    CompanyAssetsDto Assets,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyExtractionJobDto(
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

internal sealed record CompanyShipmentDto(
    string ShipmentId,
    string CompanyId,
    string ActorPlayerId,
    string ItemId,
    string ItemName,
    string ItemCategory,
    int Quantity,
    string OriginRegionId,
    string OriginRegionName,
    string DestinationRegionId,
    string DestinationRegionName,
    string Status,
    int DurationSeconds,
    DateTimeOffset DispatchedAt,
    DateTimeOffset ArrivesAt,
    DateTimeOffset? DeliveredAt,
    string? LastError,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    bool CanDeliver);

internal sealed record ShipmentDeliveryResult(string? Error);

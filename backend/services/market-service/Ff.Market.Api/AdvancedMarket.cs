using Npgsql;

internal static class AdvancedMarketEndpoints
{
    public static void MapAdvancedMarketEndpoints(this WebApplication app)
    {
        app.MapGet("/market/price-history", async (
            string? itemId,
            int? limit,
            MarketStore market) =>
            Results.Ok(await market.GetPriceHistoryAsync(itemId, ClampLimit(limit))))
            .WithName("GetMarketPriceHistory");

        app.MapGet("/market/order-book", async (
            string? itemId,
            MarketStore market) =>
            Results.Ok(await market.GetOrderBookAsync(itemId)))
            .WithName("GetMarketOrderBook");

        app.MapGet("/trade/offers", async (
            string? actorType,
            string? actorId,
            string? status,
            MarketStore market) =>
            Results.Ok(await market.GetTradeOffersAsync(actorType, actorId, status)))
            .WithName("ListTradeOffers");

        app.MapGet("/trade/offers/{offerId}", async (
            string offerId,
            MarketStore market) =>
        {
            var offer = await market.GetTradeOfferAsync(offerId);
            return offer is null
                ? Results.NotFound(new ErrorResponse("Trade offer was not found."))
                : Results.Ok(offer);
        }).WithName("GetTradeOffer");

        app.MapPost("/trade/offers", async (
            CreateTradeOfferRequest request,
            HttpRequest httpRequest,
            MarketStore market,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var validation = ValidateCreateTradeOffer(request);
            return validation is not null
                ? Results.BadRequest(new ErrorResponse(validation))
                : Results.Ok(await market.CreateTradeOfferAsync(request));
        }).WithName("CreateTradeOffer");

        app.MapPost("/trade/offers/{offerId}/accept", async (
            string offerId,
            AcceptTradeOfferRequest request,
            HttpRequest httpRequest,
            MarketStore market,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            if (string.IsNullOrWhiteSpace(request.AcceptedByPlayerId) ||
                string.IsNullOrWhiteSpace(request.IdempotencyKey))
            {
                return Results.BadRequest(new ErrorResponse("Accepted by player and idempotency key are required."));
            }

            return Results.Ok(await market.AcceptTradeOfferAsync(offerId, request));
        }).WithName("AcceptTradeOffer");

        app.MapPost("/trade/offers/{offerId}/cancel", async (
            string offerId,
            CancelTradeOfferRequest request,
            HttpRequest httpRequest,
            MarketStore market,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return Results.Ok(await market.CancelTradeOfferAsync(offerId, request));
        }).WithName("CancelTradeOffer");

        app.MapPost("/trade/contracts/{contractId}/fulfill", async (
            string contractId,
            FulfillTradeContractRequest request,
            HttpRequest httpRequest,
            MarketStore market,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return Results.Ok(await market.FulfillTradeContractAsync(contractId, request));
        }).WithName("FulfillTradeContract");

        app.MapPost("/trade/contracts/{contractId}/fail", async (
            string contractId,
            FailTradeContractRequest request,
            HttpRequest httpRequest,
            MarketStore market,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return Results.Ok(await market.FailTradeContractAsync(contractId, request));
        }).WithName("FailTradeContract");
    }

    private static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
    {
        var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
        return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
            string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
    }

    private static string? ValidateCreateTradeOffer(CreateTradeOfferRequest request)
    {
        if (!TradeActorTypes.IsValid(request.SellerType) ||
            !TradeActorTypes.IsValid(request.BuyerType) ||
            string.IsNullOrWhiteSpace(request.SellerId) ||
            string.IsNullOrWhiteSpace(request.BuyerId) ||
            string.IsNullOrWhiteSpace(request.CreatorPlayerId) ||
            string.IsNullOrWhiteSpace(request.ItemId) ||
            string.IsNullOrWhiteSpace(request.ItemName) ||
            string.IsNullOrWhiteSpace(request.Category) ||
            string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            return "Seller, buyer, item, creator, and idempotency key are required.";
        }

        if (request.Quantity <= 0 || request.Quantity > 10_000)
        {
            return "Quantity must be between 1 and 10000.";
        }

        if (request.PricePerUnit <= 0 || request.PricePerUnit > 1_000_000)
        {
            return "Price per unit must be between 1 and 1000000.";
        }

        if (string.Equals(request.SellerType, request.BuyerType, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(request.SellerId, request.BuyerId, StringComparison.OrdinalIgnoreCase))
        {
            return "Seller and buyer must be different actors.";
        }

        return null;
    }

    private static int ClampLimit(int? limit)
    {
        return Math.Clamp(limit ?? 50, 1, 200);
    }
}

internal sealed partial class MarketStore
{
    public async Task InitializeAdvancedMarketAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS market.price_history (
                price_history_id text PRIMARY KEY,
                item_id text NOT NULL,
                item_name text NOT NULL,
                category text NOT NULL,
                quantity integer NOT NULL,
                price_per_unit integer NOT NULL,
                seller_type text NOT NULL,
                seller_id text NOT NULL,
                buyer_type text NOT NULL,
                buyer_id text NOT NULL,
                source_type text NOT NULL,
                source_id text NOT NULL UNIQUE,
                traded_at timestamptz NOT NULL,
                CONSTRAINT price_history_quantity_check CHECK (quantity > 0),
                CONSTRAINT price_history_price_check CHECK (price_per_unit > 0)
            );

            CREATE TABLE IF NOT EXISTS market.trade_offers (
                offer_id text PRIMARY KEY,
                creator_player_id text NOT NULL,
                seller_type text NOT NULL,
                seller_id text NOT NULL,
                buyer_type text NOT NULL,
                buyer_id text NOT NULL,
                item_id text NOT NULL,
                item_name text NOT NULL,
                category text NOT NULL,
                quantity integer NOT NULL,
                price_per_unit integer NOT NULL,
                status text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                accept_idempotency_key text NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                expires_at timestamptz NULL,
                responded_at timestamptz NULL,
                CONSTRAINT trade_offers_quantity_check CHECK (quantity > 0),
                CONSTRAINT trade_offers_price_check CHECK (price_per_unit > 0),
                CONSTRAINT trade_offers_status_check CHECK (status IN ('open', 'accepted', 'fulfilled', 'cancelled', 'failed'))
            );

            CREATE TABLE IF NOT EXISTS market.trade_contracts (
                contract_id text PRIMARY KEY,
                offer_id text NOT NULL UNIQUE REFERENCES market.trade_offers (offer_id),
                accepted_by_player_id text NOT NULL,
                status text NOT NULL,
                failure_reason text NOT NULL DEFAULT '',
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                fulfilled_at timestamptz NULL,
                CONSTRAINT trade_contracts_status_check CHECK (status IN ('accepted', 'fulfilled', 'failed'))
            );

            CREATE INDEX IF NOT EXISTS price_history_item_traded_at_idx
            ON market.price_history (item_id, traded_at DESC);

            CREATE INDEX IF NOT EXISTS trade_offers_actor_status_idx
            ON market.trade_offers (seller_type, seller_id, buyer_type, buyer_id, status, updated_at DESC);

            CREATE INDEX IF NOT EXISTS trade_offers_status_updated_idx
            ON market.trade_offers (status, updated_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<PriceHistoryResponse> GetPriceHistoryAsync(string? itemId, int limit)
    {
        var normalizedItemId = string.IsNullOrWhiteSpace(itemId) ? string.Empty : NormalizeId(itemId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT price_history_id, item_id, item_name, category, quantity, price_per_unit,
                   seller_type, seller_id, buyer_type, buyer_id, source_type, source_id, traded_at
            FROM market.price_history
            WHERE @item_id = '' OR item_id = @item_id
            ORDER BY traded_at DESC, price_history_id DESC
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("item_id", normalizedItemId);
        command.Parameters.AddWithValue("limit", limit);

        var entries = new List<PriceHistoryEntryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(ReadPriceHistory(reader));
        }

        return new PriceHistoryResponse(normalizedItemId.Length == 0 ? null : normalizedItemId, entries.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<OrderBookResponse> GetOrderBookAsync(string? itemId)
    {
        var normalizedItemId = string.IsNullOrWhiteSpace(itemId) ? string.Empty : NormalizeId(itemId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT item_id, item_name, category, price_per_unit, SUM(quantity)::integer AS quantity, COUNT(*)::integer AS order_count
            FROM (
                SELECT item_id, item_name, category, price_per_unit, quantity
                FROM market.listings
                WHERE status = @open_status AND quantity > 0
                UNION ALL
                SELECT item_id, item_name, category, price_per_unit, quantity
                FROM market.trade_offers
                WHERE status = @open_status
            ) orders
            WHERE @item_id = '' OR item_id = @item_id
            GROUP BY item_id, item_name, category, price_per_unit
            ORDER BY item_id, price_per_unit, item_name;
            """, connection);
        command.Parameters.AddWithValue("item_id", normalizedItemId);
        command.Parameters.AddWithValue("open_status", AdvancedMarketStatuses.Open);

        var entries = new List<OrderBookEntryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(new OrderBookEntryDto(
                ItemId: reader.GetString(0),
                ItemName: reader.GetString(1),
                Category: reader.GetString(2),
                QualityTier: QualityTierFromItemId(reader.GetString(0)),
                PricePerUnit: reader.GetInt32(3),
                Quantity: reader.GetInt32(4),
                OrderCount: reader.GetInt32(5)));
        }

        return new OrderBookResponse(normalizedItemId.Length == 0 ? null : normalizedItemId, entries.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<TradeOfferListResponse> GetTradeOffersAsync(string? actorType, string? actorId, string? status)
    {
        var normalizedActorType = TradeActorTypes.Normalize(actorType);
        var normalizedActorId = string.IsNullOrWhiteSpace(actorId) ? string.Empty : NormalizeId(actorId);
        var normalizedStatus = NormalizeOfferStatus(status);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT offer_id, creator_player_id, seller_type, seller_id, buyer_type, buyer_id,
                   item_id, item_name, category, quantity, price_per_unit, status, idempotency_key,
                   accept_idempotency_key, created_at, updated_at, expires_at, responded_at
            FROM market.trade_offers
            WHERE (@status = '' OR status = @status)
              AND (
                  @actor_type = ''
                  OR ((seller_type = @actor_type AND seller_id = @actor_id)
                      OR (buyer_type = @actor_type AND buyer_id = @actor_id))
              )
            ORDER BY CASE status WHEN 'open' THEN 0 WHEN 'accepted' THEN 1 ELSE 2 END,
                     updated_at DESC,
                     offer_id DESC
            LIMIT 100;
            """, connection);
        command.Parameters.AddWithValue("actor_type", normalizedActorType);
        command.Parameters.AddWithValue("actor_id", normalizedActorId);
        command.Parameters.AddWithValue("status", normalizedStatus);

        var offers = new List<TradeOfferDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            offers.Add(ReadTradeOffer(reader));
        }

        return new TradeOfferListResponse(offers.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<TradeOfferDto?> GetTradeOfferAsync(string offerId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        return await ReadTradeOfferAsync(connection, null, NormalizeId(offerId));
    }

    public async Task<TradeOfferMutationResponse> CreateTradeOfferAsync(CreateTradeOfferRequest request)
    {
        var offerId = string.IsNullOrWhiteSpace(request.OfferId)
            ? $"offer-{Guid.NewGuid():N}"
            : NormalizeId(request.OfferId);
        var idempotencyKey = NormalizeId(request.IdempotencyKey);
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existing = await ReadTradeOfferByIdempotencyKeyAsync(connection, transaction, idempotencyKey);
        if (existing is not null)
        {
            await transaction.CommitAsync();
            return new TradeOfferMutationResponse(true, "Trade offer was already created.", existing, null);
        }

        await using (var command = new NpgsqlCommand("""
            INSERT INTO market.trade_offers (
                offer_id, creator_player_id, seller_type, seller_id, buyer_type, buyer_id,
                item_id, item_name, category, quantity, price_per_unit, status,
                idempotency_key, created_at, updated_at, expires_at
            )
            VALUES (
                @offer_id, @creator_player_id, @seller_type, @seller_id, @buyer_type, @buyer_id,
                @item_id, @item_name, @category, @quantity, @price_per_unit, @status,
                @idempotency_key, @created_at, @updated_at, @expires_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("offer_id", offerId);
            command.Parameters.AddWithValue("creator_player_id", NormalizeId(request.CreatorPlayerId));
            command.Parameters.AddWithValue("seller_type", TradeActorTypes.Normalize(request.SellerType));
            command.Parameters.AddWithValue("seller_id", NormalizeId(request.SellerId));
            command.Parameters.AddWithValue("buyer_type", TradeActorTypes.Normalize(request.BuyerType));
            command.Parameters.AddWithValue("buyer_id", NormalizeId(request.BuyerId));
            command.Parameters.AddWithValue("item_id", NormalizeId(request.ItemId));
            command.Parameters.AddWithValue("item_name", request.ItemName.Trim());
            command.Parameters.AddWithValue("category", request.Category.Trim());
            command.Parameters.AddWithValue("quantity", request.Quantity);
            command.Parameters.AddWithValue("price_per_unit", request.PricePerUnit);
            command.Parameters.AddWithValue("status", AdvancedMarketStatuses.Open);
            command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            command.Parameters.AddWithValue("expires_at", (object?)request.ExpiresAt ?? DBNull.Value);
            await command.ExecuteNonQueryAsync();
        }

        var offer = await ReadTradeOfferAsync(connection, transaction, offerId)
            ?? throw new InvalidOperationException("Trade offer could not be read after creation.");
        await transaction.CommitAsync();
        return new TradeOfferMutationResponse(true, "Trade offer created.", offer, null);
    }

    public async Task<TradeOfferMutationResponse> AcceptTradeOfferAsync(string offerId, AcceptTradeOfferRequest request)
    {
        var normalizedOfferId = NormalizeId(offerId);
        var acceptKey = NormalizeId(request.IdempotencyKey);
        var acceptedByPlayerId = NormalizeId(request.AcceptedByPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var offer = await ReadTradeOfferForUpdateAsync(connection, transaction, normalizedOfferId);
        if (offer is null)
        {
            await transaction.RollbackAsync();
            return new TradeOfferMutationResponse(false, "Trade offer was not found.", null, null);
        }

        var existingContract = await ReadTradeContractForOfferAsync(connection, transaction, normalizedOfferId);
        if (!string.Equals(offer.Status, AdvancedMarketStatuses.Open, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            var completed = existingContract is not null &&
                string.Equals(existingContract.IdempotencyKey, acceptKey, StringComparison.Ordinal);
            return new TradeOfferMutationResponse(
                completed,
                completed ? "Trade offer was already accepted." : $"Trade offer is {offer.Status}.",
                offer,
                completed ? existingContract : null);
        }

        var contractId = $"contract-{Guid.NewGuid():N}";
        await using (var update = new NpgsqlCommand("""
            UPDATE market.trade_offers
            SET status = @status,
                accept_idempotency_key = @accept_idempotency_key,
                responded_at = @responded_at,
                updated_at = @updated_at
            WHERE offer_id = @offer_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("offer_id", normalizedOfferId);
            update.Parameters.AddWithValue("status", AdvancedMarketStatuses.Accepted);
            update.Parameters.AddWithValue("accept_idempotency_key", acceptKey);
            update.Parameters.AddWithValue("responded_at", now);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await using (var insert = new NpgsqlCommand("""
            INSERT INTO market.trade_contracts (
                contract_id, offer_id, accepted_by_player_id, status, idempotency_key, created_at, updated_at
            )
            VALUES (
                @contract_id, @offer_id, @accepted_by_player_id, @status, @idempotency_key, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("contract_id", contractId);
            insert.Parameters.AddWithValue("offer_id", normalizedOfferId);
            insert.Parameters.AddWithValue("accepted_by_player_id", acceptedByPlayerId);
            insert.Parameters.AddWithValue("status", AdvancedMarketStatuses.Accepted);
            insert.Parameters.AddWithValue("idempotency_key", acceptKey);
            insert.Parameters.AddWithValue("created_at", now);
            insert.Parameters.AddWithValue("updated_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        var acceptedOffer = await ReadTradeOfferAsync(connection, transaction, normalizedOfferId)
            ?? throw new InvalidOperationException("Accepted trade offer could not be read.");
        var contract = await ReadTradeContractAsync(connection, transaction, contractId)
            ?? throw new InvalidOperationException("Trade contract could not be read.");
        await transaction.CommitAsync();

        return new TradeOfferMutationResponse(true, "Trade offer accepted.", acceptedOffer, contract);
    }

    public async Task<TradeOfferMutationResponse> CancelTradeOfferAsync(string offerId, CancelTradeOfferRequest request)
    {
        var normalizedOfferId = NormalizeId(offerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var offer = await ReadTradeOfferForUpdateAsync(connection, transaction, normalizedOfferId);
        if (offer is null)
        {
            await transaction.RollbackAsync();
            return new TradeOfferMutationResponse(false, "Trade offer was not found.", null, null);
        }

        if (string.Equals(offer.Status, AdvancedMarketStatuses.Cancelled, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new TradeOfferMutationResponse(true, "Trade offer was already cancelled.", offer, null);
        }

        if (!string.Equals(offer.Status, AdvancedMarketStatuses.Open, StringComparison.Ordinal))
        {
            await transaction.RollbackAsync();
            return new TradeOfferMutationResponse(false, $"Trade offer cannot be cancelled from status {offer.Status}.", offer, null);
        }

        await using (var update = new NpgsqlCommand("""
            UPDATE market.trade_offers
            SET status = @status,
                responded_at = COALESCE(responded_at, @updated_at),
                updated_at = @updated_at
            WHERE offer_id = @offer_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("offer_id", normalizedOfferId);
            update.Parameters.AddWithValue("status", AdvancedMarketStatuses.Cancelled);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        var cancelledOffer = await ReadTradeOfferAsync(connection, transaction, normalizedOfferId)
            ?? throw new InvalidOperationException("Cancelled trade offer could not be read.");
        await transaction.CommitAsync();
        return new TradeOfferMutationResponse(true, "Trade offer cancelled.", cancelledOffer, null);
    }

    public async Task<TradeOfferMutationResponse> FulfillTradeContractAsync(string contractId, FulfillTradeContractRequest request)
    {
        var normalizedContractId = NormalizeId(contractId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var contract = await ReadTradeContractForUpdateAsync(connection, transaction, normalizedContractId);
        if (contract is null)
        {
            await transaction.RollbackAsync();
            return new TradeOfferMutationResponse(false, "Trade contract was not found.", null, null);
        }

        var offer = await ReadTradeOfferForUpdateAsync(connection, transaction, contract.OfferId)
            ?? throw new InvalidOperationException("Trade contract offer was not found.");
        if (string.Equals(contract.Status, AdvancedMarketStatuses.Fulfilled, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new TradeOfferMutationResponse(true, "Trade contract was already fulfilled.", offer, contract);
        }

        if (!string.Equals(contract.Status, AdvancedMarketStatuses.Accepted, StringComparison.Ordinal))
        {
            await transaction.RollbackAsync();
            return new TradeOfferMutationResponse(false, $"Trade contract is {contract.Status}.", offer, contract);
        }

        await using (var updateContract = new NpgsqlCommand("""
            UPDATE market.trade_contracts
            SET status = @status,
                fulfilled_at = COALESCE(fulfilled_at, @fulfilled_at),
                updated_at = @updated_at
            WHERE contract_id = @contract_id;
            """, connection, transaction))
        {
            updateContract.Parameters.AddWithValue("contract_id", normalizedContractId);
            updateContract.Parameters.AddWithValue("status", AdvancedMarketStatuses.Fulfilled);
            updateContract.Parameters.AddWithValue("fulfilled_at", now);
            updateContract.Parameters.AddWithValue("updated_at", now);
            await updateContract.ExecuteNonQueryAsync();
        }

        await using (var updateOffer = new NpgsqlCommand("""
            UPDATE market.trade_offers
            SET status = @status,
                updated_at = @updated_at
            WHERE offer_id = @offer_id;
            """, connection, transaction))
        {
            updateOffer.Parameters.AddWithValue("offer_id", offer.OfferId);
            updateOffer.Parameters.AddWithValue("status", AdvancedMarketStatuses.Fulfilled);
            updateOffer.Parameters.AddWithValue("updated_at", now);
            await updateOffer.ExecuteNonQueryAsync();
        }

        await InsertPriceHistoryAsync(
            connection,
            transaction,
            offer.ItemId,
            offer.ItemName,
            offer.Category,
            offer.Quantity,
            offer.PricePerUnit,
            offer.SellerType,
            offer.SellerId,
            offer.BuyerType,
            offer.BuyerId,
            "trade_contract",
            normalizedContractId,
            now);

        var fulfilledOffer = await ReadTradeOfferAsync(connection, transaction, offer.OfferId)
            ?? throw new InvalidOperationException("Fulfilled trade offer could not be read.");
        var fulfilledContract = await ReadTradeContractAsync(connection, transaction, normalizedContractId)
            ?? throw new InvalidOperationException("Fulfilled trade contract could not be read.");
        await transaction.CommitAsync();
        return new TradeOfferMutationResponse(true, "Trade contract fulfilled.", fulfilledOffer, fulfilledContract);
    }

    public async Task<TradeOfferMutationResponse> FailTradeContractAsync(string contractId, FailTradeContractRequest request)
    {
        var normalizedContractId = NormalizeId(contractId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var contract = await ReadTradeContractForUpdateAsync(connection, transaction, normalizedContractId);
        if (contract is null)
        {
            await transaction.RollbackAsync();
            return new TradeOfferMutationResponse(false, "Trade contract was not found.", null, null);
        }

        var offer = await ReadTradeOfferForUpdateAsync(connection, transaction, contract.OfferId)
            ?? throw new InvalidOperationException("Trade contract offer was not found.");
        if (!string.Equals(contract.Status, AdvancedMarketStatuses.Accepted, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new TradeOfferMutationResponse(true, $"Trade contract is already {contract.Status}.", offer, contract);
        }

        var failureReason = string.IsNullOrWhiteSpace(request.Reason)
            ? "Trade contract failed during settlement."
            : request.Reason.Trim();
        await using (var updateContract = new NpgsqlCommand("""
            UPDATE market.trade_contracts
            SET status = @status,
                failure_reason = @failure_reason,
                updated_at = @updated_at
            WHERE contract_id = @contract_id;
            """, connection, transaction))
        {
            updateContract.Parameters.AddWithValue("contract_id", normalizedContractId);
            updateContract.Parameters.AddWithValue("status", AdvancedMarketStatuses.Failed);
            updateContract.Parameters.AddWithValue("failure_reason", failureReason);
            updateContract.Parameters.AddWithValue("updated_at", now);
            await updateContract.ExecuteNonQueryAsync();
        }

        await using (var updateOffer = new NpgsqlCommand("""
            UPDATE market.trade_offers
            SET status = @status,
                updated_at = @updated_at
            WHERE offer_id = @offer_id;
            """, connection, transaction))
        {
            updateOffer.Parameters.AddWithValue("offer_id", offer.OfferId);
            updateOffer.Parameters.AddWithValue("status", AdvancedMarketStatuses.Failed);
            updateOffer.Parameters.AddWithValue("updated_at", now);
            await updateOffer.ExecuteNonQueryAsync();
        }

        var failedOffer = await ReadTradeOfferAsync(connection, transaction, offer.OfferId)
            ?? throw new InvalidOperationException("Failed trade offer could not be read.");
        var failedContract = await ReadTradeContractAsync(connection, transaction, normalizedContractId)
            ?? throw new InvalidOperationException("Failed trade contract could not be read.");
        await transaction.CommitAsync();
        return new TradeOfferMutationResponse(false, failureReason, failedOffer, failedContract);
    }

    private static async Task InsertPriceHistoryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string itemId,
        string itemName,
        string category,
        int quantity,
        int pricePerUnit,
        string sellerType,
        string sellerId,
        string buyerType,
        string buyerId,
        string sourceType,
        string sourceId,
        DateTimeOffset tradedAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO market.price_history (
                price_history_id, item_id, item_name, category, quantity, price_per_unit,
                seller_type, seller_id, buyer_type, buyer_id, source_type, source_id, traded_at
            )
            VALUES (
                @price_history_id, @item_id, @item_name, @category, @quantity, @price_per_unit,
                @seller_type, @seller_id, @buyer_type, @buyer_id, @source_type, @source_id, @traded_at
            )
            ON CONFLICT (source_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("price_history_id", $"price-{Guid.NewGuid():N}");
        command.Parameters.AddWithValue("item_id", NormalizeId(itemId));
        command.Parameters.AddWithValue("item_name", itemName.Trim());
        command.Parameters.AddWithValue("category", category.Trim());
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("price_per_unit", pricePerUnit);
        command.Parameters.AddWithValue("seller_type", sellerType.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("seller_id", NormalizeId(sellerId));
        command.Parameters.AddWithValue("buyer_type", buyerType.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("buyer_id", NormalizeId(buyerId));
        command.Parameters.AddWithValue("source_type", sourceType.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("source_id", NormalizeId(sourceId));
        command.Parameters.AddWithValue("traded_at", tradedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<TradeOfferDto?> ReadTradeOfferByIdempotencyKeyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT offer_id, creator_player_id, seller_type, seller_id, buyer_type, buyer_id,
                   item_id, item_name, category, quantity, price_per_unit, status, idempotency_key,
                   accept_idempotency_key, created_at, updated_at, expires_at, responded_at
            FROM market.trade_offers
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTradeOffer(reader) : null;
    }

    private static async Task<TradeOfferDto?> ReadTradeOfferAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string offerId)
    {
        await using var command = CreateTradeOfferReadCommand(connection, transaction, forUpdate: false);
        command.Parameters.AddWithValue("offer_id", offerId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTradeOffer(reader) : null;
    }

    private static async Task<TradeOfferDto?> ReadTradeOfferForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string offerId)
    {
        await using var command = CreateTradeOfferReadCommand(connection, transaction, forUpdate: true);
        command.Parameters.AddWithValue("offer_id", offerId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTradeOffer(reader) : null;
    }

    private static NpgsqlCommand CreateTradeOfferReadCommand(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        bool forUpdate)
    {
        var sql = """
            SELECT offer_id, creator_player_id, seller_type, seller_id, buyer_type, buyer_id,
                   item_id, item_name, category, quantity, price_per_unit, status, idempotency_key,
                   accept_idempotency_key, created_at, updated_at, expires_at, responded_at
            FROM market.trade_offers
            WHERE offer_id = @offer_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE";
        }

        return new NpgsqlCommand(sql, connection, transaction);
    }

    private static async Task<TradeContractDto?> ReadTradeContractForOfferAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string offerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT contract_id, offer_id, accepted_by_player_id, status, failure_reason,
                   idempotency_key, created_at, updated_at, fulfilled_at
            FROM market.trade_contracts
            WHERE offer_id = @offer_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("offer_id", offerId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTradeContract(reader) : null;
    }

    private static async Task<TradeContractDto?> ReadTradeContractAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string contractId)
    {
        await using var command = CreateTradeContractReadCommand(connection, transaction, forUpdate: false);
        command.Parameters.AddWithValue("contract_id", contractId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTradeContract(reader) : null;
    }

    private static async Task<TradeContractDto?> ReadTradeContractForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string contractId)
    {
        await using var command = CreateTradeContractReadCommand(connection, transaction, forUpdate: true);
        command.Parameters.AddWithValue("contract_id", contractId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTradeContract(reader) : null;
    }

    private static NpgsqlCommand CreateTradeContractReadCommand(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        bool forUpdate)
    {
        var sql = """
            SELECT contract_id, offer_id, accepted_by_player_id, status, failure_reason,
                   idempotency_key, created_at, updated_at, fulfilled_at
            FROM market.trade_contracts
            WHERE contract_id = @contract_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE";
        }

        return new NpgsqlCommand(sql, connection, transaction);
    }

    private static PriceHistoryEntryDto ReadPriceHistory(NpgsqlDataReader reader)
    {
        var itemId = reader.GetString(1);
        return new PriceHistoryEntryDto(
            PriceHistoryId: reader.GetString(0),
            ItemId: itemId,
            ItemName: reader.GetString(2),
            Category: reader.GetString(3),
            QualityTier: QualityTierFromItemId(itemId),
            Quantity: reader.GetInt32(4),
            PricePerUnit: reader.GetInt32(5),
            SellerType: reader.GetString(6),
            SellerId: reader.GetString(7),
            BuyerType: reader.GetString(8),
            BuyerId: reader.GetString(9),
            SourceType: reader.GetString(10),
            SourceId: reader.GetString(11),
            TradedAt: reader.GetFieldValue<DateTimeOffset>(12));
    }

    private static TradeOfferDto ReadTradeOffer(NpgsqlDataReader reader)
    {
        var itemId = reader.GetString(6);
        return new TradeOfferDto(
            OfferId: reader.GetString(0),
            CreatorPlayerId: reader.GetString(1),
            SellerType: reader.GetString(2),
            SellerId: reader.GetString(3),
            BuyerType: reader.GetString(4),
            BuyerId: reader.GetString(5),
            ItemId: itemId,
            ItemName: reader.GetString(7),
            Category: reader.GetString(8),
            QualityTier: QualityTierFromItemId(itemId),
            Quantity: reader.GetInt32(9),
            PricePerUnit: reader.GetInt32(10),
            Status: reader.GetString(11),
            IdempotencyKey: reader.GetString(12),
            AcceptIdempotencyKey: reader.IsDBNull(13) ? null : reader.GetString(13),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(14),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(15),
            ExpiresAt: reader.IsDBNull(16) ? null : reader.GetFieldValue<DateTimeOffset>(16),
            RespondedAt: reader.IsDBNull(17) ? null : reader.GetFieldValue<DateTimeOffset>(17));
    }

    private static TradeContractDto ReadTradeContract(NpgsqlDataReader reader)
    {
        return new TradeContractDto(
            ContractId: reader.GetString(0),
            OfferId: reader.GetString(1),
            AcceptedByPlayerId: reader.GetString(2),
            Status: reader.GetString(3),
            FailureReason: reader.GetString(4),
            IdempotencyKey: reader.GetString(5),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(6),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(7),
            FulfilledAt: reader.IsDBNull(8) ? null : reader.GetFieldValue<DateTimeOffset>(8));
    }

    private static string NormalizeOfferStatus(string? status)
    {
        var normalized = string.IsNullOrWhiteSpace(status) ? string.Empty : status.Trim().ToLowerInvariant();
        return normalized is "open" or "accepted" or "fulfilled" or "cancelled" or "failed"
            ? normalized
            : string.Empty;
    }

    private static int QualityTierFromItemId(string itemId)
    {
        var normalized = itemId.ToLowerInvariant();
        for (var tier = 10; tier >= 1; tier--)
        {
            if (normalized.Contains($"q{tier}", StringComparison.Ordinal))
            {
                return tier;
            }
        }

        return 1;
    }
}

internal static class TradeActorTypes
{
    public const string Player = "player";
    public const string Company = "company";

    public static bool IsValid(string? actorType)
    {
        return Normalize(actorType) is Player or Company;
    }

    public static string Normalize(string? actorType)
    {
        var normalized = string.IsNullOrWhiteSpace(actorType)
            ? string.Empty
            : actorType.Trim().ToLowerInvariant();
        return normalized is Player or Company ? normalized : string.Empty;
    }
}

internal static class AdvancedMarketStatuses
{
    public const string Open = "open";
    public const string Accepted = "accepted";
    public const string Fulfilled = "fulfilled";
    public const string Cancelled = "cancelled";
    public const string Failed = "failed";
}

internal sealed record PriceHistoryResponse(
    string? ItemId,
    PriceHistoryEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record PriceHistoryEntryDto(
    string PriceHistoryId,
    string ItemId,
    string ItemName,
    string Category,
    int QualityTier,
    int Quantity,
    int PricePerUnit,
    string SellerType,
    string SellerId,
    string BuyerType,
    string BuyerId,
    string SourceType,
    string SourceId,
    DateTimeOffset TradedAt);

internal sealed record OrderBookResponse(
    string? ItemId,
    OrderBookEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record OrderBookEntryDto(
    string ItemId,
    string ItemName,
    string Category,
    int QualityTier,
    int PricePerUnit,
    int Quantity,
    int OrderCount);

internal sealed record TradeOfferListResponse(
    TradeOfferDto[] Offers,
    DateTimeOffset UpdatedAt);

internal sealed record TradeOfferDto(
    string OfferId,
    string CreatorPlayerId,
    string SellerType,
    string SellerId,
    string BuyerType,
    string BuyerId,
    string ItemId,
    string ItemName,
    string Category,
    int QualityTier,
    int Quantity,
    int PricePerUnit,
    string Status,
    string IdempotencyKey,
    string? AcceptIdempotencyKey,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ExpiresAt,
    DateTimeOffset? RespondedAt);

internal sealed record TradeContractDto(
    string ContractId,
    string OfferId,
    string AcceptedByPlayerId,
    string Status,
    string FailureReason,
    string IdempotencyKey,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? FulfilledAt);

internal sealed record CreateTradeOfferRequest(
    string? OfferId,
    string CreatorPlayerId,
    string SellerType,
    string SellerId,
    string BuyerType,
    string BuyerId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string IdempotencyKey,
    DateTimeOffset? ExpiresAt = null);

internal sealed record AcceptTradeOfferRequest(
    string AcceptedByPlayerId,
    string IdempotencyKey);

internal sealed record CancelTradeOfferRequest(
    string? ActorPlayerId,
    string? Reason,
    string? IdempotencyKey);

internal sealed record FulfillTradeContractRequest(string? IdempotencyKey);

internal sealed record FailTradeContractRequest(string? Reason);

internal sealed record TradeOfferMutationResponse(
    bool Completed,
    string Message,
    TradeOfferDto? Offer,
    TradeContractDto? Contract);

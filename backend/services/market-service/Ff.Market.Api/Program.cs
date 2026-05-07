using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<MarketStore>();

var metadata = new ServiceMetadata(
    Service: "market-service",
    DisplayName: "Market Service",
    Domain: "Trading, listings, order book, and market fees",
    Description: "Owns market listings and trade history for fixed-price MVP trading while reserving funds/items through economy boundaries.",
    Owns: ["sell orders", "buy orders", "order book", "trade history", "market fees"],
    Responsibilities: ["Create and read market listings", "Coordinate buyer/seller reservations", "Record fills and fees"]);

var app = builder.Build();

var marketStore = app.Services.GetRequiredService<MarketStore>();
await marketStore.InitializeAsync();
await marketStore.InitializeAdvancedMarketAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapAdvancedMarketEndpoints();

app.MapGet("/market/listings", async (MarketStore market) =>
    Results.Ok(new MarketListingsResponse(
        Listings: await market.GetOpenListingsAsync(),
        UpdatedAt: DateTimeOffset.UtcNow))).WithName("GetMarketListings");

app.MapGet("/players/{sellerId}/market/listings", async (string sellerId, MarketStore market) =>
{
    var normalizedSellerId = MarketStore.NormalizeId(sellerId);
    return Results.Ok(new SellerMarketListingsResponse(
        SellerId: normalizedSellerId,
        Listings: await market.GetSellerListingsAsync(normalizedSellerId),
        UpdatedAt: DateTimeOffset.UtcNow));
}).WithName("GetPlayerMarketListings");

app.MapGet("/market/listings/{listingId}", async (string listingId, MarketStore market) =>
{
    var listing = await market.GetListingAsync(listingId);
    return listing is null
        ? Results.NotFound(new ErrorResponse("Market listing was not found."))
        : Results.Ok(listing);
}).WithName("GetMarketListing");

app.MapPost("/market/listings", async (
    CreateListingRequest request,
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

    var validation = ValidateCreateListing(request);
    return validation is not null
        ? Results.BadRequest(new ErrorResponse(validation))
        : Results.Ok(await market.CreatePendingListingAsync(request));
}).WithName("CreateMarketListing");

app.MapPost("/market/listings/{listingId}/activate", async (
    string listingId,
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

    var listing = await market.ActivateListingAsync(listingId);
    return listing is null
        ? Results.NotFound(new ErrorResponse("Pending market listing was not found."))
        : Results.Ok(listing);
}).WithName("ActivateMarketListing");

app.MapPost("/market/listings/{listingId}/cancel", async (
    string listingId,
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

    var listing = await market.CancelListingAsync(listingId);
    return listing is null
        ? Results.NotFound(new ErrorResponse("Market listing was not cancellable."))
        : Results.Ok(listing);
}).WithName("CancelMarketListing");

app.MapPost("/market/listings/{listingId}/purchase", async (
    string listingId,
    PurchaseListingRequest request,
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

    if (request.Quantity <= 0 || string.IsNullOrWhiteSpace(request.ReservationId))
    {
        return Results.BadRequest(new ErrorResponse("Quantity and reservation id are required."));
    }

    return Results.Ok(await market.PurchaseListingAsync(listingId, request));
}).WithName("PurchaseMarketListing");

app.MapPost("/market/listings/{listingId}/release", async (
    string listingId,
    ReleaseListingRequest request,
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

    return Results.Ok(await market.ReleaseReservationAsync(listingId, request.ReservationId));
}).WithName("ReleaseMarketListingReservation");

app.MapPost("/market/listings/{listingId}/settle", async (
    string listingId,
    ReleaseListingRequest request,
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

    return Results.Ok(await market.SettleReservationAsync(listingId, request.ReservationId));
}).WithName("SettleMarketListingReservation");

app.Run();

static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
{
    var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
    return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
        string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
}

static string? ValidateCreateListing(CreateListingRequest request)
{
    if (string.IsNullOrWhiteSpace(request.SellerId) ||
        string.IsNullOrWhiteSpace(request.ItemId) ||
        string.IsNullOrWhiteSpace(request.ItemName) ||
        string.IsNullOrWhiteSpace(request.Category))
    {
        return "Seller and item details are required.";
    }

    if (request.Quantity <= 0 || request.Quantity > 10_000)
    {
        return "Quantity must be between 1 and 10000.";
    }

    if (request.PricePerUnit <= 0 || request.PricePerUnit > 1_000_000)
    {
        return "Price per unit must be between 1 and 1000000.";
    }

    return null;
}

internal sealed partial class MarketStore : IDisposable
{
    private readonly NpgsqlDataSource _dataSource;

    public MarketStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_MARKET_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Market")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS market;

            CREATE TABLE IF NOT EXISTS market.listings (
                listing_id text PRIMARY KEY,
                item_id text NOT NULL,
                item_name text NOT NULL,
                category text NOT NULL,
                quantity integer NOT NULL,
                price_per_unit integer NOT NULL,
                seller_id text NOT NULL,
                status text NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                activated_at timestamptz NULL
            );

            CREATE TABLE IF NOT EXISTS market.fills (
                fill_id text PRIMARY KEY,
                listing_id text NOT NULL REFERENCES market.listings(listing_id),
                buyer_id text NOT NULL,
                quantity integer NOT NULL,
                status text NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
        await SeedSystemListingsAsync();
    }

    public async Task<MarketListingDto[]> GetOpenListingsAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT listing_id, item_id, item_name, category, quantity, price_per_unit,
                   seller_id, status, created_at, updated_at
            FROM market.listings
            WHERE status = @status AND quantity > 0
            ORDER BY seller_id = 'system-market' DESC, created_at DESC;
            """, connection);
        command.Parameters.AddWithValue("status", MarketStatuses.Open);

        var listings = new List<MarketListingDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            listings.Add(ReadListing(reader));
        }

        return listings.ToArray();
    }

    public async Task<MarketListingDto[]> GetSellerListingsAsync(string sellerId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT listing_id, item_id, item_name, category, quantity, price_per_unit,
                   seller_id, status, created_at, updated_at
            FROM market.listings
            WHERE seller_id = @seller_id
            ORDER BY created_at DESC, listing_id DESC;
            """, connection);
        command.Parameters.AddWithValue("seller_id", NormalizeId(sellerId));

        var listings = new List<MarketListingDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            listings.Add(ReadListing(reader));
        }

        return listings.ToArray();
    }

    public async Task<MarketListingDto?> GetListingAsync(string listingId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        return await ReadListingAsync(connection, null, NormalizeId(listingId));
    }

    public async Task<MarketListingDto> CreatePendingListingAsync(CreateListingRequest request)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        var listingId = string.IsNullOrWhiteSpace(request.ListingId)
            ? $"listing-{Guid.NewGuid():N}"
            : NormalizeId(request.ListingId);

        await using var command = new NpgsqlCommand("""
            INSERT INTO market.listings (
                listing_id, item_id, item_name, category, quantity,
                price_per_unit, seller_id, status, created_at, updated_at
            )
            VALUES (
                @listing_id, @item_id, @item_name, @category, @quantity,
                @price_per_unit, @seller_id, @status, @created_at, @updated_at
            )
            ON CONFLICT (listing_id) DO NOTHING;
            """, connection);
        command.Parameters.AddWithValue("listing_id", listingId);
        command.Parameters.AddWithValue("item_id", NormalizeId(request.ItemId));
        command.Parameters.AddWithValue("item_name", request.ItemName.Trim());
        command.Parameters.AddWithValue("category", request.Category.Trim());
        command.Parameters.AddWithValue("quantity", request.Quantity);
        command.Parameters.AddWithValue("price_per_unit", request.PricePerUnit);
        command.Parameters.AddWithValue("seller_id", NormalizeId(request.SellerId));
        command.Parameters.AddWithValue("status", MarketStatuses.Pending);
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();

        return await ReadListingAsync(connection, null, listingId)
            ?? throw new InvalidOperationException("Listing could not be read after creation.");
    }

    public async Task<MarketListingDto?> ActivateListingAsync(string listingId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        var normalizedListingId = NormalizeId(listingId);
        var now = DateTimeOffset.UtcNow;

        await using var command = new NpgsqlCommand("""
            UPDATE market.listings
            SET status = @open_status,
                activated_at = COALESCE(activated_at, @updated_at),
                updated_at = @updated_at
            WHERE listing_id = @listing_id AND status = @pending_status;
            """, connection);
        command.Parameters.AddWithValue("listing_id", normalizedListingId);
        command.Parameters.AddWithValue("open_status", MarketStatuses.Open);
        command.Parameters.AddWithValue("pending_status", MarketStatuses.Pending);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();

        return await ReadListingAsync(connection, null, normalizedListingId);
    }

    public async Task<MarketListingDto?> CancelListingAsync(string listingId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        var normalizedListingId = NormalizeId(listingId);
        var now = DateTimeOffset.UtcNow;

        await using var command = new NpgsqlCommand("""
            UPDATE market.listings
            SET status = @cancelled_status,
                updated_at = @updated_at
            WHERE listing_id = @listing_id AND status IN (@pending_status, @open_status)
            RETURNING listing_id, item_id, item_name, category, quantity, price_per_unit,
                      seller_id, status, created_at, updated_at;
            """, connection);
        command.Parameters.AddWithValue("listing_id", normalizedListingId);
        command.Parameters.AddWithValue("pending_status", MarketStatuses.Pending);
        command.Parameters.AddWithValue("open_status", MarketStatuses.Open);
        command.Parameters.AddWithValue("cancelled_status", MarketStatuses.Cancelled);
        command.Parameters.AddWithValue("updated_at", now);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadListing(reader) : null;
    }

    public async Task<MarketReservationResponse> PurchaseListingAsync(
        string listingId,
        PurchaseListingRequest request)
    {
        var normalizedListingId = NormalizeId(listingId);
        var reservationId = NormalizeId(request.ReservationId);
        var buyerId = NormalizeId(request.BuyerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var existingFill = await ReadFillAsync(connection, transaction, reservationId);
        if (existingFill is not null)
        {
            var existingListing = await ReadListingAsync(connection, transaction, normalizedListingId)
                ?? throw new InvalidOperationException("Reserved listing could not be read.");
            await transaction.CommitAsync();
            return new MarketReservationResponse(
                Completed: true,
                Message: "Market listing was already reserved.",
                ReservationId: reservationId,
                Listing: existingListing,
                Quantity: existingFill.Quantity,
                RemainingQuantity: existingListing.Quantity);
        }

        await using var reserve = new NpgsqlCommand("""
            UPDATE market.listings
            SET quantity = quantity - @quantity,
                status = CASE WHEN quantity - @quantity = 0 THEN @sold_out_status ELSE status END,
                updated_at = @updated_at
            WHERE listing_id = @listing_id
              AND status = @open_status
              AND quantity >= @quantity
            RETURNING listing_id, item_id, item_name, category, quantity, price_per_unit,
                      seller_id, status, created_at, updated_at;
            """, connection, transaction);
        var now = DateTimeOffset.UtcNow;
        reserve.Parameters.AddWithValue("listing_id", normalizedListingId);
        reserve.Parameters.AddWithValue("quantity", request.Quantity);
        reserve.Parameters.AddWithValue("open_status", MarketStatuses.Open);
        reserve.Parameters.AddWithValue("sold_out_status", MarketStatuses.SoldOut);
        reserve.Parameters.AddWithValue("updated_at", now);

        MarketListingDto? listing;
        await using (var reader = await reserve.ExecuteReaderAsync())
        {
            listing = await reader.ReadAsync() ? ReadListing(reader) : null;
        }

        if (listing is null)
        {
            await transaction.RollbackAsync();
            return new MarketReservationResponse(
                Completed: false,
                Message: "Market listing is no longer available.",
                ReservationId: reservationId,
                Listing: null,
                Quantity: request.Quantity,
                RemainingQuantity: 0);
        }

        await using (var fill = new NpgsqlCommand("""
            INSERT INTO market.fills (
                fill_id, listing_id, buyer_id, quantity, status, created_at, updated_at
            )
            VALUES (
                @fill_id, @listing_id, @buyer_id, @quantity, @status, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            fill.Parameters.AddWithValue("fill_id", reservationId);
            fill.Parameters.AddWithValue("listing_id", normalizedListingId);
            fill.Parameters.AddWithValue("buyer_id", buyerId);
            fill.Parameters.AddWithValue("quantity", request.Quantity);
            fill.Parameters.AddWithValue("status", MarketStatuses.ReservedFill);
            fill.Parameters.AddWithValue("created_at", now);
            fill.Parameters.AddWithValue("updated_at", now);
            await fill.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
        return new MarketReservationResponse(
            Completed: true,
            Message: "Market listing reserved.",
            ReservationId: reservationId,
            Listing: listing,
            Quantity: request.Quantity,
            RemainingQuantity: listing.Quantity);
    }

    public Task<MarketReservationStatusResponse> ReleaseReservationAsync(string listingId, string reservationId)
    {
        return UpdateReservationStatusAsync(listingId, reservationId, MarketStatuses.ReleasedFill, releaseQuantity: true);
    }

    public Task<MarketReservationStatusResponse> SettleReservationAsync(string listingId, string reservationId)
    {
        return UpdateReservationStatusAsync(listingId, reservationId, MarketStatuses.SettledFill, releaseQuantity: false);
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task<MarketReservationStatusResponse> UpdateReservationStatusAsync(
        string listingId,
        string reservationId,
        string newStatus,
        bool releaseQuantity)
    {
        var normalizedListingId = NormalizeId(listingId);
        var normalizedReservationId = NormalizeId(reservationId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var fill = await ReadFillForUpdateAsync(connection, transaction, normalizedReservationId);
        if (fill is null || !string.Equals(fill.ListingId, normalizedListingId, StringComparison.Ordinal))
        {
            await transaction.RollbackAsync();
            return new MarketReservationStatusResponse(false, "Reservation was not found.");
        }

        if (!string.Equals(fill.Status, MarketStatuses.ReservedFill, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new MarketReservationStatusResponse(true, $"Reservation is already {fill.Status}.");
        }

        if (releaseQuantity)
        {
            await using var listing = new NpgsqlCommand("""
                UPDATE market.listings
                SET quantity = quantity + @quantity,
                    status = @open_status,
                    updated_at = @updated_at
                WHERE listing_id = @listing_id;
                """, connection, transaction);
            listing.Parameters.AddWithValue("listing_id", normalizedListingId);
            listing.Parameters.AddWithValue("quantity", fill.Quantity);
            listing.Parameters.AddWithValue("open_status", MarketStatuses.Open);
            listing.Parameters.AddWithValue("updated_at", now);
            await listing.ExecuteNonQueryAsync();
        }

        await using (var updateFill = new NpgsqlCommand("""
            UPDATE market.fills
            SET status = @status,
                updated_at = @updated_at
            WHERE fill_id = @fill_id;
            """, connection, transaction))
        {
            updateFill.Parameters.AddWithValue("fill_id", normalizedReservationId);
            updateFill.Parameters.AddWithValue("status", newStatus);
            updateFill.Parameters.AddWithValue("updated_at", now);
            await updateFill.ExecuteNonQueryAsync();
        }

        if (!releaseQuantity && string.Equals(newStatus, MarketStatuses.SettledFill, StringComparison.Ordinal))
        {
            var listing = await ReadListingAsync(connection, transaction, normalizedListingId);
            if (listing is not null)
            {
                await InsertPriceHistoryAsync(
                    connection,
                    transaction,
                    itemId: listing.ItemId,
                    itemName: listing.ItemName,
                    category: listing.Category,
                    quantity: fill.Quantity,
                    pricePerUnit: listing.PricePerUnit,
                    sellerType: string.Equals(listing.SellerId, "system-market", StringComparison.Ordinal)
                        ? "system"
                        : "player",
                    sellerId: listing.SellerId,
                    buyerType: "player",
                    buyerId: fill.BuyerId,
                    sourceType: "listing",
                    sourceId: normalizedReservationId,
                    tradedAt: now);
            }
        }

        await transaction.CommitAsync();
        return new MarketReservationStatusResponse(true, $"Reservation marked {newStatus}.");
    }

    private async Task SeedSystemListingsAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        foreach (var listing in SystemMarketListings.All)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO market.listings (
                    listing_id, item_id, item_name, category, quantity,
                    price_per_unit, seller_id, status, created_at, updated_at, activated_at
                )
                VALUES (
                    @listing_id, @item_id, @item_name, @category, @quantity,
                    @price_per_unit, @seller_id, @status, @created_at, @updated_at, @activated_at
                )
                ON CONFLICT (listing_id) DO NOTHING;
                """, connection);
            command.Parameters.AddWithValue("listing_id", listing.ListingId);
            command.Parameters.AddWithValue("item_id", listing.ItemId);
            command.Parameters.AddWithValue("item_name", listing.ItemName);
            command.Parameters.AddWithValue("category", listing.Category);
            command.Parameters.AddWithValue("quantity", listing.Quantity);
            command.Parameters.AddWithValue("price_per_unit", listing.PricePerUnit);
            command.Parameters.AddWithValue("seller_id", listing.SellerId);
            command.Parameters.AddWithValue("status", MarketStatuses.Open);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            command.Parameters.AddWithValue("activated_at", now);
            await command.ExecuteNonQueryAsync();
        }
    }

    private static async Task<MarketListingDto?> ReadListingAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string listingId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT listing_id, item_id, item_name, category, quantity, price_per_unit,
                   seller_id, status, created_at, updated_at
            FROM market.listings
            WHERE listing_id = @listing_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("listing_id", listingId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadListing(reader) : null;
    }

    private static async Task<MarketFill?> ReadFillAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string fillId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT fill_id, listing_id, buyer_id, quantity, status
            FROM market.fills
            WHERE fill_id = @fill_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("fill_id", fillId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadFill(reader) : null;
    }

    private static async Task<MarketFill?> ReadFillForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string fillId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT fill_id, listing_id, buyer_id, quantity, status
            FROM market.fills
            WHERE fill_id = @fill_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("fill_id", fillId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadFill(reader) : null;
    }

    private static MarketListingDto ReadListing(NpgsqlDataReader reader)
    {
        return new MarketListingDto(
            ListingId: reader.GetString(0),
            ItemId: reader.GetString(1),
            ItemName: reader.GetString(2),
            Category: reader.GetString(3),
            Quantity: reader.GetInt32(4),
            PricePerUnit: reader.GetInt32(5),
            SellerId: reader.GetString(6),
            Status: reader.GetString(7),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(8),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static MarketFill ReadFill(NpgsqlDataReader reader)
    {
        return new MarketFill(
            FillId: reader.GetString(0),
            ListingId: reader.GetString(1),
            BuyerId: reader.GetString(2),
            Quantity: reader.GetInt32(3),
            Status: reader.GetString(4));
    }

    internal static string NormalizeId(string value)
    {
        return value.Trim().ToLowerInvariant();
    }
}

internal static class SystemMarketListings
{
    public static MarketListingSeed[] All { get; } =
    [
        new("listing-food-1", "food", "Food", "Consumable", 12, 2, "system-market"),
        new("listing-weapon-q1-1", "weapon_q1", "Q1 Weapon", "Weapon", 4, 18, "system-market"),
        new("listing-grain-1", "grain", "Grain", "Raw material", 50, 1, "system-market")
    ];
}

internal static class MarketStatuses
{
    public const string Open = "open";
    public const string Pending = "pending";
    public const string Cancelled = "cancelled";
    public const string SoldOut = "sold_out";
    public const string ReservedFill = "reserved";
    public const string ReleasedFill = "released";
    public const string SettledFill = "settled";
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record MarketListingsResponse(MarketListingDto[] Listings, DateTimeOffset UpdatedAt);

internal sealed record SellerMarketListingsResponse(
    string SellerId,
    MarketListingDto[] Listings,
    DateTimeOffset UpdatedAt);

internal sealed record MarketListingDto(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string SellerId,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record CreateListingRequest(
    string? ListingId,
    string SellerId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit);

internal sealed record PurchaseListingRequest(
    string BuyerId,
    int Quantity,
    string ReservationId);

internal sealed record ReleaseListingRequest(string ReservationId);

internal sealed record MarketReservationResponse(
    bool Completed,
    string Message,
    string ReservationId,
    MarketListingDto? Listing,
    int Quantity,
    int RemainingQuantity);

internal sealed record MarketReservationStatusResponse(bool Completed, string Message);

internal sealed record MarketFill(string FillId, string ListingId, string BuyerId, int Quantity, string Status);

internal sealed record MarketListingSeed(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string SellerId);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

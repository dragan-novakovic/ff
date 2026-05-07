using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<EconomyStore>();

var metadata = new ServiceMetadata(
    Service: "economy-service",
    DisplayName: "Economy Service",
    Domain: "Wallet ledger, inventory balances, and reservations",
    Description: "Keeps wallet and inventory together for MVP so money and item reservations can remain atomic.",
    Owns: ["currency balances", "transaction ledger", "inventory balances", "reserved funds", "reserved items"],
    Responsibilities: ["Protect against negative balances", "Reserve and commit money/items", "Maintain append-only economic audit trails"]);

var app = builder.Build();

var economyStore = app.Services.GetRequiredService<EconomyStore>();
await economyStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/players/{playerId}/inventory", async (string playerId, EconomyStore economy) =>
    Results.Ok(await economy.GetInventoryAsync(playerId))).WithName("GetInventory");

app.MapPost("/players/{playerId}/inventory/convert", async (
    string playerId,
    InventoryConversionRequest request,
    EconomyStore economy) =>
{
    var validation = ValidatePositiveQuantities(request.InputQuantity, request.OutputQuantity);
    return validation is not null
        ? Results.BadRequest(new ErrorResponse(validation))
        : Results.Ok(await economy.ConvertInventoryAsync(playerId, request));
}).WithName("ConvertInventory");

app.MapPost("/players/{playerId}/market/buy", async (
    string playerId,
    MarketPurchaseRequest request,
    EconomyStore economy) =>
{
    if (request.Quantity <= 0 || request.PricePerUnit <= 0)
    {
        return Results.BadRequest(new ErrorResponse("Quantity and price must be positive."));
    }

    return Results.Ok(await economy.BuyListingAsync(playerId, request));
}).WithName("BuyMarketListing");

app.MapPost("/players/{playerId}/wallet/credit", async (
    string playerId,
    WalletCreditRequest request,
    HttpRequest httpRequest,
    EconomyStore economy,
    IConfiguration configuration) =>
{
    if (!HasValidInternalToken(httpRequest, configuration))
    {
        return Results.Json(
            new ErrorResponse("Internal service authorization is required."),
            statusCode: StatusCodes.Status401Unauthorized);
    }

    if (request.Amount <= 0 ||
        string.IsNullOrWhiteSpace(request.EntryType) ||
        string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Amount, entry type, and idempotency key are required."));
    }

    return Results.Ok(await economy.CreditWalletAsync(playerId, request));
}).WithName("CreditWallet");

app.Run();

static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
{
    var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
    return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
        string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
}

static string? ValidatePositiveQuantities(int inputQuantity, int outputQuantity)
{
    if (inputQuantity <= 0)
    {
        return "Input quantity must be positive.";
    }

    if (outputQuantity <= 0)
    {
        return "Output quantity must be positive.";
    }

    return null;
}

internal sealed class EconomyStore : IDisposable
{
    private readonly NpgsqlDataSource _dataSource;

    public EconomyStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_ECONOMY_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Economy")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS economy;

            CREATE TABLE IF NOT EXISTS economy.wallets (
                player_id text PRIMARY KEY,
                gold integer NOT NULL,
                storage_limit integer NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS economy.inventory_items (
                player_id text NOT NULL,
                item_id text NOT NULL,
                name text NOT NULL,
                category text NOT NULL,
                quantity integer NOT NULL,
                description text NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, item_id)
            );

            CREATE TABLE IF NOT EXISTS economy.ledger_entries (
                ledger_id text PRIMARY KEY,
                player_id text NOT NULL,
                entry_type text NOT NULL,
                gold_delta integer NOT NULL,
                item_id text NOT NULL,
                item_delta integer NOT NULL,
                description text NOT NULL,
                created_at timestamptz NOT NULL
            );
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<InventoryResponse> GetInventoryAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsurePlayerAsync(normalizedPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();

        var wallet = await ReadWalletAsync(connection, null, normalizedPlayerId);
        var items = await ReadItemsAsync(connection, null, normalizedPlayerId);
        return ToInventoryResponse(normalizedPlayerId, wallet, items);
    }

    public async Task<InventoryMutationResponse> ConvertInventoryAsync(
        string playerId,
        InventoryConversionRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var input = ItemCatalog.Resolve(request.InputItemId);
        var output = ItemCatalog.Resolve(request.OutputItemId);
        var inputQuantity = await ReadItemQuantityForUpdateAsync(connection, transaction, normalizedPlayerId, input.ItemId);
        if (inputQuantity < request.InputQuantity)
        {
            await transaction.RollbackAsync();
            return new InventoryMutationResponse(
                Completed: false,
                Message: $"Not enough {input.Name}. Required {request.InputQuantity}, available {inputQuantity}.",
                Changes: [],
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        await AddItemQuantityAsync(connection, transaction, normalizedPlayerId, input, -request.InputQuantity, now);
        var outputQuantity = await AddItemQuantityAsync(
            connection,
            transaction,
            normalizedPlayerId,
            output,
            request.OutputQuantity,
            now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            "production",
            goldDelta: 0,
            itemId: input.ItemId,
            itemDelta: -request.InputQuantity,
            description: request.Reason,
            now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            "production",
            goldDelta: 0,
            itemId: output.ItemId,
            itemDelta: request.OutputQuantity,
            description: request.Reason,
            now);
        await transaction.CommitAsync();

        return new InventoryMutationResponse(
            Completed: true,
            Message: $"Converted {request.InputQuantity} {input.Name} into {request.OutputQuantity} {output.Name}.",
            Changes:
            [
                new ItemChangeDto(input.ItemId, input.Name, -request.InputQuantity, inputQuantity - request.InputQuantity),
                new ItemChangeDto(output.ItemId, output.Name, request.OutputQuantity, outputQuantity)
            ],
            Inventory: await GetInventoryAsync(normalizedPlayerId));
    }

    public async Task<MarketPurchaseResponse> BuyListingAsync(string playerId, MarketPurchaseRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var item = ItemCatalog.Resolve(request.ItemId, request.ItemName, request.Category);
        var totalPrice = checked(request.Quantity * request.PricePerUnit);
        var wallet = await ReadWalletAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (wallet.Gold < totalPrice)
        {
            await transaction.RollbackAsync();
            return new MarketPurchaseResponse(
                Completed: false,
                Message: $"Not enough gold. Required {totalPrice}, available {wallet.Gold}.",
                ListingId: request.ListingId,
                Quantity: request.Quantity,
                TotalPrice: totalPrice,
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        await UpdateGoldAsync(connection, transaction, normalizedPlayerId, -totalPrice, now);
        var itemQuantity = await AddItemQuantityAsync(
            connection,
            transaction,
            normalizedPlayerId,
            item,
            request.Quantity,
            now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            "market_purchase",
            goldDelta: -totalPrice,
            itemId: item.ItemId,
            itemDelta: request.Quantity,
            description: $"Bought {request.Quantity} {item.Name} from listing {request.ListingId}.",
            now);
        await transaction.CommitAsync();

        return new MarketPurchaseResponse(
            Completed: true,
            Message: $"Bought {request.Quantity} {item.Name} for {totalPrice} gold.",
            ListingId: request.ListingId,
            Quantity: request.Quantity,
            TotalPrice: totalPrice,
                Inventory: await GetInventoryAsync(normalizedPlayerId));
    }

    public async Task<WalletCreditResponse> CreditWalletAsync(string playerId, WalletCreditRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var idempotencyKey = request.IdempotencyKey.Trim();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var existingCreditPlayerId = await ReadLedgerPlayerIdAsync(connection, transaction, idempotencyKey);
        if (existingCreditPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingCreditPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new WalletCreditResponse(
                Completed: completed,
                Message: completed
                    ? "Wallet credit was already applied."
                    : "Idempotency key was already used by another wallet.",
                Amount: completed ? request.Amount : 0,
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        await ReadWalletAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        var walletGold = await UpdateGoldAsync(connection, transaction, normalizedPlayerId, request.Amount, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            request.EntryType.Trim().ToLowerInvariant(),
            goldDelta: request.Amount,
            itemId: string.Empty,
            itemDelta: 0,
            description: request.Reason,
            createdAt: now,
            ledgerId: idempotencyKey);
        await transaction.CommitAsync();

        return new WalletCreditResponse(
            Completed: true,
            Message: $"Credited {request.Amount} gold. Wallet balance is {walletGold}.",
            Amount: request.Amount,
            Inventory: await GetInventoryAsync(normalizedPlayerId));
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task EnsurePlayerAsync(string playerId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await using (var wallet = new NpgsqlCommand("""
            INSERT INTO economy.wallets (player_id, gold, storage_limit, created_at, updated_at)
            VALUES (@player_id, 100, 100, @created_at, @updated_at)
            ON CONFLICT (player_id) DO NOTHING;
            """, connection, transaction))
        {
            wallet.Parameters.AddWithValue("player_id", playerId);
            wallet.Parameters.AddWithValue("created_at", now);
            wallet.Parameters.AddWithValue("updated_at", now);
            await wallet.ExecuteNonQueryAsync();
        }

        foreach (var seed in ItemCatalog.SeedItems)
        {
            await using var item = new NpgsqlCommand("""
                INSERT INTO economy.inventory_items (
                    player_id, item_id, name, category, quantity, description, updated_at
                )
                VALUES (
                    @player_id, @item_id, @name, @category, @quantity, @description, @updated_at
                )
                ON CONFLICT (player_id, item_id) DO NOTHING;
                """, connection, transaction);
            item.Parameters.AddWithValue("player_id", playerId);
            item.Parameters.AddWithValue("item_id", seed.Item.ItemId);
            item.Parameters.AddWithValue("name", seed.Item.Name);
            item.Parameters.AddWithValue("category", seed.Item.Category);
            item.Parameters.AddWithValue("quantity", seed.Quantity);
            item.Parameters.AddWithValue("description", seed.Item.Description);
            item.Parameters.AddWithValue("updated_at", now);
            await item.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
    }

    private static async Task<WalletRecord> ReadWalletAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        bool forUpdate = false)
    {
        var sql = """
            SELECT gold, storage_limit
            FROM economy.wallets
            WHERE player_id = @player_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException("Wallet was not initialized.");
        }

        return new WalletRecord(reader.GetInt32(0), reader.GetInt32(1));
    }

    private static async Task<List<InventoryItemDto>> ReadItemsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT item_id, name, category, quantity, description
            FROM economy.inventory_items
            WHERE player_id = @player_id AND quantity > 0
            ORDER BY category, name;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        var items = new List<InventoryItemDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            items.Add(new InventoryItemDto(
                ItemId: reader.GetString(0),
                Name: reader.GetString(1),
                Category: reader.GetString(2),
                Quantity: reader.GetInt32(3),
                Description: reader.GetString(4)));
        }

        return items;
    }

    private static async Task<int> ReadItemQuantityForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string itemId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT quantity
            FROM economy.inventory_items
            WHERE player_id = @player_id AND item_id = @item_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("item_id", itemId);

        var result = await command.ExecuteScalarAsync();
        return result is int quantity ? quantity : 0;
    }

    private static async Task<int> AddItemQuantityAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        CatalogItem item,
        int quantityDelta,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO economy.inventory_items (
                player_id, item_id, name, category, quantity, description, updated_at
            )
            VALUES (
                @player_id, @item_id, @name, @category, @quantity_delta, @description, @updated_at
            )
            ON CONFLICT (player_id, item_id)
            DO UPDATE SET
                quantity = economy.inventory_items.quantity + @quantity_delta,
                name = @name,
                category = @category,
                description = @description,
                updated_at = @updated_at
            RETURNING quantity;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("item_id", item.ItemId);
        command.Parameters.AddWithValue("name", item.Name);
        command.Parameters.AddWithValue("category", item.Category);
        command.Parameters.AddWithValue("quantity_delta", quantityDelta);
        command.Parameters.AddWithValue("description", item.Description);
        command.Parameters.AddWithValue("updated_at", updatedAt);

        return (int)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Inventory update did not return a quantity."));
    }

    private static async Task<int> UpdateGoldAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        int goldDelta,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE economy.wallets
            SET gold = gold + @gold_delta,
                updated_at = @updated_at
            WHERE player_id = @player_id
            RETURNING gold;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("gold_delta", goldDelta);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        return (int)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Wallet update did not return a balance."));
    }

    private static async Task<string?> ReadLedgerPlayerIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string ledgerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id
            FROM economy.ledger_entries
            WHERE ledger_id = @ledger_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("ledger_id", ledgerId);
        var result = await command.ExecuteScalarAsync();
        return result as string;
    }

    private static async Task AddLedgerAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string entryType,
        int goldDelta,
        string itemId,
        int itemDelta,
        string description,
        DateTimeOffset createdAt,
        string? ledgerId = null)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO economy.ledger_entries (
                ledger_id, player_id, entry_type, gold_delta, item_id, item_delta, description, created_at
            )
            VALUES (
                @ledger_id, @player_id, @entry_type, @gold_delta, @item_id, @item_delta, @description, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("ledger_id", ledgerId ?? $"ledger-{Guid.NewGuid():N}");
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("entry_type", entryType);
        command.Parameters.AddWithValue("gold_delta", goldDelta);
        command.Parameters.AddWithValue("item_id", itemId);
        command.Parameters.AddWithValue("item_delta", itemDelta);
        command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync();
    }

    private static InventoryResponse ToInventoryResponse(
        string playerId,
        WalletRecord wallet,
        IReadOnlyCollection<InventoryItemDto> items)
    {
        return new InventoryResponse(
            PlayerId: playerId,
            WalletGold: wallet.Gold,
            StorageUsed: items.Sum(item => item.Quantity),
            StorageLimit: wallet.StorageLimit,
            Items: items.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    private static string NormalizePlayerId(string playerId)
    {
        return playerId.Trim().ToLowerInvariant();
    }
}

internal static class ItemCatalog
{
    public static SeedItem[] SeedItems { get; } =
    [
        new(Resolve("food"), 20),
        new(Resolve("weapon_q1"), 3),
        new(Resolve("grain"), 20),
        new(Resolve("iron"), 12)
    ];

    public static CatalogItem Resolve(string itemId, string? name = null, string? category = null)
    {
        var normalized = itemId.Trim().ToLowerInvariant();
        return normalized switch
        {
            "food" => new CatalogItem("food", "Food", "Consumable", "Restores energy in a future economy slice."),
            "weapon_q1" => new CatalogItem("weapon_q1", "Q1 Weapon", "Weapon", "Basic combat weapon used by early missions."),
            "grain" => new CatalogItem("grain", "Grain", "Raw material", "Input for food production."),
            "iron" => new CatalogItem("iron", "Iron", "Raw material", "Input for weapon production."),
            _ => new CatalogItem(
                normalized,
                string.IsNullOrWhiteSpace(name) ? normalized : name.Trim(),
                string.IsNullOrWhiteSpace(category) ? "Item" : category.Trim(),
                "Player-owned item.")
        };
    }
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record InventoryResponse(
    string PlayerId,
    int WalletGold,
    int StorageUsed,
    int StorageLimit,
    InventoryItemDto[] Items,
    DateTimeOffset UpdatedAt);

internal sealed record InventoryItemDto(
    string ItemId,
    string Name,
    string Category,
    int Quantity,
    string Description);

internal sealed record InventoryConversionRequest(
    string InputItemId,
    int InputQuantity,
    string OutputItemId,
    int OutputQuantity,
    string Reason);

internal sealed record InventoryMutationResponse(
    bool Completed,
    string Message,
    ItemChangeDto[] Changes,
    InventoryResponse Inventory);

internal sealed record ItemChangeDto(
    string ItemId,
    string Name,
    int QuantityDelta,
    int FinalQuantity);

internal sealed record MarketPurchaseRequest(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit);

internal sealed record MarketPurchaseResponse(
    bool Completed,
    string Message,
    string ListingId,
    int Quantity,
    int TotalPrice,
    InventoryResponse Inventory);

internal sealed record WalletCreditRequest(
    int Amount,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record WalletCreditResponse(
    bool Completed,
    string Message,
    int Amount,
    InventoryResponse Inventory);

internal sealed record CatalogItem(string ItemId, string Name, string Category, string Description);

internal sealed record SeedItem(CatalogItem Item, int Quantity);

internal sealed record WalletRecord(int Gold, int StorageLimit);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

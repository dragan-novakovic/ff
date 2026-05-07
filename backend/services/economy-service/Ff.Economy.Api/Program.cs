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

app.MapGet("/players/{playerId}/ledger", async (string playerId, int? limit, EconomyStore economy) =>
    Results.Ok(await economy.GetLedgerAsync(playerId, ClampLedgerLimit(limit)))).WithName("GetLedger");

app.MapGet("/players/{playerId}/equipment", async (string playerId, EconomyStore economy) =>
    Results.Ok(await economy.GetEquipmentAsync(playerId))).WithName("GetEquipment");

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
    if (request.Quantity <= 0 ||
        request.PricePerUnit <= 0 ||
        request.BuyerTaxAmount < 0 ||
        request.SellerTaxAmount < 0 ||
        string.IsNullOrWhiteSpace(request.SellerId) ||
        string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Quantity, price, non-negative taxes, seller, and idempotency key are required."));
    }

    return Results.Ok(await economy.BuyListingAsync(playerId, request));
}).WithName("BuyMarketListing");

app.MapPost("/players/{playerId}/inventory/remove", async (
    string playerId,
    InventoryRemovalRequest request,
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

    if (request.Quantity <= 0 || string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Quantity and idempotency key are required."));
    }

    return Results.Ok(await economy.RemoveInventoryAsync(playerId, request));
}).WithName("RemoveInventory");

app.MapPost("/players/{playerId}/inventory/grant", async (
    string playerId,
    InventoryGrantRequest request,
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

    if (request.Quantity <= 0 || string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Quantity and idempotency key are required."));
    }

    return Results.Ok(await economy.GrantInventoryAsync(playerId, request));
}).WithName("GrantInventory");

app.MapPost("/players/{playerId}/inventory/spend", async (
    string playerId,
    InventorySpendRequest request,
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

    if (request.Quantity <= 0 ||
        request.GoldCost < 0 ||
        string.IsNullOrWhiteSpace(request.EntryType) ||
        string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Quantity, gold cost, entry type, and idempotency key are required."));
    }

    return Results.Ok(await economy.SpendInventoryAndGoldAsync(playerId, request));
}).WithName("SpendInventoryAndGold");

app.MapPost("/players/{playerId}/equipment/weapon/equip", async (
    string playerId,
    EquipWeaponRequest request,
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

    if (string.IsNullOrWhiteSpace(request.ItemId) ||
        string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Item and idempotency key are required."));
    }

    return Results.Ok(await economy.EquipWeaponAsync(playerId, request));
}).WithName("EquipWeapon");

app.MapPost("/players/{playerId}/equipment/weapon/damage", async (
    string playerId,
    DamageWeaponRequest request,
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

    if (request.DurabilityDamage <= 0 || string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Durability damage and idempotency key are required."));
    }

    return Results.Ok(await economy.DamageEquippedWeaponAsync(playerId, request));
}).WithName("DamageEquippedWeapon");

app.MapPost("/players/{playerId}/equipment/weapon/repair", async (
    string playerId,
    RepairWeaponRequest request,
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

    if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
    {
        return Results.BadRequest(new ErrorResponse("Idempotency key is required."));
    }

    return Results.Ok(await economy.RepairEquippedWeaponAsync(playerId, request));
}).WithName("RepairEquippedWeapon");

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

app.MapPost("/players/{playerId}/wallet/debit", async (
    string playerId,
    WalletDebitRequest request,
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

    return Results.Ok(await economy.DebitWalletAsync(playerId, request));
}).WithName("DebitWallet");

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

static int ClampLedgerLimit(int? limit)
{
    return Math.Clamp(limit ?? 50, 1, 100);
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

            CREATE INDEX IF NOT EXISTS ledger_entries_player_created_at_idx
            ON economy.ledger_entries (player_id, created_at DESC);

            CREATE TABLE IF NOT EXISTS economy.equipment (
                player_id text NOT NULL,
                slot text NOT NULL,
                item_id text NOT NULL,
                name text NOT NULL,
                category text NOT NULL,
                weapon_power integer NOT NULL,
                durability integer NOT NULL,
                max_durability integer NOT NULL,
                equipped_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, slot)
            );

            CREATE TABLE IF NOT EXISTS economy.equipment_actions (
                action_id text PRIMARY KEY,
                player_id text NOT NULL,
                action_type text NOT NULL,
                message text NOT NULL,
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

    public async Task<LedgerResponse> GetLedgerAsync(string playerId, int limit)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsurePlayerAsync(normalizedPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();

        var entries = await ReadLedgerEntriesAsync(connection, null, normalizedPlayerId, limit);
        return new LedgerResponse(
            PlayerId: normalizedPlayerId,
            Entries: entries.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<EquipmentResponse> GetEquipmentAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsurePlayerAsync(normalizedPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();

        var weapon = await ReadEquippedWeaponAsync(connection, null, normalizedPlayerId);
        return ToEquipmentResponse(normalizedPlayerId, weapon);
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
        var normalizedSellerId = NormalizePlayerId(request.SellerId);
        if (!string.Equals(normalizedSellerId, "system-market", StringComparison.Ordinal))
        {
            await EnsurePlayerAsync(normalizedSellerId);
        }
        var idempotencyKey = request.IdempotencyKey.Trim().ToLowerInvariant();
        var buyerLedgerId = $"{idempotencyKey}:buyer";

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var item = ItemCatalog.Resolve(request.ItemId, request.ItemName, request.Category);
        var totalPrice = checked(request.Quantity * request.PricePerUnit);
        var buyerTaxAmount = Math.Max(0, request.BuyerTaxAmount);
        var sellerTaxAmount = Math.Clamp(request.SellerTaxAmount, 0, totalPrice);
        var buyerTotalCost = checked(totalPrice + buyerTaxAmount);
        var sellerNet = totalPrice - sellerTaxAmount;

        var existingPurchasePlayerId = await ReadLedgerPlayerIdAsync(connection, transaction, buyerLedgerId);
        if (existingPurchasePlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingPurchasePlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new MarketPurchaseResponse(
                Completed: completed,
                Message: completed
                    ? "Market purchase was already applied."
                    : "Idempotency key was already used by another wallet.",
                ListingId: request.ListingId,
                Quantity: completed ? request.Quantity : 0,
                TotalPrice: completed ? totalPrice : 0,
                SellerId: normalizedSellerId,
                Inventory: await GetInventoryAsync(normalizedPlayerId),
                BuyerTaxAmount: completed ? buyerTaxAmount : 0,
                SellerTaxAmount: completed ? sellerTaxAmount : 0,
                BuyerTotal: completed ? buyerTotalCost : 0,
                SellerNet: completed ? sellerNet : 0);
        }

        var wallet = await ReadWalletAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (wallet.Gold < buyerTotalCost)
        {
            await transaction.RollbackAsync();
            return new MarketPurchaseResponse(
                Completed: false,
                Message: $"Not enough gold. Required {buyerTotalCost}, available {wallet.Gold}.",
                ListingId: request.ListingId,
                Quantity: request.Quantity,
                TotalPrice: totalPrice,
                SellerId: normalizedSellerId,
                Inventory: await GetInventoryAsync(normalizedPlayerId),
                BuyerTaxAmount: buyerTaxAmount,
                SellerTaxAmount: sellerTaxAmount,
                BuyerTotal: buyerTotalCost,
                SellerNet: sellerNet);
        }

        await UpdateGoldAsync(connection, transaction, normalizedPlayerId, -buyerTotalCost, now);
        await AddItemQuantityAsync(
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
             createdAt: now,
             ledgerId: buyerLedgerId);
        if (buyerTaxAmount > 0)
        {
            await AddLedgerAsync(
                connection,
                transaction,
                normalizedPlayerId,
                "market_tax",
                goldDelta: -buyerTaxAmount,
                itemId: string.Empty,
                itemDelta: 0,
                description: $"Paid {buyerTaxAmount} gold market purchase tax for listing {request.ListingId}.",
                createdAt: now,
                ledgerId: $"{idempotencyKey}:buyer-tax");
        }

        if (!string.Equals(normalizedSellerId, "system-market", StringComparison.Ordinal))
        {
            await UpdateGoldAsync(connection, transaction, normalizedSellerId, sellerNet, now);
            await AddLedgerAsync(
                connection,
                transaction,
                normalizedSellerId,
                "market_sale",
                goldDelta: totalPrice,
                itemId: item.ItemId,
                itemDelta: -request.Quantity,
                description: $"Sold {request.Quantity} {item.Name} through listing {request.ListingId}.",
                createdAt: now,
                ledgerId: $"{idempotencyKey}:seller");
            if (sellerTaxAmount > 0)
            {
                await AddLedgerAsync(
                    connection,
                    transaction,
                    normalizedSellerId,
                    "market_tax",
                    goldDelta: -sellerTaxAmount,
                    itemId: string.Empty,
                    itemDelta: 0,
                    description: $"Paid {sellerTaxAmount} gold market sale tax for listing {request.ListingId}.",
                    createdAt: now,
                    ledgerId: $"{idempotencyKey}:seller-tax");
            }
        }

        await transaction.CommitAsync();

        return new MarketPurchaseResponse(
            Completed: true,
            Message: buyerTaxAmount > 0 || sellerTaxAmount > 0
                ? $"Bought {request.Quantity} {item.Name} for {totalPrice} gold. Taxes: buyer {buyerTaxAmount}, seller {sellerTaxAmount}."
                : $"Bought {request.Quantity} {item.Name} for {totalPrice} gold.",
            ListingId: request.ListingId,
            Quantity: request.Quantity,
            TotalPrice: totalPrice,
            SellerId: normalizedSellerId,
            Inventory: await GetInventoryAsync(normalizedPlayerId),
            BuyerTaxAmount: buyerTaxAmount,
            SellerTaxAmount: sellerTaxAmount,
            BuyerTotal: buyerTotalCost,
            SellerNet: sellerNet);
    }

    public async Task<InventoryMutationResponse> RemoveInventoryAsync(
        string playerId,
        InventoryRemovalRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var idempotencyKey = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var item = ItemCatalog.Resolve(request.ItemId, request.ItemName, request.Category);

        var existingRemovalPlayerId = await ReadLedgerPlayerIdAsync(connection, transaction, idempotencyKey);
        if (existingRemovalPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingRemovalPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new InventoryMutationResponse(
                Completed: completed,
                Message: completed
                    ? "Inventory removal was already applied."
                    : "Idempotency key was already used by another inventory.",
                Changes: [],
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var itemQuantity = await ReadItemQuantityForUpdateAsync(connection, transaction, normalizedPlayerId, item.ItemId);
        if (itemQuantity < request.Quantity)
        {
            await transaction.RollbackAsync();
            return new InventoryMutationResponse(
                Completed: false,
                Message: $"Not enough {item.Name}. Required {request.Quantity}, available {itemQuantity}.",
                Changes: [],
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        await AddItemQuantityAsync(connection, transaction, normalizedPlayerId, item, -request.Quantity, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            "market_listing",
            goldDelta: 0,
            itemId: item.ItemId,
            itemDelta: -request.Quantity,
            description: request.Reason,
            createdAt: now,
            ledgerId: idempotencyKey);
        await transaction.CommitAsync();

        return new InventoryMutationResponse(
            Completed: true,
            Message: $"Removed {request.Quantity} {item.Name} for market listing.",
            Changes:
            [
                new ItemChangeDto(item.ItemId, item.Name, -request.Quantity, itemQuantity - request.Quantity)
            ],
            Inventory: await GetInventoryAsync(normalizedPlayerId));
    }

    public async Task<InventoryMutationResponse> SpendInventoryAndGoldAsync(
        string playerId,
        InventorySpendRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var idempotencyKey = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var item = ItemCatalog.Resolve(request.ItemId, request.ItemName, request.Category);

        var existingSpendPlayerId = await ReadLedgerPlayerIdAsync(connection, transaction, idempotencyKey);
        if (existingSpendPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingSpendPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new InventoryMutationResponse(
                Completed: completed,
                Message: completed
                    ? "Inventory and gold spend was already applied."
                    : "Idempotency key was already used by another inventory.",
                Changes: [],
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var wallet = await ReadWalletAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (wallet.Gold < request.GoldCost)
        {
            await transaction.RollbackAsync();
            return new InventoryMutationResponse(
                Completed: false,
                Message: $"Not enough gold. Required {request.GoldCost}, available {wallet.Gold}.",
                Changes: [],
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var itemQuantity = await ReadItemQuantityForUpdateAsync(connection, transaction, normalizedPlayerId, item.ItemId);
        if (itemQuantity < request.Quantity)
        {
            await transaction.RollbackAsync();
            return new InventoryMutationResponse(
                Completed: false,
                Message: $"Not enough {item.Name}. Required {request.Quantity}, available {itemQuantity}.",
                Changes: [],
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        if (request.GoldCost > 0)
        {
            await UpdateGoldAsync(connection, transaction, normalizedPlayerId, -request.GoldCost, now);
        }

        await AddItemQuantityAsync(connection, transaction, normalizedPlayerId, item, -request.Quantity, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            request.EntryType.Trim().ToLowerInvariant(),
            goldDelta: -request.GoldCost,
            itemId: item.ItemId,
            itemDelta: -request.Quantity,
            description: request.Reason,
            createdAt: now,
            ledgerId: idempotencyKey);
        await transaction.CommitAsync();

        return new InventoryMutationResponse(
            Completed: true,
            Message: $"Spent {request.GoldCost} gold and {request.Quantity} {item.Name}.",
            Changes:
            [
                new ItemChangeDto(item.ItemId, item.Name, -request.Quantity, itemQuantity - request.Quantity)
            ],
            Inventory: await GetInventoryAsync(normalizedPlayerId));
    }

    public async Task<InventoryMutationResponse> GrantInventoryAsync(
        string playerId,
        InventoryGrantRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var idempotencyKey = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var item = ItemCatalog.Resolve(request.ItemId, request.ItemName, request.Category);

        var existingGrantPlayerId = await ReadLedgerPlayerIdAsync(connection, transaction, idempotencyKey);
        if (existingGrantPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingGrantPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new InventoryMutationResponse(
                Completed: completed,
                Message: completed
                    ? "Inventory grant was already applied."
                    : "Idempotency key was already used by another inventory.",
                Changes: [],
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var finalQuantity = await AddItemQuantityAsync(connection, transaction, normalizedPlayerId, item, request.Quantity, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            request.EntryType.Trim().ToLowerInvariant(),
            goldDelta: 0,
            itemId: item.ItemId,
            itemDelta: request.Quantity,
            description: request.Reason,
            createdAt: now,
            ledgerId: idempotencyKey);
        await transaction.CommitAsync();

        return new InventoryMutationResponse(
            Completed: true,
            Message: $"Granted {request.Quantity} {item.Name}.",
            Changes:
            [
                new ItemChangeDto(item.ItemId, item.Name, request.Quantity, finalQuantity)
            ],
            Inventory: await GetInventoryAsync(normalizedPlayerId));
    }

    public async Task<EquipWeaponResponse> EquipWeaponAsync(string playerId, EquipWeaponRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        await LockEquipmentAsync(connection, transaction, normalizedPlayerId);

        var existingActionPlayerId = await ReadEquipmentActionPlayerIdAsync(connection, transaction, actionId);
        if (existingActionPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingActionPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new EquipWeaponResponse(
                Completed: completed,
                Message: completed
                    ? "Weapon equip was already applied."
                    : "Idempotency key was already used by another player.",
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var catalogItem = ItemCatalog.Resolve(request.ItemId);
        if (!string.Equals(catalogItem.Category, "Weapon", StringComparison.OrdinalIgnoreCase) ||
            catalogItem.WeaponPower <= 0 ||
            catalogItem.MaxDurability <= 0)
        {
            await transaction.RollbackAsync();
            return new EquipWeaponResponse(
                Completed: false,
                Message: $"{catalogItem.Name} is not an equippable weapon.",
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var currentWeapon = await ReadEquippedWeaponAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (currentWeapon is not null && currentWeapon.Durability > 0)
        {
            await transaction.RollbackAsync();
            return new EquipWeaponResponse(
                Completed: false,
                Message: $"Break the equipped {currentWeapon.Name} before equipping another weapon.",
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var itemQuantity = await ReadItemQuantityForUpdateAsync(connection, transaction, normalizedPlayerId, catalogItem.ItemId);
        if (itemQuantity < 1)
        {
            await transaction.RollbackAsync();
            return new EquipWeaponResponse(
                Completed: false,
                Message: $"You do not have a {catalogItem.Name} to equip.",
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        await AddItemQuantityAsync(connection, transaction, normalizedPlayerId, catalogItem, -1, now);
        await UpsertEquippedWeaponAsync(connection, transaction, normalizedPlayerId, catalogItem, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            "weapon_equip",
            goldDelta: 0,
            itemId: catalogItem.ItemId,
            itemDelta: -1,
            description: $"Equipped {catalogItem.Name}.",
            createdAt: now,
            ledgerId: $"{actionId}:equip");
        await AddEquipmentActionAsync(
            connection,
            transaction,
            actionId,
            normalizedPlayerId,
            "weapon_equip",
            $"Equipped {catalogItem.Name}.",
            now);
        var equippedWeapon = await ReadEquippedWeaponAsync(connection, transaction, normalizedPlayerId);
        var wallet = await ReadWalletAsync(connection, transaction, normalizedPlayerId);
        var items = await ReadItemsAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return new EquipWeaponResponse(
            Completed: true,
            Message: $"Equipped {catalogItem.Name}.",
            Equipment: ToEquipmentResponse(normalizedPlayerId, equippedWeapon),
            Inventory: ToInventoryResponse(normalizedPlayerId, wallet, items));
    }

    public async Task<DamageWeaponResponse> DamageEquippedWeaponAsync(string playerId, DamageWeaponRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        await LockEquipmentAsync(connection, transaction, normalizedPlayerId);

        var existingActionPlayerId = await ReadEquipmentActionPlayerIdAsync(connection, transaction, actionId);
        if (existingActionPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingActionPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new DamageWeaponResponse(
                Completed: completed,
                Message: completed
                    ? "Weapon durability change was already applied."
                    : "Idempotency key was already used by another player.",
                DurabilityLost: 0,
                Equipment: await GetEquipmentAsync(normalizedPlayerId));
        }

        var weapon = await ReadEquippedWeaponAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (weapon is null || weapon.Durability <= 0)
        {
            await AddEquipmentActionAsync(
                connection,
                transaction,
                actionId,
                normalizedPlayerId,
                "weapon_damage",
                "No usable weapon was equipped.",
                now);
            await transaction.CommitAsync();
            return new DamageWeaponResponse(
                Completed: false,
                Message: "No usable weapon was equipped.",
                DurabilityLost: 0,
                Equipment: await GetEquipmentAsync(normalizedPlayerId));
        }

        var durabilityLost = Math.Min(request.DurabilityDamage, weapon.Durability);
        var newDurability = weapon.Durability - durabilityLost;
        await UpdateEquippedWeaponDurabilityAsync(connection, transaction, normalizedPlayerId, newDurability, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            "weapon_durability",
            goldDelta: 0,
            itemId: weapon.ItemId,
            itemDelta: 0,
            description: request.Reason,
            createdAt: now,
            ledgerId: $"{actionId}:damage");
        await AddEquipmentActionAsync(
            connection,
            transaction,
            actionId,
            normalizedPlayerId,
            "weapon_damage",
            request.Reason,
            now);
        var updatedWeapon = await ReadEquippedWeaponAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return new DamageWeaponResponse(
            Completed: true,
            Message: newDurability > 0
                ? $"{weapon.Name} lost {durabilityLost} durability."
                : $"{weapon.Name} broke.",
            DurabilityLost: durabilityLost,
            Equipment: ToEquipmentResponse(normalizedPlayerId, updatedWeapon));
    }

    public async Task<RepairWeaponResponse> RepairEquippedWeaponAsync(string playerId, RepairWeaponRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        await LockEquipmentAsync(connection, transaction, normalizedPlayerId);

        var existingActionPlayerId = await ReadEquipmentActionPlayerIdAsync(connection, transaction, actionId);
        if (existingActionPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingActionPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new RepairWeaponResponse(
                Completed: completed,
                Message: completed
                    ? "Weapon repair was already applied."
                    : "Idempotency key was already used by another player.",
                GoldCost: 0,
                MaterialItemId: "iron",
                MaterialItemName: "Iron",
                MaterialQuantity: 0,
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var weapon = await ReadEquippedWeaponAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (weapon is null)
        {
            await transaction.RollbackAsync();
            return new RepairWeaponResponse(
                Completed: false,
                Message: "No weapon is equipped.",
                GoldCost: 0,
                MaterialItemId: "iron",
                MaterialItemName: "Iron",
                MaterialQuantity: 0,
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var missingDurability = Math.Max(0, weapon.MaxDurability - weapon.Durability);
        if (missingDurability <= 0)
        {
            await transaction.RollbackAsync();
            return new RepairWeaponResponse(
                Completed: false,
                Message: $"{weapon.Name} is already fully repaired.",
                GoldCost: 0,
                MaterialItemId: "iron",
                MaterialItemName: "Iron",
                MaterialQuantity: 0,
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var material = ItemCatalog.Resolve("iron");
        var goldCost = missingDurability;
        var materialQuantity = Math.Max(1, (missingDurability + 4) / 5);
        var wallet = await ReadWalletAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (wallet.Gold < goldCost)
        {
            await transaction.RollbackAsync();
            return new RepairWeaponResponse(
                Completed: false,
                Message: $"Not enough gold. Required {goldCost}, available {wallet.Gold}.",
                GoldCost: goldCost,
                MaterialItemId: material.ItemId,
                MaterialItemName: material.Name,
                MaterialQuantity: materialQuantity,
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var materialAvailable = await ReadItemQuantityForUpdateAsync(connection, transaction, normalizedPlayerId, material.ItemId);
        if (materialAvailable < materialQuantity)
        {
            await transaction.RollbackAsync();
            return new RepairWeaponResponse(
                Completed: false,
                Message: $"Not enough {material.Name}. Required {materialQuantity}, available {materialAvailable}.",
                GoldCost: goldCost,
                MaterialItemId: material.ItemId,
                MaterialItemName: material.Name,
                MaterialQuantity: materialQuantity,
                Equipment: await GetEquipmentAsync(normalizedPlayerId),
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        await UpdateGoldAsync(connection, transaction, normalizedPlayerId, -goldCost, now);
        await AddItemQuantityAsync(connection, transaction, normalizedPlayerId, material, -materialQuantity, now);
        await UpdateEquippedWeaponDurabilityAsync(connection, transaction, normalizedPlayerId, weapon.MaxDurability, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            "weapon_repair",
            goldDelta: -goldCost,
            itemId: material.ItemId,
            itemDelta: -materialQuantity,
            description: $"Repaired {weapon.Name} by {missingDurability} durability.",
            createdAt: now,
            ledgerId: $"{actionId}:repair");
        await AddEquipmentActionAsync(
            connection,
            transaction,
            actionId,
            normalizedPlayerId,
            "weapon_repair",
            $"Repaired {weapon.Name}.",
            now);
        var repairedWeapon = await ReadEquippedWeaponAsync(connection, transaction, normalizedPlayerId);
        var updatedWallet = await ReadWalletAsync(connection, transaction, normalizedPlayerId);
        var items = await ReadItemsAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return new RepairWeaponResponse(
            Completed: true,
            Message: $"Repaired {weapon.Name} for {goldCost} gold and {materialQuantity} {material.Name}.",
            GoldCost: goldCost,
            MaterialItemId: material.ItemId,
            MaterialItemName: material.Name,
            MaterialQuantity: materialQuantity,
            Equipment: ToEquipmentResponse(normalizedPlayerId, repairedWeapon),
            Inventory: ToInventoryResponse(normalizedPlayerId, updatedWallet, items));
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

    public async Task<WalletDebitResponse> DebitWalletAsync(string playerId, WalletDebitRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var idempotencyKey = request.IdempotencyKey.Trim();
        await EnsurePlayerAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var existingDebitPlayerId = await ReadLedgerPlayerIdAsync(connection, transaction, idempotencyKey);
        if (existingDebitPlayerId is not null)
        {
            await transaction.CommitAsync();
            var completed = string.Equals(existingDebitPlayerId, normalizedPlayerId, StringComparison.Ordinal);
            return new WalletDebitResponse(
                Completed: completed,
                Message: completed
                    ? "Wallet debit was already applied."
                    : "Idempotency key was already used by another wallet.",
                Amount: completed ? request.Amount : 0,
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var wallet = await ReadWalletAsync(connection, transaction, normalizedPlayerId, forUpdate: true);
        if (wallet.Gold < request.Amount)
        {
            await transaction.RollbackAsync();
            return new WalletDebitResponse(
                Completed: false,
                Message: $"Not enough gold. Required {request.Amount}, available {wallet.Gold}.",
                Amount: 0,
                Inventory: await GetInventoryAsync(normalizedPlayerId));
        }

        var walletGold = await UpdateGoldAsync(connection, transaction, normalizedPlayerId, -request.Amount, now);
        await AddLedgerAsync(
            connection,
            transaction,
            normalizedPlayerId,
            request.EntryType.Trim().ToLowerInvariant(),
            goldDelta: -request.Amount,
            itemId: string.Empty,
            itemDelta: 0,
            description: request.Reason,
            createdAt: now,
            ledgerId: idempotencyKey);
        await transaction.CommitAsync();

        return new WalletDebitResponse(
            Completed: true,
            Message: $"Debited {request.Amount} gold. Wallet balance is {walletGold}.",
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

    private static async Task LockEquipmentAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand(
            "SELECT pg_advisory_xact_lock(hashtext(@lock_key));",
            connection,
            transaction);
        command.Parameters.AddWithValue("lock_key", $"equipment:{playerId}");
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<EquipmentRecord?> ReadEquippedWeaponAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        bool forUpdate = false)
    {
        var sql = """
            SELECT item_id, name, category, weapon_power, durability, max_durability, equipped_at, updated_at
            FROM economy.equipment
            WHERE player_id = @player_id AND slot = 'weapon'
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new EquipmentRecord(
                ItemId: reader.GetString(0),
                Name: reader.GetString(1),
                Category: reader.GetString(2),
                WeaponPower: reader.GetInt32(3),
                Durability: reader.GetInt32(4),
                MaxDurability: reader.GetInt32(5),
                EquippedAt: reader.GetFieldValue<DateTimeOffset>(6),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(7))
            : null;
    }

    private static async Task UpsertEquippedWeaponAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        CatalogItem item,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO economy.equipment (
                player_id, slot, item_id, name, category, weapon_power, durability, max_durability, equipped_at, updated_at
            )
            VALUES (
                @player_id, 'weapon', @item_id, @name, @category, @weapon_power, @durability, @max_durability, @equipped_at, @updated_at
            )
            ON CONFLICT (player_id, slot) DO UPDATE
            SET item_id = EXCLUDED.item_id,
                name = EXCLUDED.name,
                category = EXCLUDED.category,
                weapon_power = EXCLUDED.weapon_power,
                durability = EXCLUDED.durability,
                max_durability = EXCLUDED.max_durability,
                equipped_at = EXCLUDED.equipped_at,
                updated_at = EXCLUDED.updated_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("item_id", item.ItemId);
        command.Parameters.AddWithValue("name", item.Name);
        command.Parameters.AddWithValue("category", item.Category);
        command.Parameters.AddWithValue("weapon_power", item.WeaponPower);
        command.Parameters.AddWithValue("durability", item.MaxDurability);
        command.Parameters.AddWithValue("max_durability", item.MaxDurability);
        command.Parameters.AddWithValue("equipped_at", updatedAt);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task UpdateEquippedWeaponDurabilityAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        int durability,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE economy.equipment
            SET durability = @durability,
                updated_at = @updated_at
            WHERE player_id = @player_id AND slot = 'weapon';
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("durability", durability);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<string?> ReadEquipmentActionPlayerIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id
            FROM economy.equipment_actions
            WHERE action_id = @action_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("action_id", actionId);
        var result = await command.ExecuteScalarAsync();
        return result as string;
    }

    private static async Task AddEquipmentActionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actionId,
        string playerId,
        string actionType,
        string message,
        DateTimeOffset createdAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO economy.equipment_actions (
                action_id, player_id, action_type, message, created_at
            )
            VALUES (
                @action_id, @player_id, @action_type, @message, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("action_id", actionId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<LedgerEntryDto>> ReadLedgerEntriesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT ledger_id, entry_type, gold_delta, item_id, item_delta, description, created_at
            FROM economy.ledger_entries
            WHERE player_id = @player_id
            ORDER BY created_at DESC, ledger_id DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("limit", limit);

        var entries = new List<LedgerEntryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(new LedgerEntryDto(
                LedgerId: reader.GetString(0),
                EntryType: reader.GetString(1),
                GoldDelta: reader.GetInt32(2),
                ItemId: reader.GetString(3),
                ItemDelta: reader.GetInt32(4),
                Description: reader.GetString(5),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(6)));
        }

        return entries;
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

    private static EquipmentResponse ToEquipmentResponse(
        string playerId,
        EquipmentRecord? weapon)
    {
        return new EquipmentResponse(
            PlayerId: playerId,
            Weapon: weapon is null
                ? null
                : new EquippedWeaponDto(
                    ItemId: weapon.ItemId,
                    Name: weapon.Name,
                    Category: weapon.Category,
                    WeaponPower: weapon.WeaponPower,
                    Durability: weapon.Durability,
                    MaxDurability: weapon.MaxDurability,
                    EquippedAt: weapon.EquippedAt,
                    UpdatedAt: weapon.UpdatedAt),
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
            "food" => new CatalogItem("food", "Food", "Consumable", "Restores 20 energy when used."),
            "weapon_q1" => new CatalogItem("weapon_q1", "Q1 Weapon", "Weapon", "Basic combat weapon used by early missions.", WeaponPower: 3, MaxDurability: 10),
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

internal sealed record EquipmentResponse(
    string PlayerId,
    EquippedWeaponDto? Weapon,
    DateTimeOffset UpdatedAt);

internal sealed record EquippedWeaponDto(
    string ItemId,
    string Name,
    string Category,
    int WeaponPower,
    int Durability,
    int MaxDurability,
    DateTimeOffset EquippedAt,
    DateTimeOffset UpdatedAt);

internal sealed record LedgerResponse(
    string PlayerId,
    LedgerEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

internal sealed record LedgerEntryDto(
    string LedgerId,
    string EntryType,
    int GoldDelta,
    string ItemId,
    int ItemDelta,
    string Description,
    DateTimeOffset CreatedAt);

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

internal sealed record EquipWeaponRequest(
    string ItemId,
    string IdempotencyKey);

internal sealed record EquipWeaponResponse(
    bool Completed,
    string Message,
    EquipmentResponse Equipment,
    InventoryResponse Inventory);

internal sealed record DamageWeaponRequest(
    int DurabilityDamage,
    string Reason,
    string IdempotencyKey);

internal sealed record DamageWeaponResponse(
    bool Completed,
    string Message,
    int DurabilityLost,
    EquipmentResponse Equipment);

internal sealed record RepairWeaponRequest(string IdempotencyKey);

internal sealed record RepairWeaponResponse(
    bool Completed,
    string Message,
    int GoldCost,
    string MaterialItemId,
    string MaterialItemName,
    int MaterialQuantity,
    EquipmentResponse Equipment,
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
    int PricePerUnit,
    string SellerId,
    string IdempotencyKey,
    int BuyerTaxAmount = 0,
    int SellerTaxAmount = 0);

internal sealed record MarketPurchaseResponse(
    bool Completed,
    string Message,
    string ListingId,
    int Quantity,
    int TotalPrice,
    string SellerId,
    InventoryResponse Inventory,
    int BuyerTaxAmount = 0,
    int SellerTaxAmount = 0,
    int BuyerTotal = 0,
    int SellerNet = 0);

internal sealed record InventoryRemovalRequest(
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    string Reason,
    string IdempotencyKey);

internal sealed record InventoryGrantRequest(
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record InventorySpendRequest(
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int GoldCost,
    string EntryType,
    string Reason,
    string IdempotencyKey);

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

internal sealed record WalletDebitRequest(
    int Amount,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record WalletDebitResponse(
    bool Completed,
    string Message,
    int Amount,
    InventoryResponse Inventory);

internal sealed record EquipmentRecord(
    string ItemId,
    string Name,
    string Category,
    int WeaponPower,
    int Durability,
    int MaxDurability,
    DateTimeOffset EquippedAt,
    DateTimeOffset UpdatedAt);

internal sealed record CatalogItem(
    string ItemId,
    string Name,
    string Category,
    string Description,
    int WeaponPower = 0,
    int MaxDurability = 0);

internal sealed record SeedItem(CatalogItem Item, int Quantity);

internal sealed record WalletRecord(int Gold, int StorageLimit);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

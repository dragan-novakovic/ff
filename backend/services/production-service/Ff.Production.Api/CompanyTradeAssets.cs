using Npgsql;

internal static class CompanyTradeAssetEndpoints
{
    public static void MapCompanyTradeAssetEndpoints(this WebApplication app)
    {
        app.MapPost("/companies/{companyId}/assets/wallet/debit", async (
            string companyId,
            CompanyWalletMutationRequest request,
            HttpRequest httpRequest,
            ProductionStore production,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return ToStoreResult(await production.DebitCompanyWalletAsync(companyId, request));
        }).WithName("DebitCompanyWallet");

        app.MapPost("/companies/{companyId}/assets/wallet/credit", async (
            string companyId,
            CompanyWalletMutationRequest request,
            HttpRequest httpRequest,
            ProductionStore production,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return ToStoreResult(await production.CreditCompanyWalletAsync(companyId, request));
        }).WithName("CreditCompanyWallet");

        app.MapPost("/companies/{companyId}/assets/inventory/remove", async (
            string companyId,
            CompanyInventoryMutationRequest request,
            HttpRequest httpRequest,
            ProductionStore production,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return ToStoreResult(await production.RemoveCompanyInventoryAsync(companyId, request));
        }).WithName("RemoveCompanyInventory");

        app.MapPost("/companies/{companyId}/assets/inventory/grant", async (
            string companyId,
            CompanyInventoryMutationRequest request,
            HttpRequest httpRequest,
            ProductionStore production,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(httpRequest, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return ToStoreResult(await production.GrantCompanyInventoryAsync(companyId, request));
        }).WithName("GrantCompanyInventory");
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

    private static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
    {
        var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
        return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
            string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
    }
}

internal sealed partial class ProductionStore
{
    public async Task InitializeCompanyTradeAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS production.company_asset_events (
                event_id text PRIMARY KEY,
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                actor_player_id text NOT NULL,
                event_type text NOT NULL,
                gold_delta integer NOT NULL,
                item_id text NOT NULL,
                item_delta integer NOT NULL,
                description text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS company_asset_events_company_created_idx
            ON production.company_asset_events (company_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public Task<StoreResult<CompanyAssetMutationResponse>> DebitCompanyWalletAsync(
        string companyId,
        CompanyWalletMutationRequest request)
    {
        return MutateCompanyWalletAsync(companyId, request, debit: true);
    }

    public Task<StoreResult<CompanyAssetMutationResponse>> CreditCompanyWalletAsync(
        string companyId,
        CompanyWalletMutationRequest request)
    {
        return MutateCompanyWalletAsync(companyId, request, debit: false);
    }

    public Task<StoreResult<CompanyAssetMutationResponse>> RemoveCompanyInventoryAsync(
        string companyId,
        CompanyInventoryMutationRequest request)
    {
        return MutateCompanyInventoryAsync(companyId, request, remove: true);
    }

    public Task<StoreResult<CompanyAssetMutationResponse>> GrantCompanyInventoryAsync(
        string companyId,
        CompanyInventoryMutationRequest request)
    {
        return MutateCompanyInventoryAsync(companyId, request, remove: false);
    }

    private async Task<StoreResult<CompanyAssetMutationResponse>> MutateCompanyWalletAsync(
        string companyId,
        CompanyWalletMutationRequest request,
        bool debit)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        var eventId = NormalizeId(request.IdempotencyKey);
        if (string.IsNullOrWhiteSpace(normalizedActorId) ||
            string.IsNullOrWhiteSpace(eventId) ||
            request.Amount <= 0)
        {
            return StoreResult<CompanyAssetMutationResponse>.BadRequest("Actor, amount, and idempotency key are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var access = await ValidateCompanyAssetAccessAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (access is not null)
        {
            await transaction.RollbackAsync();
            return access;
        }

        var existingCompanyId = await ReadCompanyAssetEventCompanyIdAsync(connection, transaction, eventId);
        if (existingCompanyId is not null)
        {
            var completed = string.Equals(existingCompanyId, normalizedCompanyId, StringComparison.Ordinal);
            var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
            await transaction.CommitAsync();
            return StoreResult<CompanyAssetMutationResponse>.Ok(new CompanyAssetMutationResponse(
                Completed: completed,
                Message: completed
                    ? "Company wallet mutation was already applied."
                    : "Idempotency key was already used by another company.",
                Assets: assets!));
        }

        var walletGold = await ReadCompanyWalletForUpdateAsync(connection, transaction, normalizedCompanyId);
        var delta = debit ? -request.Amount : request.Amount;
        if (debit && walletGold < request.Amount)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyAssetMutationResponse>.Conflict(
                $"Not enough company gold. Required {request.Amount}, available {walletGold}.");
        }

        await UpdateCompanyWalletAsync(connection, transaction, normalizedCompanyId, delta, now);
        await RecordCompanyAssetEventAsync(
            connection,
            transaction,
            eventId,
            normalizedCompanyId,
            normalizedActorId,
            NormalizeEntryType(request.EntryType, debit ? "company_wallet_debit" : "company_wallet_credit"),
            goldDelta: delta,
            itemId: string.Empty,
            itemDelta: 0,
            description: NormalizeReason(request.Reason, debit ? "Company wallet debit." : "Company wallet credit."),
            createdAt: now);
        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var updatedAssets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<CompanyAssetMutationResponse>.Ok(new CompanyAssetMutationResponse(
            Completed: true,
            Message: debit
                ? $"Debited {request.Amount} gold from company wallet."
                : $"Credited {request.Amount} gold to company wallet.",
            Assets: updatedAssets!));
    }

    private async Task<StoreResult<CompanyAssetMutationResponse>> MutateCompanyInventoryAsync(
        string companyId,
        CompanyInventoryMutationRequest request,
        bool remove)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        var eventId = NormalizeId(request.IdempotencyKey);
        var itemId = NormalizeId(request.ItemId);
        if (string.IsNullOrWhiteSpace(normalizedActorId) ||
            string.IsNullOrWhiteSpace(eventId) ||
            string.IsNullOrWhiteSpace(itemId) ||
            string.IsNullOrWhiteSpace(request.ItemName) ||
            string.IsNullOrWhiteSpace(request.Category) ||
            request.Quantity <= 0)
        {
            return StoreResult<CompanyAssetMutationResponse>.BadRequest(
                "Actor, item, quantity, and idempotency key are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var access = await ValidateCompanyAssetAccessAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (access is not null)
        {
            await transaction.RollbackAsync();
            return access;
        }

        var existingCompanyId = await ReadCompanyAssetEventCompanyIdAsync(connection, transaction, eventId);
        if (existingCompanyId is not null)
        {
            var completed = string.Equals(existingCompanyId, normalizedCompanyId, StringComparison.Ordinal);
            var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
            await transaction.CommitAsync();
            return StoreResult<CompanyAssetMutationResponse>.Ok(new CompanyAssetMutationResponse(
                Completed: completed,
                Message: completed
                    ? "Company inventory mutation was already applied."
                    : "Idempotency key was already used by another company.",
                Assets: assets!));
        }

        if (remove)
        {
            var available = await ReadCompanyInventoryQuantityForUpdateAsync(
                connection,
                transaction,
                normalizedCompanyId,
                itemId);
            if (available < request.Quantity)
            {
                await transaction.RollbackAsync();
                return StoreResult<CompanyAssetMutationResponse>.Conflict(
                    $"Not enough company {request.ItemName}. Required {request.Quantity}, available {available}.");
            }

            await SpendCompanyInventoryAsync(connection, transaction, normalizedCompanyId, itemId, request.Quantity, now);
        }
        else
        {
            var storageError = await GrantCompanyInventoryAsync(
                connection,
                transaction,
                normalizedCompanyId,
                itemId,
                request.ItemName.Trim(),
                request.Category.Trim(),
                request.Quantity,
                NormalizeReason(request.Reason, "Company inventory grant."),
                now);
            if (storageError is not null)
            {
                await transaction.RollbackAsync();
                return StoreResult<CompanyAssetMutationResponse>.Conflict(storageError);
            }
        }

        await RecordCompanyAssetEventAsync(
            connection,
            transaction,
            eventId,
            normalizedCompanyId,
            normalizedActorId,
            NormalizeEntryType(request.EntryType, remove ? "company_inventory_remove" : "company_inventory_grant"),
            goldDelta: 0,
            itemId: itemId,
            itemDelta: remove ? -request.Quantity : request.Quantity,
            description: NormalizeReason(request.Reason, remove ? "Company inventory removal." : "Company inventory grant."),
            createdAt: now);
        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var updatedAssets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<CompanyAssetMutationResponse>.Ok(new CompanyAssetMutationResponse(
            Completed: true,
            Message: remove
                ? $"Removed {request.Quantity} {request.ItemName} from company inventory."
                : $"Granted {request.Quantity} {request.ItemName} to company inventory.",
            Assets: updatedAssets!));
    }

    private static async Task<StoreResult<CompanyAssetMutationResponse>?> ValidateCompanyAssetAccessAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string actorPlayerId)
    {
        if (!await CompanyExistsAsync(connection, transaction, companyId))
        {
            return StoreResult<CompanyAssetMutationResponse>.NotFound("Company was not found.");
        }

        var role = await ReadCompanyMemberRoleAsync(connection, transaction, companyId, actorPlayerId);
        if (!CanManageCompany(role))
        {
            return StoreResult<CompanyAssetMutationResponse>.Forbidden(
                "Only company owners and managers can mutate company trade assets.");
        }

        return null;
    }

    private static async Task<int> ReadCompanyWalletForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT wallet_gold
            FROM production.companies
            WHERE company_id = @company_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        return (int)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Company wallet was not found."));
    }

    private static async Task UpdateCompanyWalletAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        int goldDelta,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE production.companies
            SET wallet_gold = wallet_gold + @gold_delta,
                updated_at = @updated_at
            WHERE company_id = @company_id
              AND wallet_gold + @gold_delta >= 0;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("gold_delta", goldDelta);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        var affected = await command.ExecuteNonQueryAsync();
        if (affected != 1)
        {
            throw new InvalidOperationException("Company wallet update failed.");
        }
    }

    private static async Task<string?> ReadCompanyAssetEventCompanyIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT company_id
            FROM production.company_asset_events
            WHERE event_id = @event_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        var result = await command.ExecuteScalarAsync();
        return result as string;
    }

    private static async Task RecordCompanyAssetEventAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId,
        string companyId,
        string actorPlayerId,
        string eventType,
        int goldDelta,
        string itemId,
        int itemDelta,
        string description,
        DateTimeOffset createdAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO production.company_asset_events (
                event_id, company_id, actor_player_id, event_type, gold_delta,
                item_id, item_delta, description, created_at
            )
            VALUES (
                @event_id, @company_id, @actor_player_id, @event_type, @gold_delta,
                @item_id, @item_delta, @description, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId);
        command.Parameters.AddWithValue("event_type", eventType);
        command.Parameters.AddWithValue("gold_delta", goldDelta);
        command.Parameters.AddWithValue("item_id", itemId);
        command.Parameters.AddWithValue("item_delta", itemDelta);
        command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync();
    }

    private static string NormalizeEntryType(string? entryType, string fallback)
    {
        var normalized = NormalizeId(entryType);
        return string.IsNullOrWhiteSpace(normalized) ? fallback : normalized;
    }

    private static string NormalizeReason(string? reason, string fallback)
    {
        var normalized = string.Join(
            ' ',
            (reason ?? string.Empty)
                .Trim()
                .Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return string.IsNullOrWhiteSpace(normalized) ? fallback : normalized;
    }
}

internal sealed record CompanyWalletMutationRequest(
    string? ActorPlayerId,
    int Amount,
    string? EntryType,
    string? Reason,
    string? IdempotencyKey);

internal sealed record CompanyInventoryMutationRequest(
    string? ActorPlayerId,
    string? ItemId,
    string? ItemName,
    string? Category,
    int Quantity,
    string? EntryType,
    string? Reason,
    string? IdempotencyKey);

internal sealed record CompanyAssetMutationResponse(
    bool Completed,
    string Message,
    CompanyAssetsDto Assets);

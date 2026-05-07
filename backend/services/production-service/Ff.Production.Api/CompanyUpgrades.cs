using Npgsql;

internal static class CompanyUpgradeEndpoints
{
    public static void MapCompanyUpgradeEndpoints(this WebApplication app)
    {
        app.MapGet("/companies/{companyId}/upgrades", async (
            string companyId,
            string? actorPlayerId,
            ProductionStore production) =>
        {
            if (string.IsNullOrWhiteSpace(actorPlayerId))
            {
                return Results.BadRequest(new ErrorResponse("Actor player id is required."));
            }

            return ToStoreResult(await production.GetCompanyUpgradeStateAsync(companyId, actorPlayerId));
        }).WithName("GetCompanyUpgrades");

        app.MapPost("/companies/{companyId}/upgrades/hq", async (
            string companyId,
            CompanyActorRequest request,
            ProductionStore production) =>
            ToStoreResult(await production.UpgradeCompanyHqAsync(companyId, request.ActorPlayerId)))
            .WithName("UpgradeCompanyHq");

        app.MapPost("/companies/{companyId}/specialization", async (
            string companyId,
            CompanySpecializationRequest request,
            ProductionStore production) =>
            ToStoreResult(await production.SetCompanySpecializationAsync(
                companyId,
                request.ActorPlayerId,
                request.Specialization)))
            .WithName("SetCompanySpecialization");
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
    private const int CompanyHqUpgradeBaseGoldCost = 250;
    private const int CompanyHqUpgradeLaborCreditBaseCost = 10;
    private const int CompanyHqStorageLimitIncrease = 100;
    private const int CompanyHqFactorySlotIncrease = 1;
    private const int CompanyHqProductivityBonusIncreasePercent = 5;
    private const int CompanySpecializationGoldCost = 100;
    private const int CompanySpecializationLaborCreditCost = 5;

    public async Task InitializeCompanyUpgradeAsync()
    {
        const string sql = """
            ALTER TABLE production.companies
                ADD COLUMN IF NOT EXISTS hq_level integer NOT NULL DEFAULT 1;

            ALTER TABLE production.companies
                ADD COLUMN IF NOT EXISTS specialization text NOT NULL DEFAULT 'general';

            ALTER TABLE production.companies
                ADD COLUMN IF NOT EXISTS factory_slots integer NOT NULL DEFAULT 2;

            ALTER TABLE production.companies
                ADD COLUMN IF NOT EXISTS productivity_bonus_percent integer NOT NULL DEFAULT 0;

            UPDATE production.companies companies
            SET factory_slots = GREATEST(
                    factory_slots,
                    COALESCE((
                        SELECT COUNT(*)
                        FROM production.company_factories factories
                        WHERE factories.company_id = companies.company_id
                    ), 0)::integer,
                    2
                ),
                hq_level = GREATEST(hq_level, 1),
                productivity_bonus_percent = GREATEST(productivity_bonus_percent, 0),
                specialization = CASE
                    WHEN specialization IN ('general', 'food', 'weapon', 'logistics') THEN specialization
                    ELSE 'general'
                END;

            CREATE TABLE IF NOT EXISTS production.company_upgrade_events (
                event_id text PRIMARY KEY,
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                actor_player_id text NOT NULL,
                upgrade_type text NOT NULL,
                from_level integer NOT NULL,
                to_level integer NOT NULL,
                gold_cost integer NOT NULL,
                item_id text NOT NULL,
                item_quantity integer NOT NULL,
                specialization text NOT NULL,
                description text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS company_upgrade_events_company_created_idx
            ON production.company_upgrade_events (company_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<StoreResult<CompanyUpgradeStateDto>> GetCompanyUpgradeStateAsync(
        string companyId,
        string actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();

        if (!await CompanyExistsAsync(connection, null, normalizedCompanyId))
        {
            return StoreResult<CompanyUpgradeStateDto>.NotFound("Company was not found.");
        }

        var role = await ReadCompanyMemberRoleAsync(connection, null, normalizedCompanyId, normalizedActorId);
        if (role is null)
        {
            return StoreResult<CompanyUpgradeStateDto>.Forbidden("You must be a company member to view upgrades.");
        }

        var state = await ReadCompanyUpgradeStateAsync(connection, null, normalizedCompanyId, role);
        return state is null
            ? StoreResult<CompanyUpgradeStateDto>.NotFound("Company upgrades were not found.")
            : StoreResult<CompanyUpgradeStateDto>.Ok(state);
    }

    public async Task<StoreResult<CompanyUpgradeMutationResponse>> UpgradeCompanyHqAsync(
        string companyId,
        string? actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<CompanyUpgradeMutationResponse>.BadRequest("Actor player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyUpgradeMutationResponse>.Forbidden("You must be a company member to upgrade headquarters.")
                : StoreResult<CompanyUpgradeMutationResponse>.NotFound("Company was not found.");
        }

        var permissions = CreateCompanyPermissions(actorRole);
        if (!permissions.CanManageUpgrades)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyUpgradeMutationResponse>.Forbidden("Only owners and managers can upgrade company headquarters.");
        }

        var snapshot = await ReadCompanyUpgradeSnapshotForUpdateAsync(connection, transaction, normalizedCompanyId);
        if (snapshot is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyUpgradeMutationResponse>.NotFound("Company was not found.");
        }

        var laborCredits = await ReadCompanyInventoryQuantityForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            LaborCreditItemId);
        var usedFactorySlots = await ReadCompanyFactoryCountAsync(connection, transaction, normalizedCompanyId);
        var quote = CreateCompanyHqUpgradeQuote(snapshot, usedFactorySlots, laborCredits);
        if (!quote.CanUpgrade)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyUpgradeMutationResponse>.Conflict(quote.Message);
        }

        if (quote.RequiredItemQuantity > 0)
        {
            await SpendCompanyInventoryAsync(
                connection,
                transaction,
                normalizedCompanyId,
                quote.RequiredItemId,
                quote.RequiredItemQuantity,
                now);
        }

        await using (var update = new NpgsqlCommand("""
            UPDATE production.companies
            SET wallet_gold = wallet_gold - @gold_cost,
                hq_level = @hq_level,
                storage_limit = @storage_limit,
                factory_slots = @factory_slots,
                productivity_bonus_percent = @productivity_bonus_percent,
                updated_at = @updated_at
            WHERE company_id = @company_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("company_id", normalizedCompanyId);
            update.Parameters.AddWithValue("gold_cost", quote.GoldCost);
            update.Parameters.AddWithValue("hq_level", quote.NextLevel);
            update.Parameters.AddWithValue("storage_limit", quote.StorageLimitAfterUpgrade);
            update.Parameters.AddWithValue("factory_slots", quote.FactorySlotsAfterUpgrade);
            update.Parameters.AddWithValue("productivity_bonus_percent", quote.ProductivityBonusPercentAfterUpgrade);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await RecordCompanyUpgradeEventAsync(
            connection,
            transaction,
            $"cup-{Guid.NewGuid():N}",
            normalizedCompanyId,
            normalizedActorId,
            "hq",
            snapshot.HqLevel,
            quote.NextLevel,
            quote.GoldCost,
            quote.RequiredItemId,
            quote.RequiredItemQuantity,
            snapshot.Specialization,
            $"Upgraded company HQ to level {quote.NextLevel}.",
            now);

        var company = await ReadCompanyDetailAsync(connection, transaction, normalizedCompanyId, normalizedActorId, now);
        await transaction.CommitAsync();

        return StoreResult<CompanyUpgradeMutationResponse>.Ok(new CompanyUpgradeMutationResponse(
            Completed: true,
            Message: $"Company HQ upgraded to level {quote.NextLevel}. Storage, factory slots, and productivity increased.",
            Upgrades: company!.Assets.Upgrades,
            Company: company));
    }

    public async Task<StoreResult<CompanyUpgradeMutationResponse>> SetCompanySpecializationAsync(
        string companyId,
        string? actorPlayerId,
        string? specialization)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        var normalizedSpecialization = NormalizeCompanySpecialization(specialization);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<CompanyUpgradeMutationResponse>.BadRequest("Actor player id is required.");
        }

        if (normalizedSpecialization is null)
        {
            return StoreResult<CompanyUpgradeMutationResponse>.BadRequest("Specialization must be general, food, weapon, or logistics.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyUpgradeMutationResponse>.Forbidden("You must be a company member to specialize the company.")
                : StoreResult<CompanyUpgradeMutationResponse>.NotFound("Company was not found.");
        }

        var permissions = CreateCompanyPermissions(actorRole);
        if (!permissions.CanManageSpecialization)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyUpgradeMutationResponse>.Forbidden("Only owners and managers can change company specialization.");
        }

        var snapshot = await ReadCompanyUpgradeSnapshotForUpdateAsync(connection, transaction, normalizedCompanyId);
        if (snapshot is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyUpgradeMutationResponse>.NotFound("Company was not found.");
        }

        if (string.Equals(snapshot.Specialization, normalizedSpecialization, StringComparison.Ordinal))
        {
            var unchangedCompany = await ReadCompanyDetailAsync(connection, transaction, normalizedCompanyId, normalizedActorId, now);
            await transaction.CommitAsync();
            return StoreResult<CompanyUpgradeMutationResponse>.Ok(new CompanyUpgradeMutationResponse(
                Completed: false,
                Message: $"Company specialization is already {normalizedSpecialization}.",
                Upgrades: unchangedCompany!.Assets.Upgrades,
                Company: unchangedCompany));
        }

        var laborCredits = await ReadCompanyInventoryQuantityForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            LaborCreditItemId);
        if (snapshot.WalletGold < CompanySpecializationGoldCost || laborCredits < CompanySpecializationLaborCreditCost)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyUpgradeMutationResponse>.Conflict(
                $"Specialization requires {CompanySpecializationGoldCost} gold and {CompanySpecializationLaborCreditCost} Labor Credit.");
        }

        await SpendCompanyInventoryAsync(
            connection,
            transaction,
            normalizedCompanyId,
            LaborCreditItemId,
            CompanySpecializationLaborCreditCost,
            now);

        await using (var update = new NpgsqlCommand("""
            UPDATE production.companies
            SET wallet_gold = wallet_gold - @gold_cost,
                specialization = @specialization,
                updated_at = @updated_at
            WHERE company_id = @company_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("company_id", normalizedCompanyId);
            update.Parameters.AddWithValue("gold_cost", CompanySpecializationGoldCost);
            update.Parameters.AddWithValue("specialization", normalizedSpecialization);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await RecordCompanyUpgradeEventAsync(
            connection,
            transaction,
            $"csp-{Guid.NewGuid():N}",
            normalizedCompanyId,
            normalizedActorId,
            "specialization",
            snapshot.HqLevel,
            snapshot.HqLevel,
            CompanySpecializationGoldCost,
            LaborCreditItemId,
            CompanySpecializationLaborCreditCost,
            normalizedSpecialization,
            $"Changed company specialization to {normalizedSpecialization}.",
            now);

        var company = await ReadCompanyDetailAsync(connection, transaction, normalizedCompanyId, normalizedActorId, now);
        await transaction.CommitAsync();

        return StoreResult<CompanyUpgradeMutationResponse>.Ok(new CompanyUpgradeMutationResponse(
            Completed: true,
            Message: $"Company specialization changed to {normalizedSpecialization}.",
            Upgrades: company!.Assets.Upgrades,
            Company: company));
    }

    private static async Task<CompanyUpgradeStateDto?> ReadCompanyUpgradeStateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string? actorRole)
    {
        var snapshot = await ReadCompanyUpgradeSnapshotAsync(connection, transaction, companyId);
        if (snapshot is null)
        {
            return null;
        }

        var usedFactorySlots = await ReadCompanyFactoryCountAsync(connection, transaction, companyId);
        var laborCredits = await ReadCompanyInventoryQuantityAsync(connection, transaction, companyId, LaborCreditItemId);
        return CreateCompanyUpgradeState(
            companyId,
            snapshot.HqLevel,
            snapshot.Specialization,
            snapshot.FactorySlots,
            usedFactorySlots,
            snapshot.StorageUsed,
            snapshot.StorageLimit,
            snapshot.ProductivityBonusPercent,
            snapshot.WalletGold,
            laborCredits,
            CreateCompanyPermissions(actorRole).CanManageUpgrades,
            snapshot.UpdatedAt);
    }

    private static CompanyUpgradeStateDto CreateCompanyUpgradeState(
        string companyId,
        int hqLevel,
        string specialization,
        int factorySlots,
        int usedFactorySlots,
        int storageUsed,
        int storageLimit,
        int productivityBonusPercent,
        int walletGold,
        int laborCredits,
        bool canManageUpgrades,
        DateTimeOffset updatedAt)
    {
        var snapshot = new CompanyUpgradeSnapshot(
            WalletGold: walletGold,
            StorageUsed: storageUsed,
            StorageLimit: storageLimit,
            HqLevel: hqLevel,
            Specialization: specialization,
            FactorySlots: factorySlots,
            ProductivityBonusPercent: productivityBonusPercent,
            UpdatedAt: updatedAt);
        var quote = CreateCompanyHqUpgradeQuote(snapshot, usedFactorySlots, laborCredits);
        return new CompanyUpgradeStateDto(
            CompanyId: companyId,
            HqLevel: hqLevel,
            Specialization: specialization,
            FactorySlots: factorySlots,
            UsedFactorySlots: usedFactorySlots,
            AvailableFactorySlots: Math.Max(0, factorySlots - usedFactorySlots),
            StorageUsed: storageUsed,
            StorageLimit: storageLimit,
            ProductivityBonusPercent: productivityBonusPercent,
            NextHqUpgrade: quote,
            SpecializationOptions: CreateSpecializationOptions(specialization),
            CanManageUpgrades: canManageUpgrades,
            UpdatedAt: updatedAt);
    }

    private static CompanyUpgradeQuoteDto CreateCompanyHqUpgradeQuote(
        CompanyUpgradeSnapshot snapshot,
        int usedFactorySlots,
        int availableLaborCredits)
    {
        var nextLevel = snapshot.HqLevel + 1;
        var goldCost = CompanyHqUpgradeBaseGoldCost * nextLevel;
        var laborCost = CompanyHqUpgradeLaborCreditBaseCost * nextLevel;
        var canAffordGold = snapshot.WalletGold >= goldCost;
        var canAffordLabor = availableLaborCredits >= laborCost;
        var canUpgrade = canAffordGold && canAffordLabor;
        var message = canUpgrade
            ? $"Upgrade HQ to level {nextLevel} for {goldCost} gold and {laborCost} Labor Credit."
            : $"HQ upgrade needs {goldCost} gold ({snapshot.WalletGold} available) and {laborCost} Labor Credit ({availableLaborCredits} available).";

        return new CompanyUpgradeQuoteDto(
            UpgradeType: "hq",
            CurrentLevel: snapshot.HqLevel,
            NextLevel: nextLevel,
            GoldCost: goldCost,
            RequiredItemId: LaborCreditItemId,
            RequiredItemName: "Labor Credit",
            RequiredItemQuantity: laborCost,
            AvailableGold: snapshot.WalletGold,
            AvailableItemQuantity: availableLaborCredits,
            StorageLimitAfterUpgrade: snapshot.StorageLimit + CompanyHqStorageLimitIncrease,
            FactorySlotsAfterUpgrade: Math.Max(snapshot.FactorySlots, usedFactorySlots) + CompanyHqFactorySlotIncrease,
            ProductivityBonusPercentAfterUpgrade: snapshot.ProductivityBonusPercent + CompanyHqProductivityBonusIncreasePercent,
            CanUpgrade: canUpgrade,
            Message: message);
    }

    private static async Task<CompanyUpgradeSnapshot?> ReadCompanyUpgradeSnapshotAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT wallet_gold,
                   COALESCE((
                       SELECT SUM(quantity)
                       FROM production.company_inventory inventory
                       WHERE inventory.company_id = companies.company_id
                   ), 0)::integer AS storage_used,
                   storage_limit,
                   hq_level,
                   specialization,
                   factory_slots,
                   productivity_bonus_percent,
                   updated_at
            FROM production.companies companies
            WHERE company_id = @company_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCompanyUpgradeSnapshot(reader) : null;
    }

    private static async Task<CompanyUpgradeSnapshot?> ReadCompanyUpgradeSnapshotForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT wallet_gold,
                   COALESCE((
                       SELECT SUM(quantity)
                       FROM production.company_inventory inventory
                       WHERE inventory.company_id = companies.company_id
                   ), 0)::integer AS storage_used,
                   storage_limit,
                   hq_level,
                   specialization,
                   factory_slots,
                   productivity_bonus_percent,
                   updated_at
            FROM production.companies companies
            WHERE company_id = @company_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCompanyUpgradeSnapshot(reader) : null;
    }

    private static CompanyUpgradeSnapshot ReadCompanyUpgradeSnapshot(NpgsqlDataReader reader)
    {
        return new CompanyUpgradeSnapshot(
            WalletGold: reader.GetInt32(0),
            StorageUsed: reader.GetInt32(1),
            StorageLimit: reader.GetInt32(2),
            HqLevel: reader.GetInt32(3),
            Specialization: reader.GetString(4),
            FactorySlots: reader.GetInt32(5),
            ProductivityBonusPercent: reader.GetInt32(6),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(7));
    }

    private static async Task<int> ReadCompanyFactoryCountAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT COUNT(*)
            FROM production.company_factories
            WHERE company_id = @company_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private static async Task<int> ReadCompanyInventoryQuantityAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string itemId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT quantity
            FROM production.company_inventory
            WHERE company_id = @company_id AND item_id = @item_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("item_id", itemId);
        var result = await command.ExecuteScalarAsync();
        return result is int quantity ? quantity : 0;
    }

    private static async Task<int> ReadCompanyProductivityBonusPercentAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string category)
    {
        await using var command = new NpgsqlCommand("""
            SELECT productivity_bonus_percent, specialization
            FROM production.companies
            WHERE company_id = @company_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return 0;
        }

        return reader.GetInt32(0) + GetSpecializationBonusPercent(reader.GetString(1), category);
    }

    private static int ApplyProductivityBonus(int baseQuantity, int productivityBonusPercent)
    {
        if (baseQuantity <= 0 || productivityBonusPercent <= 0)
        {
            return baseQuantity;
        }

        return Math.Max(baseQuantity + 1, (baseQuantity * (100 + productivityBonusPercent) + 99) / 100);
    }

    private static CompanyPermissionsDto CreateCompanyPermissions(string? role)
    {
        return role switch
        {
            "owner" => new CompanyPermissionsDto(
                CanManageMembers: true,
                CanManageRoles: true,
                CanManageProduction: true,
                CanManageWorkforce: true,
                CanManageUpgrades: true,
                CanManageSpecialization: true),
            "manager" => new CompanyPermissionsDto(
                CanManageMembers: false,
                CanManageRoles: false,
                CanManageProduction: true,
                CanManageWorkforce: true,
                CanManageUpgrades: true,
                CanManageSpecialization: true),
            _ => new CompanyPermissionsDto(
                CanManageMembers: false,
                CanManageRoles: false,
                CanManageProduction: false,
                CanManageWorkforce: false,
                CanManageUpgrades: false,
                CanManageSpecialization: false)
        };
    }

    private static CompanySpecializationOptionDto[] CreateSpecializationOptions(string selectedSpecialization)
    {
        return
        [
            new CompanySpecializationOptionDto(
                Specialization: "general",
                Name: "General industry",
                Description: "No focused category bonus. Best for balanced companies.",
                AffectedCategory: "All",
                ProductivityBonusPercent: 0,
                IsSelected: selectedSpecialization == "general",
                GoldCost: CompanySpecializationGoldCost,
                RequiredItemId: LaborCreditItemId,
                RequiredItemName: "Labor Credit",
                RequiredItemQuantity: CompanySpecializationLaborCreditCost),
            new CompanySpecializationOptionDto(
                Specialization: "food",
                Name: "Food consortium",
                Description: "Adds a 10% productivity bonus to company Food factories.",
                AffectedCategory: "Food",
                ProductivityBonusPercent: 10,
                IsSelected: selectedSpecialization == "food",
                GoldCost: CompanySpecializationGoldCost,
                RequiredItemId: LaborCreditItemId,
                RequiredItemName: "Labor Credit",
                RequiredItemQuantity: CompanySpecializationLaborCreditCost),
            new CompanySpecializationOptionDto(
                Specialization: "weapon",
                Name: "Arms manufacturer",
                Description: "Adds a 10% productivity bonus to company Weapon factories.",
                AffectedCategory: "Weapon",
                ProductivityBonusPercent: 10,
                IsSelected: selectedSpecialization == "weapon",
                GoldCost: CompanySpecializationGoldCost,
                RequiredItemId: LaborCreditItemId,
                RequiredItemName: "Labor Credit",
                RequiredItemQuantity: CompanySpecializationLaborCreditCost),
            new CompanySpecializationOptionDto(
                Specialization: "logistics",
                Name: "Logistics office",
                Description: "Adds a 10% productivity bonus to workforce labor credits.",
                AffectedCategory: "Productivity",
                ProductivityBonusPercent: 10,
                IsSelected: selectedSpecialization == "logistics",
                GoldCost: CompanySpecializationGoldCost,
                RequiredItemId: LaborCreditItemId,
                RequiredItemName: "Labor Credit",
                RequiredItemQuantity: CompanySpecializationLaborCreditCost)
        ];
    }

    private static int GetSpecializationBonusPercent(string specialization, string category)
    {
        return specialization switch
        {
            "food" when string.Equals(category, "Food", StringComparison.OrdinalIgnoreCase) => 10,
            "weapon" when string.Equals(category, "Weapon", StringComparison.OrdinalIgnoreCase) => 10,
            "logistics" when string.Equals(category, "Productivity", StringComparison.OrdinalIgnoreCase) => 10,
            _ => 0
        };
    }

    private static string? NormalizeCompanySpecialization(string? specialization)
    {
        var normalized = NormalizeId(specialization);
        return normalized is "general" or "food" or "weapon" or "logistics"
            ? normalized
            : null;
    }

    private static async Task RecordCompanyUpgradeEventAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId,
        string companyId,
        string actorPlayerId,
        string upgradeType,
        int fromLevel,
        int toLevel,
        int goldCost,
        string itemId,
        int itemQuantity,
        string specialization,
        string description,
        DateTimeOffset createdAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO production.company_upgrade_events (
                event_id, company_id, actor_player_id, upgrade_type, from_level,
                to_level, gold_cost, item_id, item_quantity, specialization,
                description, created_at
            )
            VALUES (
                @event_id, @company_id, @actor_player_id, @upgrade_type, @from_level,
                @to_level, @gold_cost, @item_id, @item_quantity, @specialization,
                @description, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId);
        command.Parameters.AddWithValue("upgrade_type", upgradeType);
        command.Parameters.AddWithValue("from_level", fromLevel);
        command.Parameters.AddWithValue("to_level", toLevel);
        command.Parameters.AddWithValue("gold_cost", goldCost);
        command.Parameters.AddWithValue("item_id", itemId);
        command.Parameters.AddWithValue("item_quantity", itemQuantity);
        command.Parameters.AddWithValue("specialization", specialization);
        command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync();
    }

    private sealed record CompanyUpgradeSnapshot(
        int WalletGold,
        int StorageUsed,
        int StorageLimit,
        int HqLevel,
        string Specialization,
        int FactorySlots,
        int ProductivityBonusPercent,
        DateTimeOffset UpdatedAt);
}

internal sealed record CompanySpecializationRequest(string? ActorPlayerId, string? Specialization);

internal sealed record CompanyPermissionsDto(
    bool CanManageMembers,
    bool CanManageRoles,
    bool CanManageProduction,
    bool CanManageWorkforce,
    bool CanManageUpgrades,
    bool CanManageSpecialization);

internal sealed record CompanyUpgradeStateDto(
    string CompanyId,
    int HqLevel,
    string Specialization,
    int FactorySlots,
    int UsedFactorySlots,
    int AvailableFactorySlots,
    int StorageUsed,
    int StorageLimit,
    int ProductivityBonusPercent,
    CompanyUpgradeQuoteDto NextHqUpgrade,
    CompanySpecializationOptionDto[] SpecializationOptions,
    bool CanManageUpgrades,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyUpgradeQuoteDto(
    string UpgradeType,
    int CurrentLevel,
    int NextLevel,
    int GoldCost,
    string RequiredItemId,
    string RequiredItemName,
    int RequiredItemQuantity,
    int AvailableGold,
    int AvailableItemQuantity,
    int StorageLimitAfterUpgrade,
    int FactorySlotsAfterUpgrade,
    int ProductivityBonusPercentAfterUpgrade,
    bool CanUpgrade,
    string Message);

internal sealed record CompanySpecializationOptionDto(
    string Specialization,
    string Name,
    string Description,
    string AffectedCategory,
    int ProductivityBonusPercent,
    bool IsSelected,
    int GoldCost,
    string RequiredItemId,
    string RequiredItemName,
    int RequiredItemQuantity);

internal sealed record CompanyUpgradeMutationResponse(
    bool Completed,
    string Message,
    CompanyUpgradeStateDto Upgrades,
    CompanyDetailDto? Company);

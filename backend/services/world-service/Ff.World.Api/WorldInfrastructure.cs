using Npgsql;

internal static class WorldInfrastructureEndpoints
{
    public static void MapInfrastructureEndpoints(this WebApplication app)
    {
        app.MapGet("/countries/{countryId}/infrastructure-projects", async (
            string countryId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var token = tokens.Validate(request.Headers.Authorization.ToString());
            if (!token.IsValid)
            {
                return Results.Json(
                    new ErrorResponse("A valid bearer token is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var projects = await world.GetCountryInfrastructureAsync(countryId, token.PlayerId);
            return projects is null
                ? Results.NotFound(new ErrorResponse("Country was not found."))
                : Results.Ok(projects);
        }).WithName("GetCountryInfrastructureProjects");

        app.MapPost("/countries/{countryId}/infrastructure-projects/{projectId}/contribute", async (
            string countryId,
            string projectId,
            CountryInfrastructureContributionRequest contributionRequest,
            HttpRequest request,
            WorldStore world,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(request, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            if (string.IsNullOrWhiteSpace(projectId) ||
                string.IsNullOrWhiteSpace(contributionRequest.PlayerId) ||
                string.IsNullOrWhiteSpace(contributionRequest.IdempotencyKey) ||
                contributionRequest.GoldAmount < 0 ||
                contributionRequest.ItemQuantity < 0 ||
                (contributionRequest.GoldAmount == 0 && contributionRequest.ItemQuantity == 0))
            {
                return Results.BadRequest(new ErrorResponse(
                    "Project, player, positive contribution, and idempotency key are required."));
            }

            var result = await world.ContributeCountryInfrastructureAsync(
                countryId,
                projectId,
                contributionRequest);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Country or infrastructure project was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(new ErrorResponse(result.Message), statusCode: result.StatusCode);
        }).WithName("ContributeCountryInfrastructureProject");

        app.MapGet("/internal/players/{playerId}/infrastructure-bonuses", async (
            string playerId,
            HttpRequest request,
            WorldStore world,
            IConfiguration configuration) =>
        {
            if (!HasValidInternalToken(request, configuration))
            {
                return Results.Json(
                    new ErrorResponse("Internal service authorization is required."),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var bonuses = await world.GetPlayerInfrastructureBonusesAsync(playerId);
            return bonuses is null
                ? Results.NotFound(new ErrorResponse("Player does not have active country infrastructure bonuses."))
                : Results.Ok(bonuses);
        }).WithName("GetInternalPlayerInfrastructureBonuses");
    }

    private static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
    {
        var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
        return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
            string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
    }
}

internal sealed partial class WorldStore
{
    private static readonly InfrastructureProjectTemplate[] InfrastructureTemplates =
    [
        new(
            Type: "hospital-network",
            Name: "Hospital Network",
            Description: "Public clinics and field hospitals increase national recovery support.",
            TargetGold: 1_000,
            TargetItemId: "food",
            TargetItemName: "Food",
            TargetItemCategory: "food",
            TargetItemQuantity: 80,
            BonusType: "hospital_recovery",
            BonusPercentPerLevel: 5,
            DisplayOrder: 10),
        new(
            Type: "training-academy",
            Name: "Training Academy",
            Description: "Drill yards and instructors improve country-wide training readiness.",
            TargetGold: 1_200,
            TargetItemId: "weapon",
            TargetItemName: "Weapon",
            TargetItemCategory: "weapon",
            TargetItemQuantity: 40,
            BonusType: "training_readiness",
            BonusPercentPerLevel: 3,
            DisplayOrder: 20),
        new(
            Type: "logistics-roads",
            Name: "Logistics Roads",
            Description: "Roads and depots strengthen resource movement and production logistics.",
            TargetGold: 1_500,
            TargetItemId: "raw_materials",
            TargetItemName: "Raw materials",
            TargetItemCategory: "resource",
            TargetItemQuantity: 100,
            BonusType: "logistics_efficiency",
            BonusPercentPerLevel: 4,
            DisplayOrder: 30),
        new(
            Type: "border-forts",
            Name: "Border Forts",
            Description: "Fortifications improve national defense planning and front readiness.",
            TargetGold: 1_800,
            TargetItemId: "weapon",
            TargetItemName: "Weapon",
            TargetItemCategory: "weapon",
            TargetItemQuantity: 60,
            BonusType: "defense_readiness",
            BonusPercentPerLevel: 4,
            DisplayOrder: 40),
        new(
            Type: "research-labs",
            Name: "Research Labs",
            Description: "Laboratories support technology projects and long-term country bonuses.",
            TargetGold: 2_000,
            TargetItemId: "raw_materials",
            TargetItemName: "Raw materials",
            TargetItemCategory: "resource",
            TargetItemQuantity: 120,
            BonusType: "research_output",
            BonusPercentPerLevel: 3,
            DisplayOrder: 50)
    ];

    private async Task InitializeInfrastructureSchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.country_infrastructure_projects (
                project_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                project_type text NOT NULL,
                name text NOT NULL,
                description text NOT NULL,
                level integer NOT NULL DEFAULT 0,
                target_gold integer NOT NULL,
                contributed_gold integer NOT NULL DEFAULT 0,
                target_item_id text NOT NULL,
                target_item_name text NOT NULL,
                target_item_category text NOT NULL,
                target_item_quantity integer NOT NULL,
                contributed_item_quantity integer NOT NULL DEFAULT 0,
                bonus_type text NOT NULL,
                bonus_percent_per_level integer NOT NULL,
                display_order integer NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                UNIQUE (country_id, project_type)
            );

            CREATE INDEX IF NOT EXISTS ix_world_country_infrastructure_projects_country_order
                ON world.country_infrastructure_projects (country_id, display_order);

            CREATE TABLE IF NOT EXISTS world.country_infrastructure_contributions (
                contribution_id text PRIMARY KEY,
                project_id text NOT NULL REFERENCES world.country_infrastructure_projects(project_id) ON DELETE CASCADE,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                gold_amount integer NOT NULL,
                item_id text NOT NULL,
                item_name text NOT NULL,
                item_category text NOT NULL,
                item_quantity integer NOT NULL,
                levels_completed integer NOT NULL DEFAULT 0,
                idempotency_key text NOT NULL,
                created_at timestamptz NOT NULL,
                UNIQUE (project_id, idempotency_key)
            );

            CREATE INDEX IF NOT EXISTS ix_world_country_infrastructure_contributions_country_created
                ON world.country_infrastructure_contributions (country_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    private async Task SeedInfrastructureAsync()
    {
        await InitializeInfrastructureSchemaAsync();

        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        foreach (var country in WorldCatalog.Countries)
        {
            foreach (var template in InfrastructureTemplates)
            {
                await using var command = new NpgsqlCommand("""
                    INSERT INTO world.country_infrastructure_projects (
                        project_id, country_id, project_type, name, description,
                        target_gold, target_item_id, target_item_name, target_item_category,
                        target_item_quantity, bonus_type, bonus_percent_per_level,
                        display_order, created_at, updated_at
                    )
                    VALUES (
                        @project_id, @country_id, @project_type, @name, @description,
                        @target_gold, @target_item_id, @target_item_name, @target_item_category,
                        @target_item_quantity, @bonus_type, @bonus_percent_per_level,
                        @display_order, @created_at, @updated_at
                    )
                    ON CONFLICT (country_id, project_type) DO UPDATE
                    SET name = EXCLUDED.name,
                        description = EXCLUDED.description,
                        target_item_name = EXCLUDED.target_item_name,
                        target_item_category = EXCLUDED.target_item_category,
                        bonus_type = EXCLUDED.bonus_type,
                        bonus_percent_per_level = EXCLUDED.bonus_percent_per_level,
                        display_order = EXCLUDED.display_order,
                        updated_at = EXCLUDED.updated_at;
                    """, connection);
                command.Parameters.AddWithValue("project_id", $"{country.CountryId}-{template.Type}");
                command.Parameters.AddWithValue("country_id", country.CountryId);
                command.Parameters.AddWithValue("project_type", template.Type);
                command.Parameters.AddWithValue("name", template.Name);
                command.Parameters.AddWithValue("description", template.Description);
                command.Parameters.AddWithValue("target_gold", template.TargetGold);
                command.Parameters.AddWithValue("target_item_id", template.TargetItemId);
                command.Parameters.AddWithValue("target_item_name", template.TargetItemName);
                command.Parameters.AddWithValue("target_item_category", template.TargetItemCategory);
                command.Parameters.AddWithValue("target_item_quantity", template.TargetItemQuantity);
                command.Parameters.AddWithValue("bonus_type", template.BonusType);
                command.Parameters.AddWithValue("bonus_percent_per_level", template.BonusPercentPerLevel);
                command.Parameters.AddWithValue("display_order", template.DisplayOrder);
                command.Parameters.AddWithValue("created_at", now);
                command.Parameters.AddWithValue("updated_at", now);
                await command.ExecuteNonQueryAsync();
            }
        }
    }

    public async Task<CountryInfrastructureResponse?> GetCountryInfrastructureAsync(
        string countryId,
        string? viewerPlayerId,
        int contributionLimit = 10)
    {
        var normalizedCountryId = NormalizeId(countryId);
        await using var connection = await _dataSource.OpenConnectionAsync();

        var country = await ReadInfrastructureCountryAsync(connection, null, normalizedCountryId);
        if (country is null)
        {
            return null;
        }

        var projects = await ReadInfrastructureProjectsAsync(connection, null, normalizedCountryId);
        var contributions = await ReadRecentInfrastructureContributionsAsync(
            connection,
            null,
            normalizedCountryId,
            Math.Clamp(contributionLimit, 1, 50));
        var citizenship = string.IsNullOrWhiteSpace(viewerPlayerId)
            ? null
            : await ReadInfrastructureCitizenshipAsync(
                connection,
                null,
                normalizedCountryId,
                NormalizePlayerId(viewerPlayerId));

        return new CountryInfrastructureResponse(
            CountryId: country.CountryId,
            Name: country.Name,
            Code: country.Code,
            Projects: projects.ToArray(),
            RecentContributions: contributions.ToArray(),
            CanContribute: citizenship is not null,
            ContributionMessage: citizenship is null
                ? "Only active citizens can fund country infrastructure."
                : "Your citizenship allows infrastructure contributions.",
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<CountryInfrastructureContributionResult?> ContributeCountryInfrastructureAsync(
        string countryId,
        string projectId,
        CountryInfrastructureContributionRequest request)
    {
        var normalizedCountryId = NormalizeId(countryId);
        var normalizedProjectId = NormalizeId(projectId);
        var normalizedPlayerId = NormalizePlayerId(request.PlayerId);
        var idempotencyKey = request.IdempotencyKey.Trim().ToLowerInvariant();
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var country = await ReadInfrastructureCountryAsync(connection, transaction, normalizedCountryId);
        if (country is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var citizenship = await ReadInfrastructureCitizenshipAsync(
            connection,
            transaction,
            normalizedCountryId,
            normalizedPlayerId);
        if (citizenship is null)
        {
            await transaction.RollbackAsync();
            return CountryInfrastructureContributionResult.Failed(
                "Only active citizens can fund this country's infrastructure.",
                StatusCodes.Status403Forbidden);
        }

        var project = await ReadInfrastructureProjectForUpdateAsync(
            connection,
            transaction,
            normalizedCountryId,
            normalizedProjectId);
        if (project is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var existingContribution = await ReadInfrastructureContributionByIdempotencyAsync(
            connection,
            transaction,
            normalizedProjectId,
            idempotencyKey);
        if (existingContribution is not null)
        {
            var response = await BuildInfrastructureResponseAsync(
                connection,
                transaction,
                country,
                normalizedCountryId,
                normalizedPlayerId);
            await transaction.CommitAsync();
            return new CountryInfrastructureContributionResult(
                Completed: true,
                Message: "Infrastructure contribution was already recorded.",
                Project: response.Projects.First(candidate => candidate.ProjectId == normalizedProjectId),
                Contribution: existingContribution,
                Infrastructure: response,
                StatusCode: StatusCodes.Status200OK);
        }

        var itemQuantity = request.ItemQuantity;
        var itemId = itemQuantity > 0
            ? NormalizeId(request.ItemId ?? project.TargetItemId)
            : string.Empty;
        var itemName = itemQuantity > 0
            ? (string.IsNullOrWhiteSpace(request.ItemName) ? project.TargetItemName : request.ItemName.Trim())
            : string.Empty;
        var itemCategory = itemQuantity > 0
            ? (string.IsNullOrWhiteSpace(request.ItemCategory) ? project.TargetItemCategory : request.ItemCategory.Trim().ToLowerInvariant())
            : string.Empty;

        if (itemQuantity > 0 &&
            (!string.Equals(itemId, project.TargetItemId, StringComparison.OrdinalIgnoreCase) ||
             !string.Equals(itemCategory, project.TargetItemCategory, StringComparison.OrdinalIgnoreCase)))
        {
            await transaction.RollbackAsync();
            return CountryInfrastructureContributionResult.Failed(
                $"{project.Name} needs {project.TargetItemName} contributions.",
                StatusCodes.Status400BadRequest);
        }

        var goldAmount = Math.Max(0, request.GoldAmount);
        var now = DateTimeOffset.UtcNow;
        var contributionId = StableInfrastructureId("infra", normalizedPlayerId, normalizedProjectId, idempotencyKey);
        var contribution = await AddInfrastructureContributionAsync(
            connection,
            transaction,
            contributionId,
            normalizedProjectId,
            normalizedCountryId,
            normalizedPlayerId,
            goldAmount,
            itemId,
            itemName,
            itemCategory,
            itemQuantity,
            idempotencyKey,
            now);

        var updatedProject = CompleteInfrastructureLevels(
            project,
            goldAmount,
            itemQuantity,
            out var levelsCompleted);

        await UpdateInfrastructureProjectAsync(connection, transaction, updatedProject, now);
        contribution = contribution with { LevelsCompleted = levelsCompleted };
        await UpdateInfrastructureContributionLevelsAsync(
            connection,
            transaction,
            contribution.ContributionId,
            levelsCompleted);

        if (goldAmount > 0)
        {
            await AddCountryTreasuryAsync(connection, transaction, normalizedCountryId, goldAmount, now);
            await AddTreasuryLedgerAsync(
                connection,
                transaction,
                normalizedCountryId,
                new CountryTaxCollectionRequest(
                    Amount: goldAmount,
                    GrossAmount: goldAmount,
                    TaxRate: 0,
                    EntryType: "infrastructure_contribution",
                    SourcePlayerId: normalizedPlayerId,
                    CounterpartyPlayerId: null,
                    Description: $"{project.Name} infrastructure contribution.",
                    IdempotencyKey: $"treasury:infrastructure:{idempotencyKey}",
                    LedgerId: $"infra-{contributionId}"),
                $"treasury:infrastructure:{idempotencyKey}",
                now);
        }

        var infrastructure = await BuildInfrastructureResponseAsync(
            connection,
            transaction,
            country,
            normalizedCountryId,
            normalizedPlayerId);
        await transaction.CommitAsync();

        var completedProject = infrastructure.Projects.First(candidate =>
            string.Equals(candidate.ProjectId, normalizedProjectId, StringComparison.Ordinal));
        var message = levelsCompleted > 0
            ? $"{project.Name} advanced by {levelsCompleted} level(s)."
            : $"Contributed to {project.Name}.";
        return new CountryInfrastructureContributionResult(
            Completed: true,
            Message: message,
            Project: completedProject,
            Contribution: contribution,
            Infrastructure: infrastructure,
            StatusCode: StatusCodes.Status200OK);
    }

    public async Task<CountryInfrastructureBonuses?> GetPlayerInfrastructureBonusesAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var citizenship = new NpgsqlCommand("""
            SELECT country_id
            FROM world.player_citizenships
            WHERE player_id = @player_id
              AND status = 'active';
            """, connection);
        citizenship.Parameters.AddWithValue("player_id", normalizedPlayerId);
        var countryId = await citizenship.ExecuteScalarAsync() as string;
        if (string.IsNullOrWhiteSpace(countryId))
        {
            return null;
        }

        var bonuses = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        await using var command = new NpgsqlCommand("""
            SELECT bonus_type, COALESCE(SUM(level * bonus_percent_per_level), 0)::integer
            FROM world.country_infrastructure_projects
            WHERE country_id = @country_id
            GROUP BY bonus_type;
            """, connection);
        command.Parameters.AddWithValue("country_id", countryId);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            bonuses[reader.GetString(0)] = reader.GetInt32(1);
        }

        return new CountryInfrastructureBonuses(
            CountryId: countryId,
            HospitalRecoveryPercent: bonuses.GetValueOrDefault("hospital_recovery"),
            TrainingReadinessPercent: bonuses.GetValueOrDefault("training_readiness"),
            LogisticsEfficiencyPercent: bonuses.GetValueOrDefault("logistics_efficiency"),
            DefenseReadinessPercent: bonuses.GetValueOrDefault("defense_readiness"),
            ResearchOutputPercent: bonuses.GetValueOrDefault("research_output"),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    private static InfrastructureProjectState CompleteInfrastructureLevels(
        InfrastructureProjectState project,
        int goldAmount,
        int itemQuantity,
        out int levelsCompleted)
    {
        var level = project.Level;
        var contributedGold = project.ContributedGold + goldAmount;
        var contributedItems = project.ContributedItemQuantity + itemQuantity;
        var targetGold = project.TargetGold;
        var targetItems = project.TargetItemQuantity;
        levelsCompleted = 0;

        while (contributedGold >= targetGold &&
               (targetItems <= 0 || contributedItems >= targetItems))
        {
            contributedGold -= targetGold;
            if (targetItems > 0)
            {
                contributedItems -= targetItems;
            }

            level++;
            levelsCompleted++;
            targetGold = ScaleInfrastructureTarget(targetGold);
            targetItems = targetItems <= 0 ? 0 : ScaleInfrastructureTarget(targetItems);
        }

        return project with
        {
            Level = level,
            TargetGold = targetGold,
            ContributedGold = contributedGold,
            TargetItemQuantity = targetItems,
            ContributedItemQuantity = contributedItems
        };
    }

    private static int ScaleInfrastructureTarget(int value)
    {
        return Math.Max(value + 1, (int)Math.Ceiling(value * 1.35));
    }

    private static async Task<CountryInfrastructureResponse> BuildInfrastructureResponseAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        InfrastructureCountry country,
        string countryId,
        string playerId)
    {
        var projects = await ReadInfrastructureProjectsAsync(connection, transaction, countryId);
        var contributions = await ReadRecentInfrastructureContributionsAsync(connection, transaction, countryId, 10);
        return new CountryInfrastructureResponse(
            CountryId: country.CountryId,
            Name: country.Name,
            Code: country.Code,
            Projects: projects.ToArray(),
            RecentContributions: contributions.ToArray(),
            CanContribute: true,
            ContributionMessage: "Your citizenship allows infrastructure contributions.",
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    private static async Task<InfrastructureCountry?> ReadInfrastructureCountryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT country_id, name, code
            FROM world.countries
            WHERE country_id = @country_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new InfrastructureCountry(reader.GetString(0), reader.GetString(1), reader.GetString(2))
            : null;
    }

    private static async Task<string?> ReadInfrastructureCitizenshipAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT status
            FROM world.player_citizenships
            WHERE country_id = @country_id
              AND player_id = @player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("player_id", playerId);
        var status = await command.ExecuteScalarAsync() as string;
        return string.Equals(status, "active", StringComparison.OrdinalIgnoreCase) ? status : null;
    }

    private static async Task<List<CountryInfrastructureProjectDto>> ReadInfrastructureProjectsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT project_id, country_id, project_type, name, description, level,
                   target_gold, contributed_gold, target_item_id, target_item_name,
                   target_item_category, target_item_quantity, contributed_item_quantity,
                   bonus_type, bonus_percent_per_level, display_order, updated_at
            FROM world.country_infrastructure_projects
            WHERE country_id = @country_id
            ORDER BY display_order, project_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);

        var projects = new List<CountryInfrastructureProjectDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            projects.Add(ReadInfrastructureProject(reader));
        }

        return projects;
    }

    private static async Task<InfrastructureProjectState?> ReadInfrastructureProjectForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId,
        string projectId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT project_id, country_id, project_type, name, description, level,
                   target_gold, contributed_gold, target_item_id, target_item_name,
                   target_item_category, target_item_quantity, contributed_item_quantity,
                   bonus_type, bonus_percent_per_level, display_order, updated_at
            FROM world.country_infrastructure_projects
            WHERE country_id = @country_id
              AND project_id = @project_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("project_id", projectId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadInfrastructureProjectState(reader) : null;
    }

    private static async Task UpdateInfrastructureProjectAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        InfrastructureProjectState project,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.country_infrastructure_projects
            SET level = @level,
                target_gold = @target_gold,
                contributed_gold = @contributed_gold,
                target_item_quantity = @target_item_quantity,
                contributed_item_quantity = @contributed_item_quantity,
                updated_at = @updated_at
            WHERE project_id = @project_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("project_id", project.ProjectId);
        command.Parameters.AddWithValue("level", project.Level);
        command.Parameters.AddWithValue("target_gold", project.TargetGold);
        command.Parameters.AddWithValue("contributed_gold", project.ContributedGold);
        command.Parameters.AddWithValue("target_item_quantity", project.TargetItemQuantity);
        command.Parameters.AddWithValue("contributed_item_quantity", project.ContributedItemQuantity);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<CountryInfrastructureContributionDto> AddInfrastructureContributionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string contributionId,
        string projectId,
        string countryId,
        string playerId,
        int goldAmount,
        string itemId,
        string itemName,
        string itemCategory,
        int itemQuantity,
        string idempotencyKey,
        DateTimeOffset createdAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.country_infrastructure_contributions (
                contribution_id, project_id, country_id, player_id, gold_amount,
                item_id, item_name, item_category, item_quantity, idempotency_key, created_at
            )
            VALUES (
                @contribution_id, @project_id, @country_id, @player_id, @gold_amount,
                @item_id, @item_name, @item_category, @item_quantity, @idempotency_key, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("contribution_id", contributionId);
        command.Parameters.AddWithValue("project_id", projectId);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("gold_amount", goldAmount);
        command.Parameters.AddWithValue("item_id", itemId);
        command.Parameters.AddWithValue("item_name", itemName);
        command.Parameters.AddWithValue("item_category", itemCategory);
        command.Parameters.AddWithValue("item_quantity", itemQuantity);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync();

        return new CountryInfrastructureContributionDto(
            ContributionId: contributionId,
            ProjectId: projectId,
            CountryId: countryId,
            PlayerId: playerId,
            GoldAmount: goldAmount,
            ItemId: itemId,
            ItemName: itemName,
            ItemCategory: itemCategory,
            ItemQuantity: itemQuantity,
            LevelsCompleted: 0,
            CreatedAt: createdAt);
    }

    private static async Task UpdateInfrastructureContributionLevelsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string contributionId,
        int levelsCompleted)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.country_infrastructure_contributions
            SET levels_completed = @levels_completed
            WHERE contribution_id = @contribution_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("contribution_id", contributionId);
        command.Parameters.AddWithValue("levels_completed", levelsCompleted);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<CountryInfrastructureContributionDto?> ReadInfrastructureContributionByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string projectId,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT contribution_id, project_id, country_id, player_id, gold_amount,
                   item_id, item_name, item_category, item_quantity, levels_completed, created_at
            FROM world.country_infrastructure_contributions
            WHERE project_id = @project_id
              AND idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("project_id", projectId);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadInfrastructureContribution(reader) : null;
    }

    private static async Task<List<CountryInfrastructureContributionDto>> ReadRecentInfrastructureContributionsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT contribution_id, project_id, country_id, player_id, gold_amount,
                   item_id, item_name, item_category, item_quantity, levels_completed, created_at
            FROM world.country_infrastructure_contributions
            WHERE country_id = @country_id
            ORDER BY created_at DESC, contribution_id DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("limit", limit);

        var contributions = new List<CountryInfrastructureContributionDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            contributions.Add(ReadInfrastructureContribution(reader));
        }

        return contributions;
    }

    private static CountryInfrastructureProjectDto ReadInfrastructureProject(NpgsqlDataReader reader)
    {
        return new CountryInfrastructureProjectDto(
            ProjectId: reader.GetString(0),
            CountryId: reader.GetString(1),
            ProjectType: reader.GetString(2),
            Name: reader.GetString(3),
            Description: reader.GetString(4),
            Level: reader.GetInt32(5),
            TargetGold: reader.GetInt32(6),
            ContributedGold: reader.GetInt32(7),
            TargetItemId: reader.GetString(8),
            TargetItemName: reader.GetString(9),
            TargetItemCategory: reader.GetString(10),
            TargetItemQuantity: reader.GetInt32(11),
            ContributedItemQuantity: reader.GetInt32(12),
            BonusType: reader.GetString(13),
            BonusPercentPerLevel: reader.GetInt32(14),
            ActiveBonusPercent: reader.GetInt32(5) * reader.GetInt32(14),
            DisplayOrder: reader.GetInt32(15),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(16));
    }

    private static InfrastructureProjectState ReadInfrastructureProjectState(NpgsqlDataReader reader)
    {
        return new InfrastructureProjectState(
            ProjectId: reader.GetString(0),
            CountryId: reader.GetString(1),
            ProjectType: reader.GetString(2),
            Name: reader.GetString(3),
            Description: reader.GetString(4),
            Level: reader.GetInt32(5),
            TargetGold: reader.GetInt32(6),
            ContributedGold: reader.GetInt32(7),
            TargetItemId: reader.GetString(8),
            TargetItemName: reader.GetString(9),
            TargetItemCategory: reader.GetString(10),
            TargetItemQuantity: reader.GetInt32(11),
            ContributedItemQuantity: reader.GetInt32(12),
            BonusType: reader.GetString(13),
            BonusPercentPerLevel: reader.GetInt32(14),
            DisplayOrder: reader.GetInt32(15),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(16));
    }

    private static CountryInfrastructureContributionDto ReadInfrastructureContribution(NpgsqlDataReader reader)
    {
        return new CountryInfrastructureContributionDto(
            ContributionId: reader.GetString(0),
            ProjectId: reader.GetString(1),
            CountryId: reader.GetString(2),
            PlayerId: reader.GetString(3),
            GoldAmount: reader.GetInt32(4),
            ItemId: reader.GetString(5),
            ItemName: reader.GetString(6),
            ItemCategory: reader.GetString(7),
            ItemQuantity: reader.GetInt32(8),
            LevelsCompleted: reader.GetInt32(9),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(10));
    }

    private static string StableInfrastructureId(params string[] parts)
    {
        var raw = string.Join(':', parts.Select(part => part.Trim().ToLowerInvariant()));
        return Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(raw)))[..24].ToLowerInvariant();
    }
}

internal sealed record InfrastructureProjectTemplate(
    string Type,
    string Name,
    string Description,
    int TargetGold,
    string TargetItemId,
    string TargetItemName,
    string TargetItemCategory,
    int TargetItemQuantity,
    string BonusType,
    int BonusPercentPerLevel,
    int DisplayOrder);

internal sealed record InfrastructureCountry(string CountryId, string Name, string Code);

internal sealed record InfrastructureProjectState(
    string ProjectId,
    string CountryId,
    string ProjectType,
    string Name,
    string Description,
    int Level,
    int TargetGold,
    int ContributedGold,
    string TargetItemId,
    string TargetItemName,
    string TargetItemCategory,
    int TargetItemQuantity,
    int ContributedItemQuantity,
    string BonusType,
    int BonusPercentPerLevel,
    int DisplayOrder,
    DateTimeOffset UpdatedAt);

internal sealed record CountryInfrastructureResponse(
    string CountryId,
    string Name,
    string Code,
    CountryInfrastructureProjectDto[] Projects,
    CountryInfrastructureContributionDto[] RecentContributions,
    bool CanContribute,
    string ContributionMessage,
    DateTimeOffset UpdatedAt);

internal sealed record CountryInfrastructureProjectDto(
    string ProjectId,
    string CountryId,
    string ProjectType,
    string Name,
    string Description,
    int Level,
    int TargetGold,
    int ContributedGold,
    string TargetItemId,
    string TargetItemName,
    string TargetItemCategory,
    int TargetItemQuantity,
    int ContributedItemQuantity,
    string BonusType,
    int BonusPercentPerLevel,
    int ActiveBonusPercent,
    int DisplayOrder,
    DateTimeOffset UpdatedAt);

internal sealed record CountryInfrastructureContributionDto(
    string ContributionId,
    string ProjectId,
    string CountryId,
    string PlayerId,
    int GoldAmount,
    string ItemId,
    string ItemName,
    string ItemCategory,
    int ItemQuantity,
    int LevelsCompleted,
    DateTimeOffset CreatedAt);

internal sealed record CountryInfrastructureContributionRequest(
    string PlayerId,
    int GoldAmount,
    string? ItemId,
    string? ItemName,
    string? ItemCategory,
    int ItemQuantity,
    string IdempotencyKey);

internal sealed record CountryInfrastructureContributionResult(
    bool Completed,
    string Message,
    CountryInfrastructureProjectDto? Project,
    CountryInfrastructureContributionDto? Contribution,
    CountryInfrastructureResponse? Infrastructure,
    int StatusCode)
{
    public static CountryInfrastructureContributionResult Failed(string message, int statusCode)
    {
        return new CountryInfrastructureContributionResult(false, message, null, null, null, statusCode);
    }
}

internal sealed record CountryInfrastructureBonuses(
    string CountryId,
    int HospitalRecoveryPercent,
    int TrainingReadinessPercent,
    int LogisticsEfficiencyPercent,
    int DefenseReadinessPercent,
    int ResearchOutputPercent,
    DateTimeOffset UpdatedAt);

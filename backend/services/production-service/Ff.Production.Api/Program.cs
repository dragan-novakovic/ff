using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<ProductionStore>();

var metadata = new ServiceMetadata(
    Service: "production-service",
    DisplayName: "Production Service",
    Domain: "Factories, companies, production jobs, and formulas",
    Description: "Owns factory/company production workflows and coordinates resource consumption and output grants through economy boundaries.",
    Owns: ["factories", "company ownership", "production jobs", "upgrades", "production formulas"],
    Responsibilities: ["Start and track production jobs", "Coordinate input reservations", "Emit production completion events later"]);

var app = builder.Build();

var productionStore = app.Services.GetRequiredService<ProductionStore>();
await productionStore.InitializeAsync();
await productionStore.InitializeCompanyTradeAsync();
await productionStore.InitializeCompanyUpgradeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/players/{playerId}/factories", async (string playerId, ProductionStore production) =>
    Results.Ok(await production.GetFactoriesAsync(playerId))).WithName("GetFactories");

app.MapGet("/players/{playerId}/production-jobs", async (string playerId, ProductionStore production) =>
    Results.Ok(await production.GetProductionJobsAsync(playerId))).WithName("GetProductionJobs");

app.MapGet("/companies", async (string? actorPlayerId, ProductionStore production) =>
{
    if (string.IsNullOrWhiteSpace(actorPlayerId))
    {
        return Results.BadRequest(new ErrorResponse("Actor player id is required."));
    }

    return Results.Ok(await production.ListCompaniesAsync(actorPlayerId));
}).WithName("ListCompanies");

app.MapGet("/players/{playerId}/companies", async (string playerId, ProductionStore production) =>
    Results.Ok(await production.ListCompaniesAsync(playerId))).WithName("ListPlayerCompanies");

app.MapPost("/players/{playerId}/companies", async (
    string playerId,
    CreateCompanyRequest request,
    ProductionStore production) =>
{
    return ToStoreResult(await production.CreateCompanyAsync(playerId, request));
}).WithName("CreateCompany");

app.MapGet("/companies/{companyId}", async (
    string companyId,
    string? actorPlayerId,
    ProductionStore production) =>
{
    if (string.IsNullOrWhiteSpace(actorPlayerId))
    {
        return Results.BadRequest(new ErrorResponse("Actor player id is required."));
    }

    return ToStoreResult(await production.GetCompanyAsync(companyId, actorPlayerId));
}).WithName("GetCompany");

app.MapGet("/companies/{companyId}/members", async (
    string companyId,
    string? actorPlayerId,
    ProductionStore production) =>
{
    if (string.IsNullOrWhiteSpace(actorPlayerId))
    {
        return Results.BadRequest(new ErrorResponse("Actor player id is required."));
    }

    return ToStoreResult(await production.GetCompanyMembersAsync(companyId, actorPlayerId));
}).WithName("GetCompanyMembers");

app.MapGet("/companies/{companyId}/assets", async (
    string companyId,
    string? actorPlayerId,
    ProductionStore production) =>
{
    if (string.IsNullOrWhiteSpace(actorPlayerId))
    {
        return Results.BadRequest(new ErrorResponse("Actor player id is required."));
    }

    return ToStoreResult(await production.GetCompanyAssetsAsync(companyId, actorPlayerId));
}).WithName("GetCompanyAssets");

app.MapCompanyTradeAssetEndpoints();
app.MapCompanyUpgradeEndpoints();

app.MapPost("/companies/{companyId}/join", async (
    string companyId,
    CompanyActorRequest request,
    ProductionStore production) =>
{
    return ToStoreResult(await production.JoinCompanyAsync(companyId, request.ActorPlayerId));
}).WithName("JoinCompany");

app.MapPost("/companies/{companyId}/members/{targetPlayerId}/role", async (
    string companyId,
    string targetPlayerId,
    CompanyMemberRoleRequest request,
    ProductionStore production) =>
{
    return ToStoreResult(await production.UpdateCompanyMemberRoleAsync(
        companyId,
        request.ActorPlayerId,
        targetPlayerId,
        request.Role));
}).WithName("UpdateCompanyMemberRole");

app.MapPost("/companies/{companyId}/members/{targetPlayerId}/remove", async (
    string companyId,
    string targetPlayerId,
    CompanyActorRequest request,
    ProductionStore production) =>
{
    return ToStoreResult(await production.RemoveCompanyMemberAsync(
        companyId,
        request.ActorPlayerId,
        targetPlayerId));
}).WithName("RemoveCompanyMember");

app.MapPost("/companies/{companyId}/factories/{factoryId}/produce", async (
    string companyId,
    string factoryId,
    CompanyProductionStartRequest request,
    ProductionStore production) =>
{
    return ToStoreResult(await production.StartCompanyProductionAsync(
        companyId,
        factoryId,
        request));
}).WithName("StartCompanyProduction");

app.MapPost("/companies/{companyId}/production-jobs/{jobId}/claim", async (
    string companyId,
    string jobId,
    CompanyActorRequest request,
    ProductionStore production) =>
{
    return ToStoreResult(await production.ClaimCompanyProductionJobAsync(
        companyId,
        jobId,
        request.ActorPlayerId));
}).WithName("ClaimCompanyProductionJob");

app.MapCompanyWorkforceEndpoints();

app.MapGet("/players/{playerId}/factories/{factoryId}/upgrade-quote", async (
    string playerId,
    string factoryId,
    ProductionStore production) =>
{
    var quote = await production.GetUpgradeQuoteAsync(playerId, factoryId);
    return quote is null
        ? Results.NotFound(new ErrorResponse("Factory was not found."))
        : Results.Ok(quote);
}).WithName("GetFactoryUpgradeQuote");

app.MapPost("/players/{playerId}/factories/{factoryId}/upgrade", async (
    string playerId,
    string factoryId,
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

    var result = await production.UpgradeFactoryAsync(playerId, factoryId);
    return result is null
        ? Results.NotFound(new ErrorResponse("Factory was not found."))
        : Results.Ok(result);
}).WithName("UpgradeFactory");

app.MapPost("/players/{playerId}/factories/{factoryId}/produce", async (
    string playerId,
    string factoryId,
    ProductionStartRequest? request,
    ProductionStore production) =>
{
    return ToStoreResult(await production.StartProductionAsync(playerId, factoryId, request));
}).WithName("Produce");

app.MapPost("/players/{playerId}/production-jobs/{jobId}/claim/start", async (
    string playerId,
    string jobId,
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

    return ToStoreResult(await production.BeginClaimProductionJobAsync(playerId, jobId));
}).WithName("BeginClaimProductionJob");

app.MapPost("/players/{playerId}/production-jobs/{jobId}/claim/complete", async (
    string playerId,
    string jobId,
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

    return ToStoreResult(await production.CompleteClaimProductionJobAsync(playerId, jobId));
}).WithName("CompleteClaimProductionJob");

app.MapPost("/players/{playerId}/production-jobs/{jobId}/cancel", async (
    string playerId,
    string jobId,
    ProductionJobCancellationRequest request,
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

    return ToStoreResult(await production.CancelProductionJobAsync(playerId, jobId, request.Reason));
}).WithName("CancelProductionJob");

app.Run();

static IResult ToStoreResult<T>(StoreResult<T> result) where T : class
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

static bool HasValidInternalToken(HttpRequest request, IConfiguration configuration)
{
    var expectedToken = configuration["FF_INTERNAL_SERVICE_TOKEN"]
        ?? "ff-development-internal-token-change-me";
    return request.Headers.TryGetValue("X-FF-Internal-Token", out var actualToken) &&
        string.Equals(actualToken.ToString(), expectedToken, StringComparison.Ordinal);
}

internal sealed partial class ProductionStore : IDisposable
{
    private const int UpgradeBaseGoldCost = 100;
    private const int UpgradeOutputQuantityIncrease = 1;
    private const int BaseProductionDurationSeconds = 90;
    private const int MinimumProductionDurationSeconds = 30;
    private const int LevelDurationReductionSeconds = 10;
    private const int MaxProductionQueueDepth = 3;
    private const int CompanyInitialGold = 500;
    private const int CompanyStorageLimit = 200;
    private const int CompanyInitialHqLevel = 1;
    private const int CompanyInitialFactorySlots = 2;
    private const int CompanyInitialProductivityBonusPercent = 0;
    private const string CompanyDefaultSpecialization = "general";

    private readonly NpgsqlDataSource _dataSource;

    public ProductionStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_PRODUCTION_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Production")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS production;

            CREATE TABLE IF NOT EXISTS production.player_factories (
                player_id text NOT NULL,
                factory_id text NOT NULL,
                name text NOT NULL,
                category text NOT NULL,
                level integer NOT NULL,
                input_item_id text NOT NULL,
                input_quantity integer NOT NULL,
                output_item_id text NOT NULL,
                output_quantity integer NOT NULL,
                production_count integer NOT NULL,
                last_produced_at timestamptz NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, factory_id)
            );

            CREATE TABLE IF NOT EXISTS production.production_runs (
                run_id text PRIMARY KEY,
                player_id text NOT NULL,
                factory_id text NOT NULL,
                input_item_id text NOT NULL,
                input_quantity integer NOT NULL,
                output_item_id text NOT NULL,
                output_quantity integer NOT NULL,
                production_bonus_percent integer NOT NULL DEFAULT 0,
                bonus_source_region_id text NOT NULL DEFAULT '',
                bonus_source_region_name text NOT NULL DEFAULT '',
                bonus_resource_name text NOT NULL DEFAULT '',
                bonus_item_id text NOT NULL DEFAULT '',
                created_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS production.production_jobs (
                job_id text PRIMARY KEY,
                player_id text NOT NULL,
                factory_id text NOT NULL,
                status text NOT NULL,
                input_item_id text NOT NULL,
                input_item_name text NOT NULL,
                input_item_category text NOT NULL,
                input_quantity integer NOT NULL,
                output_item_id text NOT NULL,
                output_item_name text NOT NULL,
                output_item_category text NOT NULL,
                output_quantity integer NOT NULL,
                production_bonus_percent integer NOT NULL DEFAULT 0,
                bonus_source_region_id text NOT NULL DEFAULT '',
                bonus_source_region_name text NOT NULL DEFAULT '',
                bonus_resource_name text NOT NULL DEFAULT '',
                bonus_item_id text NOT NULL DEFAULT '',
                duration_seconds integer NOT NULL,
                started_at timestamptz NOT NULL,
                completes_at timestamptz NOT NULL,
                completed_at timestamptz NULL,
                claimed_at timestamptz NULL,
                cancellation_reason text NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT production_jobs_status_check
                    CHECK (status IN ('queued', 'running', 'completed', 'claiming', 'claimed', 'cancelled')),
                CONSTRAINT production_jobs_player_factory_fk
                    FOREIGN KEY (player_id, factory_id)
                    REFERENCES production.player_factories (player_id, factory_id)
            );

            CREATE TABLE IF NOT EXISTS production.companies (
                company_id text PRIMARY KEY,
                name text NOT NULL,
                name_key text NOT NULL UNIQUE,
                description text NOT NULL,
                owner_player_id text NOT NULL,
                wallet_gold integer NOT NULL,
                storage_limit integer NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT companies_wallet_gold_check CHECK (wallet_gold >= 0),
                CONSTRAINT companies_storage_limit_check CHECK (storage_limit > 0)
            );

            CREATE TABLE IF NOT EXISTS production.company_members (
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                role text NOT NULL,
                joined_at timestamptz NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (company_id, player_id),
                CONSTRAINT company_members_role_check CHECK (role IN ('owner', 'manager', 'member'))
            );

            CREATE TABLE IF NOT EXISTS production.company_factories (
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                factory_id text NOT NULL,
                name text NOT NULL,
                category text NOT NULL,
                level integer NOT NULL,
                input_item_id text NOT NULL,
                input_quantity integer NOT NULL,
                output_item_id text NOT NULL,
                output_quantity integer NOT NULL,
                production_count integer NOT NULL,
                last_produced_at timestamptz NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (company_id, factory_id)
            );

            CREATE TABLE IF NOT EXISTS production.company_inventory (
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                item_id text NOT NULL,
                name text NOT NULL,
                category text NOT NULL,
                quantity integer NOT NULL,
                description text NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (company_id, item_id),
                CONSTRAINT company_inventory_quantity_check CHECK (quantity > 0)
            );

            CREATE TABLE IF NOT EXISTS production.company_production_jobs (
                job_id text PRIMARY KEY,
                company_id text NOT NULL,
                factory_id text NOT NULL,
                requested_by_player_id text NOT NULL,
                status text NOT NULL,
                input_item_id text NOT NULL,
                input_item_name text NOT NULL,
                input_item_category text NOT NULL,
                input_quantity integer NOT NULL,
                output_item_id text NOT NULL,
                output_item_name text NOT NULL,
                output_item_category text NOT NULL,
                output_quantity integer NOT NULL,
                production_bonus_percent integer NOT NULL DEFAULT 0,
                bonus_source_region_id text NOT NULL DEFAULT '',
                bonus_source_region_name text NOT NULL DEFAULT '',
                bonus_resource_name text NOT NULL DEFAULT '',
                bonus_item_id text NOT NULL DEFAULT '',
                duration_seconds integer NOT NULL,
                started_at timestamptz NOT NULL,
                completes_at timestamptz NOT NULL,
                completed_at timestamptz NULL,
                claimed_at timestamptz NULL,
                cancellation_reason text NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT company_production_jobs_status_check
                    CHECK (status IN ('queued', 'running', 'completed', 'claiming', 'claimed', 'cancelled')),
                CONSTRAINT company_production_jobs_factory_fk
                    FOREIGN KEY (company_id, factory_id)
                    REFERENCES production.company_factories (company_id, factory_id)
                    ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS production.company_production_runs (
                run_id text PRIMARY KEY,
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                factory_id text NOT NULL,
                job_id text NOT NULL,
                input_item_id text NOT NULL,
                input_quantity integer NOT NULL,
                output_item_id text NOT NULL,
                output_quantity integer NOT NULL,
                production_bonus_percent integer NOT NULL DEFAULT 0,
                bonus_source_region_id text NOT NULL DEFAULT '',
                bonus_source_region_name text NOT NULL DEFAULT '',
                bonus_resource_name text NOT NULL DEFAULT '',
                bonus_item_id text NOT NULL DEFAULT '',
                created_at timestamptz NOT NULL
            );

            ALTER TABLE production.production_runs
                ADD COLUMN IF NOT EXISTS production_bonus_percent integer NOT NULL DEFAULT 0;
            ALTER TABLE production.production_runs
                ADD COLUMN IF NOT EXISTS bonus_source_region_id text NOT NULL DEFAULT '';
            ALTER TABLE production.production_runs
                ADD COLUMN IF NOT EXISTS bonus_source_region_name text NOT NULL DEFAULT '';
            ALTER TABLE production.production_runs
                ADD COLUMN IF NOT EXISTS bonus_resource_name text NOT NULL DEFAULT '';
            ALTER TABLE production.production_runs
                ADD COLUMN IF NOT EXISTS bonus_item_id text NOT NULL DEFAULT '';

            ALTER TABLE production.production_jobs
                ADD COLUMN IF NOT EXISTS production_bonus_percent integer NOT NULL DEFAULT 0;
            ALTER TABLE production.production_jobs
                ADD COLUMN IF NOT EXISTS bonus_source_region_id text NOT NULL DEFAULT '';
            ALTER TABLE production.production_jobs
                ADD COLUMN IF NOT EXISTS bonus_source_region_name text NOT NULL DEFAULT '';
            ALTER TABLE production.production_jobs
                ADD COLUMN IF NOT EXISTS bonus_resource_name text NOT NULL DEFAULT '';
            ALTER TABLE production.production_jobs
                ADD COLUMN IF NOT EXISTS bonus_item_id text NOT NULL DEFAULT '';

            ALTER TABLE production.company_production_jobs
                ADD COLUMN IF NOT EXISTS production_bonus_percent integer NOT NULL DEFAULT 0;
            ALTER TABLE production.company_production_jobs
                ADD COLUMN IF NOT EXISTS bonus_source_region_id text NOT NULL DEFAULT '';
            ALTER TABLE production.company_production_jobs
                ADD COLUMN IF NOT EXISTS bonus_source_region_name text NOT NULL DEFAULT '';
            ALTER TABLE production.company_production_jobs
                ADD COLUMN IF NOT EXISTS bonus_resource_name text NOT NULL DEFAULT '';
            ALTER TABLE production.company_production_jobs
                ADD COLUMN IF NOT EXISTS bonus_item_id text NOT NULL DEFAULT '';

            ALTER TABLE production.company_production_runs
                ADD COLUMN IF NOT EXISTS production_bonus_percent integer NOT NULL DEFAULT 0;
            ALTER TABLE production.company_production_runs
                ADD COLUMN IF NOT EXISTS bonus_source_region_id text NOT NULL DEFAULT '';
            ALTER TABLE production.company_production_runs
                ADD COLUMN IF NOT EXISTS bonus_source_region_name text NOT NULL DEFAULT '';
            ALTER TABLE production.company_production_runs
                ADD COLUMN IF NOT EXISTS bonus_resource_name text NOT NULL DEFAULT '';
            ALTER TABLE production.company_production_runs
                ADD COLUMN IF NOT EXISTS bonus_item_id text NOT NULL DEFAULT '';

            CREATE TABLE IF NOT EXISTS production.company_job_postings (
                job_id text PRIMARY KEY,
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                title text NOT NULL,
                description text NOT NULL,
                wage_gold integer NOT NULL,
                required_energy integer NOT NULL,
                daily_limit integer NOT NULL,
                productivity_reward integer NOT NULL,
                status text NOT NULL,
                created_by_player_id text NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                closed_at timestamptz NULL,
                CONSTRAINT company_job_postings_wage_check CHECK (wage_gold > 0),
                CONSTRAINT company_job_postings_required_energy_check CHECK (required_energy >= 0),
                CONSTRAINT company_job_postings_daily_limit_check CHECK (daily_limit > 0),
                CONSTRAINT company_job_postings_productivity_reward_check CHECK (productivity_reward > 0),
                CONSTRAINT company_job_postings_status_check CHECK (status IN ('active', 'inactive', 'closed'))
            );

            CREATE TABLE IF NOT EXISTS production.company_work_records (
                work_id text PRIMARY KEY,
                job_id text NOT NULL REFERENCES production.company_job_postings (job_id) ON DELETE CASCADE,
                company_id text NOT NULL REFERENCES production.companies (company_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                gross_wage_gold integer NOT NULL,
                net_wage_gold integer NOT NULL,
                tax_gold integer NOT NULL,
                required_energy integer NOT NULL,
                productivity_reward integer NOT NULL,
                status text NOT NULL,
                work_date date NOT NULL,
                worked_at timestamptz NOT NULL,
                paid_at timestamptz NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT company_work_records_wage_check CHECK (gross_wage_gold > 0),
                CONSTRAINT company_work_records_net_wage_check CHECK (net_wage_gold >= 0),
                CONSTRAINT company_work_records_tax_check CHECK (tax_gold >= 0),
                CONSTRAINT company_work_records_energy_check CHECK (required_energy >= 0),
                CONSTRAINT company_work_records_productivity_check CHECK (productivity_reward > 0),
                CONSTRAINT company_work_records_status_check CHECK (status IN ('pending_credit', 'paid', 'cancelled'))
            );

            CREATE INDEX IF NOT EXISTS production_jobs_player_status_idx
            ON production.production_jobs (player_id, status, completes_at);

            CREATE INDEX IF NOT EXISTS production_jobs_factory_queue_idx
            ON production.production_jobs (player_id, factory_id, status, started_at);

            CREATE INDEX IF NOT EXISTS company_members_player_idx
            ON production.company_members (player_id, company_id);

            CREATE INDEX IF NOT EXISTS company_factories_company_idx
            ON production.company_factories (company_id);

            CREATE INDEX IF NOT EXISTS company_inventory_company_idx
            ON production.company_inventory (company_id);

            CREATE INDEX IF NOT EXISTS company_production_jobs_company_status_idx
            ON production.company_production_jobs (company_id, status, completes_at);

            CREATE INDEX IF NOT EXISTS company_production_jobs_factory_queue_idx
            ON production.company_production_jobs (company_id, factory_id, status, started_at);

            CREATE INDEX IF NOT EXISTS company_job_postings_company_status_idx
            ON production.company_job_postings (company_id, status, updated_at DESC);

            CREATE INDEX IF NOT EXISTS company_job_postings_status_idx
            ON production.company_job_postings (status, updated_at DESC);

            CREATE INDEX IF NOT EXISTS company_work_records_job_player_date_idx
            ON production.company_work_records (job_id, player_id, work_date);

            CREATE INDEX IF NOT EXISTS company_work_records_company_worked_at_idx
            ON production.company_work_records (company_id, worked_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<FactoryPortfolioResponse> GetFactoriesAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        await AdvanceProductionJobsAsync(connection, null, normalizedPlayerId, now);
        var factories = await ReadFactoriesAsync(connection, null, normalizedPlayerId, now);
        return new FactoryPortfolioResponse(
            PlayerId: normalizedPlayerId,
            Factories: factories.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<ProductionJobsResponse> GetProductionJobsAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        await AdvanceProductionJobsAsync(connection, null, normalizedPlayerId, now);
        var jobs = await ReadProductionJobsAsync(connection, null, normalizedPlayerId, now);
        return new ProductionJobsResponse(
            PlayerId: normalizedPlayerId,
            Jobs: jobs.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<CompanyPortfolioResponse> ListCompaniesAsync(string actorPlayerId)
    {
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var companies = await ReadCompanySummariesAsync(connection, null, normalizedActorId);
        return new CompanyPortfolioResponse(
            PlayerId: normalizedActorId,
            Companies: companies.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<StoreResult<CompanyMutationResponse>> CreateCompanyAsync(
        string ownerPlayerId,
        CreateCompanyRequest request)
    {
        var normalizedOwnerId = NormalizePlayerId(ownerPlayerId);
        if (string.IsNullOrWhiteSpace(normalizedOwnerId))
        {
            return StoreResult<CompanyMutationResponse>.BadRequest("Owner player id is required.");
        }

        var name = NormalizeCompanyName(request.Name);
        if (name is null)
        {
            return StoreResult<CompanyMutationResponse>.BadRequest("Company name must be between 3 and 48 characters.");
        }

        var description = NormalizeCompanyDescription(request.Description);
        var nameKey = name.ToLowerInvariant();
        var companyId = $"co-{Guid.NewGuid():N}";
        var now = DateTimeOffset.UtcNow;

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        if (await CompanyNameExistsAsync(connection, transaction, nameKey))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.Conflict("A company with that name already exists.");
        }

        await using (var insert = new NpgsqlCommand("""
            INSERT INTO production.companies (
                company_id, name, name_key, description, owner_player_id,
                wallet_gold, storage_limit, hq_level, specialization,
                factory_slots, productivity_bonus_percent, created_at, updated_at
            )
            VALUES (
                @company_id, @name, @name_key, @description, @owner_player_id,
                @wallet_gold, @storage_limit, @hq_level, @specialization,
                @factory_slots, @productivity_bonus_percent, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("company_id", companyId);
            insert.Parameters.AddWithValue("name", name);
            insert.Parameters.AddWithValue("name_key", nameKey);
            insert.Parameters.AddWithValue("description", description);
            insert.Parameters.AddWithValue("owner_player_id", normalizedOwnerId);
            insert.Parameters.AddWithValue("wallet_gold", CompanyInitialGold);
            insert.Parameters.AddWithValue("storage_limit", CompanyStorageLimit);
            insert.Parameters.AddWithValue("hq_level", CompanyInitialHqLevel);
            insert.Parameters.AddWithValue("specialization", CompanyDefaultSpecialization);
            insert.Parameters.AddWithValue("factory_slots", CompanyInitialFactorySlots);
            insert.Parameters.AddWithValue("productivity_bonus_percent", CompanyInitialProductivityBonusPercent);
            insert.Parameters.AddWithValue("created_at", now);
            insert.Parameters.AddWithValue("updated_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        await InsertCompanyMemberAsync(
            connection,
            transaction,
            companyId,
            normalizedOwnerId,
            "owner",
            now);
        await InsertCompanyFactoriesAsync(connection, transaction, companyId, now);
        await InsertCompanyStarterInventoryAsync(connection, transaction, companyId, now);

        var company = await ReadCompanyDetailAsync(connection, transaction, companyId, normalizedOwnerId, now);
        await transaction.CommitAsync();

        return StoreResult<CompanyMutationResponse>.Ok(new CompanyMutationResponse(
            Completed: true,
            Message: $"{name} was founded with starter factories, wallet gold, and inventory.",
            Company: company!));
    }

    public async Task<StoreResult<CompanyDetailDto>> GetCompanyAsync(string companyId, string actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        var company = await ReadCompanyDetailAsync(connection, null, normalizedCompanyId, normalizedActorId, now);
        if (company is null)
        {
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyDetailDto>.Forbidden("You must be a company member to view company details.")
                : StoreResult<CompanyDetailDto>.NotFound("Company was not found.");
        }

        return StoreResult<CompanyDetailDto>.Ok(company);
    }

    public async Task<StoreResult<CompanyMembersResponse>> GetCompanyMembersAsync(
        string companyId,
        string actorPlayerId)
    {
        var detail = await GetCompanyAsync(companyId, actorPlayerId);
        return detail.Value is null
            ? StoreResult<CompanyMembersResponse>.FromError(detail)
            : StoreResult<CompanyMembersResponse>.Ok(new CompanyMembersResponse(
                CompanyId: detail.Value.CompanyId,
                Members: detail.Value.Members,
                UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<CompanyAssetsDto>> GetCompanyAssetsAsync(string companyId, string actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        await AdvanceCompanyProductionJobsAsync(connection, null, normalizedCompanyId, now);

        if (!await CompanyExistsAsync(connection, null, normalizedCompanyId))
        {
            return StoreResult<CompanyAssetsDto>.NotFound("Company was not found.");
        }

        var role = await ReadCompanyMemberRoleAsync(connection, null, normalizedCompanyId, normalizedActorId);
        if (role is null)
        {
            return StoreResult<CompanyAssetsDto>.Forbidden("You must be a company member to view company assets.");
        }

        var assets = await ReadCompanyAssetsAsync(connection, null, normalizedCompanyId, now, normalizedActorId);
        return assets is null
            ? StoreResult<CompanyAssetsDto>.NotFound("Company assets were not found.")
            : StoreResult<CompanyAssetsDto>.Ok(assets);
    }

    public async Task<StoreResult<CompanyMutationResponse>> JoinCompanyAsync(
        string companyId,
        string? actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<CompanyMutationResponse>.BadRequest("Actor player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        if (!await CompanyExistsAsync(connection, transaction, normalizedCompanyId))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.NotFound("Company was not found.");
        }

        var existingRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (existingRole is not null)
        {
            var existingCompany = await ReadCompanyDetailAsync(
                connection,
                transaction,
                normalizedCompanyId,
                normalizedActorId,
                now);
            await transaction.CommitAsync();
            return StoreResult<CompanyMutationResponse>.Ok(new CompanyMutationResponse(
                Completed: false,
                Message: "You are already a member of this company.",
                Company: existingCompany!));
        }

        await InsertCompanyMemberAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedActorId,
            "member",
            now);
        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var company = await ReadCompanyDetailAsync(connection, transaction, normalizedCompanyId, normalizedActorId, now);
        await transaction.CommitAsync();

        return StoreResult<CompanyMutationResponse>.Ok(new CompanyMutationResponse(
            Completed: true,
            Message: $"Joined {company!.Name}.",
            Company: company));
    }

    public async Task<StoreResult<CompanyMutationResponse>> UpdateCompanyMemberRoleAsync(
        string companyId,
        string? actorPlayerId,
        string targetPlayerId,
        string? role)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        var normalizedTargetId = NormalizePlayerId(targetPlayerId);
        var normalizedRole = NormalizeCompanyRole(role);
        if (normalizedRole is null || normalizedRole == "owner")
        {
            return StoreResult<CompanyMutationResponse>.BadRequest("Role must be manager or member.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyMutationResponse>.Forbidden("You must be a company member to manage members.")
                : StoreResult<CompanyMutationResponse>.NotFound("Company was not found.");
        }

        if (actorRole != "owner")
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.Forbidden("Only the company owner can change member roles.");
        }

        var targetRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedTargetId);
        if (targetRole is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.NotFound("Company member was not found.");
        }

        if (targetRole == "owner")
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.Conflict("Company ownership cannot be changed here.");
        }

        await using (var update = new NpgsqlCommand("""
            UPDATE production.company_members
            SET role = @role,
                updated_at = @updated_at
            WHERE company_id = @company_id AND player_id = @player_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("company_id", normalizedCompanyId);
            update.Parameters.AddWithValue("player_id", normalizedTargetId);
            update.Parameters.AddWithValue("role", normalizedRole);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var company = await ReadCompanyDetailAsync(connection, transaction, normalizedCompanyId, normalizedActorId, now);
        await transaction.CommitAsync();

        return StoreResult<CompanyMutationResponse>.Ok(new CompanyMutationResponse(
            Completed: true,
            Message: $"{normalizedTargetId} is now a company {normalizedRole}.",
            Company: company!));
    }

    public async Task<StoreResult<CompanyMutationResponse>> RemoveCompanyMemberAsync(
        string companyId,
        string? actorPlayerId,
        string targetPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        var normalizedTargetId = NormalizePlayerId(targetPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyMutationResponse>.Forbidden("You must be a company member to manage members.")
                : StoreResult<CompanyMutationResponse>.NotFound("Company was not found.");
        }

        var targetRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedTargetId);
        if (targetRole is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.NotFound("Company member was not found.");
        }

        var removingSelf = string.Equals(normalizedActorId, normalizedTargetId, StringComparison.Ordinal);
        if (targetRole == "owner")
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.Conflict("The company owner cannot be removed.");
        }

        if (!removingSelf && actorRole != "owner" && !(actorRole == "manager" && targetRole == "member"))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyMutationResponse>.Forbidden("You do not have permission to remove this member.");
        }

        await using (var delete = new NpgsqlCommand("""
            DELETE FROM production.company_members
            WHERE company_id = @company_id AND player_id = @player_id;
            """, connection, transaction))
        {
            delete.Parameters.AddWithValue("company_id", normalizedCompanyId);
            delete.Parameters.AddWithValue("player_id", normalizedTargetId);
            await delete.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var company = await ReadCompanyDetailAsync(connection, transaction, normalizedCompanyId, normalizedActorId, now);
        await transaction.CommitAsync();

        return StoreResult<CompanyMutationResponse>.Ok(new CompanyMutationResponse(
            Completed: true,
            Message: removingSelf ? "You left the company." : $"{normalizedTargetId} was removed from the company.",
            Company: company));
    }

    public async Task<StoreResult<ProductionResult>> StartCompanyProductionAsync(
        string companyId,
        string factoryId,
        CompanyProductionStartRequest? request)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedFactoryId = NormalizeId(factoryId);
        var normalizedActorId = NormalizePlayerId(request?.ActorPlayerId);
        var appliedResourceBonus = CreateAppliedProductionBonus(request);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<ProductionResult>.Forbidden("You must be a company member to run company production.")
                : StoreResult<ProductionResult>.NotFound("Company was not found.");
        }

        if (!CanManageCompany(actorRole))
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionResult>.Forbidden("Only owners and managers can run company production.");
        }

        await AdvanceCompanyProductionJobsAsync(connection, transaction, normalizedCompanyId, now);
        var factory = await ReadCompanyFactoryForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedFactoryId,
            now);
        if (factory is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionResult>.NotFound("Company factory was not found.");
        }

        var queueDepth = await ReadCompanyFactoryQueueDepthForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedFactoryId);
        if (queueDepth >= MaxProductionQueueDepth)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionResult>.Conflict(
                $"{factory.Name} production queue is full. Claim completed company jobs before starting more production.");
        }

        var availableInput = await ReadCompanyInventoryQuantityForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            factory.InputItemId);
        if (availableInput < factory.InputQuantity)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionResult>.Conflict(
                $"Company inventory needs {factory.InputQuantity} {ToDisplayName(factory.InputItemId)} but only has {availableInput}.");
        }

        var latestQueuedCompletesAt = await ReadLatestCompanyQueuedCompletesAtAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedFactoryId);
        var productivityBonusPercent = await ReadCompanyProductivityBonusPercentAsync(
            connection,
            transaction,
            normalizedCompanyId,
            factory.Category);
        var outputQuantity = ApplyProductionBonus(
            ApplyProductivityBonus(factory.OutputQuantity, productivityBonusPercent),
            appliedResourceBonus);
        var durationSeconds = GetProductionDurationSeconds(factory.Level);
        var startedAt = latestQueuedCompletesAt is not null && latestQueuedCompletesAt > now
            ? latestQueuedCompletesAt.Value
            : now;
        var completesAt = startedAt.AddSeconds(durationSeconds);
        var status = startedAt > now ? "queued" : "running";
        var jobId = $"cjob-{Guid.NewGuid():N}";
        var inputItemName = ToDisplayName(factory.InputItemId);
        var outputItemName = ToDisplayName(factory.OutputItemId);
        var job = new ProductionJobDto(
            JobId: jobId,
            PlayerId: normalizedActorId,
            FactoryId: factory.FactoryId,
            Status: status,
            InputItemId: factory.InputItemId,
            InputItemName: inputItemName,
            InputItemCategory: ToItemCategory(factory.InputItemId, "Raw material"),
            InputQuantity: factory.InputQuantity,
            OutputItemId: factory.OutputItemId,
            OutputItemName: outputItemName,
            OutputItemCategory: ToItemCategory(factory.OutputItemId, factory.Category),
            OutputQuantity: outputQuantity,
            DurationSeconds: durationSeconds,
            StartedAt: startedAt,
            CompletesAt: completesAt,
            CompletedAt: null,
            ClaimedAt: null,
            CreatedAt: now,
            UpdatedAt: now,
            CanClaim: false,
            AppliedBonus: appliedResourceBonus);

        await SpendCompanyInventoryAsync(
            connection,
            transaction,
            normalizedCompanyId,
            factory.InputItemId,
            factory.InputQuantity,
            now);

        await using (var update = new NpgsqlCommand("""
            UPDATE production.company_factories
            SET last_produced_at = @last_produced_at,
                updated_at = @updated_at
            WHERE company_id = @company_id AND factory_id = @factory_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("company_id", normalizedCompanyId);
            update.Parameters.AddWithValue("factory_id", normalizedFactoryId);
            update.Parameters.AddWithValue("last_produced_at", startedAt);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await using (var insert = new NpgsqlCommand("""
            INSERT INTO production.company_production_jobs (
                job_id, company_id, factory_id, requested_by_player_id, status,
                input_item_id, input_item_name, input_item_category, input_quantity,
                output_item_id, output_item_name, output_item_category, output_quantity,
                production_bonus_percent, bonus_source_region_id, bonus_source_region_name,
                bonus_resource_name, bonus_item_id,
                duration_seconds, started_at, completes_at, created_at, updated_at
            )
            VALUES (
                @job_id, @company_id, @factory_id, @requested_by_player_id, @status,
                @input_item_id, @input_item_name, @input_item_category, @input_quantity,
                @output_item_id, @output_item_name, @output_item_category, @output_quantity,
                @production_bonus_percent, @bonus_source_region_id, @bonus_source_region_name,
                @bonus_resource_name, @bonus_item_id,
                @duration_seconds, @started_at, @completes_at, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("job_id", job.JobId);
            insert.Parameters.AddWithValue("company_id", normalizedCompanyId);
            insert.Parameters.AddWithValue("factory_id", job.FactoryId);
            insert.Parameters.AddWithValue("requested_by_player_id", normalizedActorId);
            insert.Parameters.AddWithValue("status", job.Status);
            insert.Parameters.AddWithValue("input_item_id", job.InputItemId);
            insert.Parameters.AddWithValue("input_item_name", job.InputItemName);
            insert.Parameters.AddWithValue("input_item_category", job.InputItemCategory);
            insert.Parameters.AddWithValue("input_quantity", job.InputQuantity);
            insert.Parameters.AddWithValue("output_item_id", job.OutputItemId);
            insert.Parameters.AddWithValue("output_item_name", job.OutputItemName);
            insert.Parameters.AddWithValue("output_item_category", job.OutputItemCategory);
            insert.Parameters.AddWithValue("output_quantity", job.OutputQuantity);
            AddProductionBonusParameters(insert, job.AppliedBonus);
            insert.Parameters.AddWithValue("duration_seconds", job.DurationSeconds);
            insert.Parameters.AddWithValue("started_at", job.StartedAt);
            insert.Parameters.AddWithValue("completes_at", job.CompletesAt);
            insert.Parameters.AddWithValue("created_at", job.CreatedAt);
            insert.Parameters.AddWithValue("updated_at", job.UpdatedAt);
            await insert.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        await transaction.CommitAsync();

        var queueMessage = status == "queued"
            ? $"{factory.Name} queued company production job {job.JobId}. It starts at {startedAt:O} and completes at {completesAt:O}."
            : $"{factory.Name} started company production job {job.JobId}. It completes at {completesAt:O}.";
        return StoreResult<ProductionResult>.Accepted(new ProductionResult(
            Completed: false,
            FactoryId: factory.FactoryId,
            Message: queueMessage,
            ConsumedItemId: factory.InputItemId,
            ConsumedQuantity: factory.InputQuantity,
            ProducedItemId: factory.OutputItemId,
            ProducedQuantity: outputQuantity,
            Note: BuildProductionNote(
                "Input was consumed from company inventory; claim the completed company job to receive output.",
                appliedResourceBonus,
                productivityBonusPercent),
            CompletedAt: completesAt,
            ProductionCount: factory.ProductionCount,
            LastProducedAt: startedAt,
            Job: job,
            StartedAt: startedAt,
            CompletesAt: completesAt,
            AppliedBonus: appliedResourceBonus));
    }

    public async Task<StoreResult<CompanyProductionClaimResult>> ClaimCompanyProductionJobAsync(
        string companyId,
        string jobId,
        string? actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedJobId = NormalizeId(jobId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyProductionClaimResult>.Forbidden("You must be a company member to claim company production.")
                : StoreResult<CompanyProductionClaimResult>.NotFound("Company was not found.");
        }

        await AdvanceCompanyProductionJobsAsync(connection, transaction, normalizedCompanyId, now);
        var job = await ReadCompanyProductionJobForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            now);
        if (job is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyProductionClaimResult>.NotFound("Company production job was not found.");
        }

        if (string.Equals(job.Status, "claimed", StringComparison.OrdinalIgnoreCase))
        {
            var assets = await ReadCompanyAssetsAsync(connection, transaction, normalizedCompanyId, now, normalizedActorId);
            await transaction.CommitAsync();
            return StoreResult<CompanyProductionClaimResult>.Ok(new CompanyProductionClaimResult(
                Completed: true,
                Message: "Company production job was already claimed.",
                Claim: new ProductionClaimCompletion(
                    Completed: true,
                    AlreadyClaimed: true,
                    Message: "Company production job was already claimed.",
                    Job: job,
                    ProductionCount: await ReadCompanyProductionCountAsync(normalizedCompanyId, job.FactoryId)),
                Assets: assets!));
        }

        if (job.CompletesAt > now)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyProductionClaimResult>.Conflict(
                $"Company production job is still cooling down until {job.CompletesAt:O}.");
        }

        if (!string.Equals(job.Status, "completed", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(job.Status, "claiming", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyProductionClaimResult>.Conflict(
                $"Company production job cannot be claimed from status '{job.Status}'.");
        }

        var factory = await ReadCompanyFactoryForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            job.FactoryId,
            now);
        if (factory is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyProductionClaimResult>.NotFound("Company factory was not found.");
        }

        await using (var updateJob = new NpgsqlCommand("""
            UPDATE production.company_production_jobs
            SET status = 'claimed',
                completed_at = COALESCE(completed_at, completes_at),
                claimed_at = COALESCE(claimed_at, @claimed_at),
                updated_at = @updated_at
            WHERE company_id = @company_id AND job_id = @job_id;
            """, connection, transaction))
        {
            updateJob.Parameters.AddWithValue("company_id", normalizedCompanyId);
            updateJob.Parameters.AddWithValue("job_id", normalizedJobId);
            updateJob.Parameters.AddWithValue("claimed_at", now);
            updateJob.Parameters.AddWithValue("updated_at", now);
            await updateJob.ExecuteNonQueryAsync();
        }

        var productionCount = await IncrementCompanyProductionCountAsync(
            connection,
            transaction,
            normalizedCompanyId,
            job.FactoryId,
            now);
        var storageError = await GrantCompanyInventoryAsync(
            connection,
            transaction,
            normalizedCompanyId,
            job.OutputItemId,
            job.OutputItemName,
            job.OutputItemCategory,
            job.OutputQuantity,
            $"Output from company production job {job.JobId}.",
            now);
        if (storageError is not null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyProductionClaimResult>.Conflict(storageError);
        }

        await using (var run = new NpgsqlCommand("""
            INSERT INTO production.company_production_runs (
                run_id, company_id, factory_id, job_id, input_item_id, input_quantity,
                output_item_id, output_quantity, production_bonus_percent,
                bonus_source_region_id, bonus_source_region_name, bonus_resource_name,
                bonus_item_id, created_at
            )
            VALUES (
                @run_id, @company_id, @factory_id, @job_id, @input_item_id, @input_quantity,
                @output_item_id, @output_quantity, @production_bonus_percent,
                @bonus_source_region_id, @bonus_source_region_name, @bonus_resource_name,
                @bonus_item_id, @created_at
            )
            ON CONFLICT (run_id) DO NOTHING;
            """, connection, transaction))
        {
            run.Parameters.AddWithValue("run_id", $"crun-{job.JobId}");
            run.Parameters.AddWithValue("company_id", normalizedCompanyId);
            run.Parameters.AddWithValue("factory_id", job.FactoryId);
            run.Parameters.AddWithValue("job_id", job.JobId);
            run.Parameters.AddWithValue("input_item_id", job.InputItemId);
            run.Parameters.AddWithValue("input_quantity", job.InputQuantity);
            run.Parameters.AddWithValue("output_item_id", job.OutputItemId);
            run.Parameters.AddWithValue("output_quantity", job.OutputQuantity);
            AddProductionBonusParameters(run, job.AppliedBonus);
            run.Parameters.AddWithValue("created_at", now);
            await run.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var assetsAfterClaim = await ReadCompanyAssetsAsync(
            connection,
            transaction,
            normalizedCompanyId,
            now,
            normalizedActorId);
        await transaction.CommitAsync();

        var claimedJob = job with
        {
            Status = "claimed",
            CompletedAt = job.CompletedAt ?? job.CompletesAt,
            ClaimedAt = now,
            UpdatedAt = now,
            CanClaim = false
        };
        var message = $"Claimed {job.OutputQuantity} {job.OutputItemName} into company inventory.";
        return StoreResult<CompanyProductionClaimResult>.Ok(new CompanyProductionClaimResult(
            Completed: true,
            Message: message,
            Claim: new ProductionClaimCompletion(
                Completed: true,
                AlreadyClaimed: false,
                Message: message,
                Job: claimedJob,
                ProductionCount: productionCount),
            Assets: assetsAfterClaim!));
    }

    public async Task<FactoryUpgradeQuote?> GetUpgradeQuoteAsync(string playerId, string factoryId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedFactoryId = NormalizeId(factoryId);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        await AdvanceProductionJobsAsync(connection, null, normalizedPlayerId, now);
        var factory = await ReadFactoryAsync(connection, normalizedPlayerId, normalizedFactoryId, now);
        return factory is null ? null : CreateUpgradeQuote(factory);
    }

    public async Task<FactoryUpgradeResult?> UpgradeFactoryAsync(string playerId, string factoryId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedFactoryId = NormalizeId(factoryId);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await AdvanceProductionJobsAsync(connection, transaction, normalizedPlayerId, now);
        var factory = await ReadFactoryForUpdateAsync(connection, transaction, normalizedPlayerId, normalizedFactoryId, now);
        if (factory is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var quote = CreateUpgradeQuote(factory);
        await using (var update = new NpgsqlCommand("""
            UPDATE production.player_factories
            SET level = @level,
                output_quantity = @output_quantity,
                updated_at = @updated_at
            WHERE player_id = @player_id AND factory_id = @factory_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("player_id", normalizedPlayerId);
            update.Parameters.AddWithValue("factory_id", normalizedFactoryId);
            update.Parameters.AddWithValue("level", quote.NextLevel);
            update.Parameters.AddWithValue("output_quantity", quote.OutputQuantityAfterUpgrade);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();

        var upgradedFactory = factory with
        {
            Level = quote.NextLevel,
            OutputQuantity = quote.OutputQuantityAfterUpgrade
        };

        return new FactoryUpgradeResult(
            Upgraded: true,
            FactoryId: upgradedFactory.FactoryId,
            Message: $"{upgradedFactory.Name} upgraded to level {upgradedFactory.Level}.",
            Factory: upgradedFactory,
            AppliedQuote: quote,
            UpgradedAt: now);
    }

    public async Task<StoreResult<ProductionResult>> StartProductionAsync(
        string playerId,
        string factoryId,
        ProductionStartRequest? request = null)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedFactoryId = NormalizeId(factoryId);
        var appliedResourceBonus = CreateAppliedProductionBonus(request);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await AdvanceProductionJobsAsync(connection, transaction, normalizedPlayerId, now);
        var factory = await ReadFactoryForUpdateAsync(connection, transaction, normalizedPlayerId, normalizedFactoryId, now);
        if (factory is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionResult>.NotFound("Factory was not found.");
        }

        var queueDepth = await ReadFactoryQueueDepthForUpdateAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedFactoryId);
        if (queueDepth >= MaxProductionQueueDepth)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionResult>.Conflict(
                $"{factory.Name} production queue is full. Claim completed jobs before starting more production.");
        }

        var latestQueuedCompletesAt = await ReadLatestQueuedCompletesAtAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedFactoryId);
        var outputQuantity = ApplyProductionBonus(factory.OutputQuantity, appliedResourceBonus);
        var durationSeconds = GetProductionDurationSeconds(factory.Level);
        var startedAt = latestQueuedCompletesAt is not null && latestQueuedCompletesAt > now
            ? latestQueuedCompletesAt.Value
            : now;
        var completesAt = startedAt.AddSeconds(durationSeconds);
        var status = startedAt > now ? "queued" : "running";
        var jobId = $"job-{Guid.NewGuid():N}";
        var inputItemName = ToDisplayName(factory.InputItemId);
        var outputItemName = ToDisplayName(factory.OutputItemId);
        var job = new ProductionJobDto(
            JobId: jobId,
            PlayerId: normalizedPlayerId,
            FactoryId: factory.FactoryId,
            Status: status,
            InputItemId: factory.InputItemId,
            InputItemName: inputItemName,
            InputItemCategory: ToItemCategory(factory.InputItemId, "Raw material"),
            InputQuantity: factory.InputQuantity,
            OutputItemId: factory.OutputItemId,
            OutputItemName: outputItemName,
            OutputItemCategory: ToItemCategory(factory.OutputItemId, factory.Category),
            OutputQuantity: outputQuantity,
            DurationSeconds: durationSeconds,
            StartedAt: startedAt,
            CompletesAt: completesAt,
            CompletedAt: null,
            ClaimedAt: null,
            CreatedAt: now,
            UpdatedAt: now,
            CanClaim: false,
            AppliedBonus: appliedResourceBonus);

        await using (var update = new NpgsqlCommand("""
            UPDATE production.player_factories
            SET last_produced_at = @last_produced_at,
                updated_at = @updated_at
            WHERE player_id = @player_id AND factory_id = @factory_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("player_id", normalizedPlayerId);
            update.Parameters.AddWithValue("factory_id", normalizedFactoryId);
            update.Parameters.AddWithValue("last_produced_at", startedAt);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await using (var insert = new NpgsqlCommand("""
            INSERT INTO production.production_jobs (
                job_id, player_id, factory_id, status,
                input_item_id, input_item_name, input_item_category, input_quantity,
                output_item_id, output_item_name, output_item_category, output_quantity,
                production_bonus_percent, bonus_source_region_id, bonus_source_region_name,
                bonus_resource_name, bonus_item_id,
                duration_seconds, started_at, completes_at, created_at, updated_at
            )
            VALUES (
                @job_id, @player_id, @factory_id, @status,
                @input_item_id, @input_item_name, @input_item_category, @input_quantity,
                @output_item_id, @output_item_name, @output_item_category, @output_quantity,
                @production_bonus_percent, @bonus_source_region_id, @bonus_source_region_name,
                @bonus_resource_name, @bonus_item_id,
                @duration_seconds, @started_at, @completes_at, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("job_id", job.JobId);
            insert.Parameters.AddWithValue("player_id", job.PlayerId);
            insert.Parameters.AddWithValue("factory_id", job.FactoryId);
            insert.Parameters.AddWithValue("status", job.Status);
            insert.Parameters.AddWithValue("input_item_id", job.InputItemId);
            insert.Parameters.AddWithValue("input_item_name", job.InputItemName);
            insert.Parameters.AddWithValue("input_item_category", job.InputItemCategory);
            insert.Parameters.AddWithValue("input_quantity", job.InputQuantity);
            insert.Parameters.AddWithValue("output_item_id", job.OutputItemId);
            insert.Parameters.AddWithValue("output_item_name", job.OutputItemName);
            insert.Parameters.AddWithValue("output_item_category", job.OutputItemCategory);
            insert.Parameters.AddWithValue("output_quantity", job.OutputQuantity);
            AddProductionBonusParameters(insert, job.AppliedBonus);
            insert.Parameters.AddWithValue("duration_seconds", job.DurationSeconds);
            insert.Parameters.AddWithValue("started_at", job.StartedAt);
            insert.Parameters.AddWithValue("completes_at", job.CompletesAt);
            insert.Parameters.AddWithValue("created_at", job.CreatedAt);
            insert.Parameters.AddWithValue("updated_at", job.UpdatedAt);
            await insert.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();

        var queueMessage = status == "queued"
            ? $"{factory.Name} queued production job {job.JobId}. It starts at {startedAt:O} and completes at {completesAt:O}."
            : $"{factory.Name} started production job {job.JobId}. It completes at {completesAt:O}.";
        return StoreResult<ProductionResult>.Accepted(new ProductionResult(
            Completed: false,
            FactoryId: factory.FactoryId,
            Message: queueMessage,
            ConsumedItemId: factory.InputItemId,
            ConsumedQuantity: factory.InputQuantity,
            ProducedItemId: factory.OutputItemId,
            ProducedQuantity: outputQuantity,
            Note: BuildProductionNote(
                "Input is consumed at start; claim the completed job to receive output.",
                appliedResourceBonus),
            CompletedAt: completesAt,
            ProductionCount: factory.ProductionCount,
            LastProducedAt: startedAt,
            Job: job,
            StartedAt: startedAt,
            CompletesAt: completesAt,
            AppliedBonus: appliedResourceBonus));
    }

    public async Task<StoreResult<ProductionClaimTicket>> BeginClaimProductionJobAsync(string playerId, string jobId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedJobId = NormalizeId(jobId);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        await AdvanceProductionJobsAsync(connection, transaction, normalizedPlayerId, now);

        var job = await ReadProductionJobForUpdateAsync(connection, transaction, normalizedPlayerId, normalizedJobId, now);
        if (job is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimTicket>.NotFound("Production job was not found.");
        }

        if (string.Equals(job.Status, "claimed", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return StoreResult<ProductionClaimTicket>.Ok(new ProductionClaimTicket(
                ReadyToClaim: false,
                AlreadyClaimed: true,
                Message: "Production job was already claimed.",
                Job: job));
        }

        if (string.Equals(job.Status, "cancelled", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimTicket>.Conflict("Production job was cancelled.");
        }

        if (job.CompletesAt > now)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimTicket>.Conflict(
                $"Production job is still cooling down until {job.CompletesAt:O}.");
        }

        if (!string.Equals(job.Status, "completed", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(job.Status, "claiming", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimTicket>.Conflict(
                $"Production job cannot be claimed from status '{job.Status}'.");
        }

        var claimingJob = job;
        if (!string.Equals(job.Status, "claiming", StringComparison.OrdinalIgnoreCase))
        {
            await using var update = new NpgsqlCommand("""
                UPDATE production.production_jobs
                SET status = 'claiming',
                    completed_at = COALESCE(completed_at, completes_at),
                    updated_at = @updated_at
                WHERE player_id = @player_id AND job_id = @job_id;
                """, connection, transaction);
            update.Parameters.AddWithValue("player_id", normalizedPlayerId);
            update.Parameters.AddWithValue("job_id", normalizedJobId);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();

            claimingJob = job with
            {
                Status = "claiming",
                CompletedAt = job.CompletedAt ?? job.CompletesAt,
                UpdatedAt = now,
                CanClaim = true
            };
        }

        await transaction.CommitAsync();
        return StoreResult<ProductionClaimTicket>.Ok(new ProductionClaimTicket(
            ReadyToClaim: true,
            AlreadyClaimed: false,
            Message: $"Production job {claimingJob.JobId} is ready to claim.",
            Job: claimingJob));
    }

    public async Task<StoreResult<ProductionClaimCompletion>> CompleteClaimProductionJobAsync(string playerId, string jobId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedJobId = NormalizeId(jobId);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        await AdvanceProductionJobsAsync(connection, transaction, normalizedPlayerId, now);

        var job = await ReadProductionJobForUpdateAsync(connection, transaction, normalizedPlayerId, normalizedJobId, now);
        if (job is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimCompletion>.NotFound("Production job was not found.");
        }

        if (string.Equals(job.Status, "claimed", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return StoreResult<ProductionClaimCompletion>.Ok(new ProductionClaimCompletion(
                Completed: true,
                AlreadyClaimed: true,
                Message: "Production job was already claimed.",
                Job: job,
                ProductionCount: await ReadProductionCountAsync(normalizedPlayerId, job.FactoryId)));
        }

        if (job.CompletesAt > now)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimCompletion>.Conflict(
                $"Production job is still cooling down until {job.CompletesAt:O}.");
        }

        if (!string.Equals(job.Status, "claiming", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(job.Status, "completed", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimCompletion>.Conflict(
                $"Production job cannot be finalized from status '{job.Status}'.");
        }

        var factory = await ReadFactoryForUpdateAsync(connection, transaction, normalizedPlayerId, job.FactoryId, now);
        if (factory is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionClaimCompletion>.NotFound("Factory was not found.");
        }

        await using (var updateJob = new NpgsqlCommand("""
            UPDATE production.production_jobs
            SET status = 'claimed',
                completed_at = COALESCE(completed_at, completes_at),
                claimed_at = COALESCE(claimed_at, @claimed_at),
                updated_at = @updated_at
            WHERE player_id = @player_id AND job_id = @job_id;
            """, connection, transaction))
        {
            updateJob.Parameters.AddWithValue("player_id", normalizedPlayerId);
            updateJob.Parameters.AddWithValue("job_id", normalizedJobId);
            updateJob.Parameters.AddWithValue("claimed_at", now);
            updateJob.Parameters.AddWithValue("updated_at", now);
            await updateJob.ExecuteNonQueryAsync();
        }

        var productionCount = await IncrementProductionCountAsync(
            connection,
            transaction,
            normalizedPlayerId,
            job.FactoryId,
            now);

        await using (var run = new NpgsqlCommand("""
            INSERT INTO production.production_runs (
                run_id, player_id, factory_id, input_item_id, input_quantity,
                output_item_id, output_quantity, production_bonus_percent,
                bonus_source_region_id, bonus_source_region_name, bonus_resource_name,
                bonus_item_id, created_at
            )
            VALUES (
                @run_id, @player_id, @factory_id, @input_item_id, @input_quantity,
                @output_item_id, @output_quantity, @production_bonus_percent,
                @bonus_source_region_id, @bonus_source_region_name, @bonus_resource_name,
                @bonus_item_id, @created_at
            )
            ON CONFLICT (run_id) DO NOTHING;
            """, connection, transaction))
        {
            run.Parameters.AddWithValue("run_id", $"run-{job.JobId}");
            run.Parameters.AddWithValue("player_id", normalizedPlayerId);
            run.Parameters.AddWithValue("factory_id", job.FactoryId);
            run.Parameters.AddWithValue("input_item_id", job.InputItemId);
            run.Parameters.AddWithValue("input_quantity", job.InputQuantity);
            run.Parameters.AddWithValue("output_item_id", job.OutputItemId);
            run.Parameters.AddWithValue("output_quantity", job.OutputQuantity);
            AddProductionBonusParameters(run, job.AppliedBonus);
            run.Parameters.AddWithValue("created_at", now);
            await run.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();

        var claimedJob = job with
        {
            Status = "claimed",
            CompletedAt = job.CompletedAt ?? job.CompletesAt,
            ClaimedAt = now,
            UpdatedAt = now,
            CanClaim = false
        };
        return StoreResult<ProductionClaimCompletion>.Ok(new ProductionClaimCompletion(
            Completed: true,
            AlreadyClaimed: false,
            Message: $"Claimed {job.OutputQuantity} {job.OutputItemName} from {factory.Name}.",
            Job: claimedJob,
            ProductionCount: productionCount));
    }

    public async Task<StoreResult<ProductionJobDto>> CancelProductionJobAsync(string playerId, string jobId, string? reason)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedJobId = NormalizeId(jobId);
        await EnsurePlayerFactoriesAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var job = await ReadProductionJobForUpdateAsync(connection, transaction, normalizedPlayerId, normalizedJobId, now);
        if (job is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionJobDto>.NotFound("Production job was not found.");
        }

        if (string.Equals(job.Status, "claimed", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.RollbackAsync();
            return StoreResult<ProductionJobDto>.Conflict("Claimed production jobs cannot be cancelled.");
        }

        if (string.Equals(job.Status, "cancelled", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return StoreResult<ProductionJobDto>.Ok(job);
        }

        await using (var update = new NpgsqlCommand("""
            UPDATE production.production_jobs
            SET status = 'cancelled',
                cancellation_reason = @reason,
                updated_at = @updated_at
            WHERE player_id = @player_id AND job_id = @job_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("player_id", normalizedPlayerId);
            update.Parameters.AddWithValue("job_id", normalizedJobId);
            update.Parameters.AddWithValue("reason", string.IsNullOrWhiteSpace(reason) ? "Production start failed." : reason.Trim());
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        await using (var updateFactory = new NpgsqlCommand("""
            UPDATE production.player_factories
            SET last_produced_at = (
                    SELECT MAX(started_at)
                    FROM production.production_jobs
                    WHERE player_id = @player_id
                      AND factory_id = @factory_id
                      AND status <> 'cancelled'
                ),
                updated_at = @updated_at
            WHERE player_id = @player_id AND factory_id = @factory_id;
            """, connection, transaction))
        {
            updateFactory.Parameters.AddWithValue("player_id", normalizedPlayerId);
            updateFactory.Parameters.AddWithValue("factory_id", job.FactoryId);
            updateFactory.Parameters.AddWithValue("updated_at", now);
            await updateFactory.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
        return StoreResult<ProductionJobDto>.Ok(job with
        {
            Status = "cancelled",
            UpdatedAt = now,
            CanClaim = false
        });
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task EnsurePlayerFactoriesAsync(string playerId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        foreach (var factory in FactoryCatalog.All)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO production.player_factories (
                    player_id, factory_id, name, category, level,
                    input_item_id, input_quantity, output_item_id, output_quantity,
                    production_count, created_at, updated_at
                )
                VALUES (
                    @player_id, @factory_id, @name, @category, @level,
                    @input_item_id, @input_quantity, @output_item_id, @output_quantity,
                    0, @created_at, @updated_at
                )
                ON CONFLICT (player_id, factory_id) DO NOTHING;
                """, connection, transaction);
            command.Parameters.AddWithValue("player_id", playerId);
            command.Parameters.AddWithValue("factory_id", factory.FactoryId);
            command.Parameters.AddWithValue("name", factory.Name);
            command.Parameters.AddWithValue("category", factory.Category);
            command.Parameters.AddWithValue("level", factory.Level);
            command.Parameters.AddWithValue("input_item_id", factory.InputItemId);
            command.Parameters.AddWithValue("input_quantity", factory.InputQuantity);
            command.Parameters.AddWithValue("output_item_id", factory.OutputItemId);
            command.Parameters.AddWithValue("output_quantity", factory.OutputQuantity);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
    }

    private static async Task<bool> CompanyNameExistsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string nameKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM production.companies
            WHERE name_key = @name_key
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("name_key", nameKey);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task<bool> CompanyExistsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM production.companies
            WHERE company_id = @company_id
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task InsertCompanyMemberAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string playerId,
        string role,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO production.company_members (
                company_id, player_id, role, joined_at, created_at, updated_at
            )
            VALUES (
                @company_id, @player_id, @role, @joined_at, @created_at, @updated_at
            )
            ON CONFLICT (company_id, player_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("role", role);
        command.Parameters.AddWithValue("joined_at", now);
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task InsertCompanyFactoriesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        DateTimeOffset now)
    {
        foreach (var factory in FactoryCatalog.All)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO production.company_factories (
                    company_id, factory_id, name, category, level,
                    input_item_id, input_quantity, output_item_id, output_quantity,
                    production_count, created_at, updated_at
                )
                VALUES (
                    @company_id, @factory_id, @name, @category, @level,
                    @input_item_id, @input_quantity, @output_item_id, @output_quantity,
                    0, @created_at, @updated_at
                )
                ON CONFLICT (company_id, factory_id) DO NOTHING;
                """, connection, transaction);
            command.Parameters.AddWithValue("company_id", companyId);
            command.Parameters.AddWithValue("factory_id", factory.FactoryId);
            command.Parameters.AddWithValue("name", factory.Name);
            command.Parameters.AddWithValue("category", factory.Category);
            command.Parameters.AddWithValue("level", factory.Level);
            command.Parameters.AddWithValue("input_item_id", factory.InputItemId);
            command.Parameters.AddWithValue("input_quantity", factory.InputQuantity);
            command.Parameters.AddWithValue("output_item_id", factory.OutputItemId);
            command.Parameters.AddWithValue("output_quantity", factory.OutputQuantity);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }
    }

    private static async Task InsertCompanyStarterInventoryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        DateTimeOffset now)
    {
        var starterItems = new[]
        {
            new CompanyInventorySeed("grain", "Grain", "Raw material", 80, "Starter input for company food production."),
            new CompanyInventorySeed("iron", "Iron", "Raw material", 40, "Starter input for company weapon production.")
        };

        foreach (var item in starterItems)
        {
            var storageError = await GrantCompanyInventoryAsync(
                connection,
                transaction,
                companyId,
                item.ItemId,
                item.Name,
                item.Category,
                item.Quantity,
                item.Description,
                now);
            if (storageError is not null)
            {
                throw new InvalidOperationException(storageError);
            }
        }
    }

    private static async Task TouchCompanyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE production.companies
            SET updated_at = @updated_at
            WHERE company_id = @company_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<CompanySummaryDto>> ReadCompanySummariesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string actorPlayerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.company_id, c.name, c.description, c.owner_player_id,
                   c.wallet_gold,
                   COALESCE((
                       SELECT SUM(quantity)
                       FROM production.company_inventory inventory
                       WHERE inventory.company_id = c.company_id
                   ), 0)::integer AS storage_used,
                   c.storage_limit,
                   c.hq_level,
                   c.specialization,
                   c.factory_slots,
                   c.productivity_bonus_percent,
                   c.created_at, c.updated_at,
                   (
                       SELECT COUNT(*)
                       FROM production.company_members members
                       WHERE members.company_id = c.company_id
                   )::integer AS member_count,
                   (
                       SELECT COUNT(*)
                       FROM production.company_factories factories
                       WHERE factories.company_id = c.company_id
                   )::integer AS factory_count,
                   member.role
            FROM production.companies c
            LEFT JOIN production.company_members member
              ON member.company_id = c.company_id
             AND member.player_id = @actor_player_id
            ORDER BY member.role IS NULL, c.updated_at DESC, c.name;
            """, connection, transaction);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId);

        var companies = new List<CompanySummaryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            companies.Add(ReadCompanySummary(reader));
        }

        return companies;
    }

    private static async Task<CompanySummaryDto?> ReadCompanySummaryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string actorPlayerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.company_id, c.name, c.description, c.owner_player_id,
                   c.wallet_gold,
                   COALESCE((
                       SELECT SUM(quantity)
                       FROM production.company_inventory inventory
                       WHERE inventory.company_id = c.company_id
                   ), 0)::integer AS storage_used,
                   c.storage_limit,
                   c.hq_level,
                   c.specialization,
                   c.factory_slots,
                   c.productivity_bonus_percent,
                   c.created_at, c.updated_at,
                   (
                       SELECT COUNT(*)
                       FROM production.company_members members
                       WHERE members.company_id = c.company_id
                   )::integer AS member_count,
                   (
                       SELECT COUNT(*)
                       FROM production.company_factories factories
                       WHERE factories.company_id = c.company_id
                   )::integer AS factory_count,
                   member.role
            FROM production.companies c
            LEFT JOIN production.company_members member
              ON member.company_id = c.company_id
             AND member.player_id = @actor_player_id
            WHERE c.company_id = @company_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCompanySummary(reader) : null;
    }

    private static CompanySummaryDto ReadCompanySummary(NpgsqlDataReader reader)
    {
        var role = reader.IsDBNull(15) ? null : reader.GetString(15);
        return new CompanySummaryDto(
            CompanyId: reader.GetString(0),
            Name: reader.GetString(1),
            Description: reader.GetString(2),
            OwnerPlayerId: reader.GetString(3),
            WalletGold: reader.GetInt32(4),
            StorageUsed: reader.GetInt32(5),
            StorageLimit: reader.GetInt32(6),
            HqLevel: reader.GetInt32(7),
            Specialization: reader.GetString(8),
            FactorySlots: reader.GetInt32(9),
            ProductivityBonusPercent: reader.GetInt32(10),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(11),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(12),
            MemberCount: reader.GetInt32(13),
            FactoryCount: reader.GetInt32(14),
            Role: role,
            IsMember: role is not null,
            CanManage: CanManageCompany(role),
            Permissions: CreateCompanyPermissions(role));
    }

    private static async Task<CompanyDetailDto?> ReadCompanyDetailAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string actorPlayerId,
        DateTimeOffset now)
    {
        await AdvanceCompanyProductionJobsAsync(connection, transaction, companyId, now);
        var summary = await ReadCompanySummaryAsync(connection, transaction, companyId, actorPlayerId);
        if (summary is null || !summary.IsMember)
        {
            return null;
        }

        var members = await ReadCompanyMembersAsync(connection, transaction, companyId);
        var assets = await ReadCompanyAssetsAsync(connection, transaction, companyId, now, actorPlayerId);
        return new CompanyDetailDto(
            CompanyId: summary.CompanyId,
            Name: summary.Name,
            Description: summary.Description,
            OwnerPlayerId: summary.OwnerPlayerId,
            WalletGold: summary.WalletGold,
            StorageUsed: summary.StorageUsed,
            StorageLimit: summary.StorageLimit,
            HqLevel: summary.HqLevel,
            Specialization: summary.Specialization,
            FactorySlots: summary.FactorySlots,
            ProductivityBonusPercent: summary.ProductivityBonusPercent,
            CreatedAt: summary.CreatedAt,
            UpdatedAt: summary.UpdatedAt,
            MemberCount: summary.MemberCount,
            FactoryCount: summary.FactoryCount,
            Role: summary.Role,
            IsMember: summary.IsMember,
            CanManage: summary.CanManage,
            Permissions: summary.Permissions,
            Members: members.ToArray(),
            Assets: assets!);
    }

    private static async Task<string?> ReadCompanyMemberRoleAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT role
            FROM production.company_members
            WHERE company_id = @company_id AND player_id = @player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("player_id", playerId);
        var role = await command.ExecuteScalarAsync();
        return role is string value ? value : null;
    }

    private static async Task<List<CompanyMemberDto>> ReadCompanyMembersAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, role, joined_at
            FROM production.company_members
            WHERE company_id = @company_id
            ORDER BY CASE role WHEN 'owner' THEN 0 WHEN 'manager' THEN 1 ELSE 2 END,
                     joined_at,
                     player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        var members = new List<CompanyMemberDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            members.Add(new CompanyMemberDto(
                PlayerId: reader.GetString(0),
                Role: reader.GetString(1),
                JoinedAt: reader.GetFieldValue<DateTimeOffset>(2),
                CanManage: CanManageCompany(reader.GetString(1))));
        }

        return members;
    }

    private static async Task<CompanyAssetsDto?> ReadCompanyAssetsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        DateTimeOffset now,
        string? actorPlayerId = null)
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
        if (!await reader.ReadAsync())
        {
            return null;
        }

        var walletGold = reader.GetInt32(0);
        var storageUsed = reader.GetInt32(1);
        var storageLimit = reader.GetInt32(2);
        var hqLevel = reader.GetInt32(3);
        var specialization = reader.GetString(4);
        var factorySlots = reader.GetInt32(5);
        var productivityBonusPercent = reader.GetInt32(6);
        var updatedAt = reader.GetFieldValue<DateTimeOffset>(7);
        await reader.DisposeAsync();

        var inventory = await ReadCompanyInventoryAsync(connection, transaction, companyId);
        var factories = await ReadCompanyFactoriesAsync(connection, transaction, companyId, now);
        var jobs = await ReadCompanyProductionJobsAsync(connection, transaction, companyId, now);
        var workforceJobs = await ReadCompanyJobPostingsAsync(
            connection,
            transaction,
            companyId,
            actorPlayerId,
            includeInactive: true);
        var workRecords = await ReadCompanyWorkRecordsAsync(connection, transaction, companyId, limit: 20);
        var laborCredits = inventory
            .FirstOrDefault(item => string.Equals(item.ItemId, LaborCreditItemId, StringComparison.OrdinalIgnoreCase))
            ?.Quantity ?? 0;
        var upgrades = CreateCompanyUpgradeState(
            companyId,
            hqLevel,
            specialization,
            factorySlots,
            factories.Count,
            storageUsed,
            storageLimit,
            productivityBonusPercent,
            walletGold,
            laborCredits,
            CreateCompanyPermissions(await ReadCompanyMemberRoleAsync(
                connection,
                transaction,
                companyId,
                actorPlayerId ?? string.Empty)).CanManageUpgrades,
            updatedAt);
        return new CompanyAssetsDto(
            CompanyId: companyId,
            WalletGold: walletGold,
            StorageUsed: storageUsed,
            StorageLimit: storageLimit,
            Upgrades: upgrades,
            Inventory: inventory.ToArray(),
            Factories: factories.ToArray(),
            ProductionJobs: jobs.ToArray(),
            WorkforceJobs: workforceJobs.ToArray(),
            WorkRecords: workRecords.ToArray(),
            UpdatedAt: updatedAt);
    }

    private static async Task<List<CompanyInventoryItemDto>> ReadCompanyInventoryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT item_id, name, category, quantity, description
            FROM production.company_inventory
            WHERE company_id = @company_id
            ORDER BY category, name;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        var items = new List<CompanyInventoryItemDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            items.Add(new CompanyInventoryItemDto(
                ItemId: reader.GetString(0),
                Name: reader.GetString(1),
                Category: reader.GetString(2),
                Quantity: reader.GetInt32(3),
                Description: reader.GetString(4)));
        }

        return items;
    }

    private static async Task<List<FactoryDto>> ReadCompanyFactoriesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT factory_id, name, category, level, input_item_id, input_quantity,
                   output_item_id, output_quantity, production_count, last_produced_at,
                   (
                       SELECT job_id
                       FROM production.company_production_jobs jobs
                       WHERE jobs.company_id = factories.company_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_id,
                   (
                       SELECT completes_at
                       FROM production.company_production_jobs jobs
                       WHERE jobs.company_id = factories.company_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_completes_at,
                   (
                       SELECT COUNT(*)
                       FROM production.company_production_jobs jobs
                       WHERE jobs.company_id = factories.company_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                   ) AS queue_depth
            FROM production.company_factories factories
            WHERE factories.company_id = @company_id
            ORDER BY category, name;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        var factories = new List<FactoryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            factories.Add(ReadFactory(reader, now));
        }

        return factories;
    }

    private static async Task<FactoryDto?> ReadCompanyFactoryForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string factoryId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT factory_id, name, category, level, input_item_id, input_quantity,
                   output_item_id, output_quantity, production_count, last_produced_at,
                   (
                       SELECT job_id
                       FROM production.company_production_jobs jobs
                       WHERE jobs.company_id = factories.company_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_id,
                   (
                       SELECT completes_at
                       FROM production.company_production_jobs jobs
                       WHERE jobs.company_id = factories.company_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_completes_at,
                   (
                       SELECT COUNT(*)
                       FROM production.company_production_jobs jobs
                       WHERE jobs.company_id = factories.company_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                   ) AS queue_depth
            FROM production.company_factories factories
            WHERE factories.company_id = @company_id AND factories.factory_id = @factory_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("factory_id", factoryId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadFactory(reader, now) : null;
    }

    private static async Task AdvanceCompanyProductionJobsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE production.company_production_jobs
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

    private static async Task<int> ReadCompanyFactoryQueueDepthForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string factoryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT COUNT(*)
            FROM production.company_production_jobs
            WHERE company_id = @company_id
              AND factory_id = @factory_id
              AND status IN ('queued', 'running', 'completed', 'claiming');
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private static async Task<DateTimeOffset?> ReadLatestCompanyQueuedCompletesAtAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string factoryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT MAX(completes_at)
            FROM production.company_production_jobs
            WHERE company_id = @company_id
              AND factory_id = @factory_id
              AND status IN ('queued', 'running');
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        var result = await command.ExecuteScalarAsync();
        return result is DBNull or null ? null : (DateTimeOffset)result;
    }

    private static async Task<List<ProductionJobDto>> ReadCompanyProductionJobsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT job_id, requested_by_player_id, factory_id, status,
                   input_item_id, input_item_name, input_item_category, input_quantity,
                   output_item_id, output_item_name, output_item_category, output_quantity,
                   production_bonus_percent, bonus_source_region_id, bonus_source_region_name,
                   bonus_resource_name, bonus_item_id,
                   duration_seconds, started_at, completes_at, completed_at, claimed_at,
                   created_at, updated_at
            FROM production.company_production_jobs
            WHERE company_id = @company_id
              AND status <> 'cancelled'
            ORDER BY
                CASE WHEN status IN ('completed', 'claiming') THEN 0
                     WHEN status IN ('running', 'queued') THEN 1
                     ELSE 2
                END,
                completes_at,
                created_at DESC;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        var jobs = new List<ProductionJobDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            jobs.Add(ReadProductionJob(reader, now));
        }

        return jobs;
    }

    private static async Task<ProductionJobDto?> ReadCompanyProductionJobForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string jobId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT job_id, requested_by_player_id, factory_id, status,
                   input_item_id, input_item_name, input_item_category, input_quantity,
                   output_item_id, output_item_name, output_item_category, output_quantity,
                   production_bonus_percent, bonus_source_region_id, bonus_source_region_name,
                   bonus_resource_name, bonus_item_id,
                   duration_seconds, started_at, completes_at, completed_at, claimed_at,
                   created_at, updated_at
            FROM production.company_production_jobs
            WHERE company_id = @company_id AND job_id = @job_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("job_id", jobId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadProductionJob(reader, now) : null;
    }

    private static async Task<int> ReadCompanyInventoryQuantityForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string itemId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT quantity
            FROM production.company_inventory
            WHERE company_id = @company_id AND item_id = @item_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("item_id", itemId);
        var result = await command.ExecuteScalarAsync();
        return result is int quantity ? quantity : 0;
    }

    private static async Task SpendCompanyInventoryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string itemId,
        int quantity,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            DELETE FROM production.company_inventory
            WHERE company_id = @company_id AND item_id = @item_id AND quantity = @quantity;

            UPDATE production.company_inventory
            SET quantity = quantity - @quantity,
                updated_at = @updated_at
            WHERE company_id = @company_id AND item_id = @item_id AND quantity > @quantity;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("item_id", itemId);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<string?> ValidateCompanyStorageCapacityAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        int quantityToAdd)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.storage_limit,
                   COALESCE((
                       SELECT SUM(quantity)
                       FROM production.company_inventory inventory
                       WHERE inventory.company_id = c.company_id
                   ), 0)::integer AS storage_used
            FROM production.companies c
            WHERE c.company_id = @company_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return "Company was not found.";
        }

        var storageLimit = reader.GetInt32(0);
        var storageUsed = reader.GetInt32(1);
        return storageUsed + quantityToAdd <= storageLimit
            ? null
            : $"Company storage is full. Required {storageUsed + quantityToAdd}/{storageLimit} capacity.";
    }

    private static async Task<string?> GrantCompanyInventoryAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string itemId,
        string name,
        string category,
        int quantity,
        string description,
        DateTimeOffset updatedAt)
    {
        var storageError = await ValidateCompanyStorageCapacityAsync(
            connection,
            transaction,
            companyId,
            quantity);
        if (storageError is not null)
        {
            return storageError;
        }

        await using var command = new NpgsqlCommand("""
            INSERT INTO production.company_inventory (
                company_id, item_id, name, category, quantity, description, created_at, updated_at
            )
            VALUES (
                @company_id, @item_id, @name, @category, @quantity, @description, @created_at, @updated_at
            )
            ON CONFLICT (company_id, item_id)
            DO UPDATE SET quantity = production.company_inventory.quantity + EXCLUDED.quantity,
                          name = EXCLUDED.name,
                          category = EXCLUDED.category,
                          description = EXCLUDED.description,
                          updated_at = EXCLUDED.updated_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("item_id", itemId);
        command.Parameters.AddWithValue("name", name);
        command.Parameters.AddWithValue("category", category);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("created_at", updatedAt);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync();
        return null;
    }

    private static async Task<int> IncrementCompanyProductionCountAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string factoryId,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE production.company_factories
            SET production_count = production_count + 1,
                updated_at = @updated_at
            WHERE company_id = @company_id AND factory_id = @factory_id
            RETURNING production_count;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        return (int)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Company factory production count update did not return a value."));
    }

    private async Task<int> ReadCompanyProductionCountAsync(string companyId, string factoryId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT production_count
            FROM production.company_factories
            WHERE company_id = @company_id AND factory_id = @factory_id;
            """, connection);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        return (int)(await command.ExecuteScalarAsync() ?? 0);
    }

    private static async Task<List<FactoryDto>> ReadFactoriesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT factory_id, name, category, level, input_item_id, input_quantity,
                   output_item_id, output_quantity, production_count, last_produced_at,
                   (
                       SELECT job_id
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_id,
                   (
                       SELECT completes_at
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_completes_at,
                   (
                       SELECT COUNT(*)
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                   ) AS queue_depth
            FROM production.player_factories factories
            WHERE factories.player_id = @player_id
            ORDER BY category, name;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        var factories = new List<FactoryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            factories.Add(ReadFactory(reader, now));
        }

        return factories;
    }

    private static async Task<FactoryDto?> ReadFactoryAsync(
        NpgsqlConnection connection,
        string playerId,
        string factoryId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT factory_id, name, category, level, input_item_id, input_quantity,
                   output_item_id, output_quantity, production_count, last_produced_at,
                   (
                       SELECT job_id
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_id,
                   (
                       SELECT completes_at
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_completes_at,
                   (
                       SELECT COUNT(*)
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                   ) AS queue_depth
            FROM production.player_factories factories
            WHERE factories.player_id = @player_id AND factories.factory_id = @factory_id;
            """, connection);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("factory_id", factoryId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadFactory(reader, now) : null;
    }

    private static async Task<FactoryDto?> ReadFactoryForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string factoryId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT factory_id, name, category, level, input_item_id, input_quantity,
                   output_item_id, output_quantity, production_count, last_produced_at,
                   (
                       SELECT job_id
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_id,
                   (
                       SELECT completes_at
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                       ORDER BY jobs.started_at, jobs.created_at
                       LIMIT 1
                   ) AS active_job_completes_at,
                   (
                       SELECT COUNT(*)
                       FROM production.production_jobs jobs
                       WHERE jobs.player_id = factories.player_id
                         AND jobs.factory_id = factories.factory_id
                         AND jobs.status IN ('queued', 'running', 'completed', 'claiming')
                   ) AS queue_depth
            FROM production.player_factories factories
            WHERE factories.player_id = @player_id AND factories.factory_id = @factory_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("factory_id", factoryId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadFactory(reader, now) : null;
    }

    private static FactoryDto ReadFactory(NpgsqlDataReader reader, DateTimeOffset now)
    {
        var level = reader.GetInt32(3);
        var durationSeconds = GetProductionDurationSeconds(level);
        DateTimeOffset? lastProducedAt = reader.IsDBNull(9) ? null : reader.GetFieldValue<DateTimeOffset>(9);
        var activeJobId = reader.IsDBNull(10) ? null : reader.GetString(10);
        DateTimeOffset? activeJobCompletesAt = reader.IsDBNull(11) ? null : reader.GetFieldValue<DateTimeOffset>(11);
        var queueDepth = reader.GetInt32(12);
        var cooldownUntil = activeJobCompletesAt ??
            (lastProducedAt is null ? null : lastProducedAt.Value.AddSeconds(durationSeconds));
        if (cooldownUntil is not null && cooldownUntil <= now)
        {
            cooldownUntil = null;
        }

        return new FactoryDto(
            FactoryId: reader.GetString(0),
            Name: reader.GetString(1),
            Category: reader.GetString(2),
            Level: level,
            InputItemId: reader.GetString(4),
            InputQuantity: reader.GetInt32(5),
            OutputItemId: reader.GetString(6),
            OutputQuantity: reader.GetInt32(7),
            CanProduce: queueDepth < MaxProductionQueueDepth,
            ProductionCount: reader.GetInt32(8),
            LastProducedAt: lastProducedAt,
            CooldownUntil: cooldownUntil,
            ProductionDurationSeconds: durationSeconds,
            ActiveJobId: activeJobId,
            QueueDepth: queueDepth,
            MaxQueueDepth: MaxProductionQueueDepth);
    }

    private static async Task AdvanceProductionJobsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE production.production_jobs
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
            WHERE player_id = @player_id
              AND status IN ('queued', 'running')
              AND (started_at <= @now OR completes_at <= @now);
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("now", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<int> ReadFactoryQueueDepthForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string factoryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT COUNT(*)
            FROM production.production_jobs
            WHERE player_id = @player_id
              AND factory_id = @factory_id
              AND status IN ('queued', 'running', 'completed', 'claiming');
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private static async Task<DateTimeOffset?> ReadLatestQueuedCompletesAtAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string factoryId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT MAX(completes_at)
            FROM production.production_jobs
            WHERE player_id = @player_id
              AND factory_id = @factory_id
              AND status IN ('queued', 'running');
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        var result = await command.ExecuteScalarAsync();
        return result is DBNull or null ? null : (DateTimeOffset)result;
    }

    private static async Task<List<ProductionJobDto>> ReadProductionJobsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT job_id, player_id, factory_id, status,
                   input_item_id, input_item_name, input_item_category, input_quantity,
                   output_item_id, output_item_name, output_item_category, output_quantity,
                   production_bonus_percent, bonus_source_region_id, bonus_source_region_name,
                   bonus_resource_name, bonus_item_id,
                   duration_seconds, started_at, completes_at, completed_at, claimed_at,
                   created_at, updated_at
            FROM production.production_jobs
            WHERE player_id = @player_id
              AND status <> 'cancelled'
            ORDER BY
                CASE WHEN status IN ('completed', 'claiming') THEN 0
                     WHEN status IN ('running', 'queued') THEN 1
                     ELSE 2
                END,
                completes_at,
                created_at DESC;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        var jobs = new List<ProductionJobDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            jobs.Add(ReadProductionJob(reader, now));
        }

        return jobs;
    }

    private static async Task<ProductionJobDto?> ReadProductionJobForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string jobId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT job_id, player_id, factory_id, status,
                   input_item_id, input_item_name, input_item_category, input_quantity,
                   output_item_id, output_item_name, output_item_category, output_quantity,
                   production_bonus_percent, bonus_source_region_id, bonus_source_region_name,
                   bonus_resource_name, bonus_item_id,
                   duration_seconds, started_at, completes_at, completed_at, claimed_at,
                   created_at, updated_at
            FROM production.production_jobs
            WHERE player_id = @player_id AND job_id = @job_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("job_id", jobId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadProductionJob(reader, now) : null;
    }

    private static ProductionJobDto ReadProductionJob(NpgsqlDataReader reader, DateTimeOffset now)
    {
        var status = reader.GetString(3);
        var bonusPercent = reader.GetInt32(12);
        var appliedBonus = bonusPercent <= 0
            ? null
            : new ProductionBonusDto(
                ProductionBonusPercent: bonusPercent,
                SourceRegionId: reader.GetString(13),
                SourceRegionName: reader.GetString(14),
                ResourceName: reader.GetString(15),
                ItemId: reader.GetString(16));
        var completesAt = reader.GetFieldValue<DateTimeOffset>(19);
        DateTimeOffset? claimedAt = reader.IsDBNull(21) ? null : reader.GetFieldValue<DateTimeOffset>(21);
        return new ProductionJobDto(
            JobId: reader.GetString(0),
            PlayerId: reader.GetString(1),
            FactoryId: reader.GetString(2),
            Status: status,
            InputItemId: reader.GetString(4),
            InputItemName: reader.GetString(5),
            InputItemCategory: reader.GetString(6),
            InputQuantity: reader.GetInt32(7),
            OutputItemId: reader.GetString(8),
            OutputItemName: reader.GetString(9),
            OutputItemCategory: reader.GetString(10),
            OutputQuantity: reader.GetInt32(11),
            DurationSeconds: reader.GetInt32(17),
            StartedAt: reader.GetFieldValue<DateTimeOffset>(18),
            CompletesAt: completesAt,
            CompletedAt: reader.IsDBNull(20) ? null : reader.GetFieldValue<DateTimeOffset>(20),
            ClaimedAt: claimedAt,
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(22),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(23),
            CanClaim: claimedAt is null &&
                completesAt <= now &&
                (string.Equals(status, "completed", StringComparison.OrdinalIgnoreCase) ||
                 string.Equals(status, "claiming", StringComparison.OrdinalIgnoreCase)),
            AppliedBonus: appliedBonus);
    }

    private static async Task<int> IncrementProductionCountAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string factoryId,
        DateTimeOffset updatedAt)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE production.player_factories
            SET production_count = production_count + 1,
                updated_at = @updated_at
            WHERE player_id = @player_id AND factory_id = @factory_id
            RETURNING production_count;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        command.Parameters.AddWithValue("updated_at", updatedAt);
        return (int)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Factory production count update did not return a value."));
    }

    private async Task<int> ReadProductionCountAsync(string playerId, string factoryId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT production_count
            FROM production.player_factories
            WHERE player_id = @player_id AND factory_id = @factory_id;
            """, connection);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("factory_id", factoryId);
        return (int)(await command.ExecuteScalarAsync() ?? 0);
    }

    private static FactoryUpgradeQuote CreateUpgradeQuote(FactoryDto factory)
    {
        var nextLevel = factory.Level + 1;
        return new FactoryUpgradeQuote(
            FactoryId: factory.FactoryId,
            CurrentLevel: factory.Level,
            NextLevel: nextLevel,
            GoldCost: UpgradeBaseGoldCost * nextLevel,
            RequiredItemId: factory.InputItemId,
            RequiredItemName: ToDisplayName(factory.InputItemId),
            RequiredItemQuantity: factory.InputQuantity * nextLevel,
            OutputQuantityAfterUpgrade: factory.OutputQuantity + UpgradeOutputQuantityIncrease,
            CanUpgrade: true);
    }

    private static ProductionBonusDto? CreateAppliedProductionBonus(ProductionStartRequest? request)
    {
        return CreateAppliedProductionBonus(
            request?.OutputBonusPercent,
            request?.BonusSourceRegionId,
            request?.BonusSourceRegionName,
            request?.BonusResourceName,
            request?.BonusItemId);
    }

    private static ProductionBonusDto? CreateAppliedProductionBonus(CompanyProductionStartRequest? request)
    {
        return CreateAppliedProductionBonus(
            request?.OutputBonusPercent,
            request?.BonusSourceRegionId,
            request?.BonusSourceRegionName,
            request?.BonusResourceName,
            request?.BonusItemId);
    }

    private static ProductionBonusDto? CreateAppliedProductionBonus(
        int? outputBonusPercent,
        string? sourceRegionId,
        string? sourceRegionName,
        string? resourceName,
        string? itemId)
    {
        var percent = Math.Clamp(outputBonusPercent ?? 0, 0, 50);
        if (percent <= 0)
        {
            return null;
        }

        return new ProductionBonusDto(
            ProductionBonusPercent: percent,
            SourceRegionId: NormalizeId(sourceRegionId),
            SourceRegionName: string.IsNullOrWhiteSpace(sourceRegionName) ? "Controlled region" : sourceRegionName.Trim(),
            ResourceName: string.IsNullOrWhiteSpace(resourceName) ? "Regional resource" : resourceName.Trim(),
            ItemId: NormalizeId(itemId));
    }

    private static int ApplyProductionBonus(int outputQuantity, ProductionBonusDto? bonus)
    {
        if (bonus is null || bonus.ProductionBonusPercent <= 0)
        {
            return outputQuantity;
        }

        var boosted = (int)Math.Ceiling(outputQuantity * (100 + bonus.ProductionBonusPercent) / 100m);
        return Math.Max(outputQuantity + 1, boosted);
    }

    private static string BuildProductionNote(
        string baseNote,
        ProductionBonusDto? bonus,
        int productivityBonusPercent = 0)
    {
        var parts = new List<string> { baseNote };
        if (productivityBonusPercent > 0)
        {
            parts.Add($"Company productivity bonus: +{productivityBonusPercent}%.");
        }

        if (bonus is not null)
        {
            parts.Add($"{bonus.ResourceName} in {bonus.SourceRegionName} added +{bonus.ProductionBonusPercent}% regional output.");
        }

        return string.Join(' ', parts);
    }

    private static void AddProductionBonusParameters(NpgsqlCommand command, ProductionBonusDto? bonus)
    {
        command.Parameters.AddWithValue("production_bonus_percent", bonus?.ProductionBonusPercent ?? 0);
        command.Parameters.AddWithValue("bonus_source_region_id", bonus?.SourceRegionId ?? string.Empty);
        command.Parameters.AddWithValue("bonus_source_region_name", bonus?.SourceRegionName ?? string.Empty);
        command.Parameters.AddWithValue("bonus_resource_name", bonus?.ResourceName ?? string.Empty);
        command.Parameters.AddWithValue("bonus_item_id", bonus?.ItemId ?? string.Empty);
    }

    private static string ToDisplayName(string itemId)
    {
        var words = itemId.Split(['-', '_'], StringSplitOptions.RemoveEmptyEntries)
            .Select(word => char.ToUpperInvariant(word[0]) + word[1..]);
        return string.Join(' ', words);
    }

    private static string ToItemCategory(string itemId, string fallback)
    {
        if (itemId.StartsWith("weapon", StringComparison.OrdinalIgnoreCase))
        {
            return "Weapon";
        }

        if (string.Equals(itemId, "food", StringComparison.OrdinalIgnoreCase))
        {
            return "Consumable";
        }

        return string.IsNullOrWhiteSpace(fallback) ? "Material" : fallback;
    }

    private static string? NormalizeCompanyName(string? name)
    {
        var normalized = string.Join(
            ' ',
            (name ?? string.Empty)
                .Trim()
                .Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return normalized.Length is < 3 or > 48 ? null : normalized;
    }

    private static string NormalizeCompanyDescription(string? description)
    {
        var normalized = string.Join(
            ' ',
            (description ?? string.Empty)
                .Trim()
                .Split(' ', StringSplitOptions.RemoveEmptyEntries));
        if (normalized.Length > 240)
        {
            normalized = normalized[..240];
        }

        return string.IsNullOrWhiteSpace(normalized)
            ? "A newly founded player company."
            : normalized;
    }

    private static string? NormalizeCompanyRole(string? role)
    {
        var normalized = (role ?? string.Empty).Trim().ToLowerInvariant();
        return normalized is "owner" or "manager" or "member" ? normalized : null;
    }

    private static bool CanManageCompany(string? role)
    {
        return role is "owner" or "manager";
    }

    private static int GetProductionDurationSeconds(int factoryLevel)
    {
        return Math.Max(
            MinimumProductionDurationSeconds,
            BaseProductionDurationSeconds - ((factoryLevel - 1) * LevelDurationReductionSeconds));
    }

    private static string NormalizePlayerId(string? playerId)
    {
        return (playerId ?? string.Empty).Trim().ToLowerInvariant();
    }

    private static string NormalizeId(string? value)
    {
        return (value ?? string.Empty).Trim().ToLowerInvariant();
    }
}

internal static class FactoryCatalog
{
    public static FactoryTemplate[] All { get; } =
    [
        new FactoryTemplate("food-factory", "Food Factory", "Food", 1, "grain", 5, "food", 3),
        new FactoryTemplate("weapon-workshop", "Weapon Workshop", "Weapon", 1, "iron", 4, "weapon_q1", 1)
    ];
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record FactoryPortfolioResponse(
    string PlayerId,
    FactoryDto[] Factories,
    DateTimeOffset UpdatedAt);

internal sealed record ProductionJobsResponse(
    string PlayerId,
    ProductionJobDto[] Jobs,
    DateTimeOffset UpdatedAt);

internal sealed record FactoryDto(
    string FactoryId,
    string Name,
    string Category,
    int Level,
    string InputItemId,
    int InputQuantity,
    string OutputItemId,
    int OutputQuantity,
    bool CanProduce,
    int ProductionCount,
    DateTimeOffset? LastProducedAt,
    DateTimeOffset? CooldownUntil,
    int ProductionDurationSeconds,
    string? ActiveJobId,
    int QueueDepth,
    int MaxQueueDepth,
    ProductionBonusDto? ResourceEffect = null);

internal sealed record ProductionJobDto(
    string JobId,
    string PlayerId,
    string FactoryId,
    string Status,
    string InputItemId,
    string InputItemName,
    string InputItemCategory,
    int InputQuantity,
    string OutputItemId,
    string OutputItemName,
    string OutputItemCategory,
    int OutputQuantity,
    int DurationSeconds,
    DateTimeOffset StartedAt,
    DateTimeOffset CompletesAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? ClaimedAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    bool CanClaim,
    ProductionBonusDto? AppliedBonus = null);

internal sealed record ProductionResult(
    bool Completed,
    string FactoryId,
    string Message,
    string ConsumedItemId,
    int ConsumedQuantity,
    string ProducedItemId,
    int ProducedQuantity,
    string Note,
    DateTimeOffset CompletedAt,
    int ProductionCount,
    DateTimeOffset LastProducedAt,
    ProductionJobDto? Job = null,
    DateTimeOffset? StartedAt = null,
    DateTimeOffset? CompletesAt = null,
    ProductionBonusDto? AppliedBonus = null);

internal sealed record ProductionBonusDto(
    int ProductionBonusPercent,
    string SourceRegionId,
    string SourceRegionName,
    string ResourceName,
    string ItemId);

internal sealed record ProductionClaimTicket(
    bool ReadyToClaim,
    bool AlreadyClaimed,
    string Message,
    ProductionJobDto Job);

internal sealed record ProductionClaimCompletion(
    bool Completed,
    bool AlreadyClaimed,
    string Message,
    ProductionJobDto Job,
    int ProductionCount);

internal sealed record ProductionJobCancellationRequest(string? Reason);

internal sealed record FactoryUpgradeQuote(
    string FactoryId,
    int CurrentLevel,
    int NextLevel,
    int GoldCost,
    string RequiredItemId,
    string RequiredItemName,
    int RequiredItemQuantity,
    int OutputQuantityAfterUpgrade,
    bool CanUpgrade);

internal sealed record FactoryUpgradeResult(
    bool Upgraded,
    string FactoryId,
    string Message,
    FactoryDto Factory,
    FactoryUpgradeQuote AppliedQuote,
    DateTimeOffset UpgradedAt);

internal sealed record CreateCompanyRequest(string? Name, string? Description);

internal sealed record CompanyActorRequest(string? ActorPlayerId);

internal sealed record ProductionStartRequest(
    int? OutputBonusPercent = null,
    string? BonusSourceRegionId = null,
    string? BonusSourceRegionName = null,
    string? BonusResourceName = null,
    string? BonusItemId = null);

internal sealed record CompanyProductionStartRequest(
    string? ActorPlayerId,
    int? OutputBonusPercent = null,
    string? BonusSourceRegionId = null,
    string? BonusSourceRegionName = null,
    string? BonusResourceName = null,
    string? BonusItemId = null);

internal sealed record CompanyMemberRoleRequest(string? ActorPlayerId, string? Role);

internal sealed record CompanyPortfolioResponse(
    string PlayerId,
    CompanySummaryDto[] Companies,
    DateTimeOffset UpdatedAt);

internal sealed record CompanySummaryDto(
    string CompanyId,
    string Name,
    string Description,
    string OwnerPlayerId,
    int WalletGold,
    int StorageUsed,
    int StorageLimit,
    int HqLevel,
    string Specialization,
    int FactorySlots,
    int ProductivityBonusPercent,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    int MemberCount,
    int FactoryCount,
    string? Role,
    bool IsMember,
    bool CanManage,
    CompanyPermissionsDto Permissions);

internal sealed record CompanyDetailDto(
    string CompanyId,
    string Name,
    string Description,
    string OwnerPlayerId,
    int WalletGold,
    int StorageUsed,
    int StorageLimit,
    int HqLevel,
    string Specialization,
    int FactorySlots,
    int ProductivityBonusPercent,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    int MemberCount,
    int FactoryCount,
    string? Role,
    bool IsMember,
    bool CanManage,
    CompanyPermissionsDto Permissions,
    CompanyMemberDto[] Members,
    CompanyAssetsDto Assets);

internal sealed record CompanyMemberDto(
    string PlayerId,
    string Role,
    DateTimeOffset JoinedAt,
    bool CanManage);

internal sealed record CompanyMembersResponse(
    string CompanyId,
    CompanyMemberDto[] Members,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyAssetsDto(
    string CompanyId,
    int WalletGold,
    int StorageUsed,
    int StorageLimit,
    CompanyUpgradeStateDto Upgrades,
    CompanyInventoryItemDto[] Inventory,
    FactoryDto[] Factories,
    ProductionJobDto[] ProductionJobs,
    CompanyJobPostingDto[] WorkforceJobs,
    CompanyWorkRecordDto[] WorkRecords,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyInventoryItemDto(
    string ItemId,
    string Name,
    string Category,
    int Quantity,
    string Description);

internal sealed record CompanyMutationResponse(
    bool Completed,
    string Message,
    CompanyDetailDto? Company);

internal sealed record CompanyProductionClaimResult(
    bool Completed,
    string Message,
    ProductionClaimCompletion Claim,
    CompanyAssetsDto Assets);

internal sealed record CompanyInventorySeed(
    string ItemId,
    string Name,
    string Category,
    int Quantity,
    string Description);

internal sealed record FactoryTemplate(
    string FactoryId,
    string Name,
    string Category,
    int Level,
    string InputItemId,
    int InputQuantity,
    string OutputItemId,
    int OutputQuantity);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

internal sealed record StoreResult<T>(T? Value, string? Message, int StatusCode) where T : class
{
    public static StoreResult<T> FromError<TOther>(StoreResult<TOther> other) where TOther : class
    {
        return new StoreResult<T>(null, other.Message, other.StatusCode);
    }

    public static StoreResult<T> Ok(T value)
    {
        return new StoreResult<T>(value, null, StatusCodes.Status200OK);
    }

    public static StoreResult<T> Accepted(T value)
    {
        return new StoreResult<T>(value, null, StatusCodes.Status202Accepted);
    }

    public static StoreResult<T> NotFound(string message)
    {
        return new StoreResult<T>(null, message, StatusCodes.Status404NotFound);
    }

    public static StoreResult<T> BadRequest(string message)
    {
        return new StoreResult<T>(null, message, StatusCodes.Status400BadRequest);
    }

    public static StoreResult<T> Forbidden(string message)
    {
        return new StoreResult<T>(null, message, StatusCodes.Status403Forbidden);
    }

    public static StoreResult<T> Conflict(string message)
    {
        return new StoreResult<T>(null, message, StatusCodes.Status409Conflict);
    }
}

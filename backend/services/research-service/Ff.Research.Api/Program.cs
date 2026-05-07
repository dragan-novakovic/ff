using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<ResearchStore>();

var metadata = new ServiceMetadata(
    Service: "research-service",
    DisplayName: "Research Service",
    Domain: "Persistent country and company technology trees",
    Description: "Owns research catalogs, progress, point budgets, completion state, and active technology bonuses.",
    Owns: ["technology catalogs", "research projects", "research points", "technology bonuses"],
    Responsibilities: ["Persist tech-tree state", "Enforce research transitions", "Publish active bonus totals for other services"]);

var app = builder.Build();

var researchStore = app.Services.GetRequiredService<ResearchStore>();
await researchStore.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/research/technologies", async (string? scopeType, ResearchStore research) =>
{
    var result = await research.GetTechnologiesAsync(scopeType);
    return ToStoreResult(result);
}).WithName("GetResearchTechnologies");

app.MapGet("/research/scopes/{scopeType}/{scopeId}", async (
    string scopeType,
    string scopeId,
    string? actorPlayerId,
    ResearchStore research) =>
{
    var result = await research.GetScopeStateAsync(scopeType, scopeId, actorPlayerId);
    return ToStoreResult(result);
}).WithName("GetResearchScope");

app.MapGet("/research/scopes/{scopeType}/{scopeId}/bonuses", async (
    string scopeType,
    string scopeId,
    ResearchStore research) =>
{
    var result = await research.GetScopeBonusesAsync(scopeType, scopeId);
    return ToStoreResult(result);
}).WithName("GetResearchScopeBonuses");

app.MapPost("/research/scopes/{scopeType}/{scopeId}/technologies/{technologyId}/start", async (
    string scopeType,
    string scopeId,
    string technologyId,
    ResearchMutationRequest request,
    ResearchStore research) =>
{
    var result = await research.StartResearchAsync(scopeType, scopeId, technologyId, request);
    return ToStoreResult(result);
}).WithName("StartResearch");

app.MapPost("/research/scopes/{scopeType}/{scopeId}/projects/{projectId}/contribute", async (
    string scopeType,
    string scopeId,
    string projectId,
    ResearchContributionRequest request,
    ResearchStore research) =>
{
    var result = await research.ContributeResearchAsync(scopeType, scopeId, projectId, request);
    return ToStoreResult(result);
}).WithName("ContributeResearch");

app.MapPost("/research/scopes/{scopeType}/{scopeId}/projects/{projectId}/complete", async (
    string scopeType,
    string scopeId,
    string projectId,
    ResearchMutationRequest request,
    ResearchStore research) =>
{
    var result = await research.CompleteResearchAsync(scopeType, scopeId, projectId, request);
    return ToStoreResult(result);
}).WithName("CompleteResearch");

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

internal sealed class ResearchStore : IDisposable
{
    private const string CountryScope = "country";
    private const string CompanyScope = "company";
    private const string ProductionSpeedBonus = "production_speed_percent";

    private readonly NpgsqlDataSource _dataSource;

    public ResearchStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_RESEARCH_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Research")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS research;

            CREATE TABLE IF NOT EXISTS research.technologies (
                tech_id text PRIMARY KEY,
                scope_type text NOT NULL,
                track text NOT NULL,
                name text NOT NULL,
                description text NOT NULL,
                tier integer NOT NULL,
                prerequisite_tech_ids text NOT NULL DEFAULT '',
                required_points integer NOT NULL,
                duration_seconds integer NOT NULL,
                bonus_type text NOT NULL,
                bonus_value integer NOT NULL,
                bonus_target text NOT NULL,
                bonus_description text NOT NULL,
                sort_order integer NOT NULL,
                is_active boolean NOT NULL DEFAULT true,
                updated_at timestamptz NOT NULL,
                CONSTRAINT technologies_scope_check CHECK (scope_type IN ('country', 'company')),
                CONSTRAINT technologies_cost_check CHECK (required_points > 0 AND duration_seconds >= 0)
            );

            CREATE TABLE IF NOT EXISTS research.scope_accounts (
                scope_type text NOT NULL,
                scope_id text NOT NULL,
                available_points integer NOT NULL,
                lifetime_points integer NOT NULL,
                point_cap integer NOT NULL,
                hourly_point_rate integer NOT NULL,
                last_accrued_at timestamptz NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (scope_type, scope_id),
                CONSTRAINT scope_accounts_scope_check CHECK (scope_type IN ('country', 'company')),
                CONSTRAINT scope_accounts_points_check CHECK (available_points >= 0 AND lifetime_points >= 0)
            );

            CREATE TABLE IF NOT EXISTS research.research_projects (
                project_id text PRIMARY KEY,
                scope_type text NOT NULL,
                scope_id text NOT NULL,
                tech_id text NOT NULL REFERENCES research.technologies (tech_id),
                status text NOT NULL,
                required_points integer NOT NULL,
                contributed_points integer NOT NULL,
                duration_seconds integer NOT NULL,
                started_at timestamptz NOT NULL,
                ready_at timestamptz NOT NULL,
                completed_at timestamptz NULL,
                started_by_player_id text NOT NULL,
                completed_by_player_id text NULL,
                start_idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT research_projects_scope_check CHECK (scope_type IN ('country', 'company')),
                CONSTRAINT research_projects_status_check CHECK (status IN ('active', 'completed', 'cancelled')),
                CONSTRAINT research_projects_points_check CHECK (required_points > 0 AND contributed_points >= 0)
            );

            CREATE UNIQUE INDEX IF NOT EXISTS research_projects_scope_tech_open_idx
            ON research.research_projects (scope_type, scope_id, tech_id)
            WHERE status IN ('active', 'completed');

            CREATE TABLE IF NOT EXISTS research.research_contributions (
                contribution_id text PRIMARY KEY,
                project_id text NOT NULL REFERENCES research.research_projects (project_id) ON DELETE CASCADE,
                scope_type text NOT NULL,
                scope_id text NOT NULL,
                tech_id text NOT NULL,
                actor_player_id text NOT NULL,
                points integer NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL,
                CONSTRAINT research_contributions_points_check CHECK (points > 0)
            );

            CREATE TABLE IF NOT EXISTS research.completed_technologies (
                scope_type text NOT NULL,
                scope_id text NOT NULL,
                tech_id text NOT NULL REFERENCES research.technologies (tech_id),
                project_id text NOT NULL,
                completed_by_player_id text NOT NULL,
                completed_at timestamptz NOT NULL,
                PRIMARY KEY (scope_type, scope_id, tech_id)
            );

            CREATE TABLE IF NOT EXISTS research.research_completion_events (
                event_id text PRIMARY KEY,
                scope_type text NOT NULL,
                scope_id text NOT NULL,
                tech_id text NOT NULL,
                project_id text NOT NULL,
                actor_player_id text NOT NULL,
                idempotency_key text NOT NULL UNIQUE,
                created_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS research.scope_bonus_totals (
                scope_type text NOT NULL,
                scope_id text NOT NULL,
                bonus_type text NOT NULL,
                bonus_target text NOT NULL,
                total_value integer NOT NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (scope_type, scope_id, bonus_type, bonus_target)
            );

            CREATE INDEX IF NOT EXISTS research_projects_scope_status_idx
            ON research.research_projects (scope_type, scope_id, status, updated_at DESC);

            CREATE INDEX IF NOT EXISTS completed_technologies_scope_idx
            ON research.completed_technologies (scope_type, scope_id, completed_at DESC);

            CREATE INDEX IF NOT EXISTS scope_bonus_totals_lookup_idx
            ON research.scope_bonus_totals (scope_type, scope_id, bonus_type);
            """;

        await using (var command = _dataSource.CreateCommand(sql))
        {
            await command.ExecuteNonQueryAsync();
        }

        await SeedTechnologyCatalogAsync();
    }

    public async Task<StoreResult<ResearchTechnologyCatalogDto>> GetTechnologiesAsync(string? scopeType)
    {
        var normalizedScopeType = NormalizeScopeType(scopeType);
        if (!string.IsNullOrWhiteSpace(scopeType) && normalizedScopeType is null)
        {
            return StoreResult<ResearchTechnologyCatalogDto>.BadRequest("Scope type must be country or company.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var technologies = await ReadTechnologiesAsync(connection, null, normalizedScopeType);
        return StoreResult<ResearchTechnologyCatalogDto>.Ok(new ResearchTechnologyCatalogDto(
            ScopeType: normalizedScopeType,
            Technologies: technologies.Select(ToTechnologyDto).ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ResearchScopeStateDto>> GetScopeStateAsync(
        string scopeType,
        string scopeId,
        string? actorPlayerId)
    {
        var normalizedScopeType = NormalizeScopeType(scopeType);
        var normalizedScopeId = NormalizeId(scopeId);
        if (normalizedScopeType is null || string.IsNullOrWhiteSpace(normalizedScopeId))
        {
            return StoreResult<ResearchScopeStateDto>.BadRequest("Research scope must be a country or company id.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var state = await BuildScopeStateAsync(
            connection,
            transaction,
            normalizedScopeType,
            normalizedScopeId,
            NormalizePlayerId(actorPlayerId),
            DateTimeOffset.UtcNow);
        await transaction.CommitAsync();
        return StoreResult<ResearchScopeStateDto>.Ok(state);
    }

    public async Task<StoreResult<ResearchBonusListDto>> GetScopeBonusesAsync(string scopeType, string scopeId)
    {
        var normalizedScopeType = NormalizeScopeType(scopeType);
        var normalizedScopeId = NormalizeId(scopeId);
        if (normalizedScopeType is null || string.IsNullOrWhiteSpace(normalizedScopeId))
        {
            return StoreResult<ResearchBonusListDto>.BadRequest("Research scope must be a country or company id.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        var bonuses = await ReadBonusesAsync(connection, null, normalizedScopeType, normalizedScopeId);
        return StoreResult<ResearchBonusListDto>.Ok(new ResearchBonusListDto(
            ScopeType: normalizedScopeType,
            ScopeId: normalizedScopeId,
            Bonuses: bonuses.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<ResearchMutationResponse>> StartResearchAsync(
        string scopeType,
        string scopeId,
        string technologyId,
        ResearchMutationRequest request)
    {
        var normalizedScopeType = NormalizeScopeType(scopeType);
        var normalizedScopeId = NormalizeId(scopeId);
        var normalizedTechnologyId = NormalizeId(technologyId);
        var actorPlayerId = NormalizePlayerId(request.ActorPlayerId);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey);
        if (normalizedScopeType is null ||
            string.IsNullOrWhiteSpace(normalizedScopeId) ||
            string.IsNullOrWhiteSpace(normalizedTechnologyId))
        {
            return StoreResult<ResearchMutationResponse>.BadRequest("Research scope and technology are required.");
        }

        if (string.IsNullOrWhiteSpace(actorPlayerId) || string.IsNullOrWhiteSpace(idempotencyKey))
        {
            return StoreResult<ResearchMutationResponse>.BadRequest("Actor player id and idempotency key are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        await EnsureAccountAsync(connection, transaction, normalizedScopeType, normalizedScopeId, now);

        var idempotentProject = await ReadProjectByStartIdempotencyAsync(connection, transaction, idempotencyKey);
        if (idempotentProject is not null)
        {
            if (!Matches(idempotentProject, normalizedScopeType, normalizedScopeId, normalizedTechnologyId))
            {
                await transaction.RollbackAsync();
                return StoreResult<ResearchMutationResponse>.Conflict("Idempotency key was already used for another research project.");
            }

            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                idempotentProject.ProjectId,
                true,
                "Research project was already started.");
        }

        var technology = await ReadTechnologyAsync(connection, transaction, normalizedScopeType, normalizedTechnologyId);
        if (technology is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ResearchMutationResponse>.NotFound("Technology was not found for this research scope.");
        }

        var completedTechIds = await ReadCompletedTechIdsAsync(connection, transaction, normalizedScopeType, normalizedScopeId);
        if (completedTechIds.Contains(normalizedTechnologyId))
        {
            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                null,
                true,
                $"{technology.Name} is already completed.");
        }

        var existingProject = await ReadOpenProjectByTechnologyAsync(
            connection,
            transaction,
            normalizedScopeType,
            normalizedScopeId,
            normalizedTechnologyId);
        if (existingProject is not null)
        {
            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                existingProject.ProjectId,
                true,
                $"{technology.Name} research is already active.");
        }

        var missingPrerequisites = technology.PrerequisiteTechIds
            .Where(prerequisite => !completedTechIds.Contains(prerequisite))
            .ToArray();
        if (missingPrerequisites.Length > 0)
        {
            await transaction.RollbackAsync();
            return StoreResult<ResearchMutationResponse>.Conflict(
                $"Missing prerequisite technology: {string.Join(", ", missingPrerequisites)}.");
        }

        var projectId = $"rproj-{Guid.NewGuid():N}";
        await using (var insert = new NpgsqlCommand("""
            INSERT INTO research.research_projects (
                project_id, scope_type, scope_id, tech_id, status,
                required_points, contributed_points, duration_seconds,
                started_at, ready_at, started_by_player_id, start_idempotency_key,
                created_at, updated_at
            )
            VALUES (
                @project_id, @scope_type, @scope_id, @tech_id, 'active',
                @required_points, 0, @duration_seconds,
                @started_at, @ready_at, @started_by_player_id, @start_idempotency_key,
                @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("project_id", projectId);
            insert.Parameters.AddWithValue("scope_type", normalizedScopeType);
            insert.Parameters.AddWithValue("scope_id", normalizedScopeId);
            insert.Parameters.AddWithValue("tech_id", technology.TechId);
            insert.Parameters.AddWithValue("required_points", technology.RequiredPoints);
            insert.Parameters.AddWithValue("duration_seconds", technology.DurationSeconds);
            insert.Parameters.AddWithValue("started_at", now);
            insert.Parameters.AddWithValue("ready_at", now.AddSeconds(technology.DurationSeconds));
            insert.Parameters.AddWithValue("started_by_player_id", actorPlayerId);
            insert.Parameters.AddWithValue("start_idempotency_key", idempotencyKey);
            insert.Parameters.AddWithValue("created_at", now);
            insert.Parameters.AddWithValue("updated_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
        return await MutationWithStateAsync(
            normalizedScopeType,
            normalizedScopeId,
            actorPlayerId,
            projectId,
            true,
            $"{technology.Name} research started. Contribute points and wait until the project is ready.");
    }

    public async Task<StoreResult<ResearchMutationResponse>> ContributeResearchAsync(
        string scopeType,
        string scopeId,
        string projectId,
        ResearchContributionRequest request)
    {
        var normalizedScopeType = NormalizeScopeType(scopeType);
        var normalizedScopeId = NormalizeId(scopeId);
        var normalizedProjectId = NormalizeId(projectId);
        var actorPlayerId = NormalizePlayerId(request.ActorPlayerId);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey);
        if (normalizedScopeType is null ||
            string.IsNullOrWhiteSpace(normalizedScopeId) ||
            string.IsNullOrWhiteSpace(normalizedProjectId))
        {
            return StoreResult<ResearchMutationResponse>.BadRequest("Research scope and project are required.");
        }

        if (string.IsNullOrWhiteSpace(actorPlayerId) || string.IsNullOrWhiteSpace(idempotencyKey) || request.Points <= 0)
        {
            return StoreResult<ResearchMutationResponse>.BadRequest("Actor player id, positive points, and idempotency key are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var idempotentContribution = await ReadContributionByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (idempotentContribution is not null)
        {
            if (!string.Equals(idempotentContribution.ProjectId, normalizedProjectId, StringComparison.Ordinal))
            {
                await transaction.RollbackAsync();
                return StoreResult<ResearchMutationResponse>.Conflict("Idempotency key was already used for another research contribution.");
            }

            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                normalizedProjectId,
                true,
                "Research contribution was already applied.");
        }

        var project = await ReadProjectForUpdateAsync(
            connection,
            transaction,
            normalizedScopeType,
            normalizedScopeId,
            normalizedProjectId);
        if (project is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ResearchMutationResponse>.NotFound("Research project was not found.");
        }

        if (!string.Equals(project.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                project.ProjectId,
                true,
                "Research project is already completed.");
        }

        var remaining = Math.Max(0, project.RequiredPoints - project.ContributedPoints);
        if (remaining == 0)
        {
            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                project.ProjectId,
                true,
                "Research project is fully funded and ready for completion when its timer ends.");
        }

        var account = await EnsureAccountAsync(connection, transaction, normalizedScopeType, normalizedScopeId, now);
        var pointsToApply = Math.Min(request.Points, remaining);
        if (account.AvailablePoints < pointsToApply)
        {
            await transaction.RollbackAsync();
            return StoreResult<ResearchMutationResponse>.Conflict(
                $"Not enough research points. Required {pointsToApply}, available {account.AvailablePoints}.");
        }

        await using (var updateAccount = new NpgsqlCommand("""
            UPDATE research.scope_accounts
            SET available_points = available_points - @points,
                updated_at = @updated_at
            WHERE scope_type = @scope_type AND scope_id = @scope_id;
            """, connection, transaction))
        {
            updateAccount.Parameters.AddWithValue("scope_type", normalizedScopeType);
            updateAccount.Parameters.AddWithValue("scope_id", normalizedScopeId);
            updateAccount.Parameters.AddWithValue("points", pointsToApply);
            updateAccount.Parameters.AddWithValue("updated_at", now);
            await updateAccount.ExecuteNonQueryAsync();
        }

        await using (var insert = new NpgsqlCommand("""
            INSERT INTO research.research_contributions (
                contribution_id, project_id, scope_type, scope_id, tech_id,
                actor_player_id, points, idempotency_key, created_at
            )
            VALUES (
                @contribution_id, @project_id, @scope_type, @scope_id, @tech_id,
                @actor_player_id, @points, @idempotency_key, @created_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("contribution_id", $"rcon-{Guid.NewGuid():N}");
            insert.Parameters.AddWithValue("project_id", project.ProjectId);
            insert.Parameters.AddWithValue("scope_type", normalizedScopeType);
            insert.Parameters.AddWithValue("scope_id", normalizedScopeId);
            insert.Parameters.AddWithValue("tech_id", project.TechnologyId);
            insert.Parameters.AddWithValue("actor_player_id", actorPlayerId);
            insert.Parameters.AddWithValue("points", pointsToApply);
            insert.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            insert.Parameters.AddWithValue("created_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        await using (var updateProject = new NpgsqlCommand("""
            UPDATE research.research_projects
            SET contributed_points = contributed_points + @points,
                updated_at = @updated_at
            WHERE project_id = @project_id;
            """, connection, transaction))
        {
            updateProject.Parameters.AddWithValue("project_id", project.ProjectId);
            updateProject.Parameters.AddWithValue("points", pointsToApply);
            updateProject.Parameters.AddWithValue("updated_at", now);
            await updateProject.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
        return await MutationWithStateAsync(
            normalizedScopeType,
            normalizedScopeId,
            actorPlayerId,
            project.ProjectId,
            true,
            $"Contributed {pointsToApply} research points.");
    }

    public async Task<StoreResult<ResearchMutationResponse>> CompleteResearchAsync(
        string scopeType,
        string scopeId,
        string projectId,
        ResearchMutationRequest request)
    {
        var normalizedScopeType = NormalizeScopeType(scopeType);
        var normalizedScopeId = NormalizeId(scopeId);
        var normalizedProjectId = NormalizeId(projectId);
        var actorPlayerId = NormalizePlayerId(request.ActorPlayerId);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey);
        if (normalizedScopeType is null ||
            string.IsNullOrWhiteSpace(normalizedScopeId) ||
            string.IsNullOrWhiteSpace(normalizedProjectId))
        {
            return StoreResult<ResearchMutationResponse>.BadRequest("Research scope and project are required.");
        }

        if (string.IsNullOrWhiteSpace(actorPlayerId) || string.IsNullOrWhiteSpace(idempotencyKey))
        {
            return StoreResult<ResearchMutationResponse>.BadRequest("Actor player id and idempotency key are required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var completionEvent = await ReadCompletionEventByIdempotencyAsync(connection, transaction, idempotencyKey);
        if (completionEvent is not null)
        {
            if (!string.Equals(completionEvent.ProjectId, normalizedProjectId, StringComparison.Ordinal))
            {
                await transaction.RollbackAsync();
                return StoreResult<ResearchMutationResponse>.Conflict("Idempotency key was already used for another research completion.");
            }

            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                normalizedProjectId,
                true,
                "Research completion was already applied.");
        }

        var project = await ReadProjectForUpdateAsync(
            connection,
            transaction,
            normalizedScopeType,
            normalizedScopeId,
            normalizedProjectId);
        if (project is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<ResearchMutationResponse>.NotFound("Research project was not found.");
        }

        if (await IsTechnologyCompletedAsync(
            connection,
            transaction,
            normalizedScopeType,
            normalizedScopeId,
            project.TechnologyId))
        {
            await transaction.CommitAsync();
            return await MutationWithStateAsync(
                normalizedScopeType,
                normalizedScopeId,
                actorPlayerId,
                project.ProjectId,
                true,
                "Technology is already completed.");
        }

        if (project.ContributedPoints < project.RequiredPoints)
        {
            await transaction.RollbackAsync();
            return StoreResult<ResearchMutationResponse>.Conflict(
                $"Research needs {project.RequiredPoints - project.ContributedPoints} more points.");
        }

        if (project.ReadyAt > now)
        {
            await transaction.RollbackAsync();
            return StoreResult<ResearchMutationResponse>.Conflict(
                $"Research is still in progress until {project.ReadyAt:O}.");
        }

        await using (var complete = new NpgsqlCommand("""
            INSERT INTO research.completed_technologies (
                scope_type, scope_id, tech_id, project_id, completed_by_player_id, completed_at
            )
            VALUES (
                @scope_type, @scope_id, @tech_id, @project_id, @completed_by_player_id, @completed_at
            )
            ON CONFLICT (scope_type, scope_id, tech_id) DO NOTHING;

            UPDATE research.research_projects
            SET status = 'completed',
                completed_at = @completed_at,
                completed_by_player_id = @completed_by_player_id,
                updated_at = @completed_at
            WHERE project_id = @project_id
              AND status = 'active';

            INSERT INTO research.research_completion_events (
                event_id, scope_type, scope_id, tech_id, project_id, actor_player_id, idempotency_key, created_at
            )
            VALUES (
                @event_id, @scope_type, @scope_id, @tech_id, @project_id, @actor_player_id, @idempotency_key, @created_at
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
            """, connection, transaction))
        {
            complete.Parameters.AddWithValue("scope_type", normalizedScopeType);
            complete.Parameters.AddWithValue("scope_id", normalizedScopeId);
            complete.Parameters.AddWithValue("tech_id", project.TechnologyId);
            complete.Parameters.AddWithValue("project_id", project.ProjectId);
            complete.Parameters.AddWithValue("completed_by_player_id", actorPlayerId);
            complete.Parameters.AddWithValue("completed_at", now);
            complete.Parameters.AddWithValue("event_id", $"rce-{Guid.NewGuid():N}");
            complete.Parameters.AddWithValue("actor_player_id", actorPlayerId);
            complete.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            complete.Parameters.AddWithValue("created_at", now);
            await complete.ExecuteNonQueryAsync();
        }

        await RecalculateBonusTotalsAsync(connection, transaction, normalizedScopeType, normalizedScopeId, now);
        await transaction.CommitAsync();

        var technology = await ReadTechnologyByIdAsync(project.TechnologyId);
        return await MutationWithStateAsync(
            normalizedScopeType,
            normalizedScopeId,
            actorPlayerId,
            project.ProjectId,
            true,
            $"{technology?.Name ?? project.TechnologyId} completed. Bonuses are now active.");
    }

    private async Task<StoreResult<ResearchMutationResponse>> MutationWithStateAsync(
        string scopeType,
        string scopeId,
        string actorPlayerId,
        string? projectId,
        bool completed,
        string message)
    {
        var stateResult = await GetScopeStateAsync(scopeType, scopeId, actorPlayerId);
        if (stateResult.Value is null)
        {
            return StoreResult<ResearchMutationResponse>.FromError(stateResult);
        }

        var state = stateResult.Value;
        var project = projectId is null
            ? null
            : state.ActiveProjects.FirstOrDefault(candidate =>
                string.Equals(candidate.ProjectId, projectId, StringComparison.OrdinalIgnoreCase)) ??
              state.Technologies.Select(node => node.Project).FirstOrDefault(candidate =>
                  candidate is not null &&
                  string.Equals(candidate.ProjectId, projectId, StringComparison.OrdinalIgnoreCase));
        return StoreResult<ResearchMutationResponse>.Ok(new ResearchMutationResponse(
            Completed: completed,
            Message: message,
            Project: project,
            State: state,
            ActiveBonuses: state.Bonuses,
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    private async Task<ResearchScopeStateDto> BuildScopeStateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string scopeId,
        string actorPlayerId,
        DateTimeOffset now)
    {
        var account = await EnsureAccountAsync(connection, transaction, scopeType, scopeId, now);
        var technologies = await ReadTechnologiesAsync(connection, transaction, scopeType);
        var completedTechIds = await ReadCompletedTechIdsAsync(connection, transaction, scopeType, scopeId);
        var activeProjects = await ReadActiveProjectsAsync(connection, transaction, scopeType, scopeId, now);
        var activeByTechnology = activeProjects.ToDictionary(project => project.TechnologyId, StringComparer.OrdinalIgnoreCase);
        var bonuses = await ReadBonusesAsync(connection, transaction, scopeType, scopeId);
        var nodes = technologies.Select(technology =>
        {
            var isCompleted = completedTechIds.Contains(technology.TechId);
            activeByTechnology.TryGetValue(technology.TechId, out var project);
            var missing = technology.PrerequisiteTechIds
                .Where(prerequisite => !completedTechIds.Contains(prerequisite))
                .ToArray();
            var canStart = !isCompleted && project is null && missing.Length == 0;
            var status = isCompleted
                ? "completed"
                : project is not null
                    ? (project.CanComplete ? "ready" : "active")
                    : canStart
                        ? "available"
                        : "locked";
            return new ResearchTechnologyNodeDto(
                Technology: ToTechnologyDto(technology),
                Status: status,
                IsCompleted: isCompleted,
                CanStart: canStart,
                BlockedReason: isCompleted
                    ? "Completed."
                    : project is not null
                        ? "Research already active."
                        : missing.Length == 0
                            ? null
                            : $"Requires {string.Join(", ", missing)}.",
                Project: project);
        }).ToArray();

        return new ResearchScopeStateDto(
            ScopeType: scopeType,
            ScopeId: scopeId,
            ActorPlayerId: actorPlayerId,
            AvailablePoints: account.AvailablePoints,
            LifetimePoints: account.LifetimePoints,
            PointCap: account.PointCap,
            HourlyPointRate: account.HourlyPointRate,
            LastAccruedAt: account.LastAccruedAt,
            Technologies: nodes,
            ActiveProjects: activeProjects.ToArray(),
            CompletedTechnologyIds: completedTechIds.OrderBy(id => id, StringComparer.OrdinalIgnoreCase).ToArray(),
            Bonuses: bonuses.ToArray(),
            UpdatedAt: now);
    }

    private async Task SeedTechnologyCatalogAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        var now = DateTimeOffset.UtcNow;
        foreach (var technology in TechnologyCatalog.All)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO research.technologies (
                    tech_id, scope_type, track, name, description, tier,
                    prerequisite_tech_ids, required_points, duration_seconds,
                    bonus_type, bonus_value, bonus_target, bonus_description,
                    sort_order, is_active, updated_at
                )
                VALUES (
                    @tech_id, @scope_type, @track, @name, @description, @tier,
                    @prerequisite_tech_ids, @required_points, @duration_seconds,
                    @bonus_type, @bonus_value, @bonus_target, @bonus_description,
                    @sort_order, true, @updated_at
                )
                ON CONFLICT (tech_id) DO UPDATE
                SET scope_type = EXCLUDED.scope_type,
                    track = EXCLUDED.track,
                    name = EXCLUDED.name,
                    description = EXCLUDED.description,
                    tier = EXCLUDED.tier,
                    prerequisite_tech_ids = EXCLUDED.prerequisite_tech_ids,
                    required_points = EXCLUDED.required_points,
                    duration_seconds = EXCLUDED.duration_seconds,
                    bonus_type = EXCLUDED.bonus_type,
                    bonus_value = EXCLUDED.bonus_value,
                    bonus_target = EXCLUDED.bonus_target,
                    bonus_description = EXCLUDED.bonus_description,
                    sort_order = EXCLUDED.sort_order,
                    is_active = true,
                    updated_at = EXCLUDED.updated_at;
                """, connection);
            command.Parameters.AddWithValue("tech_id", technology.TechId);
            command.Parameters.AddWithValue("scope_type", technology.ScopeType);
            command.Parameters.AddWithValue("track", technology.Track);
            command.Parameters.AddWithValue("name", technology.Name);
            command.Parameters.AddWithValue("description", technology.Description);
            command.Parameters.AddWithValue("tier", technology.Tier);
            command.Parameters.AddWithValue("prerequisite_tech_ids", string.Join(',', technology.PrerequisiteTechIds));
            command.Parameters.AddWithValue("required_points", technology.RequiredPoints);
            command.Parameters.AddWithValue("duration_seconds", technology.DurationSeconds);
            command.Parameters.AddWithValue("bonus_type", technology.BonusType);
            command.Parameters.AddWithValue("bonus_value", technology.BonusValue);
            command.Parameters.AddWithValue("bonus_target", technology.BonusTarget);
            command.Parameters.AddWithValue("bonus_description", technology.BonusDescription);
            command.Parameters.AddWithValue("sort_order", technology.SortOrder);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }
    }

    private async Task<ResearchAccountRecord> EnsureAccountAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string scopeId,
        DateTimeOffset now)
    {
        var rules = GetPointRules(scopeType);
        await using (var insert = new NpgsqlCommand("""
            INSERT INTO research.scope_accounts (
                scope_type, scope_id, available_points, lifetime_points, point_cap,
                hourly_point_rate, last_accrued_at, created_at, updated_at
            )
            VALUES (
                @scope_type, @scope_id, @available_points, @lifetime_points, @point_cap,
                @hourly_point_rate, @last_accrued_at, @created_at, @updated_at
            )
            ON CONFLICT (scope_type, scope_id) DO NOTHING;
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("scope_type", scopeType);
            insert.Parameters.AddWithValue("scope_id", scopeId);
            insert.Parameters.AddWithValue("available_points", rules.InitialPoints);
            insert.Parameters.AddWithValue("lifetime_points", rules.InitialPoints);
            insert.Parameters.AddWithValue("point_cap", rules.PointCap);
            insert.Parameters.AddWithValue("hourly_point_rate", rules.HourlyPointRate);
            insert.Parameters.AddWithValue("last_accrued_at", now);
            insert.Parameters.AddWithValue("created_at", now);
            insert.Parameters.AddWithValue("updated_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        var account = await ReadAccountForUpdateAsync(connection, transaction, scopeType, scopeId);
        var elapsedHours = account.LastAccruedAt >= now
            ? 0
            : (int)Math.Floor((now - account.LastAccruedAt).TotalHours);
        if (elapsedHours <= 0)
        {
            return account;
        }

        var accrued = elapsedHours * Math.Max(0, account.HourlyPointRate);
        var updatedAvailable = Math.Min(account.PointCap, account.AvailablePoints + accrued);
        var lifetimeDelta = Math.Max(0, updatedAvailable - account.AvailablePoints);
        await using (var update = new NpgsqlCommand("""
            UPDATE research.scope_accounts
            SET available_points = @available_points,
                lifetime_points = lifetime_points + @lifetime_delta,
                point_cap = @point_cap,
                hourly_point_rate = @hourly_point_rate,
                last_accrued_at = @last_accrued_at,
                updated_at = @updated_at
            WHERE scope_type = @scope_type AND scope_id = @scope_id;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("scope_type", scopeType);
            update.Parameters.AddWithValue("scope_id", scopeId);
            update.Parameters.AddWithValue("available_points", updatedAvailable);
            update.Parameters.AddWithValue("lifetime_delta", lifetimeDelta);
            update.Parameters.AddWithValue("point_cap", rules.PointCap);
            update.Parameters.AddWithValue("hourly_point_rate", rules.HourlyPointRate);
            update.Parameters.AddWithValue("last_accrued_at", now);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        return account with
        {
            AvailablePoints = updatedAvailable,
            LifetimePoints = account.LifetimePoints + lifetimeDelta,
            PointCap = rules.PointCap,
            HourlyPointRate = rules.HourlyPointRate,
            LastAccruedAt = now,
            UpdatedAt = now
        };
    }

    private static async Task<ResearchAccountRecord> ReadAccountForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string scopeId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT scope_type, scope_id, available_points, lifetime_points, point_cap,
                   hourly_point_rate, last_accrued_at, created_at, updated_at
            FROM research.scope_accounts
            WHERE scope_type = @scope_type AND scope_id = @scope_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException("Research account was not created.");
        }

        return new ResearchAccountRecord(
            ScopeType: reader.GetString(0),
            ScopeId: reader.GetString(1),
            AvailablePoints: reader.GetInt32(2),
            LifetimePoints: reader.GetInt32(3),
            PointCap: reader.GetInt32(4),
            HourlyPointRate: reader.GetInt32(5),
            LastAccruedAt: reader.GetFieldValue<DateTimeOffset>(6),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(7),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(8));
    }

    private static async Task<List<TechnologyRecord>> ReadTechnologiesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? scopeType)
    {
        var sql = """
            SELECT tech_id, scope_type, track, name, description, tier,
                   prerequisite_tech_ids, required_points, duration_seconds,
                   bonus_type, bonus_value, bonus_target, bonus_description,
                   sort_order, updated_at
            FROM research.technologies
            WHERE is_active = true
            """;
        if (!string.IsNullOrWhiteSpace(scopeType))
        {
            sql += " AND scope_type = @scope_type";
        }

        sql += " ORDER BY scope_type, sort_order, tier, track, name;";
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        if (!string.IsNullOrWhiteSpace(scopeType))
        {
            command.Parameters.AddWithValue("scope_type", scopeType);
        }

        var technologies = new List<TechnologyRecord>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            technologies.Add(ReadTechnology(reader));
        }

        return technologies;
    }

    private static async Task<TechnologyRecord?> ReadTechnologyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string technologyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT tech_id, scope_type, track, name, description, tier,
                   prerequisite_tech_ids, required_points, duration_seconds,
                   bonus_type, bonus_value, bonus_target, bonus_description,
                   sort_order, updated_at
            FROM research.technologies
            WHERE scope_type = @scope_type
              AND tech_id = @tech_id
              AND is_active = true;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("tech_id", technologyId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTechnology(reader) : null;
    }

    private async Task<TechnologyRecord?> ReadTechnologyByIdAsync(string technologyId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT tech_id, scope_type, track, name, description, tier,
                   prerequisite_tech_ids, required_points, duration_seconds,
                   bonus_type, bonus_value, bonus_target, bonus_description,
                   sort_order, updated_at
            FROM research.technologies
            WHERE tech_id = @tech_id;
            """, connection);
        command.Parameters.AddWithValue("tech_id", technologyId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadTechnology(reader) : null;
    }

    private static TechnologyRecord ReadTechnology(NpgsqlDataReader reader)
    {
        return new TechnologyRecord(
            TechId: reader.GetString(0),
            ScopeType: reader.GetString(1),
            Track: reader.GetString(2),
            Name: reader.GetString(3),
            Description: reader.GetString(4),
            Tier: reader.GetInt32(5),
            PrerequisiteTechIds: SplitPrerequisites(reader.GetString(6)),
            RequiredPoints: reader.GetInt32(7),
            DurationSeconds: reader.GetInt32(8),
            BonusType: reader.GetString(9),
            BonusValue: reader.GetInt32(10),
            BonusTarget: reader.GetString(11),
            BonusDescription: reader.GetString(12),
            SortOrder: reader.GetInt32(13),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(14));
    }

    private static async Task<HashSet<string>> ReadCompletedTechIdsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string scopeType,
        string scopeId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT tech_id
            FROM research.completed_technologies
            WHERE scope_type = @scope_type AND scope_id = @scope_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);

        var completed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            completed.Add(reader.GetString(0));
        }

        return completed;
    }

    private static async Task<List<ResearchProjectDto>> ReadActiveProjectsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string scopeType,
        string scopeId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            SELECT project_id, scope_type, scope_id, tech_id, status,
                   required_points, contributed_points, duration_seconds,
                   started_at, ready_at, completed_at, started_by_player_id,
                   completed_by_player_id, created_at, updated_at
            FROM research.research_projects
            WHERE scope_type = @scope_type
              AND scope_id = @scope_id
              AND status = 'active'
            ORDER BY ready_at, started_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);

        var projects = new List<ResearchProjectDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            projects.Add(ToProjectDto(ReadProject(reader), now));
        }

        return projects;
    }

    private static async Task<ProjectRecord?> ReadProjectByStartIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT project_id, scope_type, scope_id, tech_id, status,
                   required_points, contributed_points, duration_seconds,
                   started_at, ready_at, completed_at, started_by_player_id,
                   completed_by_player_id, created_at, updated_at
            FROM research.research_projects
            WHERE start_idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadProject(reader) : null;
    }

    private static async Task<ProjectRecord?> ReadOpenProjectByTechnologyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string scopeId,
        string technologyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT project_id, scope_type, scope_id, tech_id, status,
                   required_points, contributed_points, duration_seconds,
                   started_at, ready_at, completed_at, started_by_player_id,
                   completed_by_player_id, created_at, updated_at
            FROM research.research_projects
            WHERE scope_type = @scope_type
              AND scope_id = @scope_id
              AND tech_id = @tech_id
              AND status IN ('active', 'completed')
            ORDER BY created_at DESC
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);
        command.Parameters.AddWithValue("tech_id", technologyId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadProject(reader) : null;
    }

    private static async Task<ProjectRecord?> ReadProjectForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string scopeId,
        string projectId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT project_id, scope_type, scope_id, tech_id, status,
                   required_points, contributed_points, duration_seconds,
                   started_at, ready_at, completed_at, started_by_player_id,
                   completed_by_player_id, created_at, updated_at
            FROM research.research_projects
            WHERE scope_type = @scope_type
              AND scope_id = @scope_id
              AND project_id = @project_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);
        command.Parameters.AddWithValue("project_id", projectId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadProject(reader) : null;
    }

    private static ProjectRecord ReadProject(NpgsqlDataReader reader)
    {
        return new ProjectRecord(
            ProjectId: reader.GetString(0),
            ScopeType: reader.GetString(1),
            ScopeId: reader.GetString(2),
            TechnologyId: reader.GetString(3),
            Status: reader.GetString(4),
            RequiredPoints: reader.GetInt32(5),
            ContributedPoints: reader.GetInt32(6),
            DurationSeconds: reader.GetInt32(7),
            StartedAt: reader.GetFieldValue<DateTimeOffset>(8),
            ReadyAt: reader.GetFieldValue<DateTimeOffset>(9),
            CompletedAt: reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10),
            StartedByPlayerId: reader.GetString(11),
            CompletedByPlayerId: reader.IsDBNull(12) ? null : reader.GetString(12),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(13),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(14));
    }

    private static async Task<ContributionRecord?> ReadContributionByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT contribution_id, project_id, scope_type, scope_id, tech_id, points
            FROM research.research_contributions
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new ContributionRecord(
                ContributionId: reader.GetString(0),
                ProjectId: reader.GetString(1),
                ScopeType: reader.GetString(2),
                ScopeId: reader.GetString(3),
                TechnologyId: reader.GetString(4),
                Points: reader.GetInt32(5))
            : null;
    }

    private static async Task<CompletionEventRecord?> ReadCompletionEventByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT event_id, project_id, scope_type, scope_id, tech_id
            FROM research.research_completion_events
            WHERE idempotency_key = @idempotency_key;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new CompletionEventRecord(
                EventId: reader.GetString(0),
                ProjectId: reader.GetString(1),
                ScopeType: reader.GetString(2),
                ScopeId: reader.GetString(3),
                TechnologyId: reader.GetString(4))
            : null;
    }

    private static async Task<bool> IsTechnologyCompletedAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string scopeId,
        string technologyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM research.completed_technologies
            WHERE scope_type = @scope_type
              AND scope_id = @scope_id
              AND tech_id = @tech_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);
        command.Parameters.AddWithValue("tech_id", technologyId);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task RecalculateBonusTotalsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string scopeType,
        string scopeId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            DELETE FROM research.scope_bonus_totals
            WHERE scope_type = @scope_type AND scope_id = @scope_id;

            INSERT INTO research.scope_bonus_totals (
                scope_type, scope_id, bonus_type, bonus_target, total_value, updated_at
            )
            SELECT @scope_type,
                   @scope_id,
                   technologies.bonus_type,
                   technologies.bonus_target,
                   SUM(technologies.bonus_value)::integer,
                   @updated_at
            FROM research.completed_technologies completed
            JOIN research.technologies technologies
              ON technologies.tech_id = completed.tech_id
            WHERE completed.scope_type = @scope_type
              AND completed.scope_id = @scope_id
              AND technologies.bonus_value > 0
            GROUP BY technologies.bonus_type, technologies.bonus_target
            ON CONFLICT (scope_type, scope_id, bonus_type, bonus_target) DO UPDATE
            SET total_value = EXCLUDED.total_value,
                updated_at = EXCLUDED.updated_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<ResearchBonusDto>> ReadBonusesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string scopeType,
        string scopeId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT totals.bonus_type,
                   totals.bonus_target,
                   totals.total_value,
                   string_agg(technologies.tech_id, ',' ORDER BY technologies.sort_order) AS technology_ids,
                   string_agg(technologies.name, ', ' ORDER BY technologies.sort_order) AS technology_names,
                   max(totals.updated_at) AS updated_at
            FROM research.scope_bonus_totals totals
            JOIN research.completed_technologies completed
              ON completed.scope_type = totals.scope_type
             AND completed.scope_id = totals.scope_id
            JOIN research.technologies technologies
              ON technologies.tech_id = completed.tech_id
             AND technologies.bonus_type = totals.bonus_type
             AND technologies.bonus_target = totals.bonus_target
            WHERE totals.scope_type = @scope_type
              AND totals.scope_id = @scope_id
            GROUP BY totals.bonus_type, totals.bonus_target, totals.total_value
            ORDER BY totals.bonus_type, totals.bonus_target;
            """, connection, transaction);
        command.Parameters.AddWithValue("scope_type", scopeType);
        command.Parameters.AddWithValue("scope_id", scopeId);

        var bonuses = new List<ResearchBonusDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var bonusType = reader.GetString(0);
            var totalValue = reader.GetInt32(2);
            var technologyNames = reader.GetString(4);
            bonuses.Add(new ResearchBonusDto(
                BonusType: bonusType,
                BonusTarget: reader.GetString(1),
                TotalValue: totalValue,
                SourceTechnologyIds: SplitPrerequisites(reader.GetString(3)),
                Description: $"{FormatBonusType(bonusType)} +{totalValue}% from {technologyNames}.",
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(5)));
        }

        return bonuses;
    }

    private static ResearchTechnologyDto ToTechnologyDto(TechnologyRecord technology)
    {
        return new ResearchTechnologyDto(
            TechnologyId: technology.TechId,
            ScopeType: technology.ScopeType,
            Track: technology.Track,
            Name: technology.Name,
            Description: technology.Description,
            Tier: technology.Tier,
            PrerequisiteTechnologyIds: technology.PrerequisiteTechIds,
            RequiredPoints: technology.RequiredPoints,
            DurationSeconds: technology.DurationSeconds,
            Bonus: new ResearchTechnologyBonusDto(
                BonusType: technology.BonusType,
                BonusValue: technology.BonusValue,
                BonusTarget: technology.BonusTarget,
                Description: technology.BonusDescription),
            UpdatedAt: technology.UpdatedAt);
    }

    private static ResearchProjectDto ToProjectDto(ProjectRecord project, DateTimeOffset now)
    {
        var remaining = Math.Max(0, project.RequiredPoints - project.ContributedPoints);
        var progressPercent = project.RequiredPoints <= 0
            ? 100
            : Math.Clamp((project.ContributedPoints * 100) / project.RequiredPoints, 0, 100);
        var canComplete = string.Equals(project.Status, "active", StringComparison.OrdinalIgnoreCase) &&
            remaining == 0 &&
            project.ReadyAt <= now;
        return new ResearchProjectDto(
            ProjectId: project.ProjectId,
            ScopeType: project.ScopeType,
            ScopeId: project.ScopeId,
            TechnologyId: project.TechnologyId,
            Status: project.Status,
            RequiredPoints: project.RequiredPoints,
            ContributedPoints: project.ContributedPoints,
            RemainingPoints: remaining,
            ProgressPercent: progressPercent,
            DurationSeconds: project.DurationSeconds,
            StartedAt: project.StartedAt,
            ReadyAt: project.ReadyAt,
            CompletedAt: project.CompletedAt,
            CanComplete: canComplete,
            UpdatedAt: project.UpdatedAt);
    }

    private static bool Matches(ProjectRecord project, string scopeType, string scopeId, string technologyId)
    {
        return string.Equals(project.ScopeType, scopeType, StringComparison.Ordinal) &&
            string.Equals(project.ScopeId, scopeId, StringComparison.Ordinal) &&
            string.Equals(project.TechnologyId, technologyId, StringComparison.Ordinal);
    }

    private static string[] SplitPrerequisites(string value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? []
            : value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    private static string FormatBonusType(string bonusType)
    {
        return bonusType switch
        {
            ProductionSpeedBonus => "Production speed",
            "region_defense_percent" => "Region defense",
            "hospital_recovery_percent" => "Hospital recovery",
            "market_fee_reduction_percent" => "Market efficiency",
            "storage_capacity_percent" => "Storage capacity",
            "company_productivity_percent" => "Company productivity",
            _ => bonusType.Replace('_', ' ')
        };
    }

    private static ResearchPointRules GetPointRules(string scopeType)
    {
        return scopeType switch
        {
            CountryScope => new ResearchPointRules(InitialPoints: 180, HourlyPointRate: 15, PointCap: 750),
            CompanyScope => new ResearchPointRules(InitialPoints: 140, HourlyPointRate: 10, PointCap: 500),
            _ => new ResearchPointRules(InitialPoints: 0, HourlyPointRate: 0, PointCap: 0)
        };
    }

    private static string? NormalizeScopeType(string? scopeType)
    {
        var normalized = NormalizeId(scopeType);
        return normalized is CountryScope or CompanyScope ? normalized : null;
    }

    private static string NormalizeId(string? value)
    {
        return (value ?? string.Empty).Trim().ToLowerInvariant();
    }

    private static string NormalizePlayerId(string? playerId)
    {
        return (playerId ?? string.Empty).Trim().ToLowerInvariant();
    }

    private static string NormalizeIdempotencyKey(string? idempotencyKey)
    {
        return (idempotencyKey ?? string.Empty).Trim().ToLowerInvariant();
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private sealed record ResearchAccountRecord(
        string ScopeType,
        string ScopeId,
        int AvailablePoints,
        int LifetimePoints,
        int PointCap,
        int HourlyPointRate,
        DateTimeOffset LastAccruedAt,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt);

    private sealed record ResearchPointRules(int InitialPoints, int HourlyPointRate, int PointCap);

    private sealed record TechnologyRecord(
        string TechId,
        string ScopeType,
        string Track,
        string Name,
        string Description,
        int Tier,
        string[] PrerequisiteTechIds,
        int RequiredPoints,
        int DurationSeconds,
        string BonusType,
        int BonusValue,
        string BonusTarget,
        string BonusDescription,
        int SortOrder,
        DateTimeOffset UpdatedAt);

    private sealed record ProjectRecord(
        string ProjectId,
        string ScopeType,
        string ScopeId,
        string TechnologyId,
        string Status,
        int RequiredPoints,
        int ContributedPoints,
        int DurationSeconds,
        DateTimeOffset StartedAt,
        DateTimeOffset ReadyAt,
        DateTimeOffset? CompletedAt,
        string StartedByPlayerId,
        string? CompletedByPlayerId,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt);

    private sealed record ContributionRecord(
        string ContributionId,
        string ProjectId,
        string ScopeType,
        string ScopeId,
        string TechnologyId,
        int Points);

    private sealed record CompletionEventRecord(
        string EventId,
        string ProjectId,
        string ScopeType,
        string ScopeId,
        string TechnologyId);
}

internal static class TechnologyCatalog
{
    public static TechnologySeed[] All { get; } =
    [
        new TechnologySeed(
            TechId: "agricultural-mechanization",
            ScopeType: "country",
            Track: "Production",
            Name: "Agricultural Mechanization",
            Description: "Shared tooling and planning lets citizens finish routine production faster.",
            Tier: 1,
            PrerequisiteTechIds: [],
            RequiredPoints: 120,
            DurationSeconds: 60,
            BonusType: "production_speed_percent",
            BonusValue: 10,
            BonusTarget: "citizen_factories",
            BonusDescription: "Citizens finish player production jobs 10% faster.",
            SortOrder: 10),
        new TechnologySeed(
            TechId: "regional-fortifications",
            ScopeType: "country",
            Track: "Military",
            Name: "Regional Fortifications",
            Description: "Engineers harden defensive positions and supply depots across owned regions.",
            Tier: 1,
            PrerequisiteTechIds: [],
            RequiredPoints: 150,
            DurationSeconds: 90,
            BonusType: "region_defense_percent",
            BonusValue: 8,
            BonusTarget: "owned_regions",
            BonusDescription: "Exposes an 8% country region defense bonus for battle and campaign systems.",
            SortOrder: 20),
        new TechnologySeed(
            TechId: "public-health-network",
            ScopeType: "country",
            Track: "Infrastructure",
            Name: "Public Health Network",
            Description: "Hospitals coordinate staffing, triage, and recovery supplies nationally.",
            Tier: 2,
            PrerequisiteTechIds: ["agricultural-mechanization"],
            RequiredPoints: 180,
            DurationSeconds: 120,
            BonusType: "hospital_recovery_percent",
            BonusValue: 10,
            BonusTarget: "citizen_hospital",
            BonusDescription: "Exposes a 10% hospital recovery efficiency bonus.",
            SortOrder: 30),
        new TechnologySeed(
            TechId: "market-logistics",
            ScopeType: "country",
            Track: "Economy",
            Name: "Market Logistics",
            Description: "Roadmaps and freight standards reduce economic friction for national markets.",
            Tier: 2,
            PrerequisiteTechIds: ["agricultural-mechanization"],
            RequiredPoints: 200,
            DurationSeconds: 150,
            BonusType: "market_fee_reduction_percent",
            BonusValue: 5,
            BonusTarget: "country_market",
            BonusDescription: "Exposes a 5% market and logistics efficiency bonus.",
            SortOrder: 40),
        new TechnologySeed(
            TechId: "lean-workshops",
            ScopeType: "company",
            Track: "Production",
            Name: "Lean Workshops",
            Description: "Company floor layouts and shared jigs reduce job setup time.",
            Tier: 1,
            PrerequisiteTechIds: [],
            RequiredPoints: 100,
            DurationSeconds: 60,
            BonusType: "production_speed_percent",
            BonusValue: 8,
            BonusTarget: "company_factories",
            BonusDescription: "Company production jobs finish 8% faster.",
            SortOrder: 110),
        new TechnologySeed(
            TechId: "warehouse-systems",
            ScopeType: "company",
            Track: "Logistics",
            Name: "Warehouse Systems",
            Description: "Slotting, labels, and receiving routines prepare the company for larger inventories.",
            Tier: 1,
            PrerequisiteTechIds: [],
            RequiredPoints: 120,
            DurationSeconds: 90,
            BonusType: "storage_capacity_percent",
            BonusValue: 10,
            BonusTarget: "company_storage",
            BonusDescription: "Exposes a 10% company storage capacity bonus.",
            SortOrder: 120),
        new TechnologySeed(
            TechId: "specialized-tools",
            ScopeType: "company",
            Track: "Specialization",
            Name: "Specialized Tools",
            Description: "Dedicated tooling supports company specialization and future productivity upgrades.",
            Tier: 2,
            PrerequisiteTechIds: ["lean-workshops"],
            RequiredPoints: 150,
            DurationSeconds: 120,
            BonusType: "company_productivity_percent",
            BonusValue: 5,
            BonusTarget: "company_specialization",
            BonusDescription: "Exposes a 5% company productivity specialization hook.",
            SortOrder: 130)
    ];
}

internal sealed record TechnologySeed(
    string TechId,
    string ScopeType,
    string Track,
    string Name,
    string Description,
    int Tier,
    string[] PrerequisiteTechIds,
    int RequiredPoints,
    int DurationSeconds,
    string BonusType,
    int BonusValue,
    string BonusTarget,
    string BonusDescription,
    int SortOrder);

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

internal sealed record ResearchMutationRequest(string? ActorPlayerId, string? IdempotencyKey);

internal sealed record ResearchContributionRequest(string? ActorPlayerId, int Points, string? IdempotencyKey);

internal sealed record ResearchTechnologyCatalogDto(
    string? ScopeType,
    ResearchTechnologyDto[] Technologies,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchScopeStateDto(
    string ScopeType,
    string ScopeId,
    string ActorPlayerId,
    int AvailablePoints,
    int LifetimePoints,
    int PointCap,
    int HourlyPointRate,
    DateTimeOffset LastAccruedAt,
    ResearchTechnologyNodeDto[] Technologies,
    ResearchProjectDto[] ActiveProjects,
    string[] CompletedTechnologyIds,
    ResearchBonusDto[] Bonuses,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchTechnologyNodeDto(
    ResearchTechnologyDto Technology,
    string Status,
    bool IsCompleted,
    bool CanStart,
    string? BlockedReason,
    ResearchProjectDto? Project);

internal sealed record ResearchTechnologyDto(
    string TechnologyId,
    string ScopeType,
    string Track,
    string Name,
    string Description,
    int Tier,
    string[] PrerequisiteTechnologyIds,
    int RequiredPoints,
    int DurationSeconds,
    ResearchTechnologyBonusDto Bonus,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchTechnologyBonusDto(
    string BonusType,
    int BonusValue,
    string BonusTarget,
    string Description);

internal sealed record ResearchProjectDto(
    string ProjectId,
    string ScopeType,
    string ScopeId,
    string TechnologyId,
    string Status,
    int RequiredPoints,
    int ContributedPoints,
    int RemainingPoints,
    int ProgressPercent,
    int DurationSeconds,
    DateTimeOffset StartedAt,
    DateTimeOffset ReadyAt,
    DateTimeOffset? CompletedAt,
    bool CanComplete,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchBonusListDto(
    string ScopeType,
    string ScopeId,
    ResearchBonusDto[] Bonuses,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchBonusDto(
    string BonusType,
    string BonusTarget,
    int TotalValue,
    string[] SourceTechnologyIds,
    string Description,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchMutationResponse(
    bool Completed,
    string Message,
    ResearchProjectDto? Project,
    ResearchScopeStateDto? State,
    ResearchBonusDto[] ActiveBonuses,
    DateTimeOffset UpdatedAt);

internal sealed record StoreResult<T>(T? Value, string? Message, int StatusCode) where T : class
{
    public static StoreResult<T> Ok(T value) => new(value, null, StatusCodes.Status200OK);
    public static StoreResult<T> BadRequest(string message) => new(null, message, StatusCodes.Status400BadRequest);
    public static StoreResult<T> NotFound(string message) => new(null, message, StatusCodes.Status404NotFound);
    public static StoreResult<T> Conflict(string message) => new(null, message, StatusCodes.Status409Conflict);
    public static StoreResult<T> FromError<TOther>(StoreResult<TOther> result) where TOther : class =>
        new(null, result.Message, result.StatusCode);
}

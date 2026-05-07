internal static class ResearchGatewayEndpoints
{
    public static void MapResearchGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/research/technologies", async (
            string? scopeType,
            HttpRequest request,
            ResearchServiceClient research,
            DevTokenValidator tokens) =>
        {
            var error = ValidateResearchBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = string.IsNullOrWhiteSpace(scopeType)
                ? string.Empty
                : $"?scopeType={Uri.EscapeDataString(scopeType)}";
            return await research.GetAsync($"research/technologies{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayResearchTechnologies");

        app.MapGet("/players/{playerId}/research", async (
            string playerId,
            HttpRequest request,
            ResearchServiceClient research,
            WorldServiceClient world,
            ProductionServiceClient production,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchPlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var authorization = request.Headers.Authorization.ToString();
            var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
            var citizenshipResult = await world.GetJsonAsync<PlayerCitizenshipResponseDto>(
                $"internal/players/{escapedPlayerId}/citizenship",
                authorization,
                InternalResearchToken(configuration));
            if (citizenshipResult.Error is not null)
            {
                return citizenshipResult.Error;
            }

            ResearchScopeStateDto? countryState = null;
            var citizenship = citizenshipResult.Value!.Citizenship;
            if (citizenship is not null &&
                string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
            {
                var countryResult = await research.GetJsonAsync<ResearchScopeStateDto>(
                    ResearchScopePath("country", citizenship.CountryId, access.PlayerId),
                    authorization);
                if (countryResult.Error is not null)
                {
                    return countryResult.Error;
                }

                countryState = countryResult.Value;
            }

            var companiesResult = await production.GetJsonAsync<ResearchCompanyPortfolioDto>(
                $"players/{escapedPlayerId}/companies",
                authorization);
            if (companiesResult.Error is not null)
            {
                return companiesResult.Error;
            }

            var companies = companiesResult.Value!.Companies
                .Where(company => company.IsMember)
                .Select(company => new ResearchCompanyScopeSummaryDto(
                    CompanyId: company.CompanyId,
                    Name: company.Name,
                    Role: company.Role,
                    CanManageResearch: company.Permissions.CanManageUpgrades || company.CanManage))
                .ToArray();

            return Results.Ok(new ResearchDashboardDto(
                PlayerId: access.PlayerId!,
                Citizenship: citizenship,
                Country: countryState,
                Companies: companies,
                UpdatedAt: DateTimeOffset.UtcNow));
        }).WithName("GetPlayerResearchDashboard");

        app.MapGet("/research/countries/{countryId}", async (
            string countryId,
            HttpRequest request,
            ResearchServiceClient research,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var countryError = await ValidateCountryExistsAsync(
                countryId,
                request.Headers.Authorization.ToString(),
                world);
            if (countryError is not null)
            {
                return countryError;
            }

            return await research.GetAsync(
                ResearchScopePath("country", countryId, access.PlayerId),
                request.Headers.Authorization.ToString());
        }).WithName("GetCountryResearch");

        app.MapGet("/research/countries/{countryId}/bonuses", async (
            string countryId,
            HttpRequest request,
            ResearchServiceClient research,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var countryError = await ValidateCountryExistsAsync(
                countryId,
                request.Headers.Authorization.ToString(),
                world);
            if (countryError is not null)
            {
                return countryError;
            }

            return await research.GetAsync(
                $"research/scopes/country/{Uri.EscapeDataString(countryId)}/bonuses",
                request.Headers.Authorization.ToString());
        }).WithName("GetCountryResearchBonuses");

        app.MapPost("/research/countries/{countryId}/technologies/{technologyId}/start", async (
            string countryId,
            string technologyId,
            HttpRequest request,
            ResearchServiceClient research,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var permissionError = await ValidateCountryResearchPermissionAsync(
                countryId,
                request.Headers.Authorization.ToString(),
                world);
            if (permissionError is not null)
            {
                return permissionError;
            }

            return await ForwardResearchMutationAsync(
                research,
                request,
                $"research/scopes/country/{Uri.EscapeDataString(countryId)}/technologies/{Uri.EscapeDataString(technologyId)}/start",
                access.PlayerId!);
        }).WithName("StartCountryResearch");

        app.MapPost("/research/countries/{countryId}/projects/{projectId}/contribute", async (
            string countryId,
            string projectId,
            ResearchContributionGatewayRequest contribution,
            HttpRequest request,
            ResearchServiceClient research,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var permissionError = await ValidateCountryResearchPermissionAsync(
                countryId,
                request.Headers.Authorization.ToString(),
                world);
            if (permissionError is not null)
            {
                return permissionError;
            }

            return await ForwardResearchContributionAsync(
                research,
                request,
                $"research/scopes/country/{Uri.EscapeDataString(countryId)}/projects/{Uri.EscapeDataString(projectId)}/contribute",
                access.PlayerId!,
                contribution.Points);
        }).WithName("ContributeCountryResearch");

        app.MapPost("/research/countries/{countryId}/projects/{projectId}/complete", async (
            string countryId,
            string projectId,
            HttpRequest request,
            ResearchServiceClient research,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var permissionError = await ValidateCountryResearchPermissionAsync(
                countryId,
                request.Headers.Authorization.ToString(),
                world);
            if (permissionError is not null)
            {
                return permissionError;
            }

            return await ForwardResearchMutationAsync(
                research,
                request,
                $"research/scopes/country/{Uri.EscapeDataString(countryId)}/projects/{Uri.EscapeDataString(projectId)}/complete",
                access.PlayerId!);
        }).WithName("CompleteCountryResearch");

        app.MapGet("/research/companies/{companyId}", async (
            string companyId,
            HttpRequest request,
            ResearchServiceClient research,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var companyError = await ValidateCompanyResearchAccessAsync(
                companyId,
                access.PlayerId!,
                request.Headers.Authorization.ToString(),
                production,
                requireManager: false);
            if (companyError is not null)
            {
                return companyError;
            }

            return await research.GetAsync(
                ResearchScopePath("company", companyId, access.PlayerId),
                request.Headers.Authorization.ToString());
        }).WithName("GetCompanyResearch");

        app.MapGet("/research/companies/{companyId}/bonuses", async (
            string companyId,
            HttpRequest request,
            ResearchServiceClient research,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var companyError = await ValidateCompanyResearchAccessAsync(
                companyId,
                access.PlayerId!,
                request.Headers.Authorization.ToString(),
                production,
                requireManager: false);
            if (companyError is not null)
            {
                return companyError;
            }

            return await research.GetAsync(
                $"research/scopes/company/{Uri.EscapeDataString(companyId)}/bonuses",
                request.Headers.Authorization.ToString());
        }).WithName("GetCompanyResearchBonuses");

        app.MapPost("/research/companies/{companyId}/technologies/{technologyId}/start", async (
            string companyId,
            string technologyId,
            HttpRequest request,
            ResearchServiceClient research,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var companyError = await ValidateCompanyResearchAccessAsync(
                companyId,
                access.PlayerId!,
                request.Headers.Authorization.ToString(),
                production,
                requireManager: true);
            if (companyError is not null)
            {
                return companyError;
            }

            return await ForwardResearchMutationAsync(
                research,
                request,
                $"research/scopes/company/{Uri.EscapeDataString(companyId)}/technologies/{Uri.EscapeDataString(technologyId)}/start",
                access.PlayerId!);
        }).WithName("StartCompanyResearch");

        app.MapPost("/research/companies/{companyId}/projects/{projectId}/contribute", async (
            string companyId,
            string projectId,
            ResearchContributionGatewayRequest contribution,
            HttpRequest request,
            ResearchServiceClient research,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var companyError = await ValidateCompanyResearchAccessAsync(
                companyId,
                access.PlayerId!,
                request.Headers.Authorization.ToString(),
                production,
                requireManager: true);
            if (companyError is not null)
            {
                return companyError;
            }

            return await ForwardResearchContributionAsync(
                research,
                request,
                $"research/scopes/company/{Uri.EscapeDataString(companyId)}/projects/{Uri.EscapeDataString(projectId)}/contribute",
                access.PlayerId!,
                contribution.Points);
        }).WithName("ContributeCompanyResearch");

        app.MapPost("/research/companies/{companyId}/projects/{projectId}/complete", async (
            string companyId,
            string projectId,
            HttpRequest request,
            ResearchServiceClient research,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateResearchBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var companyError = await ValidateCompanyResearchAccessAsync(
                companyId,
                access.PlayerId!,
                request.Headers.Authorization.ToString(),
                production,
                requireManager: true);
            if (companyError is not null)
            {
                return companyError;
            }

            return await ForwardResearchMutationAsync(
                research,
                request,
                $"research/scopes/company/{Uri.EscapeDataString(companyId)}/projects/{Uri.EscapeDataString(projectId)}/complete",
                access.PlayerId!);
        }).WithName("CompleteCompanyResearch");
    }

    private static async Task<IResult> ForwardResearchMutationAsync(
        ResearchServiceClient research,
        HttpRequest request,
        string path,
        string actorPlayerId)
    {
        var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
        if (string.IsNullOrWhiteSpace(idempotencyKey))
        {
            return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
        }

        var result = await research.PostJsonAsync<ResearchMutationRequestDto, ResearchMutationResponseDto>(
            path,
            request.Headers.Authorization.ToString(),
            new ResearchMutationRequestDto(actorPlayerId, idempotencyKey));
        return result.Error is not null ? result.Error : Results.Ok(result.Value!);
    }

    private static async Task<IResult> ForwardResearchContributionAsync(
        ResearchServiceClient research,
        HttpRequest request,
        string path,
        string actorPlayerId,
        int points)
    {
        if (points <= 0)
        {
            return Results.BadRequest(new ErrorResponse("Contribution points must be positive."));
        }

        var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
        if (string.IsNullOrWhiteSpace(idempotencyKey))
        {
            return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
        }

        var result = await research.PostJsonAsync<ResearchContributionRequestDto, ResearchMutationResponseDto>(
            path,
            request.Headers.Authorization.ToString(),
            new ResearchContributionRequestDto(actorPlayerId, points, idempotencyKey));
        return result.Error is not null ? result.Error : Results.Ok(result.Value!);
    }

    private static async Task<IResult?> ValidateCountryExistsAsync(
        string countryId,
        string authorization,
        WorldServiceClient world)
    {
        var treasury = await world.GetJsonAsync<CountryTreasuryResponseDto>(
            $"countries/{Uri.EscapeDataString(countryId)}/treasury",
            authorization);
        return treasury.Error;
    }

    private static async Task<IResult?> ValidateCountryResearchPermissionAsync(
        string countryId,
        string authorization,
        WorldServiceClient world)
    {
        var treasury = await world.GetJsonAsync<CountryTreasuryResponseDto>(
            $"countries/{Uri.EscapeDataString(countryId)}/treasury",
            authorization);
        if (treasury.Error is not null)
        {
            return treasury.Error;
        }

        var authorizationState = treasury.Value!.Authorization;
        return authorizationState.CanUpdatePolicy
            ? null
            : Results.Json(
                new ErrorResponse(authorizationState.Message),
                statusCode: StatusCodes.Status403Forbidden);
    }

    private static async Task<IResult?> ValidateCompanyResearchAccessAsync(
        string companyId,
        string actorPlayerId,
        string authorization,
        ProductionServiceClient production,
        bool requireManager)
    {
        var assets = await production.GetJsonAsync<CompanyAssetsDto>(
            $"companies/{Uri.EscapeDataString(companyId)}/assets?actorPlayerId={Uri.EscapeDataString(actorPlayerId)}",
            authorization);
        if (assets.Error is not null)
        {
            return assets.Error;
        }

        if (!requireManager)
        {
            return null;
        }

        var canManageResearch = assets.Value!.Upgrades?.CanManageUpgrades == true;
        return canManageResearch
            ? null
            : Results.Json(
                new ErrorResponse("Only company owners and managers can manage company research."),
                statusCode: StatusCodes.Status403Forbidden);
    }

    private static string ResearchScopePath(string scopeType, string scopeId, string? actorPlayerId)
    {
        var query = string.IsNullOrWhiteSpace(actorPlayerId)
            ? string.Empty
            : $"?actorPlayerId={Uri.EscapeDataString(actorPlayerId)}";
        return $"research/scopes/{Uri.EscapeDataString(scopeType)}/{Uri.EscapeDataString(scopeId)}{query}";
    }

    private static IResult? ValidateResearchBearer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? null
            : Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized);
    }

    private static PlayerAccessResult ValidateResearchBearerPlayer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? PlayerAccessResult.Allowed(token.PlayerId!)
            : PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
    }

    private static PlayerAccessResult ValidateResearchPlayerAccess(
        string playerId,
        HttpRequest request,
        DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        if (!token.IsValid)
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
        }

        if (!string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase) &&
            !token.Roles.Contains("admin", StringComparer.OrdinalIgnoreCase))
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("You cannot access another player's research."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(
            string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase)
                ? token.PlayerId!
                : playerId);
    }

    private static string InternalResearchToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed class ResearchServiceClient(HttpClient httpClient) : ForwardingServiceClient(httpClient, "Research service");

internal sealed record ResearchDashboardDto(
    string PlayerId,
    PlayerCitizenshipDto? Citizenship,
    ResearchScopeStateDto? Country,
    ResearchCompanyScopeSummaryDto[] Companies,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchCompanyScopeSummaryDto(
    string CompanyId,
    string Name,
    string? Role,
    bool CanManageResearch);

internal sealed record ResearchCompanyPortfolioDto(
    string PlayerId,
    ResearchCompanySummaryDto[] Companies,
    DateTimeOffset UpdatedAt);

internal sealed record ResearchCompanySummaryDto(
    string CompanyId,
    string Name,
    string? Role,
    bool IsMember,
    bool CanManage,
    ResearchCompanyPermissionsDto Permissions);

internal sealed record ResearchCompanyPermissionsDto(
    bool CanManageMembers,
    bool CanManageRoles,
    bool CanManageProduction,
    bool CanManageWorkforce,
    bool CanManageUpgrades,
    bool CanManageSpecialization);

internal sealed record ResearchContributionGatewayRequest(int Points);

internal sealed record ResearchMutationRequestDto(string ActorPlayerId, string IdempotencyKey);

internal sealed record ResearchContributionRequestDto(string ActorPlayerId, int Points, string IdempotencyKey);

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

internal sealed record ResearchMutationResponseDto(
    bool Completed,
    string Message,
    ResearchProjectDto? Project,
    ResearchScopeStateDto? State,
    ResearchBonusDto[] ActiveBonuses,
    DateTimeOffset UpdatedAt);

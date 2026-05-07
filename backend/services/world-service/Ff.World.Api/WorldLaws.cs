using Npgsql;

internal static class LawEndpoints
{
    public static void MapLawEndpoints(this WebApplication app)
    {
        app.MapGet("/politics/law-proposals", async (
            string? countryId,
            string? status,
            int? limit,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var viewer = tokens.Validate(request.Headers.Authorization.ToString()).PlayerId;
            return Results.Ok(await world.GetLawProposalsAsync(countryId, status, viewer, limit));
        }).WithName("GetLawProposals");

        app.MapGet("/politics/law-proposals/{proposalId}", async (
            string proposalId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var viewer = tokens.Validate(request.Headers.Authorization.ToString()).PlayerId;
            var proposal = await world.GetLawProposalAsync(proposalId, viewer);
            return proposal is null
                ? Results.NotFound(new ErrorResponse("Law proposal was not found."))
                : Results.Ok(proposal);
        }).WithName("GetLawProposal");

        app.MapGet("/politics/law-proposals/{proposalId}/votes", async (
            string proposalId,
            int? limit,
            WorldStore world) =>
        {
            var votes = await world.GetLawProposalVotesAsync(proposalId, limit);
            return votes is null
                ? Results.NotFound(new ErrorResponse("Law proposal was not found."))
                : Results.Ok(votes);
        }).WithName("GetLawProposalVotes");

        app.MapGet("/politics/laws", async (
            string? countryId,
            string? status,
            int? limit,
            WorldStore world) =>
            Results.Ok(await world.GetLawsAsync(countryId, status, limit))).WithName("GetLaws");

        app.MapPost("/players/{playerId}/politics/law-proposals", async (
            string playerId,
            LawProposalCreateRequest proposal,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateLawProposal(proposal);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.CreateLawProposalAsync(access.PlayerId!, proposal);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Country was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("CreateLawProposal");

        app.MapPost("/players/{playerId}/politics/law-proposals/{proposalId}/vote", async (
            string playerId,
            string proposalId,
            LawVoteRequest vote,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var choice = NormalizeVoteChoice(vote.Choice);
            if (choice is null)
            {
                return Results.BadRequest(new ErrorResponse("Vote choice must be yes, no, or abstain."));
            }

            var result = await world.CastLawVoteAsync(access.PlayerId!, proposalId, vote with { Choice = choice });
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Law proposal was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("CastLawProposalVote");

        app.MapPost("/players/{playerId}/politics/law-proposals/{proposalId}/resolve", async (
            string playerId,
            string proposalId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.ResolveLawProposalAsync(access.PlayerId!, proposalId);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Law proposal was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: result.StatusCode);
        }).WithName("ResolveLawProposal");
    }

    private static PlayerAccessResult ValidatePlayerAccess(
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

        if (!string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase))
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("You cannot access another player's congress state."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string? ValidateLawProposal(LawProposalCreateRequest proposal)
    {
        if (string.IsNullOrWhiteSpace(proposal.CountryId))
        {
            return "Country is required.";
        }

        if (NormalizeProposalType(proposal.ProposalType) is null)
        {
            return "Proposal type must be tax_policy, treasury_grant, treasury_spend, citizenship_rule, or war_declaration.";
        }

        if (string.IsNullOrWhiteSpace(proposal.Title) || proposal.Title.Trim().Length < 3)
        {
            return "Proposal title must be at least 3 characters.";
        }

        if (proposal.Title.Length > 120 || proposal.Description?.Length > 1_200)
        {
            return "Proposal title or description is too long.";
        }

        var proposalType = NormalizeProposalType(proposal.ProposalType)!;
        if (proposalType == LawProposalTypes.TaxPolicy)
        {
            return ValidateTaxRate(proposal.IncomeTaxRate, "Income tax")
                ?? ValidateTaxRate(proposal.MarketTaxRate, "Market tax")
                ?? ValidateTaxRate(proposal.ProductionTaxRate, "Production tax");
        }

        if (proposalType is LawProposalTypes.TreasuryGrant or LawProposalTypes.TreasurySpend)
        {
            return proposal.TreasuryAmount is null or <= 0
                ? "Treasury grant/spend proposals require a positive treasury amount."
                : null;
        }

        if (proposalType == LawProposalTypes.CitizenshipRule &&
            string.IsNullOrWhiteSpace(proposal.CitizenshipRule))
        {
            return "Citizenship rule proposals require a rule summary.";
        }

        return null;
    }

    private static string? ValidateTaxRate(int? rate, string name)
    {
        if (rate is null)
        {
            return $"{name} is required for tax policy proposals.";
        }

        return rate is < 0 or > 50
            ? $"{name} must be between 0 and 50 percent."
            : null;
    }

    private static string? NormalizeVoteChoice(string? choice)
    {
        var normalized = choice?.Trim().ToLowerInvariant();
        return normalized is "yes" or "no" or "abstain" ? normalized : null;
    }

    internal static string? NormalizeProposalType(string? proposalType)
    {
        var normalized = proposalType?.Trim().ToLowerInvariant().Replace('-', '_');
        return normalized is LawProposalTypes.TaxPolicy
            or LawProposalTypes.TreasuryGrant
            or LawProposalTypes.TreasurySpend
            or LawProposalTypes.CitizenshipRule
            or LawProposalTypes.WarDeclaration
            ? normalized
            : null;
    }
}

internal sealed partial class WorldStore
{
    private const int DefaultLawVotingHours = 48;
    private const int DefaultLawApprovalThresholdPercent = 50;

    public async Task InitializeLawsSchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.country_congress_authorizations (
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                role text NOT NULL,
                granted_at timestamptz NOT NULL,
                granted_by_player_id text NOT NULL,
                PRIMARY KEY (country_id, player_id)
            );

            CREATE INDEX IF NOT EXISTS ix_world_country_congress_authorizations_player_id
                ON world.country_congress_authorizations (player_id);

            CREATE TABLE IF NOT EXISTS world.law_proposals (
                proposal_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                proposal_type text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                sponsor_player_id text NOT NULL,
                status text NOT NULL,
                voting_starts_at timestamptz NOT NULL,
                voting_ends_at timestamptz NOT NULL,
                resolved_at timestamptz NULL,
                executed_at timestamptz NULL,
                approval_threshold_percent integer NOT NULL,
                execution_status text NOT NULL,
                execution_message text NOT NULL,
                result_law_id text NULL,
                income_tax_rate integer NULL,
                market_tax_rate integer NULL,
                production_tax_rate integer NULL,
                treasury_amount integer NULL,
                treasury_target_player_id text NULL,
                treasury_reason text NOT NULL DEFAULT '',
                citizenship_rule text NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL,
                CONSTRAINT law_proposals_type_check
                    CHECK (proposal_type IN ('tax_policy', 'treasury_grant', 'treasury_spend', 'citizenship_rule', 'war_declaration')),
                CONSTRAINT law_proposals_status_check
                    CHECK (status IN ('voting', 'passed', 'rejected', 'execution_failed')),
                CONSTRAINT law_proposals_execution_status_check
                    CHECK (execution_status IN ('pending', 'executed', 'not_executed', 'failed'))
            );

            CREATE INDEX IF NOT EXISTS ix_world_law_proposals_country_status
                ON world.law_proposals (country_id, status, voting_ends_at DESC);

            CREATE TABLE IF NOT EXISTS world.law_proposal_votes (
                vote_id text PRIMARY KEY,
                proposal_id text NOT NULL REFERENCES world.law_proposals(proposal_id) ON DELETE CASCADE,
                voter_player_id text NOT NULL,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                choice text NOT NULL,
                cast_at timestamptz NOT NULL,
                CONSTRAINT law_proposal_votes_choice_check
                    CHECK (choice IN ('yes', 'no', 'abstain'))
            );

            CREATE UNIQUE INDEX IF NOT EXISTS ix_world_law_proposal_votes_once
                ON world.law_proposal_votes (proposal_id, voter_player_id);

            CREATE INDEX IF NOT EXISTS ix_world_law_proposal_votes_country_player
                ON world.law_proposal_votes (country_id, voter_player_id, cast_at DESC);

            CREATE TABLE IF NOT EXISTS world.laws (
                law_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                source_proposal_id text NULL REFERENCES world.law_proposals(proposal_id) ON DELETE SET NULL,
                proposal_type text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                status text NOT NULL,
                enacted_at timestamptz NOT NULL,
                repealed_at timestamptz NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_laws_country_status
                ON world.laws (country_id, status, enacted_at DESC);

            CREATE TABLE IF NOT EXISTS world.law_execution_results (
                execution_id text PRIMARY KEY,
                proposal_id text NOT NULL REFERENCES world.law_proposals(proposal_id) ON DELETE CASCADE,
                law_id text NULL REFERENCES world.laws(law_id) ON DELETE SET NULL,
                executor_player_id text NOT NULL,
                action text NOT NULL,
                status text NOT NULL,
                message text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_law_execution_results_proposal
                ON world.law_execution_results (proposal_id, created_at DESC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task SeedLawsAsync()
    {
        await ResolveDueLawProposalsAsync();
    }

    public async Task<LawProposalListResponse> GetLawProposalsAsync(
        string? countryId,
        string? status,
        string? viewerPlayerId,
        int? limit)
    {
        await ResolveDueLawProposalsAsync();
        var normalizedCountryId = string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId);
        var normalizedStatus = NormalizeLawProposalStatus(status);
        var normalizedViewerId = string.IsNullOrWhiteSpace(viewerPlayerId) ? null : NormalizePlayerId(viewerPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        var proposals = await ReadLawProposalsAsync(
            connection,
            null,
            normalizedCountryId,
            normalizedStatus,
            Math.Clamp(limit ?? 25, 1, 100));
        var authorization = normalizedCountryId is not null && normalizedViewerId is not null
            ? await DetermineCongressAuthorizationAsync(connection, null, normalizedCountryId, normalizedViewerId)
            : null;
        return new LawProposalListResponse(proposals.ToArray(), authorization, DateTimeOffset.UtcNow);
    }

    public async Task<LawProposalDetailsResponse?> GetLawProposalAsync(string proposalId, string? viewerPlayerId)
    {
        await ResolveDueLawProposalsAsync();
        var normalizedProposalId = NormalizeId(proposalId);
        var normalizedViewerId = string.IsNullOrWhiteSpace(viewerPlayerId) ? null : NormalizePlayerId(viewerPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        var proposal = await ReadLawProposalAsync(connection, null, normalizedProposalId);
        if (proposal is null)
        {
            return null;
        }

        var votes = await ReadLawProposalVotesAsync(connection, null, normalizedProposalId, 100);
        var executions = await ReadLawExecutionResultsAsync(connection, null, normalizedProposalId);
        var authorization = normalizedViewerId is null
            ? null
            : await DetermineCongressAuthorizationAsync(connection, null, proposal.CountryId, normalizedViewerId);
        return new LawProposalDetailsResponse(
            proposal,
            votes.ToArray(),
            executions.ToArray(),
            authorization,
            DateTimeOffset.UtcNow);
    }

    public async Task<LawVoteListResponse?> GetLawProposalVotesAsync(string proposalId, int? limit)
    {
        await ResolveDueLawProposalsAsync();
        var normalizedProposalId = NormalizeId(proposalId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var proposal = await ReadLawProposalAsync(connection, null, normalizedProposalId);
        if (proposal is null)
        {
            return null;
        }

        var votes = await ReadLawProposalVotesAsync(
            connection,
            null,
            normalizedProposalId,
            Math.Clamp(limit ?? 100, 1, 250));
        return new LawVoteListResponse(proposal.ProposalId, votes.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<LawListResponse> GetLawsAsync(string? countryId, string? status, int? limit)
    {
        await ResolveDueLawProposalsAsync();
        await using var connection = await _dataSource.OpenConnectionAsync();
        var laws = await ReadLawsAsync(
            connection,
            string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId),
            NormalizeLawStatus(status),
            Math.Clamp(limit ?? 50, 1, 100));
        return new LawListResponse(laws.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<LawProposalMutationResult?> CreateLawProposalAsync(
        string playerId,
        LawProposalCreateRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedCountryId = NormalizeId(request.CountryId!);
        var proposalType = LawEndpoints.NormalizeProposalType(request.ProposalType)!;
        if (!await CountryExistsAsync(normalizedCountryId))
        {
            return null;
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var authorization = await DetermineCongressAuthorizationAsync(
            connection,
            transaction,
            normalizedCountryId,
            normalizedPlayerId);
        if (!authorization.CanCreateProposal)
        {
            await transaction.CommitAsync();
            return LawProposalMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                null);
        }

        var now = DateTimeOffset.UtcNow;
        var title = request.Title!.Trim();
        var proposalId = $"law-proposal-{normalizedCountryId}-{SlugifyLawTitle(title)}-{Guid.NewGuid().ToString("N")[..8]}";
        var votingHours = Math.Clamp(request.VotingHours ?? DefaultLawVotingHours, 1, 168);
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.law_proposals (
                proposal_id, country_id, proposal_type, title, description, sponsor_player_id,
                status, voting_starts_at, voting_ends_at, approval_threshold_percent,
                execution_status, execution_message, income_tax_rate, market_tax_rate,
                production_tax_rate, treasury_amount, treasury_target_player_id,
                treasury_reason, citizenship_rule, created_at, updated_at
            )
            VALUES (
                @proposal_id, @country_id, @proposal_type, @title, @description, @sponsor_player_id,
                'voting', @voting_starts_at, @voting_ends_at, @approval_threshold_percent,
                'pending', '', @income_tax_rate, @market_tax_rate,
                @production_tax_rate, @treasury_amount, @treasury_target_player_id,
                @treasury_reason, @citizenship_rule, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("proposal_id", proposalId);
            command.Parameters.AddWithValue("country_id", normalizedCountryId);
            command.Parameters.AddWithValue("proposal_type", proposalType);
            command.Parameters.AddWithValue("title", title);
            command.Parameters.AddWithValue("description", CleanOptionalText(request.Description, "Citizen law proposal."));
            command.Parameters.AddWithValue("sponsor_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("voting_starts_at", now);
            command.Parameters.AddWithValue("voting_ends_at", now.AddHours(votingHours));
            command.Parameters.AddWithValue("approval_threshold_percent", DefaultLawApprovalThresholdPercent);
            command.Parameters.AddWithValue("income_tax_rate", (object?)request.IncomeTaxRate ?? DBNull.Value);
            command.Parameters.AddWithValue("market_tax_rate", (object?)request.MarketTaxRate ?? DBNull.Value);
            command.Parameters.AddWithValue("production_tax_rate", (object?)request.ProductionTaxRate ?? DBNull.Value);
            command.Parameters.AddWithValue("treasury_amount", (object?)request.TreasuryAmount ?? DBNull.Value);
            command.Parameters.AddWithValue(
                "treasury_target_player_id",
                (object?)NormalizeOptionalPlayerId(request.TreasuryTargetPlayerId) ?? DBNull.Value);
            command.Parameters.AddWithValue("treasury_reason", CleanOptionalText(request.TreasuryReason, title));
            command.Parameters.AddWithValue(
                "citizenship_rule",
                string.IsNullOrWhiteSpace(request.CitizenshipRule)
                    ? DBNull.Value
                    : (object)request.CitizenshipRule.Trim());
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var proposal = await ReadLawProposalAsync(connection, transaction, proposalId);
        await transaction.CommitAsync();

        return new LawProposalMutationResult(
            true,
            "Law proposal was opened for congress voting.",
            proposal,
            authorization,
            StatusCodes.Status200OK,
            now);
    }

    public async Task<LawVoteMutationResult?> CastLawVoteAsync(
        string playerId,
        string proposalId,
        LawVoteRequest request)
    {
        await ResolveDueLawProposalsAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedProposalId = NormalizeId(proposalId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var proposal = await ReadLawProposalAsync(connection, transaction, normalizedProposalId, forUpdate: true);
        if (proposal is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        if (!string.Equals(proposal.Status, "voting", StringComparison.OrdinalIgnoreCase) ||
            proposal.VotingStartsAt > now ||
            proposal.VotingEndsAt <= now)
        {
            await transaction.CommitAsync();
            return LawVoteMutationResult.Failed(
                "Voting is not open for this proposal.",
                StatusCodes.Status409Conflict,
                proposal,
                null);
        }

        var authorization = await DetermineCongressAuthorizationAsync(
            connection,
            transaction,
            proposal.CountryId,
            normalizedPlayerId);
        if (!authorization.CanVote)
        {
            await transaction.CommitAsync();
            return LawVoteMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                proposal,
                null);
        }

        var existingVote = await ReadLawProposalVoteAsync(
            connection,
            transaction,
            normalizedProposalId,
            normalizedPlayerId);
        if (existingVote is not null)
        {
            await transaction.CommitAsync();
            return LawVoteMutationResult.Failed(
                "You have already voted on this proposal.",
                StatusCodes.Status409Conflict,
                proposal,
                existingVote);
        }

        var voteId = $"law-vote-{normalizedProposalId}-{normalizedPlayerId}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.law_proposal_votes (
                vote_id, proposal_id, voter_player_id, country_id, choice, cast_at
            )
            VALUES (
                @vote_id, @proposal_id, @voter_player_id, @country_id, @choice, @cast_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("vote_id", voteId);
            command.Parameters.AddWithValue("proposal_id", normalizedProposalId);
            command.Parameters.AddWithValue("voter_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("country_id", proposal.CountryId);
            command.Parameters.AddWithValue("choice", request.Choice);
            command.Parameters.AddWithValue("cast_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var vote = await ReadLawProposalVoteAsync(connection, transaction, normalizedProposalId, normalizedPlayerId);
        proposal = await ReadLawProposalAsync(connection, transaction, normalizedProposalId);
        await transaction.CommitAsync();

        return new LawVoteMutationResult(
            true,
            "Congress vote recorded.",
            proposal,
            vote,
            StatusCodes.Status200OK,
            now);
    }

    public async Task<LawProposalMutationResult?> ResolveLawProposalAsync(string playerId, string proposalId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedProposalId = NormalizeId(proposalId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var proposal = await ReadLawProposalAsync(connection, transaction, normalizedProposalId, forUpdate: true);
        if (proposal is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var authorization = await DetermineCongressAuthorizationAsync(
            connection,
            transaction,
            proposal.CountryId,
            normalizedPlayerId);
        if (!authorization.CanVote)
        {
            await transaction.CommitAsync();
            return LawProposalMutationResult.Failed(
                authorization.Message,
                StatusCodes.Status403Forbidden,
                proposal);
        }

        if (!string.Equals(proposal.Status, "voting", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new LawProposalMutationResult(
                true,
                "Law proposal has already been resolved.",
                proposal,
                authorization,
                StatusCodes.Status200OK,
                DateTimeOffset.UtcNow);
        }

        if (proposal.VotingEndsAt > DateTimeOffset.UtcNow && !authorization.CanResolve)
        {
            await transaction.CommitAsync();
            return LawProposalMutationResult.Failed(
                "Voting is still open. Only an active elected office holder or congress authorization can resolve early.",
                StatusCodes.Status403Forbidden,
                proposal);
        }

        proposal = await ResolveLawProposalForUpdateAsync(
            connection,
            transaction,
            proposal,
            normalizedPlayerId,
            DateTimeOffset.UtcNow);
        await transaction.CommitAsync();

        return new LawProposalMutationResult(
            true,
            proposal.Status == "passed"
                ? "Law proposal passed and was executed."
                : proposal.Status == "execution_failed"
                    ? "Law proposal passed, but execution failed."
                    : "Law proposal was rejected.",
            proposal,
            authorization,
            StatusCodes.Status200OK,
            proposal.UpdatedAt);
    }

    private async Task ResolveDueLawProposalsAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var dueProposalIds = new List<string>();
        await using (var command = new NpgsqlCommand("""
            SELECT proposal_id
            FROM world.law_proposals
            WHERE status = 'voting'
              AND voting_ends_at <= @now
            FOR UPDATE;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("now", now);
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                dueProposalIds.Add(reader.GetString(0));
            }
        }

        foreach (var proposalId in dueProposalIds)
        {
            var proposal = await ReadLawProposalAsync(connection, transaction, proposalId, forUpdate: true);
            if (proposal is null)
            {
                continue;
            }

            await ResolveLawProposalForUpdateAsync(connection, transaction, proposal, "system", now);
        }

        await transaction.CommitAsync();
    }

    private async Task<LawProposalDto> ResolveLawProposalForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        LawProposalDto proposal,
        string executorPlayerId,
        DateTimeOffset now)
    {
        var yesNoVotes = proposal.YesVotes + proposal.NoVotes;
        var yesPercent = yesNoVotes == 0
            ? 0
            : (proposal.YesVotes * 100) / yesNoVotes;
        var passed = proposal.YesVotes > 0 &&
            proposal.YesVotes > proposal.NoVotes &&
            yesPercent >= proposal.ApprovalThresholdPercent;

        if (!passed)
        {
            var message = proposal.VoteCount == 0
                ? "Proposal rejected because no votes were cast."
                : $"Proposal rejected with {proposal.YesVotes} yes, {proposal.NoVotes} no, and {proposal.AbstainVotes} abstain votes.";
            await UpdateLawProposalResolutionAsync(
                connection,
                transaction,
                proposal.ProposalId,
                "rejected",
                "not_executed",
                message,
                null,
                now);
            await InsertLawExecutionResultAsync(
                connection,
                transaction,
                proposal.ProposalId,
                null,
                executorPlayerId,
                "resolve",
                "rejected",
                message,
                now);
            return (await ReadLawProposalAsync(connection, transaction, proposal.ProposalId))!;
        }

        var outcome = await ExecuteLawProposalAsync(connection, transaction, proposal, executorPlayerId, now);
        await UpdateLawProposalResolutionAsync(
            connection,
            transaction,
            proposal.ProposalId,
            outcome.Completed ? "passed" : "execution_failed",
            outcome.Completed ? "executed" : "failed",
            outcome.Message,
            outcome.LawId,
            now);
        await InsertLawExecutionResultAsync(
            connection,
            transaction,
            proposal.ProposalId,
            outcome.LawId,
            executorPlayerId,
            outcome.Action,
            outcome.Completed ? "executed" : "failed",
            outcome.Message,
            now);
        return (await ReadLawProposalAsync(connection, transaction, proposal.ProposalId))!;
    }

    private async Task<LawExecutionOutcome> ExecuteLawProposalAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        LawProposalDto proposal,
        string executorPlayerId,
        DateTimeOffset now)
    {
        var actor = string.Equals(executorPlayerId, "system", StringComparison.OrdinalIgnoreCase)
            ? proposal.SponsorPlayerId
            : executorPlayerId;
        var lawId = $"law-{proposal.ProposalId}";

        if (proposal.ProposalType == LawProposalTypes.TaxPolicy)
        {
            if (proposal.IncomeTaxRate is null ||
                proposal.MarketTaxRate is null ||
                proposal.ProductionTaxRate is null)
            {
                return LawExecutionOutcome.Failed("execute_tax_policy", "Tax policy proposal is missing rates.");
            }

            await using (var command = new NpgsqlCommand("""
                INSERT INTO world.country_tax_policies (
                    country_id, income_tax_rate, market_tax_rate, production_tax_rate,
                    updated_by_player_id, updated_at
                )
                VALUES (
                    @country_id, @income_tax_rate, @market_tax_rate, @production_tax_rate,
                    @updated_by_player_id, @updated_at
                )
                ON CONFLICT (country_id) DO UPDATE
                SET income_tax_rate = EXCLUDED.income_tax_rate,
                    market_tax_rate = EXCLUDED.market_tax_rate,
                    production_tax_rate = EXCLUDED.production_tax_rate,
                    updated_by_player_id = EXCLUDED.updated_by_player_id,
                    updated_at = EXCLUDED.updated_at;
                """, connection, transaction))
            {
                command.Parameters.AddWithValue("country_id", proposal.CountryId);
                command.Parameters.AddWithValue("income_tax_rate", proposal.IncomeTaxRate.Value);
                command.Parameters.AddWithValue("market_tax_rate", proposal.MarketTaxRate.Value);
                command.Parameters.AddWithValue("production_tax_rate", proposal.ProductionTaxRate.Value);
                command.Parameters.AddWithValue("updated_by_player_id", actor);
                command.Parameters.AddWithValue("updated_at", now);
                await command.ExecuteNonQueryAsync();
            }

            await using (var command = new NpgsqlCommand("""
                UPDATE world.countries
                SET tax_rate = @tax_rate,
                    updated_at = @updated_at
                WHERE country_id = @country_id;
                """, connection, transaction))
            {
                command.Parameters.AddWithValue("country_id", proposal.CountryId);
                command.Parameters.AddWithValue("tax_rate", proposal.IncomeTaxRate.Value);
                command.Parameters.AddWithValue("updated_at", now);
                await command.ExecuteNonQueryAsync();
            }

            await InsertLawAsync(connection, transaction, proposal, lawId, now);
            return LawExecutionOutcome.Succeeded(
                "execute_tax_policy",
                lawId,
                $"Tax policy changed to {proposal.IncomeTaxRate}/{proposal.MarketTaxRate}/{proposal.ProductionTaxRate}%.");
        }

        if (proposal.ProposalType is LawProposalTypes.TreasuryGrant or LawProposalTypes.TreasurySpend)
        {
            if (proposal.TreasuryAmount is null or <= 0)
            {
                return LawExecutionOutcome.Failed("execute_treasury_spend", "Treasury proposal is missing a positive amount.");
            }

            var amount = proposal.TreasuryAmount.Value;
            var balance = await ReadCountryTreasuryBalanceAsync(connection, transaction, proposal.CountryId);
            if (balance < amount)
            {
                return LawExecutionOutcome.Failed(
                    "execute_treasury_spend",
                    $"Treasury has {balance} gold, but the proposal requires {amount}.");
            }

            var newBalance = await AddCountryTreasuryAsync(connection, transaction, proposal.CountryId, -amount, now);
            var reason = string.IsNullOrWhiteSpace(proposal.TreasuryReason)
                ? proposal.Title
                : proposal.TreasuryReason;
            await AddTreasuryLedgerAsync(
                connection,
                transaction,
                proposal.CountryId,
                new CountryTaxCollectionRequest(
                    Amount: -amount,
                    GrossAmount: amount,
                    TaxRate: 0,
                    EntryType: $"law_{proposal.ProposalType}",
                    SourcePlayerId: actor,
                    CounterpartyPlayerId: proposal.TreasuryTargetPlayerId,
                    Description: reason,
                    IdempotencyKey: $"law:{proposal.ProposalId}:treasury",
                    LedgerId: $"ledger-{proposal.ProposalId}"),
                $"law:{proposal.ProposalId}:treasury",
                now);

            await InsertLawAsync(connection, transaction, proposal, lawId, now);
            return LawExecutionOutcome.Succeeded(
                "execute_treasury_spend",
                lawId,
                $"Treasury spent {amount} gold by congress law. New balance: {newBalance}.");
        }

        await InsertLawAsync(connection, transaction, proposal, lawId, now);
        return LawExecutionOutcome.Succeeded(
            $"record_{proposal.ProposalType}",
            lawId,
            $"Passed {proposal.ProposalType.Replace('_', ' ')} law was persisted.");
    }

    private static async Task UpdateLawProposalResolutionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string proposalId,
        string status,
        string executionStatus,
        string executionMessage,
        string? lawId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.law_proposals
            SET status = @status,
                resolved_at = @resolved_at,
                executed_at = @executed_at,
                execution_status = @execution_status,
                execution_message = @execution_message,
                result_law_id = @result_law_id,
                updated_at = @updated_at
            WHERE proposal_id = @proposal_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("proposal_id", proposalId);
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("resolved_at", now);
        command.Parameters.AddWithValue("executed_at", executionStatus == "executed" ? (object)now : DBNull.Value);
        command.Parameters.AddWithValue("execution_status", executionStatus);
        command.Parameters.AddWithValue("execution_message", executionMessage);
        command.Parameters.AddWithValue("result_law_id", (object?)lawId ?? DBNull.Value);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task InsertLawAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        LawProposalDto proposal,
        string lawId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.laws (
                law_id, country_id, source_proposal_id, proposal_type, title, description,
                status, enacted_at, created_at, updated_at
            )
            VALUES (
                @law_id, @country_id, @source_proposal_id, @proposal_type, @title, @description,
                'active', @enacted_at, @created_at, @updated_at
            )
            ON CONFLICT (law_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("law_id", lawId);
        command.Parameters.AddWithValue("country_id", proposal.CountryId);
        command.Parameters.AddWithValue("source_proposal_id", proposal.ProposalId);
        command.Parameters.AddWithValue("proposal_type", proposal.ProposalType);
        command.Parameters.AddWithValue("title", proposal.Title);
        command.Parameters.AddWithValue("description", proposal.Description);
        command.Parameters.AddWithValue("enacted_at", now);
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task InsertLawExecutionResultAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string proposalId,
        string? lawId,
        string executorPlayerId,
        string action,
        string status,
        string message,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.law_execution_results (
                execution_id, proposal_id, law_id, executor_player_id,
                action, status, message, created_at
            )
            VALUES (
                @execution_id, @proposal_id, @law_id, @executor_player_id,
                @action, @status, @message, @created_at
            )
            ON CONFLICT (execution_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("execution_id", $"law-execution-{proposalId}-{Guid.NewGuid():N}");
        command.Parameters.AddWithValue("proposal_id", proposalId);
        command.Parameters.AddWithValue("law_id", (object?)lawId ?? DBNull.Value);
        command.Parameters.AddWithValue("executor_player_id", executorPlayerId);
        command.Parameters.AddWithValue("action", action);
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<CongressAuthorizationDto> DetermineCongressAuthorizationAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string countryId,
        string? playerId)
    {
        if (string.IsNullOrWhiteSpace(playerId))
        {
            return CongressAuthorizationDto.Denied("Sign in as a citizen to use congress.");
        }

        await using (var citizenship = new NpgsqlCommand("""
            SELECT status
            FROM world.player_citizenships
            WHERE player_id = @player_id AND country_id = @country_id;
            """, connection, transaction))
        {
            citizenship.Parameters.AddWithValue("player_id", playerId);
            citizenship.Parameters.AddWithValue("country_id", countryId);
            var status = await citizenship.ExecuteScalarAsync() as string;
            if (!string.Equals(status, "active", StringComparison.OrdinalIgnoreCase))
            {
                return CongressAuthorizationDto.Denied("Only active citizens of this country can use congress.");
            }
        }

        var officeRole = await ReadActiveOfficeRoleAsync(connection, transaction, countryId, playerId);
        if (!string.IsNullOrWhiteSpace(officeRole))
        {
            return CongressAuthorizationDto.Allowed(
                officeRole,
                canResolve: true,
                "You hold an active elected country office.");
        }

        await using (var roleCommand = new NpgsqlCommand("""
            SELECT role
            FROM world.country_congress_authorizations
            WHERE country_id = @country_id AND player_id = @player_id;
            """, connection, transaction))
        {
            roleCommand.Parameters.AddWithValue("country_id", countryId);
            roleCommand.Parameters.AddWithValue("player_id", playerId);
            var role = await roleCommand.ExecuteScalarAsync() as string;
            if (!string.IsNullOrWhiteSpace(role))
            {
                return CongressAuthorizationDto.Allowed(
                    role,
                    canResolve: true,
                    "You hold recorded congress authorization.");
            }
        }

        return CongressAuthorizationDto.Allowed(
            "citizen-congress",
            canResolve: false,
            "MVP congress rule: active citizens may create proposals and vote once.");
    }

    private static async Task<List<LawProposalDto>> ReadLawProposalsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? countryId,
        string? status,
        int limit)
    {
        var conditions = new List<string>();
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            conditions.Add("lp.country_id = @country_id");
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            conditions.Add(status == "current"
                ? "lp.status = 'voting'"
                : "lp.status = @status");
        }

        var where = conditions.Count == 0 ? string.Empty : $"WHERE {string.Join(" AND ", conditions)}";
        await using var command = new NpgsqlCommand($"""
            {LawProposalSelectSql(where, "ORDER BY lp.created_at DESC LIMIT @limit")}
            """, connection, transaction);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }
        if (!string.IsNullOrWhiteSpace(status) && status != "current")
        {
            command.Parameters.AddWithValue("status", status);
        }
        command.Parameters.AddWithValue("limit", limit);

        var proposals = new List<LawProposalDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            proposals.Add(ReadLawProposal(reader));
        }

        return proposals;
    }

    private static async Task<LawProposalDto?> ReadLawProposalAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string proposalId,
        bool forUpdate = false)
    {
        var locking = forUpdate ? "FOR UPDATE OF lp" : string.Empty;
        await using var command = new NpgsqlCommand($"""
            {LawProposalSelectSql("WHERE lp.proposal_id = @proposal_id", locking)}
            """, connection, transaction);
        command.Parameters.AddWithValue("proposal_id", proposalId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadLawProposal(reader) : null;
    }

    private static string LawProposalSelectSql(string where, string suffix)
    {
        return $"""
            SELECT lp.proposal_id, lp.country_id, c.name AS country_name, c.code AS country_code,
                   lp.proposal_type, lp.title, lp.description, lp.sponsor_player_id,
                   lp.status, lp.voting_starts_at, lp.voting_ends_at, lp.resolved_at,
                   lp.executed_at, lp.approval_threshold_percent, lp.execution_status,
                   lp.execution_message, lp.result_law_id, lp.income_tax_rate,
                   lp.market_tax_rate, lp.production_tax_rate, lp.treasury_amount,
                   lp.treasury_target_player_id, lp.treasury_reason, lp.citizenship_rule,
                   (
                       SELECT COUNT(*)::integer
                       FROM world.law_proposal_votes v
                       WHERE v.proposal_id = lp.proposal_id AND v.choice = 'yes'
                   ) AS yes_votes,
                   (
                       SELECT COUNT(*)::integer
                       FROM world.law_proposal_votes v
                       WHERE v.proposal_id = lp.proposal_id AND v.choice = 'no'
                   ) AS no_votes,
                   (
                       SELECT COUNT(*)::integer
                       FROM world.law_proposal_votes v
                       WHERE v.proposal_id = lp.proposal_id AND v.choice = 'abstain'
                   ) AS abstain_votes,
                   (
                       SELECT COUNT(*)::integer
                       FROM world.law_proposal_votes v
                       WHERE v.proposal_id = lp.proposal_id
                   ) AS vote_count,
                   lp.created_at, lp.updated_at
            FROM world.law_proposals lp
            INNER JOIN world.countries c ON c.country_id = lp.country_id
            {where}
            {suffix};
            """;
    }

    private static LawProposalDto ReadLawProposal(NpgsqlDataReader reader)
    {
        return new LawProposalDto(
            ProposalId: reader.GetString(0),
            CountryId: reader.GetString(1),
            CountryName: reader.GetString(2),
            CountryCode: reader.GetString(3),
            ProposalType: reader.GetString(4),
            Title: reader.GetString(5),
            Description: reader.GetString(6),
            SponsorPlayerId: reader.GetString(7),
            Status: reader.GetString(8),
            VotingStartsAt: reader.GetFieldValue<DateTimeOffset>(9),
            VotingEndsAt: reader.GetFieldValue<DateTimeOffset>(10),
            ResolvedAt: reader.IsDBNull(11) ? null : reader.GetFieldValue<DateTimeOffset>(11),
            ExecutedAt: reader.IsDBNull(12) ? null : reader.GetFieldValue<DateTimeOffset>(12),
            ApprovalThresholdPercent: reader.GetInt32(13),
            ExecutionStatus: reader.GetString(14),
            ExecutionMessage: reader.GetString(15),
            ResultLawId: reader.IsDBNull(16) ? null : reader.GetString(16),
            IncomeTaxRate: reader.IsDBNull(17) ? null : reader.GetInt32(17),
            MarketTaxRate: reader.IsDBNull(18) ? null : reader.GetInt32(18),
            ProductionTaxRate: reader.IsDBNull(19) ? null : reader.GetInt32(19),
            TreasuryAmount: reader.IsDBNull(20) ? null : reader.GetInt32(20),
            TreasuryTargetPlayerId: reader.IsDBNull(21) ? null : reader.GetString(21),
            TreasuryReason: reader.GetString(22),
            CitizenshipRule: reader.IsDBNull(23) ? null : reader.GetString(23),
            YesVotes: reader.GetInt32(24),
            NoVotes: reader.GetInt32(25),
            AbstainVotes: reader.GetInt32(26),
            VoteCount: reader.GetInt32(27),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(28),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(29));
    }

    private static async Task<List<LawProposalVoteDto>> ReadLawProposalVotesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string proposalId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT vote_id, proposal_id, voter_player_id, country_id, choice, cast_at
            FROM world.law_proposal_votes
            WHERE proposal_id = @proposal_id
            ORDER BY cast_at DESC, vote_id DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("proposal_id", proposalId);
        command.Parameters.AddWithValue("limit", limit);

        var votes = new List<LawProposalVoteDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            votes.Add(ReadLawProposalVote(reader));
        }

        return votes;
    }

    private static async Task<LawProposalVoteDto?> ReadLawProposalVoteAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string proposalId,
        string voterPlayerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT vote_id, proposal_id, voter_player_id, country_id, choice, cast_at
            FROM world.law_proposal_votes
            WHERE proposal_id = @proposal_id AND voter_player_id = @voter_player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("proposal_id", proposalId);
        command.Parameters.AddWithValue("voter_player_id", voterPlayerId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadLawProposalVote(reader) : null;
    }

    private static LawProposalVoteDto ReadLawProposalVote(NpgsqlDataReader reader)
    {
        return new LawProposalVoteDto(
            VoteId: reader.GetString(0),
            ProposalId: reader.GetString(1),
            VoterPlayerId: reader.GetString(2),
            CountryId: reader.GetString(3),
            Choice: reader.GetString(4),
            CastAt: reader.GetFieldValue<DateTimeOffset>(5));
    }

    private static async Task<List<LawExecutionResultDto>> ReadLawExecutionResultsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string proposalId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT execution_id, proposal_id, law_id, executor_player_id,
                   action, status, message, created_at
            FROM world.law_execution_results
            WHERE proposal_id = @proposal_id
            ORDER BY created_at DESC, execution_id DESC;
            """, connection, transaction);
        command.Parameters.AddWithValue("proposal_id", proposalId);

        var executions = new List<LawExecutionResultDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            executions.Add(new LawExecutionResultDto(
                ExecutionId: reader.GetString(0),
                ProposalId: reader.GetString(1),
                LawId: reader.IsDBNull(2) ? null : reader.GetString(2),
                ExecutorPlayerId: reader.GetString(3),
                Action: reader.GetString(4),
                Status: reader.GetString(5),
                Message: reader.GetString(6),
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(7)));
        }

        return executions;
    }

    private static async Task<List<LawDto>> ReadLawsAsync(
        NpgsqlConnection connection,
        string? countryId,
        string? status,
        int limit)
    {
        var conditions = new List<string>();
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            conditions.Add("l.country_id = @country_id");
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            conditions.Add("l.status = @status");
        }

        var where = conditions.Count == 0 ? string.Empty : $"WHERE {string.Join(" AND ", conditions)}";
        await using var command = new NpgsqlCommand($"""
            SELECT l.law_id, l.country_id, c.name AS country_name, c.code AS country_code,
                   l.source_proposal_id, l.proposal_type, l.title, l.description,
                   l.status, l.enacted_at, l.repealed_at, l.updated_at
            FROM world.laws l
            INNER JOIN world.countries c ON c.country_id = l.country_id
            {where}
            ORDER BY l.enacted_at DESC
            LIMIT @limit;
            """, connection);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            command.Parameters.AddWithValue("status", status);
        }
        command.Parameters.AddWithValue("limit", limit);

        var laws = new List<LawDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            laws.Add(new LawDto(
                LawId: reader.GetString(0),
                CountryId: reader.GetString(1),
                CountryName: reader.GetString(2),
                CountryCode: reader.GetString(3),
                SourceProposalId: reader.IsDBNull(4) ? null : reader.GetString(4),
                ProposalType: reader.GetString(5),
                Title: reader.GetString(6),
                Description: reader.GetString(7),
                Status: reader.GetString(8),
                EnactedAt: reader.GetFieldValue<DateTimeOffset>(9),
                RepealedAt: reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(11)));
        }

        return laws;
    }

    private static string? NormalizeLawProposalStatus(string? status)
    {
        var normalized = status?.Trim().ToLowerInvariant();
        return string.IsNullOrWhiteSpace(normalized)
            ? null
            : normalized is "current" or "voting" or "passed" or "rejected" or "execution_failed"
                ? normalized
                : null;
    }

    private static string? NormalizeLawStatus(string? status)
    {
        var normalized = status?.Trim().ToLowerInvariant();
        return string.IsNullOrWhiteSpace(normalized)
            ? null
            : normalized is "active" or "repealed"
                ? normalized
                : null;
    }

    private static string SlugifyLawTitle(string value)
    {
        var lower = value.Trim().ToLowerInvariant();
        var slug = System.Text.RegularExpressions.Regex.Replace(lower, "[^a-z0-9]+", "-").Trim('-');
        return string.IsNullOrWhiteSpace(slug) ? "proposal" : slug[..Math.Min(slug.Length, 48)];
    }
}

internal static class LawProposalTypes
{
    public const string TaxPolicy = "tax_policy";
    public const string TreasuryGrant = "treasury_grant";
    public const string TreasurySpend = "treasury_spend";
    public const string CitizenshipRule = "citizenship_rule";
    public const string WarDeclaration = "war_declaration";
}

internal sealed record LawProposalListResponse(
    LawProposalDto[] Proposals,
    CongressAuthorizationDto? Authorization,
    DateTimeOffset UpdatedAt);

internal sealed record LawProposalDetailsResponse(
    LawProposalDto Proposal,
    LawProposalVoteDto[] Votes,
    LawExecutionResultDto[] Executions,
    CongressAuthorizationDto? Authorization,
    DateTimeOffset UpdatedAt);

internal sealed record LawVoteListResponse(
    string ProposalId,
    LawProposalVoteDto[] Votes,
    DateTimeOffset UpdatedAt);

internal sealed record LawListResponse(LawDto[] Laws, DateTimeOffset UpdatedAt);

internal sealed record LawProposalDto(
    string ProposalId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string ProposalType,
    string Title,
    string Description,
    string SponsorPlayerId,
    string Status,
    DateTimeOffset VotingStartsAt,
    DateTimeOffset VotingEndsAt,
    DateTimeOffset? ResolvedAt,
    DateTimeOffset? ExecutedAt,
    int ApprovalThresholdPercent,
    string ExecutionStatus,
    string ExecutionMessage,
    string? ResultLawId,
    int? IncomeTaxRate,
    int? MarketTaxRate,
    int? ProductionTaxRate,
    int? TreasuryAmount,
    string? TreasuryTargetPlayerId,
    string TreasuryReason,
    string? CitizenshipRule,
    int YesVotes,
    int NoVotes,
    int AbstainVotes,
    int VoteCount,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record LawDto(
    string LawId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string? SourceProposalId,
    string ProposalType,
    string Title,
    string Description,
    string Status,
    DateTimeOffset EnactedAt,
    DateTimeOffset? RepealedAt,
    DateTimeOffset UpdatedAt);

internal sealed record LawProposalVoteDto(
    string VoteId,
    string ProposalId,
    string VoterPlayerId,
    string CountryId,
    string Choice,
    DateTimeOffset CastAt);

internal sealed record LawExecutionResultDto(
    string ExecutionId,
    string ProposalId,
    string? LawId,
    string ExecutorPlayerId,
    string Action,
    string Status,
    string Message,
    DateTimeOffset CreatedAt);

internal sealed record CongressAuthorizationDto(
    bool CanCreateProposal,
    bool CanVote,
    bool CanResolve,
    string? Role,
    string Message)
{
    public static CongressAuthorizationDto Allowed(string role, bool canResolve, string message)
    {
        return new CongressAuthorizationDto(true, true, canResolve, role, message);
    }

    public static CongressAuthorizationDto Denied(string message)
    {
        return new CongressAuthorizationDto(false, false, false, null, message);
    }
}

internal sealed record LawProposalMutationResult(
    bool Completed,
    string Message,
    LawProposalDto? Proposal,
    CongressAuthorizationDto? Authorization,
    int StatusCode,
    DateTimeOffset UpdatedAt)
{
    public static LawProposalMutationResult Failed(
        string message,
        int statusCode,
        LawProposalDto? proposal)
    {
        return new LawProposalMutationResult(false, message, proposal, null, statusCode, DateTimeOffset.UtcNow);
    }
}

internal sealed record LawVoteMutationResult(
    bool Completed,
    string Message,
    LawProposalDto? Proposal,
    LawProposalVoteDto? Vote,
    int StatusCode,
    DateTimeOffset UpdatedAt)
{
    public static LawVoteMutationResult Failed(
        string message,
        int statusCode,
        LawProposalDto? proposal,
        LawProposalVoteDto? vote)
    {
        return new LawVoteMutationResult(false, message, proposal, vote, statusCode, DateTimeOffset.UtcNow);
    }
}

internal sealed record LawProposalCreateRequest(
    string? CountryId,
    string? ProposalType,
    string? Title,
    string? Description,
    int? IncomeTaxRate,
    int? MarketTaxRate,
    int? ProductionTaxRate,
    int? TreasuryAmount,
    string? TreasuryTargetPlayerId,
    string? TreasuryReason,
    string? CitizenshipRule,
    int? VotingHours);

internal sealed record LawVoteRequest(string Choice);

internal sealed record LawExecutionOutcome(
    bool Completed,
    string Action,
    string? LawId,
    string Message)
{
    public static LawExecutionOutcome Succeeded(string action, string lawId, string message)
    {
        return new LawExecutionOutcome(true, action, lawId, message);
    }

    public static LawExecutionOutcome Failed(string action, string message)
    {
        return new LawExecutionOutcome(false, action, null, message);
    }
}

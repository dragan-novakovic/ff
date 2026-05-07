using System.Text.RegularExpressions;
using Npgsql;

internal static partial class PoliticsEndpoints
{
    public static void MapPoliticsEndpoints(this WebApplication app)
    {
        app.MapGet("/politics/parties", async (
            string? countryId,
            WorldStore world) =>
            Results.Ok(await world.GetPoliticalPartiesAsync(countryId))).WithName("GetPoliticalParties");

        app.MapGet("/players/{playerId}/politics/status", async (
            string playerId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return Results.Ok(await world.GetPlayerPoliticsStatusAsync(access.PlayerId!));
        }).WithName("GetPlayerPoliticsStatus");

        app.MapPost("/players/{playerId}/politics/parties", async (
            string playerId,
            PoliticalPartyCreateRequest party,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidatePartyCreate(party);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.CreatePoliticalPartyAsync(access.PlayerId!, party);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Country was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
        }).WithName("CreatePoliticalParty");

        app.MapPost("/players/{playerId}/politics/parties/{partyId}/join", async (
            string playerId,
            string partyId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.JoinPoliticalPartyAsync(access.PlayerId!, partyId);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Political party was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
        }).WithName("JoinPoliticalParty");

        app.MapPost("/players/{playerId}/politics/parties/{partyId}/leave", async (
            string playerId,
            string partyId,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var result = await world.LeavePoliticalPartyAsync(access.PlayerId!, partyId);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Political party was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
        }).WithName("LeavePoliticalParty");

        app.MapGet("/politics/elections", async (
            string? countryId,
            string? status,
            WorldStore world) =>
            Results.Ok(await world.GetElectionsAsync(countryId, status))).WithName("GetElections");

        app.MapGet("/politics/elections/{electionId}", async (
            string electionId,
            WorldStore world) =>
        {
            var election = await world.GetElectionAsync(electionId);
            return election is null
                ? Results.NotFound(new ErrorResponse("Election was not found."))
                : Results.Ok(election);
        }).WithName("GetElection");

        app.MapGet("/politics/elections/{electionId}/results", async (
            string electionId,
            WorldStore world) =>
        {
            var results = await world.GetElectionResultsAsync(electionId);
            return results is null
                ? Results.NotFound(new ErrorResponse("Election was not found."))
                : Results.Ok(results);
        }).WithName("GetElectionResults");

        app.MapPost("/players/{playerId}/politics/elections/{electionId}/candidacies", async (
            string playerId,
            string electionId,
            CandidacyDeclarationRequest candidacy,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateCandidacy(candidacy);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            var result = await world.DeclareCandidacyAsync(access.PlayerId!, electionId, candidacy);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Election was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
        }).WithName("DeclareCandidacy");

        app.MapPost("/players/{playerId}/politics/elections/{electionId}/vote", async (
            string playerId,
            string electionId,
            VoteRequest vote,
            HttpRequest request,
            WorldStore world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (string.IsNullOrWhiteSpace(vote.CandidacyId))
            {
                return Results.BadRequest(new ErrorResponse("Candidacy is required."));
            }

            var result = await world.CastVoteAsync(access.PlayerId!, electionId, vote);
            if (result is null)
            {
                return Results.NotFound(new ErrorResponse("Election was not found."));
            }

            return result.Completed
                ? Results.Ok(result)
                : Results.Json(result, statusCode: StatusCodes.Status409Conflict);
        }).WithName("CastElectionVote");

        app.MapGet("/politics/office-holders", async (
            string? countryId,
            WorldStore world) =>
            Results.Ok(await world.GetOfficeHoldersAsync(countryId))).WithName("GetOfficeHolders");
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
                new ErrorResponse("You cannot access another player's politics state."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string? ValidatePartyCreate(PoliticalPartyCreateRequest party)
    {
        if (string.IsNullOrWhiteSpace(party.CountryId))
        {
            return "Country is required.";
        }

        if (string.IsNullOrWhiteSpace(party.Name) || party.Name.Trim().Length < 3)
        {
            return "Party name must be at least 3 characters.";
        }

        if (string.IsNullOrWhiteSpace(party.ShortName) || party.ShortName.Trim().Length is < 2 or > 8)
        {
            return "Party short name must be 2-8 characters.";
        }

        if (party.Description?.Length > 500 || party.Ideology?.Length > 120)
        {
            return "Party description or ideology is too long.";
        }

        return null;
    }

    private static string? ValidateCandidacy(CandidacyDeclarationRequest candidacy)
    {
        if (candidacy.Manifesto?.Length > 800)
        {
            return "Candidacy manifesto is too long.";
        }

        return null;
    }
}

internal sealed partial class WorldStore
{
    private const string PresidentOfficeId = "president";
    private const string PresidentOfficeName = "President";

    public async Task InitializePoliticsSchemaAsync()
    {
        const string sql = """
            CREATE TABLE IF NOT EXISTS world.political_parties (
                party_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                name text NOT NULL,
                short_name text NOT NULL,
                description text NOT NULL,
                ideology text NOT NULL,
                founder_player_id text NOT NULL,
                status text NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE UNIQUE INDEX IF NOT EXISTS ix_world_political_parties_country_name
                ON world.political_parties (country_id, lower(name));

            CREATE INDEX IF NOT EXISTS ix_world_political_parties_country_status
                ON world.political_parties (country_id, status);

            CREATE TABLE IF NOT EXISTS world.party_memberships (
                membership_id text PRIMARY KEY,
                party_id text NOT NULL REFERENCES world.political_parties(party_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                role text NOT NULL,
                status text NOT NULL,
                joined_at timestamptz NOT NULL,
                left_at timestamptz NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE UNIQUE INDEX IF NOT EXISTS ix_world_party_memberships_party_player
                ON world.party_memberships (party_id, player_id);

            CREATE UNIQUE INDEX IF NOT EXISTS ix_world_party_memberships_one_active_player
                ON world.party_memberships (player_id)
                WHERE status = 'active';

            CREATE INDEX IF NOT EXISTS ix_world_party_memberships_party_status
                ON world.party_memberships (party_id, status);

            CREATE TABLE IF NOT EXISTS world.elections (
                election_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                office_id text NOT NULL,
                office_name text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                status text NOT NULL,
                voting_starts_at timestamptz NOT NULL,
                voting_ends_at timestamptz NOT NULL,
                term_starts_at timestamptz NOT NULL,
                term_ends_at timestamptz NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_elections_country_status
                ON world.elections (country_id, status, voting_ends_at);

            CREATE TABLE IF NOT EXISTS world.candidacies (
                candidacy_id text PRIMARY KEY,
                election_id text NOT NULL REFERENCES world.elections(election_id) ON DELETE CASCADE,
                player_id text NOT NULL,
                party_id text NULL REFERENCES world.political_parties(party_id) ON DELETE SET NULL,
                manifesto text NOT NULL,
                status text NOT NULL,
                declared_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE UNIQUE INDEX IF NOT EXISTS ix_world_candidacies_one_active_candidate
                ON world.candidacies (election_id, player_id)
                WHERE status = 'active';

            CREATE INDEX IF NOT EXISTS ix_world_candidacies_election_status
                ON world.candidacies (election_id, status);

            CREATE TABLE IF NOT EXISTS world.votes (
                vote_id text PRIMARY KEY,
                election_id text NOT NULL REFERENCES world.elections(election_id) ON DELETE CASCADE,
                voter_player_id text NOT NULL,
                candidacy_id text NOT NULL REFERENCES world.candidacies(candidacy_id) ON DELETE CASCADE,
                candidate_player_id text NOT NULL,
                country_id text NOT NULL REFERENCES world.countries(country_id),
                cast_at timestamptz NOT NULL
            );

            CREATE UNIQUE INDEX IF NOT EXISTS ix_world_votes_once_per_election
                ON world.votes (election_id, voter_player_id);

            CREATE INDEX IF NOT EXISTS ix_world_votes_candidacy
                ON world.votes (candidacy_id);

            CREATE TABLE IF NOT EXISTS world.office_terms (
                term_id text PRIMARY KEY,
                country_id text NOT NULL REFERENCES world.countries(country_id) ON DELETE CASCADE,
                office_id text NOT NULL,
                office_name text NOT NULL,
                player_id text NOT NULL,
                party_id text NULL REFERENCES world.political_parties(party_id) ON DELETE SET NULL,
                source_election_id text NULL REFERENCES world.elections(election_id) ON DELETE SET NULL,
                status text NOT NULL,
                started_at timestamptz NOT NULL,
                ends_at timestamptz NOT NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ix_world_office_terms_country_status
                ON world.office_terms (country_id, status, office_id);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task SeedPoliticsAsync()
    {
        await ResolveDueElectionsAsync();

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        foreach (var party in PoliticsCatalog.Parties)
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO world.political_parties (
                    party_id, country_id, name, short_name, description, ideology,
                    founder_player_id, status, created_at, updated_at
                )
                VALUES (
                    @party_id, @country_id, @name, @short_name, @description, @ideology,
                    'world-catalog', 'active', @created_at, @updated_at
                )
                ON CONFLICT (party_id) DO UPDATE
                SET name = EXCLUDED.name,
                    short_name = EXCLUDED.short_name,
                    description = EXCLUDED.description,
                    ideology = EXCLUDED.ideology,
                    status = EXCLUDED.status,
                    updated_at = EXCLUDED.updated_at;
                """, connection, transaction);
            command.Parameters.AddWithValue("party_id", party.PartyId);
            command.Parameters.AddWithValue("country_id", party.CountryId);
            command.Parameters.AddWithValue("name", party.Name);
            command.Parameters.AddWithValue("short_name", party.ShortName);
            command.Parameters.AddWithValue("description", party.Description);
            command.Parameters.AddWithValue("ideology", party.Ideology);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        foreach (var country in WorldCatalog.Countries)
        {
            var hasCurrentElection = await HasCurrentElectionAsync(
                connection,
                transaction,
                country.CountryId,
                PresidentOfficeId);
            if (hasCurrentElection)
            {
                continue;
            }

            var votingEndsAt = now.AddDays(3);
            await InsertElectionAsync(
                connection,
                transaction,
                new ElectionSeed(
                    ElectionId: $"election-{country.CountryId}-{PresidentOfficeId}-{now:yyyyMMddHHmmss}",
                    CountryId: country.CountryId,
                    OfficeId: PresidentOfficeId,
                    OfficeName: PresidentOfficeName,
                    Title: $"{country.Name} presidential election",
                    Description: $"Bootstrap persisted election for {country.Name}. Citizens can declare candidacy and cast one vote.",
                    Status: "voting",
                    VotingStartsAt: now.AddHours(-1),
                    VotingEndsAt: votingEndsAt,
                    TermStartsAt: votingEndsAt,
                    TermEndsAt: votingEndsAt.AddDays(30),
                    CreatedAt: now,
                    UpdatedAt: now));
        }

        await transaction.CommitAsync();
    }

    public async Task<PoliticalPartyListResponse> GetPoliticalPartiesAsync(string? countryId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        var parties = await ReadPoliticalPartiesAsync(
            connection,
            string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId));
        return new PoliticalPartyListResponse(parties.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<PlayerPoliticsStatusResponse> GetPlayerPoliticsStatusAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var citizenship = await ReadPlayerCitizenshipAsync(connection, null, normalizedPlayerId);
        var membership = await ReadActivePartyMembershipAsync(connection, null, normalizedPlayerId);
        var candidacies = await ReadPlayerCandidaciesAsync(connection, normalizedPlayerId);
        var votes = await ReadPlayerVotesAsync(connection, normalizedPlayerId);
        return new PlayerPoliticsStatusResponse(
            normalizedPlayerId,
            citizenship,
            membership,
            candidacies.ToArray(),
            votes.ToArray(),
            DateTimeOffset.UtcNow);
    }

    public async Task<PoliticalPartyMutationResult?> CreatePoliticalPartyAsync(
        string playerId,
        PoliticalPartyCreateRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedCountryId = NormalizeId(request.CountryId!);
        if (!await CountryExistsAsync(normalizedCountryId))
        {
            return null;
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.CountryId, normalizedCountryId, StringComparison.Ordinal) ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new PoliticalPartyMutationResult(
                false,
                "You must be an active citizen of the country to create a party there.",
                null,
                null,
                DateTimeOffset.UtcNow);
        }

        var name = request.Name!.Trim();
        if (await PoliticalPartyNameExistsAsync(connection, transaction, normalizedCountryId, name))
        {
            await transaction.CommitAsync();
            return new PoliticalPartyMutationResult(
                false,
                "A political party with that name already exists in this country.",
                null,
                null,
                DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        var partyId = $"party-{normalizedCountryId}-{Slugify(name)}-{Guid.NewGuid().ToString("N")[..8]}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.political_parties (
                party_id, country_id, name, short_name, description, ideology,
                founder_player_id, status, created_at, updated_at
            )
            VALUES (
                @party_id, @country_id, @name, @short_name, @description, @ideology,
                @founder_player_id, 'active', @created_at, @updated_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("party_id", partyId);
            command.Parameters.AddWithValue("country_id", normalizedCountryId);
            command.Parameters.AddWithValue("name", name);
            command.Parameters.AddWithValue("short_name", request.ShortName!.Trim().ToUpperInvariant());
            command.Parameters.AddWithValue("description", CleanOptionalText(request.Description, "A newly founded citizen party."));
            command.Parameters.AddWithValue("ideology", CleanOptionalText(request.Ideology, "Citizen platform"));
            command.Parameters.AddWithValue("founder_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("created_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        await LeaveActivePartyMembershipsAsync(connection, transaction, normalizedPlayerId, now);
        var membershipId = MembershipId(partyId, normalizedPlayerId);
        await UpsertPartyMembershipAsync(
            connection,
            transaction,
            membershipId,
            partyId,
            normalizedPlayerId,
            normalizedCountryId,
            "leader",
            now);

        var party = await ReadPoliticalPartyAsync(connection, transaction, partyId);
        var membership = await ReadActivePartyMembershipAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return new PoliticalPartyMutationResult(
            true,
            $"Created {party!.Name} and joined as party leader.",
            party,
            membership,
            now);
    }

    public async Task<PoliticalPartyMutationResult?> JoinPoliticalPartyAsync(string playerId, string partyId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedPartyId = NormalizeId(partyId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var party = await ReadPoliticalPartyAsync(connection, transaction, normalizedPartyId);
        if (party is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.CountryId, party.CountryId, StringComparison.Ordinal) ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new PoliticalPartyMutationResult(
                false,
                $"You must be an active citizen of {party.CountryName} to join this party.",
                party,
                null,
                DateTimeOffset.UtcNow);
        }

        var activeMembership = await ReadActivePartyMembershipAsync(connection, transaction, normalizedPlayerId);
        if (activeMembership is not null &&
            string.Equals(activeMembership.PartyId, normalizedPartyId, StringComparison.Ordinal))
        {
            await transaction.CommitAsync();
            return new PoliticalPartyMutationResult(
                true,
                $"You are already a member of {party.Name}.",
                party,
                activeMembership,
                DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        await LeaveActivePartyMembershipsAsync(connection, transaction, normalizedPlayerId, now);
        await UpsertPartyMembershipAsync(
            connection,
            transaction,
            MembershipId(normalizedPartyId, normalizedPlayerId),
            normalizedPartyId,
            normalizedPlayerId,
            party.CountryId,
            "member",
            now);

        var membership = await ReadActivePartyMembershipAsync(connection, transaction, normalizedPlayerId);
        party = await ReadPoliticalPartyAsync(connection, transaction, normalizedPartyId);
        await transaction.CommitAsync();

        return new PoliticalPartyMutationResult(
            true,
            $"Joined {party!.Name}.",
            party,
            membership,
            now);
    }

    public async Task<PoliticalPartyMutationResult?> LeavePoliticalPartyAsync(string playerId, string partyId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedPartyId = NormalizeId(partyId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var party = await ReadPoliticalPartyAsync(connection, transaction, normalizedPartyId);
        if (party is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        var membership = await ReadActivePartyMembershipAsync(connection, transaction, normalizedPlayerId, normalizedPartyId);
        if (membership is null)
        {
            await transaction.CommitAsync();
            return new PoliticalPartyMutationResult(
                false,
                $"You are not an active member of {party.Name}.",
                party,
                null,
                DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("""
            UPDATE world.party_memberships
            SET status = 'left',
                left_at = @left_at,
                updated_at = @updated_at
            WHERE membership_id = @membership_id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("membership_id", membership.MembershipId);
            command.Parameters.AddWithValue("left_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        party = await ReadPoliticalPartyAsync(connection, transaction, normalizedPartyId);
        await transaction.CommitAsync();

        return new PoliticalPartyMutationResult(
            true,
            $"Left {party!.Name}.",
            party,
            null,
            now);
    }

    public async Task<ElectionListResponse> GetElectionsAsync(string? countryId, string? status)
    {
        await ResolveDueElectionsAsync();
        await using var connection = await _dataSource.OpenConnectionAsync();
        var elections = await ReadElectionSummariesAsync(
            connection,
            string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId),
            NormalizeElectionStatusFilter(status));
        return new ElectionListResponse(elections.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<ElectionDetailsResponse?> GetElectionAsync(string electionId)
    {
        await ResolveDueElectionsAsync();
        var normalizedElectionId = NormalizeId(electionId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var election = await ReadElectionAsync(connection, null, normalizedElectionId);
        if (election is null)
        {
            return null;
        }

        var candidacies = await ReadCandidaciesAsync(connection, null, normalizedElectionId);
        var results = await ReadElectionResultRowsAsync(connection, null, normalizedElectionId);
        return new ElectionDetailsResponse(election, candidacies.ToArray(), results.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<ElectionResultsResponse?> GetElectionResultsAsync(string electionId)
    {
        await ResolveDueElectionsAsync();
        var normalizedElectionId = NormalizeId(electionId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var election = await ReadElectionAsync(connection, null, normalizedElectionId);
        if (election is null)
        {
            return null;
        }

        var results = await ReadElectionResultRowsAsync(connection, null, normalizedElectionId);
        var holders = await ReadOfficeTermsAsync(connection, null, election.CountryId, election.OfficeId);
        return new ElectionResultsResponse(election, results.ToArray(), holders.ToArray(), DateTimeOffset.UtcNow);
    }

    public async Task<CandidacyMutationResult?> DeclareCandidacyAsync(
        string playerId,
        string electionId,
        CandidacyDeclarationRequest request)
    {
        await ResolveDueElectionsAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedElectionId = NormalizeId(electionId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var election = await ReadElectionAsync(connection, transaction, normalizedElectionId, forUpdate: true);
        if (election is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        if (!CanDeclareCandidacy(election))
        {
            await transaction.CommitAsync();
            return new CandidacyMutationResult(
                false,
                "Candidacy declarations are closed for this election.",
                null,
                election,
                DateTimeOffset.UtcNow);
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.CountryId, election.CountryId, StringComparison.Ordinal) ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new CandidacyMutationResult(
                false,
                $"You must be an active citizen of {election.CountryName} to run in this election.",
                null,
                election,
                DateTimeOffset.UtcNow);
        }

        string? partyId = null;
        if (!string.IsNullOrWhiteSpace(request.PartyId))
        {
            var requestedPartyId = NormalizeId(request.PartyId);
            var membership = await ReadActivePartyMembershipAsync(
                connection,
                transaction,
                normalizedPlayerId,
                requestedPartyId);
            if (membership is null ||
                !string.Equals(membership.CountryId, election.CountryId, StringComparison.Ordinal))
            {
                await transaction.CommitAsync();
                return new CandidacyMutationResult(
                    false,
                    "You must be an active member of that country's party to run under its banner.",
                    null,
                    election,
                    DateTimeOffset.UtcNow);
            }

            partyId = requestedPartyId;
        }

        var existing = await ReadPlayerCandidacyAsync(connection, transaction, normalizedElectionId, normalizedPlayerId);
        if (existing is not null)
        {
            await transaction.CommitAsync();
            return new CandidacyMutationResult(
                true,
                "Your candidacy is already declared for this election.",
                existing,
                election,
                DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        var candidacyId = $"candidacy-{normalizedElectionId}-{normalizedPlayerId}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.candidacies (
                candidacy_id, election_id, player_id, party_id, manifesto,
                status, declared_at, updated_at
            )
            VALUES (
                @candidacy_id, @election_id, @player_id, @party_id, @manifesto,
                'active', @declared_at, @updated_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("candidacy_id", candidacyId);
            command.Parameters.AddWithValue("election_id", normalizedElectionId);
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("party_id", (object?)partyId ?? DBNull.Value);
            command.Parameters.AddWithValue("manifesto", CleanOptionalText(request.Manifesto, "A citizen candidacy focused on country growth."));
            command.Parameters.AddWithValue("declared_at", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var candidacy = await ReadCandidacyAsync(connection, transaction, candidacyId);
        election = await ReadElectionAsync(connection, transaction, normalizedElectionId);
        await transaction.CommitAsync();

        return new CandidacyMutationResult(
            true,
            $"Declared candidacy for {election!.Title}.",
            candidacy,
            election,
            now);
    }

    public async Task<VoteMutationResult?> CastVoteAsync(
        string playerId,
        string electionId,
        VoteRequest request)
    {
        await ResolveDueElectionsAsync();
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedElectionId = NormalizeId(electionId);
        var normalizedCandidacyId = NormalizeId(request.CandidacyId!);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var election = await ReadElectionAsync(connection, transaction, normalizedElectionId, forUpdate: true);
        if (election is null)
        {
            await transaction.RollbackAsync();
            return null;
        }

        if (!CanVoteInElection(election))
        {
            await transaction.CommitAsync();
            return new VoteMutationResult(
                false,
                "Voting is not open for this election.",
                null,
                [],
                DateTimeOffset.UtcNow);
        }

        var citizenship = await ReadPlayerCitizenshipAsync(connection, transaction, normalizedPlayerId);
        if (citizenship is null ||
            !string.Equals(citizenship.CountryId, election.CountryId, StringComparison.Ordinal) ||
            !string.Equals(citizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new VoteMutationResult(
                false,
                $"You must be an active citizen of {election.CountryName} to vote.",
                null,
                [],
                DateTimeOffset.UtcNow);
        }

        var existingVote = await ReadVoteAsync(connection, transaction, normalizedElectionId, normalizedPlayerId);
        if (existingVote is not null)
        {
            var currentResults = await ReadElectionResultRowsAsync(connection, transaction, normalizedElectionId);
            await transaction.CommitAsync();
            return new VoteMutationResult(
                false,
                "You have already voted in this election.",
                existingVote,
                currentResults.ToArray(),
                DateTimeOffset.UtcNow);
        }

        var candidacy = await ReadCandidacyAsync(connection, transaction, normalizedCandidacyId);
        if (candidacy is null ||
            !string.Equals(candidacy.ElectionId, normalizedElectionId, StringComparison.Ordinal) ||
            !string.Equals(candidacy.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            await transaction.CommitAsync();
            return new VoteMutationResult(
                false,
                "Selected candidacy is not active in this election.",
                null,
                [],
                DateTimeOffset.UtcNow);
        }

        var now = DateTimeOffset.UtcNow;
        var voteId = $"vote-{normalizedElectionId}-{normalizedPlayerId}";
        await using (var command = new NpgsqlCommand("""
            INSERT INTO world.votes (
                vote_id, election_id, voter_player_id, candidacy_id,
                candidate_player_id, country_id, cast_at
            )
            VALUES (
                @vote_id, @election_id, @voter_player_id, @candidacy_id,
                @candidate_player_id, @country_id, @cast_at
            );
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("vote_id", voteId);
            command.Parameters.AddWithValue("election_id", normalizedElectionId);
            command.Parameters.AddWithValue("voter_player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("candidacy_id", normalizedCandidacyId);
            command.Parameters.AddWithValue("candidate_player_id", candidacy.PlayerId);
            command.Parameters.AddWithValue("country_id", election.CountryId);
            command.Parameters.AddWithValue("cast_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var vote = await ReadVoteAsync(connection, transaction, normalizedElectionId, normalizedPlayerId);
        var results = await ReadElectionResultRowsAsync(connection, transaction, normalizedElectionId);
        await transaction.CommitAsync();

        return new VoteMutationResult(
            true,
            "Vote recorded.",
            vote,
            results.ToArray(),
            now);
    }

    public async Task<OfficeHolderListResponse> GetOfficeHoldersAsync(string? countryId)
    {
        await ResolveDueElectionsAsync();
        await using var connection = await _dataSource.OpenConnectionAsync();
        var terms = await ReadOfficeTermsAsync(
            connection,
            null,
            string.IsNullOrWhiteSpace(countryId) ? null : NormalizeId(countryId),
            null);
        return new OfficeHolderListResponse(terms.ToArray(), DateTimeOffset.UtcNow);
    }

    private static async Task<List<PoliticalPartyDto>> ReadPoliticalPartiesAsync(
        NpgsqlConnection connection,
        string? countryId)
    {
        var sql = string.IsNullOrWhiteSpace(countryId)
            ? PoliticalPartySelectSql(string.Empty, "ORDER BY c.name, p.name")
            : PoliticalPartySelectSql("WHERE p.country_id = @country_id", "ORDER BY p.name");
        await using var command = new NpgsqlCommand(sql, connection);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }

        var parties = new List<PoliticalPartyDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            parties.Add(ReadPoliticalParty(reader));
        }

        return parties;
    }

    private static async Task<PoliticalPartyDto?> ReadPoliticalPartyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string partyId)
    {
        await using var command = new NpgsqlCommand(
            PoliticalPartySelectSql("WHERE p.party_id = @party_id", string.Empty),
            connection,
            transaction);
        command.Parameters.AddWithValue("party_id", partyId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadPoliticalParty(reader) : null;
    }

    private static string PoliticalPartySelectSql(string where, string orderBy)
    {
        return $"""
            SELECT p.party_id, p.country_id, c.name AS country_name, c.code AS country_code,
                   p.name, p.short_name, p.description, p.ideology,
                   p.founder_player_id, p.status,
                   COUNT(pm.membership_id) FILTER (WHERE pm.status = 'active')::bigint AS member_count,
                   p.created_at, p.updated_at
            FROM world.political_parties p
            INNER JOIN world.countries c ON c.country_id = p.country_id
            LEFT JOIN world.party_memberships pm ON pm.party_id = p.party_id
            {where}
            GROUP BY p.party_id, p.country_id, c.name, c.code, p.name, p.short_name,
                     p.description, p.ideology, p.founder_player_id, p.status,
                     p.created_at, p.updated_at
            {orderBy}
            """;
    }

    private static PoliticalPartyDto ReadPoliticalParty(NpgsqlDataReader reader)
    {
        return new PoliticalPartyDto(
            PartyId: reader.GetString(0),
            CountryId: reader.GetString(1),
            CountryName: reader.GetString(2),
            CountryCode: reader.GetString(3),
            Name: reader.GetString(4),
            ShortName: reader.GetString(5),
            Description: reader.GetString(6),
            Ideology: reader.GetString(7),
            FounderPlayerId: reader.GetString(8),
            Status: reader.GetString(9),
            MemberCount: Convert.ToInt32(reader.GetInt64(10)),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(11),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(12));
    }

    private static async Task<bool> PoliticalPartyNameExistsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId,
        string name)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM world.political_parties
            WHERE country_id = @country_id
              AND lower(name) = lower(@name)
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("name", name);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task<PoliticalPartyMembershipDto?> ReadActivePartyMembershipAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId,
        string? partyId = null)
    {
        var sql = string.IsNullOrWhiteSpace(partyId)
            ? PartyMembershipSelectSql("WHERE pm.player_id = @player_id AND pm.status = 'active'")
            : PartyMembershipSelectSql("WHERE pm.player_id = @player_id AND pm.party_id = @party_id AND pm.status = 'active'");
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        if (!string.IsNullOrWhiteSpace(partyId))
        {
            command.Parameters.AddWithValue("party_id", partyId);
        }

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadPartyMembership(reader) : null;
    }

    private static string PartyMembershipSelectSql(string suffix)
    {
        return $"""
            SELECT pm.membership_id, pm.party_id, p.name AS party_name,
                   pm.country_id, c.name AS country_name, c.code AS country_code,
                   pm.player_id, pm.role, pm.status, pm.joined_at, pm.left_at, pm.updated_at
            FROM world.party_memberships pm
            INNER JOIN world.political_parties p ON p.party_id = pm.party_id
            INNER JOIN world.countries c ON c.country_id = pm.country_id
            {suffix}
            ORDER BY pm.updated_at DESC
            LIMIT 1;
            """;
    }

    private static PoliticalPartyMembershipDto ReadPartyMembership(NpgsqlDataReader reader)
    {
        return new PoliticalPartyMembershipDto(
            MembershipId: reader.GetString(0),
            PartyId: reader.GetString(1),
            PartyName: reader.GetString(2),
            CountryId: reader.GetString(3),
            CountryName: reader.GetString(4),
            CountryCode: reader.GetString(5),
            PlayerId: reader.GetString(6),
            Role: reader.GetString(7),
            Status: reader.GetString(8),
            JoinedAt: reader.GetFieldValue<DateTimeOffset>(9),
            LeftAt: reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(11));
    }

    private static async Task LeaveActivePartyMembershipsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE world.party_memberships
            SET status = 'left',
                left_at = @left_at,
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND status = 'active';
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("left_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task UpsertPartyMembershipAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string membershipId,
        string partyId,
        string playerId,
        string countryId,
        string role,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.party_memberships (
                membership_id, party_id, player_id, country_id, role,
                status, joined_at, left_at, updated_at
            )
            VALUES (
                @membership_id, @party_id, @player_id, @country_id, @role,
                'active', @joined_at, NULL, @updated_at
            )
            ON CONFLICT (party_id, player_id) DO UPDATE
            SET role = EXCLUDED.role,
                status = 'active',
                left_at = NULL,
                updated_at = EXCLUDED.updated_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("membership_id", membershipId);
        command.Parameters.AddWithValue("party_id", partyId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("role", role);
        command.Parameters.AddWithValue("joined_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<bool> HasCurrentElectionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string countryId,
        string officeId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT 1
            FROM world.elections
            WHERE country_id = @country_id
              AND office_id = @office_id
              AND status IN ('scheduled', 'voting')
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("country_id", countryId);
        command.Parameters.AddWithValue("office_id", officeId);
        return await command.ExecuteScalarAsync() is not null;
    }

    private static async Task InsertElectionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        ElectionSeed seed)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO world.elections (
                election_id, country_id, office_id, office_name, title, description,
                status, voting_starts_at, voting_ends_at, term_starts_at, term_ends_at,
                created_at, updated_at
            )
            VALUES (
                @election_id, @country_id, @office_id, @office_name, @title, @description,
                @status, @voting_starts_at, @voting_ends_at, @term_starts_at, @term_ends_at,
                @created_at, @updated_at
            )
            ON CONFLICT (election_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("election_id", seed.ElectionId);
        command.Parameters.AddWithValue("country_id", seed.CountryId);
        command.Parameters.AddWithValue("office_id", seed.OfficeId);
        command.Parameters.AddWithValue("office_name", seed.OfficeName);
        command.Parameters.AddWithValue("title", seed.Title);
        command.Parameters.AddWithValue("description", seed.Description);
        command.Parameters.AddWithValue("status", seed.Status);
        command.Parameters.AddWithValue("voting_starts_at", seed.VotingStartsAt);
        command.Parameters.AddWithValue("voting_ends_at", seed.VotingEndsAt);
        command.Parameters.AddWithValue("term_starts_at", seed.TermStartsAt);
        command.Parameters.AddWithValue("term_ends_at", seed.TermEndsAt);
        command.Parameters.AddWithValue("created_at", seed.CreatedAt);
        command.Parameters.AddWithValue("updated_at", seed.UpdatedAt);
        await command.ExecuteNonQueryAsync();
    }

    private async Task ResolveDueElectionsAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await using (var command = new NpgsqlCommand("""
            UPDATE world.elections
            SET status = 'voting',
                updated_at = @updated_at
            WHERE status = 'scheduled'
              AND voting_starts_at <= @now;

            UPDATE world.office_terms
            SET status = 'expired',
                updated_at = @updated_at
            WHERE status IN ('active', 'scheduled')
              AND ends_at <= @now;

            UPDATE world.office_terms
            SET status = 'active',
                updated_at = @updated_at
            WHERE status = 'scheduled'
              AND started_at <= @now
              AND ends_at > @now;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("now", now);
            command.Parameters.AddWithValue("updated_at", now);
            await command.ExecuteNonQueryAsync();
        }

        var dueElectionIds = new List<string>();
        await using (var command = new NpgsqlCommand("""
            SELECT election_id
            FROM world.elections
            WHERE status = 'voting'
              AND voting_ends_at <= @now
            FOR UPDATE;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("now", now);
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                dueElectionIds.Add(reader.GetString(0));
            }
        }

        foreach (var electionId in dueElectionIds)
        {
            var election = await ReadElectionAsync(connection, transaction, electionId, forUpdate: true);
            if (election is null)
            {
                continue;
            }

            var winner = await ReadElectionWinnerAsync(connection, transaction, election.ElectionId);
            await using (var updateElection = new NpgsqlCommand("""
                UPDATE world.elections
                SET status = 'resolved',
                    updated_at = @updated_at
                WHERE election_id = @election_id;
                """, connection, transaction))
            {
                updateElection.Parameters.AddWithValue("election_id", election.ElectionId);
                updateElection.Parameters.AddWithValue("updated_at", now);
                await updateElection.ExecuteNonQueryAsync();
            }

            if (winner is null || winner.Votes <= 0)
            {
                continue;
            }

            await using (var endCurrentTerm = new NpgsqlCommand("""
                UPDATE world.office_terms
                SET status = 'expired',
                    ends_at = LEAST(ends_at, @ends_at),
                    updated_at = @updated_at
                WHERE country_id = @country_id
                  AND office_id = @office_id
                  AND status = 'active';
                """, connection, transaction))
            {
                endCurrentTerm.Parameters.AddWithValue("country_id", election.CountryId);
                endCurrentTerm.Parameters.AddWithValue("office_id", election.OfficeId);
                endCurrentTerm.Parameters.AddWithValue("ends_at", election.TermStartsAt);
                endCurrentTerm.Parameters.AddWithValue("updated_at", now);
                await endCurrentTerm.ExecuteNonQueryAsync();
            }

            await using (var insertTerm = new NpgsqlCommand("""
                INSERT INTO world.office_terms (
                    term_id, country_id, office_id, office_name, player_id, party_id,
                    source_election_id, status, started_at, ends_at, created_at, updated_at
                )
                VALUES (
                    @term_id, @country_id, @office_id, @office_name, @player_id, @party_id,
                    @source_election_id, @status, @started_at, @ends_at, @created_at, @updated_at
                )
                ON CONFLICT (term_id) DO NOTHING;
                """, connection, transaction))
            {
                insertTerm.Parameters.AddWithValue("term_id", $"term-{election.ElectionId}");
                insertTerm.Parameters.AddWithValue("country_id", election.CountryId);
                insertTerm.Parameters.AddWithValue("office_id", election.OfficeId);
                insertTerm.Parameters.AddWithValue("office_name", election.OfficeName);
                insertTerm.Parameters.AddWithValue("player_id", winner.PlayerId);
                insertTerm.Parameters.AddWithValue("party_id", (object?)winner.PartyId ?? DBNull.Value);
                insertTerm.Parameters.AddWithValue("source_election_id", election.ElectionId);
                insertTerm.Parameters.AddWithValue("status", election.TermStartsAt <= now ? "active" : "scheduled");
                insertTerm.Parameters.AddWithValue("started_at", election.TermStartsAt);
                insertTerm.Parameters.AddWithValue("ends_at", election.TermEndsAt);
                insertTerm.Parameters.AddWithValue("created_at", now);
                insertTerm.Parameters.AddWithValue("updated_at", now);
                await insertTerm.ExecuteNonQueryAsync();
            }
        }

        await transaction.CommitAsync();
    }

    private static async Task<List<ElectionSummaryDto>> ReadElectionSummariesAsync(
        NpgsqlConnection connection,
        string? countryId,
        string? status)
    {
        var conditions = new List<string>();
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            conditions.Add("e.country_id = @country_id");
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            conditions.Add(status == "current"
                ? "e.status IN ('scheduled', 'voting')"
                : "e.status = @status");
        }

        var where = conditions.Count == 0 ? string.Empty : $"WHERE {string.Join(" AND ", conditions)}";
        await using var command = new NpgsqlCommand($"""
            {ElectionSelectSql()}
            {where}
            GROUP BY e.election_id, e.country_id, c.name, c.code, e.office_id, e.office_name,
                     e.title, e.description, e.status, e.voting_starts_at, e.voting_ends_at,
                     e.term_starts_at, e.term_ends_at, e.updated_at
            ORDER BY e.voting_ends_at DESC, e.country_id;
            """, connection);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }
        if (!string.IsNullOrWhiteSpace(status) && status != "current")
        {
            command.Parameters.AddWithValue("status", status);
        }

        var elections = new List<ElectionSummaryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            elections.Add(ReadElectionSummary(reader));
        }

        return elections;
    }

    private static async Task<ElectionSummaryDto?> ReadElectionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string electionId,
        bool forUpdate = false)
    {
        await using var command = new NpgsqlCommand($"""
            SELECT e.election_id, e.country_id, c.name AS country_name, c.code AS country_code,
                   e.office_id, e.office_name, e.title, e.description, e.status,
                   e.voting_starts_at, e.voting_ends_at, e.term_starts_at, e.term_ends_at,
                   (
                       SELECT COUNT(*)::bigint
                       FROM world.candidacies ca
                       WHERE ca.election_id = e.election_id
                         AND ca.status = 'active'
                   ) AS candidate_count,
                   (
                       SELECT COUNT(*)::bigint
                       FROM world.votes v
                       WHERE v.election_id = e.election_id
                   ) AS vote_count,
                   e.updated_at
            FROM world.elections e
            INNER JOIN world.countries c ON c.country_id = e.country_id
            WHERE e.election_id = @election_id
            {(forUpdate ? "FOR UPDATE OF e" : string.Empty)};
            """, connection, transaction);
        command.Parameters.AddWithValue("election_id", electionId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadElectionSummary(reader) : null;
    }

    private static string ElectionSelectSql()
    {
        return """
            SELECT e.election_id, e.country_id, c.name AS country_name, c.code AS country_code,
                   e.office_id, e.office_name, e.title, e.description, e.status,
                   e.voting_starts_at, e.voting_ends_at, e.term_starts_at, e.term_ends_at,
                   COUNT(DISTINCT ca.candidacy_id)::bigint AS candidate_count,
                   COUNT(DISTINCT v.vote_id)::bigint AS vote_count,
                   e.updated_at
            FROM world.elections e
            INNER JOIN world.countries c ON c.country_id = e.country_id
            LEFT JOIN world.candidacies ca ON ca.election_id = e.election_id AND ca.status = 'active'
            LEFT JOIN world.votes v ON v.election_id = e.election_id
            """;
    }

    private static ElectionSummaryDto ReadElectionSummary(NpgsqlDataReader reader)
    {
        return new ElectionSummaryDto(
            ElectionId: reader.GetString(0),
            CountryId: reader.GetString(1),
            CountryName: reader.GetString(2),
            CountryCode: reader.GetString(3),
            OfficeId: reader.GetString(4),
            OfficeName: reader.GetString(5),
            Title: reader.GetString(6),
            Description: reader.GetString(7),
            Status: reader.GetString(8),
            VotingStartsAt: reader.GetFieldValue<DateTimeOffset>(9),
            VotingEndsAt: reader.GetFieldValue<DateTimeOffset>(10),
            TermStartsAt: reader.GetFieldValue<DateTimeOffset>(11),
            TermEndsAt: reader.GetFieldValue<DateTimeOffset>(12),
            CandidateCount: Convert.ToInt32(reader.GetInt64(13)),
            VoteCount: Convert.ToInt32(reader.GetInt64(14)),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(15));
    }

    private static async Task<List<CandidacyDto>> ReadCandidaciesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string electionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT ca.candidacy_id, ca.election_id, ca.player_id,
                   ca.party_id, p.name AS party_name, p.short_name AS party_short_name,
                   ca.manifesto, ca.status,
                   COUNT(v.vote_id)::bigint AS vote_count,
                   ca.declared_at, ca.updated_at
            FROM world.candidacies ca
            LEFT JOIN world.political_parties p ON p.party_id = ca.party_id
            LEFT JOIN world.votes v ON v.candidacy_id = ca.candidacy_id
            WHERE ca.election_id = @election_id
            GROUP BY ca.candidacy_id, ca.election_id, ca.player_id,
                     ca.party_id, p.name, p.short_name, ca.manifesto,
                     ca.status, ca.declared_at, ca.updated_at
            ORDER BY vote_count DESC, ca.declared_at ASC;
            """, connection, transaction);
        command.Parameters.AddWithValue("election_id", electionId);

        var candidacies = new List<CandidacyDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            candidacies.Add(ReadCandidacy(reader));
        }

        return candidacies;
    }

    private static async Task<CandidacyDto?> ReadCandidacyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string candidacyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT ca.candidacy_id, ca.election_id, ca.player_id,
                   ca.party_id, p.name AS party_name, p.short_name AS party_short_name,
                   ca.manifesto, ca.status,
                   COUNT(v.vote_id)::bigint AS vote_count,
                   ca.declared_at, ca.updated_at
            FROM world.candidacies ca
            LEFT JOIN world.political_parties p ON p.party_id = ca.party_id
            LEFT JOIN world.votes v ON v.candidacy_id = ca.candidacy_id
            WHERE ca.candidacy_id = @candidacy_id
            GROUP BY ca.candidacy_id, ca.election_id, ca.player_id,
                     ca.party_id, p.name, p.short_name, ca.manifesto,
                     ca.status, ca.declared_at, ca.updated_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("candidacy_id", candidacyId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCandidacy(reader) : null;
    }

    private static async Task<CandidacyDto?> ReadPlayerCandidacyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string electionId,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT candidacy_id
            FROM world.candidacies
            WHERE election_id = @election_id
              AND player_id = @player_id
              AND status = 'active'
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("election_id", electionId);
        command.Parameters.AddWithValue("player_id", playerId);
        var candidacyId = await command.ExecuteScalarAsync() as string;
        return candidacyId is null
            ? null
            : await ReadCandidacyAsync(connection, transaction, candidacyId);
    }

    private static async Task<List<CandidacyDto>> ReadPlayerCandidaciesAsync(
        NpgsqlConnection connection,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT ca.candidacy_id, ca.election_id, ca.player_id,
                   ca.party_id, p.name AS party_name, p.short_name AS party_short_name,
                   ca.manifesto, ca.status,
                   COUNT(v.vote_id)::bigint AS vote_count,
                   ca.declared_at, ca.updated_at
            FROM world.candidacies ca
            LEFT JOIN world.political_parties p ON p.party_id = ca.party_id
            LEFT JOIN world.votes v ON v.candidacy_id = ca.candidacy_id
            WHERE ca.player_id = @player_id
              AND ca.status = 'active'
            GROUP BY ca.candidacy_id, ca.election_id, ca.player_id,
                     ca.party_id, p.name, p.short_name, ca.manifesto,
                     ca.status, ca.declared_at, ca.updated_at
            ORDER BY ca.updated_at DESC;
            """, connection);
        command.Parameters.AddWithValue("player_id", playerId);

        var candidacies = new List<CandidacyDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            candidacies.Add(ReadCandidacy(reader));
        }

        return candidacies;
    }

    private static CandidacyDto ReadCandidacy(NpgsqlDataReader reader)
    {
        return new CandidacyDto(
            CandidacyId: reader.GetString(0),
            ElectionId: reader.GetString(1),
            PlayerId: reader.GetString(2),
            PartyId: reader.IsDBNull(3) ? null : reader.GetString(3),
            PartyName: reader.IsDBNull(4) ? null : reader.GetString(4),
            PartyShortName: reader.IsDBNull(5) ? null : reader.GetString(5),
            Manifesto: reader.GetString(6),
            Status: reader.GetString(7),
            VoteCount: Convert.ToInt32(reader.GetInt64(8)),
            DeclaredAt: reader.GetFieldValue<DateTimeOffset>(9),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(10));
    }

    private static async Task<List<ElectionResultRowDto>> ReadElectionResultRowsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string electionId)
    {
        await using var command = new NpgsqlCommand("""
            WITH counted AS (
                SELECT ca.candidacy_id, ca.election_id, ca.player_id,
                       ca.party_id, p.name AS party_name, p.short_name AS party_short_name,
                       COUNT(v.vote_id)::integer AS votes,
                       ca.declared_at
                FROM world.candidacies ca
                LEFT JOIN world.political_parties p ON p.party_id = ca.party_id
                LEFT JOIN world.votes v ON v.candidacy_id = ca.candidacy_id
                WHERE ca.election_id = @election_id
                  AND ca.status = 'active'
                GROUP BY ca.candidacy_id, ca.election_id, ca.player_id,
                         ca.party_id, p.name, p.short_name, ca.declared_at
            ),
            ranked AS (
                SELECT counted.*,
                       RANK() OVER (ORDER BY votes DESC, declared_at ASC) AS result_rank
                FROM counted
            )
            SELECT ranked.candidacy_id, ranked.election_id, ranked.player_id,
                   ranked.party_id, ranked.party_name, ranked.party_short_name,
                   ranked.votes, ranked.result_rank::integer,
                   (e.status = 'resolved' AND ranked.result_rank = 1 AND ranked.votes > 0) AS is_winner
            FROM ranked
            INNER JOIN world.elections e ON e.election_id = ranked.election_id
            ORDER BY ranked.result_rank ASC, ranked.declared_at ASC;
            """, connection, transaction);
        command.Parameters.AddWithValue("election_id", electionId);

        var rows = new List<ElectionResultRowDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            rows.Add(new ElectionResultRowDto(
                CandidacyId: reader.GetString(0),
                ElectionId: reader.GetString(1),
                PlayerId: reader.GetString(2),
                PartyId: reader.IsDBNull(3) ? null : reader.GetString(3),
                PartyName: reader.IsDBNull(4) ? null : reader.GetString(4),
                PartyShortName: reader.IsDBNull(5) ? null : reader.GetString(5),
                Votes: reader.GetInt32(6),
                Rank: reader.GetInt32(7),
                IsWinner: reader.GetBoolean(8)));
        }

        return rows;
    }

    private static async Task<ElectionWinner?> ReadElectionWinnerAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string electionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT ca.player_id, ca.party_id, COUNT(v.vote_id)::integer AS votes
            FROM world.candidacies ca
            LEFT JOIN world.votes v ON v.candidacy_id = ca.candidacy_id
            WHERE ca.election_id = @election_id
              AND ca.status = 'active'
            GROUP BY ca.candidacy_id, ca.player_id, ca.party_id, ca.declared_at
            ORDER BY votes DESC, ca.declared_at ASC
            LIMIT 1;
            """, connection, transaction);
        command.Parameters.AddWithValue("election_id", electionId);
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        return new ElectionWinner(
            PlayerId: reader.GetString(0),
            PartyId: reader.IsDBNull(1) ? null : reader.GetString(1),
            Votes: reader.GetInt32(2));
    }

    private static async Task<VoteSummaryDto?> ReadVoteAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string electionId,
        string voterPlayerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT v.vote_id, v.election_id, v.voter_player_id, v.candidacy_id,
                   v.candidate_player_id, v.country_id, v.cast_at
            FROM world.votes v
            WHERE v.election_id = @election_id
              AND v.voter_player_id = @voter_player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("election_id", electionId);
        command.Parameters.AddWithValue("voter_player_id", voterPlayerId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadVoteSummary(reader) : null;
    }

    private static async Task<List<VoteSummaryDto>> ReadPlayerVotesAsync(
        NpgsqlConnection connection,
        string voterPlayerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT v.vote_id, v.election_id, v.voter_player_id, v.candidacy_id,
                   v.candidate_player_id, v.country_id, v.cast_at
            FROM world.votes v
            WHERE v.voter_player_id = @voter_player_id
            ORDER BY v.cast_at DESC;
            """, connection);
        command.Parameters.AddWithValue("voter_player_id", voterPlayerId);

        var votes = new List<VoteSummaryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            votes.Add(ReadVoteSummary(reader));
        }

        return votes;
    }

    private static VoteSummaryDto ReadVoteSummary(NpgsqlDataReader reader)
    {
        return new VoteSummaryDto(
            VoteId: reader.GetString(0),
            ElectionId: reader.GetString(1),
            VoterPlayerId: reader.GetString(2),
            CandidacyId: reader.GetString(3),
            CandidatePlayerId: reader.GetString(4),
            CountryId: reader.GetString(5),
            CastAt: reader.GetFieldValue<DateTimeOffset>(6));
    }

    private static async Task<List<OfficeTermDto>> ReadOfficeTermsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string? countryId,
        string? officeId)
    {
        var conditions = new List<string> { "ot.status = 'active'" };
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            conditions.Add("ot.country_id = @country_id");
        }
        if (!string.IsNullOrWhiteSpace(officeId))
        {
            conditions.Add("ot.office_id = @office_id");
        }

        await using var command = new NpgsqlCommand($"""
            SELECT ot.term_id, ot.country_id, c.name AS country_name, c.code AS country_code,
                   ot.office_id, ot.office_name, ot.player_id, ot.party_id,
                   p.name AS party_name, ot.source_election_id, ot.status,
                   ot.started_at, ot.ends_at, ot.updated_at
            FROM world.office_terms ot
            INNER JOIN world.countries c ON c.country_id = ot.country_id
            LEFT JOIN world.political_parties p ON p.party_id = ot.party_id
            WHERE {string.Join(" AND ", conditions)}
            ORDER BY c.name, ot.office_name;
            """, connection, transaction);
        if (!string.IsNullOrWhiteSpace(countryId))
        {
            command.Parameters.AddWithValue("country_id", countryId);
        }
        if (!string.IsNullOrWhiteSpace(officeId))
        {
            command.Parameters.AddWithValue("office_id", officeId);
        }

        var terms = new List<OfficeTermDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            terms.Add(new OfficeTermDto(
                TermId: reader.GetString(0),
                CountryId: reader.GetString(1),
                CountryName: reader.GetString(2),
                CountryCode: reader.GetString(3),
                OfficeId: reader.GetString(4),
                OfficeName: reader.GetString(5),
                PlayerId: reader.GetString(6),
                PartyId: reader.IsDBNull(7) ? null : reader.GetString(7),
                PartyName: reader.IsDBNull(8) ? null : reader.GetString(8),
                SourceElectionId: reader.IsDBNull(9) ? null : reader.GetString(9),
                Status: reader.GetString(10),
                StartedAt: reader.GetFieldValue<DateTimeOffset>(11),
                EndsAt: reader.GetFieldValue<DateTimeOffset>(12),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(13)));
        }

        return terms;
    }

    private static bool CanDeclareCandidacy(ElectionSummaryDto election)
    {
        var now = DateTimeOffset.UtcNow;
        return election.VotingEndsAt > now &&
            (string.Equals(election.Status, "scheduled", StringComparison.OrdinalIgnoreCase) ||
             string.Equals(election.Status, "voting", StringComparison.OrdinalIgnoreCase));
    }

    private static bool CanVoteInElection(ElectionSummaryDto election)
    {
        var now = DateTimeOffset.UtcNow;
        return string.Equals(election.Status, "voting", StringComparison.OrdinalIgnoreCase) &&
            election.VotingStartsAt <= now &&
            election.VotingEndsAt > now;
    }

    private static string? NormalizeElectionStatusFilter(string? status)
    {
        if (string.IsNullOrWhiteSpace(status) ||
            string.Equals(status, "all", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var normalized = status.Trim().ToLowerInvariant();
        return normalized switch
        {
            "open" => "current",
            "active" => "voting",
            _ => normalized
        };
    }

    private static string CleanOptionalText(string? value, string fallback)
    {
        return string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
    }

    private static string MembershipId(string partyId, string playerId)
    {
        return $"membership-{partyId}-{playerId}";
    }

    private static string Slugify(string value)
    {
        var lower = value.Trim().ToLowerInvariant();
        var slug = Regex.Replace(lower, "[^a-z0-9]+", "-").Trim('-');
        return string.IsNullOrWhiteSpace(slug) ? "party" : slug[..Math.Min(slug.Length, 48)];
    }
}

internal static class PoliticsCatalog
{
    public static PoliticalPartyTemplate[] Parties { get; } =
    [
        new PoliticalPartyTemplate(
            "party-freiland-civic-union",
            "freiland",
            "Civic Union",
            "CU",
            "A broad civic party focused on balanced growth, citizenship rights, and resilient public institutions.",
            "Civic republicanism"),
        new PoliticalPartyTemplate(
            "party-freiland-agrarian-labor",
            "freiland",
            "Agrarian Labor",
            "AL",
            "A worker and farmer coalition backing food security, fair wages, and regional development.",
            "Labor agrarianism"),
        new PoliticalPartyTemplate(
            "party-nordheim-industrial-front",
            "nordheim",
            "Industrial Front",
            "IF",
            "A production-first movement prioritizing mines, factories, and strong national defenses.",
            "Industrial nationalism"),
        new PoliticalPartyTemplate(
            "party-nordheim-northern-cooperative",
            "nordheim",
            "Northern Cooperative",
            "NC",
            "A cooperative party emphasizing shared ownership, sustainable timber, and citizen welfare.",
            "Cooperative social democracy"),
        new PoliticalPartyTemplate(
            "party-solara-trade-league",
            "solara",
            "Trade League",
            "TL",
            "A merchant bloc committed to low taxes, open markets, and international trade routes.",
            "Market liberalism"),
        new PoliticalPartyTemplate(
            "party-solara-river-guild",
            "solara",
            "River Guild",
            "RG",
            "A guild alliance protecting river cities, farmers, and caravan infrastructure.",
            "Guild federalism")
    ];
}

internal sealed record PoliticalPartyListResponse(PoliticalPartyDto[] Parties, DateTimeOffset UpdatedAt);

internal sealed record PlayerPoliticsStatusResponse(
    string PlayerId,
    PlayerCitizenshipDto? Citizenship,
    PoliticalPartyMembershipDto? Membership,
    CandidacyDto[] Candidacies,
    VoteSummaryDto[] Votes,
    DateTimeOffset UpdatedAt);

internal sealed record PoliticalPartyMutationResult(
    bool Completed,
    string Message,
    PoliticalPartyDto? Party,
    PoliticalPartyMembershipDto? Membership,
    DateTimeOffset UpdatedAt);

internal sealed record ElectionListResponse(ElectionSummaryDto[] Elections, DateTimeOffset UpdatedAt);

internal sealed record ElectionDetailsResponse(
    ElectionSummaryDto Election,
    CandidacyDto[] Candidacies,
    ElectionResultRowDto[] Results,
    DateTimeOffset UpdatedAt);

internal sealed record ElectionResultsResponse(
    ElectionSummaryDto Election,
    ElectionResultRowDto[] Results,
    OfficeTermDto[] OfficeHolders,
    DateTimeOffset UpdatedAt);

internal sealed record CandidacyMutationResult(
    bool Completed,
    string Message,
    CandidacyDto? Candidacy,
    ElectionSummaryDto? Election,
    DateTimeOffset UpdatedAt);

internal sealed record VoteMutationResult(
    bool Completed,
    string Message,
    VoteSummaryDto? Vote,
    ElectionResultRowDto[] Results,
    DateTimeOffset UpdatedAt);

internal sealed record OfficeHolderListResponse(OfficeTermDto[] OfficeHolders, DateTimeOffset UpdatedAt);

internal sealed record PoliticalPartyDto(
    string PartyId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Name,
    string ShortName,
    string Description,
    string Ideology,
    string FounderPlayerId,
    string Status,
    int MemberCount,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record PoliticalPartyMembershipDto(
    string MembershipId,
    string PartyId,
    string PartyName,
    string CountryId,
    string CountryName,
    string CountryCode,
    string PlayerId,
    string Role,
    string Status,
    DateTimeOffset JoinedAt,
    DateTimeOffset? LeftAt,
    DateTimeOffset UpdatedAt);

internal sealed record ElectionSummaryDto(
    string ElectionId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string OfficeId,
    string OfficeName,
    string Title,
    string Description,
    string Status,
    DateTimeOffset VotingStartsAt,
    DateTimeOffset VotingEndsAt,
    DateTimeOffset TermStartsAt,
    DateTimeOffset TermEndsAt,
    int CandidateCount,
    int VoteCount,
    DateTimeOffset UpdatedAt);

internal sealed record CandidacyDto(
    string CandidacyId,
    string ElectionId,
    string PlayerId,
    string? PartyId,
    string? PartyName,
    string? PartyShortName,
    string Manifesto,
    string Status,
    int VoteCount,
    DateTimeOffset DeclaredAt,
    DateTimeOffset UpdatedAt);

internal sealed record ElectionResultRowDto(
    string CandidacyId,
    string ElectionId,
    string PlayerId,
    string? PartyId,
    string? PartyName,
    string? PartyShortName,
    int Votes,
    int Rank,
    bool IsWinner);

internal sealed record VoteSummaryDto(
    string VoteId,
    string ElectionId,
    string VoterPlayerId,
    string CandidacyId,
    string CandidatePlayerId,
    string CountryId,
    DateTimeOffset CastAt);

internal sealed record OfficeTermDto(
    string TermId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string OfficeId,
    string OfficeName,
    string PlayerId,
    string? PartyId,
    string? PartyName,
    string? SourceElectionId,
    string Status,
    DateTimeOffset StartedAt,
    DateTimeOffset EndsAt,
    DateTimeOffset UpdatedAt);

internal sealed record PoliticalPartyCreateRequest(
    string? CountryId,
    string? Name,
    string? ShortName,
    string? Description,
    string? Ideology);

internal sealed record CandidacyDeclarationRequest(string? PartyId, string? Manifesto);

internal sealed record VoteRequest(string? CandidacyId);

internal sealed record PoliticalPartyTemplate(
    string PartyId,
    string CountryId,
    string Name,
    string ShortName,
    string Description,
    string Ideology);

internal sealed record ElectionSeed(
    string ElectionId,
    string CountryId,
    string OfficeId,
    string OfficeName,
    string Title,
    string Description,
    string Status,
    DateTimeOffset VotingStartsAt,
    DateTimeOffset VotingEndsAt,
    DateTimeOffset TermStartsAt,
    DateTimeOffset TermEndsAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

internal sealed record ElectionWinner(string PlayerId, string? PartyId, int Votes);

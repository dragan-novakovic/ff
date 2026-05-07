using System.Text.Json;

internal static class PoliticsGatewayEndpoints
{
    public static void MapPoliticsGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/politics/parties", async (
            HttpRequest request,
            WorldServiceClient world) =>
            await world.GetAsync(PoliticsQuery("politics/parties", request, "countryId"), string.Empty))
            .WithName("GetGatewayPoliticalParties");

        app.MapGet("/players/{playerId}/politics/status", async (
            string playerId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/status",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayPlayerPoliticsStatus");

        app.MapPost("/players/{playerId}/politics/parties", async (
            string playerId,
            PoliticalPartyGatewayRequest party,
            HttpRequest request,
            WorldServiceClient world,
            PlayerServiceClient players,
            IConfiguration configuration,
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

            var authorization = request.Headers.Authorization.ToString();
            var result = await world.PostJsonAsync<PoliticalPartyGatewayRequest, JsonElement>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/parties",
                authorization,
                party);
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value;
            if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
            {
                var onboarding = await OnboardingGatewayTracker.TrackAsync(
                    players,
                    access.PlayerId!,
                    authorization,
                    configuration,
                    "party_action",
                    $"onboarding:party-action:{access.PlayerId!.ToLowerInvariant()}");
                if (onboarding.Error is not null)
                {
                    return onboarding.Error;
                }
            }

            return Results.Json(mutation);
        }).WithName("CreateGatewayPoliticalParty");

        app.MapPost("/players/{playerId}/politics/parties/{partyId}/join", async (
            string playerId,
            string partyId,
            HttpRequest request,
            WorldServiceClient world,
            PlayerServiceClient players,
            IConfiguration configuration,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var authorization = request.Headers.Authorization.ToString();
            var result = await world.PostJsonAsync<object, JsonElement>(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/parties/{Uri.EscapeDataString(partyId)}/join",
                authorization,
                new { });
            if (result.Error is not null)
            {
                return result.Error;
            }

            var mutation = result.Value;
            if (OnboardingGatewayTracker.IsCompletedMutation(mutation))
            {
                var onboarding = await OnboardingGatewayTracker.TrackAsync(
                    players,
                    access.PlayerId!,
                    authorization,
                    configuration,
                    "party_action",
                    $"onboarding:party-action:{access.PlayerId!.ToLowerInvariant()}");
                if (onboarding.Error is not null)
                {
                    return onboarding.Error;
                }
            }

            return Results.Json(mutation);
        }).WithName("JoinGatewayPoliticalParty");

        app.MapPost("/players/{playerId}/politics/parties/{partyId}/leave", async (
            string playerId,
            string partyId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/parties/{Uri.EscapeDataString(partyId)}/leave",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("LeaveGatewayPoliticalParty");

        app.MapGet("/politics/elections", async (
            HttpRequest request,
            WorldServiceClient world) =>
            await world.GetAsync(PoliticsQuery("politics/elections", request, "countryId", "status"), string.Empty))
            .WithName("GetGatewayElections");

        app.MapGet("/politics/elections/{electionId}", async (
            string electionId,
            WorldServiceClient world) =>
            await world.GetAsync($"politics/elections/{Uri.EscapeDataString(electionId)}", string.Empty))
            .WithName("GetGatewayElection");

        app.MapGet("/politics/elections/{electionId}/results", async (
            string electionId,
            WorldServiceClient world) =>
            await world.GetAsync($"politics/elections/{Uri.EscapeDataString(electionId)}/results", string.Empty))
            .WithName("GetGatewayElectionResults");

        app.MapPost("/players/{playerId}/politics/elections/{electionId}/candidacies", async (
            string playerId,
            string electionId,
            CandidacyGatewayRequest candidacy,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            if (candidacy.Manifesto?.Length > 800)
            {
                return Results.BadRequest(new ErrorResponse("Candidacy manifesto is too long."));
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/elections/{Uri.EscapeDataString(electionId)}/candidacies",
                request.Headers.Authorization.ToString(),
                candidacy);
        }).WithName("DeclareGatewayCandidacy");

        app.MapPost("/players/{playerId}/politics/elections/{electionId}/vote", async (
            string playerId,
            string electionId,
            VoteGatewayRequest vote,
            HttpRequest request,
            WorldServiceClient world,
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

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/elections/{Uri.EscapeDataString(electionId)}/vote",
                request.Headers.Authorization.ToString(),
                vote);
        }).WithName("VoteGatewayElection");

        app.MapGet("/politics/office-holders", async (
            HttpRequest request,
            WorldServiceClient world) =>
            await world.GetAsync(PoliticsQuery("politics/office-holders", request, "countryId"), string.Empty))
            .WithName("GetGatewayOfficeHolders");
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

    private static string? ValidatePartyCreate(PoliticalPartyGatewayRequest party)
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

        return null;
    }

    private static string PoliticsQuery(string path, HttpRequest request, params string[] queryKeys)
    {
        var query = queryKeys
            .Select(key => new KeyValuePair<string, string>(key, request.Query[key].ToString()))
            .Where(pair => !string.IsNullOrWhiteSpace(pair.Value))
            .Select(pair => $"{Uri.EscapeDataString(pair.Key)}={Uri.EscapeDataString(pair.Value)}")
            .ToArray();
        return query.Length == 0 ? path : $"{path}?{string.Join("&", query)}";
    }
}

internal sealed record PoliticalPartyGatewayRequest(
    string? CountryId,
    string? Name,
    string? ShortName,
    string? Description,
    string? Ideology);

internal sealed record CandidacyGatewayRequest(string? PartyId, string? Manifesto);

internal sealed record VoteGatewayRequest(string? CandidacyId);

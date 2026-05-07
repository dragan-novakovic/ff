internal static class LawGatewayEndpoints
{
    public static void MapLawGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/politics/law-proposals", async (
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                LawQuery("politics/law-proposals", request, "countryId", "status", "limit"),
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayLawProposals");

        app.MapGet("/politics/law-proposals/{proposalId}", async (
            string proposalId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"politics/law-proposals/{Uri.EscapeDataString(proposalId)}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayLawProposal");

        app.MapGet("/politics/law-proposals/{proposalId}/votes", async (
            string proposalId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                LawQuery($"politics/law-proposals/{Uri.EscapeDataString(proposalId)}/votes", request, "limit"),
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayLawProposalVotes");

        app.MapGet("/politics/laws", async (
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                LawQuery("politics/laws", request, "countryId", "status", "limit"),
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayLaws");

        app.MapPost("/players/{playerId}/politics/law-proposals", async (
            string playerId,
            LawProposalGatewayRequest proposal,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var validation = ValidateProposal(proposal);
            if (validation is not null)
            {
                return Results.BadRequest(new ErrorResponse(validation));
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/law-proposals",
                request.Headers.Authorization.ToString(),
                proposal);
        }).WithName("CreateGatewayLawProposal");

        app.MapPost("/players/{playerId}/politics/law-proposals/{proposalId}/vote", async (
            string playerId,
            string proposalId,
            LawVoteGatewayRequest vote,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var choice = vote.Choice?.Trim().ToLowerInvariant();
            if (choice is not ("yes" or "no" or "abstain"))
            {
                return Results.BadRequest(new ErrorResponse("Vote choice must be yes, no, or abstain."));
            }

            return await world.PostJsonForwardAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/law-proposals/{Uri.EscapeDataString(proposalId)}/vote",
                request.Headers.Authorization.ToString(),
                new LawVoteGatewayRequest(choice));
        }).WithName("VoteGatewayLawProposal");

        app.MapPost("/players/{playerId}/politics/law-proposals/{proposalId}/resolve", async (
            string playerId,
            string proposalId,
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
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/politics/law-proposals/{Uri.EscapeDataString(proposalId)}/resolve",
                request.Headers.Authorization.ToString(),
                new { });
        }).WithName("ResolveGatewayLawProposal");
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

    private static IResult? ValidateBearer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? null
            : Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized);
    }

    private static string? ValidateProposal(LawProposalGatewayRequest proposal)
    {
        if (string.IsNullOrWhiteSpace(proposal.CountryId))
        {
            return "Country is required.";
        }

        var type = proposal.ProposalType?.Trim().ToLowerInvariant().Replace('-', '_');
        if (type is not ("tax_policy" or "treasury_grant" or "treasury_spend" or "citizenship_rule" or "war_declaration"))
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

        if (type == "tax_policy" &&
            (InvalidRate(proposal.IncomeTaxRate) ||
             InvalidRate(proposal.MarketTaxRate) ||
             InvalidRate(proposal.ProductionTaxRate)))
        {
            return "Tax policy proposals require income, market, and production rates from 0-50.";
        }

        if ((type is "treasury_grant" or "treasury_spend") && proposal.TreasuryAmount is null or <= 0)
        {
            return "Treasury proposals require a positive amount.";
        }

        return null;
    }

    private static bool InvalidRate(int? rate)
    {
        return rate is null or < 0 or > 50;
    }

    private static string LawQuery(string path, HttpRequest request, params string[] queryKeys)
    {
        var query = queryKeys
            .Select(key => new KeyValuePair<string, string>(key, request.Query[key].ToString()))
            .Where(pair => !string.IsNullOrWhiteSpace(pair.Value))
            .Select(pair => $"{Uri.EscapeDataString(pair.Key)}={Uri.EscapeDataString(pair.Value)}")
            .ToArray();
        return query.Length == 0 ? path : $"{path}?{string.Join("&", query)}";
    }
}

internal sealed record LawProposalGatewayRequest(
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

internal sealed record LawVoteGatewayRequest(string? Choice);

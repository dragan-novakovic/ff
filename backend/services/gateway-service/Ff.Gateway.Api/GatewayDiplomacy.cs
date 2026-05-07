internal static class DiplomacyGatewayEndpoints
{
    public static void MapDiplomacyGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/players/{playerId}/diplomacy", async (
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
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/diplomacy",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayPlayerDiplomacy");

        app.MapGet("/world/countries/{countryId}/diplomacy", async (
            string countryId,
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
                $"countries/{Uri.EscapeDataString(countryId)}/diplomacy",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCountryDiplomacy");

        app.MapGet("/diplomacy/treaties", async (
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
                DiplomacyQuery("diplomacy/treaties", request, "countryId", "counterpartyCountryId", "status", "treatyType", "limit"),
                request.Headers.Authorization.ToString());
        }).WithName("ListGatewayDiplomacyTreaties");

        app.MapGet("/diplomacy/treaties/{treatyId}", async (
            string treatyId,
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
                $"diplomacy/treaties/{Uri.EscapeDataString(treatyId)}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayDiplomacyTreaty");

        app.MapPost("/players/{playerId}/diplomacy/proposals", async (
            string playerId,
            DiplomacyProposalGatewayRequest proposal,
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
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/diplomacy/proposals",
                request.Headers.Authorization.ToString(),
                proposal);
        }).WithName("CreateGatewayDiplomacyProposal");

        app.MapPost("/players/{playerId}/diplomacy/treaties/{treatyId}/ratify", async (
            string playerId,
            string treatyId,
            DiplomacyTreatyActionGatewayRequest action,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
            await ForwardTreatyActionAsync(playerId, treatyId, "ratify", action, request, world, tokens))
            .WithName("RatifyGatewayDiplomacyTreaty");

        app.MapPost("/players/{playerId}/diplomacy/treaties/{treatyId}/reject", async (
            string playerId,
            string treatyId,
            DiplomacyTreatyActionGatewayRequest action,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
            await ForwardTreatyActionAsync(playerId, treatyId, "reject", action, request, world, tokens))
            .WithName("RejectGatewayDiplomacyTreaty");

        app.MapPost("/players/{playerId}/diplomacy/treaties/{treatyId}/terminate", async (
            string playerId,
            string treatyId,
            DiplomacyTreatyActionGatewayRequest action,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
            await ForwardTreatyActionAsync(playerId, treatyId, "terminate", action, request, world, tokens))
            .WithName("TerminateGatewayDiplomacyTreaty");
    }

    private static async Task<IResult> ForwardTreatyActionAsync(
        string playerId,
        string treatyId,
        string actionName,
        DiplomacyTreatyActionGatewayRequest action,
        HttpRequest request,
        WorldServiceClient world,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        if (string.IsNullOrWhiteSpace(action.IdempotencyKey))
        {
            return Results.BadRequest(new ErrorResponse("Idempotency key is required."));
        }

        return await world.PostJsonForwardAsync(
            $"players/{Uri.EscapeDataString(access.PlayerId!)}/diplomacy/treaties/{Uri.EscapeDataString(treatyId)}/{actionName}",
            request.Headers.Authorization.ToString(),
            action);
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
                new ErrorResponse("You cannot manage another player's diplomacy."),
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

    private static string? ValidateProposal(DiplomacyProposalGatewayRequest proposal)
    {
        if (string.IsNullOrWhiteSpace(proposal.TargetCountryId))
        {
            return "Target country is required.";
        }

        var type = proposal.TreatyType?.Trim().ToLowerInvariant().Replace('-', '_');
        if (type is not ("alliance" or "embargo" or "peace" or "military_access" or "trade_agreement"))
        {
            return "Treaty type must be alliance, embargo, peace, military_access, or trade_agreement.";
        }

        if (string.IsNullOrWhiteSpace(proposal.Title) || proposal.Title.Trim().Length < 3)
        {
            return "Treaty title must be at least 3 characters.";
        }

        if (proposal.Title.Length > 120 || proposal.Terms?.Length > 2_000)
        {
            return "Treaty title or terms are too long.";
        }

        if (proposal.DurationDays is <= 0 or > 3_650)
        {
            return "Treaty duration must be between 1 and 3650 days.";
        }

        if (proposal.TreasuryAmount is < 0 or > 1_000_000)
        {
            return "Treasury transfer must be between 0 and 1000000 gold.";
        }

        if (type == "embargo" && proposal.TreasuryAmount is > 0)
        {
            return "Embargoes cannot include treasury transfers.";
        }

        return string.IsNullOrWhiteSpace(proposal.IdempotencyKey)
            ? "Treaty proposal idempotency key is required."
            : null;
    }

    private static string DiplomacyQuery(string path, HttpRequest request, params string[] queryKeys)
    {
        var pairs = queryKeys
            .Select(key => (key, value: request.Query[key].ToString()))
            .Where(pair => !string.IsNullOrWhiteSpace(pair.value))
            .Select(pair => $"{Uri.EscapeDataString(pair.key)}={Uri.EscapeDataString(pair.value)}")
            .ToArray();
        return pairs.Length == 0 ? path : $"{path}?{string.Join("&", pairs)}";
    }
}

internal sealed record DiplomacyProposalGatewayRequest(
    string? InitiatorCountryId,
    string? TargetCountryId,
    string? TreatyType,
    string? Title,
    string? Terms,
    int? DurationDays,
    int? TreasuryAmount,
    string? SourceLawId,
    string? IdempotencyKey);

internal sealed record DiplomacyTreatyActionGatewayRequest(string? Reason, string? IdempotencyKey);

internal sealed record DiplomacyRelationshipCheckDto(
    string CountryId,
    string CounterpartyCountryId,
    bool HasActiveEmbargo,
    bool HasActivePeace,
    bool HasActiveAlliance,
    bool HasMilitaryAccess,
    bool HasTradeAgreement,
    DateTimeOffset UpdatedAt);

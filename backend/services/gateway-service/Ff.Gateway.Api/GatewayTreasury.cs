internal static class TreasuryGatewayEndpoints
{
    public static void MapTreasuryGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/world/countries/{countryId}/treasury", async (
            string countryId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateTreasuryBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"countries/{Uri.EscapeDataString(countryId)}/treasury",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayCountryTreasury");

        app.MapPost("/world/countries/{countryId}/tax-policy", async (
            string countryId,
            CountryTaxPolicyUpdateRequestDto policyRequest,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateTreasuryBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            if (policyRequest.IncomeTaxRate is null ||
                policyRequest.MarketTaxRate is null ||
                policyRequest.ProductionTaxRate is null)
            {
                return Results.BadRequest(new ErrorResponse(
                    "Income, market, and production tax rates are required."));
            }

            return await world.PostJsonForwardAsync(
                $"countries/{Uri.EscapeDataString(countryId)}/tax-policy",
                request.Headers.Authorization.ToString(),
                policyRequest);
        }).WithName("UpdateGatewayCountryTaxPolicy");
    }

    public static int CalculateTaxAmount(int grossAmount, int taxRate)
    {
        if (grossAmount <= 0 || taxRate <= 0)
        {
            return 0;
        }

        var clampedRate = Math.Clamp(taxRate, 0, 50);
        return checked((grossAmount * clampedRate + 99) / 100);
    }

    public static async Task<ServiceJsonResult<PlayerTaxContext?>> GetPlayerTaxContextAsync(
        WorldServiceClient world,
        IConfiguration configuration,
        string playerId,
        string authorization)
    {
        if (string.Equals(playerId, "system-market", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceJsonResult<PlayerTaxContext?>.Succeeded(null);
        }

        var escapedPlayerId = Uri.EscapeDataString(playerId);
        var citizenship = await world.GetJsonAsync<PlayerCitizenshipResponseDto>(
            $"internal/players/{escapedPlayerId}/citizenship",
            authorization,
            InternalTreasuryToken(configuration));
        if (citizenship.Error is not null)
        {
            return ServiceJsonResult<PlayerTaxContext?>.Failed(citizenship.Error);
        }

        var playerCitizenship = citizenship.Value!.Citizenship;
        if (playerCitizenship is null ||
            !string.Equals(playerCitizenship.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceJsonResult<PlayerTaxContext?>.Succeeded(null);
        }

        var treasury = await world.GetJsonAsync<CountryTreasuryResponseDto>(
            $"countries/{Uri.EscapeDataString(playerCitizenship.CountryId)}/treasury",
            authorization);
        if (treasury.Error is not null)
        {
            return ServiceJsonResult<PlayerTaxContext?>.Failed(treasury.Error);
        }

        return ServiceJsonResult<PlayerTaxContext?>.Succeeded(
            new PlayerTaxContext(playerCitizenship, treasury.Value!));
    }

    public static async Task<ServiceJsonResult<CountryTaxCollectionResponseDto?>> CollectCountryTaxAsync(
        WorldServiceClient world,
        IConfiguration configuration,
        string authorization,
        string countryId,
        int amount,
        int grossAmount,
        int taxRate,
        string entryType,
        string sourcePlayerId,
        string? counterpartyPlayerId,
        string description,
        string idempotencyKey)
    {
        if (amount <= 0)
        {
            return ServiceJsonResult<CountryTaxCollectionResponseDto?>.Succeeded(null);
        }

        var collection = await world.PostJsonAsync<CountryTaxCollectionRequestDto, CountryTaxCollectionResponseDto>(
            $"countries/{Uri.EscapeDataString(countryId)}/treasury/tax-collections",
            authorization,
            new CountryTaxCollectionRequestDto(
                Amount: amount,
                GrossAmount: Math.Max(0, grossAmount),
                TaxRate: Math.Clamp(taxRate, 0, 50),
                EntryType: entryType,
                SourcePlayerId: sourcePlayerId,
                CounterpartyPlayerId: counterpartyPlayerId,
                Description: description,
                IdempotencyKey: idempotencyKey),
            InternalTreasuryToken(configuration));
        if (collection.Error is not null)
        {
            return ServiceJsonResult<CountryTaxCollectionResponseDto?>.Failed(collection.Error);
        }

        return ServiceJsonResult<CountryTaxCollectionResponseDto?>.Succeeded(collection.Value);
    }

    private static IResult? ValidateTreasuryBearer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? null
            : Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized);
    }

    private static string InternalTreasuryToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }
}

internal sealed record PlayerTaxContext(
    PlayerCitizenshipDto Citizenship,
    CountryTreasuryResponseDto Treasury);

internal sealed record CountryTreasuryResponseDto(
    string CountryId,
    string Name,
    string Code,
    int Treasury,
    CountryTaxPolicyDto Policy,
    CountryTreasuryLedgerEntryDto[] RecentLedger,
    CountryTaxPolicyAuthorizationDto Authorization,
    DateTimeOffset UpdatedAt);

internal sealed record CountryTaxPolicyDto(
    string CountryId,
    int IncomeTaxRate,
    int MarketTaxRate,
    int ProductionTaxRate,
    string UpdatedByPlayerId,
    DateTimeOffset UpdatedAt);

internal sealed record CountryTaxPolicyAuthorizationDto(
    bool CanUpdatePolicy,
    string? Role,
    string Message);

internal sealed record CountryTreasuryLedgerEntryDto(
    string LedgerId,
    string CountryId,
    string EntryType,
    string SourcePlayerId,
    string CounterpartyPlayerId,
    int GoldDelta,
    int GrossAmount,
    int TaxRate,
    string Description,
    DateTimeOffset CreatedAt);

internal sealed record CountryTaxPolicyUpdateRequestDto(
    int? IncomeTaxRate,
    int? MarketTaxRate,
    int? ProductionTaxRate);

internal sealed record CountryTaxCollectionRequestDto(
    int Amount,
    int GrossAmount,
    int TaxRate,
    string EntryType,
    string SourcePlayerId,
    string? CounterpartyPlayerId,
    string Description,
    string IdempotencyKey);

internal sealed record CountryTaxCollectionResponseDto(
    bool Completed,
    string Message,
    string CountryId,
    int Amount,
    int Treasury,
    CountryTreasuryLedgerEntryDto? Entry,
    DateTimeOffset UpdatedAt);

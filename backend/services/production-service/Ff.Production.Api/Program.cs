var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "production-service",
    DisplayName: "Production Service",
    Domain: "Factories, companies, production jobs, and formulas",
    Description: "Owns factory/company production workflows and coordinates resource consumption and output grants through economy boundaries.",
    Owns: ["factories", "company ownership", "production jobs", "upgrades", "production formulas"],
    Responsibilities: ["Start and track production jobs", "Coordinate input reservations", "Emit production completion events later"]);

var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.MapGet("/players/{playerId}/factories", (string playerId) =>
{
    var normalizedPlayerId = NormalizePlayerId(playerId);
    return Results.Ok(new FactoryPortfolioResponse(
        PlayerId: normalizedPlayerId,
        Factories:
        [
            new FactoryDto("food-factory", "Food Factory", "Food", 1, "grain", 5, "food", 3, true),
            new FactoryDto("weapon-workshop", "Weapon Workshop", "Weapon", 1, "iron", 4, "weapon_q1", 1, true)
        ],
        UpdatedAt: DateTimeOffset.UtcNow));
}).WithName("GetFactories");

app.MapPost("/players/{playerId}/factories/{factoryId}/produce", (string playerId, string factoryId) =>
{
    var normalizedFactoryId = NormalizeId(factoryId);
    var factory = Catalog().FirstOrDefault(item => item.FactoryId == normalizedFactoryId);
    if (factory is null)
    {
        return Results.NotFound(new ErrorResponse("Factory was not found."));
    }

    var result = new ProductionResult(
        Completed: true,
        FactoryId: factory.FactoryId,
        Message: $"{factory.Name} completed an MVP production run.",
        ConsumedItemId: factory.InputItemId,
        ConsumedQuantity: factory.InputQuantity,
        ProducedItemId: factory.OutputItemId,
        ProducedQuantity: factory.OutputQuantity,
        Note: "Inventory mutation is not enabled yet; this production run is a backend-backed preview.",
        CompletedAt: DateTimeOffset.UtcNow);

    return Results.Ok(result);
}).WithName("Produce");

app.Run();

static FactoryDto[] Catalog()
{
    return
    [
        new FactoryDto("food-factory", "Food Factory", "Food", 1, "grain", 5, "food", 3, true),
        new FactoryDto("weapon-workshop", "Weapon Workshop", "Weapon", 1, "iron", 4, "weapon_q1", 1, true)
    ];
}

static string NormalizePlayerId(string playerId)
{
    return playerId.Trim().ToLowerInvariant();
}

static string NormalizeId(string value)
{
    return value.Trim().ToLowerInvariant();
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record FactoryPortfolioResponse(
    string PlayerId,
    FactoryDto[] Factories,
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
    bool CanProduce);

internal sealed record ProductionResult(
    bool Completed,
    string FactoryId,
    string Message,
    string ConsumedItemId,
    int ConsumedQuantity,
    string ProducedItemId,
    int ProducedQuantity,
    string Note,
    DateTimeOffset CompletedAt);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

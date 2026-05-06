var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "market-service",
    DisplayName: "Market Service",
    Domain: "Trading, listings, order book, and market fees",
    Description: "Owns market listings and trade history for fixed-price MVP trading while reserving funds/items through economy boundaries.",
    Owns: ["sell orders", "buy orders", "order book", "trade history", "market fees"],
    Responsibilities: ["Create and read market listings", "Coordinate buyer/seller reservations", "Record fills and fees"]);

var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new HealthResponse(metadata.Service, "ok", DateTimeOffset.UtcNow)))
    .WithName("GetHealth");

app.MapGet("/metadata", () => Results.Ok(metadata))
    .WithName("GetMetadata");

app.Run();

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

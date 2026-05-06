var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "world-service",
    DisplayName: "World Service",
    Domain: "Countries, regions, laws, modifiers, and global time",
    Description: "Owns persistent world state and applies authoritative world changes such as region ownership and global configuration.",
    Owns: ["countries", "regions", "region ownership", "laws and modifiers", "global day/time", "world configuration"],
    Responsibilities: ["Serve world configuration", "Apply region ownership changes", "Expose country/region state"]);

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

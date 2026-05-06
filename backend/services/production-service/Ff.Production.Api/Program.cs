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

app.Run();

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

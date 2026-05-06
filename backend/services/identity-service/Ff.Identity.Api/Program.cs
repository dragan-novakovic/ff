var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "identity-service",
    DisplayName: "Identity Service",
    Domain: "Authentication account linkage and account state",
    Description: "Owns account identity metadata and maps auth subjects to internal player IDs without owning game progression state.",
    Owns: ["identity subjects", "player ID mappings", "account state", "ban and suspension state", "login metadata"],
    Responsibilities: ["Link authentication subjects to players", "Track account status", "Expose identity metadata to trusted services"]);

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

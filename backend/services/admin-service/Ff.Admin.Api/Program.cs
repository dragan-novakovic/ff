var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "admin-service",
    DisplayName: "Admin / Moderation Service",
    Domain: "Operations tooling, moderation, audit views, and support workflows",
    Description: "Owns administrative API surfaces for trusted operations such as user lookup, bans, compensation, and audit views.",
    Owns: ["admin API surface", "moderation operations", "audit views", "support workflows"],
    Responsibilities: ["Expose protected operational metadata later", "Coordinate bans and compensation", "Provide economy and player inspection views"]);

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

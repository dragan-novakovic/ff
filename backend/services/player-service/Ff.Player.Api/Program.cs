var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "player-service",
    DisplayName: "Player Service",
    Domain: "Player profile, progression, and energy state",
    Description: "Owns player profile and progression state such as level, XP, energy, strength, and daily counters.",
    Owns: ["player profiles", "levels and XP", "energy", "strength", "daily status", "tutorial state"],
    Responsibilities: ["Serve player profile reads", "Apply progression changes atomically", "Own daily player reset state"]);

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

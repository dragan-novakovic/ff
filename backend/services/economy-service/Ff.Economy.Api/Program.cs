var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "economy-service",
    DisplayName: "Economy Service",
    Domain: "Wallet ledger, inventory balances, and reservations",
    Description: "Keeps wallet and inventory together for MVP so money and item reservations can remain atomic.",
    Owns: ["currency balances", "transaction ledger", "inventory balances", "reserved funds", "reserved items"],
    Responsibilities: ["Protect against negative balances", "Reserve and commit money/items", "Maintain append-only economic audit trails"]);

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

var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "social-chat-service",
    DisplayName: "Social Chat Service",
    Domain: "Contacts, conversations, channels, and unread counts",
    Description: "Combines social graph and chat ownership for the MVP split, including DMs, groups, global channels, and moderation metadata.",
    Owns: ["contacts", "direct conversations", "group channels", "global channels", "unread counts", "moderation metadata"],
    Responsibilities: ["Serve contact and conversation metadata", "Accept chat messages later", "Support realtime fan-out later"]);

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

var builder = WebApplication.CreateBuilder(args);

var metadata = new ServiceMetadata(
    Service: "gateway-service",
    DisplayName: "API Gateway / BFF",
    Domain: "Client-facing API gateway and backend-for-frontend",
    Description: "Public REST entrypoint for Flutter clients that will verify auth, route requests, and shape mobile-friendly responses.",
    Owns: ["request routing", "API versioning", "client response shaping"],
    Responsibilities: ["Verify OIDC/JWT bearer tokens", "Map external identities to internal player IDs", "Route requests to backend services", "Apply client-facing rate limits"]);

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

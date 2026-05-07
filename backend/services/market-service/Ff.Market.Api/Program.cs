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

app.MapGet("/market/listings", () => Results.Ok(new MarketListingsResponse(
    Listings: Catalog(),
    UpdatedAt: DateTimeOffset.UtcNow))).WithName("GetMarketListings");

app.MapGet("/market/listings/{listingId}", (string listingId) =>
{
    var listing = Catalog().FirstOrDefault(item =>
        string.Equals(item.ListingId, listingId, StringComparison.OrdinalIgnoreCase));
    return listing is null
        ? Results.NotFound(new ErrorResponse("Market listing was not found."))
        : Results.Ok(listing);
}).WithName("GetMarketListing");

app.Run();

static MarketListingDto[] Catalog()
{
    return
    [
        new MarketListingDto("listing-food-1", "food", "Food", "Consumable", 12, 2, "system-market"),
        new MarketListingDto("listing-weapon-q1-1", "weapon_q1", "Q1 Weapon", "Weapon", 4, 18, "system-market"),
        new MarketListingDto("listing-grain-1", "grain", "Grain", "Raw material", 50, 1, "system-market")
    ];
}

internal sealed record HealthResponse(string Service, string Status, DateTimeOffset CheckedAt);

internal sealed record ErrorResponse(string Message);

internal sealed record MarketListingsResponse(MarketListingDto[] Listings, DateTimeOffset UpdatedAt);

internal sealed record MarketListingDto(
    string ListingId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string SellerId);

internal sealed record ServiceMetadata(
    string Service,
    string DisplayName,
    string Domain,
    string Description,
    string[] Owns,
    string[] Responsibilities);

using System.Text.Json.Serialization;

namespace Ff.Identity.Api.Accounts;

public sealed record LoginRequest(string? Email, string? Password);

public sealed record RegisterRequest(string? Email, string? Password, string? Username);

public sealed record AuthResponse(string Token, PlayerDto User);

public sealed record ErrorResponse(string Message);

public sealed record PlayerDto(
    string Uid,
    string Email,
    string Username,
    [property: JsonPropertyName("created_on")] string CreatedOn,
    [property: JsonPropertyName("first_name")] string FirstName,
    [property: JsonPropertyName("last_name")] string LastName,
    string[] Contacts,
    string[] Groups);

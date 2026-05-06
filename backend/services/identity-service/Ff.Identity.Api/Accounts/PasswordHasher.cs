using System.Security.Cryptography;

namespace Ff.Identity.Api.Accounts;

internal static class PasswordHasher
{
    private const int SaltSize = 16;
    private const int KeySize = 32;
    private const int CurrentIterations = 120_000;

    public static PasswordHash Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            CurrentIterations,
            HashAlgorithmName.SHA256,
            KeySize);

        return new PasswordHash(
            Convert.ToBase64String(salt),
            Convert.ToBase64String(hash),
            CurrentIterations);
    }

    public static bool Verify(string password, string salt, string expectedHash, int iterations)
    {
        var saltBytes = Convert.FromBase64String(salt);
        var expectedHashBytes = Convert.FromBase64String(expectedHash);
        var actualHashBytes = Rfc2898DeriveBytes.Pbkdf2(
            password,
            saltBytes,
            iterations,
            HashAlgorithmName.SHA256,
            expectedHashBytes.Length);

        return CryptographicOperations.FixedTimeEquals(actualHashBytes, expectedHashBytes);
    }
}

internal readonly record struct PasswordHash(string Salt, string Hash, int Iterations);

using Microsoft.Extensions.Configuration;
using Npgsql;

namespace Ff.Player.Api.Players;

internal sealed class PlayerProgressionStore : IDisposable
{
    private const int WorkGoldReward = 25;
    private const int WorkExperienceReward = 10;
    private const int TrainStrengthReward = 1;
    private const int TrainExperienceReward = 15;

    private readonly NpgsqlDataSource _dataSource;

    public PlayerProgressionStore(IConfiguration configuration)
    {
        var connectionString = configuration["FF_PLAYER_CONNECTION_STRING"]
            ?? configuration.GetConnectionString("Player")
            ?? "Host=127.0.0.1;Port=5432;Database=ff_dev;Username=ff_dev;Password=ff_dev_password;Include Error Detail=true";
        _dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public async Task InitializeAsync()
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS player;

            CREATE TABLE IF NOT EXISTS player.progression (
                player_id text PRIMARY KEY,
                level integer NOT NULL DEFAULT 1,
                experience integer NOT NULL DEFAULT 0,
                energy integer NOT NULL DEFAULT 100,
                max_energy integer NOT NULL DEFAULT 100,
                strength integer NOT NULL DEFAULT 10,
                gold integer NOT NULL DEFAULT 100,
                last_work_date date NULL,
                last_train_date date NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<PlayerStateDto> GetStateAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);
        return await LoadStateAsync(normalizedPlayerId)
            ?? throw new InvalidOperationException("Player state could not be loaded after initialization.");
    }

    public async Task<PlayerActionResponse> WorkAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var command = _dataSource.CreateCommand("""
            UPDATE player.progression
            SET experience = experience + @experience_reward,
                level = GREATEST(level, floor((experience + @experience_reward)::numeric / 100)::integer + 1),
                last_work_date = CURRENT_DATE,
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND (last_work_date IS NULL OR last_work_date < CURRENT_DATE)
            RETURNING player_id, level, experience, energy, max_energy, strength, gold,
                      COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                      COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                      updated_at;
            """);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId);
        command.Parameters.AddWithValue("experience_reward", WorkExperienceReward);
        command.Parameters.AddWithValue("updated_at", DateTimeOffset.UtcNow);

        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var state = ReadState(reader);
            return new PlayerActionResponse(
                Completed: true,
                Message: $"Work complete. You earned {WorkGoldReward} gold and {WorkExperienceReward} XP.",
                Rewards: new PlayerRewardsDto(Gold: WorkGoldReward, Experience: WorkExperienceReward, Strength: 0),
                State: state);
        }

        var currentState = await GetStateAsync(normalizedPlayerId);
        return new PlayerActionResponse(
            Completed: false,
            Message: "You already worked today. Come back after the daily reset.",
            Rewards: PlayerRewardsDto.None,
            State: currentState);
    }

    public async Task<PlayerActionResponse> TrainAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var command = _dataSource.CreateCommand("""
            UPDATE player.progression
            SET strength = strength + @strength_reward,
                experience = experience + @experience_reward,
                level = GREATEST(level, floor((experience + @experience_reward)::numeric / 100)::integer + 1),
                last_train_date = CURRENT_DATE,
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND (last_train_date IS NULL OR last_train_date < CURRENT_DATE)
            RETURNING player_id, level, experience, energy, max_energy, strength, gold,
                      COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                      COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                      updated_at;
            """);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId);
        command.Parameters.AddWithValue("strength_reward", TrainStrengthReward);
        command.Parameters.AddWithValue("experience_reward", TrainExperienceReward);
        command.Parameters.AddWithValue("updated_at", DateTimeOffset.UtcNow);

        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var state = ReadState(reader);
            return new PlayerActionResponse(
                Completed: true,
                Message: $"Training complete. You gained {TrainStrengthReward} strength and {TrainExperienceReward} XP.",
                Rewards: new PlayerRewardsDto(Gold: 0, Experience: TrainExperienceReward, Strength: TrainStrengthReward),
                State: state);
        }

        var currentState = await GetStateAsync(normalizedPlayerId);
        return new PlayerActionResponse(
            Completed: false,
            Message: "You already trained today. Come back after the daily reset.",
            Rewards: PlayerRewardsDto.None,
            State: currentState);
    }

    public async Task<PlayerActionResponse> ApplyCombatResultAsync(string playerId, CombatResultRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var command = _dataSource.CreateCommand("""
            UPDATE player.progression
            SET energy = GREATEST(0, energy - @energy_cost),
                experience = experience + @experience_reward,
                level = GREATEST(level, floor((experience + @experience_reward)::numeric / 100)::integer + 1),
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND energy >= @energy_cost
            RETURNING player_id, level, experience, energy, max_energy, strength, gold,
                      COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                      COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                      updated_at;
            """);
        command.Parameters.AddWithValue("player_id", normalizedPlayerId);
        command.Parameters.AddWithValue("energy_cost", request.EnergyCost);
        command.Parameters.AddWithValue("experience_reward", request.ExperienceReward);
        command.Parameters.AddWithValue("updated_at", DateTimeOffset.UtcNow);

        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var state = ReadState(reader);
            return new PlayerActionResponse(
                Completed: true,
                Message: request.Message,
                Rewards: new PlayerRewardsDto(
                    Gold: request.GoldReward,
                    Experience: request.ExperienceReward,
                    Strength: 0),
                State: state);
        }

        var currentState = await GetStateAsync(normalizedPlayerId);
        return new PlayerActionResponse(
            Completed: false,
            Message: $"Not enough energy. Required {request.EnergyCost}, available {currentState.Energy}.",
            Rewards: PlayerRewardsDto.None,
            State: currentState);
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task EnsureExistsAsync(string playerId)
    {
        var now = DateTimeOffset.UtcNow;
        await using var command = _dataSource.CreateCommand("""
            INSERT INTO player.progression (player_id, created_at, updated_at)
            VALUES (@player_id, @created_at, @updated_at)
            ON CONFLICT (player_id) DO NOTHING;
            """);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private async Task<PlayerStateDto?> LoadStateAsync(string playerId)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT player_id, level, experience, energy, max_energy, strength, gold,
                   COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                   COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                   updated_at
            FROM player.progression
            WHERE player_id = @player_id;
            """);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadState(reader) : null;
    }

    private static PlayerStateDto ReadState(NpgsqlDataReader reader)
    {
        var experience = reader.GetInt32(2);
        var level = reader.GetInt32(1);
        var experienceToNextLevel = Math.Max(0, (level * 100) - experience);

        return new PlayerStateDto(
            PlayerId: reader.GetString(0),
            Level: level,
            Experience: experience,
            ExperienceToNextLevel: experienceToNextLevel,
            Energy: reader.GetInt32(3),
            MaxEnergy: reader.GetInt32(4),
            Strength: reader.GetInt32(5),
            Gold: reader.GetInt32(6),
            HasWorkedToday: reader.GetBoolean(7),
            HasTrainedToday: reader.GetBoolean(8),
            NextResetAt: NextDailyResetUtc(),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static DateTimeOffset NextDailyResetUtc()
    {
        var nextResetDate = DateTimeOffset.UtcNow.UtcDateTime.Date.AddDays(1);
        return new DateTimeOffset(nextResetDate, TimeSpan.Zero);
    }

    private static string NormalizePlayerId(string playerId)
    {
        return playerId.Trim().ToLowerInvariant();
    }
}

public sealed record PlayerStateDto(
    string PlayerId,
    int Level,
    int Experience,
    int ExperienceToNextLevel,
    int Energy,
    int MaxEnergy,
    int Strength,
    int Gold,
    bool HasWorkedToday,
    bool HasTrainedToday,
    DateTimeOffset NextResetAt,
    DateTimeOffset UpdatedAt);

public sealed record PlayerActionResponse(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    PlayerStateDto State);

public sealed record PlayerRewardsDto(int Gold, int Experience, int Strength)
{
    public static PlayerRewardsDto None { get; } = new(Gold: 0, Experience: 0, Strength: 0);
}

public sealed record CombatResultRequest(
    int EnergyCost,
    int GoldReward,
    int ExperienceReward,
    string Message);

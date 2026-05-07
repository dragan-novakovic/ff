using Microsoft.Extensions.Configuration;
using Npgsql;

namespace Ff.Player.Api.Players;

internal sealed class PlayerProgressionStore : IDisposable
{
    private const int WorkGoldReward = 25;
    private const int WorkExperienceReward = 10;
    private const int TrainStrengthReward = 1;
    private const int TrainExperienceReward = 15;
    private const int EnergyRegenerationAmount = 1;
    private const int HospitalEnergyRestore = 50;
    private const int HospitalGoldCost = 30;
    private static readonly TimeSpan EnergyRegenerationInterval = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan HospitalCooldown = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan MissionCooldown = TimeSpan.FromSeconds(60);

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
                last_energy_regenerated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
                hospital_cooldown_until timestamptz NULL,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            ALTER TABLE player.progression
            ADD COLUMN IF NOT EXISTS last_energy_regenerated_at timestamptz;

            ALTER TABLE player.progression
            ADD COLUMN IF NOT EXISTS hospital_cooldown_until timestamptz NULL;

            UPDATE player.progression
            SET last_energy_regenerated_at = COALESCE(last_energy_regenerated_at, updated_at, created_at, CURRENT_TIMESTAMP)
            WHERE last_energy_regenerated_at IS NULL;

            ALTER TABLE player.progression
            ALTER COLUMN last_energy_regenerated_at SET DEFAULT CURRENT_TIMESTAMP;

            ALTER TABLE player.progression
            ALTER COLUMN last_energy_regenerated_at SET NOT NULL;

            CREATE TABLE IF NOT EXISTS player.energy_actions (
                action_id text PRIMARY KEY,
                player_id text NOT NULL,
                energy_restored integer NOT NULL,
                message text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.mission_progress (
                player_id text NOT NULL,
                mission_id text NOT NULL,
                attempts integer NOT NULL DEFAULT 0,
                wins integer NOT NULL DEFAULT 0,
                losses integer NOT NULL DEFAULT 0,
                total_rounds integer NOT NULL DEFAULT 0,
                last_won boolean NOT NULL DEFAULT false,
                last_result text NOT NULL DEFAULT '',
                last_attempted_at timestamptz NULL,
                cooldown_until timestamptz NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, mission_id)
            );

            CREATE TABLE IF NOT EXISTS player.combat_attempts (
                action_id text PRIMARY KEY,
                player_id text NOT NULL,
                mission_id text NOT NULL,
                won boolean NOT NULL,
                energy_cost integer NOT NULL,
                gold_reward integer NOT NULL,
                experience_reward integer NOT NULL,
                rounds_completed integer NOT NULL,
                message text NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.daily_objective_catalog (
                objective_id text PRIMARY KEY,
                action_type text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                target_count integer NOT NULL,
                reward_gold integer NOT NULL DEFAULT 0,
                reward_experience integer NOT NULL DEFAULT 0,
                reward_strength integer NOT NULL DEFAULT 0,
                reward_energy integer NOT NULL DEFAULT 0,
                display_order integer NOT NULL,
                enabled boolean NOT NULL DEFAULT true,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.daily_objective_progress (
                player_id text NOT NULL,
                objective_id text NOT NULL REFERENCES player.daily_objective_catalog (objective_id),
                reset_date date NOT NULL,
                current_count integer NOT NULL DEFAULT 0,
                completed_at timestamptz NULL,
                claimed_at timestamptz NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, objective_id, reset_date)
            );

            CREATE TABLE IF NOT EXISTS player.daily_objective_events (
                event_id text PRIMARY KEY,
                player_id text NOT NULL,
                action_type text NOT NULL,
                quantity integer NOT NULL,
                reset_date date NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.daily_objective_claims (
                claim_id text PRIMARY KEY,
                player_id text NOT NULL,
                objective_id text NOT NULL,
                reset_date date NOT NULL,
                gold_awarded integer NOT NULL,
                experience_awarded integer NOT NULL,
                strength_awarded integer NOT NULL,
                energy_awarded integer NOT NULL,
                claimed_at timestamptz NOT NULL,
                UNIQUE (player_id, objective_id, reset_date)
            );

            CREATE TABLE IF NOT EXISTS player.onboarding_quest_catalog (
                quest_id text PRIMARY KEY,
                action_type text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                guidance text NOT NULL,
                route text NULL,
                target_count integer NOT NULL,
                reward_gold integer NOT NULL DEFAULT 0,
                reward_experience integer NOT NULL DEFAULT 0,
                reward_strength integer NOT NULL DEFAULT 0,
                reward_energy integer NOT NULL DEFAULT 0,
                display_order integer NOT NULL,
                enabled boolean NOT NULL DEFAULT true,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.onboarding_quest_progress (
                player_id text NOT NULL,
                quest_id text NOT NULL REFERENCES player.onboarding_quest_catalog (quest_id),
                current_count integer NOT NULL DEFAULT 0,
                completed_at timestamptz NULL,
                claimed_at timestamptz NULL,
                skipped_at timestamptz NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, quest_id)
            );

            ALTER TABLE player.onboarding_quest_progress
            ADD COLUMN IF NOT EXISTS skipped_at timestamptz NULL;

            CREATE TABLE IF NOT EXISTS player.onboarding_quest_events (
                event_id text PRIMARY KEY,
                player_id text NOT NULL,
                action_type text NOT NULL,
                quantity integer NOT NULL,
                created_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.onboarding_quest_claims (
                claim_id text PRIMARY KEY,
                player_id text NOT NULL,
                quest_id text NOT NULL,
                gold_awarded integer NOT NULL,
                experience_awarded integer NOT NULL,
                strength_awarded integer NOT NULL,
                energy_awarded integer NOT NULL,
                claimed_at timestamptz NOT NULL,
                UNIQUE (player_id, quest_id)
            );

            CREATE TABLE IF NOT EXISTS player.achievement_catalog (
                achievement_id text PRIMARY KEY,
                action_type text NOT NULL,
                title text NOT NULL,
                description text NOT NULL,
                category text NOT NULL,
                medal_name text NOT NULL,
                medal_rarity text NOT NULL,
                target_count integer NOT NULL,
                points integer NOT NULL DEFAULT 0,
                display_order integer NOT NULL,
                enabled boolean NOT NULL DEFAULT true,
                created_at timestamptz NOT NULL,
                updated_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.achievement_progress (
                player_id text NOT NULL,
                achievement_id text NOT NULL REFERENCES player.achievement_catalog (achievement_id),
                current_count integer NOT NULL DEFAULT 0,
                unlocked_at timestamptz NULL,
                claimed_at timestamptz NULL,
                updated_at timestamptz NOT NULL,
                PRIMARY KEY (player_id, achievement_id)
            );

            CREATE TABLE IF NOT EXISTS player.achievement_events (
                event_id text PRIMARY KEY,
                player_id text NOT NULL,
                action_type text NOT NULL,
                quantity integer NOT NULL,
                related_id text NULL,
                created_at timestamptz NOT NULL
            );

            CREATE TABLE IF NOT EXISTS player.achievement_awards (
                award_id text PRIMARY KEY,
                player_id text NOT NULL,
                achievement_id text NOT NULL REFERENCES player.achievement_catalog (achievement_id),
                points_awarded integer NOT NULL,
                medal_rarity text NOT NULL,
                awarded_at timestamptz NOT NULL,
                UNIQUE (player_id, achievement_id)
            );

            CREATE TABLE IF NOT EXISTS player.achievement_claims (
                claim_id text PRIMARY KEY,
                player_id text NOT NULL,
                achievement_id text NOT NULL REFERENCES player.achievement_catalog (achievement_id),
                claimed_at timestamptz NOT NULL,
                UNIQUE (player_id, achievement_id)
            );

            INSERT INTO player.daily_objective_catalog (
                objective_id, action_type, title, description, target_count,
                reward_gold, reward_experience, reward_strength, reward_energy,
                display_order, enabled, created_at, updated_at
            )
            VALUES
                ('daily-work-shift', 'work', 'Work a shift', 'Complete one work action before the daily reset.', 1, 20, 5, 0, 0, 10, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('daily-training-drill', 'train', 'Train your fighter', 'Complete one training action before the daily reset.', 1, 10, 10, 0, 0, 20, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('daily-mission-fight', 'fight', 'Fight a mission', 'Attempt one combat mission before the daily reset.', 1, 25, 15, 0, 0, 30, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('daily-production-start', 'production_start', 'Start production', 'Start one factory production job before the daily reset.', 1, 15, 5, 0, 0, 40, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('daily-production-claim', 'production_claim', 'Claim production', 'Claim one completed production job before the daily reset.', 1, 20, 10, 0, 0, 50, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('daily-hospital-recovery', 'hospital_recover', 'Visit the hospital', 'Recover energy at the hospital before the daily reset.', 1, 5, 5, 0, 0, 60, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (objective_id) DO UPDATE
            SET action_type = EXCLUDED.action_type,
                title = EXCLUDED.title,
                description = EXCLUDED.description,
                target_count = EXCLUDED.target_count,
                reward_gold = EXCLUDED.reward_gold,
                reward_experience = EXCLUDED.reward_experience,
                reward_strength = EXCLUDED.reward_strength,
                reward_energy = EXCLUDED.reward_energy,
                display_order = EXCLUDED.display_order,
                enabled = EXCLUDED.enabled,
                updated_at = CURRENT_TIMESTAMP;

            INSERT INTO player.onboarding_quest_catalog (
                quest_id, action_type, title, description, guidance, route, target_count,
                reward_gold, reward_experience, reward_strength, reward_energy,
                display_order, enabled, created_at, updated_at
            )
            VALUES
                ('choose-country', 'choose_country', 'Choose your country', 'Pick a country so your citizenship, taxes, battles, and politics have a home.', 'Open World and join any country that looks interesting.', '/world', 1, 10, 5, 0, 0, 10, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('first-work', 'work', 'Work your first shift', 'Earn your first wage and see wallet persistence in action.', 'Use the Work button on your dashboard.', '/home', 1, 15, 5, 0, 0, 20, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('first-training', 'train', 'Train your fighter', 'Gain strength so future fights are easier.', 'Use the Train button on your dashboard.', '/home', 1, 10, 10, 1, 0, 30, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('first-production', 'produce', 'Start production', 'Queue a factory job and turn input materials into output goods.', 'Open Factories and start production in one of your factories.', '/factories', 1, 15, 10, 0, 0, 40, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('first-fight', 'fight', 'Fight a mission', 'Try combat to earn rewards and mission progress.', 'Open Missions and simulate any available fight.', '/missions', 1, 20, 15, 0, 5, 50, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('company-action', 'company_action', 'Join company life', 'Create, join, or work for a company to participate in the player economy.', 'Open Companies and create, join, or work a company job.', '/companies', 1, 20, 10, 0, 0, 60, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('unit-action', 'unit_action', 'Join military organization', 'Create or join a military unit for coordinated battle activity.', 'Open Military Units and create or join a unit.', '/military-units', 1, 20, 10, 1, 0, 70, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('party-action', 'party_action', 'Join politics', 'Create or join a party to participate in elections and laws.', 'Open Politics and create or join a political party.', '/politics', 1, 20, 10, 0, 0, 80, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (quest_id) DO UPDATE
            SET action_type = EXCLUDED.action_type,
                title = EXCLUDED.title,
                description = EXCLUDED.description,
                guidance = EXCLUDED.guidance,
                route = EXCLUDED.route,
                target_count = EXCLUDED.target_count,
                reward_gold = EXCLUDED.reward_gold,
                reward_experience = EXCLUDED.reward_experience,
                reward_strength = EXCLUDED.reward_strength,
                reward_energy = EXCLUDED.reward_energy,
                display_order = EXCLUDED.display_order,
                enabled = EXCLUDED.enabled,
                updated_at = CURRENT_TIMESTAMP;

            INSERT INTO player.achievement_catalog (
                achievement_id, action_type, title, description, category, medal_name,
                medal_rarity, target_count, points, display_order, enabled, created_at, updated_at
            )
            VALUES
                ('first-work-shift', 'work', 'First Shift', 'Complete your first citizen work action.', 'Work & Training', 'Bronze Worker Medal', 'bronze', 1, 10, 10, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('steady-worker', 'work', 'Steady Worker', 'Complete five citizen work actions.', 'Work & Training', 'Silver Worker Medal', 'silver', 5, 25, 20, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('first-training', 'train', 'Training Initiate', 'Complete your first training session.', 'Work & Training', 'Bronze Training Medal', 'bronze', 1, 10, 30, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('disciplined-trainee', 'train', 'Disciplined Trainee', 'Complete five training sessions.', 'Work & Training', 'Silver Training Medal', 'silver', 5, 25, 40, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('mission-rookie', 'fight', 'Mission Rookie', 'Fight your first combat mission.', 'Battles & Campaigns', 'Bronze Combat Medal', 'bronze', 1, 15, 50, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('battle-volunteer', 'battle_contribution', 'Battle Volunteer', 'Contribute to a country battle.', 'Battles & Campaigns', 'Bronze Battle Medal', 'bronze', 1, 20, 60, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('battle-damage-100', 'battle_damage', 'Battle Tested', 'Deal 100 total damage in country battles.', 'Battles & Campaigns', 'Silver Battle Medal', 'silver', 100, 35, 70, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('production-starter', 'production_start', 'Production Starter', 'Start your first factory production job.', 'Economy & Production', 'Bronze Production Medal', 'bronze', 1, 15, 80, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('production-collector', 'production_claim', 'Production Collector', 'Claim your first completed production job.', 'Economy & Production', 'Silver Production Medal', 'silver', 1, 20, 90, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('market-trader', 'market_trade', 'Market Trader', 'Complete your first market purchase or sale.', 'Economy & Market', 'Bronze Trade Medal', 'bronze', 1, 15, 100, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('deal-maker', 'market_trade', 'Deal Maker', 'Complete five market trades.', 'Economy & Market', 'Silver Trade Medal', 'silver', 5, 30, 110, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('company-worker', 'company_work', 'Company Worker', 'Complete your first company workforce shift.', 'Companies & Workforce', 'Bronze Workforce Medal', 'bronze', 1, 20, 120, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('company-regular', 'company_work', 'Company Regular', 'Complete five company workforce shifts.', 'Companies & Workforce', 'Silver Workforce Medal', 'silver', 5, 35, 130, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('company-life', 'company_action', 'Company Life', 'Create, join, or otherwise take a company action.', 'Companies & Workforce', 'Company Citizen Medal', 'bronze', 1, 15, 140, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('country-citizen', 'choose_country', 'Citizen', 'Join or change citizenship through the world system.', 'Territory & Citizenship', 'Citizenship Medal', 'bronze', 1, 15, 150, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('onboarding-graduate', 'onboarding_complete', 'Onboarding Graduate', 'Complete the onboarding questline.', 'Onboarding', 'Graduate Medal', 'gold', 1, 50, 160, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('party-member', 'party_action', 'Party Member', 'Create or join a political party.', 'Politics & Laws', 'Civic Medal', 'bronze', 1, 20, 170, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('law-maker', 'law_vote', 'Law Maker', 'Cast a vote or participate in a law proposal.', 'Politics & Laws', 'Congress Medal', 'silver', 1, 25, 180, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('press-voice', 'newspaper_publish', 'Press Voice', 'Publish your first newspaper article.', 'Media & Newspapers', 'Press Medal', 'bronze', 1, 20, 190, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('campaign-helper', 'campaign_action', 'Campaign Helper', 'Take part in a political or military campaign.', 'Battles & Campaigns', 'Campaign Medal', 'silver', 1, 25, 200, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (achievement_id) DO UPDATE
            SET action_type = EXCLUDED.action_type,
                title = EXCLUDED.title,
                description = EXCLUDED.description,
                category = EXCLUDED.category,
                medal_name = EXCLUDED.medal_name,
                medal_rarity = EXCLUDED.medal_rarity,
                target_count = EXCLUDED.target_count,
                points = EXCLUDED.points,
                display_order = EXCLUDED.display_order,
                enabled = EXCLUDED.enabled,
                updated_at = CURRENT_TIMESTAMP;

            CREATE INDEX IF NOT EXISTS daily_objective_progress_player_reset_idx
            ON player.daily_objective_progress (player_id, reset_date);

            CREATE INDEX IF NOT EXISTS daily_objective_events_player_reset_idx
            ON player.daily_objective_events (player_id, reset_date, action_type);

            CREATE INDEX IF NOT EXISTS onboarding_quest_progress_player_idx
            ON player.onboarding_quest_progress (player_id, quest_id);

            CREATE INDEX IF NOT EXISTS onboarding_quest_events_player_action_idx
            ON player.onboarding_quest_events (player_id, action_type, created_at);

            CREATE INDEX IF NOT EXISTS achievement_catalog_action_idx
            ON player.achievement_catalog (action_type, enabled);

            CREATE INDEX IF NOT EXISTS achievement_progress_player_idx
            ON player.achievement_progress (player_id, achievement_id);

            CREATE INDEX IF NOT EXISTS achievement_events_player_action_idx
            ON player.achievement_events (player_id, action_type, created_at);

            CREATE INDEX IF NOT EXISTS achievement_awards_player_awarded_idx
            ON player.achievement_awards (player_id, awarded_at DESC);

            CREATE INDEX IF NOT EXISTS progression_level_ranking_idx
            ON player.progression (level DESC, experience DESC, strength DESC, updated_at ASC, player_id ASC);

            CREATE INDEX IF NOT EXISTS progression_experience_ranking_idx
            ON player.progression (experience DESC, level DESC, strength DESC, updated_at ASC, player_id ASC);

            CREATE INDEX IF NOT EXISTS progression_strength_ranking_idx
            ON player.progression (strength DESC, level DESC, experience DESC, updated_at ASC, player_id ASC);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        await command.ExecuteNonQueryAsync();
    }

    public async Task<PlayerStateDto> GetStateAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);
        await ApplyEnergyRegenerationAsync(normalizedPlayerId);
        return await LoadStateAsync(normalizedPlayerId)
            ?? throw new InvalidOperationException("Player state could not be loaded after initialization.");
    }

    public async Task<MissionProgressResponse> GetMissionProgressAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var missions = await ReadMissionProgressAsync(connection, null, normalizedPlayerId);
        return new MissionProgressResponse(
            PlayerId: normalizedPlayerId,
            Missions: missions.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<DailyObjectivesResponse> GetDailyObjectivesAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var resetDate = CurrentResetDate();

        await EnsureDailyObjectiveProgressAsync(connection, transaction, normalizedPlayerId, resetDate, now);
        var objectives = await ReadDailyObjectivesAsync(connection, transaction, normalizedPlayerId, resetDate);
        await transaction.CommitAsync();

        return new DailyObjectivesResponse(
            PlayerId: normalizedPlayerId,
            ResetDate: resetDate,
            ResetAt: ResetAt(resetDate),
            Objectives: objectives.ToArray(),
            UpdatedAt: now);
    }

    public async Task<OnboardingQuestlineResponse> GetOnboardingQuestlineAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await EnsureOnboardingQuestProgressAsync(connection, transaction, normalizedPlayerId, now);
        var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now);
    }

    public async Task<AchievementsSummary> GetAchievementsAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await EnsureAchievementProgressAsync(connection, transaction, normalizedPlayerId, now);
        var achievements = await ReadAchievementsAsync(connection, transaction, normalizedPlayerId);
        var recentUnlocks = await ReadRecentAchievementUnlocksAsync(connection, transaction, normalizedPlayerId, 10);
        await transaction.CommitAsync();

        return BuildAchievementsSummary(normalizedPlayerId, achievements, recentUnlocks, now);
    }

    public async Task<AchievementUnlocksResponse> GetRecentAchievementUnlocksAsync(string playerId, int? limit)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var safeLimit = Math.Clamp(limit ?? 10, 1, 50);

        await EnsureAchievementProgressAsync(connection, transaction, normalizedPlayerId, now);
        var recentUnlocks = await ReadRecentAchievementUnlocksAsync(
            connection,
            transaction,
            normalizedPlayerId,
            safeLimit);
        await transaction.CommitAsync();

        return new AchievementUnlocksResponse(normalizedPlayerId, recentUnlocks.ToArray(), now);
    }

    public async Task<AchievementsSummary> TrackAchievementAsync(
        string playerId,
        AchievementTrackRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionType = NormalizeId(request.ActionType);
        var eventId = request.IdempotencyKey.Trim().ToLowerInvariant();
        var quantity = Math.Max(1, request.Quantity);
        var relatedId = string.IsNullOrWhiteSpace(request.RelatedId)
            ? null
            : request.RelatedId.Trim().ToLowerInvariant();
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await EnsureAchievementProgressAsync(connection, transaction, normalizedPlayerId, now);
        var existingEventPlayerId = await ReadAchievementEventPlayerIdAsync(connection, transaction, eventId);
        if (existingEventPlayerId is null)
        {
            await AddAchievementEventAsync(
                connection,
                transaction,
                eventId,
                normalizedPlayerId,
                actionType,
                quantity,
                relatedId,
                now);
            var newlyUnlocked = await IncrementAchievementProgressAsync(
                connection,
                transaction,
                normalizedPlayerId,
                actionType,
                quantity,
                now);
            foreach (var achievement in newlyUnlocked)
            {
                await AddAchievementAwardAsync(
                    connection,
                    transaction,
                    $"achievement-award:{normalizedPlayerId}:{achievement.AchievementId}",
                    normalizedPlayerId,
                    achievement,
                    now);
            }
        }

        var achievements = await ReadAchievementsAsync(connection, transaction, normalizedPlayerId);
        var recentUnlocks = await ReadRecentAchievementUnlocksAsync(connection, transaction, normalizedPlayerId, 10);
        await transaction.CommitAsync();

        return BuildAchievementsSummary(normalizedPlayerId, achievements, recentUnlocks, now);
    }

    public async Task<AchievementClaimResponse> ClaimAchievementAsync(
        string playerId,
        string achievementId,
        AchievementClaimRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedAchievementId = NormalizeId(achievementId);
        var claimId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await EnsureAchievementProgressAsync(connection, transaction, normalizedPlayerId, now);
        var existingClaim = await ReadAchievementClaimAsync(connection, transaction, claimId);
        if (existingClaim is not null)
        {
            var achievements = await ReadAchievementsAsync(connection, transaction, normalizedPlayerId);
            var recentUnlocks = await ReadRecentAchievementUnlocksAsync(connection, transaction, normalizedPlayerId, 10);
            await transaction.CommitAsync();

            var achievement = achievements.FirstOrDefault(candidate =>
                string.Equals(candidate.AchievementId, normalizedAchievementId, StringComparison.Ordinal));
            var completed = string.Equals(existingClaim.PlayerId, normalizedPlayerId, StringComparison.Ordinal) &&
                string.Equals(existingClaim.AchievementId, normalizedAchievementId, StringComparison.Ordinal);
            return new AchievementClaimResponse(
                Completed: completed,
                Message: completed
                    ? "Achievement medal was already claimed."
                    : "Achievement claim idempotency key was already used.",
                Achievement: achievement,
                Achievements: BuildAchievementsSummary(normalizedPlayerId, achievements, recentUnlocks, now));
        }

        var achievementForUpdate = await ReadAchievementForUpdateAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedAchievementId);
        if (achievementForUpdate is null)
        {
            var achievements = await ReadAchievementsAsync(connection, transaction, normalizedPlayerId);
            var recentUnlocks = await ReadRecentAchievementUnlocksAsync(connection, transaction, normalizedPlayerId, 10);
            await transaction.CommitAsync();
            return new AchievementClaimResponse(
                Completed: false,
                Message: "Achievement was not found.",
                Achievement: null,
                Achievements: BuildAchievementsSummary(normalizedPlayerId, achievements, recentUnlocks, now));
        }

        if (!achievementForUpdate.Unlocked)
        {
            var achievements = await ReadAchievementsAsync(connection, transaction, normalizedPlayerId);
            var recentUnlocks = await ReadRecentAchievementUnlocksAsync(connection, transaction, normalizedPlayerId, 10);
            await transaction.CommitAsync();
            return new AchievementClaimResponse(
                Completed: false,
                Message: "Achievement has not been unlocked yet.",
                Achievement: achievementForUpdate,
                Achievements: BuildAchievementsSummary(normalizedPlayerId, achievements, recentUnlocks, now));
        }

        if (!achievementForUpdate.Claimed)
        {
            await MarkAchievementClaimedAsync(
                connection,
                transaction,
                normalizedPlayerId,
                normalizedAchievementId,
                now);
            await AddAchievementClaimAsync(
                connection,
                transaction,
                claimId,
                normalizedPlayerId,
                normalizedAchievementId,
                now);
        }

        var updatedAchievements = await ReadAchievementsAsync(connection, transaction, normalizedPlayerId);
        var updatedRecentUnlocks = await ReadRecentAchievementUnlocksAsync(connection, transaction, normalizedPlayerId, 10);
        await transaction.CommitAsync();
        var updatedAchievement = updatedAchievements.FirstOrDefault(candidate =>
            string.Equals(candidate.AchievementId, normalizedAchievementId, StringComparison.Ordinal)) ?? achievementForUpdate;

        return new AchievementClaimResponse(
            Completed: true,
            Message: updatedAchievement.Claimed
                ? $"Claimed {updatedAchievement.MedalName}."
                : "Achievement medal was already claimed.",
            Achievement: updatedAchievement,
            Achievements: BuildAchievementsSummary(normalizedPlayerId, updatedAchievements, updatedRecentUnlocks, now));
    }

    public async Task<OnboardingQuestlineResponse> TrackOnboardingQuestAsync(
        string playerId,
        OnboardingQuestTrackRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionType = NormalizeId(request.ActionType);
        var eventId = request.IdempotencyKey.Trim().ToLowerInvariant();
        var quantity = Math.Max(1, request.Quantity);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await EnsureOnboardingQuestProgressAsync(connection, transaction, normalizedPlayerId, now);
        var existingEventPlayerId = await ReadOnboardingQuestEventPlayerIdAsync(connection, transaction, eventId);
        if (existingEventPlayerId is null)
        {
            await AddOnboardingQuestEventAsync(
                connection,
                transaction,
                eventId,
                normalizedPlayerId,
                actionType,
                quantity,
                now);
            await IncrementOnboardingQuestProgressAsync(
                connection,
                transaction,
                normalizedPlayerId,
                actionType,
                quantity,
                now);
        }

        var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now);
    }

    public async Task<OnboardingQuestClaimResponse> ClaimOnboardingQuestAsync(
        string playerId,
        string questId,
        OnboardingQuestClaimRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedQuestId = NormalizeId(questId);
        var claimId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await EnsureOnboardingQuestProgressAsync(connection, transaction, normalizedPlayerId, now);

        var existingClaim = await ReadOnboardingQuestClaimAsync(connection, transaction, claimId);
        if (existingClaim is not null)
        {
            var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();

            var completed = string.Equals(existingClaim.PlayerId, normalizedPlayerId, StringComparison.Ordinal) &&
                string.Equals(existingClaim.QuestId, normalizedQuestId, StringComparison.Ordinal);
            return new OnboardingQuestClaimResponse(
                Completed: completed,
                Message: completed
                    ? "Onboarding reward was already claimed."
                    : "Onboarding claim idempotency key was already used.",
                Rewards: completed
                    ? new PlayerRewardsDto(
                        existingClaim.GoldAwarded,
                        existingClaim.ExperienceAwarded,
                        existingClaim.StrengthAwarded,
                        existingClaim.EnergyAwarded)
                    : PlayerRewardsDto.None,
                State: state,
                Quest: quests.FirstOrDefault(candidate =>
                    string.Equals(candidate.QuestId, normalizedQuestId, StringComparison.Ordinal)),
                Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now));
        }

        var quest = await ReadOnboardingQuestForUpdateAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedQuestId);
        if (quest is null)
        {
            var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();

            return new OnboardingQuestClaimResponse(
                Completed: false,
                Message: "Onboarding quest was not found.",
                Rewards: PlayerRewardsDto.None,
                State: state,
                Quest: null,
                Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now));
        }

        if (quest.Skipped)
        {
            var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();

            return new OnboardingQuestClaimResponse(
                Completed: false,
                Message: "Skipped onboarding quests cannot be claimed.",
                Rewards: PlayerRewardsDto.None,
                State: state,
                Quest: quest,
                Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now));
        }

        if (!quest.Completed)
        {
            var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();

            return new OnboardingQuestClaimResponse(
                Completed: false,
                Message: "Onboarding quest is not complete yet.",
                Rewards: PlayerRewardsDto.None,
                State: state,
                Quest: quest,
                Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now));
        }

        if (quest.Claimed)
        {
            existingClaim = await ReadOnboardingQuestClaimByQuestAsync(
                connection,
                transaction,
                normalizedPlayerId,
                normalizedQuestId);
            var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();

            return new OnboardingQuestClaimResponse(
                Completed: existingClaim is not null,
                Message: "Onboarding reward was already claimed.",
                Rewards: existingClaim is null
                    ? PlayerRewardsDto.None
                    : new PlayerRewardsDto(
                        existingClaim.GoldAwarded,
                        existingClaim.ExperienceAwarded,
                        existingClaim.StrengthAwarded,
                        existingClaim.EnergyAwarded),
                State: state,
                Quest: quests.FirstOrDefault(candidate =>
                    string.Equals(candidate.QuestId, normalizedQuestId, StringComparison.Ordinal)) ?? quest,
                Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now));
        }

        await MarkOnboardingQuestClaimedAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedQuestId,
            now);
        await AddOnboardingQuestClaimAsync(
            connection,
            transaction,
            claimId,
            normalizedPlayerId,
            normalizedQuestId,
            quest.Rewards,
            now);
        var updatedState = await ApplyOnboardingQuestPlayerRewardAsync(
            connection,
            transaction,
            normalizedPlayerId,
            quest.Rewards,
            now);
        var updatedQuests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();

        return new OnboardingQuestClaimResponse(
            Completed: true,
            Message: $"Claimed {quest.Title}.",
            Rewards: quest.Rewards,
            State: updatedState,
            Quest: updatedQuests.FirstOrDefault(candidate =>
                string.Equals(candidate.QuestId, normalizedQuestId, StringComparison.Ordinal)) ?? quest,
            Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, updatedQuests, now));
    }

    public async Task<OnboardingQuestSkipResponse> SkipOnboardingQuestAsync(
        string playerId,
        string questId,
        OnboardingQuestSkipRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedQuestId = NormalizeId(questId);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        await EnsureOnboardingQuestProgressAsync(connection, transaction, normalizedPlayerId, now);
        var quest = await ReadOnboardingQuestForUpdateAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedQuestId);
        if (quest is null)
        {
            var quests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
            await transaction.CommitAsync();
            return new OnboardingQuestSkipResponse(
                Completed: false,
                Message: "Onboarding quest was not found.",
                Quest: null,
                Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, quests, now));
        }

        if (!quest.Claimed && !quest.Skipped)
        {
            await MarkOnboardingQuestSkippedAsync(
                connection,
                transaction,
                normalizedPlayerId,
                normalizedQuestId,
                now);
        }

        var updatedQuests = await ReadOnboardingQuestsAsync(connection, transaction, normalizedPlayerId);
        await transaction.CommitAsync();
        var updatedQuest = updatedQuests.FirstOrDefault(candidate =>
            string.Equals(candidate.QuestId, normalizedQuestId, StringComparison.Ordinal)) ?? quest;

        return new OnboardingQuestSkipResponse(
            Completed: !updatedQuest.Claimed,
            Message: updatedQuest.Claimed
                ? "Claimed onboarding quests cannot be skipped."
                : $"Skipped {updatedQuest.Title}.",
            Quest: updatedQuest,
            Questline: BuildOnboardingQuestlineResponse(normalizedPlayerId, updatedQuests, now));
    }

    public async Task<DailyObjectivesResponse> TrackDailyObjectiveAsync(
        string playerId,
        DailyObjectiveTrackRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionType = NormalizeId(request.ActionType);
        var eventId = request.IdempotencyKey.Trim().ToLowerInvariant();
        var quantity = Math.Max(1, request.Quantity);
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var resetDate = CurrentResetDate();

        await EnsureDailyObjectiveProgressAsync(connection, transaction, normalizedPlayerId, resetDate, now);
        var existingEventPlayerId = await ReadDailyObjectiveEventPlayerIdAsync(connection, transaction, eventId);
        if (existingEventPlayerId is null)
        {
            await AddDailyObjectiveEventAsync(
                connection,
                transaction,
                eventId,
                normalizedPlayerId,
                actionType,
                quantity,
                resetDate,
                now);
            await IncrementDailyObjectiveProgressAsync(
                connection,
                transaction,
                normalizedPlayerId,
                actionType,
                quantity,
                resetDate,
                now);
        }

        var objectives = await ReadDailyObjectivesAsync(connection, transaction, normalizedPlayerId, resetDate);
        await transaction.CommitAsync();

        return new DailyObjectivesResponse(
            PlayerId: normalizedPlayerId,
            ResetDate: resetDate,
            ResetAt: ResetAt(resetDate),
            Objectives: objectives.ToArray(),
            UpdatedAt: now);
    }

    public async Task<DailyObjectiveClaimResponse> ClaimDailyObjectiveAsync(
        string playerId,
        string objectiveId,
        DailyObjectiveClaimRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedObjectiveId = NormalizeId(objectiveId);
        var claimId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var resetDate = CurrentResetDate();

        await EnsureDailyObjectiveProgressAsync(connection, transaction, normalizedPlayerId, resetDate, now);

        var existingClaim = await ReadDailyObjectiveClaimAsync(connection, transaction, claimId);
        if (existingClaim is not null)
        {
            var objectives = await ReadDailyObjectivesAsync(connection, transaction, normalizedPlayerId, resetDate);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();

            var completed = string.Equals(existingClaim.PlayerId, normalizedPlayerId, StringComparison.Ordinal) &&
                string.Equals(existingClaim.ObjectiveId, normalizedObjectiveId, StringComparison.Ordinal) &&
                existingClaim.ResetDate == resetDate;
            return new DailyObjectiveClaimResponse(
                Completed: completed,
                Message: completed
                    ? "Daily objective reward was already claimed."
                    : "Daily objective claim idempotency key was already used.",
                Rewards: completed
                    ? new PlayerRewardsDto(
                        existingClaim.GoldAwarded,
                        existingClaim.ExperienceAwarded,
                        existingClaim.StrengthAwarded,
                        existingClaim.EnergyAwarded)
                    : PlayerRewardsDto.None,
                State: state,
                Objective: objectives.FirstOrDefault(candidate =>
                    string.Equals(candidate.ObjectiveId, normalizedObjectiveId, StringComparison.Ordinal)),
                Objectives: new DailyObjectivesResponse(
                    PlayerId: normalizedPlayerId,
                    ResetDate: resetDate,
                    ResetAt: ResetAt(resetDate),
                    Objectives: objectives.ToArray(),
                    UpdatedAt: now));
        }

        var objective = await ReadDailyObjectiveForUpdateAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedObjectiveId,
            resetDate);
        if (objective is null)
        {
            var objectives = await ReadDailyObjectivesAsync(connection, transaction, normalizedPlayerId, resetDate);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();
            return new DailyObjectiveClaimResponse(
                Completed: false,
                Message: "Daily objective was not found.",
                Rewards: PlayerRewardsDto.None,
                State: state,
                Objective: null,
                Objectives: new DailyObjectivesResponse(
                    PlayerId: normalizedPlayerId,
                    ResetDate: resetDate,
                    ResetAt: ResetAt(resetDate),
                    Objectives: objectives.ToArray(),
                    UpdatedAt: now));
        }

        if (!objective.Completed)
        {
            var objectives = await ReadDailyObjectivesAsync(connection, transaction, normalizedPlayerId, resetDate);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();
            return new DailyObjectiveClaimResponse(
                Completed: false,
                Message: "Daily objective is not complete yet.",
                Rewards: PlayerRewardsDto.None,
                State: state,
                Objective: objective,
                Objectives: new DailyObjectivesResponse(
                    PlayerId: normalizedPlayerId,
                    ResetDate: resetDate,
                    ResetAt: ResetAt(resetDate),
                    Objectives: objectives.ToArray(),
                    UpdatedAt: now));
        }

        if (objective.Claimed)
        {
            existingClaim = await ReadDailyObjectiveClaimByObjectiveAsync(
                connection,
                transaction,
                normalizedPlayerId,
                normalizedObjectiveId,
                resetDate);
            var objectives = await ReadDailyObjectivesAsync(connection, transaction, normalizedPlayerId, resetDate);
            var state = await LoadStateAsync(connection, transaction, normalizedPlayerId)
                ?? throw new InvalidOperationException("Player state could not be loaded.");
            await transaction.CommitAsync();
            return new DailyObjectiveClaimResponse(
                Completed: existingClaim is not null,
                Message: "Daily objective reward was already claimed.",
                Rewards: existingClaim is null
                    ? PlayerRewardsDto.None
                    : new PlayerRewardsDto(
                        existingClaim.GoldAwarded,
                        existingClaim.ExperienceAwarded,
                        existingClaim.StrengthAwarded,
                        existingClaim.EnergyAwarded),
                State: state,
                Objective: objectives.FirstOrDefault(candidate =>
                    string.Equals(candidate.ObjectiveId, normalizedObjectiveId, StringComparison.Ordinal)) ?? objective,
                Objectives: new DailyObjectivesResponse(
                    PlayerId: normalizedPlayerId,
                    ResetDate: resetDate,
                    ResetAt: ResetAt(resetDate),
                    Objectives: objectives.ToArray(),
                    UpdatedAt: now));
        }

        await MarkDailyObjectiveClaimedAsync(
            connection,
            transaction,
            normalizedPlayerId,
            normalizedObjectiveId,
            resetDate,
            now);
        await AddDailyObjectiveClaimAsync(
            connection,
            transaction,
            claimId,
            normalizedPlayerId,
            normalizedObjectiveId,
            resetDate,
            objective.Rewards,
            now);
        var updatedState = await ApplyDailyObjectivePlayerRewardAsync(
            connection,
            transaction,
            normalizedPlayerId,
            objective.Rewards,
            now);
        var updatedObjectives = await ReadDailyObjectivesAsync(connection, transaction, normalizedPlayerId, resetDate);
        await transaction.CommitAsync();

        var claimedObjective = updatedObjectives.FirstOrDefault(candidate =>
            string.Equals(candidate.ObjectiveId, normalizedObjectiveId, StringComparison.Ordinal)) ?? objective;
        return new DailyObjectiveClaimResponse(
            Completed: true,
            Message: $"Claimed {objective.Title}.",
            Rewards: objective.Rewards,
            State: updatedState,
            Objective: claimedObjective,
            Objectives: new DailyObjectivesResponse(
                PlayerId: normalizedPlayerId,
                ResetDate: resetDate,
                ResetAt: ResetAt(resetDate),
                Objectives: updatedObjectives.ToArray(),
                UpdatedAt: now));
    }

    public async Task<PlayerRankingsResponse> GetRankingsAsync(string? sortBy, int? limit)
    {
        var normalizedSortBy = NormalizeRankingSort(sortBy);
        var safeLimit = ClampRankingLimit(limit);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var totalPlayers = await CountRankedPlayersAsync(connection);
        var entries = await ReadRankingsAsync(connection, normalizedSortBy, safeLimit);

        return new PlayerRankingsResponse(
            SortBy: normalizedSortBy,
            Limit: safeLimit,
            TotalPlayers: totalPlayers,
            Entries: entries.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<PlayerRankingEntryDto?> GetRankingAsync(string playerId, string? sortBy)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var normalizedSortBy = NormalizeRankingSort(sortBy);
        await using var connection = await _dataSource.OpenConnectionAsync();
        return await ReadRankingAsync(connection, normalizedPlayerId, normalizedSortBy);
    }

    public async Task<PlayerActionResponse> WorkAsync(string playerId)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        await EnsureExistsAsync(normalizedPlayerId);
        await ApplyEnergyRegenerationAsync(normalizedPlayerId);

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
                      updated_at, last_energy_regenerated_at, hospital_cooldown_until;
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
        await ApplyEnergyRegenerationAsync(normalizedPlayerId);

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
                      updated_at, last_energy_regenerated_at, hospital_cooldown_until;
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
        var missionId = NormalizeId(request.MissionId);
        var actionId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var existingAttempt = await ReadCombatAttemptAsync(connection, transaction, actionId);
        if (existingAttempt is not null)
        {
            await transaction.CommitAsync();
            var state = await GetStateAsync(normalizedPlayerId);
            var progress = await GetMissionProgressAsync(normalizedPlayerId);
            return new PlayerActionResponse(
                Completed: string.Equals(existingAttempt.PlayerId, normalizedPlayerId, StringComparison.Ordinal),
                Message: string.Equals(existingAttempt.PlayerId, normalizedPlayerId, StringComparison.Ordinal)
                    ? "Mission attempt was already applied."
                    : "Combat idempotency key was already used by another player.",
                Rewards: string.Equals(existingAttempt.PlayerId, normalizedPlayerId, StringComparison.Ordinal)
                    ? new PlayerRewardsDto(
                        Gold: existingAttempt.GoldReward,
                        Experience: existingAttempt.ExperienceReward,
                        Strength: 0)
                    : PlayerRewardsDto.None,
                State: state,
                MissionProgress: progress.Missions.FirstOrDefault(progress => progress.MissionId == missionId));
        }

        await ApplyEnergyRegenerationAsync(connection, transaction, normalizedPlayerId, now);

        PlayerStateDto? updatedState = null;
        await using (var command = new NpgsqlCommand("""
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
                      updated_at, last_energy_regenerated_at, hospital_cooldown_until;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("player_id", normalizedPlayerId);
            command.Parameters.AddWithValue("energy_cost", request.EnergyCost);
            command.Parameters.AddWithValue("experience_reward", request.ExperienceReward);
            command.Parameters.AddWithValue("updated_at", now);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                updatedState = ReadState(reader);
            }
        }

        if (updatedState is null)
        {
            await transaction.RollbackAsync();
            var currentState = await GetStateAsync(normalizedPlayerId);
            return new PlayerActionResponse(
                Completed: false,
                Message: $"Not enough energy. Required {request.EnergyCost}, available {currentState.Energy}.",
                Rewards: PlayerRewardsDto.None,
                State: currentState,
                MissionProgress: null);
        }

        var missionProgress = await UpsertMissionProgressAsync(
            connection,
            transaction,
            normalizedPlayerId,
            missionId,
            request.Won,
            request.RoundsCompleted,
            request.Message,
            now);
        await AddCombatAttemptAsync(
            connection,
            transaction,
            actionId,
            normalizedPlayerId,
            missionId,
            request.Won,
            request.EnergyCost,
            request.GoldReward,
            request.ExperienceReward,
            request.RoundsCompleted,
            request.Message,
            now);
        await transaction.CommitAsync();

        return new PlayerActionResponse(
            Completed: true,
            Message: request.Message,
            Rewards: new PlayerRewardsDto(
                Gold: request.GoldReward,
                Experience: request.ExperienceReward,
                Strength: 0),
            State: updatedState,
            MissionProgress: missionProgress);
    }

    public async Task<PlayerActionResponse> RestoreEnergyAsync(string playerId, RestoreEnergyRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var existingRestore = await ReadEnergyActionAsync(connection, transaction, actionId);
        if (existingRestore is not null)
        {
            await transaction.CommitAsync();
            var state = await GetStateAsync(normalizedPlayerId);
            var completed = string.Equals(existingRestore.PlayerId, normalizedPlayerId, StringComparison.Ordinal) &&
                existingRestore.EnergyRestored > 0;
            return new PlayerActionResponse(
                Completed: completed,
                Message: completed
                    ? $"Energy restoration already applied. Restored {existingRestore.EnergyRestored} energy."
                    : "Energy restore idempotency key was already used.",
                Rewards: new PlayerRewardsDto(
                    Gold: 0,
                    Experience: 0,
                    Strength: 0,
                    Energy: completed ? existingRestore.EnergyRestored : 0),
                State: state);
        }

        await ApplyEnergyRegenerationAsync(connection, transaction, normalizedPlayerId, now);

        var currentEnergy = 0;
        var maxEnergy = 0;
        await using (var readEnergy = new NpgsqlCommand("""
            SELECT energy, max_energy
            FROM player.progression
            WHERE player_id = @player_id
            FOR UPDATE;
            """, connection, transaction))
        {
            readEnergy.Parameters.AddWithValue("player_id", normalizedPlayerId);
            await using var reader = await readEnergy.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
            {
                throw new InvalidOperationException("Player progression was not initialized.");
            }

            currentEnergy = reader.GetInt32(0);
            maxEnergy = reader.GetInt32(1);
        }

        var energyRestored = Math.Min(request.EnergyAmount, Math.Max(0, maxEnergy - currentEnergy));
        if (energyRestored <= 0)
        {
            await AddEnergyActionAsync(
                connection,
                transaction,
                actionId,
                normalizedPlayerId,
                energyRestored: 0,
                message: "Energy was already full.",
                now);
            await transaction.CommitAsync();
            var state = await GetStateAsync(normalizedPlayerId);
            return new PlayerActionResponse(
                Completed: false,
                Message: "Energy is already full.",
                Rewards: new PlayerRewardsDto(Gold: 0, Experience: 0, Strength: 0, Energy: 0),
                State: state);
        }

        PlayerStateDto updatedState;
        await using (var updateEnergy = new NpgsqlCommand("""
            UPDATE player.progression
            SET energy = LEAST(max_energy, energy + @energy_restored),
                last_energy_regenerated_at = CASE
                    WHEN energy + @energy_restored >= max_energy THEN @updated_at
                    ELSE last_energy_regenerated_at
                END,
                updated_at = @updated_at
            WHERE player_id = @player_id
            RETURNING player_id, level, experience, energy, max_energy, strength, gold,
                      COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                      COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                      updated_at, last_energy_regenerated_at, hospital_cooldown_until;
            """, connection, transaction))
        {
            updateEnergy.Parameters.AddWithValue("player_id", normalizedPlayerId);
            updateEnergy.Parameters.AddWithValue("energy_restored", energyRestored);
            updateEnergy.Parameters.AddWithValue("updated_at", now);
            await using var reader = await updateEnergy.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
            {
                throw new InvalidOperationException("Energy update did not return player state.");
            }

            updatedState = ReadState(reader);
        }

        await AddEnergyActionAsync(
            connection,
            transaction,
            actionId,
            normalizedPlayerId,
            energyRestored,
            request.Message,
            now);
        await transaction.CommitAsync();

        return new PlayerActionResponse(
            Completed: true,
            Message: $"Restored {energyRestored} energy.",
            Rewards: new PlayerRewardsDto(Gold: 0, Experience: 0, Strength: 0, Energy: energyRestored),
            State: updatedState);
    }

    public async Task<PlayerActionResponse> RecoverAtHospitalAsync(string playerId, HospitalRecoveryRequest request)
    {
        var normalizedPlayerId = NormalizePlayerId(playerId);
        var actionId = request.IdempotencyKey.Trim().ToLowerInvariant();
        await EnsureExistsAsync(normalizedPlayerId);

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var existingRecovery = await ReadEnergyActionAsync(connection, transaction, actionId);
        if (existingRecovery is not null)
        {
            await transaction.CommitAsync();
            var state = await GetStateAsync(normalizedPlayerId);
            var completed = string.Equals(existingRecovery.PlayerId, normalizedPlayerId, StringComparison.Ordinal) &&
                existingRecovery.EnergyRestored > 0;
            return new PlayerActionResponse(
                Completed: completed,
                Message: completed
                    ? $"Hospital recovery was already applied. Restored {existingRecovery.EnergyRestored} energy."
                    : "Hospital recovery idempotency key was already used.",
                Rewards: new PlayerRewardsDto(
                    Gold: 0,
                    Experience: 0,
                    Strength: 0,
                    Energy: completed ? existingRecovery.EnergyRestored : 0),
                State: state);
        }

        await ApplyEnergyRegenerationAsync(connection, transaction, normalizedPlayerId, now);

        var currentEnergy = 0;
        var maxEnergy = 0;
        DateTimeOffset? cooldownUntil = null;
        await using (var readState = new NpgsqlCommand("""
            SELECT energy, max_energy, hospital_cooldown_until
            FROM player.progression
            WHERE player_id = @player_id
            FOR UPDATE;
            """, connection, transaction))
        {
            readState.Parameters.AddWithValue("player_id", normalizedPlayerId);
            await using var reader = await readState.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
            {
                throw new InvalidOperationException("Player progression was not initialized.");
            }

            currentEnergy = reader.GetInt32(0);
            maxEnergy = reader.GetInt32(1);
            cooldownUntil = reader.IsDBNull(2) ? null : reader.GetFieldValue<DateTimeOffset>(2);
        }

        if (cooldownUntil is DateTimeOffset activeCooldown && activeCooldown > now)
        {
            await transaction.RollbackAsync();
            var state = await GetStateAsync(normalizedPlayerId);
            return new PlayerActionResponse(
                Completed: false,
                Message: $"Hospital recovery is on cooldown until {activeCooldown:O}.",
                Rewards: PlayerRewardsDto.None,
                State: state);
        }

        var energyRestored = Math.Min(HospitalEnergyRestore, Math.Max(0, maxEnergy - currentEnergy));
        if (energyRestored <= 0)
        {
            await transaction.RollbackAsync();
            var state = await GetStateAsync(normalizedPlayerId);
            return new PlayerActionResponse(
                Completed: false,
                Message: "Energy is already full.",
                Rewards: PlayerRewardsDto.None,
                State: state);
        }

        var nextCooldownUntil = now.Add(HospitalCooldown);
        PlayerStateDto updatedState;
        await using (var updateRecovery = new NpgsqlCommand("""
            UPDATE player.progression
            SET energy = LEAST(max_energy, energy + @energy_restored),
                hospital_cooldown_until = @hospital_cooldown_until,
                last_energy_regenerated_at = CASE
                    WHEN energy + @energy_restored >= max_energy THEN @updated_at
                    ELSE last_energy_regenerated_at
                END,
                updated_at = @updated_at
            WHERE player_id = @player_id
            RETURNING player_id, level, experience, energy, max_energy, strength, gold,
                      COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                      COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                      updated_at, last_energy_regenerated_at, hospital_cooldown_until;
            """, connection, transaction))
        {
            updateRecovery.Parameters.AddWithValue("player_id", normalizedPlayerId);
            updateRecovery.Parameters.AddWithValue("energy_restored", energyRestored);
            updateRecovery.Parameters.AddWithValue("hospital_cooldown_until", nextCooldownUntil);
            updateRecovery.Parameters.AddWithValue("updated_at", now);
            await using var reader = await updateRecovery.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
            {
                throw new InvalidOperationException("Hospital recovery did not return player state.");
            }

            updatedState = ReadState(reader);
        }

        await AddEnergyActionAsync(
            connection,
            transaction,
            actionId,
            normalizedPlayerId,
            energyRestored,
            $"Hospital restored {energyRestored} energy.",
            now);
        await transaction.CommitAsync();

        return new PlayerActionResponse(
            Completed: true,
            Message: $"Hospital restored {energyRestored} energy. Next recovery is available at {nextCooldownUntil:O}.",
            Rewards: new PlayerRewardsDto(Gold: 0, Experience: 0, Strength: 0, Energy: energyRestored),
            State: updatedState);
    }

    public void Dispose()
    {
        _dataSource.Dispose();
    }

    private async Task EnsureExistsAsync(string playerId)
    {
        var now = DateTimeOffset.UtcNow;
        await using var command = _dataSource.CreateCommand("""
            INSERT INTO player.progression (player_id, last_energy_regenerated_at, created_at, updated_at)
            VALUES (@player_id, @last_energy_regenerated_at, @created_at, @updated_at)
            ON CONFLICT (player_id) DO NOTHING;
            """);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("last_energy_regenerated_at", now);
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private async Task ApplyEnergyRegenerationAsync(string playerId)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await ApplyEnergyRegenerationAsync(connection, transaction, playerId, DateTimeOffset.UtcNow);
        await transaction.CommitAsync();
    }

    private static async Task ApplyEnergyRegenerationAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        DateTimeOffset now)
    {
        var energy = 0;
        var maxEnergy = 0;
        var lastRegeneratedAt = now;
        await using (var readEnergy = new NpgsqlCommand("""
            SELECT energy, max_energy, last_energy_regenerated_at
            FROM player.progression
            WHERE player_id = @player_id
            FOR UPDATE;
            """, connection, transaction))
        {
            readEnergy.Parameters.AddWithValue("player_id", playerId);
            await using var reader = await readEnergy.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
            {
                throw new InvalidOperationException("Player progression was not initialized.");
            }

            energy = reader.GetInt32(0);
            maxEnergy = reader.GetInt32(1);
            lastRegeneratedAt = reader.GetFieldValue<DateTimeOffset>(2);
        }

        if (maxEnergy <= 0)
        {
            return;
        }

        var nextLastRegeneratedAt = lastRegeneratedAt;
        var nextEnergy = energy;
        if (energy >= maxEnergy)
        {
            nextLastRegeneratedAt = now;
        }
        else
        {
            var elapsed = now - lastRegeneratedAt;
            if (elapsed < EnergyRegenerationInterval)
            {
                return;
            }

            var intervalsElapsed = (int)Math.Floor(elapsed.TotalSeconds / EnergyRegenerationInterval.TotalSeconds);
            var energyToRestore = intervalsElapsed * EnergyRegenerationAmount;
            nextEnergy = Math.Min(maxEnergy, energy + energyToRestore);
            nextLastRegeneratedAt = nextEnergy >= maxEnergy
                ? now
                : lastRegeneratedAt.AddSeconds(intervalsElapsed * EnergyRegenerationInterval.TotalSeconds);
        }

        if (nextEnergy == energy && nextLastRegeneratedAt == lastRegeneratedAt)
        {
            return;
        }

        await using var updateEnergy = new NpgsqlCommand("""
            UPDATE player.progression
            SET energy = @energy,
                last_energy_regenerated_at = @last_energy_regenerated_at,
                updated_at = @updated_at
            WHERE player_id = @player_id;
            """, connection, transaction);
        updateEnergy.Parameters.AddWithValue("player_id", playerId);
        updateEnergy.Parameters.AddWithValue("energy", nextEnergy);
        updateEnergy.Parameters.AddWithValue("last_energy_regenerated_at", nextLastRegeneratedAt);
        updateEnergy.Parameters.AddWithValue("updated_at", now);
        await updateEnergy.ExecuteNonQueryAsync();
    }

    private async Task<PlayerStateDto?> LoadStateAsync(string playerId)
    {
        await using var command = _dataSource.CreateCommand("""
            SELECT player_id, level, experience, energy, max_energy, strength, gold,
                   COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                   COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                   updated_at, last_energy_regenerated_at, hospital_cooldown_until
            FROM player.progression
            WHERE player_id = @player_id;
            """);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadState(reader) : null;
    }

    private static async Task<PlayerStateDto?> LoadStateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, level, experience, energy, max_energy, strength, gold,
                   COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                   COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                   updated_at, last_energy_regenerated_at, hospital_cooldown_until
            FROM player.progression
            WHERE player_id = @player_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadState(reader) : null;
    }

    private static async Task EnsureDailyObjectiveProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        DateOnly resetDate,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.daily_objective_progress (
                player_id, objective_id, reset_date, current_count, updated_at
            )
            SELECT @player_id, objective_id, @reset_date, 0, @updated_at
            FROM player.daily_objective_catalog
            WHERE enabled
            ON CONFLICT (player_id, objective_id, reset_date) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("reset_date", resetDate);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<DailyObjectiveDto>> ReadDailyObjectivesAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        DateOnly resetDate)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.objective_id, c.action_type, c.title, c.description,
                   p.current_count, c.target_count,
                   c.reward_gold, c.reward_experience, c.reward_strength, c.reward_energy,
                   p.completed_at, p.claimed_at, p.reset_date, c.display_order
            FROM player.daily_objective_catalog c
            JOIN player.daily_objective_progress p
              ON p.objective_id = c.objective_id
            WHERE p.player_id = @player_id
              AND p.reset_date = @reset_date
              AND c.enabled
            ORDER BY c.display_order, c.objective_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("reset_date", resetDate);

        var objectives = new List<DailyObjectiveDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            objectives.Add(ReadDailyObjective(reader));
        }

        return objectives;
    }

    private static async Task<DailyObjectiveDto?> ReadDailyObjectiveForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string objectiveId,
        DateOnly resetDate)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.objective_id, c.action_type, c.title, c.description,
                   p.current_count, c.target_count,
                   c.reward_gold, c.reward_experience, c.reward_strength, c.reward_energy,
                   p.completed_at, p.claimed_at, p.reset_date, c.display_order
            FROM player.daily_objective_catalog c
            JOIN player.daily_objective_progress p
              ON p.objective_id = c.objective_id
            WHERE p.player_id = @player_id
              AND p.objective_id = @objective_id
              AND p.reset_date = @reset_date
              AND c.enabled
            FOR UPDATE OF p;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("objective_id", objectiveId);
        command.Parameters.AddWithValue("reset_date", resetDate);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadDailyObjective(reader) : null;
    }

    private static async Task<string?> ReadDailyObjectiveEventPlayerIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id
            FROM player.daily_objective_events
            WHERE event_id = @event_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        var result = await command.ExecuteScalarAsync();
        return result as string;
    }

    private static async Task AddDailyObjectiveEventAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId,
        string playerId,
        string actionType,
        int quantity,
        DateOnly resetDate,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.daily_objective_events (
                event_id, player_id, action_type, quantity, reset_date, created_at
            )
            VALUES (
                @event_id, @player_id, @action_type, @quantity, @reset_date, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("reset_date", resetDate);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task IncrementDailyObjectiveProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        int quantity,
        DateOnly resetDate,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.daily_objective_progress p
            SET current_count = LEAST(c.target_count, p.current_count + @quantity),
                completed_at = CASE
                    WHEN p.completed_at IS NULL AND p.current_count + @quantity >= c.target_count THEN @completed_at
                    ELSE p.completed_at
                END,
                updated_at = @updated_at
            FROM player.daily_objective_catalog c
            WHERE p.objective_id = c.objective_id
              AND p.player_id = @player_id
              AND p.reset_date = @reset_date
              AND c.action_type = @action_type
              AND c.enabled
              AND p.claimed_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("reset_date", resetDate);
        command.Parameters.AddWithValue("completed_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<DailyObjectiveClaimRecord?> ReadDailyObjectiveClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string claimId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, objective_id, reset_date, gold_awarded, experience_awarded,
                   strength_awarded, energy_awarded, claimed_at
            FROM player.daily_objective_claims
            WHERE claim_id = @claim_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("claim_id", claimId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadDailyObjectiveClaim(reader) : null;
    }

    private static async Task<DailyObjectiveClaimRecord?> ReadDailyObjectiveClaimByObjectiveAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string objectiveId,
        DateOnly resetDate)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, objective_id, reset_date, gold_awarded, experience_awarded,
                   strength_awarded, energy_awarded, claimed_at
            FROM player.daily_objective_claims
            WHERE player_id = @player_id
              AND objective_id = @objective_id
              AND reset_date = @reset_date;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("objective_id", objectiveId);
        command.Parameters.AddWithValue("reset_date", resetDate);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadDailyObjectiveClaim(reader) : null;
    }

    private static async Task MarkDailyObjectiveClaimedAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string objectiveId,
        DateOnly resetDate,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.daily_objective_progress
            SET claimed_at = @claimed_at,
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND objective_id = @objective_id
              AND reset_date = @reset_date
              AND claimed_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("objective_id", objectiveId);
        command.Parameters.AddWithValue("reset_date", resetDate);
        command.Parameters.AddWithValue("claimed_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task AddDailyObjectiveClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string claimId,
        string playerId,
        string objectiveId,
        DateOnly resetDate,
        PlayerRewardsDto rewards,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.daily_objective_claims (
                claim_id, player_id, objective_id, reset_date, gold_awarded,
                experience_awarded, strength_awarded, energy_awarded, claimed_at
            )
            VALUES (
                @claim_id, @player_id, @objective_id, @reset_date, @gold_awarded,
                @experience_awarded, @strength_awarded, @energy_awarded, @claimed_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("claim_id", claimId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("objective_id", objectiveId);
        command.Parameters.AddWithValue("reset_date", resetDate);
        command.Parameters.AddWithValue("gold_awarded", rewards.Gold);
        command.Parameters.AddWithValue("experience_awarded", rewards.Experience);
        command.Parameters.AddWithValue("strength_awarded", rewards.Strength);
        command.Parameters.AddWithValue("energy_awarded", rewards.Energy);
        command.Parameters.AddWithValue("claimed_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<PlayerStateDto> ApplyDailyObjectivePlayerRewardAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        PlayerRewardsDto rewards,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.progression
            SET experience = experience + @experience_reward,
                strength = strength + @strength_reward,
                energy = LEAST(max_energy, energy + @energy_reward),
                level = GREATEST(level, floor((experience + @experience_reward)::numeric / 100)::integer + 1),
                updated_at = @updated_at
            WHERE player_id = @player_id
            RETURNING player_id, level, experience, energy, max_energy, strength, gold,
                      COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                      COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                      updated_at, last_energy_regenerated_at, hospital_cooldown_until;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("experience_reward", rewards.Experience);
        command.Parameters.AddWithValue("strength_reward", rewards.Strength);
        command.Parameters.AddWithValue("energy_reward", rewards.Energy);
        command.Parameters.AddWithValue("updated_at", now);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException("Daily objective reward did not return player state.");
        }

        return ReadState(reader);
    }

    private static async Task EnsureOnboardingQuestProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.onboarding_quest_progress (
                player_id, quest_id, current_count, updated_at
            )
            SELECT @player_id, quest_id, 0, @updated_at
            FROM player.onboarding_quest_catalog
            WHERE enabled
            ON CONFLICT (player_id, quest_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<OnboardingQuestDto>> ReadOnboardingQuestsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.quest_id, c.action_type, c.title, c.description, c.guidance, c.route,
                   p.current_count, c.target_count,
                   c.reward_gold, c.reward_experience, c.reward_strength, c.reward_energy,
                   p.completed_at, p.claimed_at, p.skipped_at, c.display_order
            FROM player.onboarding_quest_catalog c
            JOIN player.onboarding_quest_progress p
              ON p.quest_id = c.quest_id
            WHERE p.player_id = @player_id
              AND c.enabled
            ORDER BY c.display_order, c.quest_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        var quests = new List<OnboardingQuestDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            quests.Add(ReadOnboardingQuest(reader));
        }

        return quests;
    }

    private static async Task<OnboardingQuestDto?> ReadOnboardingQuestForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string questId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.quest_id, c.action_type, c.title, c.description, c.guidance, c.route,
                   p.current_count, c.target_count,
                   c.reward_gold, c.reward_experience, c.reward_strength, c.reward_energy,
                   p.completed_at, p.claimed_at, p.skipped_at, c.display_order
            FROM player.onboarding_quest_catalog c
            JOIN player.onboarding_quest_progress p
              ON p.quest_id = c.quest_id
            WHERE p.player_id = @player_id
              AND p.quest_id = @quest_id
              AND c.enabled
            FOR UPDATE OF p;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("quest_id", questId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadOnboardingQuest(reader) : null;
    }

    private static async Task<string?> ReadOnboardingQuestEventPlayerIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id
            FROM player.onboarding_quest_events
            WHERE event_id = @event_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        var result = await command.ExecuteScalarAsync();
        return result as string;
    }

    private static async Task AddOnboardingQuestEventAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId,
        string playerId,
        string actionType,
        int quantity,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.onboarding_quest_events (
                event_id, player_id, action_type, quantity, created_at
            )
            VALUES (
                @event_id, @player_id, @action_type, @quantity, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task IncrementOnboardingQuestProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        int quantity,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.onboarding_quest_progress p
            SET current_count = LEAST(c.target_count, p.current_count + @quantity),
                completed_at = CASE
                    WHEN p.completed_at IS NULL AND p.current_count + @quantity >= c.target_count THEN @completed_at
                    ELSE p.completed_at
                END,
                updated_at = @updated_at
            FROM player.onboarding_quest_catalog c
            WHERE p.quest_id = c.quest_id
              AND p.player_id = @player_id
              AND c.action_type = @action_type
              AND c.enabled
              AND p.claimed_at IS NULL
              AND p.skipped_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("completed_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<OnboardingQuestClaimRecord?> ReadOnboardingQuestClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string claimId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, quest_id, gold_awarded, experience_awarded,
                   strength_awarded, energy_awarded, claimed_at
            FROM player.onboarding_quest_claims
            WHERE claim_id = @claim_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("claim_id", claimId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadOnboardingQuestClaim(reader) : null;
    }

    private static async Task<OnboardingQuestClaimRecord?> ReadOnboardingQuestClaimByQuestAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string questId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, quest_id, gold_awarded, experience_awarded,
                   strength_awarded, energy_awarded, claimed_at
            FROM player.onboarding_quest_claims
            WHERE player_id = @player_id
              AND quest_id = @quest_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("quest_id", questId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadOnboardingQuestClaim(reader) : null;
    }

    private static async Task MarkOnboardingQuestClaimedAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string questId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.onboarding_quest_progress
            SET claimed_at = @claimed_at,
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND quest_id = @quest_id
              AND claimed_at IS NULL
              AND skipped_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("quest_id", questId);
        command.Parameters.AddWithValue("claimed_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task MarkOnboardingQuestSkippedAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string questId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.onboarding_quest_progress
            SET skipped_at = @skipped_at,
                completed_at = COALESCE(completed_at, @skipped_at),
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND quest_id = @quest_id
              AND claimed_at IS NULL
              AND skipped_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("quest_id", questId);
        command.Parameters.AddWithValue("skipped_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task AddOnboardingQuestClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string claimId,
        string playerId,
        string questId,
        PlayerRewardsDto rewards,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.onboarding_quest_claims (
                claim_id, player_id, quest_id, gold_awarded,
                experience_awarded, strength_awarded, energy_awarded, claimed_at
            )
            VALUES (
                @claim_id, @player_id, @quest_id, @gold_awarded,
                @experience_awarded, @strength_awarded, @energy_awarded, @claimed_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("claim_id", claimId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("quest_id", questId);
        command.Parameters.AddWithValue("gold_awarded", rewards.Gold);
        command.Parameters.AddWithValue("experience_awarded", rewards.Experience);
        command.Parameters.AddWithValue("strength_awarded", rewards.Strength);
        command.Parameters.AddWithValue("energy_awarded", rewards.Energy);
        command.Parameters.AddWithValue("claimed_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<PlayerStateDto> ApplyOnboardingQuestPlayerRewardAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        PlayerRewardsDto rewards,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.progression
            SET experience = experience + @experience_reward,
                strength = strength + @strength_reward,
                energy = LEAST(max_energy, energy + @energy_reward),
                level = GREATEST(level, floor((experience + @experience_reward)::numeric / 100)::integer + 1),
                updated_at = @updated_at
            WHERE player_id = @player_id
            RETURNING player_id, level, experience, energy, max_energy, strength, gold,
                      COALESCE(last_work_date = CURRENT_DATE, false) AS has_worked_today,
                      COALESCE(last_train_date = CURRENT_DATE, false) AS has_trained_today,
                      updated_at, last_energy_regenerated_at, hospital_cooldown_until;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("experience_reward", rewards.Experience);
        command.Parameters.AddWithValue("strength_reward", rewards.Strength);
        command.Parameters.AddWithValue("energy_reward", rewards.Energy);
        command.Parameters.AddWithValue("updated_at", now);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException("Onboarding reward did not return player state.");
        }

        return ReadState(reader);
    }

    private static async Task EnsureAchievementProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.achievement_progress (
                player_id, achievement_id, current_count, updated_at
            )
            SELECT @player_id, achievement_id, 0, @updated_at
            FROM player.achievement_catalog
            WHERE enabled
            ON CONFLICT (player_id, achievement_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<AchievementProgressDto>> ReadAchievementsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.achievement_id, c.action_type, c.title, c.description, c.category,
                   c.medal_name, c.medal_rarity, c.points,
                   p.current_count, c.target_count, p.unlocked_at, p.claimed_at, c.display_order
            FROM player.achievement_catalog c
            JOIN player.achievement_progress p
              ON p.achievement_id = c.achievement_id
            WHERE p.player_id = @player_id
              AND c.enabled
            ORDER BY c.display_order, c.achievement_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        var achievements = new List<AchievementProgressDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            achievements.Add(ReadAchievementProgress(reader));
        }

        return achievements;
    }

    private static async Task<AchievementProgressDto?> ReadAchievementForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string achievementId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT c.achievement_id, c.action_type, c.title, c.description, c.category,
                   c.medal_name, c.medal_rarity, c.points,
                   p.current_count, c.target_count, p.unlocked_at, p.claimed_at, c.display_order
            FROM player.achievement_catalog c
            JOIN player.achievement_progress p
              ON p.achievement_id = c.achievement_id
            WHERE p.player_id = @player_id
              AND p.achievement_id = @achievement_id
              AND c.enabled
            FOR UPDATE OF p;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("achievement_id", achievementId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadAchievementProgress(reader) : null;
    }

    private static async Task<List<AchievementUnlockDto>> ReadRecentAchievementUnlocksAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT a.achievement_id, c.title, c.category, c.medal_name, c.medal_rarity,
                   a.points_awarded, a.awarded_at, p.claimed_at IS NOT NULL AS claimed
            FROM player.achievement_awards a
            JOIN player.achievement_catalog c
              ON c.achievement_id = a.achievement_id
            JOIN player.achievement_progress p
              ON p.player_id = a.player_id
             AND p.achievement_id = a.achievement_id
            WHERE a.player_id = @player_id
              AND c.enabled
            ORDER BY a.awarded_at DESC, c.display_order, a.achievement_id
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("limit", Math.Clamp(limit, 1, 50));

        var unlocks = new List<AchievementUnlockDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            unlocks.Add(new AchievementUnlockDto(
                AchievementId: reader.GetString(0),
                Title: reader.GetString(1),
                Category: reader.GetString(2),
                MedalName: reader.GetString(3),
                MedalRarity: reader.GetString(4),
                Points: reader.GetInt32(5),
                AwardedAt: reader.GetFieldValue<DateTimeOffset>(6),
                Claimed: reader.GetBoolean(7)));
        }

        return unlocks;
    }

    private static async Task<string?> ReadAchievementEventPlayerIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id
            FROM player.achievement_events
            WHERE event_id = @event_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        var result = await command.ExecuteScalarAsync();
        return result as string;
    }

    private static async Task AddAchievementEventAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string eventId,
        string playerId,
        string actionType,
        int quantity,
        string? relatedId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.achievement_events (
                event_id, player_id, action_type, quantity, related_id, created_at
            )
            VALUES (
                @event_id, @player_id, @action_type, @quantity, @related_id, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("event_id", eventId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("related_id", (object?)relatedId ?? DBNull.Value);
        command.Parameters.AddWithValue("created_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<List<AchievementProgressDto>> IncrementAchievementProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string actionType,
        int quantity,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.achievement_progress p
            SET current_count = LEAST(c.target_count, p.current_count + @quantity),
                unlocked_at = CASE
                    WHEN p.unlocked_at IS NULL AND p.current_count + @quantity >= c.target_count THEN @unlocked_at
                    ELSE p.unlocked_at
                END,
                updated_at = @updated_at
            FROM player.achievement_catalog c
            WHERE p.achievement_id = c.achievement_id
              AND p.player_id = @player_id
              AND c.action_type = @action_type
              AND c.enabled
              AND (p.unlocked_at IS NULL OR p.current_count < c.target_count)
            RETURNING c.achievement_id, c.action_type, c.title, c.description, c.category,
                      c.medal_name, c.medal_rarity, c.points,
                      p.current_count, c.target_count, p.unlocked_at, p.claimed_at, c.display_order,
                      COALESCE(p.unlocked_at = @unlocked_at, FALSE) AS newly_unlocked;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("action_type", actionType);
        command.Parameters.AddWithValue("quantity", quantity);
        command.Parameters.AddWithValue("unlocked_at", now);
        command.Parameters.AddWithValue("updated_at", now);

        var newlyUnlocked = new List<AchievementProgressDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var achievement = ReadAchievementProgress(reader);
            if (reader.GetBoolean(13))
            {
                newlyUnlocked.Add(achievement);
            }
        }

        return newlyUnlocked;
    }

    private static async Task AddAchievementAwardAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string awardId,
        string playerId,
        AchievementProgressDto achievement,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.achievement_awards (
                award_id, player_id, achievement_id, points_awarded, medal_rarity, awarded_at
            )
            VALUES (
                @award_id, @player_id, @achievement_id, @points_awarded, @medal_rarity, @awarded_at
            )
            ON CONFLICT (player_id, achievement_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("award_id", awardId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("achievement_id", achievement.AchievementId);
        command.Parameters.AddWithValue("points_awarded", achievement.Points);
        command.Parameters.AddWithValue("medal_rarity", achievement.MedalRarity);
        command.Parameters.AddWithValue("awarded_at", achievement.UnlockedAt ?? now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<AchievementClaimRecord?> ReadAchievementClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string claimId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, achievement_id, claimed_at
            FROM player.achievement_claims
            WHERE claim_id = @claim_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("claim_id", claimId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new AchievementClaimRecord(
                PlayerId: reader.GetString(0),
                AchievementId: reader.GetString(1),
                ClaimedAt: reader.GetFieldValue<DateTimeOffset>(2))
            : null;
    }

    private static async Task MarkAchievementClaimedAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string achievementId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            UPDATE player.achievement_progress
            SET claimed_at = @claimed_at,
                updated_at = @updated_at
            WHERE player_id = @player_id
              AND achievement_id = @achievement_id
              AND unlocked_at IS NOT NULL
              AND claimed_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("achievement_id", achievementId);
        command.Parameters.AddWithValue("claimed_at", now);
        command.Parameters.AddWithValue("updated_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task AddAchievementClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string claimId,
        string playerId,
        string achievementId,
        DateTimeOffset now)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.achievement_claims (
                claim_id, player_id, achievement_id, claimed_at
            )
            VALUES (
                @claim_id, @player_id, @achievement_id, @claimed_at
            )
            ON CONFLICT (player_id, achievement_id) DO NOTHING;
            """, connection, transaction);
        command.Parameters.AddWithValue("claim_id", claimId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("achievement_id", achievementId);
        command.Parameters.AddWithValue("claimed_at", now);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<int> CountRankedPlayersAsync(NpgsqlConnection connection)
    {
        await using var command = new NpgsqlCommand("SELECT count(*)::int FROM player.progression;", connection);
        var result = await command.ExecuteScalarAsync();
        return result is int count ? count : Convert.ToInt32(result);
    }

    private static async Task<List<PlayerRankingEntryDto>> ReadRankingsAsync(
        NpgsqlConnection connection,
        string sortBy,
        int limit)
    {
        await using var command = new NpgsqlCommand($"""
            WITH ranked AS (
                SELECT row_number() OVER (ORDER BY {RankingOrderBy(sortBy)})::integer AS rank,
                       player_id, level, experience, strength, energy, max_energy, updated_at
                FROM player.progression
            )
            SELECT rank, player_id, level, experience, strength, energy, max_energy, updated_at
            FROM ranked
            ORDER BY rank
            LIMIT @limit;
            """, connection);
        command.Parameters.AddWithValue("limit", limit);

        var entries = new List<PlayerRankingEntryDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            entries.Add(ReadRankingEntry(reader));
        }

        return entries;
    }

    private static async Task<PlayerRankingEntryDto?> ReadRankingAsync(
        NpgsqlConnection connection,
        string playerId,
        string sortBy)
    {
        await using var command = new NpgsqlCommand($"""
            WITH ranked AS (
                SELECT row_number() OVER (ORDER BY {RankingOrderBy(sortBy)})::integer AS rank,
                       player_id, level, experience, strength, energy, max_energy, updated_at
                FROM player.progression
            )
            SELECT rank, player_id, level, experience, strength, energy, max_energy, updated_at
            FROM ranked
            WHERE player_id = @player_id;
            """, connection);
        command.Parameters.AddWithValue("player_id", playerId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadRankingEntry(reader) : null;
    }

    private static async Task<List<MissionProgressDto>> ReadMissionProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string playerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT mission_id, attempts, wins, losses, total_rounds, last_won, last_result,
                   last_attempted_at, cooldown_until, updated_at
            FROM player.mission_progress
            WHERE player_id = @player_id
            ORDER BY mission_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);

        var missions = new List<MissionProgressDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            missions.Add(ReadMissionProgress(reader));
        }

        return missions;
    }

    private static async Task<CombatAttemptRecord?> ReadCombatAttemptAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, mission_id, won, energy_cost, gold_reward, experience_reward, rounds_completed, message
            FROM player.combat_attempts
            WHERE action_id = @action_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("action_id", actionId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new CombatAttemptRecord(
                PlayerId: reader.GetString(0),
                MissionId: reader.GetString(1),
                Won: reader.GetBoolean(2),
                EnergyCost: reader.GetInt32(3),
                GoldReward: reader.GetInt32(4),
                ExperienceReward: reader.GetInt32(5),
                RoundsCompleted: reader.GetInt32(6),
                Message: reader.GetString(7))
            : null;
    }

    private static async Task<MissionProgressDto> UpsertMissionProgressAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string playerId,
        string missionId,
        bool won,
        int roundsCompleted,
        string message,
        DateTimeOffset now)
    {
        var cooldownUntil = now.Add(MissionCooldown);
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.mission_progress (
                player_id, mission_id, attempts, wins, losses, total_rounds, last_won, last_result,
                last_attempted_at, cooldown_until, updated_at
            )
            VALUES (
                @player_id, @mission_id, 1, @wins, @losses, @rounds_completed, @won, @last_result,
                @last_attempted_at, @cooldown_until, @updated_at
            )
            ON CONFLICT (player_id, mission_id) DO UPDATE
            SET attempts = player.mission_progress.attempts + 1,
                wins = player.mission_progress.wins + @wins,
                losses = player.mission_progress.losses + @losses,
                total_rounds = player.mission_progress.total_rounds + @rounds_completed,
                last_won = @won,
                last_result = @last_result,
                last_attempted_at = @last_attempted_at,
                cooldown_until = @cooldown_until,
                updated_at = @updated_at
            RETURNING mission_id, attempts, wins, losses, total_rounds, last_won, last_result,
                      last_attempted_at, cooldown_until, updated_at;
            """, connection, transaction);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("mission_id", missionId);
        command.Parameters.AddWithValue("wins", won ? 1 : 0);
        command.Parameters.AddWithValue("losses", won ? 0 : 1);
        command.Parameters.AddWithValue("rounds_completed", roundsCompleted);
        command.Parameters.AddWithValue("won", won);
        command.Parameters.AddWithValue("last_result", message);
        command.Parameters.AddWithValue("last_attempted_at", now);
        command.Parameters.AddWithValue("cooldown_until", cooldownUntil);
        command.Parameters.AddWithValue("updated_at", now);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException("Mission progress update did not return a row.");
        }

        return ReadMissionProgress(reader);
    }

    private static async Task AddCombatAttemptAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actionId,
        string playerId,
        string missionId,
        bool won,
        int energyCost,
        int goldReward,
        int experienceReward,
        int roundsCompleted,
        string message,
        DateTimeOffset createdAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.combat_attempts (
                action_id, player_id, mission_id, won, energy_cost, gold_reward,
                experience_reward, rounds_completed, message, created_at
            )
            VALUES (
                @action_id, @player_id, @mission_id, @won, @energy_cost, @gold_reward,
                @experience_reward, @rounds_completed, @message, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("action_id", actionId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("mission_id", missionId);
        command.Parameters.AddWithValue("won", won);
        command.Parameters.AddWithValue("energy_cost", energyCost);
        command.Parameters.AddWithValue("gold_reward", goldReward);
        command.Parameters.AddWithValue("experience_reward", experienceReward);
        command.Parameters.AddWithValue("rounds_completed", roundsCompleted);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<EnergyActionRecord?> ReadEnergyActionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actionId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT player_id, energy_restored, message
            FROM player.energy_actions
            WHERE action_id = @action_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("action_id", actionId);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? new EnergyActionRecord(
                PlayerId: reader.GetString(0),
                EnergyRestored: reader.GetInt32(1),
                Message: reader.GetString(2))
            : null;
    }

    private static async Task AddEnergyActionAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actionId,
        string playerId,
        int energyRestored,
        string message,
        DateTimeOffset createdAt)
    {
        await using var command = new NpgsqlCommand("""
            INSERT INTO player.energy_actions (
                action_id, player_id, energy_restored, message, created_at
            )
            VALUES (
                @action_id, @player_id, @energy_restored, @message, @created_at
            );
            """, connection, transaction);
        command.Parameters.AddWithValue("action_id", actionId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("energy_restored", energyRestored);
        command.Parameters.AddWithValue("message", message);
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync();
    }

    private static PlayerStateDto ReadState(NpgsqlDataReader reader)
    {
        var experience = reader.GetInt32(2);
        var level = reader.GetInt32(1);
        var energy = reader.GetInt32(3);
        var maxEnergy = reader.GetInt32(4);
        var experienceToNextLevel = Math.Max(0, (level * 100) - experience);
        var lastEnergyRegeneratedAt = reader.GetFieldValue<DateTimeOffset>(10);
        DateTimeOffset? hospitalCooldownUntil = reader.IsDBNull(11)
            ? null
            : reader.GetFieldValue<DateTimeOffset>(11);
        if (hospitalCooldownUntil <= DateTimeOffset.UtcNow)
        {
            hospitalCooldownUntil = null;
        }

        return new PlayerStateDto(
            PlayerId: reader.GetString(0),
            Level: level,
            Experience: experience,
            ExperienceToNextLevel: experienceToNextLevel,
            Energy: energy,
            MaxEnergy: maxEnergy,
            Strength: reader.GetInt32(5),
            Gold: reader.GetInt32(6),
            HasWorkedToday: reader.GetBoolean(7),
            HasTrainedToday: reader.GetBoolean(8),
            NextResetAt: NextDailyResetUtc(),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9),
            LastEnergyRegeneratedAt: lastEnergyRegeneratedAt,
            NextEnergyRegenAt: energy >= maxEnergy
                ? null
                : lastEnergyRegeneratedAt.Add(EnergyRegenerationInterval),
            EnergyRegenSeconds: (int)EnergyRegenerationInterval.TotalSeconds,
            EnergyRegenAmount: EnergyRegenerationAmount,
            HospitalCooldownUntil: hospitalCooldownUntil,
            HospitalEnergyRestore: HospitalEnergyRestore,
            HospitalGoldCost: HospitalGoldCost);
    }

    private static MissionProgressDto ReadMissionProgress(NpgsqlDataReader reader)
    {
        return new MissionProgressDto(
            MissionId: reader.GetString(0),
            Attempts: reader.GetInt32(1),
            Wins: reader.GetInt32(2),
            Losses: reader.GetInt32(3),
            TotalRounds: reader.GetInt32(4),
            LastWon: reader.GetBoolean(5),
            LastResult: reader.GetString(6),
            LastAttemptedAt: reader.IsDBNull(7) ? null : reader.GetFieldValue<DateTimeOffset>(7),
            CooldownUntil: reader.IsDBNull(8) ? null : reader.GetFieldValue<DateTimeOffset>(8),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static DailyObjectiveDto ReadDailyObjective(NpgsqlDataReader reader)
    {
        var currentCount = reader.GetInt32(4);
        var targetCount = reader.GetInt32(5);
        DateTimeOffset? completedAt = reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10);
        DateTimeOffset? claimedAt = reader.IsDBNull(11) ? null : reader.GetFieldValue<DateTimeOffset>(11);
        var resetDate = reader.GetFieldValue<DateOnly>(12);
        return new DailyObjectiveDto(
            ObjectiveId: reader.GetString(0),
            ActionType: reader.GetString(1),
            Title: reader.GetString(2),
            Description: reader.GetString(3),
            CurrentCount: currentCount,
            TargetCount: targetCount,
            Rewards: new PlayerRewardsDto(
                Gold: reader.GetInt32(6),
                Experience: reader.GetInt32(7),
                Strength: reader.GetInt32(8),
                Energy: reader.GetInt32(9)),
            Completed: completedAt is not null || currentCount >= targetCount,
            Claimed: claimedAt is not null,
            CompletedAt: completedAt,
            ClaimedAt: claimedAt,
            ResetDate: resetDate,
            ResetAt: ResetAt(resetDate),
            DisplayOrder: reader.GetInt32(13));
    }

    private static DailyObjectiveClaimRecord ReadDailyObjectiveClaim(NpgsqlDataReader reader)
    {
        return new DailyObjectiveClaimRecord(
            PlayerId: reader.GetString(0),
            ObjectiveId: reader.GetString(1),
            ResetDate: reader.GetFieldValue<DateOnly>(2),
            GoldAwarded: reader.GetInt32(3),
            ExperienceAwarded: reader.GetInt32(4),
            StrengthAwarded: reader.GetInt32(5),
            EnergyAwarded: reader.GetInt32(6),
            ClaimedAt: reader.GetFieldValue<DateTimeOffset>(7));
    }

    private static OnboardingQuestDto ReadOnboardingQuest(NpgsqlDataReader reader)
    {
        var currentCount = reader.GetInt32(6);
        var targetCount = reader.GetInt32(7);
        DateTimeOffset? completedAt = reader.IsDBNull(12) ? null : reader.GetFieldValue<DateTimeOffset>(12);
        DateTimeOffset? claimedAt = reader.IsDBNull(13) ? null : reader.GetFieldValue<DateTimeOffset>(13);
        DateTimeOffset? skippedAt = reader.IsDBNull(14) ? null : reader.GetFieldValue<DateTimeOffset>(14);
        return new OnboardingQuestDto(
            QuestId: reader.GetString(0),
            ActionType: reader.GetString(1),
            Title: reader.GetString(2),
            Description: reader.GetString(3),
            Guidance: reader.GetString(4),
            Route: reader.IsDBNull(5) ? null : reader.GetString(5),
            CurrentCount: currentCount,
            TargetCount: targetCount,
            Rewards: new PlayerRewardsDto(
                Gold: reader.GetInt32(8),
                Experience: reader.GetInt32(9),
                Strength: reader.GetInt32(10),
                Energy: reader.GetInt32(11)),
            Completed: completedAt is not null || currentCount >= targetCount,
            Claimed: claimedAt is not null,
            Skipped: skippedAt is not null,
            CompletedAt: completedAt,
            ClaimedAt: claimedAt,
            SkippedAt: skippedAt,
            DisplayOrder: reader.GetInt32(15));
    }

    private static OnboardingQuestClaimRecord ReadOnboardingQuestClaim(NpgsqlDataReader reader)
    {
        return new OnboardingQuestClaimRecord(
            PlayerId: reader.GetString(0),
            QuestId: reader.GetString(1),
            GoldAwarded: reader.GetInt32(2),
            ExperienceAwarded: reader.GetInt32(3),
            StrengthAwarded: reader.GetInt32(4),
            EnergyAwarded: reader.GetInt32(5),
            ClaimedAt: reader.GetFieldValue<DateTimeOffset>(6));
    }

    private static AchievementProgressDto ReadAchievementProgress(NpgsqlDataReader reader)
    {
        var currentCount = reader.GetInt32(8);
        var targetCount = reader.GetInt32(9);
        DateTimeOffset? unlockedAt = reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10);
        DateTimeOffset? claimedAt = reader.IsDBNull(11) ? null : reader.GetFieldValue<DateTimeOffset>(11);
        return new AchievementProgressDto(
            AchievementId: reader.GetString(0),
            ActionType: reader.GetString(1),
            Title: reader.GetString(2),
            Description: reader.GetString(3),
            Category: reader.GetString(4),
            MedalName: reader.GetString(5),
            MedalRarity: reader.GetString(6),
            Points: reader.GetInt32(7),
            CurrentCount: currentCount,
            TargetCount: targetCount,
            Unlocked: unlockedAt is not null || currentCount >= targetCount,
            Claimed: claimedAt is not null,
            UnlockedAt: unlockedAt,
            ClaimedAt: claimedAt,
            DisplayOrder: reader.GetInt32(12));
    }

    private static OnboardingQuestlineResponse BuildOnboardingQuestlineResponse(
        string playerId,
        IReadOnlyList<OnboardingQuestDto> quests,
        DateTimeOffset updatedAt)
    {
        var completedCount = quests.Count(quest => quest.Completed || quest.Skipped);
        var claimedCount = quests.Count(quest => quest.Claimed || quest.Skipped);
        var totalCount = quests.Count;
        var currentQuest = quests.FirstOrDefault(quest => !quest.Claimed && !quest.Skipped);
        var status = totalCount > 0 && claimedCount >= totalCount ? "completed" : "in_progress";
        var completionPercent = totalCount == 0
            ? 100
            : (int)Math.Floor((completedCount * 100.0) / totalCount);

        return new OnboardingQuestlineResponse(
            PlayerId: playerId,
            Status: status,
            CurrentQuest: currentQuest,
            Quests: quests.ToArray(),
            CompletedCount: completedCount,
            TotalCount: totalCount,
            CompletionPercent: completionPercent,
            UpdatedAt: updatedAt);
    }

    private static AchievementsSummary BuildAchievementsSummary(
        string playerId,
        IReadOnlyList<AchievementProgressDto> achievements,
        IReadOnlyList<AchievementUnlockDto> recentUnlocks,
        DateTimeOffset updatedAt)
    {
        var totalAvailable = achievements.Count;
        var totalUnlocked = achievements.Count(achievement => achievement.Unlocked);
        var totalPoints = achievements
            .Where(achievement => achievement.Unlocked)
            .Sum(achievement => achievement.Points);
        var unclaimedCount = achievements.Count(achievement => achievement.Unlocked && !achievement.Claimed);

        return new AchievementsSummary(
            PlayerId: playerId,
            Achievements: achievements.ToArray(),
            RecentUnlocks: recentUnlocks.ToArray(),
            TotalUnlocked: totalUnlocked,
            TotalAvailable: totalAvailable,
            TotalPoints: totalPoints,
            UnclaimedCount: unclaimedCount,
            UpdatedAt: updatedAt);
    }

    private static DateTimeOffset NextDailyResetUtc()
    {
        var nextResetDate = DateTimeOffset.UtcNow.UtcDateTime.Date.AddDays(1);
        return new DateTimeOffset(nextResetDate, TimeSpan.Zero);
    }

    private static DateOnly CurrentResetDate()
    {
        return DateOnly.FromDateTime(DateTime.UtcNow);
    }

    private static DateTimeOffset ResetAt(DateOnly resetDate)
    {
        return new DateTimeOffset(resetDate.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc), TimeSpan.Zero);
    }

    private static string NormalizePlayerId(string playerId)
    {
        return playerId.Trim().ToLowerInvariant();
    }

    private static string NormalizeId(string value)
    {
        return value.Trim().ToLowerInvariant();
    }

    private static string NormalizeRankingSort(string? sortBy)
    {
        var normalized = string.IsNullOrWhiteSpace(sortBy)
            ? "level"
            : sortBy.Trim().ToLowerInvariant();
        return normalized switch
        {
            "experience" or "xp" => "experience",
            "strength" => "strength",
            _ => "level"
        };
    }

    private static int ClampRankingLimit(int? limit)
    {
        return Math.Clamp(limit ?? 50, 1, 100);
    }

    private static string RankingOrderBy(string sortBy)
    {
        return sortBy switch
        {
            "experience" => "experience DESC, level DESC, strength DESC, updated_at ASC, player_id ASC",
            "strength" => "strength DESC, level DESC, experience DESC, updated_at ASC, player_id ASC",
            _ => "level DESC, experience DESC, strength DESC, updated_at ASC, player_id ASC"
        };
    }

    private static PlayerRankingEntryDto ReadRankingEntry(NpgsqlDataReader reader)
    {
        return new PlayerRankingEntryDto(
            Rank: reader.GetInt32(0),
            PlayerId: reader.GetString(1),
            Level: reader.GetInt32(2),
            Experience: reader.GetInt32(3),
            Strength: reader.GetInt32(4),
            Energy: reader.GetInt32(5),
            MaxEnergy: reader.GetInt32(6),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(7));
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
    DateTimeOffset UpdatedAt,
    DateTimeOffset LastEnergyRegeneratedAt,
    DateTimeOffset? NextEnergyRegenAt,
    int EnergyRegenSeconds,
    int EnergyRegenAmount,
    DateTimeOffset? HospitalCooldownUntil,
    int HospitalEnergyRestore,
    int HospitalGoldCost);

public sealed record PlayerRankingsResponse(
    string SortBy,
    int Limit,
    int TotalPlayers,
    PlayerRankingEntryDto[] Entries,
    DateTimeOffset UpdatedAt);

public sealed record PlayerRankingEntryDto(
    int Rank,
    string PlayerId,
    int Level,
    int Experience,
    int Strength,
    int Energy,
    int MaxEnergy,
    DateTimeOffset UpdatedAt);

public sealed record PlayerActionResponse(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    PlayerStateDto State,
    MissionProgressDto? MissionProgress = null);

public sealed record PlayerRewardsDto(int Gold, int Experience, int Strength, int Energy = 0)
{
    public static PlayerRewardsDto None { get; } = new(Gold: 0, Experience: 0, Strength: 0, Energy: 0);
}

public sealed record DailyObjectivesResponse(
    string PlayerId,
    DateOnly ResetDate,
    DateTimeOffset ResetAt,
    DailyObjectiveDto[] Objectives,
    DateTimeOffset UpdatedAt);

public sealed record DailyObjectiveDto(
    string ObjectiveId,
    string ActionType,
    string Title,
    string Description,
    int CurrentCount,
    int TargetCount,
    PlayerRewardsDto Rewards,
    bool Completed,
    bool Claimed,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? ClaimedAt,
    DateOnly ResetDate,
    DateTimeOffset ResetAt,
    int DisplayOrder);

public sealed record DailyObjectiveTrackRequest(
    string ActionType,
    int Quantity,
    string IdempotencyKey);

public sealed record DailyObjectiveClaimRequest(string IdempotencyKey);

public sealed record DailyObjectiveClaimResponse(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    PlayerStateDto State,
    DailyObjectiveDto? Objective,
    DailyObjectivesResponse Objectives);

public sealed record OnboardingQuestlineResponse(
    string PlayerId,
    string Status,
    OnboardingQuestDto? CurrentQuest,
    OnboardingQuestDto[] Quests,
    int CompletedCount,
    int TotalCount,
    int CompletionPercent,
    DateTimeOffset UpdatedAt);

public sealed record OnboardingQuestDto(
    string QuestId,
    string ActionType,
    string Title,
    string Description,
    string Guidance,
    string? Route,
    int CurrentCount,
    int TargetCount,
    PlayerRewardsDto Rewards,
    bool Completed,
    bool Claimed,
    bool Skipped,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? ClaimedAt,
    DateTimeOffset? SkippedAt,
    int DisplayOrder);

public sealed record OnboardingQuestTrackRequest(
    string ActionType,
    int Quantity,
    string IdempotencyKey);

public sealed record OnboardingQuestClaimRequest(string IdempotencyKey);

public sealed record OnboardingQuestSkipRequest(string IdempotencyKey);

public sealed record OnboardingQuestClaimResponse(
    bool Completed,
    string Message,
    PlayerRewardsDto Rewards,
    PlayerStateDto State,
    OnboardingQuestDto? Quest,
    OnboardingQuestlineResponse Questline);

public sealed record OnboardingQuestSkipResponse(
    bool Completed,
    string Message,
    OnboardingQuestDto? Quest,
    OnboardingQuestlineResponse Questline);

public sealed record AchievementsSummary(
    string PlayerId,
    AchievementProgressDto[] Achievements,
    AchievementUnlockDto[] RecentUnlocks,
    int TotalUnlocked,
    int TotalAvailable,
    int TotalPoints,
    int UnclaimedCount,
    DateTimeOffset UpdatedAt);

public sealed record AchievementProgressDto(
    string AchievementId,
    string ActionType,
    string Title,
    string Description,
    string Category,
    string MedalName,
    string MedalRarity,
    int Points,
    int CurrentCount,
    int TargetCount,
    bool Unlocked,
    bool Claimed,
    DateTimeOffset? UnlockedAt,
    DateTimeOffset? ClaimedAt,
    int DisplayOrder);

public sealed record AchievementUnlockDto(
    string AchievementId,
    string Title,
    string Category,
    string MedalName,
    string MedalRarity,
    int Points,
    DateTimeOffset AwardedAt,
    bool Claimed);

public sealed record AchievementUnlocksResponse(
    string PlayerId,
    AchievementUnlockDto[] Unlocks,
    DateTimeOffset UpdatedAt);

public sealed record AchievementTrackRequest(
    string ActionType,
    int Quantity,
    string IdempotencyKey,
    string? RelatedId);

public sealed record AchievementClaimRequest(string IdempotencyKey);

public sealed record AchievementClaimResponse(
    bool Completed,
    string Message,
    AchievementProgressDto? Achievement,
    AchievementsSummary Achievements);

public sealed record CombatResultRequest(
    int EnergyCost,
    int GoldReward,
    int ExperienceReward,
    string Message,
    string MissionId,
    bool Won,
    int RoundsCompleted,
    int AttackerDamage,
    int DefenderDamage,
    string IdempotencyKey);

public sealed record RestoreEnergyRequest(
    int EnergyAmount,
    string Message,
    string IdempotencyKey);

public sealed record HospitalRecoveryRequest(string IdempotencyKey);

public sealed record MissionProgressResponse(
    string PlayerId,
    MissionProgressDto[] Missions,
    DateTimeOffset UpdatedAt);

public sealed record MissionProgressDto(
    string MissionId,
    int Attempts,
    int Wins,
    int Losses,
    int TotalRounds,
    bool LastWon,
    string LastResult,
    DateTimeOffset? LastAttemptedAt,
    DateTimeOffset? CooldownUntil,
    DateTimeOffset UpdatedAt);

internal sealed record CombatAttemptRecord(
    string PlayerId,
    string MissionId,
    bool Won,
    int EnergyCost,
    int GoldReward,
    int ExperienceReward,
    int RoundsCompleted,
    string Message);

internal sealed record EnergyActionRecord(
    string PlayerId,
    int EnergyRestored,
    string Message);

internal sealed record DailyObjectiveClaimRecord(
    string PlayerId,
    string ObjectiveId,
    DateOnly ResetDate,
    int GoldAwarded,
    int ExperienceAwarded,
    int StrengthAwarded,
    int EnergyAwarded,
    DateTimeOffset ClaimedAt);

internal sealed record OnboardingQuestClaimRecord(
    string PlayerId,
    string QuestId,
    int GoldAwarded,
    int ExperienceAwarded,
    int StrengthAwarded,
    int EnergyAwarded,
    DateTimeOffset ClaimedAt);

internal sealed record AchievementClaimRecord(
    string PlayerId,
    string AchievementId,
    DateTimeOffset ClaimedAt);

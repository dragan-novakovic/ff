using Microsoft.Extensions.Logging;

internal static class BattleGatewayEndpoints
{
    private const int MinimumBattleEnergy = 10;

    public static void MapBattleGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/world/battles", async (
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var status = request.Query["status"].ToString();
            var query = string.IsNullOrWhiteSpace(status)
                ? string.Empty
                : $"?status={Uri.EscapeDataString(status)}";
            return await world.GetAsync($"battles{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayBattles");

        app.MapGet("/world/battles/{battleId}", async (
            string battleId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            return await world.GetAsync(
                $"battles/{Uri.EscapeDataString(battleId)}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayBattle");

        app.MapGet("/world/battles/{battleId}/reports", async (
            string battleId,
            string? playerId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var error = ValidateBearer(request, tokens);
            if (error is not null)
            {
                return error;
            }

            var query = new List<string>();
            if (!string.IsNullOrWhiteSpace(playerId))
            {
                query.Add($"playerId={Uri.EscapeDataString(playerId.Trim())}");
            }
            if (limit is not null)
            {
                query.Add($"limit={Math.Clamp(limit.Value, 1, 100)}");
            }
            var suffix = query.Count == 0 ? string.Empty : $"?{string.Join('&', query)}";
            return await world.GetAsync(
                $"battles/{Uri.EscapeDataString(battleId)}/reports{suffix}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayBattleCombatReports");

        app.MapGet("/players/{playerId}/battles/{battleId}/participation", async (
            string playerId,
            string battleId,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            return await world.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/battles/{Uri.EscapeDataString(battleId)}/participation",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayBattleParticipation");

        app.MapGet("/players/{playerId}/combat-reports", async (
            string playerId,
            string? battleId,
            int? limit,
            HttpRequest request,
            WorldServiceClient world,
            DevTokenValidator tokens) =>
        {
            var access = ValidatePlayerAccess(playerId, request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var query = new List<string>();
            if (!string.IsNullOrWhiteSpace(battleId))
            {
                query.Add($"battleId={Uri.EscapeDataString(battleId.Trim())}");
            }
            if (limit is not null)
            {
                query.Add($"limit={Math.Clamp(limit.Value, 1, 100)}");
            }
            var suffix = query.Count == 0 ? string.Empty : $"?{string.Join('&', query)}";
            return await world.GetAsync(
                $"players/{Uri.EscapeDataString(access.PlayerId!)}/combat-reports{suffix}",
                request.Headers.Authorization.ToString());
        }).WithName("GetGatewayPlayerCombatReports");

        app.MapPost("/players/{playerId}/battles/{battleId}/contribute", ContributeToBattle)
            .WithName("ContributeGatewayBattle");
    }

    private static async Task<IResult> ContributeToBattle(
        string playerId,
        string battleId,
        BattleContributionGatewayRequest contributionRequest,
        HttpRequest request,
        WorldServiceClient world,
        PlayerServiceClient players,
        CombatServiceClient combat,
        EconomyServiceClient economy,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        ILoggerFactory loggerFactory,
        DevTokenValidator tokens)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        var authorization = request.Headers.Authorization.ToString();
        var idempotencyKey = request.Headers["Idempotency-Key"].ToString().Trim();
        if (string.IsNullOrWhiteSpace(idempotencyKey))
        {
            return Results.BadRequest(new ErrorResponse("Idempotency-Key header is required."));
        }

        var escapedPlayerId = Uri.EscapeDataString(access.PlayerId!);
        var escapedBattleId = Uri.EscapeDataString(battleId);
        var battleDetails = await world.GetJsonAsync<BattleDetailsResponseDto>(
            $"battles/{escapedBattleId}",
            authorization);
        if (battleDetails.Error is not null)
        {
            return battleDetails.Error;
        }

        var battle = battleDetails.Value!.Battle;
        if (!string.Equals(battle.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            return Results.Json(
                new ErrorResponse("Battle is not active."),
                statusCode: StatusCodes.Status409Conflict);
        }

        if (battle.EndsAt <= DateTimeOffset.UtcNow)
        {
            return Results.Json(
                new ErrorResponse($"Battle ended at {battle.EndsAt:O}."),
                statusCode: StatusCodes.Status409Conflict);
        }

        var citizenship = await world.GetJsonAsync<PlayerCitizenshipResponseDto>(
            $"players/{escapedPlayerId}/citizenship",
            authorization);
        if (citizenship.Error is not null)
        {
            return citizenship.Error;
        }

        var playerCountry = citizenship.Value!.Citizenship;
        if (playerCountry is null ||
            !string.Equals(playerCountry.Status, "active", StringComparison.OrdinalIgnoreCase))
        {
            return Results.Json(
                new ErrorResponse("Join a country before contributing to battles."),
                statusCode: StatusCodes.Status409Conflict);
        }

        if (!string.Equals(playerCountry.CountryId, battle.AttackerCountryId, StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(playerCountry.CountryId, battle.DefenderCountryId, StringComparison.OrdinalIgnoreCase))
        {
            return Results.Json(
                new ErrorResponse("Your country is not fighting in this battle."),
                statusCode: StatusCodes.Status409Conflict);
        }

        var battleMissionId = BattleMissionId(battle.BattleId);
        var progress = await players.GetJsonAsync<MissionProgressResponseDto>(
            $"players/{escapedPlayerId}/missions/progress",
            authorization);
        if (progress.Error is not null)
        {
            return progress.Error;
        }

        var battleProgress = progress.Value!.Missions.FirstOrDefault(candidate =>
            string.Equals(candidate.MissionId, battleMissionId, StringComparison.OrdinalIgnoreCase));
        if (battleProgress?.CooldownUntil is DateTimeOffset cooldownUntil &&
            cooldownUntil > DateTimeOffset.UtcNow)
        {
            return Results.Json(
                new ErrorResponse($"Battle contribution is on cooldown until {cooldownUntil:O}."),
                statusCode: StatusCodes.Status409Conflict);
        }

        var playerState = await players.GetJsonAsync<PlayerStateForCombat>(
            $"players/{escapedPlayerId}/state",
            authorization);
        if (playerState.Error is not null)
        {
            return playerState.Error;
        }

        var state = playerState.Value!;
        if (state.Energy < MinimumBattleEnergy)
        {
            return Results.Json(
                new ErrorResponse($"Not enough energy. Battle contributions require at least {MinimumBattleEnergy} energy."),
                statusCode: StatusCodes.Status409Conflict);
        }

        var equipment = await economy.GetJsonAsync<EquipmentResponseDto>(
            $"players/{escapedPlayerId}/equipment",
            authorization);
        if (equipment.Error is not null)
        {
            return equipment.Error;
        }

        var equipmentBeforeFight = equipment.Value!;
        var weaponBeforeFight = equipmentBeforeFight.Weapon;
        var weaponPower = weaponBeforeFight is { Durability: > 0 }
            ? Math.Clamp(weaponBeforeFight.WeaponPower, 1, 5)
            : 1;
        var rounds = Math.Clamp(contributionRequest.Rounds ?? battle.Rounds, 1, Math.Max(1, battle.Rounds));
        var simulatedAttackerEnergy = Math.Clamp(state.Energy, 0, 100);

        var fight = await combat.PostJsonAsync<FightRequestDto, FightResponseDto>(
            "simulate/fight",
            authorization,
            new FightRequestDto(
                Attacker: new FighterDto(
                    Strength: Math.Max(1, state.Strength),
                    Energy: simulatedAttackerEnergy,
                    WeaponPower: weaponPower),
                Defender: new FighterDto(
                    Strength: Math.Max(1, battle.DefenderStrength),
                    Energy: Math.Clamp(battle.DefenderEnergy, 0, 100),
                    WeaponPower: Math.Clamp(battle.DefenderWeaponPower, 1, 5)),
                Rounds: rounds));
        if (fight.Error is not null)
        {
            return fight.Error;
        }

        var fightResult = fight.Value!;
        var damage = Math.Max(0, fightResult.AttackerDamage);
        if (damage <= 0)
        {
            return Results.Json(
                new ErrorResponse("Battle contribution dealt no damage."),
                statusCode: StatusCodes.Status409Conflict);
        }

        var won = string.Equals(fightResult.Winner, "attacker", StringComparison.OrdinalIgnoreCase);
        var energyCost = Math.Max(1, simulatedAttackerEnergy - fightResult.AttackerRemainingEnergy);
        var experienceReward = Math.Clamp(damage / 5, 1, 40);
        var goldReward = Math.Clamp((damage / 20) + (won ? 1 : 0), 1, 20);
        var playerMessage = $"Battle contribution dealt {damage} damage for {playerCountry.CountryName}.";
        var actionPrefix = $"battle:{access.PlayerId!.ToLowerInvariant()}:{battle.BattleId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}";

        var progression = await players.PostJsonAsync<CombatResultRequestDto, PlayerActionResponseDto>(
            $"players/{escapedPlayerId}/combat/result",
            authorization,
            new CombatResultRequestDto(
                EnergyCost: energyCost,
                GoldReward: goldReward,
                ExperienceReward: experienceReward,
                Message: playerMessage,
                MissionId: battleMissionId,
                Won: won,
                RoundsCompleted: fightResult.RoundsCompleted,
                AttackerDamage: fightResult.AttackerDamage,
                DefenderDamage: fightResult.DefenderDamage,
                IdempotencyKey: $"{actionPrefix}:progression"),
            InternalToken(configuration));
        if (progression.Error is not null)
        {
            return progression.Error;
        }

        var appliedProgression = progression.Value!;
        if (!appliedProgression.Completed)
        {
            return Results.Json(
                new ErrorResponse(appliedProgression.Message),
                statusCode: StatusCodes.Status409Conflict);
        }

        if (appliedProgression.Rewards.Gold > 0)
        {
            var walletCredit = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
                $"players/{escapedPlayerId}/wallet/credit",
                authorization,
                new WalletCreditRequestDto(
                    Amount: appliedProgression.Rewards.Gold,
                    EntryType: "battle_reward",
                    Reason: appliedProgression.Message,
                    IdempotencyKey: $"{actionPrefix}:gold"),
                InternalToken(configuration));
            if (walletCredit.Error is not null)
            {
                return walletCredit.Error;
            }

            var credit = walletCredit.Value!;
            if (!credit.Completed)
            {
                return Results.Json(
                    new ErrorResponse(credit.Message),
                    statusCode: StatusCodes.Status409Conflict);
            }

            appliedProgression = appliedProgression with { Wallet = credit.Inventory };
        }

        DamageWeaponResponseDto? weaponDamage = null;
        EquipmentResponseDto equipmentAfterFight = equipmentBeforeFight;
        if (weaponBeforeFight is { Durability: > 0 })
        {
            var damageWeapon = await economy.PostJsonAsync<DamageWeaponRequestDto, DamageWeaponResponseDto>(
                $"players/{escapedPlayerId}/equipment/weapon/damage",
                authorization,
                new DamageWeaponRequestDto(
                    DurabilityDamage: Math.Max(1, fightResult.RoundsCompleted),
                    Reason: $"Weapon durability used during battle {battle.BattleId}.",
                    IdempotencyKey: $"{actionPrefix}:weapon"),
                InternalToken(configuration));
            if (damageWeapon.Error is not null)
            {
                return damageWeapon.Error;
            }

            weaponDamage = damageWeapon.Value!;
            equipmentAfterFight = weaponDamage.Equipment;
        }

        var contribution = await world.PostJsonAsync<BattleContributionCommitRequestDto, BattleContributionResultDto>(
            $"players/{escapedPlayerId}/battles/{escapedBattleId}/contributions",
            authorization,
            new BattleContributionCommitRequestDto(
                Damage: damage,
                EnergySpent: energyCost,
                RoundsCompleted: fightResult.RoundsCompleted,
                Won: won,
                GoldReward: appliedProgression.Rewards.Gold,
                ExperienceReward: appliedProgression.Rewards.Experience,
                Message: playerMessage,
                IdempotencyKey: $"{actionPrefix}:world",
                Fight: new FightReportRequestDto(
                    Winner: fightResult.Winner,
                    RoundsRequested: fightResult.RoundsRequested,
                    RoundsCompleted: fightResult.RoundsCompleted,
                    AttackerDamage: fightResult.AttackerDamage,
                    DefenderDamage: fightResult.DefenderDamage,
                    AttackerRemainingEnergy: fightResult.AttackerRemainingEnergy,
                    DefenderRemainingEnergy: fightResult.DefenderRemainingEnergy),
                Weapon: BuildWeaponReport(
                    weaponBeforeFight,
                    equipmentAfterFight,
                    weaponDamage)));
        if (contribution.Error is not null)
        {
            return contribution.Error;
        }

        var contributionResult = contribution.Value!;
        if (!contributionResult.Completed)
        {
            return Results.Json(
                new ErrorResponse(contributionResult.Message),
                statusCode: StatusCodes.Status409Conflict);
        }

        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            access.PlayerId!,
            "battle_contribution",
            contributionResult.Message,
            battle.BattleId,
            $"activity:battle-contribution:{access.PlayerId!.ToLowerInvariant()}:{battle.BattleId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}");

        var achievementLogger = loggerFactory.CreateLogger(nameof(AchievementGatewayEndpoints));
        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "battle_contribution",
            $"achievement:battle-contribution:{access.PlayerId!.ToLowerInvariant()}:{battle.BattleId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}",
            achievementLogger,
            relatedId: battle.BattleId);
        await AchievementGatewayEndpoints.TrackAsync(
            players,
            access.PlayerId!,
            authorization,
            configuration,
            "battle_damage",
            $"achievement:battle-damage:{access.PlayerId!.ToLowerInvariant()}:{battle.BattleId.ToLowerInvariant()}:{idempotencyKey.ToLowerInvariant()}",
            achievementLogger,
            quantity: damage,
            relatedId: battle.BattleId);

        return Results.Ok(new BattleContributionGatewayResponse(
            Completed: true,
            Message: contributionResult.Message,
            Battle: contributionResult.Battle!,
            Contribution: contributionResult.Contribution,
            Participation: contributionResult.Participation,
            Report: contributionResult.Report,
            Fight: fightResult,
            PlayerAction: appliedProgression,
            MissionProgress: appliedProgression.MissionProgress,
            Equipment: equipmentAfterFight,
            WeaponDamage: weaponDamage,
            UpdatedAt: contributionResult.UpdatedAt));
    }

    private static IResult? ValidateBearer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? null
            : Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized);
    }

    private static WeaponReportRequestDto? BuildWeaponReport(
        EquippedWeaponDto? weaponBeforeFight,
        EquipmentResponseDto equipmentAfterFight,
        DamageWeaponResponseDto? weaponDamage)
    {
        if (weaponBeforeFight is null)
        {
            return null;
        }

        var weaponAfterFight = equipmentAfterFight.Weapon;
        var durabilityAfter = weaponAfterFight is not null &&
            string.Equals(weaponAfterFight.ItemId, weaponBeforeFight.ItemId, StringComparison.OrdinalIgnoreCase)
            ? weaponAfterFight.Durability
            : (int?)null;

        return new WeaponReportRequestDto(
            ItemId: weaponBeforeFight.ItemId,
            Name: weaponBeforeFight.Name,
            WeaponPower: weaponBeforeFight.WeaponPower,
            DurabilityBefore: weaponBeforeFight.Durability,
            DurabilityAfter: durabilityAfter,
            DurabilityDamage: Math.Max(0, weaponDamage?.DurabilityLost ?? 0));
    }

    private static PlayerAccessResult ValidatePlayerAccess(
        string playerId,
        HttpRequest request,
        DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        if (!token.IsValid)
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
        }

        if (!string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase))
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("You cannot access another player's battle participation."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }

    private static string BattleMissionId(string battleId)
    {
        return $"battle:{battleId.Trim().ToLowerInvariant()}";
    }
}

internal sealed record BattleContributionGatewayRequest(int? Rounds = null);

internal sealed record BattleContributionCommitRequestDto(
    int Damage,
    int EnergySpent,
    int RoundsCompleted,
    bool Won,
    int GoldReward,
    int ExperienceReward,
    string Message,
    string IdempotencyKey,
    FightReportRequestDto Fight,
    WeaponReportRequestDto? Weapon);

internal sealed record FightReportRequestDto(
    string Winner,
    int RoundsRequested,
    int RoundsCompleted,
    int AttackerDamage,
    int DefenderDamage,
    int AttackerRemainingEnergy,
    int DefenderRemainingEnergy);

internal sealed record WeaponReportRequestDto(
    string? ItemId,
    string? Name,
    int? WeaponPower,
    int? DurabilityBefore,
    int? DurabilityAfter,
    int DurabilityDamage);

internal sealed record BattleContributionGatewayResponse(
    bool Completed,
    string Message,
    CountryBattleDto Battle,
    BattleContributionDto? Contribution,
    PlayerBattleParticipationDto? Participation,
    CombatReportDto? Report,
    FightResponseDto Fight,
    PlayerActionResponseDto PlayerAction,
    MissionProgressDto? MissionProgress,
    EquipmentResponseDto Equipment,
    DamageWeaponResponseDto? WeaponDamage,
    DateTimeOffset UpdatedAt);

internal sealed record BattleDetailsResponseDto(
    CountryBattleDto Battle,
    BattleContributionDto[] Contributions,
    DateTimeOffset UpdatedAt);

internal sealed record BattleContributionResultDto(
    bool Completed,
    string Message,
    CountryBattleDto? Battle,
    BattleContributionDto? Contribution,
    PlayerBattleParticipationDto? Participation,
    CombatReportDto? Report,
    DateTimeOffset UpdatedAt);

internal sealed record CountryBattleDto(
    string BattleId,
    string RegionId,
    string RegionName,
    string AttackerCountryId,
    string AttackerCountryName,
    string AttackerCountryCode,
    string DefenderCountryId,
    string DefenderCountryName,
    string DefenderCountryCode,
    string Name,
    string Description,
    string BattleType,
    string? CampaignId,
    string Status,
    int AttackerScore,
    int DefenderScore,
    int TargetScore,
    int DefenderStrength,
    int DefenderEnergy,
    int DefenderWeaponPower,
    int Rounds,
    DateTimeOffset StartedAt,
    DateTimeOffset EndsAt,
    DateTimeOffset? ResolvedAt,
    string? WinnerCountryId,
    string? WinnerCountryName,
    DateTimeOffset UpdatedAt);

internal sealed record BattleContributionDto(
    string ContributionId,
    string BattleId,
    string PlayerId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Side,
    int Damage,
    int EnergySpent,
    int RoundsCompleted,
    bool Won,
    int GoldReward,
    int ExperienceReward,
    string Message,
    DateTimeOffset CreatedAt);

internal sealed record CombatReportListResponseDto(
    string? BattleId,
    string? PlayerId,
    CombatReportDto[] Reports,
    DateTimeOffset UpdatedAt);

internal sealed record CombatReportDto(
    string ReportId,
    string ContributionId,
    string BattleId,
    string PlayerId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Side,
    string BattleName,
    string BattleType,
    string RegionId,
    string RegionName,
    string AttackerCountryId,
    string AttackerCountryName,
    string AttackerCountryCode,
    string DefenderCountryId,
    string DefenderCountryName,
    string DefenderCountryCode,
    int Damage,
    int EnergySpent,
    int RoundsCompleted,
    bool Won,
    int GoldReward,
    int ExperienceReward,
    string FightWinner,
    int FightRoundsRequested,
    int FightRoundsCompleted,
    int AttackerDamage,
    int DefenderDamage,
    int AttackerRemainingEnergy,
    int DefenderRemainingEnergy,
    int AttackerScoreAfter,
    int DefenderScoreAfter,
    int TargetScore,
    string StatusAfter,
    string? WinnerCountryId,
    string? WinnerCountryName,
    string? WeaponItemId,
    string? WeaponName,
    int? WeaponPower,
    int? WeaponDurabilityBefore,
    int? WeaponDurabilityAfter,
    int WeaponDurabilityDamage,
    string? CampaignId,
    string? CampaignName,
    CombatReportPhaseDto[] PhaseSnapshots,
    string Message,
    DateTimeOffset CreatedAt);

internal sealed record CombatReportPhaseDto(
    string PhaseId,
    string CampaignId,
    string BattleId,
    string BattleName,
    int PhaseNumber,
    string Name,
    string Objectives,
    int TargetDamage,
    int AttackerDamage,
    int DefenderDamage,
    string Status,
    DateTimeOffset? CompletedAt);

internal sealed record PlayerBattleParticipationDto(
    string PlayerId,
    string BattleId,
    string? CountryId,
    string? CountryName,
    string? CountryCode,
    string? Side,
    int ContributionCount,
    int Damage,
    int EnergySpent,
    int GoldReward,
    int ExperienceReward,
    DateTimeOffset? LastContributedAt);

internal sealed record PlayerCitizenshipResponseDto(
    string PlayerId,
    PlayerCitizenshipDto? Citizenship,
    DateTimeOffset UpdatedAt);

internal sealed record PlayerCitizenshipDto(
    string PlayerId,
    string CountryId,
    string CountryName,
    string CountryCode,
    string Status,
    DateTimeOffset JoinedAt,
    DateTimeOffset UpdatedAt);

import 'dart:math';

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MissionsPage extends StatefulWidget {
  final User user;
  const MissionsPage({super.key, required this.user});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  late final MissionsBloc _missionsBloc;
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _missionsBloc = Provider.of<MissionsBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _missionsBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _fight(CombatMission mission) async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _missionsBloc.fight(
      playerId: widget.user.uid,
      missionId: mission.missionId,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      _playerBloc.setBearerToken(_loginBloc.currentToken);
      _inventoryBloc.setBearerToken(_loginBloc.currentToken);
      await _playerBloc.loadState(widget.user.uid);
      await _inventoryBloc.load(widget.user.uid);
      await _onboardingBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _missionsBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _repairWeapon() async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _missionsBloc.repairWeapon(
      playerId: widget.user.uid,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      await _inventoryBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _missionsBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missions')),
      body: Consumer<MissionsBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.missions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.missions.isEmpty) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OnboardingGuidanceCard(
                  questline: context.watch<OnboardingQuestlineBloc>().questline,
                  route: '/missions',
                ),
                _EquipmentCombatCard(
                  equipment: bloc.equipment,
                  isRepairing: bloc.isRepairingWeapon,
                  onRepair: _repairWeapon,
                ),
                if (bloc.lastRepair != null)
                  _RepairResultCard(result: bloc.lastRepair!),
                if (bloc.lastFight != null)
                  _FightResultCard(result: bloc.lastFight!),
                ...bloc.missions.map(
                  (mission) => _MissionCard(
                    mission: mission,
                    progress: bloc.progress?.forMission(mission.missionId),
                    isFighting:
                        bloc.fightingMissionIds.contains(mission.missionId),
                    onFight: () => _fight(mission),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FightResultCard extends StatelessWidget {
  final MissionFightResult result;
  const _FightResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        leading: const Icon(Icons.shield, color: Colors.blue),
        title: Text('Last fight: ${result.fight.winner}'),
        subtitle: Text(
          'Damage ${result.fight.attackerDamage}-${result.fight.defenderDamage}; '
          'Record ${result.missionProgress?.wins ?? 0}/${result.missionProgress?.attempts ?? 0} wins; '
          '${result.weaponDamage?.message ?? 'No weapon durability changed.'} '
          '${result.message}',
        ),
      ),
    );
  }
}

class _EquipmentCombatCard extends StatelessWidget {
  final EquipmentSummary? equipment;
  final bool isRepairing;
  final Future<void> Function() onRepair;
  const _EquipmentCombatCard({
    required this.equipment,
    required this.isRepairing,
    required this.onRepair,
  });

  @override
  Widget build(BuildContext context) {
    final weapon = equipment?.weapon;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipped weapon',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (weapon == null)
              const Text('No weapon equipped. You will fight unarmed.')
            else ...[
              Text(
                '${weapon.name} • Power ${weapon.weaponPower} • '
                '${weapon.durability}/${weapon.maxDurability} durability',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: weapon.durabilityProgress),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    weapon.durability < weapon.maxDurability && !isRepairing
                        ? onRepair
                        : null,
                icon: isRepairing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.build),
                label: Text(isRepairing ? 'Repairing...' : 'Repair weapon'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepairResultCard extends StatelessWidget {
  final RepairWeaponResult result;
  const _RepairResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.build_circle : Icons.info_outline,
          color: result.completed ? Colors.green : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: Text(
          result.completed
              ? 'Repair cost: ${result.goldCost} gold + ${result.materialQuantity} ${result.materialItemName}.'
              : 'No repair was applied.',
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final CombatMission mission;
  final MissionProgress? progress;
  final bool isFighting;
  final VoidCallback onFight;
  const _MissionCard({
    required this.mission,
    required this.progress,
    required this.isFighting,
    required this.onFight,
  });

  @override
  Widget build(BuildContext context) {
    final cooldownUntil = progress?.cooldownUntil;
    final isOnCooldown = progress?.isOnCooldown ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mission.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(mission.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _MissionStat(label: 'Rounds', value: '${mission.rounds}'),
                _MissionStat(
                    label: 'Defender strength',
                    value: '${mission.defender.strength}'),
                _MissionStat(
                    label: 'Reward XP', value: '${mission.rewardExperience}'),
                _MissionStat(
                    label: 'Reward gold', value: '${mission.rewardGold}'),
                _MissionStat(
                  label: 'Attempts',
                  value: '${progress?.attempts ?? 0}',
                ),
                _MissionStat(
                  label: 'Wins',
                  value: '${progress?.wins ?? 0}',
                ),
              ],
            ),
            if (progress?.lastResult.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Last result: ${progress!.lastResult}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (isOnCooldown && cooldownUntil != null) ...[
              const SizedBox(height: 8),
              Text(
                'Cooldown until ${cooldownUntil.toLocal()}',
                style: TextStyle(color: Colors.orange.shade700),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isFighting || isOnCooldown ? null : onFight,
              icon: isFighting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sports_mma),
              label: Text(isFighting
                  ? 'Fighting...'
                  : isOnCooldown
                      ? 'Cooling down'
                      : 'Simulate fight'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionStat extends StatelessWidget {
  final String label;
  final String value;
  const _MissionStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

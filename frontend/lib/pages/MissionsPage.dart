import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
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

  @override
  void initState() {
    super.initState();
    _missionsBloc = Provider.of<MissionsBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    await _missionsBloc.load();
  }

  Future<void> _fight(CombatMission mission) async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    final result =
        await _missionsBloc.fight(widget.user.uid, mission.missionId);
    if (result != null) {
      _playerBloc.setBearerToken(_loginBloc.currentToken);
      _inventoryBloc.setBearerToken(_loginBloc.currentToken);
      await _playerBloc.loadState(widget.user.uid);
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
                if (bloc.lastFight != null)
                  _FightResultCard(result: bloc.lastFight!),
                ...bloc.missions.map(
                  (mission) => _MissionCard(
                    mission: mission,
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
          'Damage ${result.fight.attackerDamage}-${result.fight.defenderDamage}; ${result.message}',
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final CombatMission mission;
  final bool isFighting;
  final VoidCallback onFight;
  const _MissionCard({
    required this.mission,
    required this.isFighting,
    required this.onFight,
  });

  @override
  Widget build(BuildContext context) {
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
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isFighting ? null : onFight,
              icon: isFighting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sports_mma),
              label: Text(isFighting ? 'Fighting...' : 'Simulate fight'),
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

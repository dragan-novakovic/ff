import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/DailyObjectives.dart';
import 'package:ff/models/PlayerState.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DailyCampaignBoardPage extends StatefulWidget {
  final User user;

  const DailyCampaignBoardPage({super.key, required this.user});

  @override
  State<DailyCampaignBoardPage> createState() => _DailyCampaignBoardPageState();
}

class _DailyCampaignBoardPageState extends State<DailyCampaignBoardPage> {
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    await _playerBloc.loadDailyObjectives(widget.user.uid);
  }

  Future<void> _claim(DailyObjective objective) async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.claimDailyObjective(
      playerId: widget.user.uid,
      objectiveId: objective.objectiveId,
    );
    if (result != null && (result.wallet != null || result.rewards.gold > 0)) {
      _inventoryBloc.setBearerToken(_loginBloc.currentToken);
      await _inventoryBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _playerBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Daily Campaign Board',
      subtitle: 'Rotating objectives, rewards, and claimable orders',
      icon: Icons.checklist_rtl,
      actions: [
        IconButton(
          tooltip: 'Refresh campaign board',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer<PlayerBloc>(
        builder: (context, bloc, _) {
          final summary = bloc.dailyObjectives;
          if (bloc.isLoadingObjectives && summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && summary == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (summary == null) {
            return Center(
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.flag_circle_outlined),
                label: const Text('Load daily campaign board'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: _CampaignBoard(
              summary: summary,
              isLoading: bloc.isLoadingObjectives,
              claimingObjectiveIds: bloc.claimingObjectiveIds,
              lastClaim: bloc.lastObjectiveClaim,
              onClaim: _claim,
            ),
          );
        },
      ),
    );
  }
}

class _CampaignBoard extends StatelessWidget {
  final DailyObjectivesSummary summary;
  final bool isLoading;
  final Set<String> claimingObjectiveIds;
  final DailyObjectiveClaimResult? lastClaim;
  final Future<void> Function(DailyObjective objective) onClaim;

  const _CampaignBoard({
    required this.summary,
    required this.isLoading,
    required this.claimingObjectiveIds,
    required this.lastClaim,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final objectives = [...summary.objectives]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final completed =
        objectives.where((objective) => objective.completed).length;
    final claimed = objectives.where((objective) => objective.claimed).length;
    final totalGold =
        objectives.fold<int>(0, (sum, item) => sum + item.rewards.gold);
    final totalXp =
        objectives.fold<int>(0, (sum, item) => sum + item.rewards.experience);
    final progress = objectives.isEmpty ? 0.0 : completed / objectives.length;
    final groups = _groupObjectives(objectives);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GameHero(
          eyebrow: 'Daily Operation',
          title:
              'Command objectives reset ${DateFormat.Hm().format(summary.resetAt.toLocal())}',
          subtitle:
              'Complete a balanced set of war, economy, training, and social orders before the daily reset.',
          icon: Icons.flag_circle_outlined,
          accent: GameColors.emerald,
          stats: [
            GameStat(
              label: 'completed',
              value: '$completed/${objectives.length}',
              icon: Icons.task_alt,
              color: GameColors.emerald,
            ),
            GameStat(
              label: 'claimable',
              value: summary.claimableCount.toString(),
              icon: Icons.redeem,
              color: GameColors.amber,
            ),
            GameStat(
              label: 'reward pool',
              value: '${Utils.number(totalGold)}g / ${Utils.number(totalXp)}xp',
              icon: Icons.stars,
              color: GameColors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: GameColors.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Campaign progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GameProgressBar(
                label: 'Daily board completion',
                valueLabel: '$completed/${objectives.length}',
                value: progress,
                color: GameColors.emerald,
              ),
              const SizedBox(height: 10),
              Text(
                'Reset date ${DateFormat.yMMMd().format(summary.resetDate.toLocal())} - $claimed reward(s) claimed.',
                style: const TextStyle(color: GameColors.textMuted),
              ),
            ],
          ),
        ),
        if (lastClaim != null)
          GameNotice(
            icon:
                lastClaim!.completed ? Icons.check_circle : Icons.info_outline,
            message:
                '${lastClaim!.message} Rewards: ${_rewardLabel(lastClaim!.rewards)}',
            color: lastClaim!.completed ? GameColors.emerald : GameColors.amber,
          ),
        if (objectives.isEmpty)
          const GameEmptyState(
            icon: Icons.flag_outlined,
            message: 'No daily campaign objectives are available yet.',
          )
        else
          ...groups.entries.expand(
            (entry) => [
              GameSectionTitle(
                title: entry.key,
                subtitle: _groupSubtitle(entry.key, entry.value.length),
              ),
              ...entry.value.map(
                (objective) => _ObjectiveCard(
                  objective: objective,
                  isClaiming:
                      claimingObjectiveIds.contains(objective.objectiveId),
                  onClaim:
                      objective.claimable ? () => onClaim(objective) : null,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  final DailyObjective objective;
  final bool isClaiming;
  final VoidCallback? onClaim;

  const _ObjectiveCard({
    required this.objective,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final color = _objectiveColor(objective.actionType);
    return GamePanel(
      borderColor: objective.claimable
          ? GameColors.amber.withOpacity(0.55)
          : GameColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.42)),
                ),
                child: Icon(_objectiveIcon(objective.actionType), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      objective.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      objective.description,
                      style: const TextStyle(
                        color: GameColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: objective.claimed
                    ? 'claimed'
                    : objective.completed
                        ? 'ready'
                        : 'active',
                color: objective.claimed
                    ? GameColors.emerald
                    : objective.completed
                        ? GameColors.amber
                        : GameColors.cyan,
              ),
            ],
          ),
          const SizedBox(height: 14),
          GameProgressBar(
            label: 'Order progress',
            valueLabel:
                '${objective.currentCount.clamp(0, objective.targetCount)}/${objective.targetCount}',
            value: objective.progress,
            color: color,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (objective.rewards.gold > 0)
                GameStatPill(
                  stat: GameStat(
                    label: 'gold',
                    value: '+${Utils.number(objective.rewards.gold)}',
                    icon: Icons.monetization_on,
                    color: GameColors.amber,
                  ),
                ),
              if (objective.rewards.experience > 0)
                GameStatPill(
                  stat: GameStat(
                    label: 'experience',
                    value: '+${Utils.number(objective.rewards.experience)}',
                    icon: Icons.star,
                    color: GameColors.violet,
                  ),
                ),
              if (objective.rewards.strength > 0)
                GameStatPill(
                  stat: GameStat(
                    label: 'strength',
                    value: '+${Utils.number(objective.rewards.strength)}',
                    icon: Icons.fitness_center,
                    color: GameColors.crimson,
                  ),
                ),
              if (objective.rewards.energy > 0)
                GameStatPill(
                  stat: GameStat(
                    label: 'energy',
                    value: '+${Utils.number(objective.rewards.energy)}',
                    icon: Icons.bolt,
                    color: GameColors.emerald,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: isClaiming ? null : onClaim,
              icon: isClaiming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(objective.claimed ? Icons.check : Icons.redeem),
              label: Text(
                isClaiming
                    ? 'Claiming...'
                    : objective.claimed
                        ? 'Claimed'
                        : objective.completed
                            ? 'Claim reward'
                            : 'In progress',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.40)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GameTheme(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: GameColors.crimson,
              ),
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
      ),
    );
  }
}

Map<String, List<DailyObjective>> _groupObjectives(
  List<DailyObjective> objectives,
) {
  final groups = <String, List<DailyObjective>>{};
  for (final objective in objectives) {
    groups
        .putIfAbsent(_groupLabel(objective.actionType), () => [])
        .add(objective);
  }
  return groups;
}

String _groupLabel(String actionType) {
  final normalized = actionType.toLowerCase();
  if (normalized.contains('battle') || normalized.contains('fight')) {
    return 'War Orders';
  }
  if (normalized.contains('work') ||
      normalized.contains('market') ||
      normalized.contains('production')) {
    return 'Economy Orders';
  }
  if (normalized.contains('train') || normalized.contains('strength')) {
    return 'Training Orders';
  }
  if (normalized.contains('social') ||
      normalized.contains('article') ||
      normalized.contains('chat')) {
    return 'Social Orders';
  }
  return 'Other Orders';
}

String _groupSubtitle(String label, int count) {
  return switch (label) {
    'War Orders' => '$count objective(s) pushing combat and country damage.',
    'Economy Orders' =>
      '$count objective(s) feeding jobs, production, and trade.',
    'Training Orders' => '$count objective(s) improving citizen readiness.',
    'Social Orders' => '$count objective(s) growing community activity.',
    _ => '$count objective(s) from the daily campaign rotation.',
  };
}

IconData _objectiveIcon(String actionType) {
  final normalized = actionType.toLowerCase();
  if (normalized.contains('battle') || normalized.contains('fight')) {
    return Icons.local_fire_department;
  }
  if (normalized.contains('work')) {
    return Icons.engineering;
  }
  if (normalized.contains('market')) {
    return Icons.storefront;
  }
  if (normalized.contains('production')) {
    return Icons.factory;
  }
  if (normalized.contains('train') || normalized.contains('strength')) {
    return Icons.fitness_center;
  }
  if (normalized.contains('social') || normalized.contains('article')) {
    return Icons.forum;
  }
  return Icons.flag;
}

Color _objectiveColor(String actionType) {
  final normalized = actionType.toLowerCase();
  if (normalized.contains('battle') || normalized.contains('fight')) {
    return GameColors.crimson;
  }
  if (normalized.contains('work') ||
      normalized.contains('market') ||
      normalized.contains('production')) {
    return GameColors.emerald;
  }
  if (normalized.contains('train') || normalized.contains('strength')) {
    return GameColors.violet;
  }
  if (normalized.contains('social') || normalized.contains('article')) {
    return GameColors.cyan;
  }
  return GameColors.amber;
}

String _rewardLabel(PlayerRewards rewards) {
  final parts = <String>[];
  if (rewards.gold > 0) {
    parts.add('${Utils.number(rewards.gold)} gold');
  }
  if (rewards.experience > 0) {
    parts.add('${Utils.number(rewards.experience)} XP');
  }
  if (rewards.strength > 0) {
    parts.add('${Utils.number(rewards.strength)} strength');
  }
  if (rewards.energy > 0) {
    parts.add('${Utils.number(rewards.energy)} energy');
  }
  return parts.isEmpty ? 'none' : parts.join(', ');
}

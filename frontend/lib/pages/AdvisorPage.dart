import 'package:ff/blocs/AchievementsBloc.dart';
import 'package:ff/blocs/ActivityFeedBloc.dart';
import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/Achievements.dart';
import 'package:ff/models/DailyObjectives.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/OnboardingQuestline.dart';
import 'package:ff/models/PlayerState.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdvisorPage extends StatefulWidget {
  final User user;
  const AdvisorPage({super.key, required this.user});

  @override
  State<AdvisorPage> createState() => _AdvisorPageState();
}

class _AdvisorPageState extends State<AdvisorPage> {
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;
  late final AchievementsBloc _achievementsBloc;
  late final WorldBloc _worldBloc;
  late final CountryBattlesBloc _battlesBloc;
  late final ActivityFeedBloc _activityFeedBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _achievementsBloc = Provider.of<AchievementsBloc>(context, listen: false);
    _worldBloc = Provider.of<WorldBloc>(context, listen: false);
    _battlesBloc = Provider.of<CountryBattlesBloc>(context, listen: false);
    _activityFeedBloc = Provider.of<ActivityFeedBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    final token = _loginBloc.currentToken;
    _playerBloc.setBearerToken(token);
    _inventoryBloc.setBearerToken(token);
    _onboardingBloc.setBearerToken(token);
    _achievementsBloc.setBearerToken(token);
    _worldBloc.setBearerToken(token);
    _battlesBloc.setBearerToken(token);
    _activityFeedBloc.setBearerToken(token);
    await Future.wait([
      _playerBloc.loadState(widget.user.uid),
      _playerBloc.loadDailyObjectives(widget.user.uid),
      _inventoryBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
      _achievementsBloc.load(widget.user.uid),
      _worldBloc.load(widget.user.uid),
      _battlesBloc.load(widget.user.uid, reportLimit: 25),
      _activityFeedBloc.load(widget.user.uid, limit: 10),
    ]);
  }

  Future<void> _claimOnboarding(OnboardingQuest quest) async {
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _onboardingBloc.claim(
      playerId: widget.user.uid,
      questId: quest.questId,
    );
    if (result != null) {
      await Future.wait([
        _playerBloc.loadState(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
        _achievementsBloc.load(widget.user.uid),
      ]);
    }
    _showMessage(result?.message ?? _onboardingBloc.error);
  }

  Future<void> _skipOnboarding(OnboardingQuest quest) async {
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _onboardingBloc.skip(
      playerId: widget.user.uid,
      questId: quest.questId,
    );
    _showMessage(result?.message ?? _onboardingBloc.error);
  }

  Future<void> _claimDailyObjective(DailyObjective objective) async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.claimDailyObjective(
      playerId: widget.user.uid,
      objectiveId: objective.objectiveId,
    );
    if (result != null) {
      await Future.wait([
        _inventoryBloc.load(widget.user.uid),
        _onboardingBloc.load(widget.user.uid),
        _achievementsBloc.load(widget.user.uid),
      ]);
    }
    _showMessage(result?.message ?? _playerBloc.error);
  }

  void _showMessage(String? message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final playerBloc = context.watch<PlayerBloc>();
    final inventoryBloc = context.watch<InventoryBloc>();
    final onboardingBloc = context.watch<OnboardingQuestlineBloc>();
    final achievementsBloc = context.watch<AchievementsBloc>();
    final worldBloc = context.watch<WorldBloc>();
    final battlesBloc = context.watch<CountryBattlesBloc>();
    final activityBloc = context.watch<ActivityFeedBloc>();
    final state = playerBloc.state;
    final signals = _buildSignals(
      context: context,
      state: state,
      inventory: inventoryBloc.inventory,
      dailyObjectives: playerBloc.dailyObjectives,
      questline: onboardingBloc.questline,
      achievements: achievementsBloc.summary,
      worldBloc: worldBloc,
      battles: battlesBloc.battles,
      reports: battlesBloc.playerCombatReports,
      unreadNotifications: activityBloc.unreadCount,
    );

    return GameScaffold(
      title: 'Advisor',
      subtitle: 'Adaptive tutorial and next-step command center',
      icon: Icons.assistant,
      actions: [
        IconButton(
          tooltip: 'Refresh advisor',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Builder(
        builder: (context) {
          if (state == null && playerBloc.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AdvisorHero(
                  state: state,
                  inventory: inventoryBloc.inventory,
                  questline: onboardingBloc.questline,
                  signalCount: signals.length,
                ),
                const SizedBox(height: 12),
                ..._errors(
                  playerBloc.error,
                  inventoryBloc.error,
                  onboardingBloc.error,
                  achievementsBloc.error,
                  worldBloc.error,
                  battlesBloc.error,
                  activityBloc.error,
                ).map(
                  (error) => GameNotice(
                    icon: Icons.warning_amber,
                    message: error,
                    color: GameColors.amber,
                  ),
                ),
                const GameSectionTitle(
                  title: 'Recommended next actions',
                  subtitle:
                      'Prioritized from real player, economy, world, battle, achievement, notification, and tutorial state.',
                ),
                if (signals.isEmpty)
                  const GameEmptyState(
                    icon: Icons.check_circle_outline,
                    message:
                        'No urgent advisor signals. Refresh after completing more gameplay.',
                  )
                else
                  ...signals
                      .map((signal) => _AdvisorSignalCard(signal: signal)),
                const GameSectionTitle(
                  title: 'Tutorial roadmap',
                  subtitle:
                      'Backend onboarding steps remain the source of truth for tutorial progress.',
                ),
                _QuestlinePanel(
                  questline: onboardingBloc.questline,
                  claimingQuestIds: onboardingBloc.claimingQuestIds,
                  skippingQuestIds: onboardingBloc.skippingQuestIds,
                  onClaim: _claimOnboarding,
                  onSkip: _skipOnboarding,
                ),
                const GameSectionTitle(
                  title: 'Daily objective planner',
                  subtitle: 'Claim ready rewards or route to unfinished tasks.',
                ),
                _DailyObjectivePanel(
                  summary: playerBloc.dailyObjectives,
                  claimingIds: playerBloc.claimingObjectiveIds,
                  onClaim: _claimDailyObjective,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_AdvisorSignal> _buildSignals({
    required BuildContext context,
    required PlayerState? state,
    required InventorySummary? inventory,
    required DailyObjectivesSummary? dailyObjectives,
    required OnboardingQuestline? questline,
    required AchievementsSummary? achievements,
    required WorldBloc worldBloc,
    required CountryBattleList? battles,
    required CombatReportList? reports,
    required int unreadNotifications,
  }) {
    final signals = <_AdvisorSignal>[];
    final quest = questline?.currentQuest;
    if (quest != null) {
      signals.add(
        _AdvisorSignal(
          priority: quest.claimable ? 100 : 86,
          icon: quest.claimable ? Icons.card_giftcard : Icons.tour,
          title:
              quest.claimable ? 'Claim tutorial reward' : 'Continue tutorial',
          message: quest.claimable ? quest.description : quest.guidance,
          color: quest.claimable ? GameColors.emerald : GameColors.cyan,
          route: quest.claimable ? null : quest.route,
          actionLabel: quest.claimable ? 'Claim reward' : 'Go to step',
          onAction: quest.claimable ? () => _claimOnboarding(quest) : null,
          secondaryLabel:
              !quest.claimable && quest.route == null ? null : 'Skip',
          onSecondary: !quest.claimed && !quest.claimable
              ? () => _skipOnboarding(quest)
              : null,
          progress: quest.progress,
          valueLabel:
              '${quest.currentCount}/${quest.targetCount} • ${questline?.completionPercent ?? 0}% tutorial',
        ),
      );
    }

    final claimableObjective = dailyObjectives?.objectives
        .where((objective) => objective.claimable)
        .cast<DailyObjective?>()
        .firstWhere((objective) => objective != null, orElse: () => null);
    if (claimableObjective != null) {
      signals.add(
        _AdvisorSignal(
          priority: 95,
          icon: Icons.redeem,
          title: 'Claim daily objective',
          message: claimableObjective.description,
          color: GameColors.emerald,
          actionLabel: 'Claim',
          onAction: () => _claimDailyObjective(claimableObjective),
          progress: claimableObjective.progress,
          valueLabel:
              '${claimableObjective.currentCount}/${claimableObjective.targetCount}',
        ),
      );
    }

    if (achievements != null && achievements.unclaimedCount > 0) {
      signals.add(
        _AdvisorSignal(
          priority: 90,
          icon: Icons.emoji_events,
          title: 'Claim achievement medals',
          message:
              '${achievements.unclaimedCount} unlocked medal reward(s) are waiting.',
          color: GameColors.amber,
          route: '/achievements',
          actionLabel: 'Open medals',
          progress: achievements.progress,
          valueLabel:
              '${achievements.totalUnlocked}/${achievements.totalAvailable}',
        ),
      );
    }

    if (state != null) {
      if (!state.hasWorkedToday) {
        signals.add(
          const _AdvisorSignal(
            priority: 82,
            icon: Icons.work,
            title: 'Work before reset',
            message: 'Earn daily gold and XP before the next reset window.',
            color: GameColors.cyan,
            route: '/home',
            actionLabel: 'Go home',
          ),
        );
      }
      if (!state.hasTrainedToday) {
        signals.add(
          const _AdvisorSignal(
            priority: 80,
            icon: Icons.fitness_center,
            title: 'Train today',
            message: 'Gain strength and keep combat progression moving.',
            color: GameColors.violet,
            route: '/home',
            actionLabel: 'Go train',
          ),
        );
      }
      if (state.canRecoverAtHospital) {
        signals.add(
          _AdvisorSignal(
            priority: state.energyProgress < 0.35 ? 88 : 74,
            icon: Icons.local_hospital,
            title: 'Recover battle energy',
            message:
                'Hospital recovery can restore up to ${state.hospitalEnergyRestore <= 0 ? state.maxEnergy - state.energy : state.hospitalEnergyRestore} energy.',
            color: GameColors.crimson,
            route: '/recovery-center',
            actionLabel: 'Open recovery',
            progress: state.energyProgress,
            valueLabel: '${state.energy}/${state.maxEnergy}',
          ),
        );
      }
    }

    if (worldBloc.citizenship == null) {
      signals.add(
        const _AdvisorSignal(
          priority: 78,
          icon: Icons.public,
          title: 'Choose citizenship',
          message:
              'Join a country to unlock treasury, wars, politics, and national objectives.',
          color: GameColors.cyan,
          route: '/world',
          actionLabel: 'Pick country',
        ),
      );
    }

    final activeBattles = battles?.activeBattles ?? const <CountryBattle>[];
    if (activeBattles.isNotEmpty) {
      signals.add(
        _AdvisorSignal(
          priority: 76,
          icon: Icons.local_fire_department,
          title: 'Active war fronts',
          message:
              '${activeBattles.length} battle(s) are open for contribution and combat reports.',
          color: GameColors.crimson,
          route: '/battle-reports',
          actionLabel: 'Open reports',
        ),
      );
    }

    if (unreadNotifications > 0) {
      signals.add(
        _AdvisorSignal(
          priority: 66,
          icon: Icons.notifications_active,
          title: 'Read new notifications',
          message: '$unreadNotifications unread backend activity alert(s).',
          color: GameColors.amber,
          route: '/activity',
          actionLabel: 'Open inbox',
        ),
      );
    }

    final storageProgress = inventory == null || inventory.storageLimit <= 0
        ? 0.0
        : inventory.storageUsed / inventory.storageLimit;
    if (storageProgress >= 0.8) {
      signals.add(
        _AdvisorSignal(
          priority: 64,
          icon: Icons.inventory_2,
          title: 'Storage is filling up',
          message:
              'Inventory storage is at ${(storageProgress * 100).round()}%. Sell, use, or move supplies.',
          color: GameColors.violet,
          route: '/inventory',
          actionLabel: 'Open storage',
          progress: storageProgress,
          valueLabel: '${inventory!.storageUsed}/${inventory.storageLimit}',
        ),
      );
    }

    if ((reports?.reports.length ?? 0) == 0 && activeBattles.isNotEmpty) {
      signals.add(
        const _AdvisorSignal(
          priority: 58,
          icon: Icons.receipt_long,
          title: 'Generate first battle report',
          message:
              'Contribute to an active country battle to create a persisted combat report.',
          color: GameColors.crimson,
          route: '/battle-reports',
          actionLabel: 'Contribute',
        ),
      );
    }

    signals.sort((a, b) => b.priority.compareTo(a.priority));
    return signals.take(10).toList();
  }
}

class _AdvisorHero extends StatelessWidget {
  final PlayerState? state;
  final InventorySummary? inventory;
  final OnboardingQuestline? questline;
  final int signalCount;

  const _AdvisorHero({
    required this.state,
    required this.inventory,
    required this.questline,
    required this.signalCount,
  });

  @override
  Widget build(BuildContext context) {
    return GameHero(
      eyebrow: 'Strategic advisor',
      title: signalCount == 0
          ? 'Command queue clear'
          : '$signalCount action signals',
      subtitle:
          'Recommendations are derived from persisted player state, wallet, objectives, onboarding, achievements, citizenship, battles, and notifications.',
      icon: Icons.assistant,
      accent: GameColors.cyan,
      stats: [
        GameStat(
          label: 'energy',
          value: state == null ? '--' : '${state!.energy}/${state!.maxEnergy}',
          icon: Icons.bolt,
          color: GameColors.emerald,
        ),
        GameStat(
          label: 'wallet',
          value: inventory == null
              ? '--'
              : '${Utils.number(inventory!.walletGold)}g',
          icon: Icons.account_balance_wallet,
          color: GameColors.amber,
        ),
        GameStat(
          label: 'tutorial',
          value: '${questline?.completionPercent ?? 0}%',
          icon: Icons.tour,
          color: GameColors.violet,
        ),
      ],
    );
  }
}

class _AdvisorSignal {
  final int priority;
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final String? route;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;
  final double? progress;
  final String? valueLabel;

  const _AdvisorSignal({
    required this.priority,
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.route,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.progress,
    this.valueLabel,
  });
}

class _AdvisorSignalCard extends StatelessWidget {
  final _AdvisorSignal signal;

  const _AdvisorSignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      borderColor: signal.color.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: signal.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: signal.color.withOpacity(0.35)),
                ),
                child: Icon(signal.icon, color: signal.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signal.message,
                      style: const TextStyle(
                        color: GameColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _PriorityBadge(priority: signal.priority, color: signal.color),
            ],
          ),
          if (signal.progress != null) ...[
            const SizedBox(height: 14),
            GameProgressBar(
              label: 'Progress',
              valueLabel:
                  signal.valueLabel ?? '${(signal.progress! * 100).round()}%',
              value: signal.progress!,
              color: signal.color,
            ),
          ],
          if (signal.actionLabel != null ||
              signal.route != null ||
              signal.onSecondary != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (signal.actionLabel != null)
                  ElevatedButton.icon(
                    onPressed: signal.onAction ??
                        (signal.route == null
                            ? null
                            : () =>
                                Navigator.pushNamed(context, signal.route!)),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(signal.actionLabel!),
                  ),
                if (signal.secondaryLabel != null && signal.onSecondary != null)
                  TextButton(
                    onPressed: signal.onSecondary,
                    child: Text(signal.secondaryLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestlinePanel extends StatelessWidget {
  final OnboardingQuestline? questline;
  final Set<String> claimingQuestIds;
  final Set<String> skippingQuestIds;
  final Future<void> Function(OnboardingQuest quest) onClaim;
  final Future<void> Function(OnboardingQuest quest) onSkip;

  const _QuestlinePanel({
    required this.questline,
    required this.claimingQuestIds,
    required this.skippingQuestIds,
    required this.onClaim,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final line = questline;
    if (line == null) {
      return const GameEmptyState(
        icon: Icons.tour_outlined,
        message: 'Tutorial progress has not loaded yet.',
      );
    }
    return GamePanel(
      child: Column(
        children: [
          GameProgressBar(
            label: 'Tutorial completion',
            valueLabel: '${line.completedCount}/${line.totalCount}',
            value: line.totalCount <= 0
                ? 0
                : line.completedCount / line.totalCount,
            color: GameColors.cyan,
          ),
          const SizedBox(height: 14),
          ...line.quests.map(
            (quest) => _QuestTile(
              quest: quest,
              isClaiming: claimingQuestIds.contains(quest.questId),
              isSkipping: skippingQuestIds.contains(quest.questId),
              onClaim: () => onClaim(quest),
              onSkip: () => onSkip(quest),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final OnboardingQuest quest;
  final bool isClaiming;
  final bool isSkipping;
  final Future<void> Function() onClaim;
  final Future<void> Function() onSkip;

  const _QuestTile({
    required this.quest,
    required this.isClaiming,
    required this.isSkipping,
    required this.onClaim,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final color = quest.claimed
        ? GameColors.emerald
        : quest.claimable
            ? GameColors.amber
            : GameColors.cyan;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GameColors.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(quest.claimed ? Icons.check_circle : Icons.tour,
                  color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quest.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${quest.currentCount}/${quest.targetCount}',
                style: const TextStyle(color: GameColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quest.claimable ? 'Step complete. Claim reward.' : quest.guidance,
            style: const TextStyle(color: GameColors.textMuted),
          ),
          const SizedBox(height: 8),
          GameProgressBar(
            label: 'Step progress',
            valueLabel: quest.claimed
                ? 'claimed'
                : quest.claimable
                    ? 'ready'
                    : '${(quest.progress * 100).round()}%',
            value: quest.progress,
            color: color,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (quest.claimable)
                ElevatedButton.icon(
                  onPressed: isClaiming ? null : onClaim,
                  icon: isClaiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.card_giftcard),
                  label: Text(isClaiming ? 'Claiming...' : 'Claim'),
                ),
              if (!quest.claimed && !quest.claimable)
                OutlinedButton.icon(
                  onPressed: quest.route == null
                      ? null
                      : () => Navigator.pushNamed(context, quest.route!),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Go'),
                ),
              if (!quest.claimed)
                TextButton(
                  onPressed: isSkipping ? null : onSkip,
                  child: Text(isSkipping ? 'Skipping...' : 'Skip'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyObjectivePanel extends StatelessWidget {
  final DailyObjectivesSummary? summary;
  final Set<String> claimingIds;
  final Future<void> Function(DailyObjective objective) onClaim;

  const _DailyObjectivePanel({
    required this.summary,
    required this.claimingIds,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final objectives = summary?.objectives ?? const <DailyObjective>[];
    if (summary == null) {
      return const GameEmptyState(
        icon: Icons.checklist,
        message: 'Daily objectives have not loaded yet.',
      );
    }
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resets ${DateFormat.MMMd().add_Hm().format(summary!.resetAt.toLocal())}',
            style: const TextStyle(color: GameColors.textMuted),
          ),
          const SizedBox(height: 12),
          ...objectives.map(
            (objective) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GameColors.panelAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: objective.claimable
                      ? GameColors.emerald.withOpacity(0.35)
                      : GameColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    objective.claimed
                        ? Icons.check_circle
                        : objective.claimable
                            ? Icons.card_giftcard
                            : Icons.timelapse,
                    color: objective.claimed
                        ? GameColors.emerald
                        : objective.claimable
                            ? GameColors.amber
                            : GameColors.cyan,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          objective.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${objective.currentCount}/${objective.targetCount} • ${_rewardText(objective.rewards)}',
                          style: const TextStyle(color: GameColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: objective.claimable &&
                            !claimingIds.contains(objective.objectiveId)
                        ? () => onClaim(objective)
                        : null,
                    child: Text(
                      claimingIds.contains(objective.objectiveId)
                          ? 'Claiming...'
                          : objective.claimed
                              ? 'Claimed'
                              : objective.claimable
                                  ? 'Claim'
                                  : 'Pending',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final int priority;
  final Color color;

  const _PriorityBadge({required this.priority, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Text(
        'P$priority',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

List<String> _errors(String? first, String? second, String? third,
    String? fourth, String? fifth, String? sixth, String? seventh) {
  return [
    first,
    second,
    third,
    fourth,
    fifth,
    sixth,
    seventh,
  ].whereType<String>().where((error) => error.isNotEmpty).toList();
}

String _rewardText(PlayerRewards rewards) {
  final parts = <String>[];
  if (rewards.gold > 0) {
    parts.add('${rewards.gold} gold');
  }
  if (rewards.experience > 0) {
    parts.add('${rewards.experience} XP');
  }
  if (rewards.strength > 0) {
    parts.add('${rewards.strength} strength');
  }
  if (rewards.energy > 0) {
    parts.add('${rewards.energy} energy');
  }
  return parts.isEmpty ? 'No reward' : parts.join(' / ');
}

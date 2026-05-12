import 'dart:math';

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BattleReportsPage extends StatefulWidget {
  final User user;
  const BattleReportsPage({super.key, required this.user});

  @override
  State<BattleReportsPage> createState() => _BattleReportsPageState();
}

class _BattleReportsPageState extends State<BattleReportsPage> {
  late final CountryBattlesBloc _battlesBloc;
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;
  late final LoginBloc _loginBloc;
  late final RealtimeUpdatesBloc _realtimeBloc;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _battlesBloc = Provider.of<CountryBattlesBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _realtimeBloc = RealtimeUpdatesBloc();
    _load();
    _startRealtime();
  }

  Future<void> _load() async {
    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    await _battlesBloc.load(widget.user.uid, reportLimit: 50);
  }

  void _startRealtime() {
    _realtimeBloc.setBearerToken(_loginBloc.currentToken);
    _realtimeBloc.start(
      playerId: widget.user.uid,
      chatToId: 'global',
      onUpdate: (update) {
        final battles = update.battles;
        if (battles != null) {
          _battlesBloc.applyRealtimeBattles(battles);
        }
      },
    );
  }

  Future<void> _contribute(CountryBattle battle) async {
    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _battlesBloc.contribute(
      playerId: widget.user.uid,
      battleId: battle.battleId,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      _playerBloc.setBearerToken(_loginBloc.currentToken);
      _inventoryBloc.setBearerToken(_loginBloc.currentToken);
      await Future.wait([
        _playerBloc.loadState(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
        _battlesBloc.loadPlayerReports(widget.user.uid, limit: 50),
      ]);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _battlesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _realtimeBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Battle Reports',
      subtitle: 'War contribution, combat receipts, and campaign impact',
      icon: Icons.receipt_long,
      actions: [
        IconButton(
          tooltip: 'Refresh battle reports',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer<CountryBattlesBloc>(
        builder: (context, bloc, _) {
          final battleList = bloc.battles;
          final reports = bloc.playerCombatReports?.reports ??
              bloc.myCombatReports?.reports ??
              [];
          if (bloc.isLoading && battleList == null && reports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (battleList == null && bloc.error != null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final active = battleList?.activeBattles ?? const <CountryBattle>[];
          final recent = battleList?.recentBattles ?? const <CountryBattle>[];
          final campaigns = bloc.campaigns?.campaigns ?? const <WarCampaign>[];
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (bloc.error != null)
                  GameNotice(
                    icon: Icons.warning_amber,
                    message: bloc.error!,
                    color: GameColors.amber,
                  ),
                if (bloc.lastContribution != null)
                  _ContributionOutcome(result: bloc.lastContribution!),
                _ReportsHero(
                  reports: reports,
                  activeBattleCount: active.length,
                  campaignCount: campaigns.length,
                  updatedAt: bloc.playerCombatReports?.updatedAt ??
                      battleList?.updatedAt ??
                      DateTime.now().toUtc(),
                ),
                const SizedBox(height: 12),
                const GameSectionTitle(
                  title: 'Contribution console',
                  subtitle:
                      'Active wars use the persisted battle contribution endpoint and generate combat reports.',
                ),
                if (active.isEmpty)
                  const GameEmptyState(
                    icon: Icons.flag_outlined,
                    message:
                        'No active battles are open. Review your archived reports below.',
                  )
                else
                  ...active.map(
                    (battle) => _ActiveBattleCard(
                      battle: battle,
                      isContributing:
                          bloc.contributingBattleIds.contains(battle.battleId),
                      onContribute: () => _contribute(battle),
                      onWarRoom: () => Navigator.pushNamed(
                        context,
                        '/country-battles',
                      ),
                    ),
                  ),
                const GameSectionTitle(
                  title: 'My combat dossier',
                  subtitle:
                      'Detailed receipts with damage, rewards, weapon wear, scores, and campaign phase snapshots.',
                ),
                if (reports.isEmpty)
                  const GameEmptyState(
                    icon: Icons.receipt_long_outlined,
                    message:
                        'No combat reports yet. Contribute to a country battle to generate one.',
                  )
                else
                  ...reports
                      .take(30)
                      .map((report) => _CombatReportCard(report: report)),
                const GameSectionTitle(
                  title: 'Country impact board',
                  subtitle:
                      'Live country damage, victories, and contribution score.',
                ),
                if (bloc.countryLeaderboard == null ||
                    bloc.countryLeaderboard!.entries.isEmpty)
                  const GameEmptyState(
                    icon: Icons.leaderboard_outlined,
                    message:
                        'No country contribution leaderboard is available yet.',
                  )
                else
                  _CountryImpactPanel(leaderboard: bloc.countryLeaderboard!),
                const GameSectionTitle(
                  title: 'Resolved battle history',
                  subtitle:
                      'Recent completed fronts remain visible as persisted war history.',
                ),
                if (recent.isEmpty)
                  const GameEmptyState(
                    icon: Icons.history,
                    message: 'No resolved country battles are available yet.',
                  )
                else
                  ...recent
                      .take(8)
                      .map((battle) => _BattleHistoryCard(battle: battle)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportsHero extends StatelessWidget {
  final List<CombatReport> reports;
  final int activeBattleCount;
  final int campaignCount;
  final DateTime updatedAt;

  const _ReportsHero({
    required this.reports,
    required this.activeBattleCount,
    required this.campaignCount,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final totalDamage =
        reports.fold<int>(0, (sum, report) => sum + report.damage);
    final gold = reports.fold<int>(0, (sum, report) => sum + report.goldReward);
    final xp =
        reports.fold<int>(0, (sum, report) => sum + report.experienceReward);
    final wins = reports.where((report) => report.won).length;
    return GameHero(
      eyebrow: 'War contribution ledger',
      title: 'Combat report dossier',
      subtitle:
          'Every entry is produced by backend battle contribution flows and records score impact, rewards, weapon durability, and campaign phase snapshots.',
      icon: Icons.military_tech,
      accent: GameColors.crimson,
      stats: [
        GameStat(
          label: 'reports',
          value: Utils.number(reports.length),
          icon: Icons.receipt_long,
          color: GameColors.cyan,
        ),
        GameStat(
          label: 'damage',
          value: Utils.number(totalDamage),
          icon: Icons.local_fire_department,
          color: GameColors.crimson,
        ),
        GameStat(
          label: 'wins',
          value: Utils.number(wins),
          icon: Icons.emoji_events,
          color: GameColors.amber,
        ),
        GameStat(
          label: 'rewards',
          value: '${Utils.number(gold)}g / ${Utils.number(xp)} XP',
          icon: Icons.card_giftcard,
          color: GameColors.emerald,
        ),
        GameStat(
          label: 'active fronts',
          value: Utils.number(activeBattleCount),
          icon: Icons.flag,
          color: GameColors.crimson,
        ),
        GameStat(
          label: 'campaigns',
          value: Utils.number(campaignCount),
          icon: Icons.account_tree,
          color: GameColors.violet,
        ),
      ],
    );
  }
}

class _ActiveBattleCard extends StatelessWidget {
  final CountryBattle battle;
  final bool isContributing;
  final Future<void> Function() onContribute;
  final VoidCallback onWarRoom;

  const _ActiveBattleCard({
    required this.battle,
    required this.isContributing,
    required this.onContribute,
    required this.onWarRoom,
  });

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      borderColor: GameColors.crimson.withOpacity(0.36),
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
                  color: GameColors.crimson.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: GameColors.crimson,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      battle.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${battle.attackerCountryName} attacks ${battle.defenderCountryName} in ${battle.regionName}',
                      style: const TextStyle(color: GameColors.textMuted),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: battle.status, color: GameColors.crimson),
            ],
          ),
          const SizedBox(height: 14),
          GameProgressBar(
            label: battle.attackerCountryCode,
            valueLabel:
                '${Utils.number(battle.attackerScore)} / ${Utils.number(battle.targetScore)}',
            value: battle.attackerProgress,
            color: GameColors.crimson,
          ),
          const SizedBox(height: 10),
          GameProgressBar(
            label: battle.defenderCountryCode,
            valueLabel:
                '${Utils.number(battle.defenderScore)} / ${Utils.number(battle.targetScore)}',
            value: battle.defenderProgress,
            color: GameColors.cyan,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GameStatPill(
                stat: GameStat(
                  label: 'rounds',
                  value: Utils.number(battle.rounds),
                  icon: Icons.repeat,
                  color: GameColors.violet,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'ends',
                  value: DateFormat.MMMd()
                      .add_Hm()
                      .format(battle.endsAt.toLocal()),
                  icon: Icons.schedule,
                  color: GameColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: isContributing ? null : onContribute,
                icon: isContributing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flash_on),
                label: Text(isContributing ? 'Contributing...' : 'Contribute'),
              ),
              OutlinedButton.icon(
                onPressed: onWarRoom,
                icon: const Icon(Icons.map),
                label: const Text('War room'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CombatReportCard extends StatelessWidget {
  final CombatReport report;

  const _CombatReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final sideColor =
        report.side == 'attacker' ? GameColors.crimson : GameColors.cyan;
    final weaponText = report.hasWeapon
        ? '${report.weaponName} ${report.weaponDurabilityBefore ?? '?'} -> ${report.weaponDurabilityAfter ?? '?'}'
        : 'Unarmed';
    return GamePanel(
      borderColor: sideColor.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: sideColor,
                foregroundColor: GameColors.background,
                child: Icon(
                  report.side == 'attacker' ? Icons.north_east : Icons.shield,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.battleName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${report.countryName} (${report.countryCode}) • ${DateFormat.yMMMd().add_Hm().format(report.createdAt.toLocal())}',
                      style: const TextStyle(color: GameColors.textMuted),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: report.won ? 'won' : report.fightWinner,
                color: report.won ? GameColors.emerald : GameColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GameStatPill(
                stat: GameStat(
                  label: 'damage',
                  value: Utils.number(report.damage),
                  icon: Icons.local_fire_department,
                  color: GameColors.crimson,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'energy',
                  value: Utils.number(report.energySpent),
                  icon: Icons.bolt,
                  color: GameColors.amber,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'rewards',
                  value:
                      '${Utils.number(report.goldReward)}g / ${Utils.number(report.experienceReward)} XP',
                  icon: Icons.card_giftcard,
                  color: GameColors.emerald,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'rounds',
                  value:
                      '${report.fightRoundsCompleted}/${report.fightRoundsRequested}',
                  icon: Icons.repeat,
                  color: GameColors.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ScoreSnapshot(report: report),
          const SizedBox(height: 12),
          _MetaLine(
            icon: Icons.handyman,
            label: 'Weapon',
            value:
                '$weaponText${report.weaponDurabilityDamage > 0 ? ' (-${report.weaponDurabilityDamage})' : ''}',
            color: GameColors.violet,
          ),
          _MetaLine(
            icon: Icons.map,
            label: 'Country impact',
            value:
                '${report.attackerCountryCode} ${Utils.number(report.attackerScoreAfter)} - ${Utils.number(report.defenderScoreAfter)} ${report.defenderCountryCode}',
            color: GameColors.cyan,
          ),
          if (report.campaignName != null)
            _MetaLine(
              icon: Icons.account_tree,
              label: 'Campaign',
              value: report.campaignName!,
              color: GameColors.amber,
            ),
          if (report.phaseSnapshots.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Phase snapshots',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            ...report.phaseSnapshots.take(3).map(
                  (phase) => _PhaseSnapshotLine(phase: phase),
                ),
          ],
        ],
      ),
    );
  }
}

class _ScoreSnapshot extends StatelessWidget {
  final CombatReport report;

  const _ScoreSnapshot({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GameProgressBar(
          label: report.attackerCountryCode,
          valueLabel:
              '${Utils.number(report.attackerScoreAfter)} / ${Utils.number(report.targetScore)}',
          value: report.targetScore <= 0
              ? 0
              : (report.attackerScoreAfter / report.targetScore)
                  .clamp(0, 1)
                  .toDouble(),
          color: GameColors.crimson,
        ),
        const SizedBox(height: 10),
        GameProgressBar(
          label: report.defenderCountryCode,
          valueLabel:
              '${Utils.number(report.defenderScoreAfter)} / ${Utils.number(report.targetScore)}',
          value: report.targetScore <= 0
              ? 0
              : (report.defenderScoreAfter / report.targetScore)
                  .clamp(0, 1)
                  .toDouble(),
          color: GameColors.cyan,
        ),
      ],
    );
  }
}

class _PhaseSnapshotLine extends StatelessWidget {
  final CombatReportPhase phase;

  const _PhaseSnapshotLine({required this.phase});

  @override
  Widget build(BuildContext context) {
    final total = phase.attackerDamage + phase.defenderDamage;
    final progress = phase.targetDamage <= 0
        ? 0.0
        : (total / phase.targetDamage).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GameProgressBar(
        label: '#${phase.phaseNumber} ${phase.name}',
        valueLabel:
            '${Utils.number(total)} / ${Utils.number(phase.targetDamage)}',
        value: progress,
        color: phase.status == 'completed'
            ? GameColors.emerald
            : GameColors.violet,
      ),
    );
  }
}

class _CountryImpactPanel extends StatelessWidget {
  final CountryBattleLeaderboard leaderboard;

  const _CountryImpactPanel({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        children: leaderboard.entries.take(8).map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GameColors.panelAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GameColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      entry.rank <= 3 ? GameColors.amber : GameColors.panel,
                  foregroundColor:
                      entry.rank <= 3 ? GameColors.background : Colors.white,
                  child: Text('#${entry.rank}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.countryName} (${entry.countryCode})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${Utils.number(entry.totalDamage)} damage • ${entry.contributionCount} attacks • ${entry.victoryCount} wins',
                        style: const TextStyle(color: GameColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  Utils.number(entry.score),
                  style: const TextStyle(
                    color: GameColors.amber,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BattleHistoryCard extends StatelessWidget {
  final CountryBattle battle;

  const _BattleHistoryCard({required this.battle});

  @override
  Widget build(BuildContext context) {
    final winner = battle.winnerCountryName ?? 'undecided';
    return GamePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history, color: GameColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  battle.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${battle.attackerCountryCode} ${Utils.number(battle.attackerScore)} - ${Utils.number(battle.defenderScore)} ${battle.defenderCountryCode} • Winner: $winner',
                  style: const TextStyle(color: GameColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionOutcome extends StatelessWidget {
  final BattleContributionResult result;

  const _ContributionOutcome({required this.result});

  @override
  Widget build(BuildContext context) {
    final report = result.report;
    return GameNotice(
      icon: result.completed ? Icons.verified : Icons.info_outline,
      message:
          '${result.message} Damage ${Utils.number(result.fight.attackerDamage)}. ${report == null ? 'No report returned.' : 'Report ${report.reportId} recorded at ${report.scoreAfter}.'}',
      color: result.completed ? GameColors.emerald : GameColors.amber,
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetaLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: GameColors.textMuted),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: GameColors.crimson, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
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

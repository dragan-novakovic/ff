import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkforcePage extends StatefulWidget {
  final User user;
  const WorkforcePage({super.key, required this.user});

  @override
  State<WorkforcePage> createState() => _WorkforcePageState();
}

class _WorkforcePageState extends State<WorkforcePage> {
  late final WorkforceBloc _workforceBloc;
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;

  @override
  void initState() {
    super.initState();
    _workforceBloc = Provider.of<WorkforceBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _workforceBloc.setBearerToken(_loginBloc.currentToken);
    await _workforceBloc.load();
  }

  Future<void> _work(CompanyJobPosting job) async {
    _workforceBloc.setBearerToken(_loginBloc.currentToken);
    final idempotencyKey =
        'workforce-${job.jobId}-${DateTime.now().microsecondsSinceEpoch}';
    final result = await _workforceBloc.work(
      playerId: widget.user.uid,
      companyId: job.companyId,
      jobId: job.jobId,
      idempotencyKey: idempotencyKey,
    );
    if (result != null) {
      _playerBloc.setBearerToken(_loginBloc.currentToken);
      await _playerBloc.loadState(widget.user.uid);
    }
    final message = result?.message ?? _workforceBloc.error;
    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Labor Exchange',
      subtitle: 'Company jobs, wages, energy, and production pressure',
      icon: Icons.engineering,
      body: Consumer<WorkforceBloc>(
        builder: (context, bloc, _) {
          final jobs = bloc.jobMarket?.jobs ?? [];
          if (bloc.isLoading && bloc.jobMarket == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeJobs = jobs.where((job) => job.isActive).length;
          final totalWages =
              jobs.fold<int>(0, (sum, job) => sum + job.wageGold);
          final totalDemand =
              jobs.fold<int>(0, (sum, job) => sum + job.dailyLimit);

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GameHero(
                  eyebrow: 'Economy Loop',
                  title: 'Work for player companies',
                  subtitle:
                      'Jobs pay from company wallets, credit your wallet, spend energy, and generate labor credits that feed production upgrades.',
                  icon: Icons.payments_outlined,
                  accent: GameColors.emerald,
                  stats: [
                    GameStat(
                      label: 'open contracts',
                      value: activeJobs.toString(),
                      icon: Icons.work_outline,
                      color: GameColors.emerald,
                    ),
                    GameStat(
                      label: 'listed wages',
                      value: Utils.number(totalWages),
                      icon: Icons.attach_money,
                      color: GameColors.amber,
                    ),
                    GameStat(
                      label: 'daily slots',
                      value: Utils.number(totalDemand),
                      icon: Icons.groups_2_outlined,
                      color: GameColors.cyan,
                    ),
                  ],
                ),
                if (bloc.error != null)
                  GameNotice(
                    icon: Icons.warning_amber,
                    message: bloc.error!,
                    color: GameColors.amber,
                  ),
                if (bloc.lastWork != null)
                  _WorkResultPanel(result: bloc.lastWork!),
                const GameSectionTitle(
                  title: 'Company job board',
                  subtitle:
                      'Pick the best wage-to-energy contract before daily slots run out.',
                ),
                if (jobs.isEmpty)
                  const GameEmptyState(
                    icon: Icons.work_off_outlined,
                    message: 'No active jobs are posted right now.',
                  )
                else
                  ...jobs.map(
                    (job) => _WorkforceJobCard(
                      job: job,
                      isWorking: bloc.workingJobIds.contains(job.jobId),
                      onWork: () => _work(job),
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

class _WorkResultPanel extends StatelessWidget {
  final CompanyWorkResult result;

  const _WorkResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final record = result.workRecord;
    return GameNotice(
      icon: result.completed ? Icons.check_circle : Icons.info_outline,
      color: result.completed ? GameColors.emerald : GameColors.amber,
      message:
          '${result.message} Net wage ${Utils.number(record.netWageGold)} gold, tax ${Utils.number(record.taxGold)}, +${Utils.number(record.productivityReward)} labor credit.',
    );
  }
}

class _WorkforceJobCard extends StatelessWidget {
  final CompanyJobPosting job;
  final bool isWorking;
  final VoidCallback onWork;

  const _WorkforceJobCard({
    required this.job,
    required this.isWorking,
    required this.onWork,
  });

  @override
  Widget build(BuildContext context) {
    final canWork = job.isActive && !job.isDailyLimitReached && !isWorking;
    final fill = job.dailyLimit <= 0
        ? 0.0
        : (job.todayWorkCount / job.dailyLimit).clamp(0, 1).toDouble();

    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: GameColors.emerald.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: GameColors.emerald.withOpacity(0.35),
                  ),
                ),
                child: const Icon(Icons.factory, color: GameColors.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      job.companyName.isEmpty ? job.companyId : job.companyName,
                      style: const TextStyle(color: GameColors.textMuted),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                text: job.isDailyLimitReached ? 'filled' : job.status,
                color: job.isDailyLimitReached
                    ? GameColors.amber
                    : GameColors.emerald,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.description,
            style: const TextStyle(color: GameColors.textMuted, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GameStatPill(
                stat: GameStat(
                  label: 'net wage source',
                  value: '${Utils.number(job.wageGold)} gold',
                  icon: Icons.attach_money,
                  color: GameColors.amber,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'energy cost',
                  value: Utils.number(job.requiredEnergy),
                  icon: Icons.bolt,
                  color: GameColors.cyan,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'labor credit',
                  value: '+${Utils.number(job.productivityReward)}',
                  icon: Icons.handyman_outlined,
                  color: GameColors.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GameProgressBar(
            label: 'Daily labor demand',
            valueLabel: '${job.todayWorkCount}/${job.dailyLimit}',
            value: fill,
            color: job.isDailyLimitReached ? GameColors.amber : GameColors.cyan,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: canWork ? onWork : null,
              icon: isWorking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.work),
              label: Text(isWorking
                  ? 'Working...'
                  : job.isDailyLimitReached
                      ? 'Limit reached'
                      : 'Work shift'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

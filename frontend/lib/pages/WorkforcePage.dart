import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
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

  @override
  void initState() {
    super.initState();
    _workforceBloc = Provider.of<WorkforceBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Workforce Market')),
      body: Consumer<WorkforceBloc>(
        builder: (context, bloc, _) {
          final jobs = bloc.jobMarket?.jobs ?? [];
          if (bloc.isLoading && bloc.jobMarket == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.work, color: Colors.indigo),
                    title: const Text('Open company jobs'),
                    subtitle: const Text(
                      'Real posted jobs pay from company wallets, credit player wallets, and add company labor credits.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Refresh',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                if (bloc.error != null)
                  Card(
                    color: Colors.orange.withOpacity(0.12),
                    child: ListTile(
                      leading:
                          const Icon(Icons.warning_amber, color: Colors.orange),
                      title: Text(bloc.error!),
                    ),
                  ),
                if (bloc.lastWork != null)
                  Card(
                    color: Colors.green.withOpacity(0.12),
                    child: ListTile(
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(bloc.lastWork!.message),
                    ),
                  ),
                if (jobs.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.work_outline),
                      title: Text('No active jobs are posted right now.'),
                    ),
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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.payments, color: Colors.green),
        title: Text(job.title),
        subtitle: Text(
          '${job.companyName} • ${job.description}\n'
          '${Utils.number(job.wageGold)} gold wage • '
          '${job.requiredEnergy} energy required • '
          '${job.todayWorkCount}/${job.dailyLimit} today • '
          '+${job.productivityReward} labor credit',
        ),
        isThreeLine: true,
        trailing: ElevatedButton.icon(
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
                  : 'Work'),
        ),
      ),
    );
  }
}

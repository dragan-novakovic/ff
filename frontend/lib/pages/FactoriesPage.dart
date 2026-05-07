import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart' hide PlayerFactory;
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FactoriesPage extends StatefulWidget {
  final User user;
  const FactoriesPage({super.key, required this.user});

  @override
  State<FactoriesPage> createState() => _FactoriesPageState();
}

class _FactoriesPageState extends State<FactoriesPage> {
  late final FactoriesBloc _factoriesBloc;
  late final InventoryBloc _inventoryBloc;
  late final LoginBloc _loginBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;
  late final RealtimeUpdatesBloc _realtimeBloc;

  @override
  void initState() {
    super.initState();
    _factoriesBloc = Provider.of<FactoriesBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _realtimeBloc = RealtimeUpdatesBloc();
    _load();
    _startRealtime();
  }

  Future<void> _load() async {
    _factoriesBloc.setBearerToken(_loginBloc.currentToken);
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _factoriesBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
    ]);
  }

  void _startRealtime() {
    _realtimeBloc.setBearerToken(_loginBloc.currentToken);
    _realtimeBloc.start(
      playerId: widget.user.uid,
      chatToId: 'global',
      onUpdate: (update) {
        final production = update.production;
        if (production != null) {
          _factoriesBloc.applyRealtimeProduction(production);
        }
      },
    );
  }

  Future<void> _produce(PlayerFactory factory) async {
    _factoriesBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result =
        await _factoriesBloc.produce(widget.user.uid, factory.factoryId);
    if (result != null) {
      await Future.wait([
        _factoriesBloc.load(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
        _onboardingBloc.load(widget.user.uid),
      ]);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _factoriesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _claim(ProductionJob job) async {
    _factoriesBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _factoriesBloc.claim(widget.user.uid, job.jobId);
    if (result != null) {
      await Future.wait([
        _factoriesBloc.load(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
      ]);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _factoriesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _upgrade(PlayerFactory factory) async {
    _factoriesBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result =
        await _factoriesBloc.upgrade(widget.user.uid, factory.factoryId);
    if (result != null) {
      await Future.wait([
        _factoriesBloc.load(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
      ]);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _factoriesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _realtimeBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Factories')),
      body: Consumer<FactoriesBloc>(
        builder: (context, bloc, _) {
          final portfolio = bloc.portfolio;
          if (bloc.isLoading && portfolio == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && portfolio == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (portfolio == null) {
            return _ErrorState(
              message: 'Factories have not loaded yet.',
              onRetry: _load,
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OnboardingGuidanceCard(
                  questline: context.watch<OnboardingQuestlineBloc>().questline,
                  route: '/factories',
                ),
                if (bloc.lastProduction != null)
                  _ProductionNotice(result: bloc.lastProduction!),
                if (bloc.lastClaim != null)
                  _ProductionClaimNotice(result: bloc.lastClaim!),
                if (bloc.lastUpgrade != null)
                  _FactoryUpgradeNotice(result: bloc.lastUpgrade!),
                ...portfolio.factories.map(
                  (factory) => _FactoryCard(
                    factory: factory,
                    jobs: (bloc.productionJobs?.forFactory(factory.factoryId) ??
                            const <ProductionJob>[])
                        .where((job) => job.isVisibleOnFactory)
                        .toList(),
                    quote: bloc.upgradeQuotes[factory.factoryId],
                    isProducing:
                        bloc.producingFactoryIds.contains(factory.factoryId),
                    claimingJobIds: bloc.claimingJobIds,
                    isUpgrading:
                        bloc.upgradingFactoryIds.contains(factory.factoryId),
                    onProduce: () => _produce(factory),
                    onClaim: _claim,
                    onUpgrade: () => _upgrade(factory),
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

class _FactoryUpgradeNotice extends StatelessWidget {
  final FactoryUpgradeGatewayResult result;
  const _FactoryUpgradeNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.upgrade : Icons.info_outline,
          color: result.completed ? Colors.green : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: Text(
          '${result.upgrade.factory.name} is now level ${result.upgrade.factory.level}. Wallet: ${Utils.number(result.inventory.walletGold)} gold.',
        ),
      ),
    );
  }
}

class _ProductionNotice extends StatelessWidget {
  final ProductionResult result;
  const _ProductionNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    final job = result.job;
    final bonus = result.appliedBonus ?? job?.appliedBonus;
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.blue.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.check_circle : Icons.pending_actions,
          color: result.completed ? Colors.green : Colors.blue,
        ),
        title: Text(result.message),
        subtitle: Text(
          job == null
              ? 'Produced ${result.producedQuantity} ${result.producedItemId}. ${result.note}'
              : 'Job ${job.jobId}: ${job.inputQuantity} ${job.inputItemName} → ${job.outputQuantity} ${job.outputItemName}. ${result.note}',
        ),
        trailing: bonus == null ? null : _ProductionBonusChip(bonus: bonus),
      ),
    );
  }
}

class _ProductionClaimNotice extends StatelessWidget {
  final ProductionClaimResult result;
  const _ProductionClaimNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: const Icon(Icons.inventory_2, color: Colors.green),
        title: Text(result.message),
        subtitle: Text(
          'Claimed ${result.claim.job.outputQuantity} ${result.claim.job.outputItemName}. Completed runs: ${result.claim.productionCount}.',
        ),
      ),
    );
  }
}

class _FactoryCard extends StatelessWidget {
  final PlayerFactory factory;
  final List<ProductionJob> jobs;
  final FactoryUpgradeQuote? quote;
  final bool isProducing;
  final Set<String> claimingJobIds;
  final bool isUpgrading;
  final VoidCallback onProduce;
  final ValueChanged<ProductionJob> onClaim;
  final VoidCallback onUpgrade;
  const _FactoryCard({
    required this.factory,
    required this.jobs,
    required this.quote,
    required this.isProducing,
    required this.claimingJobIds,
    required this.isUpgrading,
    required this.onProduce,
    required this.onClaim,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.factory, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${factory.name} L${factory.level}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(factory.category),
            const SizedBox(height: 12),
            Text(
              'Input: ${factory.inputQuantity} ${factory.inputItemId} → Output: ${factory.outputQuantity} ${factory.outputItemId}',
            ),
            if (factory.resourceEffect != null) ...[
              const SizedBox(height: 8),
              _ProductionBonusBanner(bonus: factory.resourceEffect!),
            ],
            const SizedBox(height: 8),
            Text('Completed runs: ${factory.productionCount}'),
            Text(
              'Queue: ${factory.queueDepth}/${factory.maxQueueDepth == 0 ? 3 : factory.maxQueueDepth}',
            ),
            if (factory.cooldownUntil != null)
              Text(
                  'Cooldown: ready ${_formatDateTime(factory.cooldownUntil!)}'),
            const SizedBox(height: 12),
            if (jobs.isNotEmpty) ...[
              _ProductionJobsList(
                jobs: jobs,
                claimingJobIds: claimingJobIds,
                onClaim: onClaim,
              ),
              const SizedBox(height: 12),
            ],
            if (quote != null) _UpgradeCost(quote: quote!),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      factory.canProduce && !isProducing ? onProduce : null,
                  icon: isProducing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(isProducing ? 'Starting...' : 'Start production'),
                ),
                ElevatedButton.icon(
                  onPressed: quote != null && quote!.canUpgrade && !isUpgrading
                      ? onUpgrade
                      : null,
                  icon: isUpgrading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upgrade),
                  label: Text(isUpgrading ? 'Upgrading...' : 'Upgrade'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductionJobsList extends StatelessWidget {
  final List<ProductionJob> jobs;
  final Set<String> claimingJobIds;
  final ValueChanged<ProductionJob> onClaim;
  const _ProductionJobsList({
    required this.jobs,
    required this.claimingJobIds,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Production jobs',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...jobs.map(
          (job) => _ProductionJobTile(
            job: job,
            isClaiming: claimingJobIds.contains(job.jobId),
            onClaim: () => onClaim(job),
          ),
        ),
      ],
    );
  }
}

class _ProductionJobTile extends StatelessWidget {
  final ProductionJob job;
  final bool isClaiming;
  final VoidCallback onClaim;
  const _ProductionJobTile({
    required this.job,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final ready = job.isReady;
    final statusColor = ready ? Colors.green : Colors.blueGrey;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ready ? Colors.green.shade50 : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.hourglass_bottom,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${job.outputQuantity} ${job.outputItemName} • ${job.status}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (ready)
                ElevatedButton.icon(
                  onPressed: isClaiming ? null : onClaim,
                  icon: isClaiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory),
                  label: Text(isClaiming ? 'Claiming...' : 'Claim'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${job.inputQuantity} ${job.inputItemName} → ${job.outputQuantity} ${job.outputItemName}',
          ),
          if (job.appliedBonus != null) ...[
            const SizedBox(height: 8),
            _ProductionBonusBanner(bonus: job.appliedBonus!),
          ],
          if (job.researchDurationReductionPercent > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Research speed bonus: -${job.researchDurationReductionPercent}% duration',
              style: TextStyle(color: Colors.blueGrey.shade700),
            ),
          ],
          const SizedBox(height: 8),
          LinearProgressIndicator(value: job.progress),
          const SizedBox(height: 6),
          Text(_jobTimingText(job)),
        ],
      ),
    );
  }
}

class _UpgradeCost extends StatelessWidget {
  final FactoryUpgradeQuote quote;
  const _UpgradeCost({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Upgrade to L${quote.nextLevel}: ${Utils.number(quote.goldCost)} gold + '
        '${quote.requiredItemQuantity} ${quote.requiredItemName}. '
        'Output becomes ${quote.outputQuantityAfterUpgrade}.',
      ),
    );
  }
}

class _ProductionBonusChip extends StatelessWidget {
  final ProductionBonus bonus;
  const _ProductionBonusChip({required this.bonus});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.public, size: 16),
      label: Text('+${bonus.productionBonusPercent}%'),
    );
  }
}

class _ProductionBonusBanner extends StatelessWidget {
  final ProductionBonus bonus;
  const _ProductionBonusBanner({required this.bonus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.public, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${bonus.resourceName} in ${bonus.sourceRegionName}: +${bonus.productionBonusPercent}% output for ${bonus.itemId}.',
            ),
          ),
        ],
      ),
    );
  }
}

String _jobTimingText(ProductionJob job) {
  if (job.isReady) {
    return 'Ready to claim since ${_formatDateTime(job.completedAt ?? job.completesAt)}.';
  }

  if (job.status == 'queued') {
    return 'Queued: starts ${_formatDateTime(job.startedAt)}, ready ${_formatDateTime(job.completesAt)}.';
  }

  final remaining = job.remaining;
  return 'Cooling down: ready in ${_formatDuration(remaining)} (${_formatDateTime(job.completesAt)}).';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  if (minutes <= 0) {
    return '${seconds}s';
  }
  return '${minutes}m ${seconds}s';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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

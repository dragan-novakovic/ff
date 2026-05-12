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
      backgroundColor: const Color(0xFF08111E),
      appBar: AppBar(
        title: const Text('Factories'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh factories',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
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

          final visibleJobs = bloc.productionJobs?.jobs
                  .where((job) => job.isVisibleOnFactory)
                  .toList() ??
              const <ProductionJob>[];

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                OnboardingGuidanceCard(
                  questline: context.watch<OnboardingQuestlineBloc>().questline,
                  route: '/factories',
                ),
                if (context
                            .watch<OnboardingQuestlineBloc>()
                            .questline
                            ?.currentQuest
                            ?.route ==
                        '/factories' &&
                    context
                            .watch<OnboardingQuestlineBloc>()
                            .questline
                            ?.currentQuest !=
                        null)
                  const SizedBox(height: 16),
                if (bloc.error != null)
                  _FactoriesMessageCard(
                    message: bloc.error!,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                if (bloc.lastProduction != null)
                  _ProductionNotice(result: bloc.lastProduction!),
                if (bloc.lastClaim != null)
                  _ProductionClaimNotice(result: bloc.lastClaim!),
                if (bloc.lastUpgrade != null)
                  _FactoryUpgradeNotice(result: bloc.lastUpgrade!),
                _FactoriesHero(portfolio: portfolio, jobs: visibleJobs),
                const SizedBox(height: 16),
                if (portfolio.factories.isEmpty)
                  const _EmptyFactoriesPanel()
                else
                  ...portfolio.factories.map(
                    (factory) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _FactoryCard(
                        factory: factory,
                        jobs: (bloc.productionJobs
                                    ?.forFactory(factory.factoryId) ??
                                const <ProductionJob>[])
                            .where((job) => job.isVisibleOnFactory)
                            .toList(),
                        quote: bloc.upgradeQuotes[factory.factoryId],
                        isProducing: bloc.producingFactoryIds
                            .contains(factory.factoryId),
                        claimingJobIds: bloc.claimingJobIds,
                        isUpgrading: bloc.upgradingFactoryIds
                            .contains(factory.factoryId),
                        onProduce: () => _produce(factory),
                        onClaim: _claim,
                        onUpgrade: () => _upgrade(factory),
                      ),
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

class _FactoriesHero extends StatelessWidget {
  final FactoryPortfolio portfolio;
  final List<ProductionJob> jobs;

  const _FactoriesHero({required this.portfolio, required this.jobs});

  @override
  Widget build(BuildContext context) {
    final totalLevels =
        portfolio.factories.fold<int>(0, (sum, factory) => sum + factory.level);
    final completedRuns = portfolio.factories
        .fold<int>(0, (sum, factory) => sum + factory.productionCount);
    final readyJobs = jobs.where((job) => job.isReady).length;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1020),
              Color(0xFF1E3A8A),
              Color(0xFF7C2D12),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -28,
              child: Icon(
                Icons.factory,
                size: 178,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -22,
              child: Icon(
                Icons.precision_manufacturing,
                size: 126,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const Spacer(),
                      _NeonPill(
                        label: readyJobs > 0
                            ? '$readyJobs ready'
                            : jobs.isEmpty
                                ? 'Idle'
                                : 'Producing',
                        color: readyJobs > 0
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF67E8F9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Industrial District',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Run factories, monitor production queues, claim finished goods, and invest in upgrades.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroStat(
                        icon: Icons.factory,
                        label: 'Factories',
                        value: portfolio.factories.length.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.trending_up,
                        label: 'Levels',
                        value: totalLevels.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.pending_actions,
                        label: 'Jobs',
                        value: jobs.length.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.inventory_2,
                        label: 'Runs',
                        value: Utils.number(completedRuns),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactoryUpgradeNotice extends StatelessWidget {
  final FactoryUpgradeGatewayResult result;
  const _FactoryUpgradeNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _FactoriesMessageCard(
      message:
          '${result.message} ${result.upgrade.factory.name} is now level ${result.upgrade.factory.level}. Wallet: ${Utils.number(result.inventory.walletGold)} gold.',
      icon: result.completed ? Icons.upgrade : Icons.info_outline,
      color:
          result.completed ? const Color(0xFF22C55E) : const Color(0xFFF97316),
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
    final detail = job == null
        ? 'Produced ${result.producedQuantity} ${result.producedItemId}. ${result.note}'
        : 'Job ${job.jobId}: ${job.inputQuantity} ${job.inputItemName} -> ${job.outputQuantity} ${job.outputItemName}. ${result.note}';
    return _FactoriesMessageCard(
      message: '${result.message} $detail',
      icon: result.completed ? Icons.check_circle : Icons.pending_actions,
      color:
          result.completed ? const Color(0xFF22C55E) : const Color(0xFF38BDF8),
      trailing: bonus == null ? null : _ProductionBonusChip(bonus: bonus),
    );
  }
}

class _ProductionClaimNotice extends StatelessWidget {
  final ProductionClaimResult result;
  const _ProductionClaimNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _FactoriesMessageCard(
      message:
          '${result.message} Claimed ${result.claim.job.outputQuantity} ${result.claim.job.outputItemName}. Completed runs: ${result.claim.productionCount}.',
      icon: Icons.inventory_2,
      color: const Color(0xFF22C55E),
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
    final color = _factoryColor(factory);
    final maxQueue = factory.maxQueueDepth == 0 ? 3 : factory.maxQueueDepth;
    final queueProgress = maxQueue <= 0
        ? 0.0
        : (factory.queueDepth / maxQueue).clamp(0, 1).toDouble();
    final activeJobs = jobs.where((job) => job.isPending).length;
    final readyJobs = jobs.where((job) => job.isReady).length;

    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.42)),
                  ),
                  child: Icon(_factoryIcon(factory), color: color, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              factory.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _NeonPill(
                            label: 'L${factory.level}',
                            color: color,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        factory.category,
                        style: TextStyle(color: Colors.white.withOpacity(0.64)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1728),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(
                        icon: Icons.input,
                        label:
                            '${factory.inputQuantity} ${factory.inputItemId}',
                      ),
                      _MiniStat(
                        icon: Icons.output,
                        label:
                            '${factory.outputQuantity} ${factory.outputItemId}',
                      ),
                      _MiniStat(
                        icon: Icons.timer,
                        label: _formatDuration(
                          Duration(seconds: factory.productionDurationSeconds),
                        ),
                      ),
                      _MiniStat(
                        icon: Icons.done_all,
                        label: '${factory.productionCount} runs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FactoryProgressLine(
                    label: 'Queue',
                    valueLabel: '${factory.queueDepth}/$maxQueue',
                    value: queueProgress,
                    color: color,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _factoryStatusText(factory, activeJobs, readyJobs),
                    style: TextStyle(color: Colors.white.withOpacity(0.66)),
                  ),
                ],
              ),
            ),
            if (factory.resourceEffect != null) ...[
              const SizedBox(height: 12),
              _ProductionBonusBanner(bonus: factory.resourceEffect!),
            ],
            if (jobs.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ProductionJobsList(
                jobs: jobs,
                claimingJobIds: claimingJobIds,
                onClaim: onClaim,
              ),
            ],
            if (quote != null) ...[
              const SizedBox(height: 14),
              _UpgradeCost(quote: quote!),
            ],
            const SizedBox(height: 14),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1728),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pending_actions, color: Color(0xFF67E8F9)),
              SizedBox(width: 8),
              Text(
                'Production queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...jobs.map(
            (job) => _ProductionJobTile(
              job: job,
              isClaiming: claimingJobIds.contains(job.jobId),
              onClaim: () => onClaim(job),
            ),
          ),
        ],
      ),
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
    final statusColor =
        ready ? const Color(0xFF22C55E) : const Color(0xFF38BDF8);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  ready ? Icons.check_circle : Icons.hourglass_bottom,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${job.outputQuantity} ${job.outputItemName} - ${job.status}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(
                icon: Icons.input,
                label: '${job.inputQuantity} ${job.inputItemName}',
              ),
              _MiniStat(
                icon: Icons.output,
                label: '${job.outputQuantity} ${job.outputItemName}',
              ),
              if (job.researchDurationReductionPercent > 0)
                _MiniStat(
                  icon: Icons.science,
                  label: '-${job.researchDurationReductionPercent}% research',
                ),
            ],
          ),
          if (job.appliedBonus != null) ...[
            const SizedBox(height: 10),
            _ProductionBonusBanner(bonus: job.appliedBonus!),
          ],
          const SizedBox(height: 10),
          _FactoryProgressLine(
            label: ready ? 'Output ready' : 'Manufacturing progress',
            valueLabel: '${(job.progress * 100).round()}%',
            value: job.progress,
            color: statusColor,
          ),
          const SizedBox(height: 6),
          Text(
            _jobTimingText(job),
            style: TextStyle(color: Colors.white.withOpacity(0.62)),
          ),
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
    final color =
        quote.canUpgrade ? const Color(0xFF22C55E) : const Color(0xFFF97316);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.upgrade, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Upgrade to L${quote.nextLevel}: ${Utils.number(quote.goldCost)} gold + '
              '${quote.requiredItemQuantity} ${quote.requiredItemName}. '
              'Output becomes ${quote.outputQuantityAfterUpgrade}.',
              style: TextStyle(color: Colors.white.withOpacity(0.74)),
            ),
          ),
        ],
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
      backgroundColor: const Color(0xFF22C55E).withOpacity(0.16),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.public, color: Color(0xFF86EFAC), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${bonus.resourceName} in ${bonus.sourceRegionName}: +${bonus.productionBonusPercent}% output for ${bonus.itemId}.',
              style: TextStyle(color: Colors.white.withOpacity(0.74)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoriesMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  const _FactoriesMessageCard({
    required this.message,
    required this.icon,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyFactoriesPanel extends StatelessWidget {
  const _EmptyFactoriesPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.factory, color: Color(0xFF67E8F9), size: 54),
            const SizedBox(height: 14),
            const Text(
              'No factories online',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Acquire or build factories to start production chains.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.66)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.68), size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.74)),
          ),
        ],
      ),
    );
  }
}

class _NeonPill extends StatelessWidget {
  final String label;
  final Color color;

  const _NeonPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.72)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FactoryProgressLine extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  const _FactoryProgressLine({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(color: Colors.white.withOpacity(0.66)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 9,
            backgroundColor: Colors.white.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

String _factoryStatusText(
  PlayerFactory factory,
  int activeJobs,
  int readyJobs,
) {
  if (readyJobs > 0) {
    return '$readyJobs job(s) ready to claim.';
  }
  if (activeJobs > 0) {
    return '$activeJobs job(s) currently manufacturing.';
  }
  if (!factory.canProduce && factory.cooldownUntil != null) {
    return 'Cooldown: ready ${_formatDateTime(factory.cooldownUntil!)}.';
  }
  if (!factory.canProduce) {
    return 'Production is currently unavailable.';
  }
  return 'Production line is ready.';
}

IconData _factoryIcon(PlayerFactory factory) {
  final category = factory.category.toLowerCase();
  if (category.contains('food') || factory.outputItemId.contains('food')) {
    return Icons.restaurant;
  }
  if (category.contains('weapon') || factory.outputItemId.contains('weapon')) {
    return Icons.gpp_good;
  }
  if (category.contains('raw') || category.contains('resource')) {
    return Icons.grass;
  }
  return Icons.factory;
}

Color _factoryColor(PlayerFactory factory) {
  final category = factory.category.toLowerCase();
  if (category.contains('food') || factory.outputItemId.contains('food')) {
    return const Color(0xFF22C55E);
  }
  if (category.contains('weapon') || factory.outputItemId.contains('weapon')) {
    return const Color(0xFFF97316);
  }
  if (category.contains('raw') || category.contains('resource')) {
    return const Color(0xFFA3E635);
  }
  return const Color(0xFF38BDF8);
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
        child: Card(
          color: const Color(0xFF0F2136),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
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
        ),
      ),
    );
  }
}

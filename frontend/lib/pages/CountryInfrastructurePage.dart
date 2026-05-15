import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CountryInfrastructurePage extends StatefulWidget {
  final User user;

  const CountryInfrastructurePage({super.key, required this.user});

  @override
  State<CountryInfrastructurePage> createState() =>
      _CountryInfrastructurePageState();
}

class _CountryInfrastructurePageState extends State<CountryInfrastructurePage> {
  late final LoginBloc _loginBloc;
  late final WorldBloc _worldBloc;
  late final InventoryBloc _inventoryBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _worldBloc = Provider.of<WorldBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _worldBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _worldBloc.loadInfrastructure(widget.user.uid),
      _inventoryBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _contribute(CountryInfrastructureProject project) async {
    final goldController = TextEditingController(text: '0');
    final itemController = TextEditingController(text: '0');
    final item = _inventoryBloc.inventory?.items.firstWhere(
      (candidate) => candidate.itemId == project.targetItemId,
      orElse: () => InventoryItem(
        itemId: project.targetItemId,
        name: project.targetItemName,
        category: project.targetItemCategory,
        quantity: 0,
        description: '',
      ),
    );

    final result = await showDialog<CountryInfrastructureContributionResult?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GameColors.panel,
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
          contentTextStyle: const TextStyle(color: GameColors.textMuted),
          title: Text('Support ${project.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.description),
              const SizedBox(height: 12),
              Text(
                'Wallet: ${_formatNumber(_inventoryBloc.inventory?.walletGold ?? 0)} gold',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Available ${project.targetItemName}: ${_formatNumber(item?.quantity ?? 0)}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: goldController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Gold contribution',
                  prefixIcon: Icon(Icons.monetization_on),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${project.targetItemName} contribution',
                  prefixIcon: const Icon(Icons.inventory_2),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final gold = int.tryParse(goldController.text.trim()) ?? 0;
                final items = int.tryParse(itemController.text.trim()) ?? 0;
                if (gold <= 0 && items <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Contribute gold or project materials.'),
                    ),
                  );
                  return;
                }

                _worldBloc.setBearerToken(_loginBloc.currentToken);
                final contribution = await _worldBloc.contributeInfrastructure(
                  playerId: widget.user.uid,
                  countryId: project.countryId,
                  projectId: project.projectId,
                  goldAmount: gold,
                  itemQuantity: items,
                  itemId: project.targetItemId,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(contribution);
                }
              },
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Contribute'),
            ),
          ],
        );
      },
    );

    goldController.dispose();
    itemController.dispose();

    if (result != null) {
      await _inventoryBloc.load(widget.user.uid);
    }

    if (!mounted) {
      return;
    }

    final message = result?.message ?? _worldBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Infrastructure Projects',
      subtitle: 'Fund public upgrades that improve your country bonuses',
      icon: Icons.construction,
      actions: [
        IconButton(
          tooltip: 'Refresh infrastructure',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer2<WorldBloc, InventoryBloc>(
        builder: (context, bloc, inventoryBloc, _) {
          if (bloc.isLoading && bloc.infrastructure == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.infrastructure == null) {
            return _InfrastructureErrorState(
              message: bloc.error!,
              onRetry: _load,
            );
          }

          final infrastructure = bloc.infrastructure;
          if (bloc.citizenship == null || infrastructure == null) {
            return _NoCitizenshipState(onChooseCountry: () {
              Navigator.of(context).pushNamed('/world').then((_) => _load());
            });
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: _InfrastructureBoard(
              infrastructure: infrastructure,
              inventory: inventoryBloc.inventory,
              isContributing: bloc.isContributingInfrastructure,
              onContribute: _contribute,
            ),
          );
        },
      ),
    );
  }
}

class _NoCitizenshipState extends StatelessWidget {
  final VoidCallback onChooseCountry;

  const _NoCitizenshipState({required this.onChooseCountry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const GameHero(
          eyebrow: 'No citizenship',
          title: 'Join a country to build public infrastructure',
          subtitle:
              'Infrastructure projects are funded by citizens and apply bonuses to the whole country.',
          icon: Icons.public_off,
          accent: GameColors.amber,
          stats: [
            GameStat(
              label: 'status',
              value: 'unassigned',
              icon: Icons.person_search,
              color: GameColors.amber,
            ),
          ],
        ),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick a country before contributing gold or materials.',
                style: TextStyle(color: GameColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onChooseCountry,
                icon: const Icon(Icons.flag),
                label: const Text('Choose citizenship'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfrastructureBoard extends StatelessWidget {
  final CountryInfrastructure infrastructure;
  final InventorySummary? inventory;
  final bool isContributing;
  final ValueChanged<CountryInfrastructureProject> onContribute;

  const _InfrastructureBoard({
    required this.infrastructure,
    required this.inventory,
    required this.isContributing,
    required this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final totalBonus = infrastructure.projects.fold<int>(
      0,
      (total, project) => total + project.activeBonusPercent,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GameHero(
          eyebrow: infrastructure.code,
          title: '${infrastructure.name} public works',
          subtitle: infrastructure.contributionMessage,
          icon: Icons.construction,
          accent: GameColors.amber,
          stats: [
            GameStat(
              label: 'projects',
              value: infrastructure.projects.length.toString(),
              icon: Icons.domain_add,
              color: GameColors.amber,
            ),
            GameStat(
              label: 'active bonus',
              value: '+$totalBonus%',
              icon: Icons.trending_up,
              color: GameColors.emerald,
            ),
            GameStat(
              label: 'recent gifts',
              value: infrastructure.recentContributions.length.toString(),
              icon: Icons.receipt_long,
              color: GameColors.cyan,
            ),
          ],
        ),
        if (inventory != null) ...[
          GamePanel(
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: GameColors.amber),
                const SizedBox(width: 12),
                Text(
                  '${_formatNumber(inventory!.walletGold)} gold available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
        ...infrastructure.projects.map(
          (project) => _InfrastructureProjectCard(
            project: project,
            inventory: inventory,
            canContribute: infrastructure.canContribute,
            isContributing: isContributing,
            onContribute: () => onContribute(project),
          ),
        ),
        _RecentContributions(contributions: infrastructure.recentContributions),
      ],
    );
  }
}

class _InfrastructureProjectCard extends StatelessWidget {
  final CountryInfrastructureProject project;
  final InventorySummary? inventory;
  final bool canContribute;
  final bool isContributing;
  final VoidCallback onContribute;

  const _InfrastructureProjectCard({
    required this.project,
    required this.inventory,
    required this.canContribute,
    required this.isContributing,
    required this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final owned = inventory?.items
            .where((item) => item.itemId == project.targetItemId)
            .fold<int>(0, (total, item) => total + item.quantity) ??
        0;

    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: GameColors.amber.withOpacity(0.15),
                child: Icon(_iconForBonus(project.bonusType),
                    color: GameColors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description,
                      style: const TextStyle(color: GameColors.textMuted),
                    ),
                  ],
                ),
              ),
              _ProjectLevelBadge(project: project),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressLine(
            label: 'Gold',
            value: project.goldProgress,
            text:
                '${_formatNumber(project.contributedGold)} / ${_formatNumber(project.targetGold)}',
            color: GameColors.amber,
          ),
          const SizedBox(height: 12),
          _ProgressLine(
            label: project.targetItemName,
            value: project.itemProgress,
            text:
                '${_formatNumber(project.contributedItemQuantity)} / ${_formatNumber(project.targetItemQuantity)}',
            color: GameColors.cyan,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.auto_graph,
                text:
                    '${project.bonusLabel}: +${project.activeBonusPercent}% active',
              ),
              _InfoPill(
                icon: Icons.add_chart,
                text: '+${project.bonusPercentPerLevel}% per level',
              ),
              _InfoPill(
                icon: Icons.inventory_2,
                text:
                    'You own ${_formatNumber(owned)} ${project.targetItemName}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: canContribute && !isContributing ? onContribute : null,
              icon: isContributing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volunteer_activism),
              label: const Text('Contribute'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectLevelBadge extends StatelessWidget {
  final CountryInfrastructureProject project;

  const _ProjectLevelBadge({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.emerald.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GameColors.emerald.withOpacity(0.35)),
      ),
      child: Text(
        'Level ${project.level}',
        style: const TextStyle(
          color: GameColors.emerald,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final double value;
  final String text;
  final Color color;

  const _ProgressLine({
    required this.label,
    required this.value,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(text, style: const TextStyle(color: GameColors.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: GameColors.textMuted),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: GameColors.textMuted)),
        ],
      ),
    );
  }
}

class _RecentContributions extends StatelessWidget {
  final List<CountryInfrastructureContribution> contributions;

  const _RecentContributions({required this.contributions});

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return const GamePanel(
        child: Text(
          'No recent infrastructure contributions yet.',
          style: TextStyle(color: GameColors.textMuted),
        ),
      );
    }

    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent contributions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          ...contributions.map((contribution) {
            final date =
                DateFormat('MMM d, HH:mm').format(contribution.createdAt);
            final itemText = contribution.itemQuantity <= 0
                ? ''
                : ' and ${_formatNumber(contribution.itemQuantity)} ${contribution.itemName}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.volunteer_activism, color: GameColors.amber),
              title: Text(
                '${contribution.playerId} gave ${_formatNumber(contribution.goldAmount)} gold$itemText',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                contribution.levelsCompleted > 0
                    ? '$date - completed ${contribution.levelsCompleted} level(s)'
                    : date,
                style: const TextStyle(color: GameColors.textMuted),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfrastructureErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InfrastructureErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GamePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: GameColors.crimson, size: 36),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white)),
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

IconData _iconForBonus(String bonusType) {
  switch (bonusType) {
    case 'hospital_recovery':
      return Icons.local_hospital;
    case 'training_readiness':
      return Icons.fitness_center;
    case 'logistics_efficiency':
      return Icons.local_shipping;
    case 'defense_readiness':
      return Icons.shield;
    case 'research_output':
      return Icons.science;
    default:
      return Icons.construction;
  }
}

String _formatNumber(int value) => NumberFormat.decimalPattern().format(value);

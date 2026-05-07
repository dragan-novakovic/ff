import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TerritoryPage extends StatefulWidget {
  final User user;
  const TerritoryPage({super.key, required this.user});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  late final TerritoryBloc _territoryBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _territoryBloc = Provider.of<TerritoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _territoryBloc.setBearerToken(_loginBloc.currentToken);
    await _territoryBloc.load();
  }

  Future<void> _start(TerritoryRegion region, String battleType) async {
    _territoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _territoryBloc.startBattle(
      playerId: widget.user.uid,
      regionId: region.regionId,
      battleType: battleType,
    );
    _showResult(result);
  }

  Future<void> _resolve(CountryBattle battle) async {
    _territoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _territoryBloc.resolveBattle(
      playerId: widget.user.uid,
      battleId: battle.battleId,
    );
    _showResult(result);
  }

  void _showResult(TerritoryBattleMutationResult? result) {
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _territoryBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Territory')),
      body: Consumer<TerritoryBloc>(
        builder: (context, bloc, _) {
          final territoryMap = bloc.map;
          if (bloc.isLoading && territoryMap == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && territoryMap == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (territoryMap == null) {
            return _ErrorState(
              message: 'Territory map has not loaded yet.',
              onRetry: _load,
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _IntroCard(
                  activeConflicts: territoryMap.activeConflicts.length,
                  error: bloc.error,
                ),
                _TerritoryMapOverview(regions: territoryMap.regions),
                if (bloc.lastMutation != null)
                  _MutationCard(result: bloc.lastMutation!),
                const SizedBox(height: 8),
                ...territoryMap.regions.map(
                  (region) => _TerritoryRegionCard(
                    region: region,
                    isStarting:
                        bloc.startingRegionIds.contains(region.regionId),
                    resolvingBattleIds: bloc.resolvingBattleIds,
                    onStartConquest: region.authorization.canStartConquest
                        ? () => _start(region, 'conquest')
                        : null,
                    onStartResistance: region.authorization.canStartResistance
                        ? () => _start(region, 'resistance')
                        : null,
                    onResolve: region.activeConflict == null ||
                            !region.authorization.canResolveBattle
                        ? null
                        : () => _resolve(region.activeConflict!),
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

class _IntroCard extends StatelessWidget {
  final int activeConflicts;
  final String? error;
  const _IntroCard({required this.activeConflicts, required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: error == null ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          error == null ? Icons.map : Icons.warning_amber,
          color: error == null ? Colors.green : Colors.orange,
        ),
        title: const Text('Persisted territory control'),
        subtitle: Text(
          error ??
              '$activeConflicts active conflicts. Ownership history, bonuses, defenses, and hospital capacity are loaded from the world service.',
        ),
      ),
    );
  }
}

class _MutationCard extends StatelessWidget {
  final TerritoryBattleMutationResult result;
  const _MutationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.completed ? Colors.blue.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.flag : Icons.info_outline,
          color: result.completed ? Colors.blue : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: Text(result.region == null
            ? 'Territory state was not returned.'
            : '${result.region!.name} owner: ${result.region!.ownerCountryName}'),
      ),
    );
  }
}

class _TerritoryRegionCard extends StatelessWidget {
  final TerritoryRegion region;
  final bool isStarting;
  final Set<String> resolvingBattleIds;
  final VoidCallback? onStartConquest;
  final VoidCallback? onStartResistance;
  final VoidCallback? onResolve;

  const _TerritoryRegionCard({
    required this.region,
    required this.isStarting,
    required this.resolvingBattleIds,
    required this.onStartConquest,
    required this.onStartResistance,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final battle = region.activeConflict;
    final isResolving =
        battle != null && resolvingBattleIds.contains(battle.battleId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(region.isCapital ? Icons.location_city : Icons.terrain),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    region.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(region.ownerCountryCode)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Controlled by ${region.ownerCountryName}. ${region.terrain} • ${region.resourceFocus} • ${Utils.number(region.population)} population.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.factory,
                  label:
                      '+${region.bonus.effectiveProductionBonusPercent}% production',
                ),
                _InfoChip(
                  icon: Icons.storefront,
                  label: '+${region.bonus.effectiveMarketBonusPercent}% market',
                ),
                _InfoChip(
                  icon: Icons.shield,
                  label: '+${region.bonus.defenseBonusPercent}% defense',
                ),
                _InfoChip(
                  icon: Icons.local_hospital,
                  label:
                      '${Utils.number(region.bonus.hospitalCapacity)} hospital',
                ),
                _InfoChip(
                  icon: Icons.security,
                  label: 'Defense ${region.defense.defenseLevel}',
                ),
                _InfoChip(
                  icon: Icons.groups,
                  label:
                      '${Utils.number(region.defense.garrisonStrength)} garrison',
                ),
                _InfoChip(
                  icon: Icons.fort,
                  label:
                      '${region.defense.effectiveDefensePercent}% effective defense',
                ),
                _InfoChip(
                  icon: Icons.warning_amber,
                  label: '${region.defense.resistance}% resistance',
                ),
              ],
            ),
            if (region.resources.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RegionResources(resources: region.resources),
            ],
            const SizedBox(height: 12),
            _MetricBar(
              label: 'Fortifications',
              value: region.defense.fortificationHealth / 100,
              detail: '${region.defense.fortificationHealth}% integrity',
              color: Colors.indigo,
            ),
            const SizedBox(height: 8),
            _MetricBar(
              label: 'Hospital capacity',
              value: (region.defense.effectiveHospitalCapacity / 5000)
                  .clamp(0, 1)
                  .toDouble(),
              detail:
                  '${Utils.number(region.defense.effectiveHospitalCapacity)} energy/day capacity',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            if (battle == null)
              Text(region.authorization.message)
            else
              _ActiveConflict(
                battle: battle,
                canResolve: onResolve != null,
                isResolving: isResolving,
                onResolve: onResolve,
              ),
            const SizedBox(height: 12),
            _HistoryList(history: region.recentHistory),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: isStarting ? null : onStartConquest,
                  icon: isStarting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag),
                  label: Text(isStarting ? 'Starting...' : 'Start conquest'),
                ),
                OutlinedButton.icon(
                  onPressed: isStarting ? null : onStartResistance,
                  icon: const Icon(Icons.campaign),
                  label: const Text('Start resistance'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveConflict extends StatelessWidget {
  final CountryBattle battle;
  final bool canResolve;
  final bool isResolving;
  final VoidCallback? onResolve;

  const _ActiveConflict({
    required this.battle,
    required this.canResolve,
    required this.isResolving,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active conflict: ${battle.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${battle.attackerCountryName} ${battle.attackerScore}/${battle.targetScore} vs ${battle.defenderCountryName} ${battle.defenderScore}/${battle.targetScore}',
          ),
          if (battle.campaignId != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.account_tree_outlined, size: 16),
                  label: Text('Campaign ${battle.campaignId}'),
                ),
                Chip(label: Text(battle.battleType)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: canResolve && !isResolving ? onResolve : null,
            icon: isResolving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified),
            label: Text(isResolving ? 'Resolving...' : 'Resolve battle'),
          ),
        ],
      ),
    );
  }
}

class _TerritoryMapOverview extends StatelessWidget {
  final List<TerritoryRegion> regions;
  const _TerritoryMapOverview({required this.regions});

  @override
  Widget build(BuildContext context) {
    if (regions.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.map_outlined),
          title: Text('World region map'),
          subtitle: Text('No regions have been published yet.'),
        ),
      );
    }

    final grouped = <String, List<TerritoryRegion>>{};
    for (final region in regions) {
      grouped.putIfAbsent(region.ownerCountryName, () => []).add(region);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('World region map',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...grouped.entries.map((entry) {
              final total = entry.value.length;
              final active = entry.value
                  .where((region) => region.hasActiveConflict)
                  .length;
              final production = entry.value.fold<int>(
                0,
                (sum, region) =>
                    sum + region.bonus.effectiveProductionBonusPercent,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text('$total regions • +$production% output'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (total / regions.length).clamp(0, 1).toDouble(),
                      backgroundColor: Colors.grey.shade200,
                    ),
                    if (active > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$active active conflict${active == 1 ? '' : 's'}',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RegionResources extends StatelessWidget {
  final List<RegionResource> resources;
  const _RegionResources({required this.resources});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Regional resources',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: resources
              .map(
                (resource) => Tooltip(
                  message: resource.description,
                  child: Chip(
                    avatar: const Icon(Icons.spa, size: 18),
                    label: Text(
                      '${resource.name} ${resource.abundancePercent}% • +${resource.productionBonusPercent}% output',
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final String detail;
  final Color color;
  const _MetricBar({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(detail),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          color: color,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<RegionControlHistory> history;
  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    final recent = history.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Control history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (recent.isEmpty)
          const Text('No control history recorded yet.')
        else
          ...recent.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(
                '${entry.previousCountryName ?? 'Unclaimed'} → ${entry.newCountryName}',
              ),
              subtitle: Text(entry.battleName ?? entry.reason),
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
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

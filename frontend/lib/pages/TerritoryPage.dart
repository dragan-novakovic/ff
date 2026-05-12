import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color _territoryBackground = Color(0xFF08111E);
const Color _territorySurface = Color(0xFF0D1B2A);
const Color _territoryPanel = Color(0xFF102033);
const Color _territoryInset = Color(0xFF132A42);
const Color _territoryBorder = Color(0xFF28445F);
const Color _territoryText = Color(0xFFF8FAFC);
const Color _territoryMuted = Color(0xFF94A3B8);
const Color _territoryBlue = Color(0xFF38BDF8);
const Color _territoryGreen = Color(0xFF34D399);
const Color _territoryGold = Color(0xFFFACC15);
const Color _territoryOrange = Color(0xFFF97316);

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
      backgroundColor: _territoryBackground,
      appBar: AppBar(
        title: const Text('Territory Command'),
        backgroundColor: _territorySurface,
        foregroundColor: _territoryText,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh territory',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (bloc.error != null)
                  _TerritoryMessageCard(
                    message: bloc.error!,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                if (bloc.lastMutation != null)
                  _MutationCard(result: bloc.lastMutation!),
                _TerritoryHero(map: territoryMap),
                const SizedBox(height: 16),
                _TerritoryMapOverview(regions: territoryMap.regions),
                const SizedBox(height: 16),
                if (territoryMap.regions.isEmpty)
                  const _EmptyTerritoryPanel()
                else
                  ...territoryMap.regions.map(
                    (region) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TerritoryRegionCard(
                        region: region,
                        isStarting:
                            bloc.startingRegionIds.contains(region.regionId),
                        resolvingBattleIds: bloc.resolvingBattleIds,
                        onStartConquest: region.authorization.canStartConquest
                            ? () => _start(region, 'conquest')
                            : null,
                        onStartResistance:
                            region.authorization.canStartResistance
                                ? () => _start(region, 'resistance')
                                : null,
                        onResolve: region.activeConflict == null ||
                                !region.authorization.canResolveBattle
                            ? null
                            : () => _resolve(region.activeConflict!),
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

class _TerritoryHero extends StatelessWidget {
  final TerritoryMap map;

  const _TerritoryHero({required this.map});

  @override
  Widget build(BuildContext context) {
    final regions = map.regions;
    final activeConflicts = map.activeConflicts.length;
    final countries = regions.map((region) => region.ownerCountryId).toSet();
    final population =
        regions.fold<int>(0, (sum, region) => sum + region.population);
    final production = regions.fold<int>(
      0,
      (sum, region) => sum + region.bonus.effectiveProductionBonusPercent,
    );
    final garrison = regions.fold<int>(
        0, (sum, region) => sum + region.defense.garrisonStrength);

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
              Color(0xFF14532D),
            ],
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Icon(
                    Icons.public,
                    color: _territoryBlue,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'World Territory Command',
                        style: TextStyle(
                          color: _territoryText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Monitor regional control, production bonuses, defense posture, and live conquest fronts.',
                        style: TextStyle(color: _territoryMuted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 720
                    ? 4
                    : constraints.maxWidth > 460
                        ? 2
                        : 1;
                const spacing = 10.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _HeroStatCard(
                      width: width,
                      label: 'Regions',
                      value: '${regions.length}',
                      detail: '${countries.length} countries hold land',
                      icon: Icons.map,
                      color: _territoryBlue,
                    ),
                    _HeroStatCard(
                      width: width,
                      label: 'Conflicts',
                      value: '$activeConflicts',
                      detail: activeConflicts == 1
                          ? 'active front'
                          : 'active fronts',
                      icon: Icons.local_fire_department,
                      color: activeConflicts > 0
                          ? Colors.redAccent
                          : _territoryGreen,
                    ),
                    _HeroStatCard(
                      width: width,
                      label: 'Population',
                      value: Utils.number(population),
                      detail: 'citizens under regional control',
                      icon: Icons.groups,
                      color: _territoryGold,
                    ),
                    _HeroStatCard(
                      width: width,
                      label: 'Strategic output',
                      value: '+${Utils.number(production)}%',
                      detail: '${Utils.number(garrison)} garrison strength',
                      icon: Icons.factory,
                      color: _territoryGreen,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _HeroStatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: _territoryMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _territoryText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(detail, style: const TextStyle(color: _territoryMuted)),
          ],
        ),
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
      return const _CommandSectionCard(
        title: 'World region map',
        subtitle: 'No regions have been published yet.',
        icon: Icons.map_outlined,
        child: _EmptyTerritoryPanel(),
      );
    }

    final grouped = <String, List<TerritoryRegion>>{};
    for (final region in regions) {
      grouped.putIfAbsent(region.ownerCountryName, () => []).add(region);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return _CommandSectionCard(
      title: 'Control overview',
      subtitle: 'Regional ownership, bonuses, and active fronts by country.',
      icon: Icons.account_balance,
      child: Column(
        children: entries.map((entry) {
          final total = entry.value.length;
          final active =
              entry.value.where((region) => region.hasActiveConflict).length;
          final production = entry.value.fold<int>(
            0,
            (sum, region) => sum + region.bonus.effectiveProductionBonusPercent,
          );
          final population = entry.value.fold<int>(
            0,
            (sum, region) => sum + region.population,
          );
          final share = regions.isEmpty ? 0.0 : total / regions.length;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _territoryPanel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _territoryBorder.withOpacity(0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CountryBadge(label: entry.value.first.ownerCountryCode),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: _territoryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _TerritoryBadge(
                      label: '$total regions',
                      color: _territoryBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: share.clamp(0, 1).toDouble(),
                    minHeight: 9,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_territoryBlue),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TerritoryBadge(
                      label: '+${Utils.number(production)}% output',
                      color: _territoryGreen,
                      icon: Icons.factory,
                    ),
                    _TerritoryBadge(
                      label: Utils.number(population),
                      color: _territoryGold,
                      icon: Icons.groups,
                    ),
                    if (active > 0)
                      _TerritoryBadge(
                        label:
                            '$active active conflict${active == 1 ? '' : 's'}',
                        color: Colors.redAccent,
                        icon: Icons.local_fire_department,
                      ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
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
    final statusColor =
        region.hasActiveConflict ? Colors.redAccent : _territoryGreen;

    return Card(
      elevation: 0,
      color: _territorySurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _territoryBorder.withOpacity(0.75)),
        ),
        padding: const EdgeInsets.all(16),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E3A8A), Color(0xFF14532D)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(
                    region.isCapital ? Icons.location_city : Icons.terrain,
                    color: _territoryText,
                    size: 30,
                  ),
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
                              region.name,
                              style: const TextStyle(
                                color: _territoryText,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _CountryBadge(label: region.ownerCountryCode),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Controlled by ${region.ownerCountryName}. ${region.terrain} terrain with ${region.resourceFocus} focus.',
                        style: const TextStyle(
                            color: _territoryMuted, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      _TerritoryBadge(
                        label: region.hasActiveConflict
                            ? 'Active conflict'
                            : 'Secured',
                        color: statusColor,
                        icon: region.hasActiveConflict
                            ? Icons.local_fire_department
                            : Icons.verified_user,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RegionStatGrid(region: region),
            const SizedBox(height: 14),
            _RegionBonusGrid(region: region),
            if (region.resources.isNotEmpty) ...[
              const SizedBox(height: 14),
              _RegionResources(resources: region.resources),
            ],
            const SizedBox(height: 14),
            _DefenseReadiness(region: region),
            const SizedBox(height: 14),
            if (battle == null)
              _AuthorizationPanel(message: region.authorization.message)
            else
              _ActiveConflict(
                battle: battle,
                canResolve: onResolve != null,
                isResolving: isResolving,
                onResolve: onResolve,
              ),
            const SizedBox(height: 14),
            _HistoryList(history: region.recentHistory),
            const SizedBox(height: 14),
            _RegionActionBar(
              isStarting: isStarting,
              onStartConquest: onStartConquest,
              onStartResistance: onStartResistance,
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionStatGrid extends StatelessWidget {
  final TerritoryRegion region;

  const _RegionStatGrid({required this.region});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720
            ? 4
            : constraints.maxWidth > 460
                ? 2
                : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _RegionStatTile(
              width: width,
              label: 'Population',
              value: Utils.number(region.population),
              icon: Icons.groups,
              color: _territoryGold,
            ),
            _RegionStatTile(
              width: width,
              label: 'Infrastructure',
              value: '${region.infrastructure}',
              icon: Icons.account_tree,
              color: _territoryBlue,
            ),
            _RegionStatTile(
              width: width,
              label: 'Defense',
              value: '${region.defense.effectiveDefensePercent}%',
              icon: Icons.fort,
              color: _territoryGreen,
            ),
            _RegionStatTile(
              width: width,
              label: 'Resistance',
              value: '${region.defense.resistance}%',
              icon: Icons.warning_amber_rounded,
              color: region.defense.resistance > 50
                  ? Colors.redAccent
                  : _territoryOrange,
            ),
          ],
        );
      },
    );
  }
}

class _RegionStatTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _RegionStatTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _territoryPanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _territoryBorder.withOpacity(0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _territoryMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: _territoryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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

class _RegionBonusGrid extends StatelessWidget {
  final TerritoryRegion region;

  const _RegionBonusGrid({required this.region});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TerritoryBadge(
          icon: Icons.factory,
          label: '+${region.bonus.effectiveProductionBonusPercent}% production',
          color: _territoryGreen,
        ),
        _TerritoryBadge(
          icon: Icons.storefront,
          label: '+${region.bonus.effectiveMarketBonusPercent}% market',
          color: _territoryBlue,
        ),
        _TerritoryBadge(
          icon: Icons.shield,
          label: '+${region.bonus.defenseBonusPercent}% defense',
          color: _territoryGold,
        ),
        _TerritoryBadge(
          icon: Icons.local_hospital,
          label:
              '${Utils.number(region.bonus.hospitalCapacity)} hospital capacity',
          color: _territoryOrange,
        ),
        _TerritoryBadge(
          icon: Icons.security,
          label: 'Defense level ${region.defense.defenseLevel}',
          color: _territoryGreen,
        ),
        _TerritoryBadge(
          icon: Icons.groups,
          label: '${Utils.number(region.defense.garrisonStrength)} garrison',
          color: _territoryBlue,
        ),
      ],
    );
  }
}

class _RegionResources extends StatelessWidget {
  final List<RegionResource> resources;
  const _RegionResources({required this.resources});

  @override
  Widget build(BuildContext context) {
    return _TerritorySubPanel(
      title: 'Regional resources',
      icon: Icons.spa,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: resources
            .map(
              (resource) => Tooltip(
                message: resource.description,
                child: _TerritoryBadge(
                  icon: Icons.eco,
                  label:
                      '${resource.name} ${resource.abundancePercent}% / +${resource.productionBonusPercent}% output',
                  color: _territoryGreen,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DefenseReadiness extends StatelessWidget {
  final TerritoryRegion region;

  const _DefenseReadiness({required this.region});

  @override
  Widget build(BuildContext context) {
    return _TerritorySubPanel(
      title: 'Defense readiness',
      icon: Icons.security,
      child: Column(
        children: [
          _MetricBar(
            label: 'Fortifications',
            value: region.defense.fortificationHealth / 100,
            detail: '${region.defense.fortificationHealth}% integrity',
            color: _territoryBlue,
          ),
          const SizedBox(height: 12),
          _MetricBar(
            label: 'Hospital capacity',
            value: (region.defense.effectiveHospitalCapacity / 5000)
                .clamp(0, 1)
                .toDouble(),
            detail:
                '${Utils.number(region.defense.effectiveHospitalCapacity)} energy/day',
            color: _territoryGreen,
          ),
          const SizedBox(height: 12),
          _MetricBar(
            label: 'Hospital supplies',
            value:
                (region.defense.hospitalSupplies / 1000).clamp(0, 1).toDouble(),
            detail: Utils.number(region.defense.hospitalSupplies),
            color: _territoryGold,
          ),
        ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  battle.name,
                  style: const TextStyle(
                    color: _territoryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              _TerritoryBadge(
                  label: battle.battleType, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            battle.description,
            style: const TextStyle(color: _territoryMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          _BattleScoreBar(
            label: battle.attackerCountryName,
            code: battle.attackerCountryCode,
            value: battle.attackerProgress,
            score: battle.attackerScore,
            target: battle.targetScore,
            color: _territoryOrange,
          ),
          const SizedBox(height: 10),
          _BattleScoreBar(
            label: battle.defenderCountryName,
            code: battle.defenderCountryCode,
            value: battle.defenderProgress,
            score: battle.defenderScore,
            target: battle.targetScore,
            color: _territoryBlue,
          ),
          if (battle.campaignId != null) ...[
            const SizedBox(height: 10),
            _TerritoryBadge(
              icon: Icons.account_tree_outlined,
              label: 'Campaign ${battle.campaignId}',
              color: _territoryGold,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _territoryGreen,
                foregroundColor: const Color(0xFF052E2B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
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
          ),
        ],
      ),
    );
  }
}

class _BattleScoreBar extends StatelessWidget {
  final String label;
  final String code;
  final double value;
  final int score;
  final int target;
  final Color color;

  const _BattleScoreBar({
    required this.label,
    required this.code,
    required this.value,
    required this.score,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CountryBadge(label: code),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _territoryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$score/$target',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 8,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _AuthorizationPanel extends StatelessWidget {
  final String message;

  const _AuthorizationPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _territoryInset,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _territoryBorder.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _territoryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _territoryMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<RegionControlHistory> history;
  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    final recent = history.take(3).toList();
    return _TerritorySubPanel(
      title: 'Control history',
      icon: Icons.history,
      child: recent.isEmpty
          ? const Text(
              'No control history recorded yet.',
              style: TextStyle(color: _territoryMuted),
            )
          : Column(
              children: recent
                  .map(
                    (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _territoryInset,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _territoryBorder.withOpacity(0.55),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timeline, color: _territoryBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.previousCountryName ?? 'Unclaimed'} -> ${entry.newCountryName}',
                                  style: const TextStyle(
                                    color: _territoryText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  entry.battleName ?? entry.reason,
                                  style:
                                      const TextStyle(color: _territoryMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _shortDate(entry.createdAt),
                            style: const TextStyle(
                              color: _territoryMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _RegionActionBar extends StatelessWidget {
  final bool isStarting;
  final VoidCallback? onStartConquest;
  final VoidCallback? onStartResistance;

  const _RegionActionBar({
    required this.isStarting,
    required this.onStartConquest,
    required this.onStartResistance,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _territoryBlue,
            foregroundColor: const Color(0xFF082F49),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
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
          style: OutlinedButton.styleFrom(
            foregroundColor: _territoryGold,
            side: const BorderSide(color: _territoryGold),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: isStarting ? null : onStartResistance,
          icon: const Icon(Icons.campaign),
          label: const Text('Start resistance'),
        ),
      ],
    );
  }
}

class _MutationCard extends StatelessWidget {
  final TerritoryBattleMutationResult result;
  const _MutationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return _TerritoryMessageCard(
      message: result.region == null
          ? '${result.message} Territory state was not returned.'
          : '${result.message} ${result.region!.name} owner: ${result.region!.ownerCountryName}.',
      icon: result.completed ? Icons.flag : Icons.info_outline,
      color: result.completed ? _territoryBlue : _territoryOrange,
    );
  }
}

class _CommandSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _CommandSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _territorySurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _territoryBorder.withOpacity(0.7)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _territoryBlue.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: _territoryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _territoryText,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _territoryMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TerritorySubPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _TerritorySubPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _territoryPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _territoryBorder.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _territoryBlue),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _territoryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
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
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _territoryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              detail,
              style: const TextStyle(color: _territoryMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 9,
            color: color,
            backgroundColor: color.withOpacity(0.14),
          ),
        ),
      ],
    );
  }
}

class _TerritoryBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _TerritoryBadge({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryBadge extends StatelessWidget {
  final String label;

  const _CountryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _territoryBlue.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _territoryBlue.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _territoryBlue,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TerritoryMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _TerritoryMessageCard({
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _territoryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTerritoryPanel extends StatelessWidget {
  const _EmptyTerritoryPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _territoryPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _territoryBorder.withOpacity(0.7)),
      ),
      child: const Column(
        children: [
          Icon(Icons.map_outlined, color: _territoryMuted, size: 34),
          SizedBox(height: 10),
          Text(
            'No regions published',
            style: TextStyle(
              color: _territoryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'World service territory data will appear here once available.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _territoryMuted),
          ),
        ],
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
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _territorySurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _territoryBorder),
          ),
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
                style: const TextStyle(color: _territoryText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _territoryBlue,
                  foregroundColor: const Color(0xFF082F49),
                ),
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

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

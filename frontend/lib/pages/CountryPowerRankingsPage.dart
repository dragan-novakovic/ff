import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CountryPowerRankingsPage extends StatefulWidget {
  final User user;
  const CountryPowerRankingsPage({super.key, required this.user});

  @override
  State<CountryPowerRankingsPage> createState() =>
      _CountryPowerRankingsPageState();
}

class _CountryPowerRankingsPageState extends State<CountryPowerRankingsPage> {
  late final WorldBloc _worldBloc;
  late final TerritoryBloc _territoryBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _worldBloc = Provider.of<WorldBloc>(context, listen: false);
    _territoryBloc = Provider.of<TerritoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _worldBloc.setBearerToken(_loginBloc.currentToken);
    _territoryBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _worldBloc.load(widget.user.uid),
      _territoryBloc.load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Country Power Index',
      subtitle: 'Estimated national strength from live world data',
      icon: Icons.leaderboard,
      actions: [
        IconButton(
          tooltip: 'Refresh country index',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer2<WorldBloc, TerritoryBloc>(
        builder: (context, worldBloc, territoryBloc, _) {
          final catalog = worldBloc.catalog;
          final map = territoryBloc.map;
          final isLoading = (worldBloc.isLoading && catalog == null) ||
              (territoryBloc.isLoading && map == null);
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (catalog == null) {
            return _ErrorState(
              message: worldBloc.error ?? 'Country catalog has not loaded yet.',
              onRetry: _load,
            );
          }

          final entries = _buildPowerEntries(catalog.countries, map);
          final totalScore =
              entries.fold<int>(0, (total, entry) => total + entry.powerScore);
          final highestScore = entries.isEmpty ? 0 : entries.first.powerScore;
          final controlledRegions = entries.fold<int>(
            0,
            (total, entry) => total + entry.ownedRegions,
          );
          final activeConflicts = entries.fold<int>(
            0,
            (total, entry) => total + entry.activeConflicts,
          );
          final updatedAt = [
            catalog.updatedAt,
            if (map != null) map.updatedAt,
          ]..sort();

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GameHero(
                  eyebrow: 'Live country intelligence',
                  title: 'Estimated national power',
                  subtitle:
                      'This index is derived from persisted country, treasury, and territory data. It is a transparent scout-board, not an official backend leaderboard.',
                  icon: Icons.public,
                  accent: GameColors.violet,
                  stats: [
                    GameStat(
                      label: 'countries',
                      value: Utils.number(entries.length),
                      icon: Icons.flag,
                      color: GameColors.violet,
                    ),
                    GameStat(
                      label: 'total score',
                      value: Utils.number(totalScore),
                      icon: Icons.bolt,
                      color: GameColors.amber,
                    ),
                    GameStat(
                      label: 'territories',
                      value: Utils.number(controlledRegions),
                      icon: Icons.map,
                      color: GameColors.emerald,
                    ),
                    GameStat(
                      label: 'active wars',
                      value: Utils.number(activeConflicts),
                      icon: Icons.shield,
                      color: GameColors.crimson,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (worldBloc.error != null)
                  GameNotice(
                    icon: Icons.warning_amber,
                    message: worldBloc.error!,
                    color: GameColors.amber,
                  ),
                if (territoryBloc.error != null)
                  GameNotice(
                    icon: Icons.map_outlined,
                    message: territoryBloc.error!,
                    color: GameColors.amber,
                  ),
                GamePanel(
                  borderColor: GameColors.violet.withOpacity(0.35),
                  color: GameColors.violet.withOpacity(0.10),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics, color: GameColors.violet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Score weights: treasury, citizens, owned territory, population, infrastructure, resources, defenses, hospitals, and active-conflict pressure. Last sync ${_formatDateTime(updatedAt.last)}.',
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const GameSectionTitle(
                  title: 'Power ladder',
                  subtitle:
                      'Ranked countries with visible score contributions from live records.',
                ),
                if (entries.isEmpty)
                  const GameEmptyState(
                    icon: Icons.flag_outlined,
                    message:
                        'No countries are available from the world service.',
                  )
                else
                  ...entries.map(
                    (entry) => _CountryPowerCard(
                      entry: entry,
                      maxScore: highestScore,
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

List<_CountryPowerEntry> _buildPowerEntries(
  List<WorldCountry> countries,
  TerritoryMap? territoryMap,
) {
  final regionsByCountry = <String, List<TerritoryRegion>>{};
  for (final region in territoryMap?.regions ?? const <TerritoryRegion>[]) {
    regionsByCountry.putIfAbsent(region.ownerCountryId, () => []).add(region);
  }

  final scored = countries.map((country) {
    final regions = regionsByCountry[country.countryId] ?? const [];
    return _CountryPowerEntry.fromCountry(country, regions);
  }).toList()
    ..sort((a, b) => b.powerScore.compareTo(a.powerScore));

  return [
    for (var index = 0; index < scored.length; index++)
      scored[index].copyWith(rank: index + 1),
  ];
}

class _CountryPowerEntry {
  final int rank;
  final WorldCountry country;
  final List<TerritoryRegion> regions;
  final int treasuryScore;
  final int citizenScore;
  final int territoryScore;
  final int populationScore;
  final int infrastructureScore;
  final int defenseScore;
  final int resourceScore;
  final int hospitalScore;
  final int conflictPenalty;
  final int powerScore;

  const _CountryPowerEntry({
    required this.rank,
    required this.country,
    required this.regions,
    required this.treasuryScore,
    required this.citizenScore,
    required this.territoryScore,
    required this.populationScore,
    required this.infrastructureScore,
    required this.defenseScore,
    required this.resourceScore,
    required this.hospitalScore,
    required this.conflictPenalty,
    required this.powerScore,
  });

  factory _CountryPowerEntry.fromCountry(
    WorldCountry country,
    List<TerritoryRegion> regions,
  ) {
    final ownedRegionCount =
        regions.isEmpty ? country.regionCount : regions.length;
    final population = regions.isEmpty
        ? country.regions.fold<int>(0, (sum, region) => sum + region.population)
        : regions.fold<int>(0, (sum, region) => sum + region.population);
    final infrastructure = regions.isEmpty
        ? country.regions
            .fold<int>(0, (sum, region) => sum + region.infrastructure)
        : regions.fold<int>(0, (sum, region) => sum + region.infrastructure);
    final resourceAbundance = regions.fold<int>(
      0,
      (sum, region) =>
          sum +
          region.resources.fold<int>(
            0,
            (resourceSum, resource) => resourceSum + resource.abundancePercent,
          ),
    );
    final resourceCount = regions.fold<int>(
      0,
      (sum, region) => sum + region.resources.length,
    );
    final activeConflicts =
        regions.where((region) => region.hasActiveConflict).length;
    final defenseScore = regions.fold<int>(
      0,
      (sum, region) =>
          sum +
          region.defense.effectiveDefensePercent +
          region.defense.defenseLevel * 80 +
          region.defense.garrisonStrength ~/ 10 +
          region.defense.fortificationHealth ~/ 20,
    );
    final hospitalScore = regions.fold<int>(
      0,
      (sum, region) =>
          sum +
          region.defense.hospitalLevel * 45 +
          region.defense.effectiveHospitalCapacity * 2 +
          region.defense.hospitalSupplies ~/ 20,
    );
    final treasuryScore = country.treasury ~/ 50;
    final citizenScore = country.citizenCount * 30;
    final territoryScore = ownedRegionCount * 900;
    final populationScore = population ~/ 100;
    final infrastructureScore = infrastructure * 4;
    final resourceScore = resourceCount * 150 + resourceAbundance ~/ 5;
    final conflictPenalty = activeConflicts * 175;
    final rawScore = treasuryScore +
        citizenScore +
        territoryScore +
        populationScore +
        infrastructureScore +
        defenseScore +
        resourceScore +
        hospitalScore -
        conflictPenalty;

    return _CountryPowerEntry(
      rank: 0,
      country: country,
      regions: regions,
      treasuryScore: treasuryScore,
      citizenScore: citizenScore,
      territoryScore: territoryScore,
      populationScore: populationScore,
      infrastructureScore: infrastructureScore,
      defenseScore: defenseScore,
      resourceScore: resourceScore,
      hospitalScore: hospitalScore,
      conflictPenalty: conflictPenalty,
      powerScore: rawScore < 0 ? 0 : rawScore,
    );
  }

  int get ownedRegions =>
      regions.isEmpty ? country.regionCount : regions.length;

  int get population => regions.isEmpty
      ? country.regions.fold<int>(0, (sum, region) => sum + region.population)
      : regions.fold<int>(0, (sum, region) => sum + region.population);

  int get activeConflicts =>
      regions.where((region) => region.hasActiveConflict).length;

  int get resourceCount =>
      regions.fold<int>(0, (sum, region) => sum + region.resources.length);

  int get defenseSystems =>
      regions.where((region) => region.defense.defenseLevel > 0).length;

  _CountryPowerEntry copyWith({required int rank}) {
    return _CountryPowerEntry(
      rank: rank,
      country: country,
      regions: regions,
      treasuryScore: treasuryScore,
      citizenScore: citizenScore,
      territoryScore: territoryScore,
      populationScore: populationScore,
      infrastructureScore: infrastructureScore,
      defenseScore: defenseScore,
      resourceScore: resourceScore,
      hospitalScore: hospitalScore,
      conflictPenalty: conflictPenalty,
      powerScore: powerScore,
    );
  }
}

class _CountryPowerCard extends StatelessWidget {
  final _CountryPowerEntry entry;
  final int maxScore;

  const _CountryPowerCard({
    required this.entry,
    required this.maxScore,
  });

  @override
  Widget build(BuildContext context) {
    final country = entry.country;
    final progress = maxScore <= 0 ? 0.0 : entry.powerScore / maxScore;
    final accent = entry.rank == 1
        ? GameColors.amber
        : entry.rank <= 3
            ? GameColors.emerald
            : GameColors.cyan;

    return GamePanel(
      borderColor: accent.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: accent,
                foregroundColor: GameColors.background,
                child: Text(
                  '#${entry.rank}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${country.code} • ${country.government} • ${country.taxRate}% base tax',
                      style: const TextStyle(color: GameColors.textMuted),
                    ),
                  ],
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'power index',
                  value: Utils.number(entry.powerScore),
                  icon: Icons.bolt,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GameProgressBar(
            label: 'Relative national power',
            valueLabel: '${(progress * 100).round()}%',
            value: progress,
            color: accent,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GameStatPill(
                stat: GameStat(
                  label: 'treasury',
                  value: '${Utils.number(country.treasury)}g',
                  icon: Icons.account_balance_wallet,
                  color: GameColors.amber,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'citizens',
                  value: Utils.number(country.citizenCount),
                  icon: Icons.groups,
                  color: GameColors.violet,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'regions',
                  value: Utils.number(entry.ownedRegions),
                  icon: Icons.map,
                  color: GameColors.emerald,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'population',
                  value: Utils.number(entry.population),
                  icon: Icons.apartment,
                  color: GameColors.cyan,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'resources',
                  value: Utils.number(entry.resourceCount),
                  icon: Icons.terrain,
                  color: GameColors.emerald,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'defense grids',
                  value: Utils.number(entry.defenseSystems),
                  icon: Icons.shield,
                  color: GameColors.crimson,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ScoreBreakdown(entry: entry),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  final _CountryPowerEntry entry;

  const _ScoreBreakdown({required this.entry});

  @override
  Widget build(BuildContext context) {
    final positiveMax = [
      entry.treasuryScore,
      entry.citizenScore,
      entry.territoryScore,
      entry.populationScore,
      entry.infrastructureScore,
      entry.defenseScore,
      entry.resourceScore,
      entry.hospitalScore,
    ].fold<int>(1, (max, value) => value > max ? value : max);

    return Column(
      children: [
        _ScoreLine(
          label: 'Treasury reserves',
          value: entry.treasuryScore,
          maxValue: positiveMax,
          color: GameColors.amber,
        ),
        _ScoreLine(
          label: 'Citizen base',
          value: entry.citizenScore,
          maxValue: positiveMax,
          color: GameColors.violet,
        ),
        _ScoreLine(
          label: 'Territory control',
          value: entry.territoryScore,
          maxValue: positiveMax,
          color: GameColors.emerald,
        ),
        _ScoreLine(
          label: 'Population',
          value: entry.populationScore,
          maxValue: positiveMax,
          color: GameColors.cyan,
        ),
        _ScoreLine(
          label: 'Infrastructure',
          value: entry.infrastructureScore,
          maxValue: positiveMax,
          color: GameColors.cyan,
        ),
        _ScoreLine(
          label: 'Defense grid',
          value: entry.defenseScore,
          maxValue: positiveMax,
          color: GameColors.crimson,
        ),
        _ScoreLine(
          label: 'Resources',
          value: entry.resourceScore,
          maxValue: positiveMax,
          color: GameColors.emerald,
        ),
        _ScoreLine(
          label: 'Hospitals',
          value: entry.hospitalScore,
          maxValue: positiveMax,
          color: GameColors.violet,
        ),
        if (entry.conflictPenalty > 0)
          _ScoreLine(
            label: 'Active conflict pressure',
            value: -entry.conflictPenalty,
            maxValue: positiveMax,
            color: GameColors.amber,
          ),
      ],
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _ScoreLine({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (value.abs() / maxValue).clamp(0.0, 1.0);
    final displayColor = value < 0 ? GameColors.amber : color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: GameColors.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.white10,
                color: displayColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              value < 0 ? '-${Utils.number(value.abs())}' : Utils.number(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: displayColor,
                fontWeight: FontWeight.w800,
              ),
            ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: GameColors.crimson,
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
    );
  }
}

String _formatDateTime(DateTime value) {
  return DateFormat.yMMMd().add_Hm().format(value.toLocal());
}

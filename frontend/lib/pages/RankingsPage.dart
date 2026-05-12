import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RankingsBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  static const _sortOptions = ['level', 'experience', 'strength'];
  late final RankingsBloc _rankingsBloc;
  late final LoginBloc _loginBloc;
  String _sortBy = 'level';

  @override
  void initState() {
    super.initState();
    _rankingsBloc = Provider.of<RankingsBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _rankingsBloc.setBearerToken(_loginBloc.currentToken);
    await _rankingsBloc.loadLeaderboard(sortBy: _sortBy, limit: 50);
    final user = _loginBloc.currentUser;
    if (user != null) {
      await _rankingsBloc.loadPlayerRanking(user.uid, sortBy: _sortBy);
    }
  }

  Future<void> _changeSort(String? value) async {
    if (value == null || value == _sortBy) {
      return;
    }

    setState(() {
      _sortBy = value;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Hall of Fame',
      subtitle: 'Player profile, strength, and experience rankings',
      icon: Icons.emoji_events,
      body: Consumer<RankingsBloc>(
        builder: (context, bloc, _) {
          final leaderboard = bloc.leaderboard;
          if (bloc.isLoadingLeaderboard && leaderboard == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && leaderboard == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final entries = leaderboard?.entries ?? [];
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GameHero(
                  eyebrow: 'Hall of Fame',
                  title: 'Citizen power ladder',
                  subtitle:
                      'Compare levels, experience, energy readiness, and strength. Tap a citizen to open their public dossier.',
                  icon: Icons.military_tech,
                  accent: GameColors.amber,
                  stats: [
                    GameStat(
                      label: 'ranked citizens',
                      value: Utils.number(leaderboard?.totalPlayers ?? 0),
                      icon: Icons.groups_2_outlined,
                      color: GameColors.amber,
                    ),
                    GameStat(
                      label: 'sort order',
                      value: _sortLabel(_sortBy),
                      icon: Icons.sort,
                      color: GameColors.cyan,
                    ),
                    GameStat(
                      label: 'visible rows',
                      value: Utils.number(entries.length),
                      icon: Icons.view_list,
                      color: GameColors.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SortPanel(
                  sortBy: _sortBy,
                  sortOptions: _sortOptions,
                  updatedAt: leaderboard?.updatedAt,
                  onChanged: _changeSort,
                ),
                if (bloc.playerRanking != null)
                  _PlayerSpotlight(entry: bloc.playerRanking!),
                const GameSectionTitle(
                  title: 'Leaderboard',
                  subtitle:
                      'The top citizens by the selected combat progression stat.',
                ),
                if (entries.isEmpty)
                  const GameEmptyState(
                    icon: Icons.leaderboard,
                    message: 'No ranked players yet.',
                  )
                else
                  ...entries.map(
                    (entry) => _RankingTile(
                      entry: entry,
                      metricLabel: _sortLabel(_sortBy),
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

class _SortPanel extends StatelessWidget {
  final String sortBy;
  final List<String> sortOptions;
  final DateTime? updatedAt;
  final ValueChanged<String?> onChanged;

  const _SortPanel({
    required this.sortBy,
    required this.sortOptions,
    required this.updatedAt,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Row(
        children: [
          const Icon(Icons.tune, color: GameColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ranking board controls',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  updatedAt == null
                      ? 'Waiting for leaderboard data'
                      : 'Updated ${_formatDate(updatedAt!)}',
                  style: const TextStyle(color: GameColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: sortBy,
            items: sortOptions
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(_sortLabel(option)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PlayerSpotlight extends StatelessWidget {
  final RankingEntry entry;

  const _PlayerSpotlight({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      borderColor: GameColors.violet.withOpacity(0.45),
      color: GameColors.violet.withOpacity(0.10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: GameColors.violet,
            foregroundColor: GameColors.background,
            child: Text('#${entry.rank}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your current standing',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  '${entry.username} • Level ${entry.level} • ${Utils.number(entry.experience)} XP',
                  style: const TextStyle(color: GameColors.textMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              '/profile',
              arguments: {'playerId': entry.playerId},
            ),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Dossier'),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final RankingEntry entry;
  final String metricLabel;

  const _RankingTile({
    required this.entry,
    required this.metricLabel,
  });

  @override
  Widget build(BuildContext context) {
    final metricValue = switch (metricLabel) {
      'Experience' => Utils.number(entry.experience),
      'Strength' => Utils.number(entry.strength),
      _ => entry.level.toString(),
    };
    final energyValue = entry.maxEnergy <= 0
        ? 0.0
        : (entry.energy / entry.maxEnergy).clamp(0, 1).toDouble();

    return GamePanel(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(
          context,
          '/profile',
          arguments: {'playerId': entry.playerId},
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: entry.rank <= 3
                        ? GameColors.amber
                        : GameColors.panelAlt,
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
                          entry.username,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        Text(
                          'Player ${entry.playerId}',
                          style: const TextStyle(color: GameColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  GameStatPill(
                    stat: GameStat(
                      label: metricLabel,
                      value: metricValue,
                      icon: Icons.trending_up,
                      color: GameColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GameStatPill(
                    stat: GameStat(
                      label: 'strength',
                      value: Utils.number(entry.strength),
                      icon: Icons.fitness_center,
                      color: GameColors.crimson,
                    ),
                  ),
                  GameStatPill(
                    stat: GameStat(
                      label: 'experience',
                      value: Utils.number(entry.experience),
                      icon: Icons.star,
                      color: GameColors.violet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GameProgressBar(
                label: 'Energy readiness',
                valueLabel: '${entry.energy}/${entry.maxEnergy}',
                value: energyValue,
                color: GameColors.emerald,
              ),
            ],
          ),
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
    return GameTheme(
      child: Center(
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
      ),
    );
  }
}

String _sortLabel(String sortBy) {
  return switch (sortBy) {
    'experience' => 'Experience',
    'strength' => 'Strength',
    _ => 'Level',
  };
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

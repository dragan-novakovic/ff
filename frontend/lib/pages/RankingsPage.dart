import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RankingsBloc.dart';
import 'package:ff/models/GameAreas.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rankings')),
      body: Consumer<RankingsBloc>(
        builder: (context, bloc, _) {
          final leaderboard = bloc.leaderboard;
          if (bloc.isLoadingLeaderboard && leaderboard == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && leaderboard == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RankingsHeader(
                  sortBy: _sortBy,
                  sortOptions: _sortOptions,
                  totalPlayers: leaderboard?.totalPlayers ?? 0,
                  updatedAt: leaderboard?.updatedAt,
                  onChanged: _changeSort,
                ),
                const SizedBox(height: 16),
                if (leaderboard == null || leaderboard.entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No ranked players yet.'),
                    ),
                  )
                else
                  ...leaderboard.entries.map(
                    (entry) => _RankingTile(entry: entry),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RankingsHeader extends StatelessWidget {
  final String sortBy;
  final List<String> sortOptions;
  final int totalPlayers;
  final DateTime? updatedAt;
  final ValueChanged<String?> onChanged;
  const _RankingsHeader({
    required this.sortBy,
    required this.sortOptions,
    required this.totalPlayers,
    required this.updatedAt,
    required this.onChanged,
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
                Text('Leaderboard',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
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
            Text('$totalPlayers ranked players'),
            if (updatedAt != null) Text('Updated ${_formatDate(updatedAt!)}'),
          ],
        ),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final RankingEntry entry;
  const _RankingTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('#${entry.rank}')),
        title: Text(entry.username),
        subtitle: Text(
          'Level ${entry.level} • XP ${entry.experience} • '
          'Strength ${entry.strength} • Energy ${entry.energy}/${entry.maxEnergy}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(
          context,
          '/profile',
          arguments: {'playerId': entry.playerId},
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

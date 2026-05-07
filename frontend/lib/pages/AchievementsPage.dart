import 'package:ff/blocs/AchievementsBloc.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/Achievements.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AchievementsPage extends StatefulWidget {
  final User user;

  const AchievementsPage({super.key, required this.user});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  late final LoginBloc _loginBloc;
  late final AchievementsBloc _achievementsBloc;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _achievementsBloc = Provider.of<AchievementsBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _achievementsBloc.setBearerToken(_loginBloc.currentToken);
    await _achievementsBloc.load(widget.user.uid);
  }

  Future<void> _claim(AchievementProgress achievement) async {
    _achievementsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _achievementsBloc.claim(
      playerId: widget.user.uid,
      achievementId: achievement.achievementId,
    );
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _achievementsBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements & Medals'),
        actions: [
          IconButton(
            tooltip: 'Refresh achievements',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Consumer<AchievementsBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.summary == null) {
            return _errorState(bloc.error!);
          }

          final summary = bloc.summary;
          if (summary == null) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.military_tech),
                label: const Text('Load achievements'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: _achievementList(context, summary, bloc),
          );
        },
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementList(
    BuildContext context,
    AchievementsSummary summary,
    AchievementsBloc bloc,
  ) {
    final categories = ['All', ...summary.categories];
    final achievements = _selectedCategory == 'All'
        ? summary.achievements
        : summary.achievements
            .where((achievement) => achievement.category == _selectedCategory)
            .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _summaryCard(context, summary),
        _recentUnlocksCard(context, summary.recentUnlocks),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: categories
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        ...achievements.map((achievement) {
          final isClaiming =
              bloc.claimingAchievementIds.contains(achievement.achievementId);
          return _achievementCard(
            context,
            achievement,
            isClaiming: isClaiming,
            onClaim: achievement.claimable ? () => _claim(achievement) : null,
          );
        }),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, AchievementsSummary summary) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Medal cabinet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${summary.totalUnlocked}/${summary.totalAvailable}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: summary.progress, minHeight: 8),
            const SizedBox(height: 8),
            Text(
              '${summary.totalPoints} achievement points • ${summary.unclaimedCount} medal(s) ready to claim',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentUnlocksCard(
      BuildContext context, List<AchievementUnlock> recentUnlocks) {
    if (recentUnlocks.isEmpty) {
      return const Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(Icons.military_tech),
          title: Text('No medals unlocked yet'),
          subtitle: Text('Work, train, fight, trade, and produce to earn one.'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent unlocks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...recentUnlocks.take(5).map(
                  (unlock) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.military_tech,
                      color: _rarityColor(unlock.medalRarity),
                    ),
                    title: Text(unlock.title),
                    subtitle: Text(
                      '${unlock.medalName} • ${DateFormat.yMMMd().add_Hm().format(unlock.awardedAt.toLocal())}',
                    ),
                    trailing: Text('${unlock.points} pts'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _achievementCard(
    BuildContext context,
    AchievementProgress achievement, {
    required bool isClaiming,
    required VoidCallback? onClaim,
  }) {
    final color = _rarityColor(achievement.medalRarity);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(
                    achievement.unlocked
                        ? Icons.emoji_events
                        : Icons.lock_outline,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(achievement.description),
                      const SizedBox(height: 6),
                      Text(
                        '${achievement.category} • ${achievement.medalName} • ${achievement.points} pts',
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: achievement.progress,
              color: color,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    achievement.progressLabel,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isClaiming ? null : onClaim,
                  icon: isClaiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(achievement.claimed ? Icons.check : Icons.redeem),
                  label: Text(
                    achievement.claimed
                        ? 'Claimed'
                        : achievement.unlocked
                            ? 'Claim'
                            : 'Locked',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'gold':
        return Colors.amber.shade700;
      case 'silver':
        return Colors.blueGrey;
      case 'platinum':
        return Colors.lightBlue.shade700;
      default:
        return Colors.brown;
    }
  }
}

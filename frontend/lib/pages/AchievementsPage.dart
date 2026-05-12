import 'package:ff/blocs/AchievementsBloc.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/Achievements.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
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
    return GameScaffold(
      title: 'Medal Cabinet',
      subtitle: 'Achievement medals, categories, and claimable honors',
      icon: Icons.emoji_events,
      actions: [
        IconButton(
          tooltip: 'Refresh achievements',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer<AchievementsBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.summary == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final summary = bloc.summary;
          if (summary == null) {
            return Center(
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.military_tech),
                label: const Text('Load medal cabinet'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: _MedalCabinet(
              summary: summary,
              selectedCategory: _selectedCategory,
              claimingAchievementIds: bloc.claimingAchievementIds,
              lastClaim: bloc.lastClaim,
              onCategorySelected: (category) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              onClaim: _claim,
            ),
          );
        },
      ),
    );
  }
}

class _MedalCabinet extends StatelessWidget {
  final AchievementsSummary summary;
  final String selectedCategory;
  final Set<String> claimingAchievementIds;
  final AchievementClaimResult? lastClaim;
  final ValueChanged<String> onCategorySelected;
  final Future<void> Function(AchievementProgress achievement) onClaim;

  const _MedalCabinet({
    required this.summary,
    required this.selectedCategory,
    required this.claimingAchievementIds,
    required this.lastClaim,
    required this.onCategorySelected,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...summary.categories];
    final medals = (selectedCategory == 'All'
        ? [...summary.achievements]
        : summary.achievements
            .where((achievement) => achievement.category == selectedCategory)
            .toList())
      ..sort((a, b) {
        if (a.claimable != b.claimable) {
          return a.claimable ? -1 : 1;
        }
        if (a.unlocked != b.unlocked) {
          return a.unlocked ? -1 : 1;
        }
        return a.displayOrder.compareTo(b.displayOrder);
      });
    final claimedCount =
        summary.achievements.where((achievement) => achievement.claimed).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GameHero(
          eyebrow: 'Citizen honors',
          title: 'Achievement medal cabinet',
          subtitle:
              'Earn medals by working, training, fighting, trading, and producing for your country.',
          icon: Icons.workspace_premium,
          accent: GameColors.amber,
          stats: [
            GameStat(
              label: 'unlocked',
              value: '${summary.totalUnlocked}/${summary.totalAvailable}',
              icon: Icons.lock_open,
              color: GameColors.emerald,
            ),
            GameStat(
              label: 'points',
              value: Utils.number(summary.totalPoints),
              icon: Icons.stars,
              color: GameColors.amber,
            ),
            GameStat(
              label: 'ready',
              value: summary.unclaimedCount.toString(),
              icon: Icons.redeem,
              color: GameColors.cyan,
            ),
          ],
        ),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech, color: GameColors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cabinet progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Text(
                    '$claimedCount claimed',
                    style: const TextStyle(
                      color: GameColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GameProgressBar(
                label: 'Unlocked medals',
                valueLabel:
                    '${summary.totalUnlocked}/${summary.totalAvailable}',
                value: summary.progress,
                color: GameColors.amber,
              ),
              const SizedBox(height: 10),
              Text(
                'Updated ${DateFormat.yMMMd().add_Hm().format(summary.updatedAt.toLocal())}',
                style: const TextStyle(color: GameColors.textMuted),
              ),
            ],
          ),
        ),
        if (lastClaim != null)
          GameNotice(
            icon: lastClaim!.completed ? Icons.check_circle : Icons.info,
            message: lastClaim!.message,
            color: lastClaim!.completed ? GameColors.emerald : GameColors.amber,
          ),
        _RecentUnlocksPanel(recentUnlocks: summary.recentUnlocks),
        GameSectionTitle(
          title: 'Medal filters',
          subtitle: 'Browse achievements by gameplay category.',
        ),
        GamePanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (category) => ChoiceChip(
                    label: Text(category),
                    selected: selectedCategory == category,
                    onSelected: (_) => onCategorySelected(category),
                    selectedColor: GameColors.amber.withOpacity(0.22),
                    backgroundColor: GameColors.panelAlt,
                    side: BorderSide(
                      color: selectedCategory == category
                          ? GameColors.amber
                          : GameColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: selectedCategory == category
                          ? Colors.white
                          : GameColors.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        GameSectionTitle(
          title: selectedCategory == 'All'
              ? 'All medals'
              : '$selectedCategory medals',
          subtitle: '${medals.length} medal(s) in this view.',
        ),
        if (medals.isEmpty)
          const GameEmptyState(
            icon: Icons.emoji_events_outlined,
            message: 'No medals match this category yet.',
          )
        else
          ...medals.map(
            (achievement) => _MedalCard(
              achievement: achievement,
              isClaiming:
                  claimingAchievementIds.contains(achievement.achievementId),
              onClaim:
                  achievement.claimable ? () => onClaim(achievement) : null,
            ),
          ),
      ],
    );
  }
}

class _RecentUnlocksPanel extends StatelessWidget {
  final List<AchievementUnlock> recentUnlocks;

  const _RecentUnlocksPanel({required this.recentUnlocks});

  @override
  Widget build(BuildContext context) {
    if (recentUnlocks.isEmpty) {
      return const GameEmptyState(
        icon: Icons.military_tech,
        message: 'No medals unlocked yet. Complete core actions to earn one.',
      );
    }

    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: GameColors.cyan),
              const SizedBox(width: 10),
              Text(
                'Recent unlocks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recentUnlocks.take(5).map((unlock) {
            final color = _rarityColor(unlock.medalRarity);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withOpacity(0.16),
                    child: Icon(Icons.workspace_premium, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unlock.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${unlock.medalName} - ${DateFormat.yMMMd().add_Hm().format(unlock.awardedAt.toLocal())}',
                          style: const TextStyle(color: GameColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _MedalStatusPill(
                    label: '${unlock.points} pts',
                    color: color,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MedalCard extends StatelessWidget {
  final AchievementProgress achievement;
  final bool isClaiming;
  final VoidCallback? onClaim;

  const _MedalCard({
    required this.achievement,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(achievement.medalRarity);
    return GamePanel(
      borderColor: achievement.claimable
          ? GameColors.amber.withOpacity(0.55)
          : GameColors.border,
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
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withOpacity(0.35),
                      color.withOpacity(0.08),
                    ],
                  ),
                  border: Border.all(color: color.withOpacity(0.55), width: 2),
                ),
                child: Icon(
                  achievement.unlocked
                      ? Icons.workspace_premium
                      : Icons.lock_outline,
                  color: color,
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
                            achievement.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        _MedalStatusPill(
                          label: achievement.claimed
                              ? 'claimed'
                              : achievement.unlocked
                                  ? 'unlocked'
                                  : 'locked',
                          color: achievement.claimed
                              ? GameColors.emerald
                              : achievement.unlocked
                                  ? GameColors.amber
                                  : GameColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      achievement.description,
                      style: const TextStyle(
                        color: GameColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MedalStatusPill(
                          label: achievement.category,
                          color: GameColors.cyan,
                        ),
                        _MedalStatusPill(
                          label: achievement.medalName,
                          color: color,
                        ),
                        _MedalStatusPill(
                          label: '${achievement.points} pts',
                          color: GameColors.violet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GameProgressBar(
            label: 'Medal progress',
            valueLabel: achievement.progressLabel,
            value: achievement.progress,
            color: color,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: isClaiming ? null : onClaim,
              icon: isClaiming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(achievement.claimed ? Icons.check : Icons.redeem),
              label: Text(
                isClaiming
                    ? 'Claiming...'
                    : achievement.claimed
                        ? 'Claimed'
                        : achievement.unlocked
                            ? 'Claim medal'
                            : 'Locked',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MedalStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.40)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color == GameColors.textMuted ? Colors.white70 : color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
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

Color _rarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'gold':
      return GameColors.amber;
    case 'silver':
      return const Color(0xFFC0CAD5);
    case 'platinum':
      return GameColors.cyan;
    case 'diamond':
      return GameColors.violet;
    default:
      return const Color(0xFFB7791F);
  }
}

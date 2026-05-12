import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RankingsBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PublicProfilePage extends StatefulWidget {
  final String playerId;
  const PublicProfilePage({super.key, required this.playerId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  late final RankingsBloc _rankingsBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _rankingsBloc = Provider.of<RankingsBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _rankingsBloc.setBearerToken(_loginBloc.currentToken);
    await _rankingsBloc.loadPublicProfile(widget.playerId);
    await _rankingsBloc.loadPlayerRanking(widget.playerId);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Citizen Dossier',
      subtitle: 'Public profile, rank, gear, and combat readiness',
      icon: Icons.badge_outlined,
      body: Consumer<RankingsBloc>(
        builder: (context, bloc, _) {
          final profile = bloc.profile;
          final isCurrentProfile = profile?.playerId == widget.playerId;
          if (bloc.isLoadingProfile && !isCurrentProfile) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && !isCurrentProfile) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (profile == null || !isCurrentProfile) {
            return _ErrorState(
              message: 'Public profile has not loaded yet.',
              onRetry: _load,
            );
          }

          final ranking = bloc.playerRanking?.playerId == widget.playerId
              ? bloc.playerRanking
              : null;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileHero(profile: profile, ranking: ranking),
                const SizedBox(height: 12),
                _ProfileStats(profile: profile),
                _EquippedWeaponPanel(weapon: profile.equippedWeapon),
                _TimelinePanel(profile: profile),
                GamePanel(
                  child: Row(
                    children: [
                      const Icon(Icons.leaderboard, color: GameColors.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Compare this citizen against the full Hall of Fame.',
                          style: TextStyle(color: GameColors.textMuted),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/rankings',
                        ),
                        icon: const Icon(Icons.emoji_events),
                        label: const Text('Rankings'),
                      ),
                    ],
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

class _ProfileHero extends StatelessWidget {
  final PublicPlayerProfile profile;
  final RankingEntry? ranking;

  const _ProfileHero({required this.profile, required this.ranking});

  @override
  Widget build(BuildContext context) {
    final rank = ranking?.rank ?? profile.rank;
    final rankText = rank > 0 ? '#$rank' : 'Unranked';
    return GameHero(
      eyebrow: 'Public Dossier',
      title: profile.username,
      subtitle:
          'Citizen ${profile.playerId} joined ${_formatDate(profile.createdOn)} and last updated ${_formatDate(profile.updatedAt)}.',
      icon: Icons.person_pin_circle,
      accent: GameColors.violet,
      stats: [
        GameStat(
          label: 'rank',
          value: rankText,
          icon: Icons.emoji_events,
          color: GameColors.amber,
        ),
        GameStat(
          label: 'level',
          value: profile.level.toString(),
          icon: Icons.trending_up,
          color: GameColors.cyan,
        ),
        GameStat(
          label: 'strength',
          value: Utils.number(profile.strength),
          icon: Icons.fitness_center,
          color: GameColors.crimson,
        ),
      ],
    );
  }
}

class _ProfileStats extends StatelessWidget {
  final PublicPlayerProfile profile;
  const _ProfileStats({required this.profile});

  @override
  Widget build(BuildContext context) {
    final energyValue = profile.maxEnergy <= 0
        ? 0.0
        : (profile.energy / profile.maxEnergy).clamp(0, 1).toDouble();
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Combat readiness',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GameStatPill(
                stat: GameStat(
                  label: 'experience',
                  value: Utils.number(profile.experience),
                  icon: Icons.star,
                  color: GameColors.violet,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'max energy',
                  value: Utils.number(profile.maxEnergy),
                  icon: Icons.battery_charging_full,
                  color: GameColors.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GameProgressBar(
            label: 'Energy reserve',
            valueLabel: '${profile.energy}/${profile.maxEnergy}',
            value: energyValue,
            color: GameColors.emerald,
          ),
        ],
      ),
    );
  }
}

class _EquippedWeaponPanel extends StatelessWidget {
  final EquippedWeapon? weapon;
  const _EquippedWeaponPanel({required this.weapon});

  @override
  Widget build(BuildContext context) {
    final equipped = weapon;
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, color: GameColors.cyan),
              const SizedBox(width: 10),
              Text(
                'Equipped weapon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (equipped == null)
            const Text(
              'No weapon equipped.',
              style: TextStyle(color: GameColors.textMuted),
            )
          else ...[
            Text(
              equipped.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GameStatPill(
                  stat: GameStat(
                    label: 'weapon power',
                    value: Utils.number(equipped.weaponPower),
                    icon: Icons.flash_on,
                    color: GameColors.crimson,
                  ),
                ),
                GameStatPill(
                  stat: GameStat(
                    label: 'category',
                    value: equipped.category,
                    icon: Icons.category,
                    color: GameColors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GameProgressBar(
              label: 'Durability',
              valueLabel: '${equipped.durability}/${equipped.maxDurability}',
              value: equipped.durabilityProgress,
              color:
                  equipped.isUsable ? GameColors.emerald : GameColors.crimson,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  final PublicPlayerProfile profile;

  const _TimelinePanel({required this.profile});

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Citizen timeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          _TimelineRow(
            icon: Icons.login,
            label: 'Joined the republic',
            value: _formatDate(profile.createdOn),
          ),
          _TimelineRow(
            icon: Icons.sync,
            label: 'Last profile update',
            value: _formatDate(profile.updatedAt),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: GameColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: GameColors.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
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

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RankingsBloc.dart';
import 'package:ff/models/GameAreas.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public Profile')),
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

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileHeader(profile: profile),
                const SizedBox(height: 16),
                _ProfileStats(profile: profile),
                const SizedBox(height: 16),
                _EquippedWeaponCard(weapon: profile.equippedWeapon),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/rankings'),
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('View rankings'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final PublicPlayerProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rankText = profile.rank > 0 ? '#${profile.rank}' : 'Unranked';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(profile.username.substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.username,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('Player ${profile.playerId}'),
                    ],
                  ),
                ),
                Chip(label: Text(rankText)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Joined ${_formatDate(profile.createdOn)}'),
            Text('Updated ${_formatDate(profile.updatedAt)}'),
          ],
        ),
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  final PublicPlayerProfile profile;
  const _ProfileStats({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatChip(label: 'Level', value: profile.level.toString()),
            _StatChip(label: 'XP', value: profile.experience.toString()),
            _StatChip(label: 'Strength', value: profile.strength.toString()),
            _StatChip(
              label: 'Energy',
              value: '${profile.energy}/${profile.maxEnergy}',
            ),
          ],
        ),
      ),
    );
  }
}

class _EquippedWeaponCard extends StatelessWidget {
  final EquippedWeapon? weapon;
  const _EquippedWeaponCard({required this.weapon});

  @override
  Widget build(BuildContext context) {
    final equipped = weapon;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipped weapon',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (equipped == null)
              const Text('No weapon equipped.')
            else ...[
              Text('${equipped.name} • Power ${equipped.weaponPower}'),
              const SizedBox(height: 8),
              Text(
                  'Durability ${equipped.durability}/${equipped.maxDurability}'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: equipped.durabilityProgress),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
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

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

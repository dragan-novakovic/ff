import 'dart:math';

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CountryBattlesPage extends StatefulWidget {
  final User user;
  const CountryBattlesPage({super.key, required this.user});

  @override
  State<CountryBattlesPage> createState() => _CountryBattlesPageState();
}

class _CountryBattlesPageState extends State<CountryBattlesPage> {
  late final CountryBattlesBloc _battlesBloc;
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;
  late final RealtimeUpdatesBloc _realtimeBloc;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _battlesBloc = Provider.of<CountryBattlesBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _realtimeBloc = RealtimeUpdatesBloc();
    _load();
    _startRealtime();
  }

  Future<void> _load() async {
    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    await _battlesBloc.load(widget.user.uid);
  }

  void _startRealtime() {
    _realtimeBloc.setBearerToken(_loginBloc.currentToken);
    _realtimeBloc.start(
      playerId: widget.user.uid,
      chatToId: 'global',
      onUpdate: (update) async {
        final battles = update.battles;
        if (battles != null) {
          final selected = _battlesBloc.selectedBattle?.battle.battleId;
          _battlesBloc.applyRealtimeBattles(battles);
          if (selected != null && mounted) {
            await _battlesBloc.loadDetails(
              playerId: widget.user.uid,
              battleId: selected,
            );
          }
        }
      },
    );
  }

  Future<void> _showDetails(CountryBattle battle) async {
    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    await _battlesBloc.loadDetails(
      playerId: widget.user.uid,
      battleId: battle.battleId,
    );
  }

  Future<void> _showCampaign(WarCampaign campaign) async {
    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    await _battlesBloc.loadCampaign(campaign.campaignId);
  }

  Future<void> _completePhase(BattlePhase phase) async {
    final campaignId = _battlesBloc.selectedCampaign?.campaign.campaignId;
    if (campaignId == null) {
      return;
    }

    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _battlesBloc.completeCampaignPhase(
      playerId: widget.user.uid,
      campaignId: campaignId,
      phaseId: phase.phaseId,
    );
    if (!mounted) {
      return;
    }
    final message = result?.message ?? _battlesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _claimCampaignReward(WarCampaign campaign) async {
    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _battlesBloc.claimCampaignReward(
      playerId: widget.user.uid,
      campaignId: campaign.campaignId,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      _playerBloc.setBearerToken(_loginBloc.currentToken);
      await _playerBloc.loadState(widget.user.uid);
    }
    if (!mounted) {
      return;
    }
    final message = result?.message ?? _battlesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _contribute(CountryBattle battle) async {
    _battlesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _battlesBloc.contribute(
      playerId: widget.user.uid,
      battleId: battle.battleId,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      _playerBloc.setBearerToken(_loginBloc.currentToken);
      _inventoryBloc.setBearerToken(_loginBloc.currentToken);
      await _playerBloc.loadState(widget.user.uid);
      await _inventoryBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _battlesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _realtimeBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Country Battles')),
      body: Consumer<CountryBattlesBloc>(
        builder: (context, bloc, _) {
          final battleList = bloc.battles;
          if (bloc.isLoading && battleList == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && battleList == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (battleList == null) {
            return _ErrorState(
              message: 'Country battles have not loaded yet.',
              onRetry: _load,
            );
          }

          final active = battleList.activeBattles;
          final recent = battleList.recentBattles;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _IntroCard(error: bloc.error),
                if (bloc.lastContribution != null)
                  _ContributionResultCard(result: bloc.lastContribution!),
                if (bloc.lastRewardClaim != null)
                  _CampaignRewardClaimCard(result: bloc.lastRewardClaim!),
                _SectionHeader(
                  title: 'Campaigns',
                  subtitle:
                      'Campaigns group battles into phases, objectives, and rewards.',
                ),
                if (bloc.campaigns == null || bloc.campaigns!.campaigns.isEmpty)
                  const _EmptyCard(
                    icon: Icons.account_tree_outlined,
                    message: 'No active campaigns are available yet.',
                  )
                else
                  ...bloc.campaigns!.campaigns.map(
                    (campaign) => _CampaignCard(
                      campaign: campaign,
                      isSelected: bloc.selectedCampaign?.campaign.campaignId ==
                          campaign.campaignId,
                      onDetails: () => _showCampaign(campaign),
                      onClaimReward: campaign.canClaimRewards
                          ? () => _claimCampaignReward(campaign)
                          : null,
                    ),
                  ),
                if (bloc.selectedCampaign != null)
                  _CampaignDetailsCard(
                    details: bloc.selectedCampaign!,
                    completingPhaseIds: bloc.completingPhaseIds,
                    isClaiming: bloc.claimingCampaignIds
                        .contains(bloc.selectedCampaign!.campaign.campaignId),
                    onCompletePhase: _completePhase,
                    onClaimReward:
                        bloc.selectedCampaign!.campaign.canClaimRewards
                            ? () => _claimCampaignReward(
                                  bloc.selectedCampaign!.campaign,
                                )
                            : null,
                  ),
                if (bloc.countryLeaderboard != null)
                  _CountryLeaderboardCard(
                    leaderboard: bloc.countryLeaderboard!,
                  ),
                _SectionHeader(
                  title: 'Active battles',
                  subtitle:
                      'Spend energy to add persisted damage for your country.',
                ),
                if (active.isEmpty)
                  const _EmptyCard(
                    icon: Icons.flag_outlined,
                    message:
                        'No active country battles right now. Recent results are shown below.',
                  )
                else
                  ...active.map(
                    (battle) => _BattleCard(
                      battle: battle,
                      isSelected: bloc.selectedBattle?.battle.battleId ==
                          battle.battleId,
                      isContributing:
                          bloc.contributingBattleIds.contains(battle.battleId),
                      onDetails: () => _showDetails(battle),
                      onContribute: () => _contribute(battle),
                    ),
                  ),
                if (bloc.selectedBattle != null)
                  _BattleDetailsCard(
                    details: bloc.selectedBattle!,
                    participation: bloc.participation,
                    isLoading: bloc.isLoadingDetails,
                    isContributing: bloc.contributingBattleIds
                        .contains(bloc.selectedBattle!.battle.battleId),
                    onContribute: bloc.selectedBattle!.battle.isActive
                        ? () => _contribute(bloc.selectedBattle!.battle)
                        : null,
                  ),
                _SectionHeader(
                  title: 'Recent battles',
                  subtitle:
                      'Resolved battles stay persisted as battle history.',
                ),
                if (recent.isEmpty)
                  const _EmptyCard(
                    icon: Icons.history,
                    message: 'No recent resolved battles are available yet.',
                  )
                else
                  ...recent.map(
                    (battle) => _BattleCard(
                      battle: battle,
                      isSelected: bloc.selectedBattle?.battle.battleId ==
                          battle.battleId,
                      isContributing: false,
                      onDetails: () => _showDetails(battle),
                      onContribute: null,
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
  final String? error;
  const _IntroCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: error == null ? Colors.blue.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          error == null ? Icons.shield : Icons.warning_amber,
          color: error == null ? Colors.blue : Colors.orange,
        ),
        title: const Text('Persisted war front'),
        subtitle: Text(
          error ??
              'Battles are stored by the world service. Contributions consume energy, use combat simulation, and can reward gold/XP.',
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final WarCampaign campaign;
  final bool isSelected;
  final VoidCallback onDetails;
  final VoidCallback? onClaimReward;

  const _CampaignCard({
    required this.campaign,
    required this.isSelected,
    required this.onDetails,
    required this.onClaimReward,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    campaign.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(campaign.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(campaign.description),
            const SizedBox(height: 8),
            Text('${campaign.countryName} • ${campaign.campaignType}'),
            const SizedBox(height: 8),
            _ScoreBar(
              label: 'Objective',
              score: campaign.currentScore,
              target: campaign.objectiveScore,
              value: campaign.progress,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 8),
            Text(
              '${campaign.battleCount} battles • '
              '${campaign.phaseCount} phases • '
              '${campaign.activeBattleCount} active',
            ),
            Text(
              'Reward: ${campaign.reward.gold} gold, '
              '${campaign.reward.experience} XP, '
              '${campaign.reward.prestige} prestige',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline),
                  label: Text(isSelected ? 'Refresh campaign' : 'Campaign'),
                ),
                ElevatedButton.icon(
                  onPressed: onClaimReward,
                  icon: const Icon(Icons.redeem),
                  label: const Text('Claim reward'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignDetailsCard extends StatelessWidget {
  final CampaignDetails details;
  final Set<String> completingPhaseIds;
  final bool isClaiming;
  final ValueChanged<BattlePhase> onCompletePhase;
  final VoidCallback? onClaimReward;

  const _CampaignDetailsCard({
    required this.details,
    required this.completingPhaseIds,
    required this.isClaiming,
    required this.onCompletePhase,
    required this.onClaimReward,
  });

  @override
  Widget build(BuildContext context) {
    final campaign = details.campaign;
    return Card(
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Campaign details: ${campaign.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(campaign.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(campaign.description),
            const SizedBox(height: 12),
            _ScoreBar(
              label: 'Campaign score',
              score: campaign.currentScore,
              target: campaign.objectiveScore,
              value: campaign.progress,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isClaiming ? null : onClaimReward,
              icon: isClaiming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.redeem),
              label: Text(isClaiming ? 'Claiming...' : 'Claim reward'),
            ),
            const SizedBox(height: 16),
            Text('Battle phases',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (details.phases.isEmpty)
              const Text('No campaign phases have been planned yet.')
            else
              ...details.phases.map(
                (phase) => _BattlePhaseTile(
                  phase: phase,
                  isCompleting: completingPhaseIds.contains(phase.phaseId),
                  onComplete:
                      phase.isCompleted ? null : () => onCompletePhase(phase),
                ),
              ),
            const SizedBox(height: 16),
            _CountryLeaderboardCard(
              leaderboard: details.countryLeaderboard,
              title: 'Campaign country leaderboard',
            ),
            _CampaignUnitLeaderboardCard(leaderboard: details.unitLeaderboard),
          ],
        ),
      ),
    );
  }
}

class _BattlePhaseTile extends StatelessWidget {
  final BattlePhase phase;
  final bool isCompleting;
  final VoidCallback? onComplete;

  const _BattlePhaseTile({
    required this.phase,
    required this.isCompleting,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${phase.phaseNumber}')),
      title: Text(phase.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(phase.objectives),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: phase.progress),
          const SizedBox(height: 4),
          Text(
            '${Utils.number(phase.totalDamage)} / '
            '${Utils.number(phase.targetDamage)} damage • ${phase.status}',
          ),
        ],
      ),
      trailing: TextButton(
        onPressed: isCompleting ? null : onComplete,
        child: Text(isCompleting ? 'Saving...' : 'Complete'),
      ),
    );
  }
}

class _CountryLeaderboardCard extends StatelessWidget {
  final CountryBattleLeaderboard leaderboard;
  final String title;

  const _CountryLeaderboardCard({
    required this.leaderboard,
    this.title = 'Country leaderboard',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (leaderboard.entries.isEmpty)
              const Text('No country contributions have been recorded yet.')
            else
              ...leaderboard.entries.take(5).map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('#${entry.rank}')),
                      title:
                          Text('${entry.countryName} (${entry.countryCode})'),
                      subtitle: Text(
                        '${Utils.number(entry.totalDamage)} damage • '
                        '${entry.victoryCount} victories • '
                        '${entry.contributionCount} attacks',
                      ),
                      trailing: Text(Utils.number(entry.score)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _CampaignUnitLeaderboardCard extends StatelessWidget {
  final CampaignUnitLeaderboard leaderboard;
  const _CampaignUnitLeaderboardCard({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unit leaderboard',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (leaderboard.entries.isEmpty)
              const Text('No unit campaign contributions yet.')
            else
              ...leaderboard.entries.take(5).map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('#${entry.rank}')),
                      title: Text(entry.unitName),
                      subtitle: Text(
                        '${entry.countryCode} • '
                        '${Utils.number(entry.totalDamage)} damage • '
                        '${entry.memberCount} members',
                      ),
                      trailing: Text(Utils.number(entry.score)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _CampaignRewardClaimCard extends StatelessWidget {
  final CampaignRewardClaimResult result;
  const _CampaignRewardClaimCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final claim = result.claim;
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.redeem : Icons.info_outline,
          color: result.completed ? Colors.green : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: claim == null
            ? null
            : Text(
                '${claim.goldReward} gold, '
                '${claim.experienceReward} XP, '
                '${claim.prestigeReward} prestige',
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _BattleCard extends StatelessWidget {
  final CountryBattle battle;
  final bool isSelected;
  final bool isContributing;
  final VoidCallback onDetails;
  final VoidCallback? onContribute;

  const _BattleCard({
    required this.battle,
    required this.isSelected,
    required this.isContributing,
    required this.onDetails,
    required this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final winner = battle.winnerCountryName;
    return Card(
      elevation: isSelected ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  battle.isActive ? Icons.local_fire_department : Icons.flag,
                  color: battle.isActive ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    battle.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(battle.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(battle.description),
            const SizedBox(height: 12),
            Text('Region: ${battle.regionName}'),
            Text(
              '${battle.attackerCountryName} attacks ${battle.defenderCountryName}',
            ),
            if (battle.campaignId != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.account_tree_outlined, size: 16),
                    label: Text('Campaign ${battle.campaignId}'),
                  ),
                  Chip(label: Text(battle.battleType)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _ScoreBar(
              label: battle.attackerCountryCode,
              score: battle.attackerScore,
              target: battle.targetScore,
              value: battle.attackerProgress,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            _ScoreBar(
              label: battle.defenderCountryCode,
              score: battle.defenderScore,
              target: battle.targetScore,
              value: battle.defenderProgress,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            Text(
              battle.isActive
                  ? 'Ends ${_formatDate(battle.endsAt)}'
                  : 'Winner: ${winner ?? 'undecided'}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline),
                  label: Text(isSelected ? 'Refresh details' : 'Details'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      battle.isActive && !isContributing ? onContribute : null,
                  icon: isContributing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flash_on),
                  label:
                      Text(isContributing ? 'Contributing...' : 'Contribute'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleDetailsCard extends StatelessWidget {
  final BattleDetails details;
  final PlayerBattleParticipation? participation;
  final bool isLoading;
  final bool isContributing;
  final VoidCallback? onContribute;

  const _BattleDetailsCard({
    required this.details,
    required this.participation,
    required this.isLoading,
    required this.isContributing,
    required this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final myParticipation = participation;
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Battle details: ${details.battle.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (myParticipation == null)
              const Text('You have not contributed to this battle yet.')
            else
              Text(
                'Your ${myParticipation.side ?? 'battle'} contribution: '
                '${Utils.number(myParticipation.damage)} damage across '
                '${myParticipation.contributionCount} attacks. Rewards: '
                '${myParticipation.goldReward} gold, '
                '${myParticipation.experienceReward} XP.',
              ),
            const SizedBox(height: 12),
            Text(
              'Cooldown: each battle contribution uses the combat cooldown before another attack.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (details.campaign != null) ...[
              const SizedBox(height: 12),
              Text('Campaign context',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '${details.campaign!.name} • '
                '${details.campaign!.currentScore}/${details.campaign!.objectiveScore} score',
              ),
              const SizedBox(height: 8),
              if (details.phases.isEmpty)
                const Text('No battle phases are attached yet.')
              else
                ...details.phases.map(
                  (phase) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ScoreBar(
                      label: phase.name,
                      score: phase.totalDamage,
                      target: phase.targetDamage,
                      value: phase.progress,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isContributing ? null : onContribute,
              icon: isContributing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flash_on),
              label: Text(isContributing ? 'Contributing...' : 'Contribute'),
            ),
            const SizedBox(height: 16),
            Text('Latest contributions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (details.contributions.isEmpty)
              const Text('No player contributions have been recorded yet.')
            else
              ...details.contributions.map(
                (contribution) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    contribution.side == 'attacker'
                        ? Icons.north_east
                        : Icons.shield,
                  ),
                  title: Text(
                    '${contribution.countryCode} • ${contribution.damage} damage',
                  ),
                  subtitle: Text(
                    '${contribution.playerId} • ${contribution.energySpent} energy • '
                    '${contribution.goldReward} gold / ${contribution.experienceReward} XP',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContributionResultCard extends StatelessWidget {
  final BattleContributionResult result;
  const _ContributionResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.check_circle : Icons.info_outline,
          color: result.completed ? Colors.green : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: Text(
          'Damage ${result.fight.attackerDamage}; '
          'energy ${result.contribution?.energySpent ?? 0}; '
          'weapon: ${result.weaponDamage?.message ?? 'no durability used'}.',
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final int target;
  final double value;
  final Color color;

  const _ScoreBar({
    required this.label,
    required this.score,
    required this.target,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${Utils.number(score)} / ${Utils.number(target)}'),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value, color: color),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(message),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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

String _formatDate(DateTime value) {
  final local = value.toLocal().toString();
  return local.length <= 16 ? local : local.substring(0, 16);
}

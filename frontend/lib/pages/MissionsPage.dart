import 'dart:math';

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color _missionBackground = Color(0xFF100D0B);
const Color _missionSurface = Color(0xFF1B1410);
const Color _missionPanel = Color(0xFF241A13);
const Color _missionInset = Color(0xFF302217);
const Color _missionBorder = Color(0xFF5B3A1F);
const Color _missionAccent = Color(0xFFD97706);
const Color _missionGold = Color(0xFFFACC15);
const Color _missionBlue = Color(0xFF60A5FA);
const Color _missionGreen = Color(0xFF34D399);
const Color _missionText = Color(0xFFF8FAFC);
const Color _missionMuted = Color(0xFFC4A484);

class MissionsPage extends StatefulWidget {
  final User user;
  const MissionsPage({super.key, required this.user});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  late final MissionsBloc _missionsBloc;
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _missionsBloc = Provider.of<MissionsBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _missionsBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _fight(CombatMission mission) async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _missionsBloc.fight(
      playerId: widget.user.uid,
      missionId: mission.missionId,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      _playerBloc.setBearerToken(_loginBloc.currentToken);
      _inventoryBloc.setBearerToken(_loginBloc.currentToken);
      await _playerBloc.loadState(widget.user.uid);
      await _inventoryBloc.load(widget.user.uid);
      await _onboardingBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _missionsBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _repairWeapon() async {
    _missionsBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _missionsBloc.repairWeapon(
      playerId: widget.user.uid,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      await _inventoryBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _missionsBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _missionBackground,
      appBar: AppBar(
        title: const Text('Operations'),
        backgroundColor: _missionSurface,
        foregroundColor: _missionText,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh missions',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Consumer<MissionsBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.missions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.missions.isEmpty) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final questline = context.watch<OnboardingQuestlineBloc>().questline;
          final showGuidance = questline?.currentQuest?.route == '/missions' &&
              questline?.currentQuest != null;

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                OnboardingGuidanceCard(
                  questline: questline,
                  route: '/missions',
                ),
                if (showGuidance) const SizedBox(height: 16),
                if (bloc.error != null)
                  _MissionMessageCard(
                    message: bloc.error!,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                if (bloc.lastRepair != null)
                  _RepairResultCard(result: bloc.lastRepair!),
                if (bloc.lastFight != null)
                  _FightResultCard(result: bloc.lastFight!),
                _MissionHero(
                  missions: bloc.missions,
                  progress: bloc.progress,
                  equipment: bloc.equipment,
                ),
                const SizedBox(height: 16),
                _CrewStatusStrip(
                  progress: bloc.progress,
                  equipment: bloc.equipment,
                ),
                const SizedBox(height: 16),
                _EquipmentCombatCard(
                  equipment: bloc.equipment,
                  isRepairing: bloc.isRepairingWeapon,
                  onRepair: _repairWeapon,
                ),
                const SizedBox(height: 16),
                _MissionBoardSection(
                  missions: bloc.missions,
                  progress: bloc.progress,
                  fightingMissionIds: bloc.fightingMissionIds,
                  onFight: _fight,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MissionHero extends StatelessWidget {
  final List<CombatMission> missions;
  final MissionProgressSummary? progress;
  final EquipmentSummary? equipment;

  const _MissionHero({
    required this.missions,
    required this.progress,
    required this.equipment,
  });

  @override
  Widget build(BuildContext context) {
    final progressEntries = progress?.missions ?? const <MissionProgress>[];
    final attempts =
        progressEntries.fold<int>(0, (sum, mission) => sum + mission.attempts);
    final wins =
        progressEntries.fold<int>(0, (sum, mission) => sum + mission.wins);
    final cooldowns =
        progressEntries.where((mission) => mission.isOnCooldown).length;
    final rewardGold =
        missions.fold<int>(0, (sum, mission) => sum + mission.rewardGold);
    final rewardXp =
        missions.fold<int>(0, (sum, mission) => sum + mission.rewardExperience);
    final weapon = equipment?.weapon;

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
              Color(0xFF170F0A),
              Color(0xFF3B2416),
              Color(0xFF7C2D12),
            ],
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DossierHeader(
              eyebrow: 'SOCIAL RPG DOSSIER',
              title: 'Operations Board',
              subtitle:
                  'Run jobs, collect payouts, and build mastery across every combat contract.',
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
                      label: 'Jobs',
                      value: '${missions.length}',
                      detail: '$cooldowns on cooldown',
                      icon: Icons.work_history,
                      color: _missionGold,
                    ),
                    _HeroStatCard(
                      width: width,
                      label: 'Mastery',
                      value: '$wins/$attempts',
                      detail: '${_winRate(progressEntries)}% win rate',
                      icon: Icons.military_tech,
                      color: _missionGreen,
                    ),
                    _HeroStatCard(
                      width: width,
                      label: 'Payout',
                      value: Utils.number(rewardGold),
                      detail: '${Utils.number(rewardXp)} XP available',
                      icon: Icons.payments,
                      color: _missionGold,
                    ),
                    _HeroStatCard(
                      width: width,
                      label: 'Gear',
                      value:
                          weapon == null ? 'Unarmed' : '+${weapon.weaponPower}',
                      detail: weapon == null
                          ? 'Equip a weapon in inventory'
                          : '${weapon.durability}/${weapon.maxDurability} durability',
                      icon: Icons.inventory,
                      color: _missionAccent,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const _SocialRpgNotice(),
          ],
        ),
      ),
    );
  }
}

class _DossierHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _DossierHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _missionGold.withOpacity(0.45)),
          ),
          child: const Icon(
            Icons.local_police,
            color: _missionGold,
            size: 34,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.55)),
                ),
                child: Text(
                  eyebrow,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _missionText,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: _missionMuted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialRpgNotice extends StatelessWidget {
  const _SocialRpgNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _missionGold.withOpacity(0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.groups, color: _missionGold, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Classic job-board flow: do jobs, fill mastery, watch cooldowns, and use stronger gear for better outcomes.',
              style: TextStyle(color: _missionText, height: 1.3),
            ),
          ),
        ],
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
          color: const Color(0xFF21160F).withOpacity(0.86),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
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
                      color: _missionMuted,
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
                color: _missionText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(detail, style: const TextStyle(color: _missionMuted)),
          ],
        ),
      ),
    );
  }
}

class _CrewStatusStrip extends StatelessWidget {
  final MissionProgressSummary? progress;
  final EquipmentSummary? equipment;

  const _CrewStatusStrip({
    required this.progress,
    required this.equipment,
  });

  @override
  Widget build(BuildContext context) {
    final missions = progress?.missions ?? const <MissionProgress>[];
    final completedJobs = missions.where((mission) => mission.wins > 0).length;
    final attempts =
        missions.fold<int>(0, (sum, mission) => sum + mission.attempts);
    final rounds =
        missions.fold<int>(0, (sum, mission) => sum + mission.totalRounds);
    final weapon = equipment?.weapon;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _missionSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _missionBorder.withOpacity(0.8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;
          final tiles = [
            _CrewStatusTile(
              label: 'Jobs mastered',
              value: '$completedJobs',
              icon: Icons.workspace_premium,
              color: _missionGold,
            ),
            _CrewStatusTile(
              label: 'Total attempts',
              value: '$attempts',
              icon: Icons.task_alt,
              color: _missionGreen,
            ),
            _CrewStatusTile(
              label: 'Rounds fought',
              value: '$rounds',
              icon: Icons.repeat,
              color: _missionBlue,
            ),
            _CrewStatusTile(
              label: 'Crew weapon',
              value: weapon == null ? 'None' : weapon.name,
              icon: Icons.gpp_good,
              color: _missionAccent,
            ),
          ];

          if (!wide) {
            return Column(
              children: tiles
                  .map(
                    (tile) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: tile,
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            children: tiles
                .map(
                  (tile) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: tile,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _CrewStatusTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CrewStatusTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _missionInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
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
                    color: _missionMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _missionText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCombatCard extends StatelessWidget {
  final EquipmentSummary? equipment;
  final bool isRepairing;
  final Future<void> Function() onRepair;

  const _EquipmentCombatCard({
    required this.equipment,
    required this.isRepairing,
    required this.onRepair,
  });

  @override
  Widget build(BuildContext context) {
    final weapon = equipment?.weapon;
    final repairable =
        weapon != null && weapon.durability < weapon.maxDurability;
    final durabilityColor = weapon == null
        ? _missionMuted
        : weapon.durabilityProgress > 0.55
            ? _missionGreen
            : weapon.durabilityProgress > 0.2
                ? _missionGold
                : Colors.redAccent;

    return _MissionSectionCard(
      title: 'Arsenal',
      subtitle:
          'Gear is the social-RPG loadout: power helps jobs, condition limits runs.',
      icon: Icons.inventory_2,
      trailing: _MissionBadge(
        label: weapon == null ? 'Unarmed' : 'Power +${weapon.weaponPower}',
        color: weapon == null ? _missionMuted : _missionAccent,
      ),
      child: weapon == null
          ? const _MissionEmptyState(
              icon: Icons.no_accounts,
              title: 'No gear equipped',
              message:
                  'You can still do jobs, but equipped gear from inventory makes the crew stronger.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: durabilityColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: durabilityColor.withOpacity(0.45)),
                      ),
                      child: Icon(
                        Icons.gpp_good,
                        color: durabilityColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weapon.name,
                            style: const TextStyle(
                              color: _missionText,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${weapon.category} / ${weapon.durability}/${weapon.maxDurability} condition',
                            style: const TextStyle(color: _missionMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: weapon.durabilityProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(durabilityColor),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _missionAccent,
                      foregroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: repairable && !isRepairing ? onRepair : null,
                    icon: isRepairing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.build),
                    label: Text(isRepairing ? 'Repairing...' : 'Fix gear'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MissionBoardSection extends StatelessWidget {
  final List<CombatMission> missions;
  final MissionProgressSummary? progress;
  final Set<String> fightingMissionIds;
  final Future<void> Function(CombatMission mission) onFight;

  const _MissionBoardSection({
    required this.missions,
    required this.progress,
    required this.fightingMissionIds,
    required this.onFight,
  });

  @override
  Widget build(BuildContext context) {
    return _MissionSectionCard(
      title: 'Jobs',
      subtitle:
          'Classic job-board layout: requirements, payout, mastery, action.',
      icon: Icons.work_history,
      trailing: _MissionBadge(
        label: '${missions.length} jobs',
        color: _missionGold,
      ),
      child: missions.isEmpty
          ? const _MissionEmptyState(
              icon: Icons.map_outlined,
              title: 'No combat missions',
              message: 'Backend mission data will appear here once available.',
            )
          : Column(
              children: missions
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _MissionCard(
                        jobNumber: entry.key + 1,
                        mission: entry.value,
                        progress: progress?.forMission(entry.value.missionId),
                        isFighting:
                            fightingMissionIds.contains(entry.value.missionId),
                        onFight: () => onFight(entry.value),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _FightResultCard extends StatelessWidget {
  final MissionFightResult result;

  const _FightResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final won = result.fight.winner.toLowerCase() == 'attacker';
    final progress = result.missionProgress;
    return _MissionMessageCard(
      message:
          'Job result: ${won ? 'Cleared' : result.fight.winner}. Damage ${result.fight.attackerDamage}-${result.fight.defenderDamage}; mastery ${progress?.wins ?? 0}/${progress?.attempts ?? 0}; ${result.weaponDamage?.message ?? 'No gear condition changed.'} ${result.message}',
      icon: won ? Icons.workspace_premium : Icons.shield,
      color: won ? _missionGreen : _missionAccent,
    );
  }
}

class _RepairResultCard extends StatelessWidget {
  final RepairWeaponResult result;

  const _RepairResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return _MissionMessageCard(
      message: result.completed
          ? '${result.message} Spent ${Utils.number(result.goldCost)} gold and ${result.materialQuantity} ${result.materialItemName}.'
          : '${result.message} No gear fix was applied.',
      icon: result.completed ? Icons.build_circle : Icons.info_outline,
      color: result.completed ? _missionGreen : _missionAccent,
    );
  }
}

class _MissionCard extends StatelessWidget {
  final int jobNumber;
  final CombatMission mission;
  final MissionProgress? progress;
  final bool isFighting;
  final VoidCallback onFight;

  const _MissionCard({
    required this.jobNumber,
    required this.mission,
    required this.progress,
    required this.isFighting,
    required this.onFight,
  });

  @override
  Widget build(BuildContext context) {
    final cooldownUntil = progress?.cooldownUntil;
    final isOnCooldown = progress?.isOnCooldown ?? false;
    final attempts = progress?.attempts ?? 0;
    final wins = progress?.wins ?? 0;
    final winRate = attempts == 0 ? 0.0 : (wins / attempts).clamp(0.0, 1.0);
    final statusColor = isOnCooldown ? _missionGold : _missionGreen;

    final jobCode = jobNumber.toString().padLeft(2, '0');
    return Container(
      decoration: BoxDecoration(
        color: _missionPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _missionBorder.withOpacity(0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF3A2415),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: _missionBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'JOB #$jobCode',
                  style: const TextStyle(
                    color: _missionGold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                _MissionBadge(
                  label: isOnCooldown ? 'Cooldown' : 'Ready',
                  color: statusColor,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4A2E1B), Color(0xFF111827)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _missionGold.withOpacity(0.35)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.sports_mma,
                            color: _missionGold,
                            size: 30,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${mission.rounds}x',
                            style: const TextStyle(
                              color: _missionText,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mission.name,
                            style: const TextStyle(
                              color: _missionText,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            mission.description,
                            style: const TextStyle(
                              color: _missionMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _MissionProgressPanel(
                            attempts: attempts,
                            wins: wins,
                            winRate: winRate,
                            lastResult: progress?.lastResult ?? '',
                            cooldownUntil: cooldownUntil,
                            isOnCooldown: isOnCooldown,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _JobPayoutRow(
                  mission: mission,
                  attempts: attempts,
                  wins: wins,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _missionGold,
                      foregroundColor: const Color(0xFF111827),
                      disabledBackgroundColor: _missionInset,
                      disabledForegroundColor: _missionMuted,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isFighting || isOnCooldown ? null : onFight,
                    icon: isFighting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt),
                    label: Text(
                      isFighting
                          ? 'Doing job...'
                          : isOnCooldown
                              ? 'Job cooling down'
                              : 'Do Job',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPayoutRow extends StatelessWidget {
  final CombatMission mission;
  final int attempts;
  final int wins;

  const _JobPayoutRow({
    required this.mission,
    required this.attempts,
    required this.wins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _missionInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _missionBorder.withOpacity(0.7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final tiles = [
            _JobLedgerTile(
              label: 'Requires',
              value: '${mission.rounds} stamina',
              icon: Icons.flash_on,
              color: _missionBlue,
            ),
            _JobLedgerTile(
              label: 'Enemy',
              value: '${mission.defender.strength} power',
              icon: Icons.shield,
              color: _missionAccent,
            ),
            _JobLedgerTile(
              label: 'Pays',
              value: '${Utils.number(mission.rewardGold)} gold',
              icon: Icons.payments,
              color: _missionGold,
            ),
            _JobLedgerTile(
              label: 'Mastery',
              value: attempts == 0 ? '0 clears' : '$wins clears',
              icon: Icons.workspace_premium,
              color: _missionGreen,
            ),
          ];

          if (compact) {
            return Column(
              children: tiles
                  .map(
                    (tile) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: tile,
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            children: tiles
                .map(
                  (tile) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: tile,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _JobLedgerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _JobLedgerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _missionMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _missionText,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissionProgressPanel extends StatelessWidget {
  final int attempts;
  final int wins;
  final double winRate;
  final String lastResult;
  final DateTime? cooldownUntil;
  final bool isOnCooldown;

  const _MissionProgressPanel({
    required this.attempts,
    required this.wins,
    required this.winRate,
    required this.lastResult,
    required this.cooldownUntil,
    required this.isOnCooldown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _missionBorder.withOpacity(0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: _missionGold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  attempts == 0
                      ? 'Mastery: not started'
                      : 'Mastery: $wins clears from $attempts runs',
                  style: const TextStyle(
                    color: _missionText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(winRate * 100).round()}%',
                style: const TextStyle(
                  color: _missionGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: winRate,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(_missionGold),
            ),
          ),
          if (lastResult.isNotEmpty || isOnCooldown) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (lastResult.isNotEmpty) 'Last result: $lastResult',
                if (isOnCooldown && cooldownUntil != null)
                  'Cooldown: ${_formatCooldown(cooldownUntil!)}',
              ].join(' / '),
              style: TextStyle(
                color: isOnCooldown ? _missionGold : _missionMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _MissionSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _missionSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _missionBorder.withOpacity(0.7)),
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
                    color: _missionAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: _missionAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _missionText,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _missionMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
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

class _MissionStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MissionStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _missionMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _missionText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MissionBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MissionMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _MissionMessageCard({
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
                color: _missionText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MissionEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _missionPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _missionBorder.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _missionMuted, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _missionText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _missionMuted),
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
            color: _missionSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _missionBorder),
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
                style: const TextStyle(color: _missionText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _missionAccent,
                  foregroundColor: const Color(0xFF111827),
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

int _winRate(List<MissionProgress> missions) {
  final attempts =
      missions.fold<int>(0, (sum, mission) => sum + mission.attempts);
  if (attempts == 0) {
    return 0;
  }

  final wins = missions.fold<int>(0, (sum, mission) => sum + mission.wins);
  return ((wins / attempts) * 100).round();
}

String _formatCooldown(DateTime cooldownUntil) {
  final remaining = cooldownUntil.difference(DateTime.now().toUtc());
  if (remaining.inSeconds <= 0) {
    return 'ready now';
  }
  if (remaining.inHours > 0) {
    final minutes = remaining.inMinutes.remainder(60);
    return '${remaining.inHours}h ${minutes}m';
  }
  if (remaining.inMinutes > 0) {
    return '${remaining.inMinutes}m';
  }
  return '${remaining.inSeconds}s';
}

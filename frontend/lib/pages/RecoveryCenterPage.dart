import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/PlayerState.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RecoveryCenterPage extends StatefulWidget {
  final User user;
  const RecoveryCenterPage({super.key, required this.user});

  @override
  State<RecoveryCenterPage> createState() => _RecoveryCenterPageState();
}

class _RecoveryCenterPageState extends State<RecoveryCenterPage> {
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _playerBloc.loadState(widget.user.uid),
      _inventoryBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _recover() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.recoverAtHospital(widget.user.uid);
    if (result != null) {
      await _inventoryBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _playerBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Recovery Center',
      subtitle: 'Hospital energy, cooldown, and wallet readiness',
      icon: Icons.local_hospital,
      actions: [
        IconButton(
          tooltip: 'Refresh recovery center',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer2<PlayerBloc, InventoryBloc>(
        builder: (context, playerBloc, inventoryBloc, _) {
          final state = playerBloc.state;
          if (playerBloc.isLoading && state == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state == null) {
            return _ErrorState(
              message:
                  playerBloc.error ?? 'Player recovery state has not loaded.',
              onRetry: _load,
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: _RecoveryBoard(
              state: state,
              inventory: inventoryBloc.inventory,
              playerError: playerBloc.error,
              inventoryError: inventoryBloc.error,
              isRecovering: playerBloc.isRecovering,
              onRecover: _recover,
            ),
          );
        },
      ),
    );
  }
}

class _RecoveryBoard extends StatelessWidget {
  final PlayerState state;
  final InventorySummary? inventory;
  final String? playerError;
  final String? inventoryError;
  final bool isRecovering;
  final Future<void> Function() onRecover;

  const _RecoveryBoard({
    required this.state,
    required this.inventory,
    required this.playerError,
    required this.inventoryError,
    required this.isRecovering,
    required this.onRecover,
  });

  @override
  Widget build(BuildContext context) {
    final restoreAmount = state.hospitalEnergyRestore <= 0
        ? state.maxEnergy - state.energy
        : state.hospitalEnergyRestore;
    final displayRestore = restoreAmount.clamp(0, state.maxEnergy).toInt();
    final availableGold = inventory?.walletGold ?? state.gold;
    final hasEnoughGold = state.hospitalGoldCost <= availableGold;
    final isCoolingDown = state.isHospitalCoolingDown;
    final canRecover = state.canRecoverAtHospital && hasEnoughGold;
    final cooldownUntil = state.hospitalCooldownUntil;
    final cooldownText = isCoolingDown && cooldownUntil != null
        ? _formatDateTime(cooldownUntil)
        : 'Ready now';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (playerError != null)
          GameNotice(
            icon: Icons.warning_amber,
            message: playerError!,
            color: GameColors.amber,
          ),
        if (inventoryError != null)
          GameNotice(
            icon: Icons.account_balance_wallet_outlined,
            message: inventoryError!,
            color: GameColors.amber,
          ),
        GameHero(
          eyebrow: 'Hospital operations',
          title: state.isEnergyFull
              ? 'Energy reserves full'
              : 'Recover combat energy',
          subtitle:
              'Use the player-service hospital endpoint to restore energy. Cooldowns and costs are enforced by the backend.',
          icon: Icons.health_and_safety,
          accent: state.isEnergyFull ? GameColors.emerald : GameColors.crimson,
          stats: [
            GameStat(
              label: 'energy',
              value: '${state.energy}/${state.maxEnergy}',
              icon: Icons.bolt,
              color: GameColors.emerald,
            ),
            GameStat(
              label: 'restore',
              value: '+${Utils.number(displayRestore)}',
              icon: Icons.healing,
              color: GameColors.crimson,
            ),
            GameStat(
              label: 'cost',
              value: '${Utils.number(state.hospitalGoldCost)}g',
              icon: Icons.monetization_on,
              color: GameColors.amber,
            ),
            GameStat(
              label: 'wallet',
              value: '${Utils.number(availableGold)}g',
              icon: Icons.account_balance_wallet,
              color: hasEnoughGold ? GameColors.emerald : GameColors.crimson,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GameProgressBar(
                label: 'Energy readiness',
                valueLabel: '${state.energy}/${state.maxEnergy}',
                value: state.energyProgress,
                color: state.isEnergyFull
                    ? GameColors.emerald
                    : GameColors.crimson,
              ),
              const SizedBox(height: 16),
              _RecoveryStatusRow(
                icon: Icons.schedule,
                title: 'Hospital cooldown',
                value: cooldownText,
                color: isCoolingDown ? GameColors.amber : GameColors.emerald,
              ),
              _RecoveryStatusRow(
                icon: Icons.autorenew,
                title: 'Passive regeneration',
                value: _regenText(state),
                color: GameColors.cyan,
              ),
              _RecoveryStatusRow(
                icon: Icons.update,
                title: 'State updated',
                value: _formatDateTime(state.updatedAt),
                color: GameColors.violet,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isRecovering || !canRecover ? null : onRecover,
                  icon: isRecovering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(state.isEnergyFull
                          ? Icons.check_circle
                          : Icons.healing),
                  label: Text(_buttonLabel(state, hasEnoughGold, isRecovering)),
                ),
              ),
              if (!hasEnoughGold) ...[
                const SizedBox(height: 10),
                Text(
                  'You need ${Utils.number(state.hospitalGoldCost - availableGold)} more gold for recovery.',
                  style: const TextStyle(color: GameColors.crimson),
                ),
              ],
            ],
          ),
        ),
        const GameSectionTitle(
          title: 'Recovery guidance',
          subtitle:
              'Use hospitals when battle energy is low and timing matters.',
        ),
        _GuidanceCard(
          icon: Icons.shield,
          title: 'Battle-ready threshold',
          message:
              'Recover before entering combat campaigns so every fight starts with enough energy to survive multiple rounds.',
          color: GameColors.crimson,
        ),
        _GuidanceCard(
          icon: Icons.timer,
          title: 'Cooldown planning',
          message:
              'The hospital cooldown is persisted on your player state. Plan recovery around daily objectives and war windows.',
          color: GameColors.amber,
        ),
        _GuidanceCard(
          icon: Icons.account_balance_wallet,
          title: 'Wallet-backed action',
          message:
              'Gold costs come from your real economy wallet and are refreshed after a successful recovery.',
          color: GameColors.emerald,
        ),
      ],
    );
  }
}

class _RecoveryStatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _RecoveryStatusRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GameColors.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: GameColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _GuidanceCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      borderColor: color.withOpacity(0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: GameColors.textMuted,
                    height: 1.35,
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
            const Icon(Icons.error_outline,
                color: GameColors.crimson, size: 48),
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

String _buttonLabel(PlayerState state, bool hasEnoughGold, bool isRecovering) {
  if (isRecovering) {
    return 'Recovering...';
  }
  if (state.isEnergyFull) {
    return 'Energy full';
  }
  if (state.isHospitalCoolingDown) {
    return 'Hospital cooling down';
  }
  if (!hasEnoughGold) {
    return 'Not enough gold';
  }
  return 'Recover at hospital';
}

String _regenText(PlayerState state) {
  if (state.isEnergyFull) {
    return 'Capped at full energy';
  }
  final amount = state.energyRegenAmount <= 0 ? 1 : state.energyRegenAmount;
  final next = state.nextEnergyRegenAt;
  if (next != null) {
    return '+$amount at ${_formatDateTime(next)}';
  }
  if (state.energyRegenSeconds > 0) {
    return '+$amount every ${_formatDuration(state.energyRegenSeconds)}';
  }
  return 'Passive regeneration active';
}

String _formatDateTime(DateTime value) {
  return DateFormat.MMMd().add_Hm().format(value.toLocal());
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) {
    return '${hours}h ${minutes}m';
  }
  if (hours > 0) {
    return '${hours}h';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  return '${duration.inSeconds}s';
}

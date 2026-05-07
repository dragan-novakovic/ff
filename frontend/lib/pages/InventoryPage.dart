import 'dart:math';

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InventoryPage extends StatefulWidget {
  final User user;
  const InventoryPage({super.key, required this.user});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final InventoryBloc _inventoryBloc;
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _inventoryBloc.load(widget.user.uid),
      _inventoryBloc.loadLedger(widget.user.uid),
      _inventoryBloc.loadEquipment(widget.user.uid),
    ]);
  }

  Future<void> _useItem(InventoryItem item) async {
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _inventoryBloc.useItem(
      playerId: widget.user.uid,
      itemId: item.itemId,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (result != null) {
      await _playerBloc.loadState(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _inventoryBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _equipWeapon(InventoryItem item) async {
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _inventoryBloc.equipWeapon(
      playerId: widget.user.uid,
      itemId: item.itemId,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _inventoryBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _repairWeapon() async {
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _inventoryBloc.repairWeapon(
      playerId: widget.user.uid,
      idempotencyKey:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}',
    );
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _inventoryBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Consumer<InventoryBloc>(
        builder: (context, bloc, _) {
          final inventory = bloc.inventory;
          if (bloc.isLoading && inventory == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && inventory == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (inventory == null) {
            return _ErrorState(
              message: 'Inventory has not loaded yet.',
              onRetry: _load,
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StorageCard(inventory: inventory),
                const SizedBox(height: 16),
                _EquipmentCard(
                  equipment: bloc.equipment,
                  isLoading: bloc.isEquipmentLoading,
                  isRepairing: bloc.isRepairingWeapon,
                  onRepair: _repairWeapon,
                ),
                const SizedBox(height: 16),
                if (bloc.lastUse != null)
                  _InventoryUseNotice(result: bloc.lastUse!),
                if (bloc.lastEquip != null)
                  _EquipmentNotice(result: bloc.lastEquip!),
                if (bloc.lastRepair != null)
                  _RepairNotice(result: bloc.lastRepair!),
                ...inventory.items.map(
                  (item) => _InventoryItemCard(
                    item: item,
                    isUsing: bloc.usingItemIds.contains(item.itemId),
                    isEquipping: bloc.equippingItemIds.contains(item.itemId),
                    onUse: item.itemId == 'food' ? () => _useItem(item) : null,
                    onEquip: item.category == 'Weapon'
                        ? () => _equipWeapon(item)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _LedgerSection(
                  ledger: bloc.ledger,
                  isLoading: bloc.isLedgerLoading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  final InventorySummary inventory;
  const _StorageCard({required this.inventory});

  @override
  Widget build(BuildContext context) {
    final usage = inventory.storageLimit == 0
        ? 0.0
        : (inventory.storageUsed / inventory.storageLimit)
            .clamp(0, 1)
            .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Storage', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
                '${inventory.storageUsed}/${inventory.storageLimit} slots used'),
            const SizedBox(height: 8),
            Text('Wallet: ${inventory.walletGold} gold'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: usage),
          ],
        ),
      ),
    );
  }
}

class _InventoryUseNotice extends StatelessWidget {
  final InventoryItemUseResult result;
  const _InventoryUseNotice({required this.result});

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
        subtitle: Text('Food remaining in storage updates immediately.'),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final EquipmentSummary? equipment;
  final bool isLoading;
  final bool isRepairing;
  final Future<void> Function() onRepair;
  const _EquipmentCard({
    required this.equipment,
    required this.isLoading,
    required this.isRepairing,
    required this.onRepair,
  });

  @override
  Widget build(BuildContext context) {
    final weapon = equipment?.weapon;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Equipment',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (weapon == null)
              const Text('No weapon equipped.')
            else ...[
              Text(
                '${weapon.name} • Power ${weapon.weaponPower} • '
                '${weapon.durability}/${weapon.maxDurability} durability',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: weapon.durabilityProgress),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    weapon.durability < weapon.maxDurability && !isRepairing
                        ? onRepair
                        : null,
                icon: isRepairing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.build),
                label: Text(isRepairing ? 'Repairing...' : 'Repair'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EquipmentNotice extends StatelessWidget {
  final EquipWeaponResult result;
  const _EquipmentNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.gpp_good : Icons.info_outline,
          color: result.completed ? Colors.green : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: Text(
          result.equipment.weapon == null
              ? 'No weapon equipped.'
              : '${result.equipment.weapon!.name} is ready for missions.',
        ),
      ),
    );
  }
}

class _RepairNotice extends StatelessWidget {
  final RepairWeaponResult result;
  const _RepairNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.build_circle : Icons.info_outline,
          color: result.completed ? Colors.green : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: Text(
          result.completed
              ? 'Spent ${result.goldCost} gold and ${result.materialQuantity} ${result.materialItemName}.'
              : 'Weapon repair did not change inventory.',
        ),
      ),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  final LedgerSummary? ledger;
  final bool isLoading;
  const _LedgerSection({required this.ledger, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final entries = ledger?.entries ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Transaction history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('No wallet or inventory transactions yet.')
            else
              ...entries
                  .take(10)
                  .map((entry) => _LedgerEntryTile(entry: entry)),
          ],
        ),
      ),
    );
  }
}

class _LedgerEntryTile extends StatelessWidget {
  final LedgerEntry entry;
  const _LedgerEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final goldText = entry.goldDelta == 0
        ? null
        : '${entry.goldDelta > 0 ? '+' : ''}${Utils.number(entry.goldDelta)} gold';
    final itemText = entry.itemId.isEmpty || entry.itemDelta == 0
        ? null
        : '${entry.itemDelta > 0 ? '+' : ''}${Utils.number(entry.itemDelta)} ${entry.itemId}';
    final deltas = [goldText, itemText].whereType<String>().join(' • ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        entry.goldDelta >= 0 && entry.itemDelta >= 0
            ? Icons.add_circle_outline
            : Icons.remove_circle_outline,
        color: entry.goldDelta >= 0 && entry.itemDelta >= 0
            ? Colors.green
            : Colors.orange,
      ),
      title: Text(entry.description),
      subtitle: Text(
        deltas.isEmpty ? entry.entryType : '${entry.entryType} • $deltas',
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final bool isUsing;
  final bool isEquipping;
  final Future<void> Function()? onUse;
  final Future<void> Function()? onEquip;
  const _InventoryItemCard({
    required this.item,
    required this.isUsing,
    required this.isEquipping,
    required this.onUse,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2),
        title: Text(item.name),
        subtitle: Text('${item.category} • ${item.description}'),
        trailing: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'x${item.quantity}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (onUse != null)
              ElevatedButton.icon(
                onPressed: isUsing ? null : onUse,
                icon: isUsing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restaurant),
                label: Text(isUsing ? 'Using...' : 'Use'),
              ),
            if (onEquip != null)
              ElevatedButton.icon(
                onPressed: isEquipping ? null : onEquip,
                icon: isEquipping
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gpp_good),
                label: Text(isEquipping ? 'Equipping...' : 'Equip'),
              ),
          ],
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

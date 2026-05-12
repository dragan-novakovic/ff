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
      backgroundColor: const Color(0xFF08111E),
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh inventory',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (bloc.error != null)
                  _InventoryMessageCard(
                    message: bloc.error!,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                  ),
                if (bloc.lastUse != null)
                  _InventoryUseNotice(result: bloc.lastUse!),
                if (bloc.lastEquip != null)
                  _EquipmentNotice(result: bloc.lastEquip!),
                if (bloc.lastRepair != null)
                  _RepairNotice(result: bloc.lastRepair!),
                _InventoryHero(
                  inventory: inventory,
                  equipment: bloc.equipment,
                ),
                const SizedBox(height: 16),
                _EquipmentCard(
                  equipment: bloc.equipment,
                  isLoading: bloc.isEquipmentLoading,
                  isRepairing: bloc.isRepairingWeapon,
                  onRepair: _repairWeapon,
                ),
                const SizedBox(height: 16),
                _InventoryStashSection(
                  inventory: inventory,
                  usingItemIds: bloc.usingItemIds,
                  equippingItemIds: bloc.equippingItemIds,
                  onUse: _useItem,
                  onEquip: _equipWeapon,
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

class _InventoryHero extends StatelessWidget {
  final InventorySummary inventory;
  final EquipmentSummary? equipment;

  const _InventoryHero({required this.inventory, required this.equipment});

  @override
  Widget build(BuildContext context) {
    final usage = _storageUsage(inventory);
    final itemStacks = inventory.items.length;
    final itemQuantity =
        inventory.items.fold<int>(0, (sum, item) => sum + item.quantity);
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
              Color(0xFF0B1020),
              Color(0xFF1E3A8A),
              Color(0xFF7C2D12),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -28,
              child: Icon(
                Icons.inventory_2,
                size: 172,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -20,
              child: Icon(
                Icons.shield,
                size: 120,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.backpack,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const Spacer(),
                      _NeonPill(
                        label: weapon == null ? 'Vault online' : 'Armed',
                        color: weapon == null
                            ? const Color(0xFF67E8F9)
                            : const Color(0xFF86EFAC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Armory & Vault',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage gold, supplies, equipment, and the ledger that records every backend inventory mutation.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroStat(
                        icon: Icons.monetization_on,
                        label: 'Gold',
                        value: Utils.number(inventory.walletGold),
                      ),
                      _HeroStat(
                        icon: Icons.category,
                        label: 'Stacks',
                        value: itemStacks.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.all_inbox,
                        label: 'Items',
                        value: Utils.number(itemQuantity),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _StorageProgress(
                    used: inventory.storageUsed,
                    limit: inventory.storageLimit,
                    usage: usage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageProgress extends StatelessWidget {
  final int used;
  final int limit;
  final double usage;

  const _StorageProgress({
    required this.used,
    required this.limit,
    required this.usage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Storage capacity',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '$used/$limit slots',
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: usage,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.16),
            valueColor: AlwaysStoppedAnimation<Color>(_capacityColor(usage)),
          ),
        ),
      ],
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
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              icon: Icons.gpp_good,
              title: 'Equipped gear',
              subtitle: weapon == null
                  ? 'No active weapon. Equip one from the stash below.'
                  : 'Current weapon power and durability.',
              trailing: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            if (weapon == null)
              const _InlineVaultMessage(
                icon: Icons.no_encryption_gmailerrorred,
                message:
                    'No weapon equipped. Weapon cards can be equipped from storage.',
              )
            else
              _EquippedWeaponPanel(
                weapon: weapon,
                isRepairing: isRepairing,
                onRepair: onRepair,
              ),
          ],
        ),
      ),
    );
  }
}

class _EquippedWeaponPanel extends StatelessWidget {
  final EquippedWeapon weapon;
  final bool isRepairing;
  final Future<void> Function() onRepair;

  const _EquippedWeaponPanel({
    required this.weapon,
    required this.isRepairing,
    required this.onRepair,
  });

  @override
  Widget build(BuildContext context) {
    final durabilityColor = _capacityColor(weapon.durabilityProgress);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF22C55E).withOpacity(0.18),
            const Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.48),
                  ),
                ),
                child: const Icon(
                  Icons.military_tech,
                  color: Color(0xFF86EFAC),
                  size: 31,
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
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniStat(
                          icon: Icons.flash_on,
                          label: 'Power ${weapon.weaponPower}',
                        ),
                        _MiniStat(
                          icon: Icons.shield,
                          label:
                              '${weapon.durability}/${weapon.maxDurability} durability',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Durability',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${(weapon.durabilityProgress * 100).round()}%',
                style: TextStyle(
                  color: durabilityColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: weapon.durabilityProgress,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(durabilityColor),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: weapon.durability < weapon.maxDurability && !isRepairing
                ? onRepair
                : null,
            icon: isRepairing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.build),
            label: Text(isRepairing ? 'Repairing...' : 'Repair weapon'),
          ),
        ],
      ),
    );
  }
}

class _InventoryStashSection extends StatelessWidget {
  final InventorySummary inventory;
  final Set<String> usingItemIds;
  final Set<String> equippingItemIds;
  final Future<void> Function(InventoryItem item) onUse;
  final Future<void> Function(InventoryItem item) onEquip;

  const _InventoryStashSection({
    required this.inventory,
    required this.usingItemIds,
    required this.equippingItemIds,
    required this.onUse,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final categories = _groupItems(inventory.items);
    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              icon: Icons.inventory_2,
              title: 'Supply stash',
              subtitle:
                  'Grouped storage with usable food and equip-ready weapons.',
            ),
            const SizedBox(height: 16),
            if (inventory.items.isEmpty)
              const _InlineVaultMessage(
                icon: Icons.inbox,
                message:
                    'Your vault is empty. Work, produce, trade, or claim rewards to fill it.',
              )
            else
              ...categories.entries.map((entry) {
                return _InventoryCategoryShelf(
                  category: entry.key,
                  items: entry.value,
                  usingItemIds: usingItemIds,
                  equippingItemIds: equippingItemIds,
                  onUse: onUse,
                  onEquip: onEquip,
                );
              }),
          ],
        ),
      ),
    );
  }

  Map<String, List<InventoryItem>> _groupItems(List<InventoryItem> items) {
    final grouped = <String, List<InventoryItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    for (final categoryItems in grouped.values) {
      categoryItems.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }
}

class _InventoryCategoryShelf extends StatelessWidget {
  final String category;
  final List<InventoryItem> items;
  final Set<String> usingItemIds;
  final Set<String> equippingItemIds;
  final Future<void> Function(InventoryItem item) onUse;
  final Future<void> Function(InventoryItem item) onEquip;

  const _InventoryCategoryShelf({
    required this.category,
    required this.items,
    required this.usingItemIds,
    required this.equippingItemIds,
    required this.onUse,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1728),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(category), color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${items.length} stacks',
                style: TextStyle(color: Colors.white.withOpacity(0.62)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final cardWidth =
                  wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items.map((item) {
                  return SizedBox(
                    width: cardWidth,
                    child: _InventoryItemCard(
                      item: item,
                      isUsing: usingItemIds.contains(item.itemId),
                      isEquipping: equippingItemIds.contains(item.itemId),
                      color: color,
                      onUse: item.itemId == 'food' ? () => onUse(item) : null,
                      onEquip: item.category == 'Weapon'
                          ? () => onEquip(item)
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final bool isUsing;
  final bool isEquipping;
  final Color color;
  final Future<void> Function()? onUse;
  final Future<void> Function()? onEquip;

  const _InventoryItemCard({
    required this.item,
    required this.isUsing,
    required this.isEquipping,
    required this.color,
    required this.onUse,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.20),
            const Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.46), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withOpacity(0.56)),
                ),
                child: Icon(_itemIcon(item), color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _NeonPill(label: 'x${item.quantity}', color: color),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style:
                TextStyle(color: Colors.white.withOpacity(0.72), height: 1.3),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(
                  icon: _categoryIcon(item.category), label: item.category),
              _MiniStat(icon: Icons.qr_code_2, label: item.itemId),
            ],
          ),
          if (onUse != null || onEquip != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
          ],
        ],
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
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              icon: Icons.receipt_long,
              title: 'Vault ledger',
              subtitle: 'Recent gold and inventory transactions.',
              trailing: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const _InlineVaultMessage(
                icon: Icons.history,
                message: 'No wallet or inventory transactions yet.',
              )
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
    final isPositive = entry.goldDelta >= 0 && entry.itemDelta >= 0;
    final color =
        isPositive ? const Color(0xFF22C55E) : const Color(0xFFF97316);
    final goldText = entry.goldDelta == 0
        ? null
        : '${entry.goldDelta > 0 ? '+' : ''}${Utils.number(entry.goldDelta)} gold';
    final itemText = entry.itemId.isEmpty || entry.itemDelta == 0
        ? null
        : '${entry.itemDelta > 0 ? '+' : ''}${Utils.number(entry.itemDelta)} ${entry.itemId}';
    final deltas = [goldText, itemText].whereType<String>().join(' - ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1728),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPositive
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  deltas.isEmpty
                      ? entry.entryType
                      : '${entry.entryType} - $deltas',
                  style: TextStyle(color: Colors.white.withOpacity(0.62)),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(entry.createdAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.46),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryUseNotice extends StatelessWidget {
  final InventoryItemUseResult result;

  const _InventoryUseNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _InventoryMessageCard(
      message:
          '${result.message} Food remaining in storage updates immediately.',
      icon: result.completed ? Icons.check_circle : Icons.info_outline,
      color:
          result.completed ? const Color(0xFF22C55E) : const Color(0xFFF97316),
    );
  }
}

class _EquipmentNotice extends StatelessWidget {
  final EquipWeaponResult result;

  const _EquipmentNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    final weapon = result.equipment.weapon;
    return _InventoryMessageCard(
      message: weapon == null
          ? '${result.message} No weapon equipped.'
          : '${result.message} ${weapon.name} is ready for missions.',
      icon: result.completed ? Icons.gpp_good : Icons.info_outline,
      color:
          result.completed ? const Color(0xFF22C55E) : const Color(0xFFF97316),
    );
  }
}

class _RepairNotice extends StatelessWidget {
  final RepairWeaponResult result;

  const _RepairNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _InventoryMessageCard(
      message: result.completed
          ? '${result.message} Spent ${result.goldCost} gold and ${result.materialQuantity} ${result.materialItemName}.'
          : '${result.message} Weapon repair did not change inventory.',
      icon: result.completed ? Icons.build_circle : Icons.info_outline,
      color:
          result.completed ? const Color(0xFF22C55E) : const Color(0xFFF97316),
    );
  }
}

class _InventoryMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _InventoryMessageCard({
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.66)),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _InlineVaultMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineVaultMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 11,
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.68), size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.74)),
          ),
        ],
      ),
    );
  }
}

class _NeonPill extends StatelessWidget {
  final String label;
  final Color color;

  const _NeonPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.72)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
        child: Card(
          color: const Color(0xFF0F2136),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
        ),
      ),
    );
  }
}

double _storageUsage(InventorySummary inventory) {
  if (inventory.storageLimit <= 0) {
    return 0;
  }

  return (inventory.storageUsed / inventory.storageLimit)
      .clamp(0, 1)
      .toDouble();
}

Color _capacityColor(double value) {
  if (value >= 0.85) {
    return const Color(0xFFF97316);
  }
  if (value >= 0.55) {
    return const Color(0xFFFBBF24);
  }
  return const Color(0xFF22C55E);
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Weapon':
      return Icons.gpp_good;
    case 'Consumable':
      return Icons.restaurant;
    case 'Food':
      return Icons.lunch_dining;
    case 'Raw material':
      return Icons.grass;
    case 'Material':
      return Icons.construction;
    default:
      return Icons.inventory_2;
  }
}

IconData _itemIcon(InventoryItem item) {
  if (item.itemId == 'food') {
    return Icons.restaurant;
  }
  return _categoryIcon(item.category);
}

Color _categoryColor(String category) {
  switch (category) {
    case 'Weapon':
      return const Color(0xFFF97316);
    case 'Consumable':
      return const Color(0xFF22C55E);
    case 'Food':
      return const Color(0xFF84CC16);
    case 'Raw material':
      return const Color(0xFFA3E635);
    case 'Material':
      return const Color(0xFFFBBF24);
    default:
      return const Color(0xFF38BDF8);
  }
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} $hour:$minute';
}

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
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

  @override
  void initState() {
    super.initState();
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    await _inventoryBloc.load(widget.user.uid);
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
                ...inventory.items
                    .map((item) => _InventoryItemCard(item: item)),
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

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  const _InventoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2),
        title: Text(item.name),
        subtitle: Text('${item.category} • ${item.description}'),
        trailing: Text(
          'x${item.quantity}',
          style: Theme.of(context).textTheme.titleMedium,
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

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart' hide PlayerFactory;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FactoriesPage extends StatefulWidget {
  final User user;
  const FactoriesPage({super.key, required this.user});

  @override
  State<FactoriesPage> createState() => _FactoriesPageState();
}

class _FactoriesPageState extends State<FactoriesPage> {
  late final FactoriesBloc _factoriesBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _factoriesBloc = Provider.of<FactoriesBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _factoriesBloc.setBearerToken(_loginBloc.currentToken);
    await _factoriesBloc.load(widget.user.uid);
  }

  Future<void> _produce(PlayerFactory factory) async {
    _factoriesBloc.setBearerToken(_loginBloc.currentToken);
    final result =
        await _factoriesBloc.produce(widget.user.uid, factory.factoryId);
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _factoriesBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Factories')),
      body: Consumer<FactoriesBloc>(
        builder: (context, bloc, _) {
          final portfolio = bloc.portfolio;
          if (bloc.isLoading && portfolio == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && portfolio == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (portfolio == null) {
            return _ErrorState(
              message: 'Factories have not loaded yet.',
              onRetry: _load,
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (bloc.lastProduction != null)
                  _ProductionNotice(result: bloc.lastProduction!),
                ...portfolio.factories.map(
                  (factory) => _FactoryCard(
                    factory: factory,
                    isProducing:
                        bloc.producingFactoryIds.contains(factory.factoryId),
                    onProduce: () => _produce(factory),
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

class _ProductionNotice extends StatelessWidget {
  final ProductionResult result;
  const _ProductionNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(result.message),
        subtitle: Text(
          'Produced ${result.producedQuantity} ${result.producedItemId}. ${result.note}',
        ),
      ),
    );
  }
}

class _FactoryCard extends StatelessWidget {
  final PlayerFactory factory;
  final bool isProducing;
  final VoidCallback onProduce;
  const _FactoryCard({
    required this.factory,
    required this.isProducing,
    required this.onProduce,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.factory, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${factory.name} L${factory.level}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(factory.category),
            const SizedBox(height: 12),
            Text(
              'Input: ${factory.inputQuantity} ${factory.inputItemId} → Output: ${factory.outputQuantity} ${factory.outputItemId}',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: factory.canProduce && !isProducing ? onProduce : null,
              icon: isProducing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(isProducing ? 'Producing...' : 'Produce'),
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

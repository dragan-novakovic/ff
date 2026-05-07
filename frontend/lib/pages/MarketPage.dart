import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MarketPage extends StatefulWidget {
  final User user;
  const MarketPage({super.key, required this.user});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  late final MarketBloc _marketBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _marketBloc = Provider.of<MarketBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    await _marketBloc.load();
  }

  Future<void> _buy(MarketListing listing) async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.buy(widget.user.uid, listing.listingId);
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _marketBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market')),
      body: Consumer<MarketBloc>(
        builder: (context, bloc, _) {
          final market = bloc.market;
          if (bloc.isLoading && market == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && market == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (market == null) {
            return _ErrorState(
              message: 'Market listings have not loaded yet.',
              onRetry: _load,
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (bloc.lastPurchase != null)
                  _MarketPurchaseNotice(result: bloc.lastPurchase!),
                ...market.listings.map(
                  (listing) => _MarketListingCard(
                    listing: listing,
                    isBuying: bloc.buyingListingIds.contains(listing.listingId),
                    onBuy: () => _buy(listing),
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

class _MarketPurchaseNotice extends StatelessWidget {
  final MarketPurchaseResult result;
  const _MarketPurchaseNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(result.message),
        subtitle: Text('Wallet now has ${result.inventory.walletGold} gold.'),
      ),
    );
  }
}

class _MarketListingCard extends StatelessWidget {
  final MarketListing listing;
  final bool isBuying;
  final VoidCallback onBuy;
  const _MarketListingCard({
    required this.listing,
    required this.isBuying,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final total = listing.quantity * listing.pricePerUnit;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storefront, color: Colors.blue),
        title: Text(listing.itemName),
        subtitle: Text(
          '${listing.category} • ${listing.quantity} available • Seller: ${listing.sellerId}',
        ),
        trailing: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${Utils.number(listing.pricePerUnit)} gold each'),
                Text('${Utils.number(total)} gold total'),
              ],
            ),
            ElevatedButton.icon(
              onPressed: isBuying ? null : onBuy,
              icon: isBuying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_cart),
              label: Text(isBuying ? 'Buying...' : 'Buy 1'),
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

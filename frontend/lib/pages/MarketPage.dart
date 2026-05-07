import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
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
  late final InventoryBloc _inventoryBloc;
  late final LoginBloc _loginBloc;
  late final RealtimeUpdatesBloc _realtimeBloc;
  final TextEditingController _sellQuantityController =
      TextEditingController(text: '1');
  final TextEditingController _sellPriceController =
      TextEditingController(text: '1');
  final TextEditingController _tradeItemController = TextEditingController();
  final TextEditingController _tradeBuyerController = TextEditingController();
  final TextEditingController _tradeQuantityController =
      TextEditingController(text: '1');
  final TextEditingController _tradePriceController =
      TextEditingController(text: '1');
  String? _selectedSellItemId;
  String _tradeSellerType = 'player';
  String _tradeBuyerType = 'company';
  String? _selectedSellerCompanyId;

  @override
  void initState() {
    super.initState();
    _marketBloc = Provider.of<MarketBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _realtimeBloc = RealtimeUpdatesBloc();
    _load();
    _startRealtime();
  }

  Future<void> _load() async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _marketBloc.load(),
      _marketBloc.loadPlayerListings(widget.user.uid),
      _marketBloc.loadAdvanced(widget.user.uid),
      _inventoryBloc.load(widget.user.uid),
    ]);
  }

  void _startRealtime() {
    _realtimeBloc.setBearerToken(_loginBloc.currentToken);
    _realtimeBloc.start(
      playerId: widget.user.uid,
      chatToId: 'global',
      onUpdate: (update) {
        final market = update.market;
        if (market != null) {
          _marketBloc.applyRealtimeMarket(market);
        }
      },
    );
  }

  Future<void> _buy(MarketListing listing) async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.buy(
      widget.user.uid,
      listing.listingId,
      'market-buy-${widget.user.uid}-${listing.listingId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null) {
      await Future.wait([
        _marketBloc.load(),
        _marketBloc.loadPlayerListings(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
      ]);
    }
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

  Future<void> _sell() async {
    final itemId = _selectedSellItemId;
    final quantity = int.tryParse(_sellQuantityController.text.trim()) ?? 0;
    final price = int.tryParse(_sellPriceController.text.trim()) ?? 0;
    if (itemId == null || quantity <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an item, quantity, and price.')),
      );
      return;
    }

    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.sell(
      playerId: widget.user.uid,
      itemId: itemId,
      quantity: quantity,
      pricePerUnit: price,
      idempotencyKey:
          'market-sell-${widget.user.uid}-$itemId-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null) {
      await Future.wait([
        _marketBloc.load(),
        _marketBloc.loadPlayerListings(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
      ]);
    }
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

  Future<void> _cancel(MarketListing listing) async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.cancel(
      playerId: widget.user.uid,
      listingId: listing.listingId,
      idempotencyKey:
          'market-cancel-${widget.user.uid}-${listing.listingId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null) {
      await Future.wait([
        _marketBloc.load(),
        _marketBloc.loadPlayerListings(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
      ]);
    }
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

  Future<void> _createTradeOffer() async {
    final itemId = _tradeItemController.text.trim();
    final buyerId = _tradeBuyerController.text.trim();
    final quantity = int.tryParse(_tradeQuantityController.text.trim()) ?? 0;
    final price = int.tryParse(_tradePriceController.text.trim()) ?? 0;
    final sellerId = _tradeSellerType == 'player'
        ? widget.user.uid
        : (_selectedSellerCompanyId ?? '');
    if (sellerId.isEmpty ||
        buyerId.isEmpty ||
        itemId.isEmpty ||
        quantity <= 0 ||
        price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Seller, buyer, item, quantity, and price are required.')),
      );
      return;
    }

    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.createTradeOffer(
      playerId: widget.user.uid,
      sellerType: _tradeSellerType,
      sellerId: sellerId,
      buyerType: _tradeBuyerType,
      buyerId: buyerId,
      itemId: itemId,
      quantity: quantity,
      pricePerUnit: price,
      idempotencyKey:
          'trade-offer-${widget.user.uid}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null && result.completed) {
      await Future.wait([
        _inventoryBloc.load(widget.user.uid),
        _marketBloc.loadAdvanced(widget.user.uid),
      ]);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _marketBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _acceptTradeOffer(TradeOffer offer) async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.acceptTradeOffer(
      playerId: widget.user.uid,
      offerId: offer.offerId,
      idempotencyKey:
          'trade-accept-${offer.offerId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null) {
      await Future.wait([
        _inventoryBloc.load(widget.user.uid),
        _marketBloc.loadAdvanced(widget.user.uid),
      ]);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _marketBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _cancelTradeOffer(TradeOffer offer) async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.cancelTradeOffer(
      playerId: widget.user.uid,
      offerId: offer.offerId,
      idempotencyKey:
          'trade-cancel-${offer.offerId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null) {
      await Future.wait([
        _inventoryBloc.load(widget.user.uid),
        _marketBloc.loadAdvanced(widget.user.uid),
      ]);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _marketBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _realtimeBloc.dispose();
    _sellQuantityController.dispose();
    _sellPriceController.dispose();
    _tradeItemController.dispose();
    _tradeBuyerController.dispose();
    _tradeQuantityController.dispose();
    _tradePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market')),
      body: Consumer2<MarketBloc, InventoryBloc>(
        builder: (context, bloc, inventoryBloc, _) {
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
                if (bloc.lastSale != null)
                  _MarketSaleNotice(result: bloc.lastSale!),
                if (bloc.lastCancellation != null)
                  _MarketCancellationNotice(result: bloc.lastCancellation!),
                _AdvancedMarketSection(
                  priceHistory: bloc.priceHistory,
                  orderBook: bloc.orderBook,
                  tradeOffers: bloc.tradeOffers,
                  companyPortfolio: bloc.companyPortfolio,
                  sellerType: _tradeSellerType,
                  buyerType: _tradeBuyerType,
                  selectedSellerCompanyId: _selectedSellerCompanyId,
                  itemController: _tradeItemController,
                  buyerController: _tradeBuyerController,
                  quantityController: _tradeQuantityController,
                  priceController: _tradePriceController,
                  isLoading: bloc.isAdvancedLoading,
                  isCreating: bloc.isCreatingTradeOffer,
                  acceptingOfferIds: bloc.acceptingTradeOfferIds,
                  cancelingOfferIds: bloc.cancelingTradeOfferIds,
                  currentPlayerId: widget.user.uid,
                  onSellerTypeChanged: (value) => setState(() {
                    _tradeSellerType = value ?? 'player';
                    if (_tradeSellerType == 'player') {
                      _selectedSellerCompanyId = null;
                    }
                  }),
                  onBuyerTypeChanged: (value) => setState(() {
                    _tradeBuyerType = value ?? 'company';
                  }),
                  onSellerCompanyChanged: (value) =>
                      setState(() => _selectedSellerCompanyId = value),
                  onCreate: _createTradeOffer,
                  onAccept: _acceptTradeOffer,
                  onCancel: _cancelTradeOffer,
                ),
                const SizedBox(height: 8),
                _MarketSellCard(
                  inventory: inventoryBloc.inventory,
                  selectedItemId: _selectedSellItemId,
                  quantityController: _sellQuantityController,
                  priceController: _sellPriceController,
                  isSelling: bloc.isSelling,
                  onItemChanged: (value) =>
                      setState(() => _selectedSellItemId = value),
                  onSell: _sell,
                ),
                const SizedBox(height: 8),
                _MyListingsSection(
                  listings: bloc.playerListings,
                  isLoading: bloc.isPlayerListingsLoading,
                  cancelingListingIds: bloc.cancelingListingIds,
                  onCancel: _cancel,
                ),
                const SizedBox(height: 8),
                ...market.listings.map(
                  (listing) => _MarketListingCard(
                    listing: listing,
                    canBuy: listing.sellerId != widget.user.uid,
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

class _AdvancedMarketSection extends StatelessWidget {
  final MarketPriceHistory? priceHistory;
  final MarketOrderBook? orderBook;
  final TradeOfferList? tradeOffers;
  final CompanyPortfolio? companyPortfolio;
  final String sellerType;
  final String buyerType;
  final String? selectedSellerCompanyId;
  final TextEditingController itemController;
  final TextEditingController buyerController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final bool isLoading;
  final bool isCreating;
  final Set<String> acceptingOfferIds;
  final Set<String> cancelingOfferIds;
  final String currentPlayerId;
  final ValueChanged<String?> onSellerTypeChanged;
  final ValueChanged<String?> onBuyerTypeChanged;
  final ValueChanged<String?> onSellerCompanyChanged;
  final Future<void> Function() onCreate;
  final Future<void> Function(TradeOffer offer) onAccept;
  final Future<void> Function(TradeOffer offer) onCancel;

  const _AdvancedMarketSection({
    required this.priceHistory,
    required this.orderBook,
    required this.tradeOffers,
    required this.companyPortfolio,
    required this.sellerType,
    required this.buyerType,
    required this.selectedSellerCompanyId,
    required this.itemController,
    required this.buyerController,
    required this.quantityController,
    required this.priceController,
    required this.isLoading,
    required this.isCreating,
    required this.acceptingOfferIds,
    required this.cancelingOfferIds,
    required this.currentPlayerId,
    required this.onSellerTypeChanged,
    required this.onBuyerTypeChanged,
    required this.onSellerCompanyChanged,
    required this.onCreate,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final managedCompanies = (companyPortfolio?.companies ?? [])
        .where((company) => company.canManage)
        .toList();
    final managedCompanyIds =
        managedCompanies.map((company) => company.companyId).toSet();
    final sellerCompanyValue = selectedSellerCompanyId != null &&
            managedCompanyIds.contains(selectedSellerCompanyId)
        ? selectedSellerCompanyId
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Advanced market economy',
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
            const Text(
              'Persisted price history, order book, and trade contracts for player/company trades.',
            ),
            const SizedBox(height: 16),
            _TradeOfferForm(
              managedCompanies: managedCompanies,
              sellerType: sellerType,
              buyerType: buyerType,
              selectedSellerCompanyId: sellerCompanyValue,
              itemController: itemController,
              buyerController: buyerController,
              quantityController: quantityController,
              priceController: priceController,
              isCreating: isCreating,
              onSellerTypeChanged: onSellerTypeChanged,
              onBuyerTypeChanged: onBuyerTypeChanged,
              onSellerCompanyChanged: onSellerCompanyChanged,
              onCreate: onCreate,
            ),
            const Divider(height: 32),
            _TradeOfferList(
              offers: tradeOffers?.offers ?? [],
              currentPlayerId: currentPlayerId,
              managedCompanyIds: managedCompanyIds,
              acceptingOfferIds: acceptingOfferIds,
              cancelingOfferIds: cancelingOfferIds,
              onAccept: onAccept,
              onCancel: onCancel,
            ),
            const Divider(height: 32),
            _OrderBookPreview(orderBook: orderBook),
            const Divider(height: 32),
            _PriceHistoryPreview(priceHistory: priceHistory),
          ],
        ),
      ),
    );
  }
}

class _TradeOfferForm extends StatelessWidget {
  final List<CompanySummary> managedCompanies;
  final String sellerType;
  final String buyerType;
  final String? selectedSellerCompanyId;
  final TextEditingController itemController;
  final TextEditingController buyerController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final bool isCreating;
  final ValueChanged<String?> onSellerTypeChanged;
  final ValueChanged<String?> onBuyerTypeChanged;
  final ValueChanged<String?> onSellerCompanyChanged;
  final Future<void> Function() onCreate;

  const _TradeOfferForm({
    required this.managedCompanies,
    required this.sellerType,
    required this.buyerType,
    required this.selectedSellerCompanyId,
    required this.itemController,
    required this.buyerController,
    required this.quantityController,
    required this.priceController,
    required this.isCreating,
    required this.onSellerTypeChanged,
    required this.onBuyerTypeChanged,
    required this.onSellerCompanyChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create reserved trade offer',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: sellerType,
                decoration: const InputDecoration(labelText: 'Seller'),
                items: const [
                  DropdownMenuItem(value: 'player', child: Text('My player')),
                  DropdownMenuItem(value: 'company', child: Text('My company')),
                ],
                onChanged: isCreating ? null : onSellerTypeChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: buyerType,
                decoration: const InputDecoration(labelText: 'Buyer type'),
                items: const [
                  DropdownMenuItem(value: 'player', child: Text('Player')),
                  DropdownMenuItem(value: 'company', child: Text('Company')),
                ],
                onChanged: isCreating ? null : onBuyerTypeChanged,
              ),
            ),
          ],
        ),
        if (sellerType == 'company') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedSellerCompanyId,
            decoration: const InputDecoration(labelText: 'Seller company'),
            items: managedCompanies
                .map(
                  (company) => DropdownMenuItem(
                    value: company.companyId,
                    child: Text('${company.name} (${company.walletGold} gold)'),
                  ),
                )
                .toList(),
            onChanged: isCreating ? null : onSellerCompanyChanged,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: buyerController,
          enabled: !isCreating,
          decoration: InputDecoration(
            labelText:
                buyerType == 'company' ? 'Buyer company id' : 'Buyer player id',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: itemController,
                enabled: !isCreating,
                decoration: const InputDecoration(labelText: 'Item id'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: quantityController,
                enabled: !isCreating,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: priceController,
                enabled: !isCreating,
                decoration: const InputDecoration(labelText: 'Gold each'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: isCreating ? null : onCreate,
          icon: isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.handshake),
          label: Text(isCreating ? 'Creating...' : 'Create trade offer'),
        ),
      ],
    );
  }
}

class _TradeOfferList extends StatelessWidget {
  final List<TradeOffer> offers;
  final String currentPlayerId;
  final Set<String> managedCompanyIds;
  final Set<String> acceptingOfferIds;
  final Set<String> cancelingOfferIds;
  final Future<void> Function(TradeOffer offer) onAccept;
  final Future<void> Function(TradeOffer offer) onCancel;

  const _TradeOfferList({
    required this.offers,
    required this.currentPlayerId,
    required this.managedCompanyIds,
    required this.acceptingOfferIds,
    required this.cancelingOfferIds,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trade offers & contracts',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (offers.isEmpty)
          const Text('No open trade offers are available.')
        else
          ...offers.map((offer) {
            final canAccept = offer.status == 'open' &&
                ((offer.buyerType == 'player' &&
                        offer.buyerId == currentPlayerId) ||
                    (offer.buyerType == 'company' &&
                        managedCompanyIds.contains(offer.buyerId)));
            final canCancel = offer.status == 'open' &&
                (offer.creatorPlayerId == currentPlayerId ||
                    (offer.sellerType == 'player' &&
                        offer.sellerId == currentPlayerId) ||
                    (offer.sellerType == 'company' &&
                        managedCompanyIds.contains(offer.sellerId)));
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment, color: Colors.deepPurple),
              title: Text(
                '${offer.quantity} ${offer.itemName} for ${Utils.number(offer.totalPrice)} gold',
              ),
              subtitle: Text(
                '${offer.sellerType}:${offer.sellerId} → ${offer.buyerType}:${offer.buyerId} • ${offer.status}',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed:
                        canAccept && !acceptingOfferIds.contains(offer.offerId)
                            ? () => onAccept(offer)
                            : null,
                    child: Text(acceptingOfferIds.contains(offer.offerId)
                        ? 'Accepting...'
                        : 'Accept'),
                  ),
                  OutlinedButton(
                    onPressed:
                        canCancel && !cancelingOfferIds.contains(offer.offerId)
                            ? () => onCancel(offer)
                            : null,
                    child: Text(cancelingOfferIds.contains(offer.offerId)
                        ? 'Canceling...'
                        : 'Cancel'),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _OrderBookPreview extends StatelessWidget {
  final MarketOrderBook? orderBook;
  const _OrderBookPreview({required this.orderBook});

  @override
  Widget build(BuildContext context) {
    final entries = orderBook?.entries.take(5).toList() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order book', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text('No order book depth yet.')
        else
          ...entries.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${entry.itemName} Q${entry.qualityTier}'),
              subtitle: Text(
                '${entry.quantity} units across ${entry.orderCount} orders',
              ),
              trailing: Text('${Utils.number(entry.pricePerUnit)}g'),
            ),
          ),
      ],
    );
  }
}

class _PriceHistoryPreview extends StatelessWidget {
  final MarketPriceHistory? priceHistory;
  const _PriceHistoryPreview({required this.priceHistory});

  @override
  Widget build(BuildContext context) {
    final entries = priceHistory?.entries.take(5).toList() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent price history',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text('Completed trades will appear here.')
        else
          ...entries.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${entry.itemName} Q${entry.qualityTier}'),
              subtitle: Text(
                '${entry.quantity} units • ${entry.sellerType}:${entry.sellerId} → ${entry.buyerType}:${entry.buyerId}',
              ),
              trailing: Text('${Utils.number(entry.pricePerUnit)}g each'),
            ),
          ),
      ],
    );
  }
}

class _MarketCancellationNotice extends StatelessWidget {
  final MarketCancelListingResult result;
  const _MarketCancellationNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.completed ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          result.completed ? Icons.undo : Icons.info_outline,
          color: result.completed ? Colors.green : Colors.orange,
        ),
        title: Text(result.message),
        subtitle: Text(
          result.inventory == null
              ? 'No inventory refund was needed.'
              : 'Wallet: ${Utils.number(result.inventory!.walletGold)} gold.',
        ),
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

class _MarketSaleNotice extends StatelessWidget {
  final MarketSellListingResult result;
  const _MarketSaleNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        leading: const Icon(Icons.sell, color: Colors.blue),
        title: Text(result.message),
        subtitle: Text(
          'Listing ${result.listing.listingId} is open with ${result.listing.quantity} items.',
        ),
      ),
    );
  }
}

class _MyListingsSection extends StatelessWidget {
  final PlayerMarketListings? listings;
  final bool isLoading;
  final Set<String> cancelingListingIds;
  final Future<void> Function(MarketListing listing) onCancel;

  const _MyListingsSection({
    required this.listings,
    required this.isLoading,
    required this.cancelingListingIds,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final sellerListings = listings?.listings ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('My sell orders',
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
            if (sellerListings.isEmpty)
              const Text('You do not have any market listings yet.')
            else
              ...sellerListings.map(
                (listing) => _MyListingCard(
                  listing: listing,
                  isCanceling: cancelingListingIds.contains(listing.listingId),
                  onCancel: () => onCancel(listing),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  final MarketListing listing;
  final bool isCanceling;
  final Future<void> Function() onCancel;

  const _MyListingCard({
    required this.listing,
    required this.isCanceling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canCancel = listing.status == 'open' && listing.quantity > 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
      title: Text('${listing.itemName} • ${listing.status}'),
      subtitle: Text(
        '${listing.quantity} remaining at ${Utils.number(listing.pricePerUnit)} gold each',
      ),
      trailing: ElevatedButton.icon(
        onPressed: canCancel && !isCanceling ? onCancel : null,
        icon: isCanceling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel),
        label: Text(isCanceling ? 'Canceling...' : 'Cancel'),
      ),
    );
  }
}

class _MarketSellCard extends StatelessWidget {
  final InventorySummary? inventory;
  final String? selectedItemId;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final bool isSelling;
  final ValueChanged<String?> onItemChanged;
  final Future<void> Function() onSell;

  const _MarketSellCard({
    required this.inventory,
    required this.selectedItemId,
    required this.quantityController,
    required this.priceController,
    required this.isSelling,
    required this.onItemChanged,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final items = inventory?.items ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sell from inventory',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('No inventory items are available to list.')
            else ...[
              DropdownButtonFormField<String>(
                value: selectedItemId == null ||
                        !items.any((item) => item.itemId == selectedItemId)
                    ? null
                    : selectedItemId,
                decoration: const InputDecoration(labelText: 'Item'),
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.itemId,
                        child: Text('${item.name} (x${item.quantity})'),
                      ),
                    )
                    .toList(),
                onChanged: isSelling ? null : onItemChanged,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      enabled: !isSelling,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      enabled: !isSelling,
                      decoration:
                          const InputDecoration(labelText: 'Gold per item'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: isSelling ? null : onSell,
                icon: isSelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business),
                label: Text(isSelling ? 'Listing...' : 'Create sell order'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketListingCard extends StatelessWidget {
  final MarketListing listing;
  final bool canBuy;
  final bool isBuying;
  final VoidCallback onBuy;
  const _MarketListingCard({
    required this.listing,
    required this.canBuy,
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
              onPressed: isBuying || !canBuy ? null : onBuy,
              icon: isBuying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_cart),
              label: Text(isBuying ? 'Buying...' : (canBuy ? 'Buy 1' : 'Mine')),
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

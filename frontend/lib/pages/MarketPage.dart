import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color _marketBackground = Color(0xFF07111F);
const Color _marketSurface = Color(0xFF0D1B2A);
const Color _marketPanel = Color(0xFF102033);
const Color _marketInset = Color(0xFF132A42);
const Color _marketBorder = Color(0xFF25415F);
const Color _marketAccent = Color(0xFFF59E0B);
const Color _marketAccentBlue = Color(0xFF38BDF8);
const Color _marketAccentGreen = Color(0xFF34D399);
const Color _marketText = Color(0xFFF8FAFC);
const Color _marketMuted = Color(0xFF94A3B8);

InputDecoration _marketInputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _marketMuted),
    prefixIcon: icon == null ? null : Icon(icon, color: _marketAccent),
    filled: true,
    fillColor: const Color(0xFF091827),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _marketBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _marketAccent, width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: _marketBorder.withOpacity(0.5)),
    ),
  );
}

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
  late final OnboardingQuestlineBloc _onboardingBloc;
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
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
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
      _onboardingBloc.setBearerToken(_loginBloc.currentToken);
      await Future.wait([
        _marketBloc.load(),
        _marketBloc.loadPlayerListings(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
        _onboardingBloc.load(widget.user.uid),
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
      _onboardingBloc.setBearerToken(_loginBloc.currentToken);
      await Future.wait([
        _marketBloc.load(),
        _marketBloc.loadPlayerListings(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
        _onboardingBloc.load(widget.user.uid),
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
      backgroundColor: _marketBackground,
      appBar: AppBar(
        title: const Text('Market Exchange'),
        backgroundColor: _marketSurface,
        foregroundColor: _marketText,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh market',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (bloc.error != null)
                  _MarketMessageCard(
                    message: bloc.error!,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                if (bloc.lastPurchase != null)
                  _MarketPurchaseNotice(result: bloc.lastPurchase!),
                if (bloc.lastSale != null)
                  _MarketSaleNotice(result: bloc.lastSale!),
                if (bloc.lastCancellation != null)
                  _MarketCancellationNotice(result: bloc.lastCancellation!),
                if (bloc.lastTradeOffer != null)
                  _TradeOfferNotice(result: bloc.lastTradeOffer!),
                _MarketHero(
                  market: market,
                  playerListings: bloc.playerListings,
                  inventory: inventoryBloc.inventory,
                  orderBook: bloc.orderBook,
                  priceHistory: bloc.priceHistory,
                  tradeOffers: bloc.tradeOffers,
                ),
                const SizedBox(height: 16),
                _OpenMarketSection(
                  listings: market.listings,
                  currentPlayerId: widget.user.uid,
                  buyingListingIds: bloc.buyingListingIds,
                  onBuy: _buy,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                _MyListingsSection(
                  listings: bloc.playerListings,
                  isLoading: bloc.isPlayerListingsLoading,
                  cancelingListingIds: bloc.cancelingListingIds,
                  onCancel: _cancel,
                ),
                const SizedBox(height: 16),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MarketHero extends StatelessWidget {
  final MarketListings market;
  final PlayerMarketListings? playerListings;
  final InventorySummary? inventory;
  final MarketOrderBook? orderBook;
  final MarketPriceHistory? priceHistory;
  final TradeOfferList? tradeOffers;

  const _MarketHero({
    required this.market,
    required this.playerListings,
    required this.inventory,
    required this.orderBook,
    required this.priceHistory,
    required this.tradeOffers,
  });

  @override
  Widget build(BuildContext context) {
    final openListings =
        market.listings.where((listing) => listing.status == 'open').toList();
    final listedUnits =
        openListings.fold<int>(0, (sum, listing) => sum + listing.quantity);
    final marketValue = openListings.fold<int>(
      0,
      (sum, listing) => sum + listing.quantity * listing.pricePerUnit,
    );
    final myOrders = playerListings?.listings
            .where((listing) => listing.status == 'open')
            .length ??
        0;
    final openOffers =
        tradeOffers?.offers.where((offer) => offer.status == 'open').length ??
            0;

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
              Color(0xFF07111F),
              Color(0xFF12345A),
              Color(0xFF7C2D12),
            ],
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    color: _marketAccent,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'National Trade Exchange',
                        style: TextStyle(
                          color: _marketText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Buy supplies, list surplus inventory, and negotiate reserved player or company contracts.',
                        style: TextStyle(color: _marketMuted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 720
                    ? 4
                    : constraints.maxWidth > 460
                        ? 2
                        : 1;
                final spacing = 10.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _MarketStatCard(
                      width: width,
                      label: 'Open orders',
                      value: '${openListings.length}',
                      detail: '$listedUnits units listed',
                      icon: Icons.receipt_long,
                      color: _marketAccentBlue,
                    ),
                    _MarketStatCard(
                      width: width,
                      label: 'Board value',
                      value: Utils.number(marketValue),
                      detail: 'gold in public asks',
                      icon: Icons.monetization_on,
                      color: _marketAccent,
                    ),
                    _MarketStatCard(
                      width: width,
                      label: 'My orders',
                      value: '$myOrders',
                      detail:
                          '${Utils.number(inventory?.walletGold ?? 0)} gold',
                      icon: Icons.account_balance_wallet,
                      color: _marketAccentGreen,
                    ),
                    _MarketStatCard(
                      width: width,
                      label: 'Contracts',
                      value: '$openOffers',
                      detail:
                          '${orderBook?.entries.length ?? 0} depth / ${priceHistory?.entries.length ?? 0} trades',
                      icon: Icons.handshake,
                      color: Colors.purpleAccent,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketStatCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _MarketStatCard({
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
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                      color: _marketMuted,
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
              style: const TextStyle(
                color: _marketText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(detail, style: const TextStyle(color: _marketMuted)),
          ],
        ),
      ),
    );
  }
}

class _OpenMarketSection extends StatelessWidget {
  final List<MarketListing> listings;
  final String currentPlayerId;
  final Set<String> buyingListingIds;
  final Future<void> Function(MarketListing listing) onBuy;

  const _OpenMarketSection({
    required this.listings,
    required this.currentPlayerId,
    required this.buyingListingIds,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return _MarketSectionCard(
      title: 'Exchange board',
      subtitle: 'Live public sell orders from citizens and companies.',
      icon: Icons.travel_explore,
      trailing: _MarketBadge(
        label: '${listings.length} orders',
        color: _marketAccentBlue,
      ),
      child: listings.isEmpty
          ? const _MarketEmptyState(
              icon: Icons.store_mall_directory_outlined,
              title: 'No public listings',
              message: 'The market board is quiet. Create a sell order below.',
            )
          : Column(
              children: listings
                  .map(
                    (listing) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _MarketListingCard(
                        listing: listing,
                        canBuy: listing.sellerId != currentPlayerId,
                        isBuying: buyingListingIds.contains(listing.listingId),
                        onBuy: () => onBuy(listing),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _MarketSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool isLoading;

  const _MarketSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _marketSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _marketBorder.withOpacity(0.7)),
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
                    color: _marketAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: _marketAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _marketText,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style:
                            const TextStyle(color: _marketMuted, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (trailing != null)
                  trailing!,
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

class _MarketSubCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _MarketSubCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _marketPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _marketBorder.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _marketAccentBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _marketText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(color: _marketMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MarketBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _MarketBadge({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MarketEmptyState({
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
        color: _marketPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _marketBorder.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _marketMuted, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _marketText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _marketMuted),
          ),
        ],
      ),
    );
  }
}

class _MarketFieldWrap extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const _MarketFieldWrap({
    required this.columns,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualColumns = constraints.maxWidth < 520 ? 1 : columns;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (actualColumns - 1)) /
            actualColumns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _MarketMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _MarketMessageCard({
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
                color: _marketText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeOfferNotice extends StatelessWidget {
  final TradeOfferResult result;
  const _TradeOfferNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.completed ? _marketAccentGreen : _marketAccent;
    final detail = result.contract != null
        ? 'Contract ${result.contract!.status} for ${Utils.number(result.totalPrice)} gold.'
        : result.offer != null
            ? '${result.offer!.quantity} ${result.offer!.itemName} reserved at ${Utils.number(result.offer!.pricePerUnit)} gold each.'
            : '${Utils.number(result.totalPrice)} gold total.';
    return _MarketMessageCard(
      message: '${result.message} $detail',
      icon: result.completed ? Icons.verified : Icons.handshake,
      color: color,
    );
  }
}

Color _marketStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return _marketAccentGreen;
    case 'completed':
    case 'fulfilled':
      return _marketAccentBlue;
    case 'cancelled':
    case 'canceled':
      return Colors.redAccent;
    default:
      return _marketAccent;
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

    return _MarketSectionCard(
      title: 'Contract terminal',
      subtitle:
          'Reserved trade offers, order-book depth, and persisted price history.',
      icon: Icons.insights,
      isLoading: isLoading,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final form = _TradeOfferForm(
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
              );
              final offers = _TradeOfferList(
                offers: tradeOffers?.offers ?? [],
                currentPlayerId: currentPlayerId,
                managedCompanyIds: managedCompanyIds,
                acceptingOfferIds: acceptingOfferIds,
                cancelingOfferIds: cancelingOfferIds,
                onAccept: onAccept,
                onCancel: onCancel,
              );

              if (!wide) {
                return Column(
                  children: [
                    form,
                    const SizedBox(height: 12),
                    offers,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: form),
                  const SizedBox(width: 12),
                  Expanded(child: offers),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final orderBookPreview = _OrderBookPreview(orderBook: orderBook);
              final historyPreview =
                  _PriceHistoryPreview(priceHistory: priceHistory);

              if (!wide) {
                return Column(
                  children: [
                    orderBookPreview,
                    const SizedBox(height: 12),
                    historyPreview,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: orderBookPreview),
                  const SizedBox(width: 12),
                  Expanded(child: historyPreview),
                ],
              );
            },
          ),
        ],
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
    const menuTextStyle = TextStyle(color: _marketText);
    return _MarketSubCard(
      title: 'Create reserved trade',
      subtitle: 'Lock an offer to a specific citizen or company.',
      icon: Icons.handshake,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MarketFieldWrap(
            columns: 2,
            children: [
              DropdownButtonFormField<String>(
                value: sellerType,
                dropdownColor: _marketPanel,
                style: menuTextStyle,
                decoration: _marketInputDecoration(
                  'Seller',
                  icon: Icons.outbound,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'player',
                    child: Text('My player', style: menuTextStyle),
                  ),
                  DropdownMenuItem(
                    value: 'company',
                    child: Text('My company', style: menuTextStyle),
                  ),
                ],
                onChanged: isCreating ? null : onSellerTypeChanged,
              ),
              DropdownButtonFormField<String>(
                value: buyerType,
                dropdownColor: _marketPanel,
                style: menuTextStyle,
                decoration: _marketInputDecoration(
                  'Buyer type',
                  icon: Icons.login,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'player',
                    child: Text('Player', style: menuTextStyle),
                  ),
                  DropdownMenuItem(
                    value: 'company',
                    child: Text('Company', style: menuTextStyle),
                  ),
                ],
                onChanged: isCreating ? null : onBuyerTypeChanged,
              ),
            ],
          ),
          if (sellerType == 'company') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedSellerCompanyId,
              dropdownColor: _marketPanel,
              style: menuTextStyle,
              decoration: _marketInputDecoration(
                'Seller company',
                icon: Icons.business_center,
              ),
              items: managedCompanies
                  .map(
                    (company) => DropdownMenuItem(
                      value: company.companyId,
                      child: Text(
                        '${company.name} (${Utils.number(company.walletGold)} gold)',
                        style: menuTextStyle,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isCreating ? null : onSellerCompanyChanged,
            ),
          ],
          const SizedBox(height: 12),
          _MarketFieldWrap(
            columns: 2,
            children: [
              TextField(
                controller: buyerController,
                enabled: !isCreating,
                style: menuTextStyle,
                cursorColor: _marketAccent,
                decoration: _marketInputDecoration(
                  buyerType == 'company'
                      ? 'Buyer company id'
                      : 'Buyer player id',
                  icon: Icons.badge,
                ),
              ),
              TextField(
                controller: itemController,
                enabled: !isCreating,
                style: menuTextStyle,
                cursorColor: _marketAccent,
                decoration: _marketInputDecoration(
                  'Item id',
                  icon: Icons.inventory_2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MarketFieldWrap(
            columns: 2,
            children: [
              TextField(
                controller: quantityController,
                enabled: !isCreating,
                style: menuTextStyle,
                cursorColor: _marketAccent,
                decoration: _marketInputDecoration(
                  'Quantity',
                  icon: Icons.numbers,
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                enabled: !isCreating,
                style: menuTextStyle,
                cursorColor: _marketAccent,
                decoration: _marketInputDecoration(
                  'Gold each',
                  icon: Icons.monetization_on,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _marketAccent,
              foregroundColor: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
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
      ),
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
    return _MarketSubCard(
      title: 'Open contracts',
      subtitle: 'Accept or cancel reserved trades you control.',
      icon: Icons.assignment,
      trailing: _MarketBadge(label: '${offers.length}', color: _marketAccent),
      child: offers.isEmpty
          ? const _MarketEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No open trade offers',
              message:
                  'Reserved player and company contracts will appear here.',
            )
          : Column(
              children: offers.map((offer) {
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
                final statusColor = _marketStatusColor(offer.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _marketInset,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _marketBorder.withOpacity(0.7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${offer.quantity} ${offer.itemName}',
                              style: const TextStyle(
                                color: _marketText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _MarketBadge(
                            label: offer.status,
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${Utils.number(offer.pricePerUnit)} gold each / ${Utils.number(offer.totalPrice)} total',
                        style: const TextStyle(color: _marketAccent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${offer.sellerType}:${offer.sellerId} -> ${offer.buyerType}:${offer.buyerId}',
                        style: const TextStyle(color: _marketMuted),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _marketAccentGreen,
                              foregroundColor: const Color(0xFF052E2B),
                            ),
                            onPressed: canAccept &&
                                    !acceptingOfferIds.contains(offer.offerId)
                                ? () => onAccept(offer)
                                : null,
                            child: Text(
                              acceptingOfferIds.contains(offer.offerId)
                                  ? 'Accepting...'
                                  : 'Accept',
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            onPressed: canCancel &&
                                    !cancelingOfferIds.contains(offer.offerId)
                                ? () => onCancel(offer)
                                : null,
                            child: Text(
                              cancelingOfferIds.contains(offer.offerId)
                                  ? 'Canceling...'
                                  : 'Cancel',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _OrderBookPreview extends StatelessWidget {
  final MarketOrderBook? orderBook;
  const _OrderBookPreview({required this.orderBook});

  @override
  Widget build(BuildContext context) {
    final entries = orderBook?.entries.take(5).toList() ?? [];
    return _MarketSubCard(
      title: 'Order book',
      subtitle: 'Best visible supply levels.',
      icon: Icons.stacked_bar_chart,
      child: entries.isEmpty
          ? const _MarketEmptyState(
              icon: Icons.bar_chart,
              title: 'No depth yet',
              message: 'Open listings will build market depth here.',
            )
          : Column(
              children: entries
                  .map(
                    (entry) => _MarketDataRow(
                      title: '${entry.itemName} Q${entry.qualityTier}',
                      subtitle:
                          '${entry.quantity} units across ${entry.orderCount} orders',
                      value: '${Utils.number(entry.pricePerUnit)}g',
                      icon: Icons.layers,
                      color: _marketAccentBlue,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PriceHistoryPreview extends StatelessWidget {
  final MarketPriceHistory? priceHistory;
  const _PriceHistoryPreview({required this.priceHistory});

  @override
  Widget build(BuildContext context) {
    final entries = priceHistory?.entries.take(5).toList() ?? [];
    return _MarketSubCard(
      title: 'Price history',
      subtitle: 'Recent completed trades.',
      icon: Icons.show_chart,
      child: entries.isEmpty
          ? const _MarketEmptyState(
              icon: Icons.history,
              title: 'No trades recorded',
              message: 'Completed trades will chart price history here.',
            )
          : Column(
              children: entries
                  .map(
                    (entry) => _MarketDataRow(
                      title: '${entry.itemName} Q${entry.qualityTier}',
                      subtitle:
                          '${entry.quantity} units / ${entry.sellerType}:${entry.sellerId} -> ${entry.buyerType}:${entry.buyerId}',
                      value: '${Utils.number(entry.pricePerUnit)}g each',
                      icon: Icons.timeline,
                      color: _marketAccentGreen,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _MarketDataRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _MarketDataRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _marketInset,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _marketBorder.withOpacity(0.65)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _marketText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: _marketMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MarketCancellationNotice extends StatelessWidget {
  final MarketCancelListingResult result;
  const _MarketCancellationNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    final detail = result.inventory == null
        ? 'No inventory refund was needed.'
        : 'Wallet: ${Utils.number(result.inventory!.walletGold)} gold.';
    return _MarketMessageCard(
      message: '${result.message} $detail',
      icon: result.completed ? Icons.undo : Icons.info_outline,
      color: result.completed ? _marketAccentGreen : _marketAccent,
    );
  }
}

class _MarketPurchaseNotice extends StatelessWidget {
  final MarketPurchaseResult result;
  const _MarketPurchaseNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _MarketMessageCard(
      message:
          '${result.message} Wallet now has ${Utils.number(result.inventory.walletGold)} gold.',
      icon: Icons.check_circle,
      color: _marketAccentGreen,
    );
  }
}

class _MarketSaleNotice extends StatelessWidget {
  final MarketSellListingResult result;
  const _MarketSaleNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _MarketMessageCard(
      message:
          '${result.message} Listing is open with ${result.listing.quantity} items.',
      icon: Icons.sell,
      color: _marketAccentBlue,
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
    return _MarketSectionCard(
      title: 'My sell orders',
      subtitle: 'Manage listings backed by your current inventory.',
      icon: Icons.receipt_long,
      isLoading: isLoading,
      trailing: _MarketBadge(
        label: '${sellerListings.length} listed',
        color: _marketAccentGreen,
      ),
      child: sellerListings.isEmpty
          ? const _MarketEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No active sell orders',
              message: 'List surplus supplies to start earning gold.',
            )
          : Column(
              children: sellerListings
                  .map(
                    (listing) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _MyListingCard(
                        listing: listing,
                        isCanceling:
                            cancelingListingIds.contains(listing.listingId),
                        onCancel: () => onCancel(listing),
                      ),
                    ),
                  )
                  .toList(),
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
    final statusColor = _marketStatusColor(listing.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _marketPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _marketBorder.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.sell, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.itemName,
                      style: const TextStyle(
                        color: _marketText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.quantity} remaining at ${Utils.number(listing.pricePerUnit)} gold each',
                      style: const TextStyle(color: _marketMuted),
                    ),
                  ],
                ),
              ),
              _MarketBadge(label: listing.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: canCancel && !isCanceling ? onCancel : null,
              icon: isCanceling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel),
              label: Text(isCanceling ? 'Canceling...' : 'Cancel order'),
            ),
          ),
        ],
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
    const fieldTextStyle = TextStyle(color: _marketText);
    final selectedValue = selectedItemId == null ||
            !items.any((item) => item.itemId == selectedItemId)
        ? null
        : selectedItemId;
    final totalItems = items.fold<int>(0, (sum, item) => sum + item.quantity);

    return _MarketSectionCard(
      title: 'Merchant counter',
      subtitle: 'Turn inventory stacks into public sell orders.',
      icon: Icons.add_business,
      trailing: _MarketBadge(
        label: '${items.length} stacks / ${Utils.number(totalItems)} units',
        color: _marketAccent,
      ),
      child: items.isEmpty
          ? const _MarketEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No inventory to list',
              message: 'Gather supplies before opening a market order.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedValue,
                  dropdownColor: _marketPanel,
                  style: fieldTextStyle,
                  decoration:
                      _marketInputDecoration('Item', icon: Icons.inventory),
                  items: items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.itemId,
                          child: Text(
                            '${item.name} (x${item.quantity})',
                            style: fieldTextStyle,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isSelling ? null : onItemChanged,
                ),
                const SizedBox(height: 12),
                _MarketFieldWrap(
                  columns: 2,
                  children: [
                    TextField(
                      controller: quantityController,
                      enabled: !isSelling,
                      style: fieldTextStyle,
                      cursorColor: _marketAccent,
                      decoration: _marketInputDecoration('Quantity',
                          icon: Icons.numbers),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: priceController,
                      enabled: !isSelling,
                      style: fieldTextStyle,
                      cursorColor: _marketAccent,
                      decoration: _marketInputDecoration(
                        'Gold per item',
                        icon: Icons.monetization_on,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _marketAccent,
                    foregroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
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
    final statusColor = _marketStatusColor(listing.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _marketPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _marketBorder.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _marketAccentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.storefront, color: _marketAccentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.itemName,
                      style: const TextStyle(
                        color: _marketText,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.category} / Seller ${listing.sellerId}',
                      style: const TextStyle(color: _marketMuted),
                    ),
                  ],
                ),
              ),
              _MarketBadge(label: listing.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MarketBadge(
                label: '${listing.quantity} available',
                color: _marketAccentGreen,
                icon: Icons.inventory_2,
              ),
              _MarketBadge(
                label: '${Utils.number(listing.pricePerUnit)}g each',
                color: _marketAccent,
                icon: Icons.monetization_on,
              ),
              _MarketBadge(
                label: '${Utils.number(total)}g total',
                color: _marketAccentBlue,
                icon: Icons.calculate,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _marketAccentGreen,
                foregroundColor: const Color(0xFF052E2B),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: isBuying || !canBuy ? null : onBuy,
              icon: isBuying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_cart),
              label: Text(
                  isBuying ? 'Buying...' : (canBuy ? 'Buy 1' : 'My order')),
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
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _marketSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _marketBorder),
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
                style: const TextStyle(color: _marketText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _marketAccent,
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

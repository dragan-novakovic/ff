import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CompanyContractsPage extends StatefulWidget {
  final User user;
  const CompanyContractsPage({super.key, required this.user});

  @override
  State<CompanyContractsPage> createState() => _CompanyContractsPageState();
}

class _CompanyContractsPageState extends State<CompanyContractsPage> {
  late final MarketBloc _marketBloc;
  late final InventoryBloc _inventoryBloc;
  late final LoginBloc _loginBloc;
  final TextEditingController _buyerController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _priceController =
      TextEditingController(text: '1');
  String _sellerType = 'company';
  String _buyerType = 'company';
  String? _selectedSellerCompanyId;
  bool _actionableOnly = false;

  @override
  void initState() {
    super.initState();
    _marketBloc = Provider.of<MarketBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _marketBloc.loadAdvanced(widget.user.uid),
      _inventoryBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _createTradeOffer() async {
    final itemId = _itemController.text.trim();
    final buyerId = _buyerController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final sellerId = _sellerType == 'player'
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
              Text('Seller, buyer, item, quantity, and price are required.'),
        ),
      );
      return;
    }

    _marketBloc.setBearerToken(_loginBloc.currentToken);
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _marketBloc.createTradeOffer(
      playerId: widget.user.uid,
      sellerType: _sellerType,
      sellerId: sellerId,
      buyerType: _buyerType,
      buyerId: buyerId,
      itemId: itemId,
      quantity: quantity,
      pricePerUnit: price,
      idempotencyKey:
          'company-contract-${widget.user.uid}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null && result.completed) {
      _itemController.clear();
      _buyerController.clear();
      _quantityController.text = '1';
      _priceController.text = '1';
      await Future.wait([
        _marketBloc.loadAdvanced(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
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
          'company-contract-accept-${offer.offerId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null) {
      await Future.wait([
        _marketBloc.loadAdvanced(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
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
          'company-contract-cancel-${offer.offerId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result != null) {
      await Future.wait([
        _marketBloc.loadAdvanced(widget.user.uid),
        _inventoryBloc.load(widget.user.uid),
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
    _buyerController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Company Contracts',
      subtitle: 'Reserved trade offers backed by the market service',
      icon: Icons.handshake,
      actions: [
        IconButton(
          tooltip: 'Refresh contracts',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer2<MarketBloc, InventoryBloc>(
        builder: (context, marketBloc, inventoryBloc, _) {
          final tradeOffers = marketBloc.tradeOffers;
          final portfolio = marketBloc.companyPortfolio;
          final isLoading = marketBloc.isAdvancedLoading &&
              tradeOffers == null &&
              portfolio == null;
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tradeOffers == null &&
              portfolio == null &&
              marketBloc.error != null) {
            return _ErrorState(message: marketBloc.error!, onRetry: _load);
          }

          final managedCompanies = (portfolio?.companies ?? [])
              .where((company) => company.canManage)
              .toList();
          final managedCompanyIds =
              managedCompanies.map((company) => company.companyId).toSet();
          final sellerCompanyValue = _selectedSellerCompanyId != null &&
                  managedCompanyIds.contains(_selectedSellerCompanyId)
              ? _selectedSellerCompanyId
              : null;
          final visibleOffers = _filterOffers(
            tradeOffers?.offers ?? const <TradeOffer>[],
            widget.user.uid,
            managedCompanyIds,
            actionableOnly: _actionableOnly,
          );

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (marketBloc.error != null)
                  GameNotice(
                    icon: Icons.warning_amber,
                    message: marketBloc.error!,
                    color: GameColors.amber,
                  ),
                if (marketBloc.lastTradeOffer != null)
                  _ContractNotice(result: marketBloc.lastTradeOffer!),
                GameHero(
                  eyebrow: 'Company trade desk',
                  title: 'Reserved contracts',
                  subtitle:
                      'Create, accept, and cancel persisted trade offers for your player and managed companies.',
                  icon: Icons.assignment_turned_in,
                  accent: GameColors.amber,
                  stats: [
                    GameStat(
                      label: 'managed companies',
                      value: Utils.number(managedCompanies.length),
                      icon: Icons.business_center,
                      color: GameColors.amber,
                    ),
                    GameStat(
                      label: 'open contracts',
                      value: Utils.number(visibleOffers.length),
                      icon: Icons.assignment,
                      color: GameColors.cyan,
                    ),
                    GameStat(
                      label: 'wallet',
                      value:
                          '${Utils.number(inventoryBloc.inventory?.walletGold ?? 0)}g',
                      icon: Icons.account_balance_wallet,
                      color: GameColors.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CompanyStrip(companies: managedCompanies),
                const SizedBox(height: 12),
                _CreateContractPanel(
                  managedCompanies: managedCompanies,
                  sellerType: _sellerType,
                  buyerType: _buyerType,
                  selectedSellerCompanyId: sellerCompanyValue,
                  buyerController: _buyerController,
                  itemController: _itemController,
                  quantityController: _quantityController,
                  priceController: _priceController,
                  isCreating: marketBloc.isCreatingTradeOffer,
                  onSellerTypeChanged: (value) => setState(() {
                    _sellerType = value ?? 'company';
                    if (_sellerType == 'player') {
                      _selectedSellerCompanyId = null;
                    }
                  }),
                  onBuyerTypeChanged: (value) =>
                      setState(() => _buyerType = value ?? 'company'),
                  onSellerCompanyChanged: (value) =>
                      setState(() => _selectedSellerCompanyId = value),
                  onCreate: _createTradeOffer,
                ),
                const GameSectionTitle(
                  title: 'Open company contracts',
                  subtitle:
                      'Only offers tied to your player or managed companies are shown here.',
                ),
                _ContractFilterBar(
                  actionableOnly: _actionableOnly,
                  onChanged: (value) => setState(() => _actionableOnly = value),
                ),
                const SizedBox(height: 12),
                if (visibleOffers.isEmpty)
                  const GameEmptyState(
                    icon: Icons.assignment_outlined,
                    message:
                        'No company contracts are waiting on your desk right now.',
                  )
                else
                  ...visibleOffers.map(
                    (offer) => _ContractCard(
                      offer: offer,
                      currentPlayerId: widget.user.uid,
                      managedCompanyIds: managedCompanyIds,
                      isAccepting: marketBloc.acceptingTradeOfferIds
                          .contains(offer.offerId),
                      isCanceling: marketBloc.cancelingTradeOfferIds
                          .contains(offer.offerId),
                      onAccept: () => _acceptTradeOffer(offer),
                      onCancel: () => _cancelTradeOffer(offer),
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

List<TradeOffer> _filterOffers(
  List<TradeOffer> offers,
  String currentPlayerId,
  Set<String> managedCompanyIds, {
  required bool actionableOnly,
}) {
  return offers.where((offer) {
    final touchesCompany = offer.sellerType == 'company' ||
        offer.buyerType == 'company' ||
        managedCompanyIds.contains(offer.sellerId) ||
        managedCompanyIds.contains(offer.buyerId);
    final controlled = offer.creatorPlayerId == currentPlayerId ||
        (offer.sellerType == 'player' && offer.sellerId == currentPlayerId) ||
        (offer.buyerType == 'player' && offer.buyerId == currentPlayerId) ||
        (offer.sellerType == 'company' &&
            managedCompanyIds.contains(offer.sellerId)) ||
        (offer.buyerType == 'company' &&
            managedCompanyIds.contains(offer.buyerId));
    if (!touchesCompany || !controlled) {
      return false;
    }
    if (!actionableOnly) {
      return true;
    }
    return _canAcceptOffer(offer, currentPlayerId, managedCompanyIds) ||
        _canCancelOffer(offer, currentPlayerId, managedCompanyIds);
  }).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

bool _canAcceptOffer(
  TradeOffer offer,
  String currentPlayerId,
  Set<String> managedCompanyIds,
) {
  return offer.status == 'open' &&
      ((offer.buyerType == 'player' && offer.buyerId == currentPlayerId) ||
          (offer.buyerType == 'company' &&
              managedCompanyIds.contains(offer.buyerId)));
}

bool _canCancelOffer(
  TradeOffer offer,
  String currentPlayerId,
  Set<String> managedCompanyIds,
) {
  return offer.status == 'open' &&
      (offer.creatorPlayerId == currentPlayerId ||
          (offer.sellerType == 'player' && offer.sellerId == currentPlayerId) ||
          (offer.sellerType == 'company' &&
              managedCompanyIds.contains(offer.sellerId)));
}

class _CompanyStrip extends StatelessWidget {
  final List<CompanySummary> companies;

  const _CompanyStrip({required this.companies});

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Managed companies',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Contracts can sell from companies where you have manager access.',
            style: TextStyle(color: GameColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (companies.isEmpty)
            const Text(
              'No manageable companies loaded. You can still create player-side reserved offers.',
              style: TextStyle(color: GameColors.textMuted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: companies
                  .map(
                    (company) => GameStatPill(
                      stat: GameStat(
                        label: company.role ?? 'manager',
                        value:
                            '${company.name} (${Utils.number(company.walletGold)}g)',
                        icon: Icons.business,
                        color: GameColors.amber,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _CreateContractPanel extends StatelessWidget {
  final List<CompanySummary> managedCompanies;
  final String sellerType;
  final String buyerType;
  final String? selectedSellerCompanyId;
  final TextEditingController buyerController;
  final TextEditingController itemController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final bool isCreating;
  final ValueChanged<String?> onSellerTypeChanged;
  final ValueChanged<String?> onBuyerTypeChanged;
  final ValueChanged<String?> onSellerCompanyChanged;
  final Future<void> Function() onCreate;

  const _CreateContractPanel({
    required this.managedCompanies,
    required this.sellerType,
    required this.buyerType,
    required this.selectedSellerCompanyId,
    required this.buyerController,
    required this.itemController,
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
    return GamePanel(
      borderColor: GameColors.amber.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: GameColors.amber.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GameColors.amber.withOpacity(0.35)),
                ),
                child: const Icon(Icons.handshake, color: GameColors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create reserved trade',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const Text(
                      'Lock an offer to a specific player or company ID.',
                      style: TextStyle(color: GameColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldWrap(
            children: [
              DropdownButtonFormField<String>(
                value: sellerType,
                decoration: _inputDecoration('Seller', Icons.outbound),
                items: const [
                  DropdownMenuItem(value: 'company', child: Text('My company')),
                  DropdownMenuItem(value: 'player', child: Text('My player')),
                ],
                onChanged: isCreating ? null : onSellerTypeChanged,
              ),
              DropdownButtonFormField<String>(
                value: buyerType,
                decoration: _inputDecoration('Buyer type', Icons.login),
                items: const [
                  DropdownMenuItem(value: 'company', child: Text('Company')),
                  DropdownMenuItem(value: 'player', child: Text('Player')),
                ],
                onChanged: isCreating ? null : onBuyerTypeChanged,
              ),
            ],
          ),
          if (sellerType == 'company') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedSellerCompanyId,
              decoration: _inputDecoration('Seller company', Icons.business),
              items: managedCompanies
                  .map(
                    (company) => DropdownMenuItem(
                      value: company.companyId,
                      child: Text(
                        '${company.name} (${Utils.number(company.walletGold)}g)',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isCreating ? null : onSellerCompanyChanged,
            ),
          ],
          const SizedBox(height: 12),
          _FieldWrap(
            children: [
              TextField(
                controller: buyerController,
                enabled: !isCreating,
                decoration: _inputDecoration(
                  buyerType == 'company'
                      ? 'Buyer company id'
                      : 'Buyer player id',
                  Icons.badge,
                ),
              ),
              TextField(
                controller: itemController,
                enabled: !isCreating,
                decoration: _inputDecoration('Item id', Icons.inventory_2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FieldWrap(
            children: [
              TextField(
                controller: quantityController,
                enabled: !isCreating,
                decoration: _inputDecoration('Quantity', Icons.numbers),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                enabled: !isCreating,
                decoration:
                    _inputDecoration('Gold each', Icons.monetization_on),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: isCreating ? null : onCreate,
            icon: isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_business),
            label: Text(isCreating ? 'Creating...' : 'Create company contract'),
          ),
        ],
      ),
    );
  }
}

class _ContractFilterBar extends StatelessWidget {
  final bool actionableOnly;
  final ValueChanged<bool> onChanged;

  const _ContractFilterBar({
    required this.actionableOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: GameColors.cyan),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Show only contracts I can accept or cancel',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Switch(
            value: actionableOnly,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final TradeOffer offer;
  final String currentPlayerId;
  final Set<String> managedCompanyIds;
  final bool isAccepting;
  final bool isCanceling;
  final Future<void> Function() onAccept;
  final Future<void> Function() onCancel;

  const _ContractCard({
    required this.offer,
    required this.currentPlayerId,
    required this.managedCompanyIds,
    required this.isAccepting,
    required this.isCanceling,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canAccept =
        _canAcceptOffer(offer, currentPlayerId, managedCompanyIds);
    final canCancel =
        _canCancelOffer(offer, currentPlayerId, managedCompanyIds);
    final statusColor = _statusColor(offer.status);
    return GamePanel(
      borderColor: statusColor.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.assignment, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${offer.quantity} ${offer.itemName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${offer.sellerType}:${offer.sellerId} -> ${offer.buyerType}:${offer.buyerId}',
                      style: const TextStyle(color: GameColors.textMuted),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: offer.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GameStatPill(
                stat: GameStat(
                  label: 'gold each',
                  value: Utils.number(offer.pricePerUnit),
                  icon: Icons.monetization_on,
                  color: GameColors.amber,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'total',
                  value: '${Utils.number(offer.totalPrice)}g',
                  icon: Icons.receipt_long,
                  color: GameColors.emerald,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'quality',
                  value: 'Q${offer.qualityTier}',
                  icon: Icons.workspace_premium,
                  color: GameColors.violet,
                ),
              ),
              GameStatPill(
                stat: GameStat(
                  label: 'created',
                  value: DateFormat.MMMd().format(offer.createdAt.toLocal()),
                  icon: Icons.schedule,
                  color: GameColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: canAccept && !isAccepting ? onAccept : null,
                icon: isAccepting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(isAccepting ? 'Accepting...' : 'Accept'),
              ),
              OutlinedButton.icon(
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
            ],
          ),
        ],
      ),
    );
  }
}

class _ContractNotice extends StatelessWidget {
  final TradeOfferResult result;

  const _ContractNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    final detail = result.contract != null
        ? 'Contract ${result.contract!.status} for ${Utils.number(result.totalPrice)} gold.'
        : result.offer != null
            ? '${result.offer!.quantity} ${result.offer!.itemName} reserved at ${Utils.number(result.offer!.pricePerUnit)} gold each.'
            : '${Utils.number(result.totalPrice)} gold total.';
    return GameNotice(
      icon: result.completed ? Icons.verified : Icons.handshake,
      message: '${result.message} $detail',
      color: result.completed ? GameColors.emerald : GameColors.amber,
    );
  }
}

class _FieldWrap extends StatelessWidget {
  final List<Widget> children;

  const _FieldWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 650;
        if (!wide) {
          return Column(
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

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
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
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

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
  );
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return GameColors.emerald;
    case 'completed':
    case 'fulfilled':
      return GameColors.cyan;
    case 'cancelled':
    case 'canceled':
      return GameColors.crimson;
    default:
      return GameColors.amber;
  }
}

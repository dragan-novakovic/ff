import 'package:flutter/foundation.dart';

import '../models/GameAreas.dart';
import '../models/RealtimeUpdates.dart';
import '../services/backend_api.dart';

class InventoryBloc extends ChangeNotifier {
  InventoryBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  InventorySummary? inventory;
  LedgerSummary? ledger;
  EquipmentSummary? equipment;
  InventoryItemUseResult? lastUse;
  EquipWeaponResult? lastEquip;
  RepairWeaponResult? lastRepair;
  String? error;
  bool isLoading = false;
  bool isLedgerLoading = false;
  bool isEquipmentLoading = false;
  bool isRepairingWeapon = false;
  final Set<String> usingItemIds = {};
  final Set<String> equippingItemIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    inventory = null;
    ledger = null;
    equipment = null;
    lastUse = null;
    lastEquip = null;
    lastRepair = null;
    error = null;
    isLoading = false;
    isLedgerLoading = false;
    isEquipmentLoading = false;
    isRepairingWeapon = false;
    usingItemIds.clear();
    equippingItemIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      inventory = await _apiClient.fetchInventory(playerId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load inventory.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLedger(String playerId, {int limit = 25}) async {
    isLedgerLoading = true;
    error = null;
    notifyListeners();

    try {
      ledger = await _apiClient.fetchLedger(playerId, limit: limit);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load transaction history.';
    } finally {
      isLedgerLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEquipment(String playerId) async {
    isEquipmentLoading = true;
    error = null;
    notifyListeners();

    try {
      equipment = await _apiClient.fetchEquipment(playerId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load equipment.';
    } finally {
      isEquipmentLoading = false;
      notifyListeners();
    }
  }

  Future<InventoryItemUseResult?> useItem({
    required String playerId,
    required String itemId,
    required String idempotencyKey,
  }) async {
    if (usingItemIds.contains(itemId)) {
      return null;
    }

    usingItemIds.add(itemId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.useInventoryItem(
        playerId: playerId,
        itemId: itemId,
        idempotencyKey: idempotencyKey,
      );
      inventory = result.inventory;
      lastUse = result;
      try {
        ledger = await _apiClient.fetchLedger(playerId, limit: 25);
      } on BackendApiException catch (e) {
        error = e.message;
      } on Exception {
        error = 'Could not refresh transaction history.';
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not use inventory item.';
      return null;
    } finally {
      usingItemIds.remove(itemId);
      notifyListeners();
    }
  }

  Future<EquipWeaponResult?> equipWeapon({
    required String playerId,
    required String itemId,
    required String idempotencyKey,
  }) async {
    if (equippingItemIds.contains(itemId)) {
      return null;
    }

    equippingItemIds.add(itemId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.equipWeapon(
        playerId: playerId,
        itemId: itemId,
        idempotencyKey: idempotencyKey,
      );
      inventory = result.inventory;
      equipment = result.equipment;
      lastEquip = result;
      try {
        ledger = await _apiClient.fetchLedger(playerId, limit: 25);
      } on BackendApiException catch (e) {
        error = e.message;
      } on Exception {
        error = 'Could not refresh transaction history.';
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not equip weapon.';
      return null;
    } finally {
      equippingItemIds.remove(itemId);
      notifyListeners();
    }
  }

  Future<RepairWeaponResult?> repairWeapon({
    required String playerId,
    required String idempotencyKey,
  }) async {
    if (isRepairingWeapon) {
      return null;
    }

    isRepairingWeapon = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.repairWeapon(
        playerId: playerId,
        idempotencyKey: idempotencyKey,
      );
      inventory = result.inventory;
      equipment = result.equipment;
      lastRepair = result;
      try {
        ledger = await _apiClient.fetchLedger(playerId, limit: 25);
      } on BackendApiException catch (e) {
        error = e.message;
      } on Exception {
        error = 'Could not refresh transaction history.';
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not repair weapon.';
      return null;
    } finally {
      isRepairingWeapon = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class FactoriesBloc extends ChangeNotifier {
  FactoriesBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  FactoryPortfolio? portfolio;
  ProductionJobsResponse? productionJobs;
  ProductionResult? lastProduction;
  ProductionClaimResult? lastClaim;
  FactoryUpgradeGatewayResult? lastUpgrade;
  String? error;
  bool isLoading = false;
  final Set<String> producingFactoryIds = {};
  final Set<String> claimingJobIds = {};
  final Set<String> upgradingFactoryIds = {};
  final Map<String, FactoryUpgradeQuote> upgradeQuotes = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      portfolio = await _apiClient.fetchFactories(playerId);
      productionJobs = await _apiClient.fetchProductionJobs(playerId);
      upgradeQuotes
        ..clear()
        ..addEntries(await Future.wait(
          portfolio!.factories.map((factory) async {
            final quote = await _apiClient.fetchFactoryUpgradeQuote(
              playerId: playerId,
              factoryId: factory.factoryId,
            );
            return MapEntry(factory.factoryId, quote);
          }),
        ));
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load factories.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void applyRealtimeProduction(RealtimeProductionUpdate update) {
    productionJobs = update.jobs;
    error = null;
    notifyListeners();
  }

  Future<ProductionResult?> produce(String playerId, String factoryId) async {
    if (producingFactoryIds.contains(factoryId)) {
      return null;
    }

    producingFactoryIds.add(factoryId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.produce(playerId, factoryId);
      lastProduction = result;
      final job = result.job;
      final currentJobs = productionJobs;
      if (job != null && currentJobs != null) {
        productionJobs = ProductionJobsResponse(
          playerId: currentJobs.playerId,
          jobs: [
            job,
            ...currentJobs.jobs
                .where((existing) => existing.jobId != job.jobId),
          ],
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not run production.';
      return null;
    } finally {
      producingFactoryIds.remove(factoryId);
      notifyListeners();
    }
  }

  Future<ProductionClaimResult?> claim(String playerId, String jobId) async {
    if (claimingJobIds.contains(jobId)) {
      return null;
    }

    claimingJobIds.add(jobId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.claimProductionJob(
        playerId: playerId,
        jobId: jobId,
      );
      lastClaim = result;
      final currentJobs = productionJobs;
      if (currentJobs != null) {
        productionJobs = ProductionJobsResponse(
          playerId: currentJobs.playerId,
          jobs: currentJobs.jobs
              .map((job) => job.jobId == jobId ? result.claim.job : job)
              .toList(),
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not claim production job.';
      return null;
    } finally {
      claimingJobIds.remove(jobId);
      notifyListeners();
    }
  }

  Future<FactoryUpgradeGatewayResult?> upgrade(
    String playerId,
    String factoryId,
  ) async {
    if (upgradingFactoryIds.contains(factoryId)) {
      return null;
    }

    upgradingFactoryIds.add(factoryId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.upgradeFactory(
        playerId: playerId,
        factoryId: factoryId,
      );
      lastUpgrade = result;
      final currentPortfolio = portfolio;
      if (currentPortfolio != null) {
        portfolio = FactoryPortfolio(
          playerId: currentPortfolio.playerId,
          factories: currentPortfolio.factories
              .map((factory) => factory.factoryId == factoryId
                  ? result.upgrade.factory
                  : factory)
              .toList(),
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not upgrade factory.';
      return null;
    } finally {
      upgradingFactoryIds.remove(factoryId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class ResearchBloc extends ChangeNotifier {
  ResearchBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  ResearchDashboard? dashboard;
  ResearchScopeState? selectedCompanyResearch;
  ResearchMutationResult? lastMutation;
  String? error;
  bool isLoading = false;
  bool isLoadingCompany = false;
  final Set<String> operationKeys = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    dashboard = null;
    selectedCompanyResearch = null;
    lastMutation = null;
    error = null;
    isLoading = false;
    isLoadingCompany = false;
    operationKeys.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      dashboard = await _apiClient.fetchResearchDashboard(playerId);
      final selectedCompanyId = selectedCompanyResearch?.scopeId;
      if (selectedCompanyId != null &&
          dashboard!.companies
              .any((company) => company.companyId == selectedCompanyId)) {
        selectedCompanyResearch =
            await _apiClient.fetchCompanyResearch(selectedCompanyId);
      } else {
        selectedCompanyResearch = null;
      }
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load research.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompany(String companyId) async {
    isLoadingCompany = true;
    error = null;
    notifyListeners();

    try {
      selectedCompanyResearch =
          await _apiClient.fetchCompanyResearch(companyId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load company research.';
    } finally {
      isLoadingCompany = false;
      notifyListeners();
    }
  }

  Future<ResearchMutationResult?> start({
    required String scopeType,
    required String scopeId,
    required String technologyId,
    required String idempotencyKey,
  }) async {
    final operationKey = '$scopeType:$scopeId:start:$technologyId';
    if (operationKeys.contains(operationKey)) {
      return null;
    }

    operationKeys.add(operationKey);
    error = null;
    notifyListeners();

    try {
      final result = scopeType == 'company'
          ? await _apiClient.startCompanyResearch(
              companyId: scopeId,
              technologyId: technologyId,
              idempotencyKey: idempotencyKey,
            )
          : await _apiClient.startCountryResearch(
              countryId: scopeId,
              technologyId: technologyId,
              idempotencyKey: idempotencyKey,
            );
      _applyMutation(result);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not start research.';
      return null;
    } finally {
      operationKeys.remove(operationKey);
      notifyListeners();
    }
  }

  Future<ResearchMutationResult?> contribute({
    required String scopeType,
    required String scopeId,
    required String projectId,
    required int points,
    required String idempotencyKey,
  }) async {
    final operationKey = '$scopeType:$scopeId:contribute:$projectId';
    if (operationKeys.contains(operationKey)) {
      return null;
    }

    operationKeys.add(operationKey);
    error = null;
    notifyListeners();

    try {
      final result = scopeType == 'company'
          ? await _apiClient.contributeCompanyResearch(
              companyId: scopeId,
              projectId: projectId,
              points: points,
              idempotencyKey: idempotencyKey,
            )
          : await _apiClient.contributeCountryResearch(
              countryId: scopeId,
              projectId: projectId,
              points: points,
              idempotencyKey: idempotencyKey,
            );
      _applyMutation(result);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not contribute research points.';
      return null;
    } finally {
      operationKeys.remove(operationKey);
      notifyListeners();
    }
  }

  Future<ResearchMutationResult?> complete({
    required String scopeType,
    required String scopeId,
    required String projectId,
    required String idempotencyKey,
  }) async {
    final operationKey = '$scopeType:$scopeId:complete:$projectId';
    if (operationKeys.contains(operationKey)) {
      return null;
    }

    operationKeys.add(operationKey);
    error = null;
    notifyListeners();

    try {
      final result = scopeType == 'company'
          ? await _apiClient.completeCompanyResearch(
              companyId: scopeId,
              projectId: projectId,
              idempotencyKey: idempotencyKey,
            )
          : await _apiClient.completeCountryResearch(
              countryId: scopeId,
              projectId: projectId,
              idempotencyKey: idempotencyKey,
            );
      _applyMutation(result);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not complete research.';
      return null;
    } finally {
      operationKeys.remove(operationKey);
      notifyListeners();
    }
  }

  void _applyMutation(ResearchMutationResult result) {
    lastMutation = result;
    final state = result.state;
    if (state == null) {
      return;
    }

    if (state.scopeType == 'company') {
      selectedCompanyResearch = state;
      return;
    }

    final currentDashboard = dashboard;
    if (currentDashboard != null) {
      dashboard = ResearchDashboard(
        playerId: currentDashboard.playerId,
        citizenship: currentDashboard.citizenship,
        country: state,
        companies: currentDashboard.companies,
        updatedAt: result.updatedAt,
      );
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class MarketBloc extends ChangeNotifier {
  MarketBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  MarketListings? market;
  PlayerMarketListings? playerListings;
  MarketPurchaseResult? lastPurchase;
  MarketSellListingResult? lastSale;
  MarketCancelListingResult? lastCancellation;
  MarketPriceHistory? priceHistory;
  MarketOrderBook? orderBook;
  TradeOfferList? tradeOffers;
  CompanyPortfolio? companyPortfolio;
  TradeOfferResult? lastTradeOffer;
  String? error;
  bool isLoading = false;
  bool isPlayerListingsLoading = false;
  bool isAdvancedLoading = false;
  bool isSelling = false;
  bool isCreatingTradeOffer = false;
  final Set<String> buyingListingIds = {};
  final Set<String> cancelingListingIds = {};
  final Set<String> acceptingTradeOfferIds = {};
  final Set<String> cancelingTradeOfferIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      market = await _apiClient.fetchMarketListings();
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load market listings.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void applyRealtimeMarket(RealtimeMarketUpdate update) {
    market = update.listings;
    if (update.playerListings != null) {
      playerListings = update.playerListings;
    }
    error = null;
    notifyListeners();
  }

  Future<void> loadPlayerListings(String playerId) async {
    isPlayerListingsLoading = true;
    error = null;
    notifyListeners();

    try {
      playerListings = await _apiClient.fetchPlayerMarketListings(playerId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load your market listings.';
    } finally {
      isPlayerListingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdvanced(String playerId) async {
    isAdvancedLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchMarketPriceHistory(limit: 25),
        _apiClient.fetchMarketOrderBook(),
        _apiClient.fetchTradeOffers(status: 'open'),
        _apiClient.fetchCompanies(playerId),
      ]);
      priceHistory = results[0] as MarketPriceHistory;
      orderBook = results[1] as MarketOrderBook;
      tradeOffers = results[2] as TradeOfferList;
      companyPortfolio = results[3] as CompanyPortfolio;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load advanced market data.';
    } finally {
      isAdvancedLoading = false;
      notifyListeners();
    }
  }

  Future<MarketPurchaseResult?> buy(
      String playerId, String listingId, String idempotencyKey) async {
    if (buyingListingIds.contains(listingId)) {
      return null;
    }

    buyingListingIds.add(listingId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.buyMarketListing(
        playerId: playerId,
        listingId: listingId,
        idempotencyKey: idempotencyKey,
      );
      lastPurchase = result;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not buy market listing.';
      return null;
    } finally {
      buyingListingIds.remove(listingId);
      notifyListeners();
    }
  }

  Future<MarketSellListingResult?> sell({
    required String playerId,
    required String itemId,
    required int quantity,
    required int pricePerUnit,
    required String idempotencyKey,
  }) async {
    if (isSelling) {
      return null;
    }

    isSelling = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.sellMarketListing(
        playerId: playerId,
        itemId: itemId,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        idempotencyKey: idempotencyKey,
      );
      lastSale = result;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create market listing.';
      return null;
    } finally {
      isSelling = false;
      notifyListeners();
    }
  }

  Future<MarketCancelListingResult?> cancel({
    required String playerId,
    required String listingId,
    required String idempotencyKey,
  }) async {
    if (cancelingListingIds.contains(listingId)) {
      return null;
    }

    cancelingListingIds.add(listingId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.cancelMarketListing(
        playerId: playerId,
        listingId: listingId,
        idempotencyKey: idempotencyKey,
      );
      lastCancellation = result;
      final currentListings = playerListings;
      if (currentListings != null) {
        playerListings = PlayerMarketListings(
          sellerId: currentListings.sellerId,
          listings: currentListings.listings
              .map((listing) =>
                  listing.listingId == listingId ? result.listing : listing)
              .toList(),
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not cancel market listing.';
      return null;
    } finally {
      cancelingListingIds.remove(listingId);
      notifyListeners();
    }
  }

  Future<TradeOfferResult?> createTradeOffer({
    required String playerId,
    required String sellerType,
    required String sellerId,
    required String buyerType,
    required String buyerId,
    required String itemId,
    required int quantity,
    required int pricePerUnit,
    required String idempotencyKey,
  }) async {
    if (isCreatingTradeOffer) {
      return null;
    }

    isCreatingTradeOffer = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createTradeOffer(
        playerId: playerId,
        sellerType: sellerType,
        sellerId: sellerId,
        buyerType: buyerType,
        buyerId: buyerId,
        itemId: itemId,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        idempotencyKey: idempotencyKey,
      );
      lastTradeOffer = result;
      tradeOffers = await _apiClient.fetchTradeOffers(status: 'open');
      priceHistory = await _apiClient.fetchMarketPriceHistory(limit: 25);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create trade offer.';
      return null;
    } finally {
      isCreatingTradeOffer = false;
      notifyListeners();
    }
  }

  Future<TradeOfferResult?> acceptTradeOffer({
    required String playerId,
    required String offerId,
    required String idempotencyKey,
  }) async {
    if (acceptingTradeOfferIds.contains(offerId)) {
      return null;
    }

    acceptingTradeOfferIds.add(offerId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.acceptTradeOffer(
        playerId: playerId,
        offerId: offerId,
        idempotencyKey: idempotencyKey,
      );
      lastTradeOffer = result;
      tradeOffers = await _apiClient.fetchTradeOffers(status: 'open');
      priceHistory = await _apiClient.fetchMarketPriceHistory(limit: 25);
      orderBook = await _apiClient.fetchMarketOrderBook();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not accept trade offer.';
      return null;
    } finally {
      acceptingTradeOfferIds.remove(offerId);
      notifyListeners();
    }
  }

  Future<TradeOfferResult?> cancelTradeOffer({
    required String playerId,
    required String offerId,
    required String idempotencyKey,
  }) async {
    if (cancelingTradeOfferIds.contains(offerId)) {
      return null;
    }

    cancelingTradeOfferIds.add(offerId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.cancelTradeOffer(
        playerId: playerId,
        offerId: offerId,
        idempotencyKey: idempotencyKey,
      );
      lastTradeOffer = result;
      tradeOffers = await _apiClient.fetchTradeOffers(status: 'open');
      orderBook = await _apiClient.fetchMarketOrderBook();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not cancel trade offer.';
      return null;
    } finally {
      cancelingTradeOfferIds.remove(offerId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class MissionsBloc extends ChangeNotifier {
  MissionsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  List<CombatMission> missions = [];
  EquipmentSummary? equipment;
  MissionProgressSummary? progress;
  MissionFightResult? lastFight;
  RepairWeaponResult? lastRepair;
  String? error;
  bool isLoading = false;
  bool isRepairingWeapon = false;
  final Set<String> fightingMissionIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchCombatMissions(),
        _apiClient.fetchEquipment(playerId),
        _apiClient.fetchMissionProgress(playerId),
      ]);
      missions = results[0] as List<CombatMission>;
      equipment = results[1] as EquipmentSummary;
      progress = results[2] as MissionProgressSummary;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load missions.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<MissionFightResult?> fight({
    required String playerId,
    required String missionId,
    required String idempotencyKey,
  }) async {
    if (fightingMissionIds.contains(missionId)) {
      return null;
    }

    fightingMissionIds.add(missionId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.fightMission(
        playerId,
        missionId,
        idempotencyKey,
      );
      lastFight = result;
      equipment = result.equipment;
      if (result.missionProgress != null) {
        final currentProgress = progress;
        if (currentProgress == null) {
          progress = MissionProgressSummary(
            playerId: playerId,
            missions: [result.missionProgress!],
            updatedAt: DateTime.now().toUtc(),
          );
        } else {
          final replaced = currentProgress.missions
              .map((mission) => mission.missionId == missionId
                  ? result.missionProgress!
                  : mission)
              .toList();
          if (!replaced.any((mission) =>
              mission.missionId == result.missionProgress!.missionId)) {
            replaced.add(result.missionProgress!);
          }
          progress = MissionProgressSummary(
            playerId: currentProgress.playerId,
            missions: replaced,
            updatedAt: DateTime.now().toUtc(),
          );
        }
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not simulate mission fight.';
      return null;
    } finally {
      fightingMissionIds.remove(missionId);
      notifyListeners();
    }
  }

  Future<RepairWeaponResult?> repairWeapon({
    required String playerId,
    required String idempotencyKey,
  }) async {
    if (isRepairingWeapon) {
      return null;
    }

    isRepairingWeapon = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.repairWeapon(
        playerId: playerId,
        idempotencyKey: idempotencyKey,
      );
      equipment = result.equipment;
      lastRepair = result;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not repair weapon.';
      return null;
    } finally {
      isRepairingWeapon = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class WorldBloc extends ChangeNotifier {
  WorldBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  CountryCatalog? catalog;
  RegionList? regions;
  CountryTreasury? treasury;
  CountryInfrastructure? infrastructure;
  CountryInfrastructureContributionResult? lastInfrastructureContribution;
  PlayerCitizenshipStatus? citizenshipStatus;
  CitizenshipMutationResult? lastMutation;
  String? error;
  bool isLoading = false;
  bool isUpdatingPolicy = false;
  bool isContributingInfrastructure = false;
  final Set<String> updatingCountryIds = {};

  PlayerCitizenship? get citizenship => citizenshipStatus?.citizenship;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    catalog = null;
    regions = null;
    treasury = null;
    infrastructure = null;
    lastInfrastructureContribution = null;
    citizenshipStatus = null;
    lastMutation = null;
    error = null;
    isLoading = false;
    isUpdatingPolicy = false;
    isContributingInfrastructure = false;
    updatingCountryIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchCountries(),
        _apiClient.fetchRegions(),
        _apiClient.fetchPlayerCitizenship(playerId),
      ]);
      catalog = results[0] as CountryCatalog;
      regions = results[1] as RegionList;
      citizenshipStatus = results[2] as PlayerCitizenshipStatus;
      final currentCitizenship = citizenshipStatus?.citizenship;
      treasury = currentCitizenship == null
          ? null
          : await _apiClient.fetchCountryTreasury(currentCitizenship.countryId);
      infrastructure = currentCitizenship == null
          ? null
          : await _apiClient
              .fetchCountryInfrastructure(currentCitizenship.countryId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load world countries.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<CitizenshipMutationResult?> join({
    required String playerId,
    required String countryId,
  }) async {
    return _mutateCitizenship(
      playerId: playerId,
      countryId: countryId,
      action: () => _apiClient.joinCountry(
        playerId: playerId,
        countryId: countryId,
      ),
    );
  }

  Future<CitizenshipMutationResult?> change({
    required String playerId,
    required String countryId,
  }) async {
    return _mutateCitizenship(
      playerId: playerId,
      countryId: countryId,
      action: () => _apiClient.changeCountry(
        playerId: playerId,
        countryId: countryId,
      ),
    );
  }

  Future<CitizenshipMutationResult?> _mutateCitizenship({
    required String playerId,
    required String countryId,
    required Future<CitizenshipMutationResult> Function() action,
  }) async {
    if (updatingCountryIds.contains(countryId)) {
      return null;
    }

    updatingCountryIds.add(countryId);
    error = null;
    notifyListeners();

    try {
      final result = await action();
      lastMutation = result;
      citizenshipStatus = PlayerCitizenshipStatus(
        playerId: playerId,
        citizenship: result.citizenship,
        updatedAt: result.updatedAt,
      );
      treasury = result.citizenship == null
          ? null
          : await _apiClient
              .fetchCountryTreasury(result.citizenship!.countryId);
      infrastructure = result.citizenship == null
          ? null
          : await _apiClient
              .fetchCountryInfrastructure(result.citizenship!.countryId);
      catalog = await _apiClient.fetchCountries();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update citizenship.';
      return null;
    } finally {
      updatingCountryIds.remove(countryId);
      notifyListeners();
    }
  }

  Future<CountryTaxPolicyUpdateResult?> updateTaxPolicy({
    required String countryId,
    required int incomeTaxRate,
    required int marketTaxRate,
    required int productionTaxRate,
  }) async {
    if (isUpdatingPolicy) {
      return null;
    }

    isUpdatingPolicy = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.updateCountryTaxPolicy(
        countryId: countryId,
        incomeTaxRate: incomeTaxRate,
        marketTaxRate: marketTaxRate,
        productionTaxRate: productionTaxRate,
      );
      treasury =
          result.treasury ?? await _apiClient.fetchCountryTreasury(countryId);
      catalog = await _apiClient.fetchCountries();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update country tax policy.';
      return null;
    } finally {
      isUpdatingPolicy = false;
      notifyListeners();
    }
  }

  Future<void> loadInfrastructure(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      citizenshipStatus = await _apiClient.fetchPlayerCitizenship(playerId);
      final currentCitizenship = citizenshipStatus?.citizenship;
      infrastructure = currentCitizenship == null
          ? null
          : await _apiClient
              .fetchCountryInfrastructure(currentCitizenship.countryId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load infrastructure projects.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<CountryInfrastructureContributionResult?> contributeInfrastructure({
    required String playerId,
    required String countryId,
    required String projectId,
    required int goldAmount,
    required int itemQuantity,
    String? itemId,
  }) async {
    if (isContributingInfrastructure) {
      return null;
    }

    isContributingInfrastructure = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.contributeCountryInfrastructure(
        playerId: playerId,
        countryId: countryId,
        projectId: projectId,
        goldAmount: goldAmount,
        itemQuantity: itemQuantity,
        itemId: itemId,
        idempotencyKey:
            'infrastructure-$playerId-$projectId-${DateTime.now().microsecondsSinceEpoch}',
      );
      lastInfrastructureContribution = result;
      infrastructure = result.infrastructure ??
          await _apiClient.fetchCountryInfrastructure(countryId);
      catalog = await _apiClient.fetchCountries();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not contribute to infrastructure.';
      return null;
    } finally {
      isContributingInfrastructure = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class TerritoryBloc extends ChangeNotifier {
  TerritoryBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  TerritoryMap? map;
  TerritoryBattleMutationResult? lastMutation;
  String? error;
  bool isLoading = false;
  final Set<String> startingRegionIds = {};
  final Set<String> resolvingBattleIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    map = null;
    lastMutation = null;
    error = null;
    isLoading = false;
    startingRegionIds.clear();
    resolvingBattleIds.clear();
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      map = await _apiClient.fetchTerritoryMap();
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load territory map.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<TerritoryBattleMutationResult?> startBattle({
    required String playerId,
    required String regionId,
    required String battleType,
  }) async {
    if (startingRegionIds.contains(regionId)) {
      return null;
    }

    startingRegionIds.add(regionId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.startTerritoryBattle(
        playerId: playerId,
        regionId: regionId,
        battleType: battleType,
      );
      lastMutation = result;
      await load();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not start territory battle.';
      return null;
    } finally {
      startingRegionIds.remove(regionId);
      notifyListeners();
    }
  }

  Future<TerritoryBattleMutationResult?> resolveBattle({
    required String playerId,
    required String battleId,
  }) async {
    if (resolvingBattleIds.contains(battleId)) {
      return null;
    }

    resolvingBattleIds.add(battleId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.resolveTerritoryBattle(
        playerId: playerId,
        battleId: battleId,
      );
      lastMutation = result;
      await load();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not resolve territory battle.';
      return null;
    } finally {
      resolvingBattleIds.remove(battleId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class PoliticsBloc extends ChangeNotifier {
  PoliticsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  PoliticalPartyList? parties;
  PlayerPoliticsStatus? status;
  ElectionList? elections;
  ElectionDetails? selectedElection;
  ElectionResults? selectedResults;
  OfficeHolderList? officeHolders;
  PoliticalPartyMutationResult? lastPartyMutation;
  CandidacyMutationResult? lastCandidacy;
  VoteMutationResult? lastVote;
  String? error;
  bool isLoading = false;
  bool isLoadingElection = false;
  final Set<String> updatingPartyIds = {};
  final Set<String> declaringElectionIds = {};
  final Set<String> votingCandidacyIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    parties = null;
    status = null;
    elections = null;
    selectedElection = null;
    selectedResults = null;
    officeHolders = null;
    lastPartyMutation = null;
    lastCandidacy = null;
    lastVote = null;
    error = null;
    isLoading = false;
    isLoadingElection = false;
    updatingPartyIds.clear();
    declaringElectionIds.clear();
    votingCandidacyIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchPoliticalParties(),
        _apiClient.fetchPlayerPoliticsStatus(playerId),
        _apiClient.fetchElections(),
        _apiClient.fetchOfficeHolders(),
      ]);
      parties = results[0] as PoliticalPartyList;
      status = results[1] as PlayerPoliticsStatus;
      elections = results[2] as ElectionList;
      officeHolders = results[3] as OfficeHolderList;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load politics.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PoliticalPartyMutationResult?> createParty({
    required String playerId,
    required String countryId,
    required String name,
    required String shortName,
    required String description,
    required String ideology,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createPoliticalParty(
        playerId: playerId,
        countryId: countryId,
        name: name,
        shortName: shortName,
        description: description,
        ideology: ideology,
      );
      lastPartyMutation = result;
      await _refreshPolitics(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create party.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PoliticalPartyMutationResult?> joinParty({
    required String playerId,
    required String partyId,
  }) async {
    return _mutateParty(
      playerId: playerId,
      partyId: partyId,
      action: () => _apiClient.joinPoliticalParty(
        playerId: playerId,
        partyId: partyId,
      ),
    );
  }

  Future<PoliticalPartyMutationResult?> leaveParty({
    required String playerId,
    required String partyId,
  }) async {
    return _mutateParty(
      playerId: playerId,
      partyId: partyId,
      action: () => _apiClient.leavePoliticalParty(
        playerId: playerId,
        partyId: partyId,
      ),
    );
  }

  Future<PoliticalPartyMutationResult?> _mutateParty({
    required String playerId,
    required String partyId,
    required Future<PoliticalPartyMutationResult> Function() action,
  }) async {
    if (updatingPartyIds.contains(partyId)) {
      return null;
    }

    updatingPartyIds.add(partyId);
    error = null;
    notifyListeners();

    try {
      final result = await action();
      lastPartyMutation = result;
      await _refreshPolitics(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update party membership.';
      return null;
    } finally {
      updatingPartyIds.remove(partyId);
      notifyListeners();
    }
  }

  Future<void> loadElection(String electionId) async {
    isLoadingElection = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchElectionDetails(electionId),
        _apiClient.fetchElectionResults(electionId),
      ]);
      selectedElection = results[0] as ElectionDetails;
      selectedResults = results[1] as ElectionResults;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load election details.';
    } finally {
      isLoadingElection = false;
      notifyListeners();
    }
  }

  Future<CandidacyMutationResult?> declareCandidacy({
    required String playerId,
    required String electionId,
    String? partyId,
    required String manifesto,
  }) async {
    if (declaringElectionIds.contains(electionId)) {
      return null;
    }

    declaringElectionIds.add(electionId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.declareCandidacy(
        playerId: playerId,
        electionId: electionId,
        partyId: partyId,
        manifesto: manifesto,
      );
      lastCandidacy = result;
      await _refreshPolitics(playerId);
      await loadElection(electionId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not declare candidacy.';
      return null;
    } finally {
      declaringElectionIds.remove(electionId);
      notifyListeners();
    }
  }

  Future<VoteMutationResult?> vote({
    required String playerId,
    required String electionId,
    required String candidacyId,
  }) async {
    if (votingCandidacyIds.contains(candidacyId)) {
      return null;
    }

    votingCandidacyIds.add(candidacyId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.voteInElection(
        playerId: playerId,
        electionId: electionId,
        candidacyId: candidacyId,
      );
      lastVote = result;
      await _refreshPolitics(playerId);
      await loadElection(electionId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not cast vote.';
      return null;
    } finally {
      votingCandidacyIds.remove(candidacyId);
      notifyListeners();
    }
  }

  Future<void> _refreshPolitics(String playerId) async {
    parties = await _apiClient.fetchPoliticalParties();
    status = await _apiClient.fetchPlayerPoliticsStatus(playerId);
    elections = await _apiClient.fetchElections();
    officeHolders = await _apiClient.fetchOfficeHolders();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class CongressBloc extends ChangeNotifier {
  CongressBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  PlayerPoliticsStatus? politicsStatus;
  LawProposalList? proposals;
  LawProposalDetails? selectedProposal;
  LawList? activeLaws;
  LawProposalMutationResult? lastProposalMutation;
  LawVoteMutationResult? lastVote;
  String? error;
  bool isLoading = false;
  bool isLoadingProposal = false;
  bool isMutating = false;
  final Set<String> votingProposalIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    politicsStatus = null;
    proposals = null;
    selectedProposal = null;
    activeLaws = null;
    lastProposalMutation = null;
    lastVote = null;
    error = null;
    isLoading = false;
    isLoadingProposal = false;
    isMutating = false;
    votingProposalIds.clear();
    notifyListeners();
  }

  String? get countryId => politicsStatus?.citizenship?.countryId;

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      politicsStatus = await _apiClient.fetchPlayerPoliticsStatus(playerId);
      final country = countryId;
      final results = await Future.wait([
        _apiClient.fetchLawProposals(countryId: country, status: null),
        _apiClient.fetchLaws(countryId: country),
      ]);
      proposals = results[0] as LawProposalList;
      activeLaws = results[1] as LawList;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load congress.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProposal(String proposalId) async {
    isLoadingProposal = true;
    error = null;
    notifyListeners();

    try {
      selectedProposal = await _apiClient.fetchLawProposalDetails(proposalId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load law proposal.';
    } finally {
      isLoadingProposal = false;
      notifyListeners();
    }
  }

  Future<LawProposalMutationResult?> createProposal({
    required String playerId,
    required String countryId,
    required String proposalType,
    required String title,
    required String description,
    int? incomeTaxRate,
    int? marketTaxRate,
    int? productionTaxRate,
    int? treasuryAmount,
    String? treasuryTargetPlayerId,
    String? treasuryReason,
    String? citizenshipRule,
    int? votingHours,
  }) async {
    isMutating = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createLawProposal(
        playerId: playerId,
        countryId: countryId,
        proposalType: proposalType,
        title: title,
        description: description,
        incomeTaxRate: incomeTaxRate,
        marketTaxRate: marketTaxRate,
        productionTaxRate: productionTaxRate,
        treasuryAmount: treasuryAmount,
        treasuryTargetPlayerId: treasuryTargetPlayerId,
        treasuryReason: treasuryReason,
        citizenshipRule: citizenshipRule,
        votingHours: votingHours,
      );
      lastProposalMutation = result;
      await load(playerId);
      if (result.proposal != null) {
        await loadProposal(result.proposal!.proposalId);
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create law proposal.';
      return null;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<LawVoteMutationResult?> vote({
    required String playerId,
    required String proposalId,
    required String choice,
  }) async {
    if (votingProposalIds.contains(proposalId)) {
      return null;
    }

    votingProposalIds.add(proposalId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.voteOnLawProposal(
        playerId: playerId,
        proposalId: proposalId,
        choice: choice,
      );
      lastVote = result;
      await load(playerId);
      await loadProposal(proposalId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not cast congress vote.';
      return null;
    } finally {
      votingProposalIds.remove(proposalId);
      notifyListeners();
    }
  }

  Future<LawProposalMutationResult?> resolve({
    required String playerId,
    required String proposalId,
  }) async {
    isMutating = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.resolveLawProposal(
        playerId: playerId,
        proposalId: proposalId,
      );
      lastProposalMutation = result;
      await load(playerId);
      await loadProposal(proposalId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not resolve law proposal.';
      return null;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class DiplomacyBloc extends ChangeNotifier {
  DiplomacyBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  DiplomacyStatus? status;
  DiplomaticTreatyList? treaties;
  DiplomacyMutationResult? lastMutation;
  String? error;
  bool isLoading = false;
  bool isMutating = false;
  final Set<String> mutatingTreatyIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    status = null;
    treaties = null;
    lastMutation = null;
    error = null;
    isLoading = false;
    isMutating = false;
    mutatingTreatyIds.clear();
    notifyListeners();
  }

  String? get countryId => status?.countryId;

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      status = await _apiClient.fetchDiplomacyStatus(playerId);
      final country = countryId;
      treaties = await _apiClient.fetchDiplomacyTreaties(
        countryId: country,
        status: null,
      );
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load diplomacy.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<DiplomacyMutationResult?> proposeTreaty({
    required String playerId,
    required String initiatorCountryId,
    required String targetCountryId,
    required String treatyType,
    required String title,
    required String terms,
    required int durationDays,
    int? treasuryAmount,
    String? sourceLawId,
  }) async {
    isMutating = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.proposeTreaty(
        playerId: playerId,
        initiatorCountryId: initiatorCountryId,
        targetCountryId: targetCountryId,
        treatyType: treatyType,
        title: title,
        terms: terms,
        durationDays: durationDays,
        treasuryAmount: treasuryAmount,
        sourceLawId: sourceLawId,
        idempotencyKey:
            'diplomacy-proposal:$playerId:${DateTime.now().millisecondsSinceEpoch}',
      );
      lastMutation = result;
      await load(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not propose treaty.';
      return null;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<DiplomacyMutationResult?> ratifyTreaty({
    required String playerId,
    required String treatyId,
  }) async {
    return _mutateTreaty(
      playerId: playerId,
      treatyId: treatyId,
      action: () => _apiClient.ratifyTreaty(
        playerId: playerId,
        treatyId: treatyId,
        idempotencyKey:
            'diplomacy-ratify:$playerId:$treatyId:${DateTime.now().millisecondsSinceEpoch}',
      ),
      fallbackError: 'Could not ratify treaty.',
    );
  }

  Future<DiplomacyMutationResult?> rejectTreaty({
    required String playerId,
    required String treatyId,
    required String reason,
  }) async {
    return _mutateTreaty(
      playerId: playerId,
      treatyId: treatyId,
      action: () => _apiClient.rejectTreaty(
        playerId: playerId,
        treatyId: treatyId,
        reason: reason,
        idempotencyKey:
            'diplomacy-reject:$playerId:$treatyId:${DateTime.now().millisecondsSinceEpoch}',
      ),
      fallbackError: 'Could not reject treaty.',
    );
  }

  Future<DiplomacyMutationResult?> terminateTreaty({
    required String playerId,
    required String treatyId,
    required String reason,
  }) async {
    return _mutateTreaty(
      playerId: playerId,
      treatyId: treatyId,
      action: () => _apiClient.terminateTreaty(
        playerId: playerId,
        treatyId: treatyId,
        reason: reason,
        idempotencyKey:
            'diplomacy-terminate:$playerId:$treatyId:${DateTime.now().millisecondsSinceEpoch}',
      ),
      fallbackError: 'Could not terminate treaty.',
    );
  }

  Future<DiplomacyMutationResult?> _mutateTreaty({
    required String playerId,
    required String treatyId,
    required Future<DiplomacyMutationResult> Function() action,
    required String fallbackError,
  }) async {
    if (mutatingTreatyIds.contains(treatyId)) {
      return null;
    }

    mutatingTreatyIds.add(treatyId);
    error = null;
    notifyListeners();

    try {
      final result = await action();
      lastMutation = result;
      await load(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = fallbackError;
      return null;
    } finally {
      mutatingTreatyIds.remove(treatyId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class CountryBattlesBloc extends ChangeNotifier {
  CountryBattlesBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  CountryBattleList? battles;
  CampaignList? campaigns;
  BattleDetails? selectedBattle;
  CampaignDetails? selectedCampaign;
  CountryBattleLeaderboard? countryLeaderboard;
  PlayerBattleParticipationStatus? participationStatus;
  CombatReportList? myCombatReports;
  CombatReportList? playerCombatReports;
  BattleContributionResult? lastContribution;
  CampaignMutationResult? lastCampaignMutation;
  CampaignRewardClaimResult? lastRewardClaim;
  String? error;
  bool isLoading = false;
  bool isLoadingCampaigns = false;
  bool isLoadingDetails = false;
  bool isUpdatingCampaign = false;
  final Set<String> contributingBattleIds = {};
  final Set<String> completingPhaseIds = {};
  final Set<String> claimingCampaignIds = {};

  PlayerBattleParticipation? get participation =>
      participationStatus?.participation;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    battles = null;
    campaigns = null;
    selectedBattle = null;
    selectedCampaign = null;
    countryLeaderboard = null;
    participationStatus = null;
    myCombatReports = null;
    playerCombatReports = null;
    lastContribution = null;
    lastCampaignMutation = null;
    lastRewardClaim = null;
    error = null;
    isLoading = false;
    isLoadingCampaigns = false;
    isLoadingDetails = false;
    isUpdatingCampaign = false;
    contributingBattleIds.clear();
    completingPhaseIds.clear();
    claimingCampaignIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId, {int reportLimit = 10}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchCountryBattles(),
        _apiClient.fetchCampaigns(status: 'active', limit: 25),
        _apiClient.fetchCountryBattleLeaderboard(limit: 25),
        _apiClient.fetchPlayerCombatReports(
          playerId: playerId,
          limit: reportLimit,
        ),
      ]);
      battles = results[0] as CountryBattleList;
      campaigns = results[1] as CampaignList;
      countryLeaderboard = results[2] as CountryBattleLeaderboard;
      myCombatReports = results[3] as CombatReportList;
      playerCombatReports = results[3] as CombatReportList;
      final selected = selectedBattle?.battle.battleId;
      if (selected != null) {
        await loadDetails(playerId: playerId, battleId: selected);
      }
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load country battles.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlayerReports(String playerId, {int limit = 25}) async {
    try {
      playerCombatReports = await _apiClient.fetchPlayerCombatReports(
        playerId: playerId,
        limit: limit,
      );
      error = null;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load player combat reports.';
    } finally {
      notifyListeners();
    }
  }

  void applyRealtimeBattles(RealtimeBattleUpdate update) {
    battles = update.battles;
    final selected = selectedBattle;
    if (selected != null) {
      final refreshed = update.battles.battles.where(
        (battle) => battle.battleId == selected.battle.battleId,
      );
      if (refreshed.isNotEmpty) {
        selectedBattle = BattleDetails(
          battle: refreshed.first,
          contributions: selected.contributions,
          reports: selected.reports,
          campaign: selected.campaign,
          phases: selected.phases,
          countryLeaderboard: selected.countryLeaderboard,
          unitLeaderboard: selected.unitLeaderboard,
          updatedAt: update.battles.updatedAt,
        );
      }
    }
    error = null;
    notifyListeners();
  }

  Future<void> loadDetails({
    required String playerId,
    required String battleId,
  }) async {
    isLoadingDetails = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchBattleDetails(battleId),
        _apiClient.fetchBattleParticipation(
          playerId: playerId,
          battleId: battleId,
        ),
        _apiClient.fetchPlayerCombatReports(
          playerId: playerId,
          battleId: battleId,
          limit: 10,
        ),
      ]);
      selectedBattle = results[0] as BattleDetails;
      participationStatus = results[1] as PlayerBattleParticipationStatus;
      myCombatReports = results[2] as CombatReportList;
      final campaign = selectedBattle?.campaign;
      if (campaign != null) {
        selectedCampaign = CampaignDetails(
          campaign: campaign,
          battles: [selectedBattle!.battle],
          phases: selectedBattle!.phases,
          countryLeaderboard: selectedBattle!.countryLeaderboard ??
              CountryBattleLeaderboard(
                entries: const [],
                updatedAt: selectedBattle!.updatedAt,
              ),
          unitLeaderboard: selectedBattle!.unitLeaderboard ??
              CampaignUnitLeaderboard(
                entries: const [],
                updatedAt: selectedBattle!.updatedAt,
              ),
          updatedAt: selectedBattle!.updatedAt,
        );
      }
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load battle details.';
    } finally {
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<BattleContributionResult?> contribute({
    required String playerId,
    required String battleId,
    required String idempotencyKey,
  }) async {
    if (contributingBattleIds.contains(battleId)) {
      return null;
    }

    contributingBattleIds.add(battleId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.contributeToBattle(
        playerId: playerId,
        battleId: battleId,
        idempotencyKey: idempotencyKey,
      );
      lastContribution = result;
      participationStatus = PlayerBattleParticipationStatus(
        playerId: playerId,
        battleId: battleId,
        participation: result.participation,
        updatedAt: result.updatedAt,
      );
      _replaceBattle(result.battle);
      await loadDetails(playerId: playerId, battleId: battleId);
      await loadPlayerReports(playerId, limit: 50);
      final campaignId = result.battle.campaignId;
      if (campaignId != null && campaignId.isNotEmpty) {
        await loadCampaign(campaignId);
      }
      try {
        final refreshed = await Future.wait([
          _apiClient.fetchCountryBattles(),
          _apiClient.fetchCampaigns(status: 'active', limit: 25),
          _apiClient.fetchCountryBattleLeaderboard(limit: 25),
        ]);
        battles = refreshed[0] as CountryBattleList;
        campaigns = refreshed[1] as CampaignList;
        countryLeaderboard = refreshed[2] as CountryBattleLeaderboard;
      } on BackendApiException catch (e) {
        error = e.message;
      } on Exception {
        error = 'Could not refresh country battles.';
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not contribute to battle.';
      return null;
    } finally {
      contributingBattleIds.remove(battleId);
      notifyListeners();
    }
  }

  Future<void> loadCampaigns({
    String? countryId,
    String status = 'active',
    int limit = 25,
  }) async {
    isLoadingCampaigns = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchCampaigns(
          countryId: countryId,
          status: status,
          limit: limit,
        ),
        _apiClient.fetchCountryBattleLeaderboard(limit: limit),
      ]);
      campaigns = results[0] as CampaignList;
      countryLeaderboard = results[1] as CountryBattleLeaderboard;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load campaigns.';
    } finally {
      isLoadingCampaigns = false;
      notifyListeners();
    }
  }

  Future<void> loadCampaign(String campaignId) async {
    isLoadingCampaigns = true;
    error = null;
    notifyListeners();

    try {
      selectedCampaign = await _apiClient.fetchCampaignDetails(campaignId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load campaign details.';
    } finally {
      isLoadingCampaigns = false;
      notifyListeners();
    }
  }

  Future<CampaignMutationResult?> createCampaign({
    required String playerId,
    required String countryId,
    required String name,
    required String description,
    required String campaignType,
    required int objectiveScore,
    required String idempotencyKey,
  }) async {
    if (isUpdatingCampaign) {
      return null;
    }

    isUpdatingCampaign = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createCampaign(
        playerId: playerId,
        countryId: countryId,
        name: name,
        description: description,
        campaignType: campaignType,
        objectiveScore: objectiveScore,
        idempotencyKey: idempotencyKey,
      );
      lastCampaignMutation = result;
      if (result.campaign != null) {
        await loadCampaign(result.campaign!.campaignId);
      }
      await loadCampaigns(countryId: countryId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create campaign.';
      return null;
    } finally {
      isUpdatingCampaign = false;
      notifyListeners();
    }
  }

  Future<CampaignMutationResult?> completeCampaignPhase({
    required String playerId,
    required String campaignId,
    required String phaseId,
  }) async {
    if (completingPhaseIds.contains(phaseId)) {
      return null;
    }

    completingPhaseIds.add(phaseId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.completeCampaignPhase(
        playerId: playerId,
        campaignId: campaignId,
        phaseId: phaseId,
      );
      lastCampaignMutation = result;
      await loadCampaign(campaignId);
      await loadCampaigns();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not complete campaign phase.';
      return null;
    } finally {
      completingPhaseIds.remove(phaseId);
      notifyListeners();
    }
  }

  Future<CampaignRewardClaimResult?> claimCampaignReward({
    required String playerId,
    required String campaignId,
    required String idempotencyKey,
  }) async {
    if (claimingCampaignIds.contains(campaignId)) {
      return null;
    }

    claimingCampaignIds.add(campaignId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.claimCampaignReward(
        playerId: playerId,
        campaignId: campaignId,
        idempotencyKey: idempotencyKey,
      );
      lastRewardClaim = result;
      await loadCampaign(campaignId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not claim campaign reward.';
      return null;
    } finally {
      claimingCampaignIds.remove(campaignId);
      notifyListeners();
    }
  }

  void _replaceBattle(CountryBattle battle) {
    final currentBattles = battles;
    if (currentBattles == null) {
      return;
    }

    final updated = currentBattles.battles
        .map((candidate) =>
            candidate.battleId == battle.battleId ? battle : candidate)
        .toList();
    if (!updated.any((candidate) => candidate.battleId == battle.battleId)) {
      updated.add(battle);
    }
    battles = CountryBattleList(
      battles: updated,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class MilitaryUnitsBloc extends ChangeNotifier {
  MilitaryUnitsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  MilitaryUnitList? units;
  MilitaryUnitDetails? selectedDetails;
  MilitaryUnitLeaderboard? leaderboard;
  UnitBattleContributions? selectedContributions;
  MilitaryUnitMutationResult? lastMutation;
  MilitaryUnitOrderMutationResult? lastOrderMutation;
  UnitDivisionMutationResult? lastDivisionMutation;
  DeploymentOrderMutationResult? lastDeploymentOrderMutation;
  String? error;
  bool isLoading = false;
  bool isLoadingDetails = false;
  bool isCreating = false;
  final Set<String> joiningUnitIds = {};
  final Set<String> leavingUnitIds = {};
  final Set<String> orderingUnitIds = {};
  final Set<String> updatingOrderIds = {};
  final Set<String> creatingDivisionUnitIds = {};
  final Set<String> deploymentOrderingUnitIds = {};
  final Set<String> updatingDeploymentOrderIds = {};

  MilitaryUnit? get selectedUnit => selectedDetails?.unit;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    units = null;
    selectedDetails = null;
    leaderboard = null;
    selectedContributions = null;
    lastMutation = null;
    lastOrderMutation = null;
    lastDivisionMutation = null;
    lastDeploymentOrderMutation = null;
    error = null;
    isLoading = false;
    isLoadingDetails = false;
    isCreating = false;
    joiningUnitIds.clear();
    leavingUnitIds.clear();
    orderingUnitIds.clear();
    updatingOrderIds.clear();
    creatingDivisionUnitIds.clear();
    deploymentOrderingUnitIds.clear();
    updatingDeploymentOrderIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchMilitaryUnits(playerId),
        _apiClient.fetchMilitaryUnitLeaderboard(limit: 25),
      ]);
      units = results[0] as MilitaryUnitList;
      leaderboard = results[1] as MilitaryUnitLeaderboard;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load military units.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDetails({
    required String playerId,
    required String unitId,
  }) async {
    isLoadingDetails = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiClient.fetchMilitaryUnitDetails(
          unitId: unitId,
          playerId: playerId,
        ),
        _apiClient.fetchMilitaryUnitBattleContributions(unitId: unitId),
      ]);
      selectedDetails = results[0] as MilitaryUnitDetails;
      selectedContributions = results[1] as UnitBattleContributions;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load military unit details.';
    } finally {
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<MilitaryUnitMutationResult?> create({
    required String playerId,
    required String name,
    required String description,
    required String idempotencyKey,
  }) async {
    if (isCreating) {
      return null;
    }

    isCreating = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createMilitaryUnit(
        playerId: playerId,
        name: name,
        description: description,
        idempotencyKey: idempotencyKey,
      );
      lastMutation = result;
      await load(playerId);
      if (result.unit != null) {
        await loadDetails(playerId: playerId, unitId: result.unit!.unitId);
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create military unit.';
      return null;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  Future<MilitaryUnitMutationResult?> join({
    required String playerId,
    required String unitId,
    required String idempotencyKey,
  }) async {
    if (joiningUnitIds.contains(unitId)) {
      return null;
    }

    joiningUnitIds.add(unitId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.joinMilitaryUnit(
        playerId: playerId,
        unitId: unitId,
        idempotencyKey: idempotencyKey,
      );
      lastMutation = result;
      await load(playerId);
      await loadDetails(playerId: playerId, unitId: unitId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not join military unit.';
      return null;
    } finally {
      joiningUnitIds.remove(unitId);
      notifyListeners();
    }
  }

  Future<MilitaryUnitMutationResult?> leave({
    required String playerId,
    required String unitId,
  }) async {
    if (leavingUnitIds.contains(unitId)) {
      return null;
    }

    leavingUnitIds.add(unitId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.leaveMilitaryUnit(
        playerId: playerId,
        unitId: unitId,
      );
      lastMutation = result;
      await load(playerId);
      await loadDetails(playerId: playerId, unitId: unitId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not leave military unit.';
      return null;
    } finally {
      leavingUnitIds.remove(unitId);
      notifyListeners();
    }
  }

  Future<MilitaryUnitOrderMutationResult?> issueOrder({
    required String playerId,
    required String unitId,
    required String title,
    required String description,
    required String orderType,
    String? targetBattleId,
    required String idempotencyKey,
  }) async {
    if (orderingUnitIds.contains(unitId)) {
      return null;
    }

    orderingUnitIds.add(unitId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.issueMilitaryUnitOrder(
        playerId: playerId,
        unitId: unitId,
        title: title,
        description: description,
        orderType: orderType,
        targetBattleId: targetBattleId,
        idempotencyKey: idempotencyKey,
      );
      lastOrderMutation = result;
      await loadDetails(playerId: playerId, unitId: unitId);
      await load(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not issue military unit order.';
      return null;
    } finally {
      orderingUnitIds.remove(unitId);
      notifyListeners();
    }
  }

  Future<MilitaryUnitOrderMutationResult?> completeOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    return _updateOrder(
      playerId: playerId,
      unitId: unitId,
      orderId: orderId,
      action: () => _apiClient.completeMilitaryUnitOrder(
        playerId: playerId,
        unitId: unitId,
        orderId: orderId,
      ),
    );
  }

  Future<MilitaryUnitOrderMutationResult?> cancelOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    return _updateOrder(
      playerId: playerId,
      unitId: unitId,
      orderId: orderId,
      action: () => _apiClient.cancelMilitaryUnitOrder(
        playerId: playerId,
        unitId: unitId,
        orderId: orderId,
      ),
    );
  }

  Future<UnitDivisionMutationResult?> createDivision({
    required String playerId,
    required String unitId,
    required String campaignId,
    required String name,
    required String divisionRole,
    required int memberCount,
    required int assignedStrength,
    required String idempotencyKey,
  }) async {
    if (creatingDivisionUnitIds.contains(unitId)) {
      return null;
    }

    creatingDivisionUnitIds.add(unitId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createUnitDivision(
        playerId: playerId,
        unitId: unitId,
        campaignId: campaignId,
        name: name,
        divisionRole: divisionRole,
        memberCount: memberCount,
        assignedStrength: assignedStrength,
        idempotencyKey: idempotencyKey,
      );
      lastDivisionMutation = result;
      await loadDetails(playerId: playerId, unitId: unitId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create unit division.';
      return null;
    } finally {
      creatingDivisionUnitIds.remove(unitId);
      notifyListeners();
    }
  }

  Future<DeploymentOrderMutationResult?> issueDeploymentOrder({
    required String playerId,
    required String unitId,
    String? campaignId,
    String? divisionId,
    String? targetBattleId,
    required String orderType,
    required String title,
    required String description,
    required int troopCommitment,
    required String idempotencyKey,
  }) async {
    if (deploymentOrderingUnitIds.contains(unitId)) {
      return null;
    }

    deploymentOrderingUnitIds.add(unitId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.issueDeploymentOrder(
        playerId: playerId,
        unitId: unitId,
        campaignId: campaignId,
        divisionId: divisionId,
        targetBattleId: targetBattleId,
        orderType: orderType,
        title: title,
        description: description,
        troopCommitment: troopCommitment,
        idempotencyKey: idempotencyKey,
      );
      lastDeploymentOrderMutation = result;
      await loadDetails(playerId: playerId, unitId: unitId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not issue deployment order.';
      return null;
    } finally {
      deploymentOrderingUnitIds.remove(unitId);
      notifyListeners();
    }
  }

  Future<DeploymentOrderMutationResult?> executeDeploymentOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    return _updateDeploymentOrder(
      playerId: playerId,
      unitId: unitId,
      orderId: orderId,
      action: () => _apiClient.executeDeploymentOrder(
        playerId: playerId,
        unitId: unitId,
        orderId: orderId,
      ),
    );
  }

  Future<DeploymentOrderMutationResult?> cancelDeploymentOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    return _updateDeploymentOrder(
      playerId: playerId,
      unitId: unitId,
      orderId: orderId,
      action: () => _apiClient.cancelDeploymentOrder(
        playerId: playerId,
        unitId: unitId,
        orderId: orderId,
      ),
    );
  }

  Future<DeploymentOrderMutationResult?> _updateDeploymentOrder({
    required String playerId,
    required String unitId,
    required String orderId,
    required Future<DeploymentOrderMutationResult> Function() action,
  }) async {
    if (updatingDeploymentOrderIds.contains(orderId)) {
      return null;
    }

    updatingDeploymentOrderIds.add(orderId);
    error = null;
    notifyListeners();

    try {
      final result = await action();
      lastDeploymentOrderMutation = result;
      await loadDetails(playerId: playerId, unitId: unitId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update deployment order.';
      return null;
    } finally {
      updatingDeploymentOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  Future<MilitaryUnitOrderMutationResult?> _updateOrder({
    required String playerId,
    required String unitId,
    required String orderId,
    required Future<MilitaryUnitOrderMutationResult> Function() action,
  }) async {
    if (updatingOrderIds.contains(orderId)) {
      return null;
    }

    updatingOrderIds.add(orderId);
    error = null;
    notifyListeners();

    try {
      final result = await action();
      lastOrderMutation = result;
      await loadDetails(playerId: playerId, unitId: unitId);
      await load(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update military unit order.';
      return null;
    } finally {
      updatingOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class WorkforceBloc extends ChangeNotifier {
  WorkforceBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  CompanyJobList? jobMarket;
  CompanyWorkResult? lastWork;
  String? error;
  bool isLoading = false;
  final Set<String> workingJobIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    jobMarket = null;
    lastWork = null;
    error = null;
    isLoading = false;
    workingJobIds.clear();
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      jobMarket = await _apiClient.fetchWorkforceJobs();
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load workforce jobs.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<CompanyWorkResult?> work({
    required String playerId,
    required String companyId,
    required String jobId,
    required String idempotencyKey,
  }) async {
    if (workingJobIds.contains(jobId)) {
      return null;
    }

    workingJobIds.add(jobId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.workCompanyJob(
        playerId: playerId,
        companyId: companyId,
        jobId: jobId,
        idempotencyKey: idempotencyKey,
      );
      lastWork = result;
      jobMarket = await _apiClient.fetchWorkforceJobs();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not work this company job.';
      return null;
    } finally {
      workingJobIds.remove(jobId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class CompaniesBloc extends ChangeNotifier {
  CompaniesBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  CompanyPortfolio? portfolio;
  CompanyDetail? selectedCompany;
  CompanyMutationResult? lastMutation;
  ProductionResult? lastProduction;
  CompanyProductionClaimResult? lastClaim;
  CompanyUpgradeMutationResult? lastUpgrade;
  CompanyJobMutationResult? lastJobMutation;
  CompanyWorkResult? lastWork;
  String? error;
  bool isLoading = false;
  bool isLoadingDetails = false;
  bool isCreating = false;
  bool isUpgradingHq = false;
  bool isPostingJob = false;
  final Set<String> joiningCompanyIds = {};
  final Set<String> updatingMemberIds = {};
  final Set<String> producingFactoryIds = {};
  final Set<String> claimingJobIds = {};
  final Set<String> specializingCompanyIds = {};
  final Set<String> updatingJobIds = {};
  final Set<String> workingJobIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    portfolio = null;
    selectedCompany = null;
    lastMutation = null;
    lastProduction = null;
    lastClaim = null;
    lastUpgrade = null;
    lastJobMutation = null;
    lastWork = null;
    error = null;
    isLoading = false;
    isLoadingDetails = false;
    isCreating = false;
    isUpgradingHq = false;
    isPostingJob = false;
    joiningCompanyIds.clear();
    updatingMemberIds.clear();
    producingFactoryIds.clear();
    claimingJobIds.clear();
    specializingCompanyIds.clear();
    updatingJobIds.clear();
    workingJobIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      portfolio = await _apiClient.fetchCompanies(playerId);
      final selectedId = selectedCompany?.companyId;
      if (selectedId != null) {
        await loadCompany(selectedId);
      }
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load companies.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompany(String companyId) async {
    isLoadingDetails = true;
    error = null;
    notifyListeners();

    try {
      selectedCompany = await _apiClient.fetchCompany(companyId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load company details.';
    } finally {
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<CompanyMutationResult?> create({
    required String playerId,
    required String name,
    String? description,
  }) async {
    if (isCreating) {
      return null;
    }

    isCreating = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createCompany(
        playerId: playerId,
        name: name,
        description: description,
      );
      lastMutation = result;
      selectedCompany = result.company ?? selectedCompany;
      portfolio = await _apiClient.fetchCompanies(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create company.';
      return null;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  Future<CompanyMutationResult?> join({
    required String playerId,
    required String companyId,
  }) async {
    if (joiningCompanyIds.contains(companyId)) {
      return null;
    }

    joiningCompanyIds.add(companyId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.joinCompany(companyId);
      lastMutation = result;
      selectedCompany = result.company ?? selectedCompany;
      portfolio = await _apiClient.fetchCompanies(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not join company.';
      return null;
    } finally {
      joiningCompanyIds.remove(companyId);
      notifyListeners();
    }
  }

  Future<CompanyMutationResult?> updateMemberRole({
    required String companyId,
    required String playerId,
    required String role,
  }) async {
    final key = '$companyId:$playerId';
    if (updatingMemberIds.contains(key)) {
      return null;
    }

    updatingMemberIds.add(key);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.updateCompanyMemberRole(
        companyId: companyId,
        playerId: playerId,
        role: role,
      );
      lastMutation = result;
      selectedCompany = result.company ?? selectedCompany;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update company member.';
      return null;
    } finally {
      updatingMemberIds.remove(key);
      notifyListeners();
    }
  }

  Future<CompanyMutationResult?> removeMember({
    required String companyId,
    required String playerId,
  }) async {
    final key = '$companyId:$playerId';
    if (updatingMemberIds.contains(key)) {
      return null;
    }

    updatingMemberIds.add(key);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.removeCompanyMember(
        companyId: companyId,
        playerId: playerId,
      );
      lastMutation = result;
      selectedCompany = result.company ?? selectedCompany;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not remove company member.';
      return null;
    } finally {
      updatingMemberIds.remove(key);
      notifyListeners();
    }
  }

  Future<ProductionResult?> produce({
    required String companyId,
    required String factoryId,
  }) async {
    if (producingFactoryIds.contains(factoryId)) {
      return null;
    }

    producingFactoryIds.add(factoryId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.produceCompanyFactory(
        companyId: companyId,
        factoryId: factoryId,
      );
      lastProduction = result;
      selectedCompany = await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not start company production.';
      return null;
    } finally {
      producingFactoryIds.remove(factoryId);
      notifyListeners();
    }
  }

  Future<CompanyProductionClaimResult?> claim({
    required String companyId,
    required String jobId,
  }) async {
    if (claimingJobIds.contains(jobId)) {
      return null;
    }

    claimingJobIds.add(jobId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.claimCompanyProductionJob(
        companyId: companyId,
        jobId: jobId,
      );
      lastClaim = result;
      selectedCompany = await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not claim company production.';
      return null;
    } finally {
      claimingJobIds.remove(jobId);
      notifyListeners();
    }
  }

  Future<CompanyUpgradeMutationResult?> upgradeHq({
    required String companyId,
  }) async {
    if (isUpgradingHq) {
      return null;
    }

    isUpgradingHq = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.upgradeCompanyHq(companyId: companyId);
      lastUpgrade = result;
      selectedCompany = result.company;
      selectedCompany ??= await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not upgrade company HQ.';
      return null;
    } finally {
      isUpgradingHq = false;
      notifyListeners();
    }
  }

  Future<CompanyUpgradeMutationResult?> setSpecialization({
    required String companyId,
    required String specialization,
  }) async {
    if (specializingCompanyIds.contains(companyId)) {
      return null;
    }

    specializingCompanyIds.add(companyId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.setCompanySpecialization(
        companyId: companyId,
        specialization: specialization,
      );
      lastUpgrade = result;
      selectedCompany = result.company;
      selectedCompany ??= await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not change company specialization.';
      return null;
    } finally {
      specializingCompanyIds.remove(companyId);
      notifyListeners();
    }
  }

  Future<CompanyJobMutationResult?> postJob({
    required String companyId,
    required String title,
    required String description,
    required int wageGold,
    required int requiredEnergy,
    required int dailyLimit,
    required int productivityReward,
  }) async {
    if (isPostingJob) {
      return null;
    }

    isPostingJob = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.postCompanyJob(
        companyId: companyId,
        title: title,
        description: description,
        wageGold: wageGold,
        requiredEnergy: requiredEnergy,
        dailyLimit: dailyLimit,
        productivityReward: productivityReward,
      );
      lastJobMutation = result;
      selectedCompany = await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not post company job.';
      return null;
    } finally {
      isPostingJob = false;
      notifyListeners();
    }
  }

  Future<CompanyJobMutationResult?> setJobActive({
    required String companyId,
    required CompanyJobPosting job,
    required bool isActive,
  }) async {
    if (updatingJobIds.contains(job.jobId)) {
      return null;
    }

    updatingJobIds.add(job.jobId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.updateCompanyJob(
        companyId: companyId,
        job: job,
        isActive: isActive,
      );
      lastJobMutation = result;
      selectedCompany = await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update company job.';
      return null;
    } finally {
      updatingJobIds.remove(job.jobId);
      notifyListeners();
    }
  }

  Future<CompanyJobMutationResult?> closeJob({
    required String companyId,
    required String jobId,
  }) async {
    if (updatingJobIds.contains(jobId)) {
      return null;
    }

    updatingJobIds.add(jobId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.closeCompanyJob(
        companyId: companyId,
        jobId: jobId,
      );
      lastJobMutation = result;
      selectedCompany = await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not close company job.';
      return null;
    } finally {
      updatingJobIds.remove(jobId);
      notifyListeners();
    }
  }

  Future<CompanyWorkResult?> workJob({
    required String playerId,
    required String companyId,
    required String jobId,
    required String idempotencyKey,
  }) async {
    if (workingJobIds.contains(jobId)) {
      return null;
    }

    workingJobIds.add(jobId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.workCompanyJob(
        playerId: playerId,
        companyId: companyId,
        jobId: jobId,
        idempotencyKey: idempotencyKey,
      );
      lastWork = result;
      selectedCompany = await _apiClient.fetchCompany(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not work this company job.';
      return null;
    } finally {
      workingJobIds.remove(jobId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

class NewspapersBloc extends ChangeNotifier {
  NewspapersBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  NewspaperCatalog? catalog;
  NewspaperArticleList? articleList;
  NewspaperArticle? selectedArticle;
  NewspaperMutationResult? lastNewspaperCreation;
  ArticlePublicationResult? lastPublication;
  ArticleCommentResult? lastComment;
  ArticleVoteResult? lastVote;
  NewspaperSubscriptionResult? lastSubscription;
  ContentReportResult? lastContentReport;
  String? selectedNewspaperId;
  String? error;
  bool isLoading = false;
  bool isLoadingArticles = false;
  bool isCreatingNewspaper = false;
  bool isPublishingArticle = false;
  bool isCommenting = false;
  bool isReportingContent = false;
  final Set<String> votingArticleIds = {};
  final Set<String> subscribingNewspaperIds = {};

  List<Newspaper> get newspapers => catalog?.newspapers ?? [];
  List<NewspaperArticle> get articles => articleList?.articles ?? [];

  Newspaper? get selectedNewspaper {
    final currentId = selectedNewspaperId;
    if (currentId == null) {
      return null;
    }
    for (final newspaper in newspapers) {
      if (newspaper.newspaperId == currentId) {
        return newspaper;
      }
    }
    return null;
  }

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    catalog = null;
    articleList = null;
    selectedArticle = null;
    lastNewspaperCreation = null;
    lastPublication = null;
    lastComment = null;
    lastVote = null;
    lastSubscription = null;
    lastContentReport = null;
    selectedNewspaperId = null;
    error = null;
    isLoading = false;
    isLoadingArticles = false;
    isCreatingNewspaper = false;
    isPublishingArticle = false;
    isCommenting = false;
    isReportingContent = false;
    votingArticleIds.clear();
    subscribingNewspaperIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId, {int limit = 25}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      catalog = await _apiClient.fetchNewspapers(playerId, limit: limit);
      if (selectedNewspaperId == null && newspapers.isNotEmpty) {
        selectedNewspaperId = newspapers.first.newspaperId;
      }
      final selectedId = selectedNewspaperId;
      if (selectedId != null) {
        articleList = await _apiClient.fetchNewspaperArticles(
          playerId: playerId,
          newspaperId: selectedId,
          limit: limit,
        );
      }
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load newspapers.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadArticles({
    required String playerId,
    required String newspaperId,
    int limit = 25,
  }) async {
    selectedNewspaperId = newspaperId;
    isLoadingArticles = true;
    error = null;
    notifyListeners();

    try {
      articleList = await _apiClient.fetchNewspaperArticles(
        playerId: playerId,
        newspaperId: newspaperId,
        limit: limit,
      );
      selectedArticle = null;
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load newspaper articles.';
    } finally {
      isLoadingArticles = false;
      notifyListeners();
    }
  }

  Future<NewspaperMutationResult?> createNewspaper({
    required String playerId,
    required String name,
    required String description,
  }) async {
    if (isCreatingNewspaper) {
      return null;
    }

    isCreatingNewspaper = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.createNewspaper(
        playerId: playerId,
        name: name,
        description: description,
      );
      lastNewspaperCreation = result;
      await load(playerId);
      selectedNewspaperId = result.newspaper.newspaperId;
      await loadArticles(
        playerId: playerId,
        newspaperId: result.newspaper.newspaperId,
      );
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not create newspaper.';
      return null;
    } finally {
      isCreatingNewspaper = false;
      notifyListeners();
    }
  }

  Future<ArticlePublicationResult?> publishArticle({
    required String playerId,
    required String newspaperId,
    required String title,
    required String content,
  }) async {
    if (isPublishingArticle) {
      return null;
    }

    isPublishingArticle = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.publishArticle(
        playerId: playerId,
        newspaperId: newspaperId,
        title: title,
        content: content,
      );
      lastPublication = result;
      selectedArticle = result.article;
      await load(playerId);
      selectedNewspaperId = newspaperId;
      await loadArticles(playerId: playerId, newspaperId: newspaperId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not publish article.';
      return null;
    } finally {
      isPublishingArticle = false;
      notifyListeners();
    }
  }

  Future<void> readArticle({
    required String playerId,
    required String articleId,
  }) async {
    error = null;
    notifyListeners();

    try {
      selectedArticle = await _apiClient.fetchNewspaperArticle(
        playerId: playerId,
        articleId: articleId,
      );
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not open article.';
    } finally {
      notifyListeners();
    }
  }

  Future<ArticleCommentResult?> comment({
    required String playerId,
    required String articleId,
    required String content,
  }) async {
    if (isCommenting) {
      return null;
    }

    isCommenting = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.commentOnArticle(
        playerId: playerId,
        articleId: articleId,
        content: content,
      );
      lastComment = result;
      selectedArticle = result.article;
      _replaceArticle(result.article);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not publish comment.';
      return null;
    } finally {
      isCommenting = false;
      notifyListeners();
    }
  }

  Future<ArticleVoteResult?> vote({
    required String playerId,
    required String articleId,
    required int value,
  }) async {
    if (votingArticleIds.contains(articleId)) {
      return null;
    }

    votingArticleIds.add(articleId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.voteOnArticle(
        playerId: playerId,
        articleId: articleId,
        value: value,
      );
      lastVote = result;
      selectedArticle = result.article;
      _replaceArticle(result.article);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not vote on article.';
      return null;
    } finally {
      votingArticleIds.remove(articleId);
      notifyListeners();
    }
  }

  Future<NewspaperSubscriptionResult?> subscribe({
    required String playerId,
    required String newspaperId,
    required bool subscribe,
  }) async {
    if (subscribingNewspaperIds.contains(newspaperId)) {
      return null;
    }

    subscribingNewspaperIds.add(newspaperId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.subscribeToNewspaper(
        playerId: playerId,
        newspaperId: newspaperId,
        subscribe: subscribe,
      );
      lastSubscription = result;
      selectedNewspaperId = newspaperId;
      await load(playerId);
      await loadArticles(playerId: playerId, newspaperId: newspaperId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not update newspaper subscription.';
      return null;
    } finally {
      subscribingNewspaperIds.remove(newspaperId);
      notifyListeners();
    }
  }

  Future<ContentReportResult?> reportNewspaper({
    required String playerId,
    required String newspaperId,
    required String reason,
  }) async {
    if (isReportingContent) {
      return null;
    }

    isReportingContent = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.reportNewspaper(
        playerId: playerId,
        newspaperId: newspaperId,
        reason: reason,
      );
      lastContentReport = result;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not submit content report.';
      return null;
    } finally {
      isReportingContent = false;
      notifyListeners();
    }
  }

  Future<ContentReportResult?> reportArticle({
    required String playerId,
    required String articleId,
    required String reason,
  }) async {
    if (isReportingContent) {
      return null;
    }

    isReportingContent = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.reportArticle(
        playerId: playerId,
        articleId: articleId,
        reason: reason,
      );
      lastContentReport = result;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not submit content report.';
      return null;
    } finally {
      isReportingContent = false;
      notifyListeners();
    }
  }

  Future<ContentReportResult?> reportArticleComment({
    required String playerId,
    required String articleId,
    required String commentId,
    required String reason,
  }) async {
    if (isReportingContent) {
      return null;
    }

    isReportingContent = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.reportArticleComment(
        playerId: playerId,
        articleId: articleId,
        commentId: commentId,
        reason: reason,
      );
      lastContentReport = result;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not submit content report.';
      return null;
    } finally {
      isReportingContent = false;
      notifyListeners();
    }
  }

  void _replaceArticle(NewspaperArticle article) {
    final currentList = articleList;
    if (currentList == null) {
      return;
    }

    final updated = currentList.articles
        .map((candidate) =>
            candidate.articleId == article.articleId ? article : candidate)
        .toList();
    if (!updated.any((candidate) => candidate.articleId == article.articleId)) {
      updated.insert(0, article);
    }
    articleList = NewspaperArticleList(
      newspaperId: currentList.newspaperId,
      articles: updated,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

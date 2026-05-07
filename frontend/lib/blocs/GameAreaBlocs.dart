import 'package:flutter/foundation.dart';

import '../models/GameAreas.dart';
import '../services/backend_api.dart';

class InventoryBloc extends ChangeNotifier {
  InventoryBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  InventorySummary? inventory;
  String? error;
  bool isLoading = false;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    inventory = null;
    error = null;
    isLoading = false;
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
  ProductionResult? lastProduction;
  String? error;
  bool isLoading = false;
  final Set<String> producingFactoryIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      portfolio = await _apiClient.fetchFactories(playerId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load factories.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
  MarketPurchaseResult? lastPurchase;
  String? error;
  bool isLoading = false;
  final Set<String> buyingListingIds = {};

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

  Future<MarketPurchaseResult?> buy(String playerId, String listingId) async {
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
  MissionFightResult? lastFight;
  String? error;
  bool isLoading = false;
  final Set<String> fightingMissionIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      missions = await _apiClient.fetchCombatMissions();
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load missions.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<MissionFightResult?> fight(String playerId, String missionId) async {
    if (fightingMissionIds.contains(missionId)) {
      return null;
    }

    fightingMissionIds.add(missionId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.fightMission(playerId, missionId);
      lastFight = result;
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

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

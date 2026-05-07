import 'package:flutter/foundation.dart';

import '../models/GameAreas.dart';
import '../models/ResourceLogistics.dart';
import '../services/backend_api.dart';

class ResourceLogisticsBloc extends ChangeNotifier {
  ResourceLogisticsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  ResourceSiteList? resourceSites;
  ResourceLogisticsDashboard? dashboard;
  ExtractionMutationResult? lastExtraction;
  ExtractionClaimResult? lastClaim;
  ShipmentMutationResult? lastShipment;
  String? error;
  bool isLoading = false;
  bool isMutating = false;
  final Set<String> claimingExtractionIds = {};
  final Set<String> deliveringShipmentIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load({String? companyId}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      resourceSites = await _apiClient.fetchResourceSites();
      if (companyId != null && companyId.isNotEmpty) {
        dashboard = await _apiClient.fetchCompanyResourceLogistics(companyId);
      }
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load resource logistics.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDashboard(String companyId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      dashboard = await _apiClient.fetchCompanyResourceLogistics(companyId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load company logistics.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ExtractionMutationResult?> startExtraction({
    required String companyId,
    required ResourceSite site,
    int requestedRuns = 1,
  }) async {
    if (isMutating) {
      return null;
    }

    isMutating = true;
    error = null;
    notifyListeners();
    try {
      final result = await _apiClient.startCompanyResourceExtraction(
        companyId: companyId,
        siteId: site.siteId,
        requestedRuns: requestedRuns,
        idempotencyKey:
            'extraction-${site.siteId}-${DateTime.now().microsecondsSinceEpoch}',
      );
      lastExtraction = result;
      dashboard = await _apiClient.fetchCompanyResourceLogistics(companyId);
      resourceSites = await _apiClient.fetchResourceSites();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not start extraction.';
      return null;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<ExtractionClaimResult?> claimExtraction({
    required String companyId,
    required CompanyExtractionJob job,
  }) async {
    if (claimingExtractionIds.contains(job.jobId)) {
      return null;
    }

    claimingExtractionIds.add(job.jobId);
    error = null;
    notifyListeners();
    try {
      final result = await _apiClient.claimCompanyResourceExtraction(
        companyId: companyId,
        jobId: job.jobId,
      );
      lastClaim = result;
      dashboard = await _apiClient.fetchCompanyResourceLogistics(companyId);
      resourceSites = await _apiClient.fetchResourceSites();
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not claim extraction.';
      return null;
    } finally {
      claimingExtractionIds.remove(job.jobId);
      notifyListeners();
    }
  }

  Future<ShipmentMutationResult?> dispatchShipment({
    required String companyId,
    required InventoryItem item,
    required ResourceSite origin,
    required ResourceSite destination,
    int quantity = 1,
  }) async {
    if (isMutating) {
      return null;
    }

    isMutating = true;
    error = null;
    notifyListeners();
    try {
      final result = await _apiClient.dispatchCompanyShipment(
        companyId: companyId,
        item: item,
        origin: origin,
        destination: destination,
        quantity: quantity,
        durationSeconds: 30,
        idempotencyKey:
            'shipment-${item.itemId}-${DateTime.now().microsecondsSinceEpoch}',
      );
      lastShipment = result;
      dashboard = await _apiClient.fetchCompanyResourceLogistics(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not dispatch shipment.';
      return null;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<ShipmentMutationResult?> deliverShipment({
    required String companyId,
    required CompanyShipment shipment,
  }) async {
    if (deliveringShipmentIds.contains(shipment.shipmentId)) {
      return null;
    }

    deliveringShipmentIds.add(shipment.shipmentId);
    error = null;
    notifyListeners();
    try {
      final result = await _apiClient.deliverCompanyShipment(
        companyId: companyId,
        shipmentId: shipment.shipmentId,
      );
      lastShipment = result;
      dashboard = await _apiClient.fetchCompanyResourceLogistics(companyId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not deliver shipment.';
      return null;
    } finally {
      deliveringShipmentIds.remove(shipment.shipmentId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

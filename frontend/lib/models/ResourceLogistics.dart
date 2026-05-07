import 'GameAreas.dart';

class ResourceSiteList {
  final List<ResourceSite> sites;
  final DateTime updatedAt;

  ResourceSiteList({
    required this.sites,
    required this.updatedAt,
  });

  factory ResourceSiteList.fromJson(Map<String, dynamic> json) {
    return ResourceSiteList(
      sites: _requiredList(json, 'sites')
          .map((site) => ResourceSite.fromJson(_requiredMap(site)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResourceSite {
  final String siteId;
  final String regionId;
  final String countryId;
  final String resourceId;
  final String resourceName;
  final String itemId;
  final String itemName;
  final String itemCategory;
  final String siteName;
  final String terrain;
  final int baseYield;
  final int extractionSeconds;
  final int reserveRemaining;
  final int reserveCapacity;
  final int depletionPerRun;
  final int qualityPercent;
  final int extractionCount;
  final bool isDepleted;
  final DateTime updatedAt;

  ResourceSite({
    required this.siteId,
    required this.regionId,
    required this.countryId,
    required this.resourceId,
    required this.resourceName,
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.siteName,
    required this.terrain,
    required this.baseYield,
    required this.extractionSeconds,
    required this.reserveRemaining,
    required this.reserveCapacity,
    required this.depletionPerRun,
    required this.qualityPercent,
    required this.extractionCount,
    required this.isDepleted,
    required this.updatedAt,
  });

  double get reserveRatio => reserveCapacity <= 0
      ? 0
      : (reserveRemaining / reserveCapacity).clamp(0, 1).toDouble();

  factory ResourceSite.fromJson(Map<String, dynamic> json) {
    return ResourceSite(
      siteId: _requiredString(json, 'siteId'),
      regionId: _requiredString(json, 'regionId'),
      countryId: _requiredString(json, 'countryId'),
      resourceId: _requiredString(json, 'resourceId'),
      resourceName: _requiredString(json, 'resourceName'),
      itemId: _requiredString(json, 'itemId'),
      itemName: _requiredString(json, 'itemName'),
      itemCategory: _requiredString(json, 'itemCategory'),
      siteName: _requiredString(json, 'siteName'),
      terrain: _requiredString(json, 'terrain'),
      baseYield: _requiredInt(json, 'baseYield'),
      extractionSeconds: _requiredInt(json, 'extractionSeconds'),
      reserveRemaining: _requiredInt(json, 'reserveRemaining'),
      reserveCapacity: _requiredInt(json, 'reserveCapacity'),
      depletionPerRun: _requiredInt(json, 'depletionPerRun'),
      qualityPercent: _requiredInt(json, 'qualityPercent'),
      extractionCount: _requiredInt(json, 'extractionCount'),
      isDepleted: _requiredBool(json, 'isDepleted'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResourceLogisticsDashboard {
  final String companyId;
  final List<CompanyExtractionJob> extractions;
  final List<CompanyShipment> shipments;
  final int inTransitQuantity;
  final CompanyAssets assets;
  final DateTime updatedAt;

  ResourceLogisticsDashboard({
    required this.companyId,
    required this.extractions,
    required this.shipments,
    required this.inTransitQuantity,
    required this.assets,
    required this.updatedAt,
  });

  factory ResourceLogisticsDashboard.fromJson(Map<String, dynamic> json) {
    return ResourceLogisticsDashboard(
      companyId: _requiredString(json, 'companyId'),
      extractions: _requiredList(json, 'extractions')
          .map((job) => CompanyExtractionJob.fromJson(_requiredMap(job)))
          .toList(),
      shipments: _requiredList(json, 'shipments')
          .map((shipment) => CompanyShipment.fromJson(_requiredMap(shipment)))
          .toList(),
      inTransitQuantity: _requiredInt(json, 'inTransitQuantity'),
      assets: CompanyAssets.fromJson(_requiredMap(json['assets'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CompanyExtractionJob {
  final String jobId;
  final String companyId;
  final String actorPlayerId;
  final String siteId;
  final String regionId;
  final String regionName;
  final String countryId;
  final String resourceId;
  final String resourceName;
  final String itemId;
  final String itemName;
  final String itemCategory;
  final int requestedRuns;
  final int baseYield;
  final int yieldQuantity;
  final String status;
  final int durationSeconds;
  final DateTime startedAt;
  final DateTime completesAt;
  final DateTime? completedAt;
  final DateTime? claimedAt;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool canClaim;

  CompanyExtractionJob({
    required this.jobId,
    required this.companyId,
    required this.actorPlayerId,
    required this.siteId,
    required this.regionId,
    required this.regionName,
    required this.countryId,
    required this.resourceId,
    required this.resourceName,
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.requestedRuns,
    required this.baseYield,
    required this.yieldQuantity,
    required this.status,
    required this.durationSeconds,
    required this.startedAt,
    required this.completesAt,
    required this.completedAt,
    required this.claimedAt,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
    required this.canClaim,
  });

  bool get isClaimed => claimedAt != null || status == 'claimed';

  factory CompanyExtractionJob.fromJson(Map<String, dynamic> json) {
    return CompanyExtractionJob(
      jobId: _requiredString(json, 'jobId'),
      companyId: _requiredString(json, 'companyId'),
      actorPlayerId: _requiredString(json, 'actorPlayerId'),
      siteId: _requiredString(json, 'siteId'),
      regionId: _requiredString(json, 'regionId'),
      regionName: _requiredString(json, 'regionName'),
      countryId: _requiredString(json, 'countryId'),
      resourceId: _requiredString(json, 'resourceId'),
      resourceName: _requiredString(json, 'resourceName'),
      itemId: _requiredString(json, 'itemId'),
      itemName: _requiredString(json, 'itemName'),
      itemCategory: _requiredString(json, 'itemCategory'),
      requestedRuns: _requiredInt(json, 'requestedRuns'),
      baseYield: _requiredInt(json, 'baseYield'),
      yieldQuantity: _requiredInt(json, 'yieldQuantity'),
      status: _requiredString(json, 'status'),
      durationSeconds: _requiredInt(json, 'durationSeconds'),
      startedAt: _requiredDateTime(json, 'startedAt'),
      completesAt: _requiredDateTime(json, 'completesAt'),
      completedAt: _optionalDateTime(json, 'completedAt'),
      claimedAt: _optionalDateTime(json, 'claimedAt'),
      idempotencyKey: _requiredString(json, 'idempotencyKey'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      canClaim: _requiredBool(json, 'canClaim'),
    );
  }
}

class CompanyShipment {
  final String shipmentId;
  final String companyId;
  final String actorPlayerId;
  final String itemId;
  final String itemName;
  final String itemCategory;
  final int quantity;
  final String originRegionId;
  final String originRegionName;
  final String destinationRegionId;
  final String destinationRegionName;
  final String status;
  final int durationSeconds;
  final DateTime dispatchedAt;
  final DateTime arrivesAt;
  final DateTime? deliveredAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool canDeliver;

  CompanyShipment({
    required this.shipmentId,
    required this.companyId,
    required this.actorPlayerId,
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.quantity,
    required this.originRegionId,
    required this.originRegionName,
    required this.destinationRegionId,
    required this.destinationRegionName,
    required this.status,
    required this.durationSeconds,
    required this.dispatchedAt,
    required this.arrivesAt,
    required this.deliveredAt,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
    required this.canDeliver,
  });

  bool get isDelivered => deliveredAt != null || status == 'delivered';

  factory CompanyShipment.fromJson(Map<String, dynamic> json) {
    return CompanyShipment(
      shipmentId: _requiredString(json, 'shipmentId'),
      companyId: _requiredString(json, 'companyId'),
      actorPlayerId: _requiredString(json, 'actorPlayerId'),
      itemId: _requiredString(json, 'itemId'),
      itemName: _requiredString(json, 'itemName'),
      itemCategory: _requiredString(json, 'itemCategory'),
      quantity: _requiredInt(json, 'quantity'),
      originRegionId: _requiredString(json, 'originRegionId'),
      originRegionName: _requiredString(json, 'originRegionName'),
      destinationRegionId: _requiredString(json, 'destinationRegionId'),
      destinationRegionName: _requiredString(json, 'destinationRegionName'),
      status: _requiredString(json, 'status'),
      durationSeconds: _requiredInt(json, 'durationSeconds'),
      dispatchedAt: _requiredDateTime(json, 'dispatchedAt'),
      arrivesAt: _requiredDateTime(json, 'arrivesAt'),
      deliveredAt: _optionalDateTime(json, 'deliveredAt'),
      lastError: _optionalString(json, 'lastError'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      canDeliver: _requiredBool(json, 'canDeliver'),
    );
  }
}

class ExtractionMutationResult {
  final bool completed;
  final String message;
  final CompanyExtractionJob extraction;
  final CompanyAssets assets;
  final DateTime updatedAt;

  ExtractionMutationResult({
    required this.completed,
    required this.message,
    required this.extraction,
    required this.assets,
    required this.updatedAt,
  });

  factory ExtractionMutationResult.fromJson(Map<String, dynamic> json) {
    return ExtractionMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      extraction:
          CompanyExtractionJob.fromJson(_requiredMap(json['extraction'])),
      assets: CompanyAssets.fromJson(_requiredMap(json['assets'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ExtractionClaimResult {
  final bool completed;
  final bool alreadyClaimed;
  final String message;
  final CompanyExtractionJob extraction;
  final CompanyAssets assets;
  final int depletionAmount;
  final ResourceSiteMutation? resourceDepletion;
  final DateTime updatedAt;

  ExtractionClaimResult({
    required this.completed,
    required this.alreadyClaimed,
    required this.message,
    required this.extraction,
    required this.assets,
    required this.depletionAmount,
    required this.resourceDepletion,
    required this.updatedAt,
  });

  factory ExtractionClaimResult.fromJson(Map<String, dynamic> json) {
    return ExtractionClaimResult(
      completed: _requiredBool(json, 'completed'),
      alreadyClaimed: _requiredBool(json, 'alreadyClaimed'),
      message: _requiredString(json, 'message'),
      extraction:
          CompanyExtractionJob.fromJson(_requiredMap(json['extraction'])),
      assets: CompanyAssets.fromJson(_requiredMap(json['assets'])),
      depletionAmount: _requiredInt(json, 'depletionAmount'),
      resourceDepletion: json['resourceDepletion'] == null
          ? null
          : ResourceSiteMutation.fromJson(
              _requiredMap(json['resourceDepletion'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResourceSiteMutation {
  final bool completed;
  final String message;
  final ResourceSite site;
  final DateTime updatedAt;

  ResourceSiteMutation({
    required this.completed,
    required this.message,
    required this.site,
    required this.updatedAt,
  });

  factory ResourceSiteMutation.fromJson(Map<String, dynamic> json) {
    return ResourceSiteMutation(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      site: ResourceSite.fromJson(_requiredMap(json['site'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ShipmentMutationResult {
  final bool completed;
  final String message;
  final CompanyShipment shipment;
  final CompanyAssets assets;
  final DateTime updatedAt;

  ShipmentMutationResult({
    required this.completed,
    required this.message,
    required this.shipment,
    required this.assets,
    required this.updatedAt,
  });

  factory ShipmentMutationResult.fromJson(Map<String, dynamic> json) {
    return ShipmentMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      shipment: CompanyShipment.fromJson(_requiredMap(json['shipment'])),
      assets: CompanyAssets.fromJson(_requiredMap(json['assets'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Missing required resource logistics field "$field".');
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value is String && value.isNotEmpty ? value : null;
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Missing required integer resource field "$field".');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }
  throw FormatException('Missing required boolean resource field "$field".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  throw FormatException('Missing required date resource field "$field".');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return null;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List<dynamic>) {
    return value;
  }
  throw FormatException('Missing required list resource field "$field".');
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw const FormatException('Missing required resource object field.');
}

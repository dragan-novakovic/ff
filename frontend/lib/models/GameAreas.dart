class InventorySummary {
  final String playerId;
  final int walletGold;
  final int storageUsed;
  final int storageLimit;
  final List<InventoryItem> items;
  final DateTime updatedAt;

  InventorySummary({
    required this.playerId,
    required this.walletGold,
    required this.storageUsed,
    required this.storageLimit,
    required this.items,
    required this.updatedAt,
  });

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    final items = _requiredList(json, 'items')
        .map((item) => InventoryItem.fromJson(_requiredMap(item)))
        .toList();
    return InventorySummary(
      playerId: _requiredString(json, 'playerId'),
      walletGold: _requiredInt(json, 'walletGold'),
      storageUsed: _requiredInt(json, 'storageUsed'),
      storageLimit: _requiredInt(json, 'storageLimit'),
      items: items,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class InventoryItem {
  final String itemId;
  final String name;
  final String category;
  final int quantity;
  final String description;

  InventoryItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.description,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: _requiredString(json, 'itemId'),
      name: _requiredString(json, 'name'),
      category: _requiredString(json, 'category'),
      quantity: _requiredInt(json, 'quantity'),
      description: _requiredString(json, 'description'),
    );
  }
}

class InventoryItemUseResult {
  final bool completed;
  final String message;
  final InventorySummary inventory;

  InventoryItemUseResult({
    required this.completed,
    required this.message,
    required this.inventory,
  });

  factory InventoryItemUseResult.fromJson(Map<String, dynamic> json) {
    return InventoryItemUseResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      inventory: InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class LedgerSummary {
  final String playerId;
  final List<LedgerEntry> entries;
  final DateTime updatedAt;

  LedgerSummary({
    required this.playerId,
    required this.entries,
    required this.updatedAt,
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    final entries = _requiredList(json, 'entries')
        .map((entry) => LedgerEntry.fromJson(_requiredMap(entry)))
        .toList();
    return LedgerSummary(
      playerId: _requiredString(json, 'playerId'),
      entries: entries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class LedgerEntry {
  final String ledgerId;
  final String entryType;
  final int goldDelta;
  final String itemId;
  final int itemDelta;
  final String description;
  final DateTime createdAt;

  LedgerEntry({
    required this.ledgerId,
    required this.entryType,
    required this.goldDelta,
    required this.itemId,
    required this.itemDelta,
    required this.description,
    required this.createdAt,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      ledgerId: _requiredString(json, 'ledgerId'),
      entryType: _requiredString(json, 'entryType'),
      goldDelta: _requiredInt(json, 'goldDelta'),
      itemId: _optionalString(json, 'itemId', defaultValue: ''),
      itemDelta: _requiredInt(json, 'itemDelta'),
      description: _requiredString(json, 'description'),
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }
}

class EquipmentSummary {
  final String playerId;
  final EquippedWeapon? weapon;
  final DateTime updatedAt;

  EquipmentSummary({
    required this.playerId,
    required this.weapon,
    required this.updatedAt,
  });

  factory EquipmentSummary.fromJson(Map<String, dynamic> json) {
    return EquipmentSummary(
      playerId: _requiredString(json, 'playerId'),
      weapon: json['weapon'] == null
          ? null
          : EquippedWeapon.fromJson(_requiredMap(json['weapon'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class EquippedWeapon {
  final String itemId;
  final String name;
  final String category;
  final int weaponPower;
  final int durability;
  final int maxDurability;
  final DateTime equippedAt;
  final DateTime updatedAt;

  EquippedWeapon({
    required this.itemId,
    required this.name,
    required this.category,
    required this.weaponPower,
    required this.durability,
    required this.maxDurability,
    required this.equippedAt,
    required this.updatedAt,
  });

  bool get isUsable => durability > 0;

  double get durabilityProgress {
    if (maxDurability <= 0) {
      return 0;
    }

    return (durability / maxDurability).clamp(0, 1).toDouble();
  }

  factory EquippedWeapon.fromJson(Map<String, dynamic> json) {
    return EquippedWeapon(
      itemId: _requiredString(json, 'itemId'),
      name: _requiredString(json, 'name'),
      category: _requiredString(json, 'category'),
      weaponPower: _requiredInt(json, 'weaponPower'),
      durability: _requiredInt(json, 'durability'),
      maxDurability: _requiredInt(json, 'maxDurability'),
      equippedAt: _requiredDateTime(json, 'equippedAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class EquipWeaponResult {
  final bool completed;
  final String message;
  final EquipmentSummary equipment;
  final InventorySummary inventory;

  EquipWeaponResult({
    required this.completed,
    required this.message,
    required this.equipment,
    required this.inventory,
  });

  factory EquipWeaponResult.fromJson(Map<String, dynamic> json) {
    return EquipWeaponResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      equipment: EquipmentSummary.fromJson(_requiredMap(json['equipment'])),
      inventory: InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class WeaponDamageResult {
  final bool completed;
  final String message;
  final int durabilityLost;
  final EquipmentSummary equipment;

  WeaponDamageResult({
    required this.completed,
    required this.message,
    required this.durabilityLost,
    required this.equipment,
  });

  factory WeaponDamageResult.fromJson(Map<String, dynamic> json) {
    return WeaponDamageResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      durabilityLost: _requiredInt(json, 'durabilityLost'),
      equipment: EquipmentSummary.fromJson(_requiredMap(json['equipment'])),
    );
  }
}

class RepairWeaponResult {
  final bool completed;
  final String message;
  final int goldCost;
  final String materialItemId;
  final String materialItemName;
  final int materialQuantity;
  final EquipmentSummary equipment;
  final InventorySummary inventory;

  RepairWeaponResult({
    required this.completed,
    required this.message,
    required this.goldCost,
    required this.materialItemId,
    required this.materialItemName,
    required this.materialQuantity,
    required this.equipment,
    required this.inventory,
  });

  factory RepairWeaponResult.fromJson(Map<String, dynamic> json) {
    return RepairWeaponResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      goldCost: _requiredInt(json, 'goldCost'),
      materialItemId: _requiredString(json, 'materialItemId'),
      materialItemName: _requiredString(json, 'materialItemName'),
      materialQuantity: _requiredInt(json, 'materialQuantity'),
      equipment: EquipmentSummary.fromJson(_requiredMap(json['equipment'])),
      inventory: InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class FactoryPortfolio {
  final String playerId;
  final List<PlayerFactory> factories;
  final DateTime updatedAt;

  FactoryPortfolio({
    required this.playerId,
    required this.factories,
    required this.updatedAt,
  });

  factory FactoryPortfolio.fromJson(Map<String, dynamic> json) {
    final factories = _requiredList(json, 'factories')
        .map((factory) => PlayerFactory.fromJson(_requiredMap(factory)))
        .toList();
    return FactoryPortfolio(
      playerId: _requiredString(json, 'playerId'),
      factories: factories,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PlayerFactory {
  final String factoryId;
  final String name;
  final String category;
  final int level;
  final String inputItemId;
  final int inputQuantity;
  final String outputItemId;
  final int outputQuantity;
  final bool canProduce;
  final int productionCount;
  final DateTime? lastProducedAt;
  final DateTime? cooldownUntil;
  final int productionDurationSeconds;
  final String? activeJobId;
  final int queueDepth;
  final int maxQueueDepth;
  final ProductionBonus? resourceEffect;

  PlayerFactory({
    required this.factoryId,
    required this.name,
    required this.category,
    required this.level,
    required this.inputItemId,
    required this.inputQuantity,
    required this.outputItemId,
    required this.outputQuantity,
    required this.canProduce,
    required this.productionCount,
    required this.lastProducedAt,
    required this.cooldownUntil,
    required this.productionDurationSeconds,
    required this.activeJobId,
    required this.queueDepth,
    required this.maxQueueDepth,
    required this.resourceEffect,
  });

  factory PlayerFactory.fromJson(Map<String, dynamic> json) {
    return PlayerFactory(
      factoryId: _requiredString(json, 'factoryId'),
      name: _requiredString(json, 'name'),
      category: _requiredString(json, 'category'),
      level: _requiredInt(json, 'level'),
      inputItemId: _requiredString(json, 'inputItemId'),
      inputQuantity: _requiredInt(json, 'inputQuantity'),
      outputItemId: _requiredString(json, 'outputItemId'),
      outputQuantity: _requiredInt(json, 'outputQuantity'),
      canProduce: _requiredBool(json, 'canProduce'),
      productionCount: _optionalInt(json, 'productionCount'),
      lastProducedAt: _optionalDateTime(json, 'lastProducedAt'),
      cooldownUntil: _optionalDateTime(json, 'cooldownUntil'),
      productionDurationSeconds:
          _optionalInt(json, 'productionDurationSeconds'),
      activeJobId: _optionalNullableString(json, 'activeJobId'),
      queueDepth: _optionalInt(json, 'queueDepth'),
      maxQueueDepth: _optionalInt(json, 'maxQueueDepth'),
      resourceEffect: json['resourceEffect'] == null
          ? null
          : ProductionBonus.fromJson(_requiredMap(json['resourceEffect'])),
    );
  }
}

class ProductionBonus {
  final int productionBonusPercent;
  final String sourceRegionId;
  final String sourceRegionName;
  final String resourceName;
  final String itemId;

  ProductionBonus({
    required this.productionBonusPercent,
    required this.sourceRegionId,
    required this.sourceRegionName,
    required this.resourceName,
    required this.itemId,
  });

  factory ProductionBonus.fromJson(Map<String, dynamic> json) {
    return ProductionBonus(
      productionBonusPercent: _requiredInt(json, 'productionBonusPercent',
          fallbackField: 'production_bonus_percent'),
      sourceRegionId: _requiredString(json, 'sourceRegionId',
          fallbackField: 'source_region_id'),
      sourceRegionName: _requiredString(json, 'sourceRegionName',
          fallbackField: 'source_region_name'),
      resourceName:
          _requiredString(json, 'resourceName', fallbackField: 'resource_name'),
      itemId: _requiredString(json, 'itemId', fallbackField: 'item_id'),
    );
  }
}

class ProductionJobsResponse {
  final String playerId;
  final List<ProductionJob> jobs;
  final DateTime updatedAt;

  ProductionJobsResponse({
    required this.playerId,
    required this.jobs,
    required this.updatedAt,
  });

  factory ProductionJobsResponse.fromJson(Map<String, dynamic> json) {
    final jobs = _requiredList(json, 'jobs')
        .map((job) => ProductionJob.fromJson(_requiredMap(job)))
        .toList();
    return ProductionJobsResponse(
      playerId: _requiredString(json, 'playerId'),
      jobs: jobs,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  List<ProductionJob> forFactory(String factoryId) {
    return jobs.where((job) => job.factoryId == factoryId).toList();
  }
}

class ProductionJob {
  final String jobId;
  final String playerId;
  final String factoryId;
  final String status;
  final String inputItemId;
  final String inputItemName;
  final String inputItemCategory;
  final int inputQuantity;
  final String outputItemId;
  final String outputItemName;
  final String outputItemCategory;
  final int outputQuantity;
  final int durationSeconds;
  final DateTime startedAt;
  final DateTime completesAt;
  final DateTime? completedAt;
  final DateTime? claimedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool canClaim;
  final ProductionBonus? appliedBonus;
  final int researchDurationReductionPercent;

  ProductionJob({
    required this.jobId,
    required this.playerId,
    required this.factoryId,
    required this.status,
    required this.inputItemId,
    required this.inputItemName,
    required this.inputItemCategory,
    required this.inputQuantity,
    required this.outputItemId,
    required this.outputItemName,
    required this.outputItemCategory,
    required this.outputQuantity,
    required this.durationSeconds,
    required this.startedAt,
    required this.completesAt,
    required this.completedAt,
    required this.claimedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.canClaim,
    required this.appliedBonus,
    required this.researchDurationReductionPercent,
  });

  bool get isClaimed => claimedAt != null || status == 'claimed';
  bool get isReady =>
      canClaim ||
      ((status == 'completed' || status == 'claiming') && !isClaimed);
  bool get isPending => status == 'queued' || status == 'running';
  bool get isVisibleOnFactory => !isClaimed && status != 'cancelled';

  Duration get remaining {
    final diff = completesAt.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  double get progress {
    if (isReady || isClaimed) {
      return 1;
    }
    final duration = durationSeconds <= 0 ? 1 : durationSeconds;
    final elapsed = DateTime.now().toUtc().difference(startedAt).inSeconds;
    return (elapsed / duration).clamp(0, 1).toDouble();
  }

  factory ProductionJob.fromJson(Map<String, dynamic> json) {
    return ProductionJob(
      jobId: _requiredString(json, 'jobId'),
      playerId: _requiredString(json, 'playerId'),
      factoryId: _requiredString(json, 'factoryId'),
      status: _requiredString(json, 'status'),
      inputItemId: _requiredString(json, 'inputItemId'),
      inputItemName: _requiredString(json, 'inputItemName'),
      inputItemCategory: _requiredString(json, 'inputItemCategory'),
      inputQuantity: _requiredInt(json, 'inputQuantity'),
      outputItemId: _requiredString(json, 'outputItemId'),
      outputItemName: _requiredString(json, 'outputItemName'),
      outputItemCategory: _requiredString(json, 'outputItemCategory'),
      outputQuantity: _requiredInt(json, 'outputQuantity'),
      durationSeconds: _requiredInt(json, 'durationSeconds'),
      startedAt: _requiredDateTime(json, 'startedAt'),
      completesAt: _requiredDateTime(json, 'completesAt'),
      completedAt: _optionalDateTime(json, 'completedAt'),
      claimedAt: _optionalDateTime(json, 'claimedAt'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      canClaim: _requiredBool(json, 'canClaim'),
      appliedBonus: json['appliedBonus'] == null
          ? null
          : ProductionBonus.fromJson(_requiredMap(json['appliedBonus'])),
      researchDurationReductionPercent:
          _optionalInt(json, 'researchDurationReductionPercent'),
    );
  }
}

class ProductionResult {
  final bool completed;
  final String factoryId;
  final String message;
  final String consumedItemId;
  final int consumedQuantity;
  final String producedItemId;
  final int producedQuantity;
  final String note;
  final DateTime completedAt;
  final int productionCount;
  final DateTime? lastProducedAt;
  final ProductionJob? job;
  final DateTime? startedAt;
  final DateTime? completesAt;
  final InventorySummary? inventory;
  final ProductionBonus? appliedBonus;

  ProductionResult({
    required this.completed,
    required this.factoryId,
    required this.message,
    required this.consumedItemId,
    required this.consumedQuantity,
    required this.producedItemId,
    required this.producedQuantity,
    required this.note,
    required this.completedAt,
    required this.productionCount,
    required this.lastProducedAt,
    required this.job,
    required this.startedAt,
    required this.completesAt,
    required this.inventory,
    required this.appliedBonus,
  });

  factory ProductionResult.fromJson(Map<String, dynamic> json) {
    return ProductionResult(
      completed: _requiredBool(json, 'completed'),
      factoryId: _requiredString(json, 'factoryId'),
      message: _requiredString(json, 'message'),
      consumedItemId: _requiredString(json, 'consumedItemId'),
      consumedQuantity: _requiredInt(json, 'consumedQuantity'),
      producedItemId: _requiredString(json, 'producedItemId'),
      producedQuantity: _requiredInt(json, 'producedQuantity'),
      note: _requiredString(json, 'note'),
      completedAt: _requiredDateTime(json, 'completedAt'),
      productionCount: _optionalInt(json, 'productionCount'),
      lastProducedAt: _optionalDateTime(json, 'lastProducedAt'),
      job: json['job'] == null
          ? null
          : ProductionJob.fromJson(_requiredMap(json['job'])),
      startedAt: _optionalDateTime(json, 'startedAt'),
      completesAt: _optionalDateTime(json, 'completesAt'),
      inventory: json['inventory'] == null
          ? null
          : InventorySummary.fromJson(_requiredMap(json['inventory'])),
      appliedBonus: json['appliedBonus'] == null
          ? null
          : ProductionBonus.fromJson(_requiredMap(json['appliedBonus'])),
    );
  }
}

class ProductionClaimResult {
  final bool completed;
  final String message;
  final ProductionClaimCompletion claim;
  final InventorySummary? inventory;

  ProductionClaimResult({
    required this.completed,
    required this.message,
    required this.claim,
    required this.inventory,
  });

  factory ProductionClaimResult.fromJson(Map<String, dynamic> json) {
    return ProductionClaimResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      claim: ProductionClaimCompletion.fromJson(_requiredMap(json['claim'])),
      inventory: json['inventory'] == null
          ? null
          : InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class ProductionClaimCompletion {
  final bool completed;
  final bool alreadyClaimed;
  final String message;
  final ProductionJob job;
  final int productionCount;

  ProductionClaimCompletion({
    required this.completed,
    required this.alreadyClaimed,
    required this.message,
    required this.job,
    required this.productionCount,
  });

  factory ProductionClaimCompletion.fromJson(Map<String, dynamic> json) {
    return ProductionClaimCompletion(
      completed: _requiredBool(json, 'completed'),
      alreadyClaimed: _requiredBool(json, 'alreadyClaimed'),
      message: _requiredString(json, 'message'),
      job: ProductionJob.fromJson(_requiredMap(json['job'])),
      productionCount: _optionalInt(json, 'productionCount'),
    );
  }
}

class FactoryUpgradeQuote {
  final String factoryId;
  final int currentLevel;
  final int nextLevel;
  final int goldCost;
  final String requiredItemId;
  final String requiredItemName;
  final int requiredItemQuantity;
  final int outputQuantityAfterUpgrade;
  final bool canUpgrade;

  FactoryUpgradeQuote({
    required this.factoryId,
    required this.currentLevel,
    required this.nextLevel,
    required this.goldCost,
    required this.requiredItemId,
    required this.requiredItemName,
    required this.requiredItemQuantity,
    required this.outputQuantityAfterUpgrade,
    required this.canUpgrade,
  });

  factory FactoryUpgradeQuote.fromJson(Map<String, dynamic> json) {
    return FactoryUpgradeQuote(
      factoryId: _requiredString(json, 'factoryId'),
      currentLevel: _requiredInt(json, 'currentLevel'),
      nextLevel: _requiredInt(json, 'nextLevel'),
      goldCost: _requiredInt(json, 'goldCost'),
      requiredItemId: _requiredString(json, 'requiredItemId'),
      requiredItemName: _requiredString(json, 'requiredItemName'),
      requiredItemQuantity: _requiredInt(json, 'requiredItemQuantity'),
      outputQuantityAfterUpgrade:
          _requiredInt(json, 'outputQuantityAfterUpgrade'),
      canUpgrade: _requiredBool(json, 'canUpgrade'),
    );
  }
}

class FactoryUpgradeResult {
  final bool upgraded;
  final String factoryId;
  final String message;
  final PlayerFactory factory;
  final FactoryUpgradeQuote appliedQuote;
  final DateTime upgradedAt;

  FactoryUpgradeResult({
    required this.upgraded,
    required this.factoryId,
    required this.message,
    required this.factory,
    required this.appliedQuote,
    required this.upgradedAt,
  });

  factory FactoryUpgradeResult.fromJson(Map<String, dynamic> json) {
    return FactoryUpgradeResult(
      upgraded: _requiredBool(json, 'upgraded'),
      factoryId: _requiredString(json, 'factoryId'),
      message: _requiredString(json, 'message'),
      factory: PlayerFactory.fromJson(_requiredMap(json['factory'])),
      appliedQuote:
          FactoryUpgradeQuote.fromJson(_requiredMap(json['appliedQuote'])),
      upgradedAt: _requiredDateTime(json, 'upgradedAt'),
    );
  }
}

class FactoryUpgradeGatewayResult {
  final bool completed;
  final String message;
  final FactoryUpgradeResult upgrade;
  final InventorySummary inventory;

  FactoryUpgradeGatewayResult({
    required this.completed,
    required this.message,
    required this.upgrade,
    required this.inventory,
  });

  factory FactoryUpgradeGatewayResult.fromJson(Map<String, dynamic> json) {
    return FactoryUpgradeGatewayResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      upgrade: FactoryUpgradeResult.fromJson(_requiredMap(json['upgrade'])),
      inventory: InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class ResearchDashboard {
  final String playerId;
  final PlayerCitizenship? citizenship;
  final ResearchScopeState? country;
  final List<ResearchCompanyScopeSummary> companies;
  final DateTime updatedAt;

  ResearchDashboard({
    required this.playerId,
    required this.citizenship,
    required this.country,
    required this.companies,
    required this.updatedAt,
  });

  factory ResearchDashboard.fromJson(Map<String, dynamic> json) {
    return ResearchDashboard(
      playerId: _requiredString(json, 'playerId'),
      citizenship: json['citizenship'] == null
          ? null
          : PlayerCitizenship.fromJson(_requiredMap(json['citizenship'])),
      country: json['country'] == null
          ? null
          : ResearchScopeState.fromJson(_requiredMap(json['country'])),
      companies: _requiredList(json, 'companies')
          .map((company) =>
              ResearchCompanyScopeSummary.fromJson(_requiredMap(company)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResearchCompanyScopeSummary {
  final String companyId;
  final String name;
  final String? role;
  final bool canManageResearch;

  ResearchCompanyScopeSummary({
    required this.companyId,
    required this.name,
    required this.role,
    required this.canManageResearch,
  });

  factory ResearchCompanyScopeSummary.fromJson(Map<String, dynamic> json) {
    return ResearchCompanyScopeSummary(
      companyId: _requiredString(json, 'companyId'),
      name: _requiredString(json, 'name'),
      role: _optionalNullableString(json, 'role'),
      canManageResearch: _requiredBool(json, 'canManageResearch'),
    );
  }
}

class ResearchTechnologyCatalog {
  final String? scopeType;
  final List<ResearchTechnology> technologies;
  final DateTime updatedAt;

  ResearchTechnologyCatalog({
    required this.scopeType,
    required this.technologies,
    required this.updatedAt,
  });

  factory ResearchTechnologyCatalog.fromJson(Map<String, dynamic> json) {
    return ResearchTechnologyCatalog(
      scopeType: _optionalNullableString(json, 'scopeType'),
      technologies: _requiredList(json, 'technologies')
          .map((technology) =>
              ResearchTechnology.fromJson(_requiredMap(technology)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResearchScopeState {
  final String scopeType;
  final String scopeId;
  final String actorPlayerId;
  final int availablePoints;
  final int lifetimePoints;
  final int pointCap;
  final int hourlyPointRate;
  final DateTime lastAccruedAt;
  final List<ResearchTechnologyNode> technologies;
  final List<ResearchProject> activeProjects;
  final List<String> completedTechnologyIds;
  final List<ResearchBonus> bonuses;
  final DateTime updatedAt;

  ResearchScopeState({
    required this.scopeType,
    required this.scopeId,
    required this.actorPlayerId,
    required this.availablePoints,
    required this.lifetimePoints,
    required this.pointCap,
    required this.hourlyPointRate,
    required this.lastAccruedAt,
    required this.technologies,
    required this.activeProjects,
    required this.completedTechnologyIds,
    required this.bonuses,
    required this.updatedAt,
  });

  bool get hasProductionSpeedBonus => bonuses.any((bonus) =>
      bonus.bonusType == 'production_speed_percent' && bonus.totalValue > 0);

  int get productionSpeedBonusPercent => bonuses
      .where((bonus) => bonus.bonusType == 'production_speed_percent')
      .fold<int>(0, (sum, bonus) => sum + bonus.totalValue);

  factory ResearchScopeState.fromJson(Map<String, dynamic> json) {
    return ResearchScopeState(
      scopeType: _requiredString(json, 'scopeType'),
      scopeId: _requiredString(json, 'scopeId'),
      actorPlayerId: _requiredString(json, 'actorPlayerId'),
      availablePoints: _requiredInt(json, 'availablePoints'),
      lifetimePoints: _requiredInt(json, 'lifetimePoints'),
      pointCap: _requiredInt(json, 'pointCap'),
      hourlyPointRate: _requiredInt(json, 'hourlyPointRate'),
      lastAccruedAt: _requiredDateTime(json, 'lastAccruedAt'),
      technologies: _requiredList(json, 'technologies')
          .map((technology) =>
              ResearchTechnologyNode.fromJson(_requiredMap(technology)))
          .toList(),
      activeProjects: _requiredList(json, 'activeProjects')
          .map((project) => ResearchProject.fromJson(_requiredMap(project)))
          .toList(),
      completedTechnologyIds:
          _requiredList(json, 'completedTechnologyIds').map((id) {
        return id.toString();
      }).toList(),
      bonuses: _requiredList(json, 'bonuses')
          .map((bonus) => ResearchBonus.fromJson(_requiredMap(bonus)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResearchTechnologyNode {
  final ResearchTechnology technology;
  final String status;
  final bool isCompleted;
  final bool canStart;
  final String? blockedReason;
  final ResearchProject? project;

  ResearchTechnologyNode({
    required this.technology,
    required this.status,
    required this.isCompleted,
    required this.canStart,
    required this.blockedReason,
    required this.project,
  });

  bool get isActive => status == 'active' || status == 'ready';
  bool get isReady => status == 'ready' || (project?.canComplete ?? false);
  bool get isLocked => status == 'locked';

  factory ResearchTechnologyNode.fromJson(Map<String, dynamic> json) {
    return ResearchTechnologyNode(
      technology: ResearchTechnology.fromJson(_requiredMap(json['technology'])),
      status: _requiredString(json, 'status'),
      isCompleted: _requiredBool(json, 'isCompleted'),
      canStart: _requiredBool(json, 'canStart'),
      blockedReason: _optionalNullableString(json, 'blockedReason'),
      project: json['project'] == null
          ? null
          : ResearchProject.fromJson(_requiredMap(json['project'])),
    );
  }
}

class ResearchTechnology {
  final String technologyId;
  final String scopeType;
  final String track;
  final String name;
  final String description;
  final int tier;
  final List<String> prerequisiteTechnologyIds;
  final int requiredPoints;
  final int durationSeconds;
  final ResearchTechnologyBonus bonus;
  final DateTime updatedAt;

  ResearchTechnology({
    required this.technologyId,
    required this.scopeType,
    required this.track,
    required this.name,
    required this.description,
    required this.tier,
    required this.prerequisiteTechnologyIds,
    required this.requiredPoints,
    required this.durationSeconds,
    required this.bonus,
    required this.updatedAt,
  });

  factory ResearchTechnology.fromJson(Map<String, dynamic> json) {
    return ResearchTechnology(
      technologyId: _requiredString(json, 'technologyId'),
      scopeType: _requiredString(json, 'scopeType'),
      track: _requiredString(json, 'track'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      tier: _requiredInt(json, 'tier'),
      prerequisiteTechnologyIds:
          _requiredList(json, 'prerequisiteTechnologyIds').map((id) {
        return id.toString();
      }).toList(),
      requiredPoints: _requiredInt(json, 'requiredPoints'),
      durationSeconds: _requiredInt(json, 'durationSeconds'),
      bonus: ResearchTechnologyBonus.fromJson(_requiredMap(json['bonus'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResearchTechnologyBonus {
  final String bonusType;
  final int bonusValue;
  final String bonusTarget;
  final String description;

  ResearchTechnologyBonus({
    required this.bonusType,
    required this.bonusValue,
    required this.bonusTarget,
    required this.description,
  });

  factory ResearchTechnologyBonus.fromJson(Map<String, dynamic> json) {
    return ResearchTechnologyBonus(
      bonusType: _requiredString(json, 'bonusType'),
      bonusValue: _requiredInt(json, 'bonusValue'),
      bonusTarget: _requiredString(json, 'bonusTarget'),
      description: _requiredString(json, 'description'),
    );
  }
}

class ResearchProject {
  final String projectId;
  final String scopeType;
  final String scopeId;
  final String technologyId;
  final String status;
  final int requiredPoints;
  final int contributedPoints;
  final int remainingPoints;
  final int progressPercent;
  final int durationSeconds;
  final DateTime startedAt;
  final DateTime readyAt;
  final DateTime? completedAt;
  final bool canComplete;
  final DateTime updatedAt;

  ResearchProject({
    required this.projectId,
    required this.scopeType,
    required this.scopeId,
    required this.technologyId,
    required this.status,
    required this.requiredPoints,
    required this.contributedPoints,
    required this.remainingPoints,
    required this.progressPercent,
    required this.durationSeconds,
    required this.startedAt,
    required this.readyAt,
    required this.completedAt,
    required this.canComplete,
    required this.updatedAt,
  });

  double get progress => (progressPercent / 100).clamp(0, 1).toDouble();

  factory ResearchProject.fromJson(Map<String, dynamic> json) {
    return ResearchProject(
      projectId: _requiredString(json, 'projectId'),
      scopeType: _requiredString(json, 'scopeType'),
      scopeId: _requiredString(json, 'scopeId'),
      technologyId: _requiredString(json, 'technologyId'),
      status: _requiredString(json, 'status'),
      requiredPoints: _requiredInt(json, 'requiredPoints'),
      contributedPoints: _requiredInt(json, 'contributedPoints'),
      remainingPoints: _requiredInt(json, 'remainingPoints'),
      progressPercent: _requiredInt(json, 'progressPercent'),
      durationSeconds: _requiredInt(json, 'durationSeconds'),
      startedAt: _requiredDateTime(json, 'startedAt'),
      readyAt: _requiredDateTime(json, 'readyAt'),
      completedAt: _optionalDateTime(json, 'completedAt'),
      canComplete: _requiredBool(json, 'canComplete'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResearchBonus {
  final String bonusType;
  final String bonusTarget;
  final int totalValue;
  final List<String> sourceTechnologyIds;
  final String description;
  final DateTime updatedAt;

  ResearchBonus({
    required this.bonusType,
    required this.bonusTarget,
    required this.totalValue,
    required this.sourceTechnologyIds,
    required this.description,
    required this.updatedAt,
  });

  factory ResearchBonus.fromJson(Map<String, dynamic> json) {
    return ResearchBonus(
      bonusType: _requiredString(json, 'bonusType'),
      bonusTarget: _requiredString(json, 'bonusTarget'),
      totalValue: _requiredInt(json, 'totalValue'),
      sourceTechnologyIds: _requiredList(json, 'sourceTechnologyIds').map((id) {
        return id.toString();
      }).toList(),
      description: _requiredString(json, 'description'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResearchBonusList {
  final String scopeType;
  final String scopeId;
  final List<ResearchBonus> bonuses;
  final DateTime updatedAt;

  ResearchBonusList({
    required this.scopeType,
    required this.scopeId,
    required this.bonuses,
    required this.updatedAt,
  });

  factory ResearchBonusList.fromJson(Map<String, dynamic> json) {
    return ResearchBonusList(
      scopeType: _requiredString(json, 'scopeType'),
      scopeId: _requiredString(json, 'scopeId'),
      bonuses: _requiredList(json, 'bonuses')
          .map((bonus) => ResearchBonus.fromJson(_requiredMap(bonus)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ResearchMutationResult {
  final bool completed;
  final String message;
  final ResearchProject? project;
  final ResearchScopeState? state;
  final List<ResearchBonus> activeBonuses;
  final DateTime updatedAt;

  ResearchMutationResult({
    required this.completed,
    required this.message,
    required this.project,
    required this.state,
    required this.activeBonuses,
    required this.updatedAt,
  });

  factory ResearchMutationResult.fromJson(Map<String, dynamic> json) {
    return ResearchMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      project: json['project'] == null
          ? null
          : ResearchProject.fromJson(_requiredMap(json['project'])),
      state: json['state'] == null
          ? null
          : ResearchScopeState.fromJson(_requiredMap(json['state'])),
      activeBonuses: _requiredList(json, 'activeBonuses')
          .map((bonus) => ResearchBonus.fromJson(_requiredMap(bonus)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MarketListings {
  final List<MarketListing> listings;
  final DateTime updatedAt;

  MarketListings({
    required this.listings,
    required this.updatedAt,
  });

  factory MarketListings.fromJson(Map<String, dynamic> json) {
    final listings = _requiredList(json, 'listings')
        .map((listing) => MarketListing.fromJson(_requiredMap(listing)))
        .toList();
    return MarketListings(
      listings: listings,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PlayerMarketListings {
  final String sellerId;
  final List<MarketListing> listings;
  final DateTime updatedAt;

  PlayerMarketListings({
    required this.sellerId,
    required this.listings,
    required this.updatedAt,
  });

  factory PlayerMarketListings.fromJson(Map<String, dynamic> json) {
    final listings = _requiredList(json, 'listings')
        .map((listing) => MarketListing.fromJson(_requiredMap(listing)))
        .toList();
    return PlayerMarketListings(
      sellerId: _requiredString(json, 'sellerId'),
      listings: listings,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MarketListing {
  final String listingId;
  final String itemId;
  final String itemName;
  final String category;
  final int quantity;
  final int pricePerUnit;
  final String sellerId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MarketListing({
    required this.listingId,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.pricePerUnit,
    required this.sellerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketListing.fromJson(Map<String, dynamic> json) {
    return MarketListing(
      listingId: _requiredString(json, 'listingId'),
      itemId: _requiredString(json, 'itemId'),
      itemName: _requiredString(json, 'itemName'),
      category: _requiredString(json, 'category'),
      quantity: _requiredInt(json, 'quantity'),
      pricePerUnit: _requiredInt(json, 'pricePerUnit'),
      sellerId: _requiredString(json, 'sellerId'),
      status: _optionalString(json, 'status', defaultValue: 'open'),
      createdAt: _optionalDateTime(json, 'createdAt'),
      updatedAt: _optionalDateTime(json, 'updatedAt'),
    );
  }
}

class MarketPurchaseResult {
  final bool completed;
  final String message;
  final String listingId;
  final int quantity;
  final int totalPrice;
  final String sellerId;
  final int buyerTaxAmount;
  final int sellerTaxAmount;
  final int buyerTotal;
  final int sellerNet;
  final List<CountryTaxCollection> taxCollections;
  final InventorySummary inventory;

  MarketPurchaseResult({
    required this.completed,
    required this.message,
    required this.listingId,
    required this.quantity,
    required this.totalPrice,
    required this.sellerId,
    required this.buyerTaxAmount,
    required this.sellerTaxAmount,
    required this.buyerTotal,
    required this.sellerNet,
    required this.taxCollections,
    required this.inventory,
  });

  factory MarketPurchaseResult.fromJson(Map<String, dynamic> json) {
    return MarketPurchaseResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      listingId: _requiredString(json, 'listingId'),
      quantity: _requiredInt(json, 'quantity'),
      totalPrice: _requiredInt(json, 'totalPrice'),
      sellerId: _optionalString(json, 'sellerId', defaultValue: ''),
      buyerTaxAmount: _optionalInt(json, 'buyerTaxAmount'),
      sellerTaxAmount: _optionalInt(json, 'sellerTaxAmount'),
      buyerTotal: _optionalInt(json, 'buyerTotal'),
      sellerNet: _optionalInt(json, 'sellerNet'),
      taxCollections: json['taxCollections'] is List<dynamic>
          ? (json['taxCollections'] as List<dynamic>)
              .map(
                  (entry) => CountryTaxCollection.fromJson(_requiredMap(entry)))
              .toList()
          : <CountryTaxCollection>[],
      inventory: InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class MarketSellListingResult {
  final bool completed;
  final String message;
  final MarketListing listing;
  final InventorySummary inventory;

  MarketSellListingResult({
    required this.completed,
    required this.message,
    required this.listing,
    required this.inventory,
  });

  factory MarketSellListingResult.fromJson(Map<String, dynamic> json) {
    return MarketSellListingResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      listing: MarketListing.fromJson(_requiredMap(json['listing'])),
      inventory: InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class MarketCancelListingResult {
  final bool completed;
  final String message;
  final MarketListing listing;
  final InventorySummary? inventory;

  MarketCancelListingResult({
    required this.completed,
    required this.message,
    required this.listing,
    required this.inventory,
  });

  factory MarketCancelListingResult.fromJson(Map<String, dynamic> json) {
    return MarketCancelListingResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      listing: MarketListing.fromJson(_requiredMap(json['listing'])),
      inventory: json['inventory'] == null
          ? null
          : InventorySummary.fromJson(_requiredMap(json['inventory'])),
    );
  }
}

class MarketPriceHistory {
  final String? itemId;
  final List<MarketPricePoint> entries;
  final DateTime updatedAt;

  MarketPriceHistory({
    required this.itemId,
    required this.entries,
    required this.updatedAt,
  });

  factory MarketPriceHistory.fromJson(Map<String, dynamic> json) {
    final entries = _requiredList(json, 'entries')
        .map((entry) => MarketPricePoint.fromJson(_requiredMap(entry)))
        .toList();
    return MarketPriceHistory(
      itemId: _optionalNullableString(json, 'itemId'),
      entries: entries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MarketPricePoint {
  final String priceHistoryId;
  final String itemId;
  final String itemName;
  final String category;
  final int qualityTier;
  final int quantity;
  final int pricePerUnit;
  final String sellerType;
  final String sellerId;
  final String buyerType;
  final String buyerId;
  final String sourceType;
  final String sourceId;
  final DateTime tradedAt;

  MarketPricePoint({
    required this.priceHistoryId,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.qualityTier,
    required this.quantity,
    required this.pricePerUnit,
    required this.sellerType,
    required this.sellerId,
    required this.buyerType,
    required this.buyerId,
    required this.sourceType,
    required this.sourceId,
    required this.tradedAt,
  });

  int get totalPrice => quantity * pricePerUnit;

  factory MarketPricePoint.fromJson(Map<String, dynamic> json) {
    return MarketPricePoint(
      priceHistoryId: _requiredString(json, 'priceHistoryId'),
      itemId: _requiredString(json, 'itemId'),
      itemName: _requiredString(json, 'itemName'),
      category: _requiredString(json, 'category'),
      qualityTier: _optionalInt(json, 'qualityTier') == 0
          ? 1
          : _optionalInt(json, 'qualityTier'),
      quantity: _requiredInt(json, 'quantity'),
      pricePerUnit: _requiredInt(json, 'pricePerUnit'),
      sellerType: _requiredString(json, 'sellerType'),
      sellerId: _requiredString(json, 'sellerId'),
      buyerType: _requiredString(json, 'buyerType'),
      buyerId: _requiredString(json, 'buyerId'),
      sourceType: _requiredString(json, 'sourceType'),
      sourceId: _requiredString(json, 'sourceId'),
      tradedAt: _requiredDateTime(json, 'tradedAt'),
    );
  }
}

class MarketOrderBook {
  final String? itemId;
  final List<MarketOrderBookEntry> entries;
  final DateTime updatedAt;

  MarketOrderBook({
    required this.itemId,
    required this.entries,
    required this.updatedAt,
  });

  factory MarketOrderBook.fromJson(Map<String, dynamic> json) {
    final entries = _requiredList(json, 'entries')
        .map((entry) => MarketOrderBookEntry.fromJson(_requiredMap(entry)))
        .toList();
    return MarketOrderBook(
      itemId: _optionalNullableString(json, 'itemId'),
      entries: entries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MarketOrderBookEntry {
  final String itemId;
  final String itemName;
  final String category;
  final int qualityTier;
  final int pricePerUnit;
  final int quantity;
  final int orderCount;

  MarketOrderBookEntry({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.qualityTier,
    required this.pricePerUnit,
    required this.quantity,
    required this.orderCount,
  });

  factory MarketOrderBookEntry.fromJson(Map<String, dynamic> json) {
    return MarketOrderBookEntry(
      itemId: _requiredString(json, 'itemId'),
      itemName: _requiredString(json, 'itemName'),
      category: _requiredString(json, 'category'),
      qualityTier: _optionalInt(json, 'qualityTier') == 0
          ? 1
          : _optionalInt(json, 'qualityTier'),
      pricePerUnit: _requiredInt(json, 'pricePerUnit'),
      quantity: _requiredInt(json, 'quantity'),
      orderCount: _requiredInt(json, 'orderCount'),
    );
  }
}

class TradeOfferList {
  final List<TradeOffer> offers;
  final DateTime updatedAt;

  TradeOfferList({
    required this.offers,
    required this.updatedAt,
  });

  factory TradeOfferList.fromJson(Map<String, dynamic> json) {
    final offers = _requiredList(json, 'offers')
        .map((offer) => TradeOffer.fromJson(_requiredMap(offer)))
        .toList();
    return TradeOfferList(
      offers: offers,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class TradeOffer {
  final String offerId;
  final String creatorPlayerId;
  final String sellerType;
  final String sellerId;
  final String buyerType;
  final String buyerId;
  final String itemId;
  final String itemName;
  final String category;
  final int qualityTier;
  final int quantity;
  final int pricePerUnit;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? respondedAt;

  TradeOffer({
    required this.offerId,
    required this.creatorPlayerId,
    required this.sellerType,
    required this.sellerId,
    required this.buyerType,
    required this.buyerId,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.qualityTier,
    required this.quantity,
    required this.pricePerUnit,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.respondedAt,
  });

  int get totalPrice => quantity * pricePerUnit;

  factory TradeOffer.fromJson(Map<String, dynamic> json) {
    return TradeOffer(
      offerId: _requiredString(json, 'offerId'),
      creatorPlayerId: _requiredString(json, 'creatorPlayerId'),
      sellerType: _requiredString(json, 'sellerType'),
      sellerId: _requiredString(json, 'sellerId'),
      buyerType: _requiredString(json, 'buyerType'),
      buyerId: _requiredString(json, 'buyerId'),
      itemId: _requiredString(json, 'itemId'),
      itemName: _requiredString(json, 'itemName'),
      category: _requiredString(json, 'category'),
      qualityTier: _optionalInt(json, 'qualityTier') == 0
          ? 1
          : _optionalInt(json, 'qualityTier'),
      quantity: _requiredInt(json, 'quantity'),
      pricePerUnit: _requiredInt(json, 'pricePerUnit'),
      status: _requiredString(json, 'status'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      respondedAt: _optionalDateTime(json, 'respondedAt'),
    );
  }
}

class TradeContract {
  final String contractId;
  final String offerId;
  final String acceptedByPlayerId;
  final String status;
  final String failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? fulfilledAt;

  TradeContract({
    required this.contractId,
    required this.offerId,
    required this.acceptedByPlayerId,
    required this.status,
    required this.failureReason,
    required this.createdAt,
    required this.updatedAt,
    required this.fulfilledAt,
  });

  factory TradeContract.fromJson(Map<String, dynamic> json) {
    return TradeContract(
      contractId: _requiredString(json, 'contractId'),
      offerId: _requiredString(json, 'offerId'),
      acceptedByPlayerId: _requiredString(json, 'acceptedByPlayerId'),
      status: _requiredString(json, 'status'),
      failureReason: _optionalString(json, 'failureReason', defaultValue: ''),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      fulfilledAt: _optionalDateTime(json, 'fulfilledAt'),
    );
  }
}

class TradeOfferResult {
  final bool completed;
  final String message;
  final TradeOffer? offer;
  final TradeContract? contract;
  final int totalPrice;

  TradeOfferResult({
    required this.completed,
    required this.message,
    required this.offer,
    required this.contract,
    required this.totalPrice,
  });

  factory TradeOfferResult.fromJson(Map<String, dynamic> json) {
    return TradeOfferResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      offer: json['offer'] == null
          ? null
          : TradeOffer.fromJson(_requiredMap(json['offer'])),
      contract: json['contract'] == null
          ? null
          : TradeContract.fromJson(_requiredMap(json['contract'])),
      totalPrice: _optionalInt(json, 'totalPrice'),
    );
  }
}

class CombatMission {
  final String missionId;
  final String name;
  final String description;
  final FighterStats defender;
  final int rounds;
  final int rewardExperience;
  final int rewardGold;

  CombatMission({
    required this.missionId,
    required this.name,
    required this.description,
    required this.defender,
    required this.rounds,
    required this.rewardExperience,
    required this.rewardGold,
  });

  factory CombatMission.fromJson(Map<String, dynamic> json) {
    return CombatMission(
      missionId:
          _requiredString(json, 'missionId', fallbackField: 'mission_id'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      defender: FighterStats.fromJson(_requiredMap(json['defender'])),
      rounds: _requiredInt(json, 'rounds'),
      rewardExperience: _requiredInt(json, 'rewardExperience',
          fallbackField: 'reward_experience'),
      rewardGold:
          _requiredInt(json, 'rewardGold', fallbackField: 'reward_gold'),
    );
  }
}

class MissionProgressSummary {
  final String playerId;
  final List<MissionProgress> missions;
  final DateTime updatedAt;

  MissionProgressSummary({
    required this.playerId,
    required this.missions,
    required this.updatedAt,
  });

  MissionProgress? forMission(String missionId) {
    for (final mission in missions) {
      if (mission.missionId == missionId) {
        return mission;
      }
    }

    return null;
  }

  factory MissionProgressSummary.fromJson(Map<String, dynamic> json) {
    final missions = _requiredList(json, 'missions')
        .map((mission) => MissionProgress.fromJson(_requiredMap(mission)))
        .toList();
    return MissionProgressSummary(
      playerId: _requiredString(json, 'playerId'),
      missions: missions,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MissionProgress {
  final String missionId;
  final int attempts;
  final int wins;
  final int losses;
  final int totalRounds;
  final bool lastWon;
  final String lastResult;
  final DateTime? lastAttemptedAt;
  final DateTime? cooldownUntil;
  final DateTime updatedAt;

  MissionProgress({
    required this.missionId,
    required this.attempts,
    required this.wins,
    required this.losses,
    required this.totalRounds,
    required this.lastWon,
    required this.lastResult,
    required this.lastAttemptedAt,
    required this.cooldownUntil,
    required this.updatedAt,
  });

  bool get isOnCooldown {
    final cooldown = cooldownUntil;
    return cooldown != null && cooldown.isAfter(DateTime.now().toUtc());
  }

  factory MissionProgress.fromJson(Map<String, dynamic> json) {
    return MissionProgress(
      missionId: _requiredString(json, 'missionId'),
      attempts: _requiredInt(json, 'attempts'),
      wins: _requiredInt(json, 'wins'),
      losses: _requiredInt(json, 'losses'),
      totalRounds: _requiredInt(json, 'totalRounds'),
      lastWon: _requiredBool(json, 'lastWon'),
      lastResult: _requiredString(json, 'lastResult'),
      lastAttemptedAt: _optionalDateTime(json, 'lastAttemptedAt'),
      cooldownUntil: _optionalDateTime(json, 'cooldownUntil'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class FighterStats {
  final int strength;
  final int energy;
  final int weaponPower;

  FighterStats({
    required this.strength,
    required this.energy,
    required this.weaponPower,
  });

  factory FighterStats.fromJson(Map<String, dynamic> json) {
    return FighterStats(
      strength: _requiredInt(json, 'strength'),
      energy: _requiredInt(json, 'energy'),
      weaponPower:
          _requiredInt(json, 'weaponPower', fallbackField: 'weapon_power'),
    );
  }
}

class MissionFightResult {
  final CombatMission mission;
  final FightResult fight;
  final MissionProgress? missionProgress;
  final EquipmentSummary equipment;
  final WeaponDamageResult? weaponDamage;
  final String message;

  MissionFightResult({
    required this.mission,
    required this.fight,
    required this.missionProgress,
    required this.equipment,
    required this.weaponDamage,
    required this.message,
  });

  factory MissionFightResult.fromJson(Map<String, dynamic> json) {
    return MissionFightResult(
      mission: CombatMission.fromJson(_requiredMap(json['mission'])),
      fight: FightResult.fromJson(_requiredMap(json['fight'])),
      missionProgress: json['missionProgress'] == null
          ? null
          : MissionProgress.fromJson(_requiredMap(json['missionProgress'])),
      equipment: EquipmentSummary.fromJson(_requiredMap(json['equipment'])),
      weaponDamage: json['weaponDamage'] == null
          ? null
          : WeaponDamageResult.fromJson(_requiredMap(json['weaponDamage'])),
      message: _requiredString(json, 'message'),
    );
  }
}

class FightResult {
  final String winner;
  final int roundsRequested;
  final int roundsCompleted;
  final int attackerDamage;
  final int defenderDamage;
  final int attackerRemainingEnergy;
  final int defenderRemainingEnergy;

  FightResult({
    required this.winner,
    required this.roundsRequested,
    required this.roundsCompleted,
    required this.attackerDamage,
    required this.defenderDamage,
    required this.attackerRemainingEnergy,
    required this.defenderRemainingEnergy,
  });

  factory FightResult.fromJson(Map<String, dynamic> json) {
    return FightResult(
      winner: _requiredString(json, 'winner'),
      roundsRequested: _requiredInt(json, 'roundsRequested',
          fallbackField: 'rounds_requested'),
      roundsCompleted: _requiredInt(json, 'roundsCompleted',
          fallbackField: 'rounds_completed'),
      attackerDamage: _requiredInt(json, 'attackerDamage',
          fallbackField: 'attacker_damage'),
      defenderDamage: _requiredInt(json, 'defenderDamage',
          fallbackField: 'defender_damage'),
      attackerRemainingEnergy: _requiredInt(json, 'attackerRemainingEnergy',
          fallbackField: 'attacker_remaining_energy'),
      defenderRemainingEnergy: _requiredInt(json, 'defenderRemainingEnergy',
          fallbackField: 'defender_remaining_energy'),
    );
  }
}

class CountryCatalog {
  final List<WorldCountry> countries;
  final DateTime updatedAt;

  CountryCatalog({
    required this.countries,
    required this.updatedAt,
  });

  factory CountryCatalog.fromJson(Map<String, dynamic> json) {
    final countries = _requiredList(json, 'countries')
        .map((country) => WorldCountry.fromJson(_requiredMap(country)))
        .toList();
    return CountryCatalog(
      countries: countries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RegionList {
  final List<WorldRegion> regions;
  final DateTime updatedAt;

  RegionList({
    required this.regions,
    required this.updatedAt,
  });

  factory RegionList.fromJson(Map<String, dynamic> json) {
    final regions = _requiredList(json, 'regions')
        .map((region) => WorldRegion.fromJson(_requiredMap(region)))
        .toList();
    return RegionList(
      regions: regions,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class WorldCountry {
  final String countryId;
  final String name;
  final String code;
  final String description;
  final String government;
  final int treasury;
  final int taxRate;
  final int regionCount;
  final int citizenCount;
  final DateTime updatedAt;
  final List<WorldRegion> regions;
  final CountryTaxPolicy? taxPolicy;

  WorldCountry({
    required this.countryId,
    required this.name,
    required this.code,
    required this.description,
    required this.government,
    required this.treasury,
    required this.taxRate,
    required this.regionCount,
    required this.citizenCount,
    required this.updatedAt,
    required this.regions,
    required this.taxPolicy,
  });

  factory WorldCountry.fromJson(Map<String, dynamic> json) {
    final regionValues = json['regions'];
    final regions = regionValues is List<dynamic>
        ? regionValues
            .map((region) => WorldRegion.fromJson(_requiredMap(region)))
            .toList()
        : <WorldRegion>[];
    return WorldCountry(
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      name: _requiredString(json, 'name'),
      code: _requiredString(json, 'code'),
      description: _requiredString(json, 'description'),
      government: _requiredString(json, 'government'),
      treasury: _requiredInt(json, 'treasury'),
      taxRate: _requiredInt(json, 'taxRate', fallbackField: 'tax_rate'),
      regionCount: json.containsKey('regionCount')
          ? _optionalInt(json, 'regionCount')
          : regions.length,
      citizenCount: _optionalInt(json, 'citizenCount'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      regions: regions,
      taxPolicy: json['taxPolicy'] == null
          ? null
          : CountryTaxPolicy.fromJson(_requiredMap(json['taxPolicy'])),
    );
  }
}

class CountryTreasury {
  final String countryId;
  final String name;
  final String code;
  final int treasury;
  final CountryTaxPolicy policy;
  final List<CountryTreasuryLedgerEntry> recentLedger;
  final CountryTaxPolicyAuthorization authorization;
  final DateTime updatedAt;

  CountryTreasury({
    required this.countryId,
    required this.name,
    required this.code,
    required this.treasury,
    required this.policy,
    required this.recentLedger,
    required this.authorization,
    required this.updatedAt,
  });

  int get recentTaxCollected =>
      recentLedger.fold(0, (total, entry) => total + entry.goldDelta);

  factory CountryTreasury.fromJson(Map<String, dynamic> json) {
    final ledger = _requiredList(json, 'recentLedger')
        .map(
            (entry) => CountryTreasuryLedgerEntry.fromJson(_requiredMap(entry)))
        .toList();
    return CountryTreasury(
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      name: _requiredString(json, 'name'),
      code: _requiredString(json, 'code'),
      treasury: _requiredInt(json, 'treasury'),
      policy: CountryTaxPolicy.fromJson(_requiredMap(json['policy'])),
      recentLedger: ledger,
      authorization: CountryTaxPolicyAuthorization.fromJson(
          _requiredMap(json['authorization'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CountryTaxPolicy {
  final String countryId;
  final int incomeTaxRate;
  final int marketTaxRate;
  final int productionTaxRate;
  final String updatedByPlayerId;
  final DateTime updatedAt;

  CountryTaxPolicy({
    required this.countryId,
    required this.incomeTaxRate,
    required this.marketTaxRate,
    required this.productionTaxRate,
    required this.updatedByPlayerId,
    required this.updatedAt,
  });

  factory CountryTaxPolicy.fromJson(Map<String, dynamic> json) {
    return CountryTaxPolicy(
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      incomeTaxRate:
          _requiredInt(json, 'incomeTaxRate', fallbackField: 'income_tax_rate'),
      marketTaxRate:
          _requiredInt(json, 'marketTaxRate', fallbackField: 'market_tax_rate'),
      productionTaxRate: _requiredInt(json, 'productionTaxRate',
          fallbackField: 'production_tax_rate'),
      updatedByPlayerId: _optionalString(json, 'updatedByPlayerId',
          defaultValue: _optionalString(json, 'updated_by_player_id',
              defaultValue: 'system')),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class CountryTaxPolicyAuthorization {
  final bool canUpdatePolicy;
  final String? role;
  final String message;

  CountryTaxPolicyAuthorization({
    required this.canUpdatePolicy,
    required this.role,
    required this.message,
  });

  factory CountryTaxPolicyAuthorization.fromJson(Map<String, dynamic> json) {
    return CountryTaxPolicyAuthorization(
      canUpdatePolicy: _requiredBool(json, 'canUpdatePolicy'),
      role: _optionalNullableString(json, 'role'),
      message: _requiredString(json, 'message'),
    );
  }
}

class CountryTreasuryLedgerEntry {
  final String ledgerId;
  final String countryId;
  final String entryType;
  final String sourcePlayerId;
  final String counterpartyPlayerId;
  final int goldDelta;
  final int grossAmount;
  final int taxRate;
  final String description;
  final DateTime createdAt;

  CountryTreasuryLedgerEntry({
    required this.ledgerId,
    required this.countryId,
    required this.entryType,
    required this.sourcePlayerId,
    required this.counterpartyPlayerId,
    required this.goldDelta,
    required this.grossAmount,
    required this.taxRate,
    required this.description,
    required this.createdAt,
  });

  factory CountryTreasuryLedgerEntry.fromJson(Map<String, dynamic> json) {
    return CountryTreasuryLedgerEntry(
      ledgerId: _requiredString(json, 'ledgerId', fallbackField: 'ledger_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      entryType:
          _requiredString(json, 'entryType', fallbackField: 'entry_type'),
      sourcePlayerId: _optionalString(json, 'sourcePlayerId',
          defaultValue:
              _optionalString(json, 'source_player_id', defaultValue: '')),
      counterpartyPlayerId: _optionalString(json, 'counterpartyPlayerId',
          defaultValue: _optionalString(json, 'counterparty_player_id',
              defaultValue: '')),
      goldDelta: _requiredInt(json, 'goldDelta', fallbackField: 'gold_delta'),
      grossAmount:
          _requiredInt(json, 'grossAmount', fallbackField: 'gross_amount'),
      taxRate: _requiredInt(json, 'taxRate', fallbackField: 'tax_rate'),
      description: _requiredString(json, 'description'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
    );
  }
}

class CountryTaxPolicyUpdateResult {
  final bool completed;
  final String message;
  final CountryTreasury? treasury;

  CountryTaxPolicyUpdateResult({
    required this.completed,
    required this.message,
    required this.treasury,
  });

  factory CountryTaxPolicyUpdateResult.fromJson(Map<String, dynamic> json) {
    return CountryTaxPolicyUpdateResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      treasury: json['treasury'] == null
          ? null
          : CountryTreasury.fromJson(_requiredMap(json['treasury'])),
    );
  }
}

class CountryTaxCollection {
  final bool completed;
  final String message;
  final String countryId;
  final int amount;
  final int treasury;
  final CountryTreasuryLedgerEntry? entry;
  final DateTime updatedAt;

  CountryTaxCollection({
    required this.completed,
    required this.message,
    required this.countryId,
    required this.amount,
    required this.treasury,
    required this.entry,
    required this.updatedAt,
  });

  factory CountryTaxCollection.fromJson(Map<String, dynamic> json) {
    return CountryTaxCollection(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      amount: _requiredInt(json, 'amount'),
      treasury: _requiredInt(json, 'treasury'),
      entry: json['entry'] == null
          ? null
          : CountryTreasuryLedgerEntry.fromJson(_requiredMap(json['entry'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class WorldRegion {
  final String regionId;
  final String countryId;
  final String name;
  final String terrain;
  final String resourceFocus;
  final int population;
  final int infrastructure;
  final bool isCapital;
  final DateTime updatedAt;

  WorldRegion({
    required this.regionId,
    required this.countryId,
    required this.name,
    required this.terrain,
    required this.resourceFocus,
    required this.population,
    required this.infrastructure,
    required this.isCapital,
    required this.updatedAt,
  });

  factory WorldRegion.fromJson(Map<String, dynamic> json) {
    return WorldRegion(
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      name: _requiredString(json, 'name'),
      terrain: _requiredString(json, 'terrain'),
      resourceFocus: _requiredString(json, 'resourceFocus',
          fallbackField: 'resource_focus'),
      population: _requiredInt(json, 'population'),
      infrastructure: _requiredInt(json, 'infrastructure'),
      isCapital: _requiredBool(json, 'isCapital'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class TerritoryMap {
  final List<TerritoryRegion> regions;
  final DateTime updatedAt;

  TerritoryMap({
    required this.regions,
    required this.updatedAt,
  });

  List<TerritoryRegion> get activeConflicts => regions
      .where((region) => region.activeConflict?.isActive == true)
      .toList();

  factory TerritoryMap.fromJson(Map<String, dynamic> json) {
    final regions = _requiredList(json, 'regions')
        .map((region) => TerritoryRegion.fromJson(_requiredMap(region)))
        .toList();
    return TerritoryMap(
      regions: regions,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class TerritoryRegion {
  final String regionId;
  final String name;
  final String terrain;
  final String resourceFocus;
  final int population;
  final int infrastructure;
  final bool isCapital;
  final String ownerCountryId;
  final String ownerCountryName;
  final String ownerCountryCode;
  final RegionResourceBonus bonus;
  final List<RegionResource> resources;
  final RegionDefenseSystem defense;
  final CountryBattle? activeConflict;
  final List<RegionControlHistory> recentHistory;
  final TerritoryAuthorization authorization;
  final DateTime updatedAt;

  TerritoryRegion({
    required this.regionId,
    required this.name,
    required this.terrain,
    required this.resourceFocus,
    required this.population,
    required this.infrastructure,
    required this.isCapital,
    required this.ownerCountryId,
    required this.ownerCountryName,
    required this.ownerCountryCode,
    required this.bonus,
    required this.resources,
    required this.defense,
    required this.activeConflict,
    required this.recentHistory,
    required this.authorization,
    required this.updatedAt,
  });

  bool get hasActiveConflict => activeConflict?.isActive == true;

  factory TerritoryRegion.fromJson(Map<String, dynamic> json) {
    final history = _requiredList(json, 'recentHistory')
        .map((entry) => RegionControlHistory.fromJson(_requiredMap(entry)))
        .toList();
    final resources = json['resources'] is List<dynamic>
        ? (json['resources'] as List<dynamic>)
            .map((resource) => RegionResource.fromJson(_requiredMap(resource)))
            .toList()
        : <RegionResource>[];
    return TerritoryRegion(
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      name: _requiredString(json, 'name'),
      terrain: _requiredString(json, 'terrain'),
      resourceFocus: _requiredString(json, 'resourceFocus',
          fallbackField: 'resource_focus'),
      population: _requiredInt(json, 'population'),
      infrastructure: _requiredInt(json, 'infrastructure'),
      isCapital: _requiredBool(json, 'isCapital'),
      ownerCountryId: _requiredString(json, 'ownerCountryId',
          fallbackField: 'owner_country_id'),
      ownerCountryName: _requiredString(json, 'ownerCountryName',
          fallbackField: 'owner_country_name'),
      ownerCountryCode: _requiredString(json, 'ownerCountryCode',
          fallbackField: 'owner_country_code'),
      bonus: RegionResourceBonus.fromJson(_requiredMap(json['bonus'])),
      resources: resources,
      defense: RegionDefenseSystem.fromJson(_requiredMap(json['defense'])),
      activeConflict: json['activeConflict'] == null
          ? null
          : CountryBattle.fromJson(_requiredMap(json['activeConflict'])),
      recentHistory: history,
      authorization:
          TerritoryAuthorization.fromJson(_requiredMap(json['authorization'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RegionResourceBonus {
  final String regionId;
  final String resourceType;
  final int productionBonusPercent;
  final int marketBonusPercent;
  final int defenseBonusPercent;
  final int hospitalCapacity;
  final int effectiveProductionBonusPercent;
  final int effectiveMarketBonusPercent;
  final DateTime updatedAt;

  RegionResourceBonus({
    required this.regionId,
    required this.resourceType,
    required this.productionBonusPercent,
    required this.marketBonusPercent,
    required this.defenseBonusPercent,
    required this.hospitalCapacity,
    required this.effectiveProductionBonusPercent,
    required this.effectiveMarketBonusPercent,
    required this.updatedAt,
  });

  factory RegionResourceBonus.fromJson(Map<String, dynamic> json) {
    return RegionResourceBonus(
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      resourceType:
          _requiredString(json, 'resourceType', fallbackField: 'resource_type'),
      productionBonusPercent: _requiredInt(json, 'productionBonusPercent',
          fallbackField: 'production_bonus_percent'),
      marketBonusPercent: _requiredInt(json, 'marketBonusPercent',
          fallbackField: 'market_bonus_percent'),
      defenseBonusPercent: _requiredInt(json, 'defenseBonusPercent',
          fallbackField: 'defense_bonus_percent'),
      hospitalCapacity: _requiredInt(json, 'hospitalCapacity',
          fallbackField: 'hospital_capacity'),
      effectiveProductionBonusPercent: _optionalNullableInt(
              json, 'effectiveProductionBonusPercent') ??
          _optionalNullableInt(json, 'effective_production_bonus_percent') ??
          _requiredInt(json, 'productionBonusPercent',
              fallbackField: 'production_bonus_percent'),
      effectiveMarketBonusPercent:
          _optionalNullableInt(json, 'effectiveMarketBonusPercent') ??
              _optionalNullableInt(json, 'effective_market_bonus_percent') ??
              _requiredInt(json, 'marketBonusPercent',
                  fallbackField: 'market_bonus_percent'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RegionResource {
  final String regionId;
  final String resourceId;
  final String itemId;
  final String name;
  final String category;
  final int abundancePercent;
  final int productionBonusPercent;
  final int marketBonusPercent;
  final String description;
  final DateTime updatedAt;

  RegionResource({
    required this.regionId,
    required this.resourceId,
    required this.itemId,
    required this.name,
    required this.category,
    required this.abundancePercent,
    required this.productionBonusPercent,
    required this.marketBonusPercent,
    required this.description,
    required this.updatedAt,
  });

  factory RegionResource.fromJson(Map<String, dynamic> json) {
    return RegionResource(
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      resourceId:
          _requiredString(json, 'resourceId', fallbackField: 'resource_id'),
      itemId: _requiredString(json, 'itemId', fallbackField: 'item_id'),
      name: _requiredString(json, 'name'),
      category: _requiredString(json, 'category'),
      abundancePercent: _requiredInt(json, 'abundancePercent',
          fallbackField: 'abundance_percent'),
      productionBonusPercent: _requiredInt(json, 'productionBonusPercent',
          fallbackField: 'production_bonus_percent'),
      marketBonusPercent: _requiredInt(json, 'marketBonusPercent',
          fallbackField: 'market_bonus_percent'),
      description: _requiredString(json, 'description'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RegionDefenseSystem {
  final String regionId;
  final int defenseLevel;
  final int hospitalLevel;
  final int garrisonStrength;
  final int resistance;
  final int fortificationHealth;
  final int hospitalEnergyPerDay;
  final int hospitalSupplies;
  final int effectiveDefensePercent;
  final int effectiveHospitalCapacity;
  final DateTime updatedAt;

  RegionDefenseSystem({
    required this.regionId,
    required this.defenseLevel,
    required this.hospitalLevel,
    required this.garrisonStrength,
    required this.resistance,
    required this.fortificationHealth,
    required this.hospitalEnergyPerDay,
    required this.hospitalSupplies,
    required this.effectiveDefensePercent,
    required this.effectiveHospitalCapacity,
    required this.updatedAt,
  });

  factory RegionDefenseSystem.fromJson(Map<String, dynamic> json) {
    return RegionDefenseSystem(
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      defenseLevel:
          _requiredInt(json, 'defenseLevel', fallbackField: 'defense_level'),
      hospitalLevel:
          _requiredInt(json, 'hospitalLevel', fallbackField: 'hospital_level'),
      garrisonStrength: _requiredInt(json, 'garrisonStrength',
          fallbackField: 'garrison_strength'),
      resistance: _requiredInt(json, 'resistance'),
      fortificationHealth: _optionalNullableInt(json, 'fortificationHealth') ??
          _optionalNullableInt(json, 'fortification_health') ??
          0,
      hospitalEnergyPerDay:
          _optionalNullableInt(json, 'hospitalEnergyPerDay') ??
              _optionalNullableInt(json, 'hospital_energy_per_day') ??
              0,
      hospitalSupplies: _optionalNullableInt(json, 'hospitalSupplies') ??
          _optionalNullableInt(json, 'hospital_supplies') ??
          0,
      effectiveDefensePercent:
          _optionalNullableInt(json, 'effectiveDefensePercent') ??
              _optionalNullableInt(json, 'effective_defense_percent') ??
              0,
      effectiveHospitalCapacity: _optionalNullableInt(
              json, 'effectiveHospitalCapacity') ??
          _optionalNullableInt(json, 'effective_hospital_capacity') ??
          _requiredInt(json, 'hospitalLevel', fallbackField: 'hospital_level'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RegionControlHistory {
  final String historyId;
  final String regionId;
  final String regionName;
  final String? previousCountryId;
  final String? previousCountryName;
  final String? previousCountryCode;
  final String newCountryId;
  final String newCountryName;
  final String newCountryCode;
  final String? battleId;
  final String? battleName;
  final String changedByPlayerId;
  final String reason;
  final DateTime createdAt;

  RegionControlHistory({
    required this.historyId,
    required this.regionId,
    required this.regionName,
    required this.previousCountryId,
    required this.previousCountryName,
    required this.previousCountryCode,
    required this.newCountryId,
    required this.newCountryName,
    required this.newCountryCode,
    required this.battleId,
    required this.battleName,
    required this.changedByPlayerId,
    required this.reason,
    required this.createdAt,
  });

  factory RegionControlHistory.fromJson(Map<String, dynamic> json) {
    return RegionControlHistory(
      historyId:
          _requiredString(json, 'historyId', fallbackField: 'history_id'),
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      regionName:
          _requiredString(json, 'regionName', fallbackField: 'region_name'),
      previousCountryId: _optionalNullableString(json, 'previousCountryId') ??
          _optionalNullableString(json, 'previous_country_id'),
      previousCountryName:
          _optionalNullableString(json, 'previousCountryName') ??
              _optionalNullableString(json, 'previous_country_name'),
      previousCountryCode:
          _optionalNullableString(json, 'previousCountryCode') ??
              _optionalNullableString(json, 'previous_country_code'),
      newCountryId: _requiredString(json, 'newCountryId',
          fallbackField: 'new_country_id'),
      newCountryName: _requiredString(json, 'newCountryName',
          fallbackField: 'new_country_name'),
      newCountryCode: _requiredString(json, 'newCountryCode',
          fallbackField: 'new_country_code'),
      battleId: _optionalNullableString(json, 'battleId') ??
          _optionalNullableString(json, 'battle_id'),
      battleName: _optionalNullableString(json, 'battleName') ??
          _optionalNullableString(json, 'battle_name'),
      changedByPlayerId: _requiredString(json, 'changedByPlayerId',
          fallbackField: 'changed_by_player_id'),
      reason: _requiredString(json, 'reason'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
    );
  }
}

class TerritoryAuthorization {
  final bool canStartConquest;
  final bool canStartResistance;
  final bool canResolveBattle;
  final String? role;
  final String message;

  TerritoryAuthorization({
    required this.canStartConquest,
    required this.canStartResistance,
    required this.canResolveBattle,
    required this.role,
    required this.message,
  });

  factory TerritoryAuthorization.fromJson(Map<String, dynamic> json) {
    return TerritoryAuthorization(
      canStartConquest: _requiredBool(json, 'canStartConquest'),
      canStartResistance: _requiredBool(json, 'canStartResistance'),
      canResolveBattle: _requiredBool(json, 'canResolveBattle'),
      role: _optionalNullableString(json, 'role'),
      message: _requiredString(json, 'message'),
    );
  }
}

class TerritoryBattleMutationResult {
  final bool completed;
  final String message;
  final CountryBattle? battle;
  final TerritoryRegion? region;
  final DateTime updatedAt;

  TerritoryBattleMutationResult({
    required this.completed,
    required this.message,
    required this.battle,
    required this.region,
    required this.updatedAt,
  });

  factory TerritoryBattleMutationResult.fromJson(Map<String, dynamic> json) {
    return TerritoryBattleMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      battle: json['battle'] == null
          ? null
          : CountryBattle.fromJson(_requiredMap(json['battle'])),
      region: json['region'] == null
          ? null
          : TerritoryRegion.fromJson(_requiredMap(json['region'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PlayerCitizenshipStatus {
  final String playerId;
  final PlayerCitizenship? citizenship;
  final DateTime updatedAt;

  PlayerCitizenshipStatus({
    required this.playerId,
    required this.citizenship,
    required this.updatedAt,
  });

  factory PlayerCitizenshipStatus.fromJson(Map<String, dynamic> json) {
    return PlayerCitizenshipStatus(
      playerId: _requiredString(json, 'playerId'),
      citizenship: json['citizenship'] == null
          ? null
          : PlayerCitizenship.fromJson(_requiredMap(json['citizenship'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PlayerCitizenship {
  final String playerId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String status;
  final DateTime joinedAt;
  final DateTime updatedAt;

  PlayerCitizenship({
    required this.playerId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.status,
    required this.joinedAt,
    required this.updatedAt,
  });

  factory PlayerCitizenship.fromJson(Map<String, dynamic> json) {
    return PlayerCitizenship(
      playerId: _requiredString(json, 'playerId'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      status: _requiredString(json, 'status'),
      joinedAt: _requiredDateTime(json, 'joinedAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CitizenshipMutationResult {
  final bool completed;
  final String message;
  final PlayerCitizenship? citizenship;
  final DateTime updatedAt;

  CitizenshipMutationResult({
    required this.completed,
    required this.message,
    required this.citizenship,
    required this.updatedAt,
  });

  factory CitizenshipMutationResult.fromJson(Map<String, dynamic> json) {
    return CitizenshipMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      citizenship: json['citizenship'] == null
          ? null
          : PlayerCitizenship.fromJson(_requiredMap(json['citizenship'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PoliticalPartyList {
  final List<PoliticalParty> parties;
  final DateTime updatedAt;

  PoliticalPartyList({
    required this.parties,
    required this.updatedAt,
  });

  factory PoliticalPartyList.fromJson(Map<String, dynamic> json) {
    final parties = _requiredList(json, 'parties')
        .map((party) => PoliticalParty.fromJson(_requiredMap(party)))
        .toList();
    return PoliticalPartyList(
      parties: parties,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PoliticalParty {
  final String partyId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String name;
  final String shortName;
  final String description;
  final String ideology;
  final String founderPlayerId;
  final String status;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PoliticalParty({
    required this.partyId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.name,
    required this.shortName,
    required this.description,
    required this.ideology,
    required this.founderPlayerId,
    required this.status,
    required this.memberCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PoliticalParty.fromJson(Map<String, dynamic> json) {
    return PoliticalParty(
      partyId: _requiredString(json, 'partyId', fallbackField: 'party_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      name: _requiredString(json, 'name'),
      shortName:
          _requiredString(json, 'shortName', fallbackField: 'short_name'),
      description: _requiredString(json, 'description'),
      ideology: _requiredString(json, 'ideology'),
      founderPlayerId: _requiredString(json, 'founderPlayerId',
          fallbackField: 'founder_player_id'),
      status: _requiredString(json, 'status'),
      memberCount:
          _requiredInt(json, 'memberCount', fallbackField: 'member_count'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class PoliticalPartyMembership {
  final String membershipId;
  final String partyId;
  final String partyName;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String playerId;
  final String role;
  final String status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime updatedAt;

  PoliticalPartyMembership({
    required this.membershipId,
    required this.partyId,
    required this.partyName,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.playerId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.leftAt,
    required this.updatedAt,
  });

  factory PoliticalPartyMembership.fromJson(Map<String, dynamic> json) {
    return PoliticalPartyMembership(
      membershipId:
          _requiredString(json, 'membershipId', fallbackField: 'membership_id'),
      partyId: _requiredString(json, 'partyId', fallbackField: 'party_id'),
      partyName:
          _requiredString(json, 'partyName', fallbackField: 'party_name'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      role: _requiredString(json, 'role'),
      status: _requiredString(json, 'status'),
      joinedAt: _requiredDateTime(json, 'joinedAt', fallbackField: 'joined_at'),
      leftAt: _optionalDateTime(json, 'leftAt') ??
          _optionalDateTime(json, 'left_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class PlayerPoliticsStatus {
  final String playerId;
  final PlayerCitizenship? citizenship;
  final PoliticalPartyMembership? membership;
  final List<Candidacy> candidacies;
  final List<VoteSummary> votes;
  final DateTime updatedAt;

  PlayerPoliticsStatus({
    required this.playerId,
    required this.citizenship,
    required this.membership,
    required this.candidacies,
    required this.votes,
    required this.updatedAt,
  });

  bool hasVoted(String electionId) =>
      votes.any((vote) => vote.electionId == electionId);

  factory PlayerPoliticsStatus.fromJson(Map<String, dynamic> json) {
    final candidacies = _requiredList(json, 'candidacies')
        .map((candidacy) => Candidacy.fromJson(_requiredMap(candidacy)))
        .toList();
    final votes = _requiredList(json, 'votes')
        .map((vote) => VoteSummary.fromJson(_requiredMap(vote)))
        .toList();
    return PlayerPoliticsStatus(
      playerId: _requiredString(json, 'playerId'),
      citizenship: json['citizenship'] == null
          ? null
          : PlayerCitizenship.fromJson(_requiredMap(json['citizenship'])),
      membership: json['membership'] == null
          ? null
          : PoliticalPartyMembership.fromJson(_requiredMap(json['membership'])),
      candidacies: candidacies,
      votes: votes,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PoliticalPartyMutationResult {
  final bool completed;
  final String message;
  final PoliticalParty? party;
  final PoliticalPartyMembership? membership;
  final DateTime updatedAt;

  PoliticalPartyMutationResult({
    required this.completed,
    required this.message,
    required this.party,
    required this.membership,
    required this.updatedAt,
  });

  factory PoliticalPartyMutationResult.fromJson(Map<String, dynamic> json) {
    return PoliticalPartyMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      party: json['party'] == null
          ? null
          : PoliticalParty.fromJson(_requiredMap(json['party'])),
      membership: json['membership'] == null
          ? null
          : PoliticalPartyMembership.fromJson(_requiredMap(json['membership'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ElectionList {
  final List<PoliticalElection> elections;
  final DateTime updatedAt;

  ElectionList({
    required this.elections,
    required this.updatedAt,
  });

  List<PoliticalElection> get currentElections =>
      elections.where((election) => election.isOpen).toList();

  factory ElectionList.fromJson(Map<String, dynamic> json) {
    final elections = _requiredList(json, 'elections')
        .map((election) => PoliticalElection.fromJson(_requiredMap(election)))
        .toList();
    return ElectionList(
      elections: elections,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PoliticalElection {
  final String electionId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String officeId;
  final String officeName;
  final String title;
  final String description;
  final String status;
  final DateTime votingStartsAt;
  final DateTime votingEndsAt;
  final DateTime termStartsAt;
  final DateTime termEndsAt;
  final int candidateCount;
  final int voteCount;
  final DateTime updatedAt;

  PoliticalElection({
    required this.electionId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.officeId,
    required this.officeName,
    required this.title,
    required this.description,
    required this.status,
    required this.votingStartsAt,
    required this.votingEndsAt,
    required this.termStartsAt,
    required this.termEndsAt,
    required this.candidateCount,
    required this.voteCount,
    required this.updatedAt,
  });

  bool get isVoting =>
      status.toLowerCase() == 'voting' &&
      votingStartsAt.isBefore(DateTime.now().toUtc()) &&
      votingEndsAt.isAfter(DateTime.now().toUtc());

  bool get isOpen =>
      status.toLowerCase() == 'scheduled' || status.toLowerCase() == 'voting';

  factory PoliticalElection.fromJson(Map<String, dynamic> json) {
    return PoliticalElection(
      electionId:
          _requiredString(json, 'electionId', fallbackField: 'election_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      officeId: _requiredString(json, 'officeId', fallbackField: 'office_id'),
      officeName:
          _requiredString(json, 'officeName', fallbackField: 'office_name'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      status: _requiredString(json, 'status'),
      votingStartsAt: _requiredDateTime(json, 'votingStartsAt',
          fallbackField: 'voting_starts_at'),
      votingEndsAt: _requiredDateTime(json, 'votingEndsAt',
          fallbackField: 'voting_ends_at'),
      termStartsAt: _requiredDateTime(json, 'termStartsAt',
          fallbackField: 'term_starts_at'),
      termEndsAt:
          _requiredDateTime(json, 'termEndsAt', fallbackField: 'term_ends_at'),
      candidateCount: _requiredInt(json, 'candidateCount',
          fallbackField: 'candidate_count'),
      voteCount: _requiredInt(json, 'voteCount', fallbackField: 'vote_count'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class ElectionDetails {
  final PoliticalElection election;
  final List<Candidacy> candidacies;
  final List<ElectionResultRow> results;
  final DateTime updatedAt;

  ElectionDetails({
    required this.election,
    required this.candidacies,
    required this.results,
    required this.updatedAt,
  });

  factory ElectionDetails.fromJson(Map<String, dynamic> json) {
    final candidacies = _requiredList(json, 'candidacies')
        .map((candidacy) => Candidacy.fromJson(_requiredMap(candidacy)))
        .toList();
    final results = _requiredList(json, 'results')
        .map((result) => ElectionResultRow.fromJson(_requiredMap(result)))
        .toList();
    return ElectionDetails(
      election: PoliticalElection.fromJson(_requiredMap(json['election'])),
      candidacies: candidacies,
      results: results,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class ElectionResults {
  final PoliticalElection election;
  final List<ElectionResultRow> results;
  final List<OfficeTerm> officeHolders;
  final DateTime updatedAt;

  ElectionResults({
    required this.election,
    required this.results,
    required this.officeHolders,
    required this.updatedAt,
  });

  factory ElectionResults.fromJson(Map<String, dynamic> json) {
    final results = _requiredList(json, 'results')
        .map((result) => ElectionResultRow.fromJson(_requiredMap(result)))
        .toList();
    final officeHolders = _requiredList(json, 'officeHolders')
        .map((holder) => OfficeTerm.fromJson(_requiredMap(holder)))
        .toList();
    return ElectionResults(
      election: PoliticalElection.fromJson(_requiredMap(json['election'])),
      results: results,
      officeHolders: officeHolders,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class Candidacy {
  final String candidacyId;
  final String electionId;
  final String playerId;
  final String? partyId;
  final String? partyName;
  final String? partyShortName;
  final String manifesto;
  final String status;
  final int voteCount;
  final DateTime declaredAt;
  final DateTime updatedAt;

  Candidacy({
    required this.candidacyId,
    required this.electionId,
    required this.playerId,
    required this.partyId,
    required this.partyName,
    required this.partyShortName,
    required this.manifesto,
    required this.status,
    required this.voteCount,
    required this.declaredAt,
    required this.updatedAt,
  });

  factory Candidacy.fromJson(Map<String, dynamic> json) {
    return Candidacy(
      candidacyId:
          _requiredString(json, 'candidacyId', fallbackField: 'candidacy_id'),
      electionId:
          _requiredString(json, 'electionId', fallbackField: 'election_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      partyId: _optionalNullableString(json, 'partyId') ??
          _optionalNullableString(json, 'party_id'),
      partyName: _optionalNullableString(json, 'partyName') ??
          _optionalNullableString(json, 'party_name'),
      partyShortName: _optionalNullableString(json, 'partyShortName') ??
          _optionalNullableString(json, 'party_short_name'),
      manifesto: _requiredString(json, 'manifesto'),
      status: _requiredString(json, 'status'),
      voteCount: _requiredInt(json, 'voteCount', fallbackField: 'vote_count'),
      declaredAt:
          _requiredDateTime(json, 'declaredAt', fallbackField: 'declared_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class ElectionResultRow {
  final String candidacyId;
  final String electionId;
  final String playerId;
  final String? partyId;
  final String? partyName;
  final String? partyShortName;
  final int votes;
  final int rank;
  final bool isWinner;

  ElectionResultRow({
    required this.candidacyId,
    required this.electionId,
    required this.playerId,
    required this.partyId,
    required this.partyName,
    required this.partyShortName,
    required this.votes,
    required this.rank,
    required this.isWinner,
  });

  factory ElectionResultRow.fromJson(Map<String, dynamic> json) {
    return ElectionResultRow(
      candidacyId:
          _requiredString(json, 'candidacyId', fallbackField: 'candidacy_id'),
      electionId:
          _requiredString(json, 'electionId', fallbackField: 'election_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      partyId: _optionalNullableString(json, 'partyId') ??
          _optionalNullableString(json, 'party_id'),
      partyName: _optionalNullableString(json, 'partyName') ??
          _optionalNullableString(json, 'party_name'),
      partyShortName: _optionalNullableString(json, 'partyShortName') ??
          _optionalNullableString(json, 'party_short_name'),
      votes: _requiredInt(json, 'votes'),
      rank: _requiredInt(json, 'rank'),
      isWinner: _requiredBool(json, 'isWinner'),
    );
  }
}

class VoteSummary {
  final String voteId;
  final String electionId;
  final String voterPlayerId;
  final String candidacyId;
  final String candidatePlayerId;
  final String countryId;
  final DateTime castAt;

  VoteSummary({
    required this.voteId,
    required this.electionId,
    required this.voterPlayerId,
    required this.candidacyId,
    required this.candidatePlayerId,
    required this.countryId,
    required this.castAt,
  });

  factory VoteSummary.fromJson(Map<String, dynamic> json) {
    return VoteSummary(
      voteId: _requiredString(json, 'voteId', fallbackField: 'vote_id'),
      electionId:
          _requiredString(json, 'electionId', fallbackField: 'election_id'),
      voterPlayerId: _requiredString(json, 'voterPlayerId',
          fallbackField: 'voter_player_id'),
      candidacyId:
          _requiredString(json, 'candidacyId', fallbackField: 'candidacy_id'),
      candidatePlayerId: _requiredString(json, 'candidatePlayerId',
          fallbackField: 'candidate_player_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      castAt: _requiredDateTime(json, 'castAt', fallbackField: 'cast_at'),
    );
  }
}

class CandidacyMutationResult {
  final bool completed;
  final String message;
  final Candidacy? candidacy;
  final PoliticalElection? election;
  final DateTime updatedAt;

  CandidacyMutationResult({
    required this.completed,
    required this.message,
    required this.candidacy,
    required this.election,
    required this.updatedAt,
  });

  factory CandidacyMutationResult.fromJson(Map<String, dynamic> json) {
    return CandidacyMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      candidacy: json['candidacy'] == null
          ? null
          : Candidacy.fromJson(_requiredMap(json['candidacy'])),
      election: json['election'] == null
          ? null
          : PoliticalElection.fromJson(_requiredMap(json['election'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class VoteMutationResult {
  final bool completed;
  final String message;
  final VoteSummary? vote;
  final List<ElectionResultRow> results;
  final DateTime updatedAt;

  VoteMutationResult({
    required this.completed,
    required this.message,
    required this.vote,
    required this.results,
    required this.updatedAt,
  });

  factory VoteMutationResult.fromJson(Map<String, dynamic> json) {
    final results = _requiredList(json, 'results')
        .map((result) => ElectionResultRow.fromJson(_requiredMap(result)))
        .toList();
    return VoteMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      vote: json['vote'] == null
          ? null
          : VoteSummary.fromJson(_requiredMap(json['vote'])),
      results: results,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class OfficeHolderList {
  final List<OfficeTerm> officeHolders;
  final DateTime updatedAt;

  OfficeHolderList({
    required this.officeHolders,
    required this.updatedAt,
  });

  factory OfficeHolderList.fromJson(Map<String, dynamic> json) {
    final holders = _requiredList(json, 'officeHolders')
        .map((holder) => OfficeTerm.fromJson(_requiredMap(holder)))
        .toList();
    return OfficeHolderList(
      officeHolders: holders,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class OfficeTerm {
  final String termId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String officeId;
  final String officeName;
  final String playerId;
  final String? partyId;
  final String? partyName;
  final String? sourceElectionId;
  final String status;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime updatedAt;

  OfficeTerm({
    required this.termId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.officeId,
    required this.officeName,
    required this.playerId,
    required this.partyId,
    required this.partyName,
    required this.sourceElectionId,
    required this.status,
    required this.startedAt,
    required this.endsAt,
    required this.updatedAt,
  });

  factory OfficeTerm.fromJson(Map<String, dynamic> json) {
    return OfficeTerm(
      termId: _requiredString(json, 'termId', fallbackField: 'term_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      officeId: _requiredString(json, 'officeId', fallbackField: 'office_id'),
      officeName:
          _requiredString(json, 'officeName', fallbackField: 'office_name'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      partyId: _optionalNullableString(json, 'partyId') ??
          _optionalNullableString(json, 'party_id'),
      partyName: _optionalNullableString(json, 'partyName') ??
          _optionalNullableString(json, 'party_name'),
      sourceElectionId: _optionalNullableString(json, 'sourceElectionId') ??
          _optionalNullableString(json, 'source_election_id'),
      status: _requiredString(json, 'status'),
      startedAt:
          _requiredDateTime(json, 'startedAt', fallbackField: 'started_at'),
      endsAt: _requiredDateTime(json, 'endsAt', fallbackField: 'ends_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class LawProposalList {
  final List<LawProposal> proposals;
  final CongressAuthorization? authorization;
  final DateTime updatedAt;

  LawProposalList({
    required this.proposals,
    required this.authorization,
    required this.updatedAt,
  });

  List<LawProposal> get activeProposals =>
      proposals.where((proposal) => proposal.isVoting).toList();

  List<LawProposal> get history =>
      proposals.where((proposal) => !proposal.isVoting).toList();

  factory LawProposalList.fromJson(Map<String, dynamic> json) {
    final proposals = _requiredList(json, 'proposals')
        .map((proposal) => LawProposal.fromJson(_requiredMap(proposal)))
        .toList();
    return LawProposalList(
      proposals: proposals,
      authorization: json['authorization'] == null
          ? null
          : CongressAuthorization.fromJson(_requiredMap(json['authorization'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class LawProposalDetails {
  final LawProposal proposal;
  final List<LawProposalVote> votes;
  final List<LawExecutionResult> executions;
  final CongressAuthorization? authorization;
  final DateTime updatedAt;

  LawProposalDetails({
    required this.proposal,
    required this.votes,
    required this.executions,
    required this.authorization,
    required this.updatedAt,
  });

  factory LawProposalDetails.fromJson(Map<String, dynamic> json) {
    final votes = _requiredList(json, 'votes')
        .map((vote) => LawProposalVote.fromJson(_requiredMap(vote)))
        .toList();
    final executions = _requiredList(json, 'executions')
        .map(
            (execution) => LawExecutionResult.fromJson(_requiredMap(execution)))
        .toList();
    return LawProposalDetails(
      proposal: LawProposal.fromJson(_requiredMap(json['proposal'])),
      votes: votes,
      executions: executions,
      authorization: json['authorization'] == null
          ? null
          : CongressAuthorization.fromJson(_requiredMap(json['authorization'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class LawProposal {
  final String proposalId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String proposalType;
  final String title;
  final String description;
  final String sponsorPlayerId;
  final String status;
  final DateTime votingStartsAt;
  final DateTime votingEndsAt;
  final DateTime? resolvedAt;
  final DateTime? executedAt;
  final int approvalThresholdPercent;
  final String executionStatus;
  final String executionMessage;
  final String? resultLawId;
  final int? incomeTaxRate;
  final int? marketTaxRate;
  final int? productionTaxRate;
  final int? treasuryAmount;
  final String? treasuryTargetPlayerId;
  final String treasuryReason;
  final String? citizenshipRule;
  final int yesVotes;
  final int noVotes;
  final int abstainVotes;
  final int voteCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  LawProposal({
    required this.proposalId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.proposalType,
    required this.title,
    required this.description,
    required this.sponsorPlayerId,
    required this.status,
    required this.votingStartsAt,
    required this.votingEndsAt,
    required this.resolvedAt,
    required this.executedAt,
    required this.approvalThresholdPercent,
    required this.executionStatus,
    required this.executionMessage,
    required this.resultLawId,
    required this.incomeTaxRate,
    required this.marketTaxRate,
    required this.productionTaxRate,
    required this.treasuryAmount,
    required this.treasuryTargetPlayerId,
    required this.treasuryReason,
    required this.citizenshipRule,
    required this.yesVotes,
    required this.noVotes,
    required this.abstainVotes,
    required this.voteCount,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVoting =>
      status.toLowerCase() == 'voting' &&
      votingEndsAt.isAfter(DateTime.now().toUtc());

  int get decisionVotes => yesVotes + noVotes;

  int get yesPercent =>
      decisionVotes == 0 ? 0 : ((yesVotes * 100) / decisionVotes).round();

  String get typeLabel => proposalType.replaceAll('_', ' ');

  factory LawProposal.fromJson(Map<String, dynamic> json) {
    return LawProposal(
      proposalId:
          _requiredString(json, 'proposalId', fallbackField: 'proposal_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      proposalType:
          _requiredString(json, 'proposalType', fallbackField: 'proposal_type'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      sponsorPlayerId: _requiredString(json, 'sponsorPlayerId',
          fallbackField: 'sponsor_player_id'),
      status: _requiredString(json, 'status'),
      votingStartsAt: _requiredDateTime(json, 'votingStartsAt',
          fallbackField: 'voting_starts_at'),
      votingEndsAt: _requiredDateTime(json, 'votingEndsAt',
          fallbackField: 'voting_ends_at'),
      resolvedAt: _optionalDateTime(json, 'resolvedAt') ??
          _optionalDateTime(json, 'resolved_at'),
      executedAt: _optionalDateTime(json, 'executedAt') ??
          _optionalDateTime(json, 'executed_at'),
      approvalThresholdPercent: _requiredInt(json, 'approvalThresholdPercent',
          fallbackField: 'approval_threshold_percent'),
      executionStatus: _requiredString(json, 'executionStatus',
          fallbackField: 'execution_status'),
      executionMessage: _optionalString(json, 'executionMessage',
          defaultValue:
              _optionalString(json, 'execution_message', defaultValue: '')),
      resultLawId: _optionalNullableString(json, 'resultLawId') ??
          _optionalNullableString(json, 'result_law_id'),
      incomeTaxRate: _optionalNullableInt(json, 'incomeTaxRate') ??
          _optionalNullableInt(json, 'income_tax_rate'),
      marketTaxRate: _optionalNullableInt(json, 'marketTaxRate') ??
          _optionalNullableInt(json, 'market_tax_rate'),
      productionTaxRate: _optionalNullableInt(json, 'productionTaxRate') ??
          _optionalNullableInt(json, 'production_tax_rate'),
      treasuryAmount: _optionalNullableInt(json, 'treasuryAmount') ??
          _optionalNullableInt(json, 'treasury_amount'),
      treasuryTargetPlayerId:
          _optionalNullableString(json, 'treasuryTargetPlayerId') ??
              _optionalNullableString(json, 'treasury_target_player_id'),
      treasuryReason: _optionalString(json, 'treasuryReason',
          defaultValue:
              _optionalString(json, 'treasury_reason', defaultValue: '')),
      citizenshipRule: _optionalNullableString(json, 'citizenshipRule') ??
          _optionalNullableString(json, 'citizenship_rule'),
      yesVotes: _requiredInt(json, 'yesVotes', fallbackField: 'yes_votes'),
      noVotes: _requiredInt(json, 'noVotes', fallbackField: 'no_votes'),
      abstainVotes:
          _requiredInt(json, 'abstainVotes', fallbackField: 'abstain_votes'),
      voteCount: _requiredInt(json, 'voteCount', fallbackField: 'vote_count'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class LawProposalVote {
  final String voteId;
  final String proposalId;
  final String voterPlayerId;
  final String countryId;
  final String choice;
  final DateTime castAt;

  LawProposalVote({
    required this.voteId,
    required this.proposalId,
    required this.voterPlayerId,
    required this.countryId,
    required this.choice,
    required this.castAt,
  });

  factory LawProposalVote.fromJson(Map<String, dynamic> json) {
    return LawProposalVote(
      voteId: _requiredString(json, 'voteId', fallbackField: 'vote_id'),
      proposalId:
          _requiredString(json, 'proposalId', fallbackField: 'proposal_id'),
      voterPlayerId: _requiredString(json, 'voterPlayerId',
          fallbackField: 'voter_player_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      choice: _requiredString(json, 'choice'),
      castAt: _requiredDateTime(json, 'castAt', fallbackField: 'cast_at'),
    );
  }
}

class LawExecutionResult {
  final String executionId;
  final String proposalId;
  final String? lawId;
  final String executorPlayerId;
  final String action;
  final String status;
  final String message;
  final DateTime createdAt;

  LawExecutionResult({
    required this.executionId,
    required this.proposalId,
    required this.lawId,
    required this.executorPlayerId,
    required this.action,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory LawExecutionResult.fromJson(Map<String, dynamic> json) {
    return LawExecutionResult(
      executionId:
          _requiredString(json, 'executionId', fallbackField: 'execution_id'),
      proposalId:
          _requiredString(json, 'proposalId', fallbackField: 'proposal_id'),
      lawId: _optionalNullableString(json, 'lawId') ??
          _optionalNullableString(json, 'law_id'),
      executorPlayerId: _requiredString(json, 'executorPlayerId',
          fallbackField: 'executor_player_id'),
      action: _requiredString(json, 'action'),
      status: _requiredString(json, 'status'),
      message: _requiredString(json, 'message'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
    );
  }
}

class LawList {
  final List<Law> laws;
  final DateTime updatedAt;

  LawList({required this.laws, required this.updatedAt});

  factory LawList.fromJson(Map<String, dynamic> json) {
    final laws = _requiredList(json, 'laws')
        .map((law) => Law.fromJson(_requiredMap(law)))
        .toList();
    return LawList(
      laws: laws,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class Law {
  final String lawId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String? sourceProposalId;
  final String proposalType;
  final String title;
  final String description;
  final String status;
  final DateTime enactedAt;
  final DateTime? repealedAt;
  final DateTime updatedAt;

  Law({
    required this.lawId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.sourceProposalId,
    required this.proposalType,
    required this.title,
    required this.description,
    required this.status,
    required this.enactedAt,
    required this.repealedAt,
    required this.updatedAt,
  });

  factory Law.fromJson(Map<String, dynamic> json) {
    return Law(
      lawId: _requiredString(json, 'lawId', fallbackField: 'law_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      sourceProposalId: _optionalNullableString(json, 'sourceProposalId') ??
          _optionalNullableString(json, 'source_proposal_id'),
      proposalType:
          _requiredString(json, 'proposalType', fallbackField: 'proposal_type'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      status: _requiredString(json, 'status'),
      enactedAt:
          _requiredDateTime(json, 'enactedAt', fallbackField: 'enacted_at'),
      repealedAt: _optionalDateTime(json, 'repealedAt') ??
          _optionalDateTime(json, 'repealed_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class CongressAuthorization {
  final bool canCreateProposal;
  final bool canVote;
  final bool canResolve;
  final String? role;
  final String message;

  CongressAuthorization({
    required this.canCreateProposal,
    required this.canVote,
    required this.canResolve,
    required this.role,
    required this.message,
  });

  factory CongressAuthorization.fromJson(Map<String, dynamic> json) {
    return CongressAuthorization(
      canCreateProposal: _requiredBool(json, 'canCreateProposal'),
      canVote: _requiredBool(json, 'canVote'),
      canResolve: _requiredBool(json, 'canResolve'),
      role: _optionalNullableString(json, 'role'),
      message: _requiredString(json, 'message'),
    );
  }
}

class LawProposalMutationResult {
  final bool completed;
  final String message;
  final LawProposal? proposal;
  final CongressAuthorization? authorization;
  final DateTime updatedAt;

  LawProposalMutationResult({
    required this.completed,
    required this.message,
    required this.proposal,
    required this.authorization,
    required this.updatedAt,
  });

  factory LawProposalMutationResult.fromJson(Map<String, dynamic> json) {
    return LawProposalMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      proposal: json['proposal'] == null
          ? null
          : LawProposal.fromJson(_requiredMap(json['proposal'])),
      authorization: json['authorization'] == null
          ? null
          : CongressAuthorization.fromJson(_requiredMap(json['authorization'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class LawVoteMutationResult {
  final bool completed;
  final String message;
  final LawProposal? proposal;
  final LawProposalVote? vote;
  final DateTime updatedAt;

  LawVoteMutationResult({
    required this.completed,
    required this.message,
    required this.proposal,
    required this.vote,
    required this.updatedAt,
  });

  factory LawVoteMutationResult.fromJson(Map<String, dynamic> json) {
    return LawVoteMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      proposal: json['proposal'] == null
          ? null
          : LawProposal.fromJson(_requiredMap(json['proposal'])),
      vote: json['vote'] == null
          ? null
          : LawProposalVote.fromJson(_requiredMap(json['vote'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CountryBattleList {
  final List<CountryBattle> battles;
  final DateTime updatedAt;

  CountryBattleList({
    required this.battles,
    required this.updatedAt,
  });

  List<CountryBattle> get activeBattles =>
      battles.where((battle) => battle.isActive).toList();

  List<CountryBattle> get recentBattles =>
      battles.where((battle) => !battle.isActive).toList();

  factory CountryBattleList.fromJson(Map<String, dynamic> json) {
    final battles = _requiredList(json, 'battles')
        .map((battle) => CountryBattle.fromJson(_requiredMap(battle)))
        .toList();
    return CountryBattleList(
      battles: battles,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CountryBattle {
  final String battleId;
  final String regionId;
  final String regionName;
  final String attackerCountryId;
  final String attackerCountryName;
  final String attackerCountryCode;
  final String defenderCountryId;
  final String defenderCountryName;
  final String defenderCountryCode;
  final String name;
  final String description;
  final String battleType;
  final String? campaignId;
  final String status;
  final int attackerScore;
  final int defenderScore;
  final int targetScore;
  final int defenderStrength;
  final int defenderEnergy;
  final int defenderWeaponPower;
  final int rounds;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime? resolvedAt;
  final String? winnerCountryId;
  final String? winnerCountryName;
  final DateTime updatedAt;

  CountryBattle({
    required this.battleId,
    required this.regionId,
    required this.regionName,
    required this.attackerCountryId,
    required this.attackerCountryName,
    required this.attackerCountryCode,
    required this.defenderCountryId,
    required this.defenderCountryName,
    required this.defenderCountryCode,
    required this.name,
    required this.description,
    required this.battleType,
    required this.campaignId,
    required this.status,
    required this.attackerScore,
    required this.defenderScore,
    required this.targetScore,
    required this.defenderStrength,
    required this.defenderEnergy,
    required this.defenderWeaponPower,
    required this.rounds,
    required this.startedAt,
    required this.endsAt,
    required this.resolvedAt,
    required this.winnerCountryId,
    required this.winnerCountryName,
    required this.updatedAt,
  });

  bool get isActive =>
      status.toLowerCase() == 'active' &&
      endsAt.isAfter(DateTime.now().toUtc());

  int get leadingScore =>
      attackerScore >= defenderScore ? attackerScore : defenderScore;

  double get attackerProgress {
    if (targetScore <= 0) {
      return 0;
    }
    return (attackerScore / targetScore).clamp(0, 1).toDouble();
  }

  double get defenderProgress {
    if (targetScore <= 0) {
      return 0;
    }
    return (defenderScore / targetScore).clamp(0, 1).toDouble();
  }

  factory CountryBattle.fromJson(Map<String, dynamic> json) {
    return CountryBattle(
      battleId: _requiredString(json, 'battleId', fallbackField: 'battle_id'),
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      regionName:
          _requiredString(json, 'regionName', fallbackField: 'region_name'),
      attackerCountryId: _requiredString(json, 'attackerCountryId',
          fallbackField: 'attacker_country_id'),
      attackerCountryName: _requiredString(json, 'attackerCountryName',
          fallbackField: 'attacker_country_name'),
      attackerCountryCode: _requiredString(json, 'attackerCountryCode',
          fallbackField: 'attacker_country_code'),
      defenderCountryId: _requiredString(json, 'defenderCountryId',
          fallbackField: 'defender_country_id'),
      defenderCountryName: _requiredString(json, 'defenderCountryName',
          fallbackField: 'defender_country_name'),
      defenderCountryCode: _requiredString(json, 'defenderCountryCode',
          fallbackField: 'defender_country_code'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      battleType: _optionalString(json, 'battleType',
          defaultValue:
              _optionalString(json, 'battle_type', defaultValue: 'battle')),
      campaignId: _optionalNullableString(json, 'campaignId') ??
          _optionalNullableString(json, 'campaign_id'),
      status: _requiredString(json, 'status'),
      attackerScore:
          _requiredInt(json, 'attackerScore', fallbackField: 'attacker_score'),
      defenderScore:
          _requiredInt(json, 'defenderScore', fallbackField: 'defender_score'),
      targetScore:
          _requiredInt(json, 'targetScore', fallbackField: 'target_score'),
      defenderStrength: _requiredInt(json, 'defenderStrength',
          fallbackField: 'defender_strength'),
      defenderEnergy: _requiredInt(json, 'defenderEnergy',
          fallbackField: 'defender_energy'),
      defenderWeaponPower: _requiredInt(json, 'defenderWeaponPower',
          fallbackField: 'defender_weapon_power'),
      rounds: _requiredInt(json, 'rounds'),
      startedAt:
          _requiredDateTime(json, 'startedAt', fallbackField: 'started_at'),
      endsAt: _requiredDateTime(json, 'endsAt', fallbackField: 'ends_at'),
      resolvedAt: _optionalDateTime(json, 'resolvedAt') ??
          _optionalDateTime(json, 'resolved_at'),
      winnerCountryId: _optionalNullableString(json, 'winnerCountryId') ??
          _optionalNullableString(json, 'winner_country_id'),
      winnerCountryName: _optionalNullableString(json, 'winnerCountryName') ??
          _optionalNullableString(json, 'winner_country_name'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class BattleDetails {
  final CountryBattle battle;
  final List<BattleContribution> contributions;
  final List<CombatReport> reports;
  final WarCampaign? campaign;
  final List<BattlePhase> phases;
  final CountryBattleLeaderboard? countryLeaderboard;
  final CampaignUnitLeaderboard? unitLeaderboard;
  final DateTime updatedAt;

  BattleDetails({
    required this.battle,
    required this.contributions,
    required this.reports,
    required this.campaign,
    required this.phases,
    required this.countryLeaderboard,
    required this.unitLeaderboard,
    required this.updatedAt,
  });

  factory BattleDetails.fromJson(Map<String, dynamic> json) {
    final contributions = _requiredList(json, 'contributions')
        .map((contribution) =>
            BattleContribution.fromJson(_requiredMap(contribution)))
        .toList();
    final reports = json['reports'] is List<dynamic>
        ? (json['reports'] as List<dynamic>)
            .map((report) => CombatReport.fromJson(_requiredMap(report)))
            .toList()
        : <CombatReport>[];
    final phases = json['phases'] is List<dynamic>
        ? (json['phases'] as List<dynamic>)
            .map((phase) => BattlePhase.fromJson(_requiredMap(phase)))
            .toList()
        : <BattlePhase>[];
    return BattleDetails(
      battle: CountryBattle.fromJson(_requiredMap(json['battle'])),
      contributions: contributions,
      reports: reports,
      campaign: json['campaign'] == null
          ? null
          : WarCampaign.fromJson(_requiredMap(json['campaign'])),
      phases: phases,
      countryLeaderboard: json['countryLeaderboard'] == null
          ? null
          : CountryBattleLeaderboard.fromJson(
              _requiredMap(json['countryLeaderboard'])),
      unitLeaderboard: json['unitLeaderboard'] == null
          ? null
          : CampaignUnitLeaderboard.fromJson(
              _requiredMap(json['unitLeaderboard'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class BattleContribution {
  final String contributionId;
  final String battleId;
  final String playerId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String side;
  final int damage;
  final int energySpent;
  final int roundsCompleted;
  final bool won;
  final int goldReward;
  final int experienceReward;
  final String message;
  final DateTime createdAt;

  BattleContribution({
    required this.contributionId,
    required this.battleId,
    required this.playerId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.side,
    required this.damage,
    required this.energySpent,
    required this.roundsCompleted,
    required this.won,
    required this.goldReward,
    required this.experienceReward,
    required this.message,
    required this.createdAt,
  });

  factory BattleContribution.fromJson(Map<String, dynamic> json) {
    return BattleContribution(
      contributionId: _requiredString(json, 'contributionId',
          fallbackField: 'contribution_id'),
      battleId: _requiredString(json, 'battleId', fallbackField: 'battle_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      side: _requiredString(json, 'side'),
      damage: _requiredInt(json, 'damage'),
      energySpent:
          _requiredInt(json, 'energySpent', fallbackField: 'energy_spent'),
      roundsCompleted: _requiredInt(json, 'roundsCompleted',
          fallbackField: 'rounds_completed'),
      won: _requiredBool(json, 'won'),
      goldReward:
          _requiredInt(json, 'goldReward', fallbackField: 'gold_reward'),
      experienceReward: _requiredInt(json, 'experienceReward',
          fallbackField: 'experience_reward'),
      message: _requiredString(json, 'message'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
    );
  }
}

class CombatReportList {
  final String? battleId;
  final String? playerId;
  final List<CombatReport> reports;
  final DateTime updatedAt;

  CombatReportList({
    required this.battleId,
    required this.playerId,
    required this.reports,
    required this.updatedAt,
  });

  factory CombatReportList.fromJson(Map<String, dynamic> json) {
    final reports = _requiredList(json, 'reports')
        .map((report) => CombatReport.fromJson(_requiredMap(report)))
        .toList();
    return CombatReportList(
      battleId: _optionalNullableString(json, 'battleId') ??
          _optionalNullableString(json, 'battle_id'),
      playerId: _optionalNullableString(json, 'playerId') ??
          _optionalNullableString(json, 'player_id'),
      reports: reports,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CombatReportPhase {
  final String phaseId;
  final String campaignId;
  final String battleId;
  final String battleName;
  final int phaseNumber;
  final String name;
  final String objectives;
  final int targetDamage;
  final int attackerDamage;
  final int defenderDamage;
  final String status;
  final DateTime? completedAt;

  CombatReportPhase({
    required this.phaseId,
    required this.campaignId,
    required this.battleId,
    required this.battleName,
    required this.phaseNumber,
    required this.name,
    required this.objectives,
    required this.targetDamage,
    required this.attackerDamage,
    required this.defenderDamage,
    required this.status,
    required this.completedAt,
  });

  factory CombatReportPhase.fromJson(Map<String, dynamic> json) {
    return CombatReportPhase(
      phaseId: _requiredString(json, 'phaseId', fallbackField: 'phase_id'),
      campaignId:
          _requiredString(json, 'campaignId', fallbackField: 'campaign_id'),
      battleId: _requiredString(json, 'battleId', fallbackField: 'battle_id'),
      battleName:
          _requiredString(json, 'battleName', fallbackField: 'battle_name'),
      phaseNumber:
          _requiredInt(json, 'phaseNumber', fallbackField: 'phase_number'),
      name: _requiredString(json, 'name'),
      objectives: _requiredString(json, 'objectives'),
      targetDamage:
          _requiredInt(json, 'targetDamage', fallbackField: 'target_damage'),
      attackerDamage: _requiredInt(json, 'attackerDamage',
          fallbackField: 'attacker_damage'),
      defenderDamage: _requiredInt(json, 'defenderDamage',
          fallbackField: 'defender_damage'),
      status: _requiredString(json, 'status'),
      completedAt: _optionalDateTime(json, 'completedAt') ??
          _optionalDateTime(json, 'completed_at'),
    );
  }
}

class CombatReport {
  final String reportId;
  final String contributionId;
  final String battleId;
  final String playerId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String side;
  final String battleName;
  final String battleType;
  final String regionId;
  final String regionName;
  final String attackerCountryId;
  final String attackerCountryName;
  final String attackerCountryCode;
  final String defenderCountryId;
  final String defenderCountryName;
  final String defenderCountryCode;
  final int damage;
  final int energySpent;
  final int roundsCompleted;
  final bool won;
  final int goldReward;
  final int experienceReward;
  final String fightWinner;
  final int fightRoundsRequested;
  final int fightRoundsCompleted;
  final int attackerDamage;
  final int defenderDamage;
  final int attackerRemainingEnergy;
  final int defenderRemainingEnergy;
  final int attackerScoreAfter;
  final int defenderScoreAfter;
  final int targetScore;
  final String statusAfter;
  final String? winnerCountryId;
  final String? winnerCountryName;
  final String? weaponItemId;
  final String? weaponName;
  final int? weaponPower;
  final int? weaponDurabilityBefore;
  final int? weaponDurabilityAfter;
  final int weaponDurabilityDamage;
  final String? campaignId;
  final String? campaignName;
  final List<CombatReportPhase> phaseSnapshots;
  final String message;
  final DateTime createdAt;

  CombatReport({
    required this.reportId,
    required this.contributionId,
    required this.battleId,
    required this.playerId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.side,
    required this.battleName,
    required this.battleType,
    required this.regionId,
    required this.regionName,
    required this.attackerCountryId,
    required this.attackerCountryName,
    required this.attackerCountryCode,
    required this.defenderCountryId,
    required this.defenderCountryName,
    required this.defenderCountryCode,
    required this.damage,
    required this.energySpent,
    required this.roundsCompleted,
    required this.won,
    required this.goldReward,
    required this.experienceReward,
    required this.fightWinner,
    required this.fightRoundsRequested,
    required this.fightRoundsCompleted,
    required this.attackerDamage,
    required this.defenderDamage,
    required this.attackerRemainingEnergy,
    required this.defenderRemainingEnergy,
    required this.attackerScoreAfter,
    required this.defenderScoreAfter,
    required this.targetScore,
    required this.statusAfter,
    required this.winnerCountryId,
    required this.winnerCountryName,
    required this.weaponItemId,
    required this.weaponName,
    required this.weaponPower,
    required this.weaponDurabilityBefore,
    required this.weaponDurabilityAfter,
    required this.weaponDurabilityDamage,
    required this.campaignId,
    required this.campaignName,
    required this.phaseSnapshots,
    required this.message,
    required this.createdAt,
  });

  bool get hasWeapon => weaponName != null && weaponName!.isNotEmpty;

  String get scoreAfter =>
      '$attackerCountryCode $attackerScoreAfter - $defenderScoreAfter $defenderCountryCode';

  factory CombatReport.fromJson(Map<String, dynamic> json) {
    final phaseSnapshots = json['phaseSnapshots'] is List<dynamic>
        ? (json['phaseSnapshots'] as List<dynamic>)
            .map((phase) => CombatReportPhase.fromJson(_requiredMap(phase)))
            .toList()
        : (json['phase_snapshots'] is List<dynamic>
            ? (json['phase_snapshots'] as List<dynamic>)
                .map((phase) => CombatReportPhase.fromJson(_requiredMap(phase)))
                .toList()
            : <CombatReportPhase>[]);
    return CombatReport(
      reportId: _requiredString(json, 'reportId', fallbackField: 'report_id'),
      contributionId: _requiredString(json, 'contributionId',
          fallbackField: 'contribution_id'),
      battleId: _requiredString(json, 'battleId', fallbackField: 'battle_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      side: _requiredString(json, 'side'),
      battleName:
          _requiredString(json, 'battleName', fallbackField: 'battle_name'),
      battleType:
          _requiredString(json, 'battleType', fallbackField: 'battle_type'),
      regionId: _requiredString(json, 'regionId', fallbackField: 'region_id'),
      regionName:
          _requiredString(json, 'regionName', fallbackField: 'region_name'),
      attackerCountryId: _requiredString(json, 'attackerCountryId',
          fallbackField: 'attacker_country_id'),
      attackerCountryName: _requiredString(json, 'attackerCountryName',
          fallbackField: 'attacker_country_name'),
      attackerCountryCode: _requiredString(json, 'attackerCountryCode',
          fallbackField: 'attacker_country_code'),
      defenderCountryId: _requiredString(json, 'defenderCountryId',
          fallbackField: 'defender_country_id'),
      defenderCountryName: _requiredString(json, 'defenderCountryName',
          fallbackField: 'defender_country_name'),
      defenderCountryCode: _requiredString(json, 'defenderCountryCode',
          fallbackField: 'defender_country_code'),
      damage: _requiredInt(json, 'damage'),
      energySpent:
          _requiredInt(json, 'energySpent', fallbackField: 'energy_spent'),
      roundsCompleted: _requiredInt(json, 'roundsCompleted',
          fallbackField: 'rounds_completed'),
      won: _requiredBool(json, 'won'),
      goldReward:
          _requiredInt(json, 'goldReward', fallbackField: 'gold_reward'),
      experienceReward: _requiredInt(json, 'experienceReward',
          fallbackField: 'experience_reward'),
      fightWinner:
          _requiredString(json, 'fightWinner', fallbackField: 'fight_winner'),
      fightRoundsRequested: _requiredInt(json, 'fightRoundsRequested',
          fallbackField: 'fight_rounds_requested'),
      fightRoundsCompleted: _requiredInt(json, 'fightRoundsCompleted',
          fallbackField: 'fight_rounds_completed'),
      attackerDamage: _requiredInt(json, 'attackerDamage',
          fallbackField: 'attacker_damage'),
      defenderDamage: _requiredInt(json, 'defenderDamage',
          fallbackField: 'defender_damage'),
      attackerRemainingEnergy: _requiredInt(json, 'attackerRemainingEnergy',
          fallbackField: 'attacker_remaining_energy'),
      defenderRemainingEnergy: _requiredInt(json, 'defenderRemainingEnergy',
          fallbackField: 'defender_remaining_energy'),
      attackerScoreAfter: _requiredInt(json, 'attackerScoreAfter',
          fallbackField: 'attacker_score_after'),
      defenderScoreAfter: _requiredInt(json, 'defenderScoreAfter',
          fallbackField: 'defender_score_after'),
      targetScore:
          _requiredInt(json, 'targetScore', fallbackField: 'target_score'),
      statusAfter:
          _requiredString(json, 'statusAfter', fallbackField: 'status_after'),
      winnerCountryId: _optionalNullableString(json, 'winnerCountryId') ??
          _optionalNullableString(json, 'winner_country_id'),
      winnerCountryName: _optionalNullableString(json, 'winnerCountryName') ??
          _optionalNullableString(json, 'winner_country_name'),
      weaponItemId: _optionalNullableString(json, 'weaponItemId') ??
          _optionalNullableString(json, 'weapon_item_id'),
      weaponName: _optionalNullableString(json, 'weaponName') ??
          _optionalNullableString(json, 'weapon_name'),
      weaponPower: _optionalNullableInt(json, 'weaponPower') ??
          _optionalNullableInt(json, 'weapon_power'),
      weaponDurabilityBefore:
          _optionalNullableInt(json, 'weaponDurabilityBefore') ??
              _optionalNullableInt(json, 'weapon_durability_before'),
      weaponDurabilityAfter:
          _optionalNullableInt(json, 'weaponDurabilityAfter') ??
              _optionalNullableInt(json, 'weapon_durability_after'),
      weaponDurabilityDamage: _requiredInt(json, 'weaponDurabilityDamage',
          fallbackField: 'weapon_durability_damage'),
      campaignId: _optionalNullableString(json, 'campaignId') ??
          _optionalNullableString(json, 'campaign_id'),
      campaignName: _optionalNullableString(json, 'campaignName') ??
          _optionalNullableString(json, 'campaign_name'),
      phaseSnapshots: phaseSnapshots,
      message: _requiredString(json, 'message'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
    );
  }
}

class PlayerBattleParticipationStatus {
  final String playerId;
  final String battleId;
  final PlayerBattleParticipation? participation;
  final DateTime updatedAt;

  PlayerBattleParticipationStatus({
    required this.playerId,
    required this.battleId,
    required this.participation,
    required this.updatedAt,
  });

  factory PlayerBattleParticipationStatus.fromJson(Map<String, dynamic> json) {
    return PlayerBattleParticipationStatus(
      playerId: _requiredString(json, 'playerId'),
      battleId: _requiredString(json, 'battleId'),
      participation: json['participation'] == null
          ? null
          : PlayerBattleParticipation.fromJson(
              _requiredMap(json['participation'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PlayerBattleParticipation {
  final String playerId;
  final String battleId;
  final String? countryId;
  final String? countryName;
  final String? countryCode;
  final String? side;
  final int contributionCount;
  final int damage;
  final int energySpent;
  final int goldReward;
  final int experienceReward;
  final DateTime? lastContributedAt;

  PlayerBattleParticipation({
    required this.playerId,
    required this.battleId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.side,
    required this.contributionCount,
    required this.damage,
    required this.energySpent,
    required this.goldReward,
    required this.experienceReward,
    required this.lastContributedAt,
  });

  factory PlayerBattleParticipation.fromJson(Map<String, dynamic> json) {
    return PlayerBattleParticipation(
      playerId: _requiredString(json, 'playerId'),
      battleId: _requiredString(json, 'battleId'),
      countryId: _optionalNullableString(json, 'countryId') ??
          _optionalNullableString(json, 'country_id'),
      countryName: _optionalNullableString(json, 'countryName') ??
          _optionalNullableString(json, 'country_name'),
      countryCode: _optionalNullableString(json, 'countryCode') ??
          _optionalNullableString(json, 'country_code'),
      side: _optionalNullableString(json, 'side'),
      contributionCount: _requiredInt(json, 'contributionCount',
          fallbackField: 'contribution_count'),
      damage: _requiredInt(json, 'damage'),
      energySpent:
          _requiredInt(json, 'energySpent', fallbackField: 'energy_spent'),
      goldReward:
          _requiredInt(json, 'goldReward', fallbackField: 'gold_reward'),
      experienceReward: _requiredInt(json, 'experienceReward',
          fallbackField: 'experience_reward'),
      lastContributedAt: _optionalDateTime(json, 'lastContributedAt') ??
          _optionalDateTime(json, 'last_contributed_at'),
    );
  }
}

class BattleContributionResult {
  final bool completed;
  final String message;
  final CountryBattle battle;
  final BattleContribution? contribution;
  final PlayerBattleParticipation? participation;
  final CombatReport? report;
  final FightResult fight;
  final MissionProgress? missionProgress;
  final EquipmentSummary equipment;
  final WeaponDamageResult? weaponDamage;
  final DateTime updatedAt;

  BattleContributionResult({
    required this.completed,
    required this.message,
    required this.battle,
    required this.contribution,
    required this.participation,
    required this.report,
    required this.fight,
    required this.missionProgress,
    required this.equipment,
    required this.weaponDamage,
    required this.updatedAt,
  });

  factory BattleContributionResult.fromJson(Map<String, dynamic> json) {
    return BattleContributionResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      battle: CountryBattle.fromJson(_requiredMap(json['battle'])),
      contribution: json['contribution'] == null
          ? null
          : BattleContribution.fromJson(_requiredMap(json['contribution'])),
      participation: json['participation'] == null
          ? null
          : PlayerBattleParticipation.fromJson(
              _requiredMap(json['participation'])),
      report: json['report'] == null
          ? null
          : CombatReport.fromJson(_requiredMap(json['report'])),
      fight: FightResult.fromJson(_requiredMap(json['fight'])),
      missionProgress: json['missionProgress'] == null
          ? null
          : MissionProgress.fromJson(_requiredMap(json['missionProgress'])),
      equipment: EquipmentSummary.fromJson(_requiredMap(json['equipment'])),
      weaponDamage: json['weaponDamage'] == null
          ? null
          : WeaponDamageResult.fromJson(_requiredMap(json['weaponDamage'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CompanyPermissions {
  final bool canManageMembers;
  final bool canManageRoles;
  final bool canManageProduction;
  final bool canManageWorkforce;
  final bool canManageUpgrades;
  final bool canManageSpecialization;

  CompanyPermissions({
    required this.canManageMembers,
    required this.canManageRoles,
    required this.canManageProduction,
    required this.canManageWorkforce,
    required this.canManageUpgrades,
    required this.canManageSpecialization,
  });

  factory CompanyPermissions.fromJson(Map<String, dynamic> json) {
    return CompanyPermissions(
      canManageMembers: _optionalBool(json, 'canManageMembers'),
      canManageRoles: _optionalBool(json, 'canManageRoles'),
      canManageProduction: _optionalBool(json, 'canManageProduction'),
      canManageWorkforce: _optionalBool(json, 'canManageWorkforce'),
      canManageUpgrades: _optionalBool(json, 'canManageUpgrades'),
      canManageSpecialization: _optionalBool(json, 'canManageSpecialization'),
    );
  }

  factory CompanyPermissions.forRole(String? role) {
    return CompanyPermissions(
      canManageMembers: role == 'owner',
      canManageRoles: role == 'owner',
      canManageProduction: role == 'owner' || role == 'manager',
      canManageWorkforce: role == 'owner' || role == 'manager',
      canManageUpgrades: role == 'owner' || role == 'manager',
      canManageSpecialization: role == 'owner' || role == 'manager',
    );
  }
}

class CompanyUpgradeState {
  final String companyId;
  final int hqLevel;
  final String specialization;
  final int factorySlots;
  final int usedFactorySlots;
  final int availableFactorySlots;
  final int storageUsed;
  final int storageLimit;
  final int productivityBonusPercent;
  final CompanyUpgradeQuote nextHqUpgrade;
  final List<CompanySpecializationOption> specializationOptions;
  final bool canManageUpgrades;
  final DateTime updatedAt;

  CompanyUpgradeState({
    required this.companyId,
    required this.hqLevel,
    required this.specialization,
    required this.factorySlots,
    required this.usedFactorySlots,
    required this.availableFactorySlots,
    required this.storageUsed,
    required this.storageLimit,
    required this.productivityBonusPercent,
    required this.nextHqUpgrade,
    required this.specializationOptions,
    required this.canManageUpgrades,
    required this.updatedAt,
  });

  factory CompanyUpgradeState.fromJson(Map<String, dynamic> json) {
    final options = json['specializationOptions'] is List<dynamic>
        ? (json['specializationOptions'] as List<dynamic>)
            .map((option) =>
                CompanySpecializationOption.fromJson(_requiredMap(option)))
            .toList()
        : <CompanySpecializationOption>[];
    return CompanyUpgradeState(
      companyId: _requiredString(json, 'companyId'),
      hqLevel: _requiredInt(json, 'hqLevel'),
      specialization: _requiredString(json, 'specialization'),
      factorySlots: _requiredInt(json, 'factorySlots'),
      usedFactorySlots: _requiredInt(json, 'usedFactorySlots'),
      availableFactorySlots: _requiredInt(json, 'availableFactorySlots'),
      storageUsed: _requiredInt(json, 'storageUsed'),
      storageLimit: _requiredInt(json, 'storageLimit'),
      productivityBonusPercent: _requiredInt(json, 'productivityBonusPercent'),
      nextHqUpgrade:
          CompanyUpgradeQuote.fromJson(_requiredMap(json['nextHqUpgrade'])),
      specializationOptions: options,
      canManageUpgrades: _optionalBool(json, 'canManageUpgrades'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  factory CompanyUpgradeState.fallback({
    required String companyId,
    required int walletGold,
    required int storageUsed,
    required int storageLimit,
    required int factoryCount,
    required int laborCredits,
    required bool canManageUpgrades,
    required DateTime updatedAt,
  }) {
    final nextLevel = 2;
    return CompanyUpgradeState(
      companyId: companyId,
      hqLevel: 1,
      specialization: 'general',
      factorySlots: factoryCount,
      usedFactorySlots: factoryCount,
      availableFactorySlots: 0,
      storageUsed: storageUsed,
      storageLimit: storageLimit,
      productivityBonusPercent: 0,
      nextHqUpgrade: CompanyUpgradeQuote(
        upgradeType: 'hq',
        currentLevel: 1,
        nextLevel: nextLevel,
        goldCost: 250 * nextLevel,
        requiredItemId: 'labor_credit',
        requiredItemName: 'Labor Credit',
        requiredItemQuantity: 10 * nextLevel,
        availableGold: walletGold,
        availableItemQuantity: laborCredits,
        storageLimitAfterUpgrade: storageLimit + 100,
        factorySlotsAfterUpgrade: factoryCount + 1,
        productivityBonusPercentAfterUpgrade: 5,
        canUpgrade: false,
        message: 'Upgrade state is not available yet.',
      ),
      specializationOptions: const [],
      canManageUpgrades: canManageUpgrades,
      updatedAt: updatedAt,
    );
  }
}

class CompanyUpgradeQuote {
  final String upgradeType;
  final int currentLevel;
  final int nextLevel;
  final int goldCost;
  final String requiredItemId;
  final String requiredItemName;
  final int requiredItemQuantity;
  final int availableGold;
  final int availableItemQuantity;
  final int storageLimitAfterUpgrade;
  final int factorySlotsAfterUpgrade;
  final int productivityBonusPercentAfterUpgrade;
  final bool canUpgrade;
  final String message;

  CompanyUpgradeQuote({
    required this.upgradeType,
    required this.currentLevel,
    required this.nextLevel,
    required this.goldCost,
    required this.requiredItemId,
    required this.requiredItemName,
    required this.requiredItemQuantity,
    required this.availableGold,
    required this.availableItemQuantity,
    required this.storageLimitAfterUpgrade,
    required this.factorySlotsAfterUpgrade,
    required this.productivityBonusPercentAfterUpgrade,
    required this.canUpgrade,
    required this.message,
  });

  factory CompanyUpgradeQuote.fromJson(Map<String, dynamic> json) {
    return CompanyUpgradeQuote(
      upgradeType: _requiredString(json, 'upgradeType'),
      currentLevel: _requiredInt(json, 'currentLevel'),
      nextLevel: _requiredInt(json, 'nextLevel'),
      goldCost: _requiredInt(json, 'goldCost'),
      requiredItemId: _requiredString(json, 'requiredItemId'),
      requiredItemName: _requiredString(json, 'requiredItemName'),
      requiredItemQuantity: _requiredInt(json, 'requiredItemQuantity'),
      availableGold: _requiredInt(json, 'availableGold'),
      availableItemQuantity: _requiredInt(json, 'availableItemQuantity'),
      storageLimitAfterUpgrade: _requiredInt(json, 'storageLimitAfterUpgrade'),
      factorySlotsAfterUpgrade: _requiredInt(json, 'factorySlotsAfterUpgrade'),
      productivityBonusPercentAfterUpgrade:
          _requiredInt(json, 'productivityBonusPercentAfterUpgrade'),
      canUpgrade: _requiredBool(json, 'canUpgrade'),
      message: _requiredString(json, 'message'),
    );
  }
}

class CompanySpecializationOption {
  final String specialization;
  final String name;
  final String description;
  final String affectedCategory;
  final int productivityBonusPercent;
  final bool isSelected;
  final int goldCost;
  final String requiredItemId;
  final String requiredItemName;
  final int requiredItemQuantity;

  CompanySpecializationOption({
    required this.specialization,
    required this.name,
    required this.description,
    required this.affectedCategory,
    required this.productivityBonusPercent,
    required this.isSelected,
    required this.goldCost,
    required this.requiredItemId,
    required this.requiredItemName,
    required this.requiredItemQuantity,
  });

  factory CompanySpecializationOption.fromJson(Map<String, dynamic> json) {
    return CompanySpecializationOption(
      specialization: _requiredString(json, 'specialization'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      affectedCategory: _requiredString(json, 'affectedCategory'),
      productivityBonusPercent: _requiredInt(json, 'productivityBonusPercent'),
      isSelected: _requiredBool(json, 'isSelected'),
      goldCost: _requiredInt(json, 'goldCost'),
      requiredItemId: _requiredString(json, 'requiredItemId'),
      requiredItemName: _requiredString(json, 'requiredItemName'),
      requiredItemQuantity: _requiredInt(json, 'requiredItemQuantity'),
    );
  }
}

class CompanyUpgradeMutationResult {
  final bool completed;
  final String message;
  final CompanyUpgradeState upgrades;
  final CompanyDetail? company;

  CompanyUpgradeMutationResult({
    required this.completed,
    required this.message,
    required this.upgrades,
    required this.company,
  });

  factory CompanyUpgradeMutationResult.fromJson(Map<String, dynamic> json) {
    return CompanyUpgradeMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      upgrades: CompanyUpgradeState.fromJson(_requiredMap(json['upgrades'])),
      company: json['company'] == null
          ? null
          : CompanyDetail.fromJson(_requiredMap(json['company'])),
    );
  }
}

class CampaignList {
  final List<WarCampaign> campaigns;
  final DateTime updatedAt;

  CampaignList({
    required this.campaigns,
    required this.updatedAt,
  });

  List<WarCampaign> get activeCampaigns =>
      campaigns.where((campaign) => campaign.isActive).toList();

  factory CampaignList.fromJson(Map<String, dynamic> json) {
    final campaigns = _requiredList(json, 'campaigns')
        .map((campaign) => WarCampaign.fromJson(_requiredMap(campaign)))
        .toList();
    return CampaignList(
      campaigns: campaigns,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CampaignDetails {
  final WarCampaign campaign;
  final List<CountryBattle> battles;
  final List<BattlePhase> phases;
  final CountryBattleLeaderboard countryLeaderboard;
  final CampaignUnitLeaderboard unitLeaderboard;
  final DateTime updatedAt;

  CampaignDetails({
    required this.campaign,
    required this.battles,
    required this.phases,
    required this.countryLeaderboard,
    required this.unitLeaderboard,
    required this.updatedAt,
  });

  factory CampaignDetails.fromJson(Map<String, dynamic> json) {
    final battles = _requiredList(json, 'battles')
        .map((battle) => CountryBattle.fromJson(_requiredMap(battle)))
        .toList();
    final phases = _requiredList(json, 'phases')
        .map((phase) => BattlePhase.fromJson(_requiredMap(phase)))
        .toList();
    return CampaignDetails(
      campaign: WarCampaign.fromJson(_requiredMap(json['campaign'])),
      battles: battles,
      phases: phases,
      countryLeaderboard: CountryBattleLeaderboard.fromJson(
          _requiredMap(json['countryLeaderboard'])),
      unitLeaderboard: CampaignUnitLeaderboard.fromJson(
          _requiredMap(json['unitLeaderboard'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class WarCampaign {
  final String campaignId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String name;
  final String description;
  final String campaignType;
  final String status;
  final int objectiveScore;
  final int currentScore;
  final CampaignReward reward;
  final int battleCount;
  final int phaseCount;
  final int activeBattleCount;
  final String createdByPlayerId;
  final DateTime startedAt;
  final DateTime? endsAt;
  final DateTime? concludedAt;
  final String? winnerCountryId;
  final String? winnerCountryName;
  final DateTime createdAt;
  final DateTime updatedAt;

  WarCampaign({
    required this.campaignId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.name,
    required this.description,
    required this.campaignType,
    required this.status,
    required this.objectiveScore,
    required this.currentScore,
    required this.reward,
    required this.battleCount,
    required this.phaseCount,
    required this.activeBattleCount,
    required this.createdByPlayerId,
    required this.startedAt,
    required this.endsAt,
    required this.concludedAt,
    required this.winnerCountryId,
    required this.winnerCountryName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get canClaimRewards =>
      isCompleted &&
      (reward.gold > 0 || reward.experience > 0 || reward.prestige > 0);

  double get progress {
    if (objectiveScore <= 0) {
      return 0;
    }
    return (currentScore / objectiveScore).clamp(0, 1).toDouble();
  }

  factory WarCampaign.fromJson(Map<String, dynamic> json) {
    return WarCampaign(
      campaignId:
          _requiredString(json, 'campaignId', fallbackField: 'campaign_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      campaignType:
          _requiredString(json, 'campaignType', fallbackField: 'campaign_type'),
      status: _requiredString(json, 'status'),
      objectiveScore: _requiredInt(json, 'objectiveScore',
          fallbackField: 'objective_score'),
      currentScore:
          _requiredInt(json, 'currentScore', fallbackField: 'current_score'),
      reward: CampaignReward.fromJson(_requiredMap(json['reward'])),
      battleCount:
          _requiredInt(json, 'battleCount', fallbackField: 'battle_count'),
      phaseCount:
          _requiredInt(json, 'phaseCount', fallbackField: 'phase_count'),
      activeBattleCount: _requiredInt(json, 'activeBattleCount',
          fallbackField: 'active_battle_count'),
      createdByPlayerId: _requiredString(json, 'createdByPlayerId',
          fallbackField: 'created_by_player_id'),
      startedAt:
          _requiredDateTime(json, 'startedAt', fallbackField: 'started_at'),
      endsAt: _optionalDateTime(json, 'endsAt') ??
          _optionalDateTime(json, 'ends_at'),
      concludedAt: _optionalDateTime(json, 'concludedAt') ??
          _optionalDateTime(json, 'concluded_at'),
      winnerCountryId: _optionalNullableString(json, 'winnerCountryId') ??
          _optionalNullableString(json, 'winner_country_id'),
      winnerCountryName: _optionalNullableString(json, 'winnerCountryName') ??
          _optionalNullableString(json, 'winner_country_name'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class CampaignReward {
  final int gold;
  final int experience;
  final int prestige;

  CampaignReward({
    required this.gold,
    required this.experience,
    required this.prestige,
  });

  factory CampaignReward.fromJson(Map<String, dynamic> json) {
    return CampaignReward(
      gold: _requiredInt(json, 'gold'),
      experience: _requiredInt(json, 'experience'),
      prestige: _requiredInt(json, 'prestige'),
    );
  }
}

class BattlePhase {
  final String phaseId;
  final String campaignId;
  final String battleId;
  final String battleName;
  final int phaseNumber;
  final String name;
  final String objectives;
  final int targetDamage;
  final int attackerDamage;
  final int defenderDamage;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  BattlePhase({
    required this.phaseId,
    required this.campaignId,
    required this.battleId,
    required this.battleName,
    required this.phaseNumber,
    required this.name,
    required this.objectives,
    required this.targetDamage,
    required this.attackerDamage,
    required this.defenderDamage,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.updatedAt,
  });

  int get totalDamage => attackerDamage + defenderDamage;

  double get progress {
    if (targetDamage <= 0) {
      return 0;
    }
    return (totalDamage / targetDamage).clamp(0, 1).toDouble();
  }

  bool get isCompleted => status.toLowerCase() == 'completed';

  factory BattlePhase.fromJson(Map<String, dynamic> json) {
    return BattlePhase(
      phaseId: _requiredString(json, 'phaseId', fallbackField: 'phase_id'),
      campaignId:
          _requiredString(json, 'campaignId', fallbackField: 'campaign_id'),
      battleId: _requiredString(json, 'battleId', fallbackField: 'battle_id'),
      battleName:
          _requiredString(json, 'battleName', fallbackField: 'battle_name'),
      phaseNumber:
          _requiredInt(json, 'phaseNumber', fallbackField: 'phase_number'),
      name: _requiredString(json, 'name'),
      objectives: _requiredString(json, 'objectives'),
      targetDamage:
          _requiredInt(json, 'targetDamage', fallbackField: 'target_damage'),
      attackerDamage: _requiredInt(json, 'attackerDamage',
          fallbackField: 'attacker_damage'),
      defenderDamage: _requiredInt(json, 'defenderDamage',
          fallbackField: 'defender_damage'),
      status: _requiredString(json, 'status'),
      startedAt:
          _requiredDateTime(json, 'startedAt', fallbackField: 'started_at'),
      completedAt: _optionalDateTime(json, 'completedAt') ??
          _optionalDateTime(json, 'completed_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class BattlePhaseList {
  final String campaignId;
  final List<BattlePhase> phases;
  final DateTime updatedAt;

  BattlePhaseList({
    required this.campaignId,
    required this.phases,
    required this.updatedAt,
  });

  factory BattlePhaseList.fromJson(Map<String, dynamic> json) {
    final phases = _requiredList(json, 'phases')
        .map((phase) => BattlePhase.fromJson(_requiredMap(phase)))
        .toList();
    return BattlePhaseList(
      campaignId:
          _requiredString(json, 'campaignId', fallbackField: 'campaign_id'),
      phases: phases,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CountryBattleLeaderboard {
  final List<CountryBattleLeaderboardEntry> entries;
  final DateTime updatedAt;

  CountryBattleLeaderboard({
    required this.entries,
    required this.updatedAt,
  });

  factory CountryBattleLeaderboard.fromJson(Map<String, dynamic> json) {
    final entries = _requiredList(json, 'entries')
        .map((entry) =>
            CountryBattleLeaderboardEntry.fromJson(_requiredMap(entry)))
        .toList();
    return CountryBattleLeaderboard(
      entries: entries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CountryBattleLeaderboardEntry {
  final int rank;
  final String countryId;
  final String countryName;
  final String countryCode;
  final int totalDamage;
  final int contributionCount;
  final int battleCount;
  final int victoryCount;
  final int score;
  final DateTime? lastContributedAt;

  CountryBattleLeaderboardEntry({
    required this.rank,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.totalDamage,
    required this.contributionCount,
    required this.battleCount,
    required this.victoryCount,
    required this.score,
    required this.lastContributedAt,
  });

  factory CountryBattleLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return CountryBattleLeaderboardEntry(
      rank: _requiredInt(json, 'rank'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      totalDamage:
          _requiredInt(json, 'totalDamage', fallbackField: 'total_damage'),
      contributionCount: _requiredInt(json, 'contributionCount',
          fallbackField: 'contribution_count'),
      battleCount:
          _requiredInt(json, 'battleCount', fallbackField: 'battle_count'),
      victoryCount:
          _requiredInt(json, 'victoryCount', fallbackField: 'victory_count'),
      score: _requiredInt(json, 'score'),
      lastContributedAt: _optionalDateTime(json, 'lastContributedAt') ??
          _optionalDateTime(json, 'last_contributed_at'),
    );
  }
}

class CampaignUnitLeaderboard {
  final List<CampaignUnitLeaderboardEntry> entries;
  final DateTime updatedAt;

  CampaignUnitLeaderboard({
    required this.entries,
    required this.updatedAt,
  });

  factory CampaignUnitLeaderboard.fromJson(Map<String, dynamic> json) {
    final entries = _requiredList(json, 'entries')
        .map((entry) =>
            CampaignUnitLeaderboardEntry.fromJson(_requiredMap(entry)))
        .toList();
    return CampaignUnitLeaderboard(
      entries: entries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CampaignUnitLeaderboardEntry {
  final int rank;
  final String unitId;
  final String unitName;
  final String countryId;
  final String countryName;
  final String countryCode;
  final int totalDamage;
  final int contributionCount;
  final int battleCount;
  final int memberCount;
  final int score;
  final DateTime? lastContributedAt;

  CampaignUnitLeaderboardEntry({
    required this.rank,
    required this.unitId,
    required this.unitName,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.totalDamage,
    required this.contributionCount,
    required this.battleCount,
    required this.memberCount,
    required this.score,
    required this.lastContributedAt,
  });

  factory CampaignUnitLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return CampaignUnitLeaderboardEntry(
      rank: _requiredInt(json, 'rank'),
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      unitName: _requiredString(json, 'unitName', fallbackField: 'unit_name'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      totalDamage:
          _requiredInt(json, 'totalDamage', fallbackField: 'total_damage'),
      contributionCount: _requiredInt(json, 'contributionCount',
          fallbackField: 'contribution_count'),
      battleCount:
          _requiredInt(json, 'battleCount', fallbackField: 'battle_count'),
      memberCount:
          _requiredInt(json, 'memberCount', fallbackField: 'member_count'),
      score: _requiredInt(json, 'score'),
      lastContributedAt: _optionalDateTime(json, 'lastContributedAt') ??
          _optionalDateTime(json, 'last_contributed_at'),
    );
  }
}

class CampaignMutationResult {
  final bool completed;
  final String message;
  final WarCampaign? campaign;
  final BattlePhase? phase;
  final DateTime updatedAt;

  CampaignMutationResult({
    required this.completed,
    required this.message,
    required this.campaign,
    required this.phase,
    required this.updatedAt,
  });

  factory CampaignMutationResult.fromJson(Map<String, dynamic> json) {
    return CampaignMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      campaign: json['campaign'] == null
          ? null
          : WarCampaign.fromJson(_requiredMap(json['campaign'])),
      phase: json['phase'] == null
          ? null
          : BattlePhase.fromJson(_requiredMap(json['phase'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CampaignRewardClaimResult {
  final bool completed;
  final String message;
  final WarCampaign? campaign;
  final CampaignRewardClaim? claim;
  final DateTime updatedAt;

  CampaignRewardClaimResult({
    required this.completed,
    required this.message,
    required this.campaign,
    required this.claim,
    required this.updatedAt,
  });

  factory CampaignRewardClaimResult.fromJson(Map<String, dynamic> json) {
    return CampaignRewardClaimResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      campaign: json['campaign'] == null
          ? null
          : WarCampaign.fromJson(_requiredMap(json['campaign'])),
      claim: json['claim'] == null
          ? null
          : CampaignRewardClaim.fromJson(_requiredMap(json['claim'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CampaignRewardClaim {
  final String claimId;
  final String campaignId;
  final String playerId;
  final String countryId;
  final int goldReward;
  final int experienceReward;
  final int prestigeReward;
  final String message;
  final DateTime claimedAt;

  CampaignRewardClaim({
    required this.claimId,
    required this.campaignId,
    required this.playerId,
    required this.countryId,
    required this.goldReward,
    required this.experienceReward,
    required this.prestigeReward,
    required this.message,
    required this.claimedAt,
  });

  factory CampaignRewardClaim.fromJson(Map<String, dynamic> json) {
    return CampaignRewardClaim(
      claimId: _requiredString(json, 'claimId', fallbackField: 'claim_id'),
      campaignId:
          _requiredString(json, 'campaignId', fallbackField: 'campaign_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      goldReward:
          _requiredInt(json, 'goldReward', fallbackField: 'gold_reward'),
      experienceReward: _requiredInt(json, 'experienceReward',
          fallbackField: 'experience_reward'),
      prestigeReward: _requiredInt(json, 'prestigeReward',
          fallbackField: 'prestige_reward'),
      message: _requiredString(json, 'message'),
      claimedAt:
          _requiredDateTime(json, 'claimedAt', fallbackField: 'claimed_at'),
    );
  }
}

class CompanyPortfolio {
  final String playerId;
  final List<CompanySummary> companies;
  final DateTime updatedAt;

  CompanyPortfolio({
    required this.playerId,
    required this.companies,
    required this.updatedAt,
  });

  factory CompanyPortfolio.fromJson(Map<String, dynamic> json) {
    final companies = _requiredList(json, 'companies')
        .map((company) => CompanySummary.fromJson(_requiredMap(company)))
        .toList();
    return CompanyPortfolio(
      playerId: _requiredString(json, 'playerId'),
      companies: companies,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CompanySummary {
  final String companyId;
  final String name;
  final String description;
  final String ownerPlayerId;
  final int walletGold;
  final int storageUsed;
  final int storageLimit;
  final int hqLevel;
  final String specialization;
  final int factorySlots;
  final int productivityBonusPercent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;
  final int factoryCount;
  final String? role;
  final bool isMember;
  final bool canManage;
  final CompanyPermissions permissions;

  CompanySummary({
    required this.companyId,
    required this.name,
    required this.description,
    required this.ownerPlayerId,
    required this.walletGold,
    required this.storageUsed,
    required this.storageLimit,
    required this.hqLevel,
    required this.specialization,
    required this.factorySlots,
    required this.productivityBonusPercent,
    required this.createdAt,
    required this.updatedAt,
    required this.memberCount,
    required this.factoryCount,
    required this.role,
    required this.isMember,
    required this.canManage,
    required this.permissions,
  });

  factory CompanySummary.fromJson(Map<String, dynamic> json) {
    final role = _optionalNullableString(json, 'role');
    final factoryCount = _requiredInt(json, 'factoryCount');
    final permissions = json['permissions'] is Map<String, dynamic>
        ? CompanyPermissions.fromJson(_requiredMap(json['permissions']))
        : CompanyPermissions.forRole(role);
    return CompanySummary(
      companyId: _requiredString(json, 'companyId'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      ownerPlayerId: _requiredString(json, 'ownerPlayerId'),
      walletGold: _requiredInt(json, 'walletGold'),
      storageUsed: _requiredInt(json, 'storageUsed'),
      storageLimit: _requiredInt(json, 'storageLimit'),
      hqLevel: _optionalInt(json, 'hqLevel') == 0
          ? 1
          : _optionalInt(json, 'hqLevel'),
      specialization:
          _optionalString(json, 'specialization', defaultValue: 'general'),
      factorySlots: _optionalInt(json, 'factorySlots') == 0
          ? factoryCount
          : _optionalInt(json, 'factorySlots'),
      productivityBonusPercent: _optionalInt(json, 'productivityBonusPercent'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      memberCount: _requiredInt(json, 'memberCount'),
      factoryCount: factoryCount,
      role: role,
      isMember: json['isMember'] == true || role != null,
      canManage:
          json['canManage'] == true || role == 'owner' || role == 'manager',
      permissions: permissions,
    );
  }
}

class CompanyDetail {
  final String companyId;
  final String name;
  final String description;
  final String ownerPlayerId;
  final int walletGold;
  final int storageUsed;
  final int storageLimit;
  final int hqLevel;
  final String specialization;
  final int factorySlots;
  final int productivityBonusPercent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;
  final int factoryCount;
  final String? role;
  final bool isMember;
  final bool canManage;
  final CompanyPermissions permissions;
  final List<CompanyMember> members;
  final CompanyAssets assets;

  CompanyDetail({
    required this.companyId,
    required this.name,
    required this.description,
    required this.ownerPlayerId,
    required this.walletGold,
    required this.storageUsed,
    required this.storageLimit,
    required this.hqLevel,
    required this.specialization,
    required this.factorySlots,
    required this.productivityBonusPercent,
    required this.createdAt,
    required this.updatedAt,
    required this.memberCount,
    required this.factoryCount,
    required this.role,
    required this.isMember,
    required this.canManage,
    required this.permissions,
    required this.members,
    required this.assets,
  });

  factory CompanyDetail.fromJson(Map<String, dynamic> json) {
    final summary = CompanySummary.fromJson(json);
    final members = _requiredList(json, 'members')
        .map((member) => CompanyMember.fromJson(_requiredMap(member)))
        .toList();
    return CompanyDetail(
      companyId: summary.companyId,
      name: summary.name,
      description: summary.description,
      ownerPlayerId: summary.ownerPlayerId,
      walletGold: summary.walletGold,
      storageUsed: summary.storageUsed,
      storageLimit: summary.storageLimit,
      hqLevel: summary.hqLevel,
      specialization: summary.specialization,
      factorySlots: summary.factorySlots,
      productivityBonusPercent: summary.productivityBonusPercent,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      memberCount: summary.memberCount,
      factoryCount: summary.factoryCount,
      role: summary.role,
      isMember: summary.isMember,
      canManage: summary.canManage,
      permissions: summary.permissions,
      members: members,
      assets: CompanyAssets.fromJson(_requiredMap(json['assets'])),
    );
  }
}

class CompanyMember {
  final String playerId;
  final String role;
  final DateTime joinedAt;
  final bool canManage;

  CompanyMember({
    required this.playerId,
    required this.role,
    required this.joinedAt,
    required this.canManage,
  });

  factory CompanyMember.fromJson(Map<String, dynamic> json) {
    final role = _requiredString(json, 'role');
    return CompanyMember(
      playerId: _requiredString(json, 'playerId'),
      role: role,
      joinedAt: _requiredDateTime(json, 'joinedAt'),
      canManage:
          json['canManage'] == true || role == 'owner' || role == 'manager',
    );
  }
}

class CompanyAssets {
  final String companyId;
  final int walletGold;
  final int storageUsed;
  final int storageLimit;
  final CompanyUpgradeState upgrades;
  final List<InventoryItem> inventory;
  final List<PlayerFactory> factories;
  final List<ProductionJob> productionJobs;
  final List<CompanyJobPosting> workforceJobs;
  final List<CompanyWorkRecord> workRecords;
  final DateTime updatedAt;

  CompanyAssets({
    required this.companyId,
    required this.walletGold,
    required this.storageUsed,
    required this.storageLimit,
    required this.upgrades,
    required this.inventory,
    required this.factories,
    required this.productionJobs,
    required this.workforceJobs,
    required this.workRecords,
    required this.updatedAt,
  });

  factory CompanyAssets.fromJson(Map<String, dynamic> json) {
    final companyId = _requiredString(json, 'companyId');
    final walletGold = _requiredInt(json, 'walletGold');
    final storageUsed = _requiredInt(json, 'storageUsed');
    final storageLimit = _requiredInt(json, 'storageLimit');
    final inventory = _requiredList(json, 'inventory')
        .map((item) => InventoryItem.fromJson(_requiredMap(item)))
        .toList();
    final factories = _requiredList(json, 'factories')
        .map((factory) => PlayerFactory.fromJson(_requiredMap(factory)))
        .toList();
    final jobs = _requiredList(json, 'productionJobs')
        .map((job) => ProductionJob.fromJson(_requiredMap(job)))
        .toList();
    final workforceJobs = json['workforceJobs'] is List<dynamic>
        ? (json['workforceJobs'] as List<dynamic>)
            .map((job) => CompanyJobPosting.fromJson(_requiredMap(job)))
            .toList()
        : <CompanyJobPosting>[];
    final workRecords = json['workRecords'] is List<dynamic>
        ? (json['workRecords'] as List<dynamic>)
            .map((record) => CompanyWorkRecord.fromJson(_requiredMap(record)))
            .toList()
        : <CompanyWorkRecord>[];
    final laborCredits = inventory
        .where((item) => item.itemId == 'labor_credit')
        .fold<int>(0, (sum, item) => sum + item.quantity);
    final upgrades = json['upgrades'] is Map<String, dynamic>
        ? CompanyUpgradeState.fromJson(_requiredMap(json['upgrades']))
        : CompanyUpgradeState.fallback(
            companyId: companyId,
            walletGold: walletGold,
            storageUsed: storageUsed,
            storageLimit: storageLimit,
            factoryCount: factories.length,
            laborCredits: laborCredits,
            canManageUpgrades: false,
            updatedAt: _requiredDateTime(json, 'updatedAt'),
          );
    return CompanyAssets(
      companyId: companyId,
      walletGold: walletGold,
      storageUsed: storageUsed,
      storageLimit: storageLimit,
      upgrades: upgrades,
      inventory: inventory,
      factories: factories,
      productionJobs: jobs,
      workforceJobs: workforceJobs,
      workRecords: workRecords,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  List<ProductionJob> jobsForFactory(String factoryId) {
    return productionJobs.where((job) => job.factoryId == factoryId).toList();
  }
}

class CompanyMutationResult {
  final bool completed;
  final String message;
  final CompanyDetail? company;

  CompanyMutationResult({
    required this.completed,
    required this.message,
    required this.company,
  });

  factory CompanyMutationResult.fromJson(Map<String, dynamic> json) {
    return CompanyMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      company: json['company'] == null
          ? null
          : CompanyDetail.fromJson(_requiredMap(json['company'])),
    );
  }
}

class CompanyProductionClaimResult {
  final bool completed;
  final String message;
  final ProductionClaimCompletion claim;
  final CompanyAssets assets;

  CompanyProductionClaimResult({
    required this.completed,
    required this.message,
    required this.claim,
    required this.assets,
  });

  factory CompanyProductionClaimResult.fromJson(Map<String, dynamic> json) {
    return CompanyProductionClaimResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      claim: ProductionClaimCompletion.fromJson(_requiredMap(json['claim'])),
      assets: CompanyAssets.fromJson(_requiredMap(json['assets'])),
    );
  }
}

class CompanyJobList {
  final String? companyId;
  final List<CompanyJobPosting> jobs;
  final DateTime updatedAt;

  CompanyJobList({
    required this.companyId,
    required this.jobs,
    required this.updatedAt,
  });

  factory CompanyJobList.fromJson(Map<String, dynamic> json) {
    final jobs = _requiredList(json, 'jobs')
        .map((job) => CompanyJobPosting.fromJson(_requiredMap(job)))
        .toList();
    return CompanyJobList(
      companyId: _optionalNullableString(json, 'companyId'),
      jobs: jobs,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CompanyJobPosting {
  final String jobId;
  final String companyId;
  final String companyName;
  final String title;
  final String description;
  final int wageGold;
  final int requiredEnergy;
  final int dailyLimit;
  final int productivityReward;
  final String status;
  final bool isActive;
  final String createdByPlayerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final int workCount;
  final int todayWorkCount;

  CompanyJobPosting({
    required this.jobId,
    required this.companyId,
    required this.companyName,
    required this.title,
    required this.description,
    required this.wageGold,
    required this.requiredEnergy,
    required this.dailyLimit,
    required this.productivityReward,
    required this.status,
    required this.isActive,
    required this.createdByPlayerId,
    required this.createdAt,
    required this.updatedAt,
    required this.closedAt,
    required this.workCount,
    required this.todayWorkCount,
  });

  bool get isDailyLimitReached => todayWorkCount >= dailyLimit;

  factory CompanyJobPosting.fromJson(Map<String, dynamic> json) {
    final status = _requiredString(json, 'status');
    return CompanyJobPosting(
      jobId: _requiredString(json, 'jobId'),
      companyId: _requiredString(json, 'companyId'),
      companyName: _optionalString(json, 'companyName', defaultValue: ''),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      wageGold: _requiredInt(json, 'wageGold'),
      requiredEnergy: _requiredInt(json, 'requiredEnergy'),
      dailyLimit: _requiredInt(json, 'dailyLimit'),
      productivityReward: _requiredInt(json, 'productivityReward'),
      status: status,
      isActive: json['isActive'] == true || status == 'active',
      createdByPlayerId: _requiredString(json, 'createdByPlayerId'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      closedAt: _optionalDateTime(json, 'closedAt'),
      workCount: _optionalInt(json, 'workCount'),
      todayWorkCount: _optionalInt(json, 'todayWorkCount'),
    );
  }
}

class CompanyWorkRecord {
  final String workId;
  final String jobId;
  final String companyId;
  final String playerId;
  final String idempotencyKey;
  final int grossWageGold;
  final int netWageGold;
  final int taxGold;
  final int requiredEnergy;
  final int productivityReward;
  final String status;
  final DateTime workDate;
  final DateTime workedAt;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyWorkRecord({
    required this.workId,
    required this.jobId,
    required this.companyId,
    required this.playerId,
    required this.idempotencyKey,
    required this.grossWageGold,
    required this.netWageGold,
    required this.taxGold,
    required this.requiredEnergy,
    required this.productivityReward,
    required this.status,
    required this.workDate,
    required this.workedAt,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyWorkRecord.fromJson(Map<String, dynamic> json) {
    return CompanyWorkRecord(
      workId: _requiredString(json, 'workId'),
      jobId: _requiredString(json, 'jobId'),
      companyId: _requiredString(json, 'companyId'),
      playerId: _requiredString(json, 'playerId'),
      idempotencyKey: _requiredString(json, 'idempotencyKey'),
      grossWageGold: _requiredInt(json, 'grossWageGold'),
      netWageGold: _requiredInt(json, 'netWageGold'),
      taxGold: _requiredInt(json, 'taxGold'),
      requiredEnergy: _requiredInt(json, 'requiredEnergy'),
      productivityReward: _requiredInt(json, 'productivityReward'),
      status: _requiredString(json, 'status'),
      workDate: _requiredDateTime(json, 'workDate'),
      workedAt: _requiredDateTime(json, 'workedAt'),
      paidAt: _optionalDateTime(json, 'paidAt'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class CompanyJobMutationResult {
  final bool completed;
  final String message;
  final CompanyJobPosting? job;
  final CompanyAssets? assets;

  CompanyJobMutationResult({
    required this.completed,
    required this.message,
    required this.job,
    required this.assets,
  });

  factory CompanyJobMutationResult.fromJson(Map<String, dynamic> json) {
    return CompanyJobMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      job: json['job'] == null
          ? null
          : CompanyJobPosting.fromJson(_requiredMap(json['job'])),
      assets: json['assets'] == null
          ? null
          : CompanyAssets.fromJson(_requiredMap(json['assets'])),
    );
  }
}

class CompanyWorkResult {
  final bool completed;
  final String message;
  final CompanyJobPosting job;
  final CompanyWorkRecord workRecord;
  final CompanyAssets? assets;
  final InventorySummary? wallet;
  final List<CountryTaxCollection> taxCollections;

  CompanyWorkResult({
    required this.completed,
    required this.message,
    required this.job,
    required this.workRecord,
    required this.assets,
    required this.wallet,
    required this.taxCollections,
  });

  factory CompanyWorkResult.fromJson(Map<String, dynamic> json) {
    return CompanyWorkResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      job: CompanyJobPosting.fromJson(_requiredMap(json['job'])),
      workRecord: CompanyWorkRecord.fromJson(_requiredMap(json['workRecord'])),
      assets: json['assets'] == null
          ? null
          : CompanyAssets.fromJson(_requiredMap(json['assets'])),
      wallet: json['wallet'] == null
          ? null
          : InventorySummary.fromJson(_requiredMap(json['wallet'])),
      taxCollections: json['taxCollections'] is List<dynamic>
          ? (json['taxCollections'] as List<dynamic>)
              .map(
                  (entry) => CountryTaxCollection.fromJson(_requiredMap(entry)))
              .toList()
          : <CountryTaxCollection>[],
    );
  }
}

class MilitaryUnitList {
  final List<MilitaryUnit> units;
  final DateTime updatedAt;

  MilitaryUnitList({
    required this.units,
    required this.updatedAt,
  });

  List<MilitaryUnit> get myUnits =>
      units.where((unit) => unit.isMember).toList();

  factory MilitaryUnitList.fromJson(Map<String, dynamic> json) {
    final units = _requiredList(json, 'units')
        .map((unit) => MilitaryUnit.fromJson(_requiredMap(unit)))
        .toList();
    return MilitaryUnitList(
      units: units,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MilitaryUnit {
  final String unitId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String name;
  final String description;
  final String status;
  final String createdByPlayerId;
  final int memberCount;
  final int totalBattleDamage;
  final int activeOrderCount;
  final String? viewerRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  MilitaryUnit({
    required this.unitId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.name,
    required this.description,
    required this.status,
    required this.createdByPlayerId,
    required this.memberCount,
    required this.totalBattleDamage,
    required this.activeOrderCount,
    required this.viewerRole,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  bool get isMember => viewerRole != null && viewerRole!.isNotEmpty;

  bool get canManageOrders =>
      viewerRole == 'commander' || viewerRole == 'officer';

  factory MilitaryUnit.fromJson(Map<String, dynamic> json) {
    return MilitaryUnit(
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      status: _requiredString(json, 'status'),
      createdByPlayerId: _requiredString(json, 'createdByPlayerId',
          fallbackField: 'created_by_player_id'),
      memberCount:
          _requiredInt(json, 'memberCount', fallbackField: 'member_count'),
      totalBattleDamage: _requiredInt(json, 'totalBattleDamage',
          fallbackField: 'total_battle_damage'),
      activeOrderCount: _requiredInt(json, 'activeOrderCount',
          fallbackField: 'active_order_count'),
      viewerRole: _optionalNullableString(json, 'viewerRole') ??
          _optionalNullableString(json, 'viewer_role'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MilitaryUnitDetails {
  final MilitaryUnit unit;
  final List<UnitMember> members;
  final List<UnitOrder> orders;
  final List<UnitBattleTotal> battleTotals;
  final List<UnitDivision> divisions;
  final List<DeploymentOrder> deploymentOrders;
  final DateTime updatedAt;

  MilitaryUnitDetails({
    required this.unit,
    required this.members,
    required this.orders,
    required this.battleTotals,
    required this.divisions,
    required this.deploymentOrders,
    required this.updatedAt,
  });

  factory MilitaryUnitDetails.fromJson(Map<String, dynamic> json) {
    final members = _requiredList(json, 'members')
        .map((member) => UnitMember.fromJson(_requiredMap(member)))
        .toList();
    final orders = _requiredList(json, 'orders')
        .map((order) => UnitOrder.fromJson(_requiredMap(order)))
        .toList();
    final battleTotals = _requiredList(json, 'battleTotals')
        .map((total) => UnitBattleTotal.fromJson(_requiredMap(total)))
        .toList();
    final divisions = json['divisions'] is List<dynamic>
        ? (json['divisions'] as List<dynamic>)
            .map((division) => UnitDivision.fromJson(_requiredMap(division)))
            .toList()
        : <UnitDivision>[];
    final deploymentOrders = json['deploymentOrders'] is List<dynamic>
        ? (json['deploymentOrders'] as List<dynamic>)
            .map((order) => DeploymentOrder.fromJson(_requiredMap(order)))
            .toList()
        : <DeploymentOrder>[];
    return MilitaryUnitDetails(
      unit: MilitaryUnit.fromJson(_requiredMap(json['unit'])),
      members: members,
      orders: orders,
      battleTotals: battleTotals,
      divisions: divisions,
      deploymentOrders: deploymentOrders,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class UnitMember {
  final String memberId;
  final String unitId;
  final String playerId;
  final String role;
  final String status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime updatedAt;

  UnitMember({
    required this.memberId,
    required this.unitId,
    required this.playerId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.leftAt,
    required this.updatedAt,
  });

  bool get isActive => leftAt == null && status == 'active';

  factory UnitMember.fromJson(Map<String, dynamic> json) {
    return UnitMember(
      memberId: _requiredString(json, 'memberId', fallbackField: 'member_id'),
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      role: _requiredString(json, 'role'),
      status: _requiredString(json, 'status'),
      joinedAt: _requiredDateTime(json, 'joinedAt'),
      leftAt: _optionalDateTime(json, 'leftAt') ??
          _optionalDateTime(json, 'left_at'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class UnitOrder {
  final String orderId;
  final String unitId;
  final String issuedByPlayerId;
  final String orderType;
  final String title;
  final String description;
  final String? targetBattleId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  UnitOrder({
    required this.orderId,
    required this.unitId,
    required this.issuedByPlayerId,
    required this.orderType,
    required this.title,
    required this.description,
    required this.targetBattleId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
  });

  bool get isActive => status == 'active';

  factory UnitOrder.fromJson(Map<String, dynamic> json) {
    return UnitOrder(
      orderId: _requiredString(json, 'orderId', fallbackField: 'order_id'),
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      issuedByPlayerId: _requiredString(json, 'issuedByPlayerId',
          fallbackField: 'issued_by_player_id'),
      orderType:
          _requiredString(json, 'orderType', fallbackField: 'order_type'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      targetBattleId: _optionalNullableString(json, 'targetBattleId') ??
          _optionalNullableString(json, 'target_battle_id'),
      status: _requiredString(json, 'status'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      completedAt: _optionalDateTime(json, 'completedAt') ??
          _optionalDateTime(json, 'completed_at'),
    );
  }
}

class UnitBattleTotal {
  final String unitId;
  final String unitName;
  final String battleId;
  final String battleName;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String side;
  final int totalDamage;
  final int contributionCount;
  final int memberCount;
  final DateTime? lastContributedAt;
  final DateTime updatedAt;

  UnitBattleTotal({
    required this.unitId,
    required this.unitName,
    required this.battleId,
    required this.battleName,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.side,
    required this.totalDamage,
    required this.contributionCount,
    required this.memberCount,
    required this.lastContributedAt,
    required this.updatedAt,
  });

  factory UnitBattleTotal.fromJson(Map<String, dynamic> json) {
    return UnitBattleTotal(
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      unitName: _requiredString(json, 'unitName', fallbackField: 'unit_name'),
      battleId: _requiredString(json, 'battleId', fallbackField: 'battle_id'),
      battleName:
          _requiredString(json, 'battleName', fallbackField: 'battle_name'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      side: _requiredString(json, 'side'),
      totalDamage:
          _requiredInt(json, 'totalDamage', fallbackField: 'total_damage'),
      contributionCount: _requiredInt(json, 'contributionCount',
          fallbackField: 'contribution_count'),
      memberCount:
          _requiredInt(json, 'memberCount', fallbackField: 'member_count'),
      lastContributedAt: _optionalDateTime(json, 'lastContributedAt') ??
          _optionalDateTime(json, 'last_contributed_at'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MilitaryUnitLeaderboard {
  final List<UnitBattleTotal> entries;
  final DateTime updatedAt;

  MilitaryUnitLeaderboard({
    required this.entries,
    required this.updatedAt,
  });

  factory MilitaryUnitLeaderboard.fromJson(Map<String, dynamic> json) {
    final entries = _requiredList(json, 'entries')
        .map((entry) => UnitBattleTotal.fromJson(_requiredMap(entry)))
        .toList();
    return MilitaryUnitLeaderboard(
      entries: entries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class UnitBattleContribution {
  final String unitContributionId;
  final String unitId;
  final String unitName;
  final String battleId;
  final String battleName;
  final String battleContributionId;
  final String playerId;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String side;
  final int damage;
  final int energySpent;
  final DateTime createdAt;

  UnitBattleContribution({
    required this.unitContributionId,
    required this.unitId,
    required this.unitName,
    required this.battleId,
    required this.battleName,
    required this.battleContributionId,
    required this.playerId,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.side,
    required this.damage,
    required this.energySpent,
    required this.createdAt,
  });

  factory UnitBattleContribution.fromJson(Map<String, dynamic> json) {
    return UnitBattleContribution(
      unitContributionId: _requiredString(json, 'unitContributionId',
          fallbackField: 'unit_contribution_id'),
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      unitName: _requiredString(json, 'unitName', fallbackField: 'unit_name'),
      battleId: _requiredString(json, 'battleId', fallbackField: 'battle_id'),
      battleName:
          _requiredString(json, 'battleName', fallbackField: 'battle_name'),
      battleContributionId: _requiredString(json, 'battleContributionId',
          fallbackField: 'battle_contribution_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      countryId:
          _requiredString(json, 'countryId', fallbackField: 'country_id'),
      countryName:
          _requiredString(json, 'countryName', fallbackField: 'country_name'),
      countryCode:
          _requiredString(json, 'countryCode', fallbackField: 'country_code'),
      side: _requiredString(json, 'side'),
      damage: _requiredInt(json, 'damage'),
      energySpent:
          _requiredInt(json, 'energySpent', fallbackField: 'energy_spent'),
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }
}

class UnitBattleContributions {
  final String unitId;
  final List<UnitBattleContribution> contributions;
  final DateTime updatedAt;

  UnitBattleContributions({
    required this.unitId,
    required this.contributions,
    required this.updatedAt,
  });

  factory UnitBattleContributions.fromJson(Map<String, dynamic> json) {
    final contributions = _requiredList(json, 'contributions')
        .map((entry) => UnitBattleContribution.fromJson(_requiredMap(entry)))
        .toList();
    return UnitBattleContributions(
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      contributions: contributions,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class UnitDivision {
  final String divisionId;
  final String unitId;
  final String unitName;
  final String campaignId;
  final String campaignName;
  final String name;
  final String divisionRole;
  final String status;
  final int memberCount;
  final int assignedStrength;
  final String createdByPlayerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UnitDivision({
    required this.divisionId,
    required this.unitId,
    required this.unitName,
    required this.campaignId,
    required this.campaignName,
    required this.name,
    required this.divisionRole,
    required this.status,
    required this.memberCount,
    required this.assignedStrength,
    required this.createdByPlayerId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDeployed => status.toLowerCase() == 'deployed';

  factory UnitDivision.fromJson(Map<String, dynamic> json) {
    return UnitDivision(
      divisionId:
          _requiredString(json, 'divisionId', fallbackField: 'division_id'),
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      unitName: _requiredString(json, 'unitName', fallbackField: 'unit_name'),
      campaignId:
          _requiredString(json, 'campaignId', fallbackField: 'campaign_id'),
      campaignName:
          _requiredString(json, 'campaignName', fallbackField: 'campaign_name'),
      name: _requiredString(json, 'name'),
      divisionRole:
          _requiredString(json, 'divisionRole', fallbackField: 'division_role'),
      status: _requiredString(json, 'status'),
      memberCount:
          _requiredInt(json, 'memberCount', fallbackField: 'member_count'),
      assignedStrength: _requiredInt(json, 'assignedStrength',
          fallbackField: 'assigned_strength'),
      createdByPlayerId: _requiredString(json, 'createdByPlayerId',
          fallbackField: 'created_by_player_id'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class UnitDivisionList {
  final String unitId;
  final List<UnitDivision> divisions;
  final DateTime updatedAt;

  UnitDivisionList({
    required this.unitId,
    required this.divisions,
    required this.updatedAt,
  });

  factory UnitDivisionList.fromJson(Map<String, dynamic> json) {
    final divisions = _requiredList(json, 'divisions')
        .map((division) => UnitDivision.fromJson(_requiredMap(division)))
        .toList();
    return UnitDivisionList(
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      divisions: divisions,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class DeploymentOrder {
  final String deploymentOrderId;
  final String unitId;
  final String? divisionId;
  final String? campaignId;
  final String? targetBattleId;
  final String issuedByPlayerId;
  final String orderType;
  final String title;
  final String description;
  final int troopCommitment;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? executedAt;

  DeploymentOrder({
    required this.deploymentOrderId,
    required this.unitId,
    required this.divisionId,
    required this.campaignId,
    required this.targetBattleId,
    required this.issuedByPlayerId,
    required this.orderType,
    required this.title,
    required this.description,
    required this.troopCommitment,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.executedAt,
  });

  bool get isIssued => status.toLowerCase() == 'issued';

  factory DeploymentOrder.fromJson(Map<String, dynamic> json) {
    return DeploymentOrder(
      deploymentOrderId: _requiredString(json, 'deploymentOrderId',
          fallbackField: 'deployment_order_id'),
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      divisionId: _optionalNullableString(json, 'divisionId') ??
          _optionalNullableString(json, 'division_id'),
      campaignId: _optionalNullableString(json, 'campaignId') ??
          _optionalNullableString(json, 'campaign_id'),
      targetBattleId: _optionalNullableString(json, 'targetBattleId') ??
          _optionalNullableString(json, 'target_battle_id'),
      issuedByPlayerId: _requiredString(json, 'issuedByPlayerId',
          fallbackField: 'issued_by_player_id'),
      orderType:
          _requiredString(json, 'orderType', fallbackField: 'order_type'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      troopCommitment: _requiredInt(json, 'troopCommitment',
          fallbackField: 'troop_commitment'),
      status: _requiredString(json, 'status'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
      executedAt: _optionalDateTime(json, 'executedAt') ??
          _optionalDateTime(json, 'executed_at'),
    );
  }
}

class DeploymentOrderList {
  final String unitId;
  final List<DeploymentOrder> orders;
  final DateTime updatedAt;

  DeploymentOrderList({
    required this.unitId,
    required this.orders,
    required this.updatedAt,
  });

  factory DeploymentOrderList.fromJson(Map<String, dynamic> json) {
    final orders = _requiredList(json, 'orders')
        .map((order) => DeploymentOrder.fromJson(_requiredMap(order)))
        .toList();
    return DeploymentOrderList(
      unitId: _requiredString(json, 'unitId', fallbackField: 'unit_id'),
      orders: orders,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class UnitDivisionMutationResult {
  final bool completed;
  final String message;
  final UnitDivision? division;
  final DateTime updatedAt;

  UnitDivisionMutationResult({
    required this.completed,
    required this.message,
    required this.division,
    required this.updatedAt,
  });

  factory UnitDivisionMutationResult.fromJson(Map<String, dynamic> json) {
    return UnitDivisionMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      division: json['division'] == null
          ? null
          : UnitDivision.fromJson(_requiredMap(json['division'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class DeploymentOrderMutationResult {
  final bool completed;
  final String message;
  final DeploymentOrder? order;
  final DateTime updatedAt;

  DeploymentOrderMutationResult({
    required this.completed,
    required this.message,
    required this.order,
    required this.updatedAt,
  });

  factory DeploymentOrderMutationResult.fromJson(Map<String, dynamic> json) {
    return DeploymentOrderMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      order: json['order'] == null
          ? null
          : DeploymentOrder.fromJson(_requiredMap(json['order'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MilitaryUnitMutationResult {
  final bool completed;
  final String message;
  final MilitaryUnit? unit;
  final DateTime updatedAt;

  MilitaryUnitMutationResult({
    required this.completed,
    required this.message,
    required this.unit,
    required this.updatedAt,
  });

  factory MilitaryUnitMutationResult.fromJson(Map<String, dynamic> json) {
    return MilitaryUnitMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      unit: json['unit'] == null
          ? null
          : MilitaryUnit.fromJson(_requiredMap(json['unit'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class MilitaryUnitOrderMutationResult {
  final bool completed;
  final String message;
  final MilitaryUnit? unit;
  final UnitOrder? order;
  final DateTime updatedAt;

  MilitaryUnitOrderMutationResult({
    required this.completed,
    required this.message,
    required this.unit,
    required this.order,
    required this.updatedAt,
  });

  factory MilitaryUnitOrderMutationResult.fromJson(Map<String, dynamic> json) {
    return MilitaryUnitOrderMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      unit: json['unit'] == null
          ? null
          : MilitaryUnit.fromJson(_requiredMap(json['unit'])),
      order: json['order'] == null
          ? null
          : UnitOrder.fromJson(_requiredMap(json['order'])),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class PublicPlayerProfile {
  final String playerId;
  final String username;
  final int level;
  final int experience;
  final int strength;
  final int energy;
  final int maxEnergy;
  final int rank;
  final EquippedWeapon? equippedWeapon;
  final DateTime createdOn;
  final DateTime updatedAt;

  PublicPlayerProfile({
    required this.playerId,
    required this.username,
    required this.level,
    required this.experience,
    required this.strength,
    required this.energy,
    required this.maxEnergy,
    required this.rank,
    required this.equippedWeapon,
    required this.createdOn,
    required this.updatedAt,
  });

  factory PublicPlayerProfile.fromJson(Map<String, dynamic> json) {
    return PublicPlayerProfile(
      playerId: _requiredString(json, 'playerId'),
      username: _requiredString(json, 'username'),
      level: _requiredInt(json, 'level'),
      experience: _requiredInt(json, 'experience'),
      strength: _requiredInt(json, 'strength'),
      energy: _requiredInt(json, 'energy'),
      maxEnergy: _requiredInt(json, 'maxEnergy'),
      rank: _optionalInt(json, 'rank'),
      equippedWeapon: json['equippedWeapon'] == null
          ? null
          : EquippedWeapon.fromJson(_requiredMap(json['equippedWeapon'])),
      createdOn:
          _requiredDateTime(json, 'createdOn', fallbackField: 'created_on'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RankingsLeaderboard {
  final String sortBy;
  final int limit;
  final int totalPlayers;
  final List<RankingEntry> entries;
  final DateTime updatedAt;

  RankingsLeaderboard({
    required this.sortBy,
    required this.limit,
    required this.totalPlayers,
    required this.entries,
    required this.updatedAt,
  });

  factory RankingsLeaderboard.fromJson(Map<String, dynamic> json) {
    final entries = _requiredList(json, 'entries')
        .map((entry) => RankingEntry.fromJson(_requiredMap(entry)))
        .toList();
    return RankingsLeaderboard(
      sortBy: _requiredString(json, 'sortBy'),
      limit: _requiredInt(json, 'limit'),
      totalPlayers: _requiredInt(json, 'totalPlayers'),
      entries: entries,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RankingEntry {
  final int rank;
  final String playerId;
  final String username;
  final int level;
  final int experience;
  final int strength;
  final int energy;
  final int maxEnergy;
  final DateTime updatedAt;

  RankingEntry({
    required this.rank,
    required this.playerId,
    required this.username,
    required this.level,
    required this.experience,
    required this.strength,
    required this.energy,
    required this.maxEnergy,
    required this.updatedAt,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      rank: _requiredInt(json, 'rank'),
      playerId: _requiredString(json, 'playerId'),
      username: _requiredString(json, 'username'),
      level: _requiredInt(json, 'level'),
      experience: _requiredInt(json, 'experience'),
      strength: _requiredInt(json, 'strength'),
      energy: _requiredInt(json, 'energy'),
      maxEnergy: _requiredInt(json, 'maxEnergy'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class NewspaperCatalog {
  final String? playerId;
  final List<Newspaper> newspapers;
  final DateTime updatedAt;

  NewspaperCatalog({
    required this.playerId,
    required this.newspapers,
    required this.updatedAt,
  });

  factory NewspaperCatalog.fromJson(Map<String, dynamic> json) {
    final newspapers = _requiredList(json, 'newspapers')
        .map((newspaper) => Newspaper.fromJson(_requiredMap(newspaper)))
        .toList();
    return NewspaperCatalog(
      playerId: _optionalNullableString(json, 'playerId'),
      newspapers: newspapers,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class Newspaper {
  final String newspaperId;
  final String ownerPlayerId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int subscriberCount;
  final int articleCount;
  final bool isSubscribed;

  Newspaper({
    required this.newspaperId,
    required this.ownerPlayerId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.subscriberCount,
    required this.articleCount,
    required this.isSubscribed,
  });

  factory Newspaper.fromJson(Map<String, dynamic> json) {
    return Newspaper(
      newspaperId: _requiredString(json, 'newspaperId'),
      ownerPlayerId: _requiredString(json, 'ownerPlayerId'),
      name: _requiredString(json, 'name'),
      description: _optionalString(json, 'description', defaultValue: ''),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      subscriberCount: _requiredInt(json, 'subscriberCount'),
      articleCount: _requiredInt(json, 'articleCount'),
      isSubscribed: _optionalBool(json, 'isSubscribed'),
    );
  }
}

class NewspaperArticleList {
  final String newspaperId;
  final List<NewspaperArticle> articles;
  final DateTime updatedAt;

  NewspaperArticleList({
    required this.newspaperId,
    required this.articles,
    required this.updatedAt,
  });

  factory NewspaperArticleList.fromJson(Map<String, dynamic> json) {
    final articles = _requiredList(json, 'articles')
        .map((article) => NewspaperArticle.fromJson(_requiredMap(article)))
        .toList();
    return NewspaperArticleList(
      newspaperId: _requiredString(json, 'newspaperId'),
      articles: articles,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class NewspaperArticle {
  final String articleId;
  final String newspaperId;
  final String newspaperName;
  final String newspaperOwnerPlayerId;
  final String authorPlayerId;
  final String title;
  final String content;
  final DateTime publishedAt;
  final DateTime updatedAt;
  final int voteScore;
  final int upvotes;
  final int downvotes;
  final int? playerVote;
  final int commentCount;
  final List<NewspaperComment> comments;

  NewspaperArticle({
    required this.articleId,
    required this.newspaperId,
    required this.newspaperName,
    required this.newspaperOwnerPlayerId,
    required this.authorPlayerId,
    required this.title,
    required this.content,
    required this.publishedAt,
    required this.updatedAt,
    required this.voteScore,
    required this.upvotes,
    required this.downvotes,
    required this.playerVote,
    required this.commentCount,
    required this.comments,
  });

  String get excerpt {
    final singleLine = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= 180
        ? singleLine
        : '${singleLine.substring(0, 180)}…';
  }

  factory NewspaperArticle.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'];
    final comments = rawComments is List<dynamic>
        ? rawComments
            .map((comment) => NewspaperComment.fromJson(_requiredMap(comment)))
            .toList()
        : <NewspaperComment>[];
    return NewspaperArticle(
      articleId: _requiredString(json, 'articleId'),
      newspaperId: _requiredString(json, 'newspaperId'),
      newspaperName: _requiredString(json, 'newspaperName'),
      newspaperOwnerPlayerId: _requiredString(json, 'newspaperOwnerPlayerId'),
      authorPlayerId: _requiredString(json, 'authorPlayerId'),
      title: _requiredString(json, 'title'),
      content: _requiredString(json, 'content'),
      publishedAt: _requiredDateTime(json, 'publishedAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      voteScore: _requiredInt(json, 'voteScore'),
      upvotes: _requiredInt(json, 'upvotes'),
      downvotes: _requiredInt(json, 'downvotes'),
      playerVote: _optionalNullableInt(json, 'playerVote'),
      commentCount: _requiredInt(json, 'commentCount'),
      comments: comments,
    );
  }
}

class NewspaperComment {
  final String commentId;
  final String articleId;
  final String authorPlayerId;
  final String content;
  final DateTime createdAt;

  NewspaperComment({
    required this.commentId,
    required this.articleId,
    required this.authorPlayerId,
    required this.content,
    required this.createdAt,
  });

  factory NewspaperComment.fromJson(Map<String, dynamic> json) {
    return NewspaperComment(
      commentId: _requiredString(json, 'commentId'),
      articleId: _requiredString(json, 'articleId'),
      authorPlayerId: _requiredString(json, 'authorPlayerId'),
      content: _requiredString(json, 'content'),
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }
}

class NewspaperMutationResult {
  final bool completed;
  final String message;
  final Newspaper newspaper;

  NewspaperMutationResult({
    required this.completed,
    required this.message,
    required this.newspaper,
  });

  factory NewspaperMutationResult.fromJson(Map<String, dynamic> json) {
    return NewspaperMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      newspaper: Newspaper.fromJson(_requiredMap(json['newspaper'])),
    );
  }
}

class ArticlePublicationResult {
  final bool completed;
  final String message;
  final NewspaperArticle article;

  ArticlePublicationResult({
    required this.completed,
    required this.message,
    required this.article,
  });

  factory ArticlePublicationResult.fromJson(Map<String, dynamic> json) {
    return ArticlePublicationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      article: NewspaperArticle.fromJson(_requiredMap(json['article'])),
    );
  }
}

class ArticleCommentResult {
  final bool completed;
  final String message;
  final NewspaperComment comment;
  final NewspaperArticle article;

  ArticleCommentResult({
    required this.completed,
    required this.message,
    required this.comment,
    required this.article,
  });

  factory ArticleCommentResult.fromJson(Map<String, dynamic> json) {
    return ArticleCommentResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      comment: NewspaperComment.fromJson(_requiredMap(json['comment'])),
      article: NewspaperArticle.fromJson(_requiredMap(json['article'])),
    );
  }
}

class ArticleVoteResult {
  final bool completed;
  final String message;
  final NewspaperArticle article;

  ArticleVoteResult({
    required this.completed,
    required this.message,
    required this.article,
  });

  factory ArticleVoteResult.fromJson(Map<String, dynamic> json) {
    return ArticleVoteResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      article: NewspaperArticle.fromJson(_requiredMap(json['article'])),
    );
  }
}

class NewspaperSubscriptionResult {
  final bool completed;
  final String message;
  final Newspaper newspaper;
  final bool isSubscribed;

  NewspaperSubscriptionResult({
    required this.completed,
    required this.message,
    required this.newspaper,
    required this.isSubscribed,
  });

  factory NewspaperSubscriptionResult.fromJson(Map<String, dynamic> json) {
    return NewspaperSubscriptionResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      newspaper: Newspaper.fromJson(_requiredMap(json['newspaper'])),
      isSubscribed: _requiredBool(json, 'isSubscribed'),
    );
  }
}

class ContentReportResult {
  final bool completed;
  final String message;
  final String itemId;
  final String status;
  final int reportCount;

  ContentReportResult({
    required this.completed,
    required this.message,
    required this.itemId,
    required this.status,
    required this.reportCount,
  });

  factory ContentReportResult.fromJson(Map<String, dynamic> json) {
    return ContentReportResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      itemId: _requiredString(json, 'itemId'),
      status: _requiredString(json, 'status'),
      reportCount: _optionalInt(json, 'reportCount'),
    );
  }
}

class DiplomacyStatus {
  final String playerId;
  final PlayerCitizenship? citizenship;
  final DiplomacyAuthorization authorization;
  final List<DiplomaticTreaty> activeTreaties;
  final List<DiplomaticTreaty> pendingTreaties;
  final List<DiplomaticRelation> relationships;
  final DateTime updatedAt;

  DiplomacyStatus({
    required this.playerId,
    required this.citizenship,
    required this.authorization,
    required this.activeTreaties,
    required this.pendingTreaties,
    required this.relationships,
    required this.updatedAt,
  });

  String? get countryId => citizenship?.countryId;

  factory DiplomacyStatus.fromJson(Map<String, dynamic> json) {
    return DiplomacyStatus(
      playerId: _requiredString(json, 'playerId'),
      citizenship: json['citizenship'] == null
          ? null
          : PlayerCitizenship.fromJson(_requiredMap(json['citizenship'])),
      authorization:
          DiplomacyAuthorization.fromJson(_requiredMap(json['authorization'])),
      activeTreaties: _requiredList(json, 'activeTreaties')
          .map((treaty) => DiplomaticTreaty.fromJson(_requiredMap(treaty)))
          .toList(),
      pendingTreaties: _requiredList(json, 'pendingTreaties')
          .map((treaty) => DiplomaticTreaty.fromJson(_requiredMap(treaty)))
          .toList(),
      relationships: _requiredList(json, 'relationships')
          .map(
              (relation) => DiplomaticRelation.fromJson(_requiredMap(relation)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class DiplomacyAuthorization {
  final bool canPropose;
  final bool canRatify;
  final bool canTerminate;
  final String? role;
  final String message;

  DiplomacyAuthorization({
    required this.canPropose,
    required this.canRatify,
    required this.canTerminate,
    required this.role,
    required this.message,
  });

  factory DiplomacyAuthorization.fromJson(Map<String, dynamic> json) {
    return DiplomacyAuthorization(
      canPropose: _requiredBool(json, 'canPropose'),
      canRatify: _requiredBool(json, 'canRatify'),
      canTerminate: _requiredBool(json, 'canTerminate'),
      role: _optionalNullableString(json, 'role'),
      message: _requiredString(json, 'message'),
    );
  }
}

class DiplomaticTreatyList {
  final List<DiplomaticTreaty> treaties;
  final DateTime updatedAt;

  DiplomaticTreatyList({
    required this.treaties,
    required this.updatedAt,
  });

  factory DiplomaticTreatyList.fromJson(Map<String, dynamic> json) {
    return DiplomaticTreatyList(
      treaties: _requiredList(json, 'treaties')
          .map((treaty) => DiplomaticTreaty.fromJson(_requiredMap(treaty)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class DiplomaticTreaty {
  final String treatyId;
  final String initiatorCountryId;
  final String initiatorCountryName;
  final String initiatorCountryCode;
  final String targetCountryId;
  final String targetCountryName;
  final String targetCountryCode;
  final String treatyType;
  final String status;
  final String title;
  final String terms;
  final String? sourceLawId;
  final String proposedByPlayerId;
  final DateTime proposedAt;
  final String? ratifiedByPlayerId;
  final DateTime? ratifiedAt;
  final String? rejectedByPlayerId;
  final DateTime? rejectedAt;
  final String rejectionReason;
  final String? terminatedByPlayerId;
  final DateTime? terminatedAt;
  final String terminationReason;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final int durationDays;
  final int treasuryAmount;
  final String treasuryTransferStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiplomaticTreaty({
    required this.treatyId,
    required this.initiatorCountryId,
    required this.initiatorCountryName,
    required this.initiatorCountryCode,
    required this.targetCountryId,
    required this.targetCountryName,
    required this.targetCountryCode,
    required this.treatyType,
    required this.status,
    required this.title,
    required this.terms,
    required this.sourceLawId,
    required this.proposedByPlayerId,
    required this.proposedAt,
    required this.ratifiedByPlayerId,
    required this.ratifiedAt,
    required this.rejectedByPlayerId,
    required this.rejectedAt,
    required this.rejectionReason,
    required this.terminatedByPlayerId,
    required this.terminatedAt,
    required this.terminationReason,
    required this.startsAt,
    required this.expiresAt,
    required this.durationDays,
    required this.treasuryAmount,
    required this.treasuryTransferStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isProposed => status == 'proposed';
  bool get isEmbargo => treatyType == 'embargo';

  String get displayType => treatyType
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String counterpartyName(String countryId) => countryId == initiatorCountryId
      ? targetCountryName
      : initiatorCountryName;

  bool isPendingFor(String countryId) =>
      isProposed && targetCountryId == countryId;

  factory DiplomaticTreaty.fromJson(Map<String, dynamic> json) {
    return DiplomaticTreaty(
      treatyId: _requiredString(json, 'treatyId'),
      initiatorCountryId: _requiredString(json, 'initiatorCountryId'),
      initiatorCountryName: _requiredString(json, 'initiatorCountryName'),
      initiatorCountryCode: _requiredString(json, 'initiatorCountryCode'),
      targetCountryId: _requiredString(json, 'targetCountryId'),
      targetCountryName: _requiredString(json, 'targetCountryName'),
      targetCountryCode: _requiredString(json, 'targetCountryCode'),
      treatyType: _requiredString(json, 'treatyType'),
      status: _requiredString(json, 'status'),
      title: _requiredString(json, 'title'),
      terms: _requiredString(json, 'terms'),
      sourceLawId: _optionalNullableString(json, 'sourceLawId'),
      proposedByPlayerId: _requiredString(json, 'proposedByPlayerId'),
      proposedAt: _requiredDateTime(json, 'proposedAt'),
      ratifiedByPlayerId: _optionalNullableString(json, 'ratifiedByPlayerId'),
      ratifiedAt: _optionalDateTime(json, 'ratifiedAt'),
      rejectedByPlayerId: _optionalNullableString(json, 'rejectedByPlayerId'),
      rejectedAt: _optionalDateTime(json, 'rejectedAt'),
      rejectionReason:
          _optionalString(json, 'rejectionReason', defaultValue: ''),
      terminatedByPlayerId:
          _optionalNullableString(json, 'terminatedByPlayerId'),
      terminatedAt: _optionalDateTime(json, 'terminatedAt'),
      terminationReason:
          _optionalString(json, 'terminationReason', defaultValue: ''),
      startsAt: _optionalDateTime(json, 'startsAt'),
      expiresAt: _optionalDateTime(json, 'expiresAt'),
      durationDays: _requiredInt(json, 'durationDays'),
      treasuryAmount: _requiredInt(json, 'treasuryAmount'),
      treasuryTransferStatus: _requiredString(json, 'treasuryTransferStatus'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class DiplomaticRelation {
  final String relationId;
  final String countryId;
  final String counterpartyCountryId;
  final String counterpartyCountryName;
  final String counterpartyCountryCode;
  final String relationshipType;
  final String direction;
  final String sourceTreatyId;
  final DateTime? activeUntil;

  DiplomaticRelation({
    required this.relationId,
    required this.countryId,
    required this.counterpartyCountryId,
    required this.counterpartyCountryName,
    required this.counterpartyCountryCode,
    required this.relationshipType,
    required this.direction,
    required this.sourceTreatyId,
    required this.activeUntil,
  });

  String get displayType => relationshipType
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  factory DiplomaticRelation.fromJson(Map<String, dynamic> json) {
    return DiplomaticRelation(
      relationId: _requiredString(json, 'relationId'),
      countryId: _requiredString(json, 'countryId'),
      counterpartyCountryId: _requiredString(json, 'counterpartyCountryId'),
      counterpartyCountryName: _requiredString(json, 'counterpartyCountryName'),
      counterpartyCountryCode: _requiredString(json, 'counterpartyCountryCode'),
      relationshipType: _requiredString(json, 'relationshipType'),
      direction: _requiredString(json, 'direction'),
      sourceTreatyId: _requiredString(json, 'sourceTreatyId'),
      activeUntil: _optionalDateTime(json, 'activeUntil'),
    );
  }
}

class DiplomacyMutationResult {
  final bool completed;
  final String message;
  final DiplomaticTreaty? treaty;
  final DiplomacyAuthorization? authorization;
  final int statusCode;
  final DateTime updatedAt;

  DiplomacyMutationResult({
    required this.completed,
    required this.message,
    required this.treaty,
    required this.authorization,
    required this.statusCode,
    required this.updatedAt,
  });

  factory DiplomacyMutationResult.fromJson(Map<String, dynamic> json) {
    return DiplomacyMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      treaty: json['treaty'] == null
          ? null
          : DiplomaticTreaty.fromJson(_requiredMap(json['treaty'])),
      authorization: json['authorization'] == null
          ? null
          : DiplomacyAuthorization.fromJson(
              _requiredMap(json['authorization'])),
      statusCode: _optionalInt(json, 'statusCode'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

String _requiredString(
  Map<String, dynamic> json,
  String field, {
  String? fallbackField,
}) {
  final value =
      json[field] ?? (fallbackField == null ? null : json[fallbackField]);
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required game field "$field".');
}

int _requiredInt(
  Map<String, dynamic> json,
  String field, {
  String? fallbackField,
}) {
  final value =
      json[field] ?? (fallbackField == null ? null : json[fallbackField]);
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }

  throw FormatException('Missing required integer game field "$field".');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing required boolean game field "$field".');
}

bool _optionalBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value is bool ? value : false;
}

String _optionalString(
  Map<String, dynamic> json,
  String field, {
  required String defaultValue,
}) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  return defaultValue;
}

String? _optionalNullableString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  return null;
}

int _optionalInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

int? _optionalNullableInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

DateTime _requiredDateTime(
  Map<String, dynamic> json,
  String field, {
  String? fallbackField,
}) {
  final value =
      json[field] ?? (fallbackField == null ? null : json[fallbackField]);
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Missing required date game field "$field".');
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

  throw FormatException('Missing required list game field "$field".');
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  throw const FormatException('Missing required object game field.');
}

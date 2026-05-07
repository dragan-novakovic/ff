class AdminPlayerSearchResponse {
  final String query;
  final int limit;
  final List<AdminPlayerSearchEntry> players;
  final DateTime updatedAt;

  AdminPlayerSearchResponse({
    required this.query,
    required this.limit,
    required this.players,
    required this.updatedAt,
  });

  factory AdminPlayerSearchResponse.fromJson(Map<String, dynamic> json) {
    return AdminPlayerSearchResponse(
      query: (json['query'] ?? '').toString(),
      limit: _int(json['limit']),
      players: _list(json['players'])
          .map((item) => AdminPlayerSearchEntry.fromJson(_map(item)))
          .toList(),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminPlayerSearchEntry {
  final String playerId;
  final String username;
  final String email;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int? level;
  final int? experience;
  final int? strength;
  final int? energy;
  final int? maxEnergy;
  final DateTime? playerUpdatedAt;
  final int? walletGold;
  final int activeModerationCount;

  AdminPlayerSearchEntry({
    required this.playerId,
    required this.username,
    required this.email,
    required this.createdAt,
    required this.lastLoginAt,
    required this.level,
    required this.experience,
    required this.strength,
    required this.energy,
    required this.maxEnergy,
    required this.playerUpdatedAt,
    required this.walletGold,
    required this.activeModerationCount,
  });

  factory AdminPlayerSearchEntry.fromJson(Map<String, dynamic> json) {
    return AdminPlayerSearchEntry(
      playerId: _string(json, 'playerId'),
      username: _string(json, 'username'),
      email: _string(json, 'email'),
      createdAt: _date(json['createdAt']),
      lastLoginAt: _optionalDate(json['lastLoginAt']),
      level: _optionalInt(json['level']),
      experience: _optionalInt(json['experience']),
      strength: _optionalInt(json['strength']),
      energy: _optionalInt(json['energy']),
      maxEnergy: _optionalInt(json['maxEnergy']),
      playerUpdatedAt: _optionalDate(json['playerUpdatedAt']),
      walletGold: _optionalInt(json['walletGold']),
      activeModerationCount: _optionalInt(json['activeModerationCount']) ?? 0,
    );
  }
}

class AdminPlayerSummary {
  final String playerId;
  final AdminIdentitySummary? identity;
  final AdminProgressionSummary? progression;
  final AdminWalletSummary? wallet;
  final List<AdminModerationRecord> activeModerationRecords;
  final List<AdminModerationRecord> latestNotes;
  final List<AdminEconomyLedgerEntry> latestLedgerEntries;
  final DateTime updatedAt;

  AdminPlayerSummary({
    required this.playerId,
    required this.identity,
    required this.progression,
    required this.wallet,
    required this.activeModerationRecords,
    required this.latestNotes,
    required this.latestLedgerEntries,
    required this.updatedAt,
  });

  factory AdminPlayerSummary.fromJson(Map<String, dynamic> json) {
    return AdminPlayerSummary(
      playerId: _string(json, 'playerId'),
      identity: json['identity'] == null
          ? null
          : AdminIdentitySummary.fromJson(_map(json['identity'])),
      progression: json['progression'] == null
          ? null
          : AdminProgressionSummary.fromJson(_map(json['progression'])),
      wallet: json['wallet'] == null
          ? null
          : AdminWalletSummary.fromJson(_map(json['wallet'])),
      activeModerationRecords: _list(json['activeModerationRecords'])
          .map((item) => AdminModerationRecord.fromJson(_map(item)))
          .toList(),
      latestNotes: _list(json['latestNotes'])
          .map((item) => AdminModerationRecord.fromJson(_map(item)))
          .toList(),
      latestLedgerEntries: _list(json['latestLedgerEntries'])
          .map((item) => AdminEconomyLedgerEntry.fromJson(_map(item)))
          .toList(),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminIdentitySummary {
  final String accountId;
  final String playerId;
  final String email;
  final String username;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  AdminIdentitySummary({
    required this.accountId,
    required this.playerId,
    required this.email,
    required this.username,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory AdminIdentitySummary.fromJson(Map<String, dynamic> json) {
    return AdminIdentitySummary(
      accountId: _string(json, 'accountId'),
      playerId: _string(json, 'playerId'),
      email: _string(json, 'email'),
      username: _string(json, 'username'),
      createdAt: _date(json['createdAt']),
      lastLoginAt: _optionalDate(json['lastLoginAt']),
    );
  }
}

class AdminProgressionSummary {
  final int level;
  final int experience;
  final int strength;
  final int energy;
  final int maxEnergy;
  final String? lastWorkDate;
  final String? lastTrainDate;
  final DateTime? hospitalCooldownUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminProgressionSummary({
    required this.level,
    required this.experience,
    required this.strength,
    required this.energy,
    required this.maxEnergy,
    required this.lastWorkDate,
    required this.lastTrainDate,
    required this.hospitalCooldownUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminProgressionSummary.fromJson(Map<String, dynamic> json) {
    return AdminProgressionSummary(
      level: _int(json['level']),
      experience: _int(json['experience']),
      strength: _int(json['strength']),
      energy: _int(json['energy']),
      maxEnergy: _int(json['maxEnergy']),
      lastWorkDate: json['lastWorkDate']?.toString(),
      lastTrainDate: json['lastTrainDate']?.toString(),
      hospitalCooldownUntil: _optionalDate(json['hospitalCooldownUntil']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminWalletSummary {
  final int gold;
  final int storageLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminWalletSummary({
    required this.gold,
    required this.storageLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminWalletSummary.fromJson(Map<String, dynamic> json) {
    return AdminWalletSummary(
      gold: _int(json['gold']),
      storageLimit: _int(json['storageLimit']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminModerationRecord {
  final String recordId;
  final String playerId;
  final String type;
  final String reason;
  final bool active;
  final DateTime? expiresAt;
  final String createdBy;
  final DateTime createdAt;
  final String? revokedBy;
  final DateTime? revokedAt;
  final String revocationReason;

  AdminModerationRecord({
    required this.recordId,
    required this.playerId,
    required this.type,
    required this.reason,
    required this.active,
    required this.expiresAt,
    required this.createdBy,
    required this.createdAt,
    required this.revokedBy,
    required this.revokedAt,
    required this.revocationReason,
  });

  factory AdminModerationRecord.fromJson(Map<String, dynamic> json) {
    return AdminModerationRecord(
      recordId: _string(json, 'recordId'),
      playerId: _string(json, 'playerId'),
      type: _string(json, 'type'),
      reason: _string(json, 'reason'),
      active: json['active'] == true,
      expiresAt: _optionalDate(json['expiresAt']),
      createdBy: _string(json, 'createdBy'),
      createdAt: _date(json['createdAt']),
      revokedBy: json['revokedBy']?.toString(),
      revokedAt: _optionalDate(json['revokedAt']),
      revocationReason: (json['revocationReason'] ?? '').toString(),
    );
  }
}

class AdminAuditRecordList {
  final String? playerId;
  final List<AdminAuditRecord> records;
  final DateTime updatedAt;

  AdminAuditRecordList({
    required this.playerId,
    required this.records,
    required this.updatedAt,
  });

  factory AdminAuditRecordList.fromJson(Map<String, dynamic> json) {
    return AdminAuditRecordList(
      playerId: json['playerId']?.toString(),
      records: _list(json['records'])
          .map((item) => AdminAuditRecord.fromJson(_map(item)))
          .toList(),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminAuditRecord {
  final String auditId;
  final String actorAdminId;
  final String actionType;
  final String? targetPlayerId;
  final String targetType;
  final String? targetId;
  final String details;
  final DateTime createdAt;

  AdminAuditRecord({
    required this.auditId,
    required this.actorAdminId,
    required this.actionType,
    required this.targetPlayerId,
    required this.targetType,
    required this.targetId,
    required this.details,
    required this.createdAt,
  });

  factory AdminAuditRecord.fromJson(Map<String, dynamic> json) {
    return AdminAuditRecord(
      auditId: _string(json, 'auditId'),
      actorAdminId: _string(json, 'actorAdminId'),
      actionType: _string(json, 'actionType'),
      targetPlayerId: json['targetPlayerId']?.toString(),
      targetType: _string(json, 'targetType'),
      targetId: json['targetId']?.toString(),
      details: _string(json, 'details'),
      createdAt: _date(json['createdAt']),
    );
  }
}

class AdminEconomyLedgerAuditResponse {
  final String? playerId;
  final String? entryType;
  final List<AdminEconomyLedgerEntry> entries;
  final DateTime updatedAt;

  AdminEconomyLedgerAuditResponse({
    required this.playerId,
    required this.entryType,
    required this.entries,
    required this.updatedAt,
  });

  factory AdminEconomyLedgerAuditResponse.fromJson(Map<String, dynamic> json) {
    return AdminEconomyLedgerAuditResponse(
      playerId: json['playerId']?.toString(),
      entryType: json['entryType']?.toString(),
      entries: _list(json['entries'])
          .map((item) => AdminEconomyLedgerEntry.fromJson(_map(item)))
          .toList(),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminEconomyLedgerEntry {
  final String ledgerId;
  final String playerId;
  final String username;
  final String entryType;
  final int goldDelta;
  final String itemId;
  final int itemDelta;
  final String description;
  final DateTime createdAt;

  AdminEconomyLedgerEntry({
    required this.ledgerId,
    required this.playerId,
    required this.username,
    required this.entryType,
    required this.goldDelta,
    required this.itemId,
    required this.itemDelta,
    required this.description,
    required this.createdAt,
  });

  factory AdminEconomyLedgerEntry.fromJson(Map<String, dynamic> json) {
    return AdminEconomyLedgerEntry(
      ledgerId: _string(json, 'ledgerId'),
      playerId: _string(json, 'playerId'),
      username: (json['username'] ?? '').toString(),
      entryType: _string(json, 'entryType'),
      goldDelta: _int(json['goldDelta']),
      itemId: (json['itemId'] ?? '').toString(),
      itemDelta: _int(json['itemDelta']),
      description: _string(json, 'description'),
      createdAt: _date(json['createdAt']),
    );
  }
}

class AdminEconomyBalanceDashboard {
  final int days;
  final DateTime from;
  final DateTime to;
  final AdminGoldFlowSummary gold;
  final AdminItemSupplySummary items;
  final AdminWageSummary wages;
  final AdminMarketPriceHistorySummary prices;
  final AdminTaxSummary taxes;
  final AdminFactoryOutputSummary factories;
  final AdminBattleRewardSummary battles;
  final DateTime updatedAt;

  AdminEconomyBalanceDashboard({
    required this.days,
    required this.from,
    required this.to,
    required this.gold,
    required this.items,
    required this.wages,
    required this.prices,
    required this.taxes,
    required this.factories,
    required this.battles,
    required this.updatedAt,
  });

  factory AdminEconomyBalanceDashboard.fromJson(Map<String, dynamic> json) {
    return AdminEconomyBalanceDashboard(
      days: _int(json['days']),
      from: _date(json['from']),
      to: _date(json['to']),
      gold: AdminGoldFlowSummary.fromJson(_map(json['gold'])),
      items: AdminItemSupplySummary.fromJson(_map(json['items'])),
      wages: AdminWageSummary.fromJson(_map(json['wages'])),
      prices: AdminMarketPriceHistorySummary.fromJson(_map(json['prices'])),
      taxes: AdminTaxSummary.fromJson(_map(json['taxes'])),
      factories: AdminFactoryOutputSummary.fromJson(_map(json['factories'])),
      battles: AdminBattleRewardSummary.fromJson(_map(json['battles'])),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminGoldFlowSummary {
  final int totalWalletGold;
  final int walletCount;
  final int ledgerEntryCount;
  final int goldCreated;
  final int goldSunk;
  final int netGoldDelta;
  final List<AdminGoldEntryTypeFlow> entryTypes;

  AdminGoldFlowSummary({
    required this.totalWalletGold,
    required this.walletCount,
    required this.ledgerEntryCount,
    required this.goldCreated,
    required this.goldSunk,
    required this.netGoldDelta,
    required this.entryTypes,
  });

  factory AdminGoldFlowSummary.fromJson(Map<String, dynamic> json) {
    return AdminGoldFlowSummary(
      totalWalletGold: _int(json['totalWalletGold']),
      walletCount: _int(json['walletCount']),
      ledgerEntryCount: _int(json['ledgerEntryCount']),
      goldCreated: _int(json['goldCreated']),
      goldSunk: _int(json['goldSunk']),
      netGoldDelta: _int(json['netGoldDelta']),
      entryTypes: _list(json['entryTypes'])
          .map((item) => AdminGoldEntryTypeFlow.fromJson(_map(item)))
          .toList(),
    );
  }
}

class AdminGoldEntryTypeFlow {
  final String entryType;
  final int entryCount;
  final int goldCreated;
  final int goldSunk;
  final int netGoldDelta;

  AdminGoldEntryTypeFlow({
    required this.entryType,
    required this.entryCount,
    required this.goldCreated,
    required this.goldSunk,
    required this.netGoldDelta,
  });

  factory AdminGoldEntryTypeFlow.fromJson(Map<String, dynamic> json) {
    return AdminGoldEntryTypeFlow(
      entryType: _string(json, 'entryType'),
      entryCount: _int(json['entryCount']),
      goldCreated: _int(json['goldCreated']),
      goldSunk: _int(json['goldSunk']),
      netGoldDelta: _int(json['netGoldDelta']),
    );
  }
}

class AdminItemSupplySummary {
  final int itemKinds;
  final int totalQuantity;
  final int playerQuantity;
  final int companyQuantity;
  final List<AdminItemSupplyEntry> topItems;

  AdminItemSupplySummary({
    required this.itemKinds,
    required this.totalQuantity,
    required this.playerQuantity,
    required this.companyQuantity,
    required this.topItems,
  });

  factory AdminItemSupplySummary.fromJson(Map<String, dynamic> json) {
    return AdminItemSupplySummary(
      itemKinds: _int(json['itemKinds']),
      totalQuantity: _int(json['totalQuantity']),
      playerQuantity: _int(json['playerQuantity']),
      companyQuantity: _int(json['companyQuantity']),
      topItems: _list(json['topItems'])
          .map((item) => AdminItemSupplyEntry.fromJson(_map(item)))
          .toList(),
    );
  }
}

class AdminItemSupplyEntry {
  final String itemId;
  final String name;
  final String category;
  final int totalQuantity;
  final int playerQuantity;
  final int companyQuantity;
  final int holderCount;

  AdminItemSupplyEntry({
    required this.itemId,
    required this.name,
    required this.category,
    required this.totalQuantity,
    required this.playerQuantity,
    required this.companyQuantity,
    required this.holderCount,
  });

  factory AdminItemSupplyEntry.fromJson(Map<String, dynamic> json) {
    return AdminItemSupplyEntry(
      itemId: _string(json, 'itemId'),
      name: _string(json, 'name'),
      category: _string(json, 'category'),
      totalQuantity: _int(json['totalQuantity']),
      playerQuantity: _int(json['playerQuantity']),
      companyQuantity: _int(json['companyQuantity']),
      holderCount: _int(json['holderCount']),
    );
  }
}

class AdminWageSummary {
  final int workRecordCount;
  final int paidWorkRecordCount;
  final int pendingCreditWorkRecordCount;
  final int grossWages;
  final int netWages;
  final int taxGold;
  final int averageGrossWage;
  final List<AdminWageCompanySummary> topCompanies;

  AdminWageSummary({
    required this.workRecordCount,
    required this.paidWorkRecordCount,
    required this.pendingCreditWorkRecordCount,
    required this.grossWages,
    required this.netWages,
    required this.taxGold,
    required this.averageGrossWage,
    required this.topCompanies,
  });

  factory AdminWageSummary.fromJson(Map<String, dynamic> json) {
    return AdminWageSummary(
      workRecordCount: _int(json['workRecordCount']),
      paidWorkRecordCount: _int(json['paidWorkRecordCount']),
      pendingCreditWorkRecordCount: _int(json['pendingCreditWorkRecordCount']),
      grossWages: _int(json['grossWages']),
      netWages: _int(json['netWages']),
      taxGold: _int(json['taxGold']),
      averageGrossWage: _int(json['averageGrossWage']),
      topCompanies: _list(json['topCompanies'])
          .map((item) => AdminWageCompanySummary.fromJson(_map(item)))
          .toList(),
    );
  }
}

class AdminWageCompanySummary {
  final String companyId;
  final String companyName;
  final int workRecordCount;
  final int grossWages;
  final int netWages;
  final int taxGold;

  AdminWageCompanySummary({
    required this.companyId,
    required this.companyName,
    required this.workRecordCount,
    required this.grossWages,
    required this.netWages,
    required this.taxGold,
  });

  factory AdminWageCompanySummary.fromJson(Map<String, dynamic> json) {
    return AdminWageCompanySummary(
      companyId: _string(json, 'companyId'),
      companyName: _string(json, 'companyName'),
      workRecordCount: _int(json['workRecordCount']),
      grossWages: _int(json['grossWages']),
      netWages: _int(json['netWages']),
      taxGold: _int(json['taxGold']),
    );
  }
}

class AdminMarketPriceHistorySummary {
  final int tradeCount;
  final int quantityTraded;
  final int goldVolume;
  final int averagePrice;
  final int minPrice;
  final int maxPrice;
  final List<AdminMarketPriceItemSummary> topItems;

  AdminMarketPriceHistorySummary({
    required this.tradeCount,
    required this.quantityTraded,
    required this.goldVolume,
    required this.averagePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.topItems,
  });

  factory AdminMarketPriceHistorySummary.fromJson(Map<String, dynamic> json) {
    return AdminMarketPriceHistorySummary(
      tradeCount: _int(json['tradeCount']),
      quantityTraded: _int(json['quantityTraded']),
      goldVolume: _int(json['goldVolume']),
      averagePrice: _int(json['averagePrice']),
      minPrice: _int(json['minPrice']),
      maxPrice: _int(json['maxPrice']),
      topItems: _list(json['topItems'])
          .map((item) => AdminMarketPriceItemSummary.fromJson(_map(item)))
          .toList(),
    );
  }
}

class AdminMarketPriceItemSummary {
  final String itemId;
  final String itemName;
  final String category;
  final int tradeCount;
  final int quantityTraded;
  final int goldVolume;
  final int averagePrice;
  final int minPrice;
  final int maxPrice;
  final DateTime? lastTradedAt;

  AdminMarketPriceItemSummary({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.tradeCount,
    required this.quantityTraded,
    required this.goldVolume,
    required this.averagePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.lastTradedAt,
  });

  factory AdminMarketPriceItemSummary.fromJson(Map<String, dynamic> json) {
    return AdminMarketPriceItemSummary(
      itemId: _string(json, 'itemId'),
      itemName: _string(json, 'itemName'),
      category: _string(json, 'category'),
      tradeCount: _int(json['tradeCount']),
      quantityTraded: _int(json['quantityTraded']),
      goldVolume: _int(json['goldVolume']),
      averagePrice: _int(json['averagePrice']),
      minPrice: _int(json['minPrice']),
      maxPrice: _int(json['maxPrice']),
      lastTradedAt: _optionalDate(json['lastTradedAt']),
    );
  }
}

class AdminTaxSummary {
  final int entryCount;
  final int taxCollected;
  final int taxedGrossAmount;
  final int averageTaxRate;
  final List<AdminTaxEntryTypeSummary> entryTypes;
  final List<AdminCountryTaxSummary> countries;

  AdminTaxSummary({
    required this.entryCount,
    required this.taxCollected,
    required this.taxedGrossAmount,
    required this.averageTaxRate,
    required this.entryTypes,
    required this.countries,
  });

  factory AdminTaxSummary.fromJson(Map<String, dynamic> json) {
    return AdminTaxSummary(
      entryCount: _int(json['entryCount']),
      taxCollected: _int(json['taxCollected']),
      taxedGrossAmount: _int(json['taxedGrossAmount']),
      averageTaxRate: _int(json['averageTaxRate']),
      entryTypes: _list(json['entryTypes'])
          .map((item) => AdminTaxEntryTypeSummary.fromJson(_map(item)))
          .toList(),
      countries: _list(json['countries'])
          .map((item) => AdminCountryTaxSummary.fromJson(_map(item)))
          .toList(),
    );
  }
}

class AdminTaxEntryTypeSummary {
  final String entryType;
  final int entryCount;
  final int taxCollected;
  final int taxedGrossAmount;
  final int averageTaxRate;

  AdminTaxEntryTypeSummary({
    required this.entryType,
    required this.entryCount,
    required this.taxCollected,
    required this.taxedGrossAmount,
    required this.averageTaxRate,
  });

  factory AdminTaxEntryTypeSummary.fromJson(Map<String, dynamic> json) {
    return AdminTaxEntryTypeSummary(
      entryType: _string(json, 'entryType'),
      entryCount: _int(json['entryCount']),
      taxCollected: _int(json['taxCollected']),
      taxedGrossAmount: _int(json['taxedGrossAmount']),
      averageTaxRate: _int(json['averageTaxRate']),
    );
  }
}

class AdminCountryTaxSummary {
  final String countryId;
  final String countryName;
  final int taxCollected;
  final int taxedGrossAmount;
  final int treasury;
  final int incomeTaxRate;
  final int marketTaxRate;
  final int productionTaxRate;

  AdminCountryTaxSummary({
    required this.countryId,
    required this.countryName,
    required this.taxCollected,
    required this.taxedGrossAmount,
    required this.treasury,
    required this.incomeTaxRate,
    required this.marketTaxRate,
    required this.productionTaxRate,
  });

  factory AdminCountryTaxSummary.fromJson(Map<String, dynamic> json) {
    return AdminCountryTaxSummary(
      countryId: _string(json, 'countryId'),
      countryName: _string(json, 'countryName'),
      taxCollected: _int(json['taxCollected']),
      taxedGrossAmount: _int(json['taxedGrossAmount']),
      treasury: _int(json['treasury']),
      incomeTaxRate: _int(json['incomeTaxRate']),
      marketTaxRate: _int(json['marketTaxRate']),
      productionTaxRate: _int(json['productionTaxRate']),
    );
  }
}

class AdminFactoryOutputSummary {
  final int runCount;
  final int playerRunCount;
  final int companyRunCount;
  final int outputQuantity;
  final List<AdminFactoryOutputItemSummary> topItems;

  AdminFactoryOutputSummary({
    required this.runCount,
    required this.playerRunCount,
    required this.companyRunCount,
    required this.outputQuantity,
    required this.topItems,
  });

  factory AdminFactoryOutputSummary.fromJson(Map<String, dynamic> json) {
    return AdminFactoryOutputSummary(
      runCount: _int(json['runCount']),
      playerRunCount: _int(json['playerRunCount']),
      companyRunCount: _int(json['companyRunCount']),
      outputQuantity: _int(json['outputQuantity']),
      topItems: _list(json['topItems'])
          .map((item) => AdminFactoryOutputItemSummary.fromJson(_map(item)))
          .toList(),
    );
  }
}

class AdminFactoryOutputItemSummary {
  final String itemId;
  final int runCount;
  final int outputQuantity;
  final DateTime? lastProducedAt;

  AdminFactoryOutputItemSummary({
    required this.itemId,
    required this.runCount,
    required this.outputQuantity,
    required this.lastProducedAt,
  });

  factory AdminFactoryOutputItemSummary.fromJson(Map<String, dynamic> json) {
    return AdminFactoryOutputItemSummary(
      itemId: _string(json, 'itemId'),
      runCount: _int(json['runCount']),
      outputQuantity: _int(json['outputQuantity']),
      lastProducedAt: _optionalDate(json['lastProducedAt']),
    );
  }
}

class AdminBattleRewardSummary {
  final int contributionCount;
  final int battleCount;
  final int wonContributionCount;
  final int goldRewards;
  final int experienceRewards;
  final int damage;
  final int energySpent;
  final List<AdminBattleRewardByBattle> topBattles;

  AdminBattleRewardSummary({
    required this.contributionCount,
    required this.battleCount,
    required this.wonContributionCount,
    required this.goldRewards,
    required this.experienceRewards,
    required this.damage,
    required this.energySpent,
    required this.topBattles,
  });

  factory AdminBattleRewardSummary.fromJson(Map<String, dynamic> json) {
    return AdminBattleRewardSummary(
      contributionCount: _int(json['contributionCount']),
      battleCount: _int(json['battleCount']),
      wonContributionCount: _int(json['wonContributionCount']),
      goldRewards: _int(json['goldRewards']),
      experienceRewards: _int(json['experienceRewards']),
      damage: _int(json['damage']),
      energySpent: _int(json['energySpent']),
      topBattles: _list(json['topBattles'])
          .map((item) => AdminBattleRewardByBattle.fromJson(_map(item)))
          .toList(),
    );
  }
}

class AdminBattleRewardByBattle {
  final String battleId;
  final String battleName;
  final int contributionCount;
  final int goldRewards;
  final int experienceRewards;
  final int damage;
  final DateTime? lastContributionAt;

  AdminBattleRewardByBattle({
    required this.battleId,
    required this.battleName,
    required this.contributionCount,
    required this.goldRewards,
    required this.experienceRewards,
    required this.damage,
    required this.lastContributionAt,
  });

  factory AdminBattleRewardByBattle.fromJson(Map<String, dynamic> json) {
    return AdminBattleRewardByBattle(
      battleId: _string(json, 'battleId'),
      battleName: _string(json, 'battleName'),
      contributionCount: _int(json['contributionCount']),
      goldRewards: _int(json['goldRewards']),
      experienceRewards: _int(json['experienceRewards']),
      damage: _int(json['damage']),
      lastContributionAt: _optionalDate(json['lastContributionAt']),
    );
  }
}

class AdminContentModerationQueue {
  final String status;
  final List<AdminContentModerationItem> items;
  final DateTime updatedAt;

  AdminContentModerationQueue({
    required this.status,
    required this.items,
    required this.updatedAt,
  });

  factory AdminContentModerationQueue.fromJson(Map<String, dynamic> json) {
    return AdminContentModerationQueue(
      status: _string(json, 'status'),
      items: _list(json['items'])
          .map((item) => AdminContentModerationItem.fromJson(_map(item)))
          .toList(),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminContentModerationItem {
  final String itemId;
  final String sourceType;
  final String sourceId;
  final String playerId;
  final String content;
  final String reason;
  final String status;
  final String reportedBy;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String resolution;
  final String reviewAction;
  final DateTime lastReportedAt;
  final int reportCount;

  AdminContentModerationItem({
    required this.itemId,
    required this.sourceType,
    required this.sourceId,
    required this.playerId,
    required this.content,
    required this.reason,
    required this.status,
    required this.reportedBy,
    required this.createdAt,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.resolution,
    required this.reviewAction,
    required this.lastReportedAt,
    required this.reportCount,
  });

  factory AdminContentModerationItem.fromJson(Map<String, dynamic> json) {
    final createdAt = _date(json['createdAt']);
    return AdminContentModerationItem(
      itemId: _string(json, 'itemId'),
      sourceType: _string(json, 'sourceType'),
      sourceId: _string(json, 'sourceId'),
      playerId: _string(json, 'playerId'),
      content: _string(json, 'content'),
      reason: _string(json, 'reason'),
      status: _string(json, 'status'),
      reportedBy: _string(json, 'reportedBy'),
      createdAt: createdAt,
      reviewedBy: json['reviewedBy']?.toString(),
      reviewedAt: _optionalDate(json['reviewedAt']),
      resolution: (json['resolution'] ?? '').toString(),
      reviewAction: (json['reviewAction'] ?? 'none').toString(),
      lastReportedAt: _optionalDate(json['lastReportedAt']) ?? createdAt,
      reportCount: _optionalInt(json['reportCount']) ?? 0,
    );
  }
}

class AdminAntiAbuseReviewQueue {
  final String status;
  final String? playerId;
  final List<AdminAntiAbuseReviewItem> items;
  final DateTime updatedAt;

  AdminAntiAbuseReviewQueue({
    required this.status,
    required this.playerId,
    required this.items,
    required this.updatedAt,
  });

  factory AdminAntiAbuseReviewQueue.fromJson(Map<String, dynamic> json) {
    return AdminAntiAbuseReviewQueue(
      status: _string(json, 'status'),
      playerId: json['playerId']?.toString(),
      items: _list(json['items'])
          .map((item) => AdminAntiAbuseReviewItem.fromJson(_map(item)))
          .toList(),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class AdminAntiAbuseReviewItem {
  final String eventId;
  final String playerId;
  final String username;
  final String actionType;
  final String severity;
  final String ruleId;
  final String reason;
  final String subjectType;
  final String subjectId;
  final String route;
  final String? idempotencyKey;
  final String decision;
  final String? auditId;
  final String metadata;
  final int recentLedgerEntries;
  final int recentMarketFills;
  final int recentActivityEvents;
  final String status;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String resolution;

  AdminAntiAbuseReviewItem({
    required this.eventId,
    required this.playerId,
    required this.username,
    required this.actionType,
    required this.severity,
    required this.ruleId,
    required this.reason,
    required this.subjectType,
    required this.subjectId,
    required this.route,
    required this.idempotencyKey,
    required this.decision,
    required this.auditId,
    required this.metadata,
    required this.recentLedgerEntries,
    required this.recentMarketFills,
    required this.recentActivityEvents,
    required this.status,
    required this.createdAt,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.resolution,
  });

  factory AdminAntiAbuseReviewItem.fromJson(Map<String, dynamic> json) {
    return AdminAntiAbuseReviewItem(
      eventId: _string(json, 'eventId'),
      playerId: _string(json, 'playerId'),
      username: (json['username'] ?? '').toString(),
      actionType: _string(json, 'actionType'),
      severity: _string(json, 'severity'),
      ruleId: _string(json, 'ruleId'),
      reason: _string(json, 'reason'),
      subjectType: _string(json, 'subjectType'),
      subjectId: _string(json, 'subjectId'),
      route: _string(json, 'route'),
      idempotencyKey: json['idempotencyKey']?.toString(),
      decision: _string(json, 'decision'),
      auditId: json['auditId']?.toString(),
      metadata: (json['metadata'] ?? '').toString(),
      recentLedgerEntries: _int(json['recentLedgerEntries']),
      recentMarketFills: _int(json['recentMarketFills']),
      recentActivityEvents: _int(json['recentActivityEvents']),
      status: _string(json, 'status'),
      createdAt: _date(json['createdAt']),
      reviewedBy: json['reviewedBy']?.toString(),
      reviewedAt: _optionalDate(json['reviewedAt']),
      resolution: (json['resolution'] ?? '').toString(),
    );
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Missing required admin field "$key".');
  }
  return value.toString();
}

int _int(Object? value) {
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
  throw const FormatException('Expected an integer.');
}

int? _optionalInt(Object? value) {
  return value == null ? null : _int(value);
}

DateTime _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  throw const FormatException('Expected an ISO-8601 timestamp.');
}

DateTime? _optionalDate(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  return _date(value);
}

List<dynamic> _list(Object? value) {
  if (value is List<dynamic>) {
    return value;
  }
  return const [];
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw const FormatException('Expected an object.');
}

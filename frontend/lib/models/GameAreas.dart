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

class MarketListing {
  final String listingId;
  final String itemId;
  final String itemName;
  final String category;
  final int quantity;
  final int pricePerUnit;
  final String sellerId;

  MarketListing({
    required this.listingId,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.pricePerUnit,
    required this.sellerId,
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
    );
  }
}

class MarketPurchaseResult {
  final bool completed;
  final String message;
  final String listingId;
  final int quantity;
  final int totalPrice;
  final InventorySummary inventory;

  MarketPurchaseResult({
    required this.completed,
    required this.message,
    required this.listingId,
    required this.quantity,
    required this.totalPrice,
    required this.inventory,
  });

  factory MarketPurchaseResult.fromJson(Map<String, dynamic> json) {
    return MarketPurchaseResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      listingId: _requiredString(json, 'listingId'),
      quantity: _requiredInt(json, 'quantity'),
      totalPrice: _requiredInt(json, 'totalPrice'),
      inventory: InventorySummary.fromJson(_requiredMap(json['inventory'])),
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
  final String message;

  MissionFightResult({
    required this.mission,
    required this.fight,
    required this.message,
  });

  factory MissionFightResult.fromJson(Map<String, dynamic> json) {
    return MissionFightResult(
      mission: CombatMission.fromJson(_requiredMap(json['mission'])),
      fight: FightResult.fromJson(_requiredMap(json['fight'])),
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

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Missing required date game field "$field".');
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

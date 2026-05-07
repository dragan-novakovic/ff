import 'package:ff/models/GameAreas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses inventory summary', () {
    final inventory = InventorySummary.fromJson({
      'playerId': 'player-1',
      'walletGold': 100,
      'storageUsed': 5,
      'storageLimit': 100,
      'items': [
        {
          'itemId': 'food',
          'name': 'Food',
          'category': 'Consumable',
          'quantity': 5,
          'description': 'Restores energy',
        }
      ],
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    expect(inventory.items.single.itemId, 'food');
    expect(inventory.walletGold, 100);
    expect(inventory.storageUsed, 5);
  });

  test('parses inventory item use response', () {
    final result = InventoryItemUseResult.fromJson({
      'completed': true,
      'message': 'Restored 20 energy. Consumed 1 Food.',
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 100,
        'storageUsed': 4,
        'storageLimit': 100,
        'items': [
          {
            'itemId': 'food',
            'name': 'Food',
            'category': 'Consumable',
            'quantity': 4,
            'description': 'Restores energy',
          }
        ],
        'updatedAt': '2026-05-06T12:00:00Z',
      },
    });

    expect(result.completed, isTrue);
    expect(result.inventory.items.single.quantity, 4);
  });

  test('parses transaction ledger response', () {
    final ledger = LedgerSummary.fromJson({
      'playerId': 'player-1',
      'entries': [
        {
          'ledgerId': 'work-1',
          'entryType': 'daily_work',
          'goldDelta': 10,
          'itemId': '',
          'itemDelta': 0,
          'description': 'Worked a shift.',
          'createdAt': '2026-05-06T12:00:00Z',
        },
        {
          'ledgerId': 'upgrade-1',
          'entryType': 'factory_upgrade',
          'goldDelta': -20,
          'itemId': 'grain',
          'itemDelta': -4,
          'description': 'Upgraded a food factory.',
          'createdAt': '2026-05-06T12:05:00Z',
        },
      ],
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    expect(ledger.entries, hasLength(2));
    expect(ledger.entries.first.goldDelta, 10);
    expect(ledger.entries.last.itemDelta, -4);
  });

  test('parses equipment and equip weapon response', () {
    final equipment = EquipmentSummary.fromJson({
      'playerId': 'player-1',
      'weapon': {
        'itemId': 'weapon_q1',
        'name': 'Q1 Weapon',
        'category': 'Weapon',
        'weaponPower': 3,
        'durability': 10,
        'maxDurability': 10,
        'equippedAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    final equip = EquipWeaponResult.fromJson({
      'completed': true,
      'message': 'Equipped Q1 Weapon.',
      'equipment': {
        'playerId': 'player-1',
        'weapon': {
          'itemId': 'weapon_q1',
          'name': 'Q1 Weapon',
          'category': 'Weapon',
          'weaponPower': 3,
          'durability': 10,
          'maxDurability': 10,
          'equippedAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:00:00Z',
        },
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 100,
        'storageUsed': 4,
        'storageLimit': 100,
        'items': [],
        'updatedAt': '2026-05-06T12:00:00Z',
      },
    });

    expect(equipment.weapon?.weaponPower, 3);
    expect(equipment.weapon?.durabilityProgress, 1);
    expect(equip.inventory.storageUsed, 4);
  });

  test('parses weapon repair response', () {
    final repair = RepairWeaponResult.fromJson({
      'completed': true,
      'message': 'Repaired Q1 Weapon for 3 gold and 1 Iron.',
      'goldCost': 3,
      'materialItemId': 'iron',
      'materialItemName': 'Iron',
      'materialQuantity': 1,
      'equipment': {
        'playerId': 'player-1',
        'weapon': {
          'itemId': 'weapon_q1',
          'name': 'Q1 Weapon',
          'category': 'Weapon',
          'weaponPower': 3,
          'durability': 10,
          'maxDurability': 10,
          'equippedAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:05:00Z',
        },
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 97,
        'storageUsed': 10,
        'storageLimit': 100,
        'items': [
          {
            'itemId': 'iron',
            'name': 'Iron',
            'category': 'Raw material',
            'quantity': 11,
            'description': 'Input for weapon production.',
          }
        ],
        'updatedAt': '2026-05-06T12:05:00Z',
      },
    });

    expect(repair.completed, isTrue);
    expect(repair.goldCost, 3);
    expect(repair.materialQuantity, 1);
    expect(repair.equipment.weapon?.durability, 10);
    expect(repair.inventory.walletGold, 97);
  });

  test('parses mission progress response', () {
    final progress = MissionProgressSummary.fromJson({
      'playerId': 'player-1',
      'missions': [
        {
          'missionId': 'training-bandits',
          'attempts': 2,
          'wins': 1,
          'losses': 1,
          'totalRounds': 6,
          'lastWon': true,
          'lastResult': 'Mission complete.',
          'lastAttemptedAt': '2026-05-06T12:00:00Z',
          'cooldownUntil': '2026-05-06T12:01:00Z',
          'updatedAt': '2026-05-06T12:00:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    expect(progress.forMission('training-bandits')?.wins, 1);
    expect(progress.forMission('training-bandits')?.totalRounds, 6);
  });

  test('parses factory ownership and market sale result', () {
    final factory = PlayerFactory.fromJson({
      'factoryId': 'food-factory',
      'name': 'Food Factory',
      'category': 'Food',
      'level': 1,
      'inputItemId': 'grain',
      'inputQuantity': 5,
      'outputItemId': 'food',
      'outputQuantity': 3,
      'canProduce': true,
      'productionCount': 2,
      'lastProducedAt': '2026-05-06T12:00:00Z',
      'cooldownUntil': '2026-05-06T12:02:00Z',
      'productionDurationSeconds': 90,
      'activeJobId': 'job-1',
      'queueDepth': 1,
      'maxQueueDepth': 3,
      'resourceEffect': {
        'productionBonusPercent': 14,
        'sourceRegionId': 'greenmarch',
        'sourceRegionName': 'Greenmarch',
        'resourceName': 'Grain',
        'itemId': 'grain',
      },
    });

    final sale = MarketSellListingResult.fromJson({
      'completed': true,
      'message': 'Listed 2 Food.',
      'listing': {
        'listingId': 'listing-1',
        'itemId': 'food',
        'itemName': 'Food',
        'category': 'Consumable',
        'quantity': 2,
        'pricePerUnit': 4,
        'sellerId': 'player-1',
        'status': 'open',
        'createdAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 100,
        'storageUsed': 3,
        'storageLimit': 100,
        'items': [],
        'updatedAt': '2026-05-06T12:00:00Z',
      },
    });

    expect(factory.productionCount, 2);
    expect(factory.lastProducedAt, isNotNull);
    expect(factory.cooldownUntil, isNotNull);
    expect(factory.activeJobId, 'job-1');
    expect(factory.resourceEffect?.productionBonusPercent, 14);
    expect(sale.listing.status, 'open');
    expect(sale.inventory.storageUsed, 3);
  });

  test('parses advanced market history order book and trade contract', () {
    final history = MarketPriceHistory.fromJson({
      'itemId': 'food',
      'entries': [
        {
          'priceHistoryId': 'price-1',
          'itemId': 'food',
          'itemName': 'Food',
          'category': 'Consumable',
          'qualityTier': 1,
          'quantity': 3,
          'pricePerUnit': 7,
          'sellerType': 'company',
          'sellerId': 'co-seller',
          'buyerType': 'player',
          'buyerId': 'player-1',
          'sourceType': 'trade_contract',
          'sourceId': 'contract-1',
          'tradedAt': '2026-05-06T12:10:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:11:00Z',
    });

    final orderBook = MarketOrderBook.fromJson({
      'itemId': null,
      'entries': [
        {
          'itemId': 'weapon_q1',
          'itemName': 'Q1 Weapon',
          'category': 'Weapon',
          'qualityTier': 1,
          'pricePerUnit': 18,
          'quantity': 4,
          'orderCount': 2,
        }
      ],
      'updatedAt': '2026-05-06T12:11:00Z',
    });

    final offers = TradeOfferList.fromJson({
      'offers': [
        {
          'offerId': 'offer-1',
          'creatorPlayerId': 'player-1',
          'sellerType': 'player',
          'sellerId': 'player-1',
          'buyerType': 'company',
          'buyerId': 'co-buyer',
          'itemId': 'food',
          'itemName': 'Food',
          'category': 'Consumable',
          'qualityTier': 1,
          'quantity': 2,
          'pricePerUnit': 5,
          'status': 'open',
          'idempotencyKey': 'trade-offer:offer-1',
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:00:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    final result = TradeOfferResult.fromJson({
      'completed': true,
      'message': 'Trade contract fulfilled.',
      'totalPrice': 10,
      'offer': {
        'offerId': 'offer-1',
        'creatorPlayerId': 'player-1',
        'sellerType': 'player',
        'sellerId': 'player-1',
        'buyerType': 'company',
        'buyerId': 'co-buyer',
        'itemId': 'food',
        'itemName': 'Food',
        'category': 'Consumable',
        'qualityTier': 1,
        'quantity': 2,
        'pricePerUnit': 5,
        'status': 'fulfilled',
        'idempotencyKey': 'trade-offer:offer-1',
        'createdAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:05:00Z',
        'respondedAt': '2026-05-06T12:04:00Z',
      },
      'contract': {
        'contractId': 'contract-1',
        'offerId': 'offer-1',
        'acceptedByPlayerId': 'manager-1',
        'status': 'fulfilled',
        'failureReason': '',
        'idempotencyKey': 'trade-accept:offer-1',
        'createdAt': '2026-05-06T12:04:00Z',
        'updatedAt': '2026-05-06T12:05:00Z',
        'fulfilledAt': '2026-05-06T12:05:00Z',
      },
    });

    expect(history.entries.single.totalPrice, 21);
    expect(orderBook.entries.single.orderCount, 2);
    expect(offers.offers.single.buyerType, 'company');
    expect(result.contract?.status, 'fulfilled');
    expect(result.offer?.totalPrice, 10);
  });

  test('parses production jobs and claim result', () {
    final jobs = ProductionJobsResponse.fromJson({
      'playerId': 'player-1',
      'jobs': [
        {
          'jobId': 'job-1',
          'playerId': 'player-1',
          'factoryId': 'food-factory',
          'status': 'completed',
          'inputItemId': 'grain',
          'inputItemName': 'Grain',
          'inputItemCategory': 'Raw material',
          'inputQuantity': 5,
          'outputItemId': 'food',
          'outputItemName': 'Food',
          'outputItemCategory': 'Consumable',
          'outputQuantity': 3,
          'durationSeconds': 90,
          'startedAt': '2026-05-06T12:00:00Z',
          'completesAt': '2026-05-06T12:01:30Z',
          'completedAt': '2026-05-06T12:01:30Z',
          'claimedAt': null,
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:01:30Z',
          'canClaim': true,
          'appliedBonus': {
            'productionBonusPercent': 14,
            'sourceRegionId': 'greenmarch',
            'sourceRegionName': 'Greenmarch',
            'resourceName': 'Grain',
            'itemId': 'grain',
          },
        }
      ],
      'updatedAt': '2026-05-06T12:01:30Z',
    });

    final start = ProductionResult.fromJson({
      'completed': false,
      'factoryId': 'food-factory',
      'message': 'Food Factory started production job job-1.',
      'consumedItemId': 'grain',
      'consumedQuantity': 5,
      'producedItemId': 'food',
      'producedQuantity': 3,
      'note': 'Input reserved.',
      'completedAt': '2026-05-06T12:01:30Z',
      'productionCount': 2,
      'lastProducedAt': '2026-05-06T12:00:00Z',
      'startedAt': '2026-05-06T12:00:00Z',
      'completesAt': '2026-05-06T12:01:30Z',
      'job': {
        'jobId': 'job-1',
        'playerId': 'player-1',
        'factoryId': 'food-factory',
        'status': 'running',
        'inputItemId': 'grain',
        'inputItemName': 'Grain',
        'inputItemCategory': 'Raw material',
        'inputQuantity': 5,
        'outputItemId': 'food',
        'outputItemName': 'Food',
        'outputItemCategory': 'Consumable',
        'outputQuantity': 3,
        'durationSeconds': 90,
        'startedAt': '2026-05-06T12:00:00Z',
        'completesAt': '2026-05-06T12:01:30Z',
        'completedAt': null,
        'claimedAt': null,
        'createdAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
        'canClaim': false,
        'appliedBonus': {
          'productionBonusPercent': 14,
          'sourceRegionId': 'greenmarch',
          'sourceRegionName': 'Greenmarch',
          'resourceName': 'Grain',
          'itemId': 'grain',
        },
      },
      'appliedBonus': {
        'productionBonusPercent': 14,
        'sourceRegionId': 'greenmarch',
        'sourceRegionName': 'Greenmarch',
        'resourceName': 'Grain',
        'itemId': 'grain',
      },
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 100,
        'storageUsed': 5,
        'storageLimit': 100,
        'items': [],
        'updatedAt': '2026-05-06T12:00:00Z',
      },
    });

    final claim = ProductionClaimResult.fromJson({
      'completed': true,
      'message': 'Claimed 3 Food. Granted 3 Food.',
      'claim': {
        'completed': true,
        'alreadyClaimed': false,
        'message': 'Claimed 3 Food.',
        'productionCount': 3,
        'job': {
          'jobId': 'job-1',
          'playerId': 'player-1',
          'factoryId': 'food-factory',
          'status': 'claimed',
          'inputItemId': 'grain',
          'inputItemName': 'Grain',
          'inputItemCategory': 'Raw material',
          'inputQuantity': 5,
          'outputItemId': 'food',
          'outputItemName': 'Food',
          'outputItemCategory': 'Consumable',
          'outputQuantity': 3,
          'durationSeconds': 90,
          'startedAt': '2026-05-06T12:00:00Z',
          'completesAt': '2026-05-06T12:01:30Z',
          'completedAt': '2026-05-06T12:01:30Z',
          'claimedAt': '2026-05-06T12:02:00Z',
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:02:00Z',
          'canClaim': false,
        },
      },
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 100,
        'storageUsed': 8,
        'storageLimit': 100,
        'items': [
          {
            'itemId': 'food',
            'name': 'Food',
            'category': 'Consumable',
            'quantity': 8,
            'description': 'Restores energy',
          }
        ],
        'updatedAt': '2026-05-06T12:02:00Z',
      },
    });

    expect(jobs.jobs.single.canClaim, isTrue);
    expect(jobs.jobs.single.appliedBonus?.resourceName, 'Grain');
    expect(jobs.forFactory('food-factory'), hasLength(1));
    expect(start.completed, isFalse);
    expect(start.job?.status, 'running');
    expect(start.appliedBonus?.productionBonusPercent, 14);
    expect(start.inventory?.storageUsed, 5);
    expect(claim.completed, isTrue);
    expect(claim.claim.productionCount, 3);
    expect(claim.inventory?.items.single.quantity, 8);
  });

  test('parses factory upgrade and market cancellation results', () {
    final upgrade = FactoryUpgradeGatewayResult.fromJson({
      'completed': true,
      'message': 'Factory upgraded. Inventory updated.',
      'upgrade': {
        'upgraded': true,
        'factoryId': 'food-factory',
        'message': 'Food Factory upgraded to level 2.',
        'factory': {
          'factoryId': 'food-factory',
          'name': 'Food Factory',
          'category': 'Food',
          'level': 2,
          'inputItemId': 'grain',
          'inputQuantity': 5,
          'outputItemId': 'food',
          'outputQuantity': 4,
          'canProduce': true,
          'productionCount': 2,
          'lastProducedAt': '2026-05-06T12:00:00Z',
        },
        'appliedQuote': {
          'factoryId': 'food-factory',
          'currentLevel': 1,
          'nextLevel': 2,
          'goldCost': 20,
          'requiredItemId': 'grain',
          'requiredItemName': 'Grain',
          'requiredItemQuantity': 10,
          'outputQuantityAfterUpgrade': 4,
          'canUpgrade': true,
        },
        'upgradedAt': '2026-05-06T12:10:00Z',
      },
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 80,
        'storageUsed': 3,
        'storageLimit': 100,
        'items': [],
        'updatedAt': '2026-05-06T12:10:00Z',
      },
    });

    final playerListings = PlayerMarketListings.fromJson({
      'sellerId': 'player-1',
      'listings': [
        {
          'listingId': 'listing-1',
          'itemId': 'food',
          'itemName': 'Food',
          'category': 'Consumable',
          'quantity': 2,
          'pricePerUnit': 4,
          'sellerId': 'player-1',
          'status': 'open',
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:00:00Z',
        },
      ],
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    final cancellation = MarketCancelListingResult.fromJson({
      'completed': true,
      'message': 'Cancelled listing listing-1. Refunded 2 Food.',
      'listing': {
        'listingId': 'listing-1',
        'itemId': 'food',
        'itemName': 'Food',
        'category': 'Consumable',
        'quantity': 2,
        'pricePerUnit': 4,
        'sellerId': 'player-1',
        'status': 'cancelled',
        'createdAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:10:00Z',
      },
      'inventory': {
        'playerId': 'player-1',
        'walletGold': 80,
        'storageUsed': 5,
        'storageLimit': 100,
        'items': [
          {
            'itemId': 'food',
            'name': 'Food',
            'category': 'Consumable',
            'quantity': 2,
            'description': 'Restores energy',
          }
        ],
        'updatedAt': '2026-05-06T12:10:00Z',
      },
    });

    expect(upgrade.upgrade.factory.level, 2);
    expect(upgrade.upgrade.appliedQuote.goldCost, 20);
    expect(playerListings.listings.single.sellerId, 'player-1');
    expect(cancellation.listing.status, 'cancelled');
    expect(cancellation.inventory?.items.single.quantity, 2);
  });

  test('parses combat mission and fight result with snake case fields', () {
    final mission = CombatMission.fromJson({
      'mission_id': 'training-bandits',
      'name': 'Training Bandits',
      'description': 'A low-risk skirmish',
      'defender': {'strength': 8, 'energy': 80, 'weapon_power': 1},
      'rounds': 3,
      'reward_experience': 15,
      'reward_gold': 5,
    });

    final fight = FightResult.fromJson({
      'winner': 'attacker',
      'rounds_requested': 3,
      'rounds_completed': 3,
      'attacker_damage': 30,
      'defender_damage': 20,
      'attacker_remaining_energy': 70,
      'defender_remaining_energy': 50,
    });

    expect(mission.missionId, 'training-bandits');
    expect(mission.defender.weaponPower, 1);
    expect(fight.attackerDamage, 30);
  });

  test('parses mission fight equipment durability result', () {
    final result = MissionFightResult.fromJson({
      'mission': {
        'mission_id': 'training-bandits',
        'name': 'Training Bandits',
        'description': 'A low-risk skirmish',
        'defender': {'strength': 8, 'energy': 80, 'weapon_power': 1},
        'rounds': 3,
        'reward_experience': 15,
        'reward_gold': 5,
      },
      'fight': {
        'winner': 'attacker',
        'rounds_requested': 3,
        'rounds_completed': 3,
        'attacker_damage': 42,
        'defender_damage': 20,
        'attacker_remaining_energy': 70,
        'defender_remaining_energy': 38,
      },
      'playerAction': {
        'completed': true,
        'message': 'Mission complete.',
        'rewards': {'gold': 5, 'experience': 15, 'strength': 0},
        'state': {},
      },
      'missionProgress': {
        'missionId': 'training-bandits',
        'attempts': 1,
        'wins': 1,
        'losses': 0,
        'totalRounds': 3,
        'lastWon': true,
        'lastResult': 'Mission complete.',
        'lastAttemptedAt': '2026-05-06T12:05:00Z',
        'cooldownUntil': '2026-05-06T12:06:00Z',
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'equipment': {
        'playerId': 'player-1',
        'weapon': {
          'itemId': 'weapon_q1',
          'name': 'Q1 Weapon',
          'category': 'Weapon',
          'weaponPower': 3,
          'durability': 7,
          'maxDurability': 10,
          'equippedAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:05:00Z',
        },
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'weaponDamage': {
        'completed': true,
        'message': 'Q1 Weapon lost 3 durability.',
        'durabilityLost': 3,
        'equipment': {
          'playerId': 'player-1',
          'weapon': {
            'itemId': 'weapon_q1',
            'name': 'Q1 Weapon',
            'category': 'Weapon',
            'weaponPower': 3,
            'durability': 7,
            'maxDurability': 10,
            'equippedAt': '2026-05-06T12:00:00Z',
            'updatedAt': '2026-05-06T12:05:00Z',
          },
          'updatedAt': '2026-05-06T12:05:00Z',
        },
      },
      'message': 'Mission complete.',
    });

    expect(result.equipment.weapon?.durability, 7);
    expect(result.missionProgress?.attempts, 1);
    expect(result.weaponDamage?.durabilityLost, 3);
    expect(result.fight.attackerDamage, 42);
  });

  test('parses world countries and regions', () {
    final catalog = CountryCatalog.fromJson({
      'countries': [
        {
          'countryId': 'freiland',
          'name': 'Freiland',
          'code': 'FRL',
          'description': 'A civic republic.',
          'government': 'Civic republic',
          'treasury': 250000,
          'taxRate': 5,
          'regionCount': 2,
          'citizenCount': 7,
          'updatedAt': '2026-05-06T12:00:00Z',
          'regions': [
            {
              'regionId': 'freyport',
              'countryId': 'freiland',
              'name': 'Freyport',
              'terrain': 'Coastal city',
              'resourceFocus': 'Trade',
              'population': 125000,
              'infrastructure': 78,
              'isCapital': true,
              'updatedAt': '2026-05-06T12:00:00Z',
            }
          ],
        }
      ],
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    final regions = RegionList.fromJson({
      'regions': [
        {
          'regionId': 'greenmarch',
          'countryId': 'freiland',
          'name': 'Greenmarch',
          'terrain': 'Plains',
          'resourceFocus': 'Grain',
          'population': 82000,
          'infrastructure': 63,
          'isCapital': false,
          'updatedAt': '2026-05-06T12:00:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    expect(catalog.countries.single.countryId, 'freiland');
    expect(catalog.countries.single.regions.single.isCapital, isTrue);
    expect(catalog.countries.single.citizenCount, 7);
    expect(regions.regions.single.resourceFocus, 'Grain');
  });

  test('parses territory map and battle mutation result', () {
    final territory = TerritoryMap.fromJson({
      'regions': [
        {
          'regionId': 'greenmarch',
          'name': 'Greenmarch',
          'terrain': 'Plains',
          'resourceFocus': 'Grain',
          'population': 82000,
          'infrastructure': 63,
          'isCapital': false,
          'ownerCountryId': 'freiland',
          'ownerCountryName': 'Freiland',
          'ownerCountryCode': 'FRL',
          'bonus': {
            'regionId': 'greenmarch',
            'resourceType': 'Grain',
            'productionBonusPercent': 5,
            'marketBonusPercent': 2,
            'defenseBonusPercent': 4,
            'hospitalCapacity': 756,
            'effectiveProductionBonusPercent': 14,
            'effectiveMarketBonusPercent': 6,
            'updatedAt': '2026-05-06T12:00:00Z',
          },
          'resources': [
            {
              'regionId': 'greenmarch',
              'resourceId': 'resource-grain',
              'itemId': 'grain',
              'name': 'Grain',
              'category': 'Raw material',
              'abundancePercent': 81,
              'productionBonusPercent': 14,
              'marketBonusPercent': 6,
              'description': 'Grain fields support food output.',
              'updatedAt': '2026-05-06T12:00:00Z',
            }
          ],
          'defense': {
            'regionId': 'greenmarch',
            'defenseLevel': 2,
            'hospitalLevel': 2,
            'garrisonStrength': 252,
            'resistance': 15,
            'fortificationHealth': 90,
            'hospitalEnergyPerDay': 80,
            'hospitalSupplies': 320,
            'effectiveDefensePercent': 23,
            'effectiveHospitalCapacity': 1156,
            'updatedAt': '2026-05-06T12:00:00Z',
          },
          'activeConflict': {
            'battleId': 'battle-conquest-greenmarch',
            'regionId': 'greenmarch',
            'regionName': 'Greenmarch',
            'attackerCountryId': 'nordheim',
            'attackerCountryName': 'Nordheim',
            'attackerCountryCode': 'NRD',
            'defenderCountryId': 'freiland',
            'defenderCountryName': 'Freiland',
            'defenderCountryCode': 'FRL',
            'name': 'Conquest of Greenmarch',
            'description': 'A conquest battle.',
            'battleType': 'conquest',
            'status': 'active',
            'attackerScore': 120,
            'defenderScore': 80,
            'targetScore': 500,
            'defenderStrength': 12,
            'defenderEnergy': 100,
            'defenderWeaponPower': 2,
            'rounds': 3,
            'startedAt': '2026-05-06T12:00:00Z',
            'endsAt': '2099-05-07T12:00:00Z',
            'resolvedAt': null,
            'winnerCountryId': null,
            'winnerCountryName': null,
            'updatedAt': '2026-05-06T12:05:00Z',
          },
          'recentHistory': [
            {
              'historyId': 'history-greenmarch-initial',
              'regionId': 'greenmarch',
              'regionName': 'Greenmarch',
              'previousCountryId': null,
              'previousCountryName': null,
              'previousCountryCode': null,
              'newCountryId': 'freiland',
              'newCountryName': 'Freiland',
              'newCountryCode': 'FRL',
              'battleId': null,
              'battleName': null,
              'changedByPlayerId': 'system',
              'reason': 'Initial world catalog ownership.',
              'createdAt': '2026-05-06T12:00:00Z',
            }
          ],
          'authorization': {
            'canStartConquest': false,
            'canStartResistance': false,
            'canResolveBattle': true,
            'role': 'battle-participant',
            'message': 'This active battle can be resolved now.',
          },
          'updatedAt': '2026-05-06T12:05:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    final mutation = TerritoryBattleMutationResult.fromJson({
      'completed': true,
      'message': 'Battle resolved.',
      'battle': null,
      'region': {
        'regionId': 'greenmarch',
        'name': 'Greenmarch',
        'terrain': 'Plains',
        'resourceFocus': 'Grain',
        'population': 82000,
        'infrastructure': 63,
        'isCapital': false,
        'ownerCountryId': 'nordheim',
        'ownerCountryName': 'Nordheim',
        'ownerCountryCode': 'NRD',
        'bonus': {
          'regionId': 'greenmarch',
          'resourceType': 'Grain',
          'productionBonusPercent': 5,
          'marketBonusPercent': 2,
          'defenseBonusPercent': 4,
          'hospitalCapacity': 756,
          'effectiveProductionBonusPercent': 14,
          'effectiveMarketBonusPercent': 6,
          'updatedAt': '2026-05-06T12:10:00Z',
        },
        'resources': [
          {
            'regionId': 'greenmarch',
            'resourceId': 'resource-grain',
            'itemId': 'grain',
            'name': 'Grain',
            'category': 'Raw material',
            'abundancePercent': 81,
            'productionBonusPercent': 14,
            'marketBonusPercent': 6,
            'description': 'Grain fields support food output.',
            'updatedAt': '2026-05-06T12:10:00Z',
          }
        ],
        'defense': {
          'regionId': 'greenmarch',
          'defenseLevel': 1,
          'hospitalLevel': 2,
          'garrisonStrength': 126,
          'resistance': 50,
          'fortificationHealth': 60,
          'hospitalEnergyPerDay': 80,
          'hospitalSupplies': 270,
          'effectiveDefensePercent': 15,
          'effectiveHospitalCapacity': 1106,
          'updatedAt': '2026-05-06T12:10:00Z',
        },
        'activeConflict': null,
        'recentHistory': [],
        'authorization': {
          'canStartConquest': false,
          'canStartResistance': false,
          'canResolveBattle': false,
          'role': null,
          'message': 'Nordheim already controls this region.',
        },
        'updatedAt': '2026-05-06T12:10:00Z',
      },
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    expect(territory.activeConflicts, hasLength(1));
    expect(territory.regions.single.bonus.effectiveProductionBonusPercent, 14);
    expect(territory.regions.single.resources.single.itemId, 'grain');
    expect(territory.regions.single.defense.resistance, 15);
    expect(territory.regions.single.defense.fortificationHealth, 90);
    expect(territory.regions.single.authorization.canResolveBattle, isTrue);
    expect(mutation.region?.ownerCountryId, 'nordheim');
    expect(mutation.region?.defense.resistance, 50);
  });

  test('parses country treasury and tax policy', () {
    final treasury = CountryTreasury.fromJson({
      'countryId': 'freiland',
      'name': 'Freiland',
      'code': 'FRL',
      'treasury': 250123,
      'policy': {
        'countryId': 'freiland',
        'incomeTaxRate': 5,
        'marketTaxRate': 2,
        'productionTaxRate': 1,
        'updatedByPlayerId': 'player-1',
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'recentLedger': [
        {
          'ledgerId': 'tax-1',
          'countryId': 'freiland',
          'entryType': 'income_tax',
          'sourcePlayerId': 'player-1',
          'counterpartyPlayerId': '',
          'goldDelta': 2,
          'grossAmount': 25,
          'taxRate': 5,
          'description': 'Income tax on work reward.',
          'createdAt': '2026-05-06T12:01:00Z',
        }
      ],
      'authorization': {
        'canUpdatePolicy': true,
        'role': 'founding-treasurer',
        'message': 'You hold the recorded country treasury office.',
      },
      'updatedAt': '2026-05-06T12:01:00Z',
    });

    final update = CountryTaxPolicyUpdateResult.fromJson({
      'completed': true,
      'message': 'Country tax policy was updated.',
      'treasury': {
        'countryId': 'freiland',
        'name': 'Freiland',
        'code': 'FRL',
        'treasury': 250123,
        'policy': {
          'countryId': 'freiland',
          'incomeTaxRate': 6,
          'marketTaxRate': 3,
          'productionTaxRate': 2,
          'updatedByPlayerId': 'player-1',
          'updatedAt': '2026-05-06T12:05:00Z',
        },
        'recentLedger': [],
        'authorization': {
          'canUpdatePolicy': true,
          'role': 'founding-treasurer',
          'message': 'You hold the recorded country treasury office.',
        },
        'updatedAt': '2026-05-06T12:05:00Z',
      },
    });

    expect(treasury.policy.marketTaxRate, 2);
    expect(treasury.recentTaxCollected, 2);
    expect(treasury.authorization.canUpdatePolicy, isTrue);
    expect(update.treasury?.policy.incomeTaxRate, 6);
  });

  test('parses player citizenship status and mutation result', () {
    final status = PlayerCitizenshipStatus.fromJson({
      'playerId': 'player-1',
      'citizenship': {
        'playerId': 'player-1',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'status': 'active',
        'joinedAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    final mutation = CitizenshipMutationResult.fromJson({
      'completed': true,
      'message': 'Citizenship changed to Freiland.',
      'citizenship': {
        'playerId': 'player-1',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'status': 'active',
        'joinedAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    expect(status.citizenship?.countryCode, 'FRL');
    expect(mutation.completed, isTrue);
    expect(mutation.citizenship?.status, 'active');
  });

  test('parses public player profile', () {
    final profile = PublicPlayerProfile.fromJson({
      'playerId': 'player-1',
      'username': 'Alice',
      'level': 7,
      'experience': 650,
      'strength': 18,
      'energy': 85,
      'maxEnergy': 100,
      'rank': 3,
      'equippedWeapon': {
        'itemId': 'weapon_q1',
        'name': 'Q1 Weapon',
        'category': 'Weapon',
        'weaponPower': 3,
        'durability': 8,
        'maxDurability': 10,
        'equippedAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'createdOn': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    expect(profile.playerId, 'player-1');
    expect(profile.rank, 3);
    expect(profile.equippedWeapon?.weaponPower, 3);
  });

  test('parses rankings leaderboard', () {
    final leaderboard = RankingsLeaderboard.fromJson({
      'sortBy': 'level',
      'limit': 50,
      'totalPlayers': 2,
      'entries': [
        {
          'rank': 1,
          'playerId': 'player-1',
          'username': 'Alice',
          'level': 10,
          'experience': 950,
          'strength': 24,
          'energy': 90,
          'maxEnergy': 100,
          'updatedAt': '2026-05-06T12:10:00Z',
        },
        {
          'rank': 2,
          'playerId': 'player-2',
          'username': 'Bob',
          'level': 8,
          'experience': 700,
          'strength': 20,
          'energy': 75,
          'maxEnergy': 100,
          'updatedAt': '2026-05-06T12:08:00Z',
        },
      ],
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    expect(leaderboard.entries, hasLength(2));
    expect(leaderboard.entries.first.username, 'Alice');
    expect(leaderboard.totalPlayers, 2);
  });

  test('parses single ranking entry', () {
    final entry = RankingEntry.fromJson({
      'rank': 5,
      'playerId': 'player-5',
      'username': 'Casey',
      'level': 4,
      'experience': 320,
      'strength': 13,
      'energy': 60,
      'maxEnergy': 100,
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    expect(entry.rank, 5);
    expect(entry.playerId, 'player-5');
    expect(entry.strength, 13);
  });

  test('parses country battle list, details, and participation', () {
    final battles = CountryBattleList.fromJson({
      'battles': [
        {
          'battleId': 'battle-greenmarch',
          'regionId': 'greenmarch',
          'regionName': 'Greenmarch',
          'attackerCountryId': 'nordheim',
          'attackerCountryName': 'Nordheim',
          'attackerCountryCode': 'NRD',
          'defenderCountryId': 'freiland',
          'defenderCountryName': 'Freiland',
          'defenderCountryCode': 'FRL',
          'name': 'Greenmarch Border Clash',
          'description': 'A country battle.',
          'status': 'active',
          'attackerScore': 120,
          'defenderScore': 80,
          'targetScore': 500,
          'defenderStrength': 12,
          'defenderEnergy': 100,
          'defenderWeaponPower': 2,
          'rounds': 3,
          'startedAt': '2026-05-06T12:00:00Z',
          'endsAt': '2099-05-07T12:00:00Z',
          'resolvedAt': null,
          'winnerCountryId': null,
          'winnerCountryName': null,
          'updatedAt': '2026-05-06T12:05:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    final details = BattleDetails.fromJson({
      'battle': {
        'battle_id': 'battle-greenmarch',
        'region_id': 'greenmarch',
        'region_name': 'Greenmarch',
        'attacker_country_id': 'nordheim',
        'attacker_country_name': 'Nordheim',
        'attacker_country_code': 'NRD',
        'defender_country_id': 'freiland',
        'defender_country_name': 'Freiland',
        'defender_country_code': 'FRL',
        'name': 'Greenmarch Border Clash',
        'description': 'A country battle.',
        'status': 'active',
        'attacker_score': 120,
        'defender_score': 80,
        'target_score': 500,
        'defender_strength': 12,
        'defender_energy': 100,
        'defender_weapon_power': 2,
        'rounds': 3,
        'started_at': '2026-05-06T12:00:00Z',
        'ends_at': '2099-05-07T12:00:00Z',
        'updated_at': '2026-05-06T12:05:00Z',
      },
      'contributions': [
        {
          'contributionId': 'contrib-1',
          'battleId': 'battle-greenmarch',
          'playerId': 'player-1',
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'side': 'defender',
          'damage': 42,
          'energySpent': 30,
          'roundsCompleted': 3,
          'won': true,
          'goldReward': 3,
          'experienceReward': 8,
          'message': 'Battle contribution dealt 42 damage.',
          'createdAt': '2026-05-06T12:05:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    final participation = PlayerBattleParticipationStatus.fromJson({
      'playerId': 'player-1',
      'battleId': 'battle-greenmarch',
      'participation': {
        'playerId': 'player-1',
        'battleId': 'battle-greenmarch',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'side': 'defender',
        'contributionCount': 1,
        'damage': 42,
        'energySpent': 30,
        'goldReward': 3,
        'experienceReward': 8,
        'lastContributedAt': '2026-05-06T12:05:00Z',
      },
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    expect(battles.battles.single.attackerProgress, closeTo(0.24, 0.001));
    expect(details.contributions.single.countryCode, 'FRL');
    expect(participation.participation?.damage, 42);
  });

  test('parses campaign depth, phases, rewards, and leaderboards', () {
    final campaignJson = {
      'campaignId': 'campaign-greenmarch',
      'countryId': 'freiland',
      'countryName': 'Freiland',
      'countryCode': 'FRL',
      'name': 'Greenmarch Liberation',
      'description': 'Secure the border campaign.',
      'campaignType': 'territory',
      'status': 'completed',
      'objectiveScore': 1000,
      'currentScore': 1000,
      'reward': {'gold': 25, 'experience': 75, 'prestige': 3},
      'battleCount': 1,
      'phaseCount': 1,
      'activeBattleCount': 0,
      'createdByPlayerId': 'player-1',
      'startedAt': '2026-05-06T12:00:00Z',
      'endsAt': '2026-05-07T12:00:00Z',
      'concludedAt': '2026-05-06T13:00:00Z',
      'winnerCountryId': 'freiland',
      'winnerCountryName': 'Freiland',
      'createdAt': '2026-05-06T12:00:00Z',
      'updatedAt': '2026-05-06T13:00:00Z',
    };
    final battleJson = {
      'battleId': 'battle-greenmarch',
      'regionId': 'greenmarch',
      'regionName': 'Greenmarch',
      'attackerCountryId': 'freiland',
      'attackerCountryName': 'Freiland',
      'attackerCountryCode': 'FRL',
      'defenderCountryId': 'nordheim',
      'defenderCountryName': 'Nordheim',
      'defenderCountryCode': 'NRD',
      'name': 'Greenmarch Border Clash',
      'description': 'A campaign battle.',
      'battleType': 'conquest',
      'campaignId': 'campaign-greenmarch',
      'status': 'resolved',
      'attackerScore': 1000,
      'defenderScore': 600,
      'targetScore': 1000,
      'defenderStrength': 12,
      'defenderEnergy': 100,
      'defenderWeaponPower': 2,
      'rounds': 3,
      'startedAt': '2026-05-06T12:00:00Z',
      'endsAt': '2026-05-07T12:00:00Z',
      'resolvedAt': '2026-05-06T13:00:00Z',
      'winnerCountryId': 'freiland',
      'winnerCountryName': 'Freiland',
      'updatedAt': '2026-05-06T13:00:00Z',
    };
    final phaseJson = {
      'phaseId': 'phase-1',
      'campaignId': 'campaign-greenmarch',
      'battleId': 'battle-greenmarch',
      'battleName': 'Greenmarch Border Clash',
      'phaseNumber': 1,
      'name': 'Open the front',
      'objectives': 'Deal enough battle damage to open the border.',
      'targetDamage': 500,
      'attackerDamage': 320,
      'defenderDamage': 180,
      'status': 'completed',
      'startedAt': '2026-05-06T12:00:00Z',
      'completedAt': '2026-05-06T12:45:00Z',
      'updatedAt': '2026-05-06T12:45:00Z',
    };
    final countryLeaderboardJson = {
      'entries': [
        {
          'rank': 1,
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'totalDamage': 1000,
          'contributionCount': 20,
          'battleCount': 1,
          'victoryCount': 1,
          'score': 1030,
          'lastContributedAt': '2026-05-06T12:45:00Z',
        }
      ],
      'updatedAt': '2026-05-06T13:00:00Z',
    };
    final unitLeaderboardJson = {
      'entries': [
        {
          'rank': 1,
          'unitId': 'unit-1',
          'unitName': 'Freyport Guard',
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'totalDamage': 420,
          'contributionCount': 6,
          'battleCount': 1,
          'memberCount': 3,
          'score': 438,
          'lastContributedAt': '2026-05-06T12:45:00Z',
        }
      ],
      'updatedAt': '2026-05-06T13:00:00Z',
    };

    final list = CampaignList.fromJson({
      'campaigns': [campaignJson],
      'updatedAt': '2026-05-06T13:00:00Z',
    });
    final details = CampaignDetails.fromJson({
      'campaign': campaignJson,
      'battles': [battleJson],
      'phases': [phaseJson],
      'countryLeaderboard': countryLeaderboardJson,
      'unitLeaderboard': unitLeaderboardJson,
      'updatedAt': '2026-05-06T13:00:00Z',
    });
    final mutation = CampaignMutationResult.fromJson({
      'completed': true,
      'message': 'Campaign phase completed.',
      'campaign': campaignJson,
      'phase': phaseJson,
      'updatedAt': '2026-05-06T13:00:00Z',
    });
    final rewardClaim = CampaignRewardClaimResult.fromJson({
      'completed': true,
      'message': 'Claimed campaign rewards.',
      'campaign': campaignJson,
      'claim': {
        'claimId': 'claim-1',
        'campaignId': 'campaign-greenmarch',
        'playerId': 'player-1',
        'countryId': 'freiland',
        'goldReward': 25,
        'experienceReward': 75,
        'prestigeReward': 3,
        'message': 'Claimed Greenmarch Liberation rewards.',
        'claimedAt': '2026-05-06T13:05:00Z',
      },
      'updatedAt': '2026-05-06T13:05:00Z',
    });

    expect(list.campaigns.single.canClaimRewards, isTrue);
    expect(details.phases.single.progress, 1);
    expect(details.countryLeaderboard.entries.single.victoryCount, 1);
    expect(details.unitLeaderboard.entries.single.unitName, 'Freyport Guard');
    expect(mutation.phase?.isCompleted, isTrue);
    expect(rewardClaim.claim?.prestigeReward, 3);
  });

  test('parses battle contribution result', () {
    final result = BattleContributionResult.fromJson({
      'completed': true,
      'message': 'Battle contribution dealt 42 damage.',
      'battle': {
        'battleId': 'battle-greenmarch',
        'regionId': 'greenmarch',
        'regionName': 'Greenmarch',
        'attackerCountryId': 'nordheim',
        'attackerCountryName': 'Nordheim',
        'attackerCountryCode': 'NRD',
        'defenderCountryId': 'freiland',
        'defenderCountryName': 'Freiland',
        'defenderCountryCode': 'FRL',
        'name': 'Greenmarch Border Clash',
        'description': 'A country battle.',
        'status': 'active',
        'attackerScore': 120,
        'defenderScore': 122,
        'targetScore': 500,
        'defenderStrength': 12,
        'defenderEnergy': 100,
        'defenderWeaponPower': 2,
        'rounds': 3,
        'startedAt': '2026-05-06T12:00:00Z',
        'endsAt': '2099-05-07T12:00:00Z',
        'resolvedAt': null,
        'winnerCountryId': null,
        'winnerCountryName': null,
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'contribution': {
        'contributionId': 'contrib-1',
        'battleId': 'battle-greenmarch',
        'playerId': 'player-1',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'side': 'defender',
        'damage': 42,
        'energySpent': 30,
        'roundsCompleted': 3,
        'won': true,
        'goldReward': 3,
        'experienceReward': 8,
        'message': 'Battle contribution dealt 42 damage.',
        'createdAt': '2026-05-06T12:05:00Z',
      },
      'participation': {
        'playerId': 'player-1',
        'battleId': 'battle-greenmarch',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'side': 'defender',
        'contributionCount': 1,
        'damage': 42,
        'energySpent': 30,
        'goldReward': 3,
        'experienceReward': 8,
        'lastContributedAt': '2026-05-06T12:05:00Z',
      },
      'fight': {
        'winner': 'attacker',
        'rounds_completed': 3,
        'rounds_requested': 3,
        'attacker_damage': 42,
        'defender_damage': 30,
        'attacker_remaining_energy': 70,
        'defender_remaining_energy': 70,
      },
      'missionProgress': {
        'missionId': 'battle:battle-greenmarch',
        'attempts': 1,
        'wins': 1,
        'losses': 0,
        'totalRounds': 3,
        'lastWon': true,
        'lastResult': 'Battle contribution dealt 42 damage.',
        'lastAttemptedAt': '2026-05-06T12:05:00Z',
        'cooldownUntil': '2026-05-06T12:06:00Z',
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'equipment': {
        'playerId': 'player-1',
        'weapon': null,
        'updatedAt': '2026-05-06T12:05:00Z',
      },
      'weaponDamage': null,
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    expect(result.completed, isTrue);
    expect(result.contribution?.damage, 42);
    expect(result.participation?.contributionCount, 1);
    expect(result.fight.roundsCompleted, 3);
    expect(result.missionProgress?.isOnCooldown, isFalse);
  });

  test('parses military unit details and contribution totals', () {
    final unitJson = {
      'unitId': 'unit-1',
      'countryId': 'freiland',
      'countryName': 'Freiland',
      'countryCode': 'FRL',
      'name': 'Freyport Guard',
      'description': 'Defenders of the harbor.',
      'status': 'active',
      'createdByPlayerId': 'player-1',
      'memberCount': 3,
      'totalBattleDamage': 420,
      'activeOrderCount': 1,
      'viewerRole': 'commander',
      'createdAt': '2026-05-06T12:00:00Z',
      'updatedAt': '2026-05-06T12:20:00Z',
    };
    final totalJson = {
      'unitId': 'unit-1',
      'unitName': 'Freyport Guard',
      'battleId': 'battle-greenmarch',
      'battleName': 'Greenmarch Border Clash',
      'countryId': 'freiland',
      'countryName': 'Freiland',
      'countryCode': 'FRL',
      'side': 'defender',
      'totalDamage': 420,
      'contributionCount': 6,
      'memberCount': 2,
      'lastContributedAt': '2026-05-06T12:20:00Z',
      'updatedAt': '2026-05-06T12:20:00Z',
    };
    final divisionJson = {
      'divisionId': 'division-1',
      'unitId': 'unit-1',
      'unitName': 'Freyport Guard',
      'campaignId': 'campaign-greenmarch',
      'campaignName': 'Greenmarch Liberation',
      'name': 'Harbor Rifles',
      'divisionRole': 'infantry',
      'status': 'ready',
      'memberCount': 2,
      'assignedStrength': 120,
      'createdByPlayerId': 'player-1',
      'createdAt': '2026-05-06T12:15:00Z',
      'updatedAt': '2026-05-06T12:15:00Z',
    };
    final deploymentJson = {
      'deploymentOrderId': 'deploy-1',
      'unitId': 'unit-1',
      'divisionId': 'division-1',
      'campaignId': 'campaign-greenmarch',
      'targetBattleId': 'battle-greenmarch',
      'issuedByPlayerId': 'player-1',
      'orderType': 'defense',
      'title': 'Deploy Harbor Rifles',
      'description': 'Hold the campaign front.',
      'troopCommitment': 40,
      'status': 'issued',
      'createdAt': '2026-05-06T12:16:00Z',
      'updatedAt': '2026-05-06T12:16:00Z',
      'executedAt': null,
    };

    final list = MilitaryUnitList.fromJson({
      'units': [unitJson],
      'updatedAt': '2026-05-06T12:20:00Z',
    });
    final details = MilitaryUnitDetails.fromJson({
      'unit': unitJson,
      'members': [
        {
          'memberId': 'member-1',
          'unitId': 'unit-1',
          'playerId': 'player-1',
          'role': 'commander',
          'status': 'active',
          'joinedAt': '2026-05-06T12:00:00Z',
          'leftAt': null,
          'updatedAt': '2026-05-06T12:00:00Z',
        }
      ],
      'orders': [
        {
          'orderId': 'order-1',
          'unitId': 'unit-1',
          'issuedByPlayerId': 'player-1',
          'orderType': 'defend',
          'title': 'Hold Greenmarch',
          'description': 'Focus contributions on defense.',
          'targetBattleId': 'battle-greenmarch',
          'status': 'active',
          'createdAt': '2026-05-06T12:10:00Z',
          'updatedAt': '2026-05-06T12:10:00Z',
          'completedAt': null,
        }
      ],
      'battleTotals': [totalJson],
      'divisions': [divisionJson],
      'deploymentOrders': [deploymentJson],
      'updatedAt': '2026-05-06T12:20:00Z',
    });
    final leaderboard = MilitaryUnitLeaderboard.fromJson({
      'entries': [totalJson],
      'updatedAt': '2026-05-06T12:20:00Z',
    });
    final contributions = UnitBattleContributions.fromJson({
      'unitId': 'unit-1',
      'contributions': [
        {
          'unitContributionId': 'unit-contrib-1',
          'unitId': 'unit-1',
          'unitName': 'Freyport Guard',
          'battleId': 'battle-greenmarch',
          'battleName': 'Greenmarch Border Clash',
          'battleContributionId': 'contrib-1',
          'playerId': 'player-1',
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'side': 'defender',
          'damage': 70,
          'energySpent': 20,
          'createdAt': '2026-05-06T12:20:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:20:00Z',
    });
    final mutation = MilitaryUnitMutationResult.fromJson({
      'completed': true,
      'message': 'Joined Freyport Guard.',
      'unit': unitJson,
      'updatedAt': '2026-05-06T12:20:00Z',
    });
    final divisionMutation = UnitDivisionMutationResult.fromJson({
      'completed': true,
      'message': 'Division created.',
      'division': divisionJson,
      'updatedAt': '2026-05-06T12:20:00Z',
    });
    final deploymentMutation = DeploymentOrderMutationResult.fromJson({
      'completed': true,
      'message': 'Deployment order issued.',
      'order': deploymentJson,
      'updatedAt': '2026-05-06T12:20:00Z',
    });

    expect(list.myUnits.single.canManageOrders, isTrue);
    expect(details.orders.single.targetBattleId, 'battle-greenmarch');
    expect(details.battleTotals.single.totalDamage, 420);
    expect(details.divisions.single.assignedStrength, 120);
    expect(details.deploymentOrders.single.isIssued, isTrue);
    expect(leaderboard.entries.single.memberCount, 2);
    expect(contributions.contributions.single.damage, 70);
    expect(mutation.unit?.countryCode, 'FRL');
    expect(divisionMutation.division?.campaignId, 'campaign-greenmarch');
    expect(deploymentMutation.order?.troopCommitment, 40);
  });

  test('parses newspaper catalog and article interactions', () {
    final catalog = NewspaperCatalog.fromJson({
      'playerId': 'player-1',
      'updatedAt': '2026-05-06T12:30:00Z',
      'newspapers': [
        {
          'newspaperId': 'newspaper-1',
          'ownerPlayerId': 'player-1',
          'name': 'Daily Frei',
          'description': 'Player-run news.',
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:10:00Z',
          'subscriberCount': 3,
          'articleCount': 1,
          'isSubscribed': true,
        }
      ],
    });

    final articleList = NewspaperArticleList.fromJson({
      'newspaperId': 'newspaper-1',
      'updatedAt': '2026-05-06T12:30:00Z',
      'articles': [
        {
          'articleId': 'article-1',
          'newspaperId': 'newspaper-1',
          'newspaperName': 'Daily Frei',
          'newspaperOwnerPlayerId': 'player-1',
          'authorPlayerId': 'player-1',
          'title': 'Factory boom',
          'content':
              'Factories are producing more food after the latest citizen investments.',
          'publishedAt': '2026-05-06T12:05:00Z',
          'updatedAt': '2026-05-06T12:15:00Z',
          'voteScore': 2,
          'upvotes': 3,
          'downvotes': 1,
          'playerVote': 1,
          'commentCount': 1,
          'comments': [
            {
              'commentId': 'comment-1',
              'articleId': 'article-1',
              'authorPlayerId': 'player-2',
              'content': 'Great reporting.',
              'createdAt': '2026-05-06T12:20:00Z',
            }
          ],
        }
      ],
    });

    final publication = ArticlePublicationResult.fromJson({
      'completed': true,
      'message': 'Published Factory boom.',
      'subscriberPlayerIds': ['player-2'],
      'article': {
        'articleId': 'article-1',
        'newspaperId': 'newspaper-1',
        'newspaperName': 'Daily Frei',
        'newspaperOwnerPlayerId': 'player-1',
        'authorPlayerId': 'player-1',
        'title': 'Factory boom',
        'content':
            'Factories are producing more food after the latest citizen investments.',
        'publishedAt': '2026-05-06T12:05:00Z',
        'updatedAt': '2026-05-06T12:15:00Z',
        'voteScore': 0,
        'upvotes': 0,
        'downvotes': 0,
        'playerVote': null,
        'commentCount': 0,
        'comments': [],
      },
    });

    final report = ContentReportResult.fromJson({
      'completed': true,
      'message': 'Report submitted for moderator review.',
      'itemId': 'content-1',
      'status': 'open',
      'reportCount': 1,
    });

    expect(catalog.newspapers.single.name, 'Daily Frei');
    expect(catalog.newspapers.single.isSubscribed, isTrue);
    expect(articleList.articles.single.comments.single.content,
        'Great reporting.');
    expect(articleList.articles.single.playerVote, 1);
    expect(publication.completed, isTrue);
    expect(publication.article.newspaperName, 'Daily Frei');
    expect(report.itemId, 'content-1');
    expect(report.reportCount, 1);
  });

  test('parses politics parties elections votes and offices', () {
    final parties = PoliticalPartyList.fromJson({
      'parties': [
        {
          'partyId': 'party-freiland-civic-union',
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'name': 'Civic Union',
          'shortName': 'CU',
          'description': 'A civic party.',
          'ideology': 'Civic republicanism',
          'founderPlayerId': 'world-catalog',
          'status': 'active',
          'memberCount': 12,
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:00:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:00:00Z',
    });

    final status = PlayerPoliticsStatus.fromJson({
      'playerId': 'player-1',
      'citizenship': {
        'playerId': 'player-1',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'status': 'active',
        'joinedAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'membership': {
        'membershipId': 'membership-1',
        'partyId': 'party-freiland-civic-union',
        'partyName': 'Civic Union',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'playerId': 'player-1',
        'role': 'member',
        'status': 'active',
        'joinedAt': '2026-05-06T12:00:00Z',
        'leftAt': null,
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'candidacies': [
        {
          'candidacyId': 'candidacy-1',
          'electionId': 'election-1',
          'playerId': 'player-1',
          'partyId': 'party-freiland-civic-union',
          'partyName': 'Civic Union',
          'partyShortName': 'CU',
          'manifesto': 'Build the country.',
          'status': 'active',
          'voteCount': 3,
          'declaredAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:00:00Z',
        }
      ],
      'votes': [
        {
          'voteId': 'vote-1',
          'electionId': 'election-1',
          'voterPlayerId': 'player-1',
          'candidacyId': 'candidacy-1',
          'candidatePlayerId': 'player-1',
          'countryId': 'freiland',
          'castAt': '2026-05-06T12:05:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    final elections = ElectionList.fromJson({
      'elections': [
        {
          'electionId': 'election-1',
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'officeId': 'president',
          'officeName': 'President',
          'title': 'Freiland presidential election',
          'description': 'Choose a president.',
          'status': 'voting',
          'votingStartsAt': '2026-05-06T12:00:00Z',
          'votingEndsAt': '2099-05-09T12:00:00Z',
          'termStartsAt': '2099-05-09T12:00:00Z',
          'termEndsAt': '2099-06-08T12:00:00Z',
          'candidateCount': 1,
          'voteCount': 3,
          'updatedAt': '2026-05-06T12:05:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    final details = ElectionDetails.fromJson({
      'election': {
        'electionId': 'election-1',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'officeId': 'president',
        'officeName': 'President',
        'title': 'Freiland presidential election',
        'description': 'Choose a president.',
        'status': 'resolved',
        'votingStartsAt': '2026-05-06T12:00:00Z',
        'votingEndsAt': '2026-05-09T12:00:00Z',
        'termStartsAt': '2026-05-09T12:00:00Z',
        'termEndsAt': '2026-06-08T12:00:00Z',
        'candidateCount': 1,
        'voteCount': 3,
        'updatedAt': '2026-05-09T12:00:00Z',
      },
      'candidacies': [
        {
          'candidacy_id': 'candidacy-1',
          'election_id': 'election-1',
          'player_id': 'player-1',
          'party_id': 'party-freiland-civic-union',
          'party_name': 'Civic Union',
          'party_short_name': 'CU',
          'manifesto': 'Build the country.',
          'status': 'active',
          'vote_count': 3,
          'declared_at': '2026-05-06T12:00:00Z',
          'updated_at': '2026-05-06T12:00:00Z',
        }
      ],
      'results': [
        {
          'candidacyId': 'candidacy-1',
          'electionId': 'election-1',
          'playerId': 'player-1',
          'partyId': 'party-freiland-civic-union',
          'partyName': 'Civic Union',
          'partyShortName': 'CU',
          'votes': 3,
          'rank': 1,
          'isWinner': true,
        }
      ],
      'updatedAt': '2026-05-09T12:00:00Z',
    });

    final holders = OfficeHolderList.fromJson({
      'officeHolders': [
        {
          'termId': 'term-1',
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'officeId': 'president',
          'officeName': 'President',
          'playerId': 'player-1',
          'partyId': 'party-freiland-civic-union',
          'partyName': 'Civic Union',
          'sourceElectionId': 'election-1',
          'status': 'active',
          'startedAt': '2026-05-09T12:00:00Z',
          'endsAt': '2026-06-08T12:00:00Z',
          'updatedAt': '2026-05-09T12:00:00Z',
        }
      ],
      'updatedAt': '2026-05-09T12:00:00Z',
    });

    expect(parties.parties.single.shortName, 'CU');
    expect(status.membership?.partyName, 'Civic Union');
    expect(status.hasVoted('election-1'), isTrue);
    expect(elections.elections.single.isVoting, isTrue);
    expect(details.results.single.isWinner, isTrue);
    expect(holders.officeHolders.single.playerId, 'player-1');
  });
}

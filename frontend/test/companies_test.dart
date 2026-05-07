import 'package:ff/models/GameAreas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses company portfolio and membership flags', () {
    final portfolio = CompanyPortfolio.fromJson({
      'playerId': 'player-1',
      'companies': [
        {
          'companyId': 'co-1',
          'name': 'Forge Guild',
          'description': 'Shared production',
          'ownerPlayerId': 'player-1',
          'walletGold': 500,
          'storageUsed': 120,
          'storageLimit': 200,
          'hqLevel': 1,
          'specialization': 'general',
          'factorySlots': 2,
          'productivityBonusPercent': 0,
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:05:00Z',
          'memberCount': 2,
          'factoryCount': 2,
          'role': 'owner',
          'isMember': true,
          'canManage': true,
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    final company = portfolio.companies.single;
    expect(company.name, 'Forge Guild');
    expect(company.isMember, isTrue);
    expect(company.canManage, isTrue);
    expect(company.walletGold, 500);
  });

  test('parses company detail assets, members, and production jobs', () {
    final detail = CompanyDetail.fromJson(_companyDetailJson());

    expect(detail.members, hasLength(2));
    expect(detail.members.first.role, 'owner');
    expect(detail.assets.inventory.single.itemId, 'grain');
    expect(detail.assets.factories.single.factoryId, 'food-factory');
    expect(detail.assets.workforceJobs.single.wageGold, 30);
    expect(detail.assets.workRecords.single.netWageGold, 27);
    expect(detail.assets.upgrades.hqLevel, 1);
    expect(detail.assets.upgrades.nextHqUpgrade.nextLevel, 2);
    expect(detail.assets.upgrades.specializationOptions, hasLength(2));
    expect(
        detail.assets.jobsForFactory('food-factory').single.canClaim, isTrue);
  });

  test('parses company mutation and production claim result', () {
    final mutation = CompanyMutationResult.fromJson({
      'completed': true,
      'message': 'Joined Forge Guild.',
      'company': _companyDetailJson(),
    });
    final claim = CompanyProductionClaimResult.fromJson({
      'completed': true,
      'message': 'Claimed output into company inventory.',
      'claim': {
        'completed': true,
        'alreadyClaimed': false,
        'message': 'Claimed output into company inventory.',
        'job': _jobJson(),
        'productionCount': 3,
      },
      'assets': _companyDetailJson()['assets'],
    });

    expect(mutation.company?.companyId, 'co-1');
    expect(claim.claim.productionCount, 3);
    expect(claim.assets.productionJobs.single.jobId, 'cjob-1');
  });

  test('parses company job market and work result', () {
    final jobs = CompanyJobList.fromJson({
      'companyId': 'co-1',
      'jobs': [_workforceJobJson()],
      'updatedAt': '2026-05-06T12:06:00Z',
    });
    final work = CompanyWorkResult.fromJson({
      'completed': true,
      'message': 'Paid 27 gold net wage.',
      'job': _workforceJobJson(),
      'workRecord': _workRecordJson(),
      'assets': _companyDetailJson()['assets'],
      'wallet': {
        'playerId': 'player-2',
        'walletGold': 127,
        'storageUsed': 0,
        'storageLimit': 100,
        'items': [],
        'updatedAt': '2026-05-06T12:06:00Z',
      },
      'taxCollections': [],
    });

    expect(jobs.jobs.single.isActive, isTrue);
    expect(jobs.jobs.single.isDailyLimitReached, isFalse);
    expect(work.workRecord.taxGold, 3);
    expect(work.wallet?.walletGold, 127);
  });

  test('parses company upgrade mutation result', () {
    final result = CompanyUpgradeMutationResult.fromJson({
      'completed': true,
      'message': 'Company HQ upgraded to level 2.',
      'upgrades': _companyUpgradesJson(hqLevel: 2),
      'company': _companyDetailJson(),
    });

    expect(result.completed, isTrue);
    expect(result.upgrades.hqLevel, 2);
    expect(result.upgrades.nextHqUpgrade.goldCost, 750);
    expect(result.company?.assets.upgrades.factorySlots, 2);
  });
}

Map<String, dynamic> _companyDetailJson() {
  return {
    'companyId': 'co-1',
    'name': 'Forge Guild',
    'description': 'Shared production',
    'ownerPlayerId': 'player-1',
    'walletGold': 500,
    'storageUsed': 80,
    'storageLimit': 200,
    'hqLevel': 1,
    'specialization': 'general',
    'factorySlots': 2,
    'productivityBonusPercent': 0,
    'createdAt': '2026-05-06T12:00:00Z',
    'updatedAt': '2026-05-06T12:05:00Z',
    'memberCount': 2,
    'factoryCount': 1,
    'role': 'owner',
    'isMember': true,
    'canManage': true,
    'members': [
      {
        'playerId': 'player-1',
        'role': 'owner',
        'joinedAt': '2026-05-06T12:00:00Z',
        'canManage': true,
      },
      {
        'playerId': 'player-2',
        'role': 'member',
        'joinedAt': '2026-05-06T12:01:00Z',
        'canManage': false,
      }
    ],
    'assets': {
      'companyId': 'co-1',
      'walletGold': 500,
      'storageUsed': 80,
      'storageLimit': 200,
      'upgrades': _companyUpgradesJson(),
      'inventory': [
        {
          'itemId': 'grain',
          'name': 'Grain',
          'category': 'Raw material',
          'quantity': 80,
          'description': 'Starter input',
        }
      ],
      'factories': [
        {
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
          'lastProducedAt': '2026-05-06T12:02:00Z',
          'cooldownUntil': null,
          'productionDurationSeconds': 90,
          'activeJobId': 'cjob-1',
          'queueDepth': 1,
          'maxQueueDepth': 3,
        }
      ],
      'productionJobs': [_jobJson()],
      'workforceJobs': [_workforceJobJson()],
      'workRecords': [_workRecordJson()],
      'updatedAt': '2026-05-06T12:05:00Z',
    }
  };
}

Map<String, dynamic> _companyUpgradesJson({int hqLevel = 1}) {
  final nextLevel = hqLevel + 1;
  return {
    'companyId': 'co-1',
    'hqLevel': hqLevel,
    'specialization': 'general',
    'factorySlots': 2,
    'usedFactorySlots': 1,
    'availableFactorySlots': 1,
    'storageUsed': 80,
    'storageLimit': hqLevel == 1 ? 200 : 300,
    'productivityBonusPercent': hqLevel == 1 ? 0 : 5,
    'nextHqUpgrade': {
      'upgradeType': 'hq',
      'currentLevel': hqLevel,
      'nextLevel': nextLevel,
      'goldCost': 250 * nextLevel,
      'requiredItemId': 'labor_credit',
      'requiredItemName': 'Labor Credit',
      'requiredItemQuantity': 10 * nextLevel,
      'availableGold': 500,
      'availableItemQuantity': 25,
      'storageLimitAfterUpgrade': hqLevel == 1 ? 300 : 400,
      'factorySlotsAfterUpgrade': 3,
      'productivityBonusPercentAfterUpgrade': hqLevel == 1 ? 5 : 10,
      'canUpgrade': true,
      'message': 'Upgrade HQ to level $nextLevel.',
    },
    'specializationOptions': [
      {
        'specialization': 'general',
        'name': 'General industry',
        'description': 'Balanced company production.',
        'affectedCategory': 'All',
        'productivityBonusPercent': 0,
        'isSelected': true,
        'goldCost': 100,
        'requiredItemId': 'labor_credit',
        'requiredItemName': 'Labor Credit',
        'requiredItemQuantity': 5,
      },
      {
        'specialization': 'food',
        'name': 'Food consortium',
        'description': 'Food factory bonus.',
        'affectedCategory': 'Food',
        'productivityBonusPercent': 10,
        'isSelected': false,
        'goldCost': 100,
        'requiredItemId': 'labor_credit',
        'requiredItemName': 'Labor Credit',
        'requiredItemQuantity': 5,
      }
    ],
    'canManageUpgrades': true,
    'updatedAt': '2026-05-06T12:05:00Z',
  };
}

Map<String, dynamic> _jobJson() {
  return {
    'jobId': 'cjob-1',
    'playerId': 'player-1',
    'factoryId': 'food-factory',
    'status': 'completed',
    'inputItemId': 'grain',
    'inputItemName': 'Grain',
    'inputItemCategory': 'Raw material',
    'inputQuantity': 5,
    'outputItemId': 'food',
    'outputItemName': 'Food',
    'outputItemCategory': 'Food',
    'outputQuantity': 3,
    'durationSeconds': 90,
    'startedAt': '2026-05-06T12:00:00Z',
    'completesAt': '2026-05-06T12:01:30Z',
    'completedAt': '2026-05-06T12:01:30Z',
    'claimedAt': null,
    'createdAt': '2026-05-06T12:00:00Z',
    'updatedAt': '2026-05-06T12:01:30Z',
    'canClaim': true,
  };
}

Map<String, dynamic> _workforceJobJson() {
  return {
    'jobId': 'wjob-1',
    'companyId': 'co-1',
    'companyName': 'Forge Guild',
    'title': 'Factory shift',
    'description': 'Help the company produce goods.',
    'wageGold': 30,
    'requiredEnergy': 10,
    'dailyLimit': 2,
    'productivityReward': 1,
    'status': 'active',
    'isActive': true,
    'createdByPlayerId': 'player-1',
    'createdAt': '2026-05-06T12:00:00Z',
    'updatedAt': '2026-05-06T12:05:00Z',
    'closedAt': null,
    'workCount': 4,
    'todayWorkCount': 1,
  };
}

Map<String, dynamic> _workRecordJson() {
  return {
    'workId': 'work-1',
    'jobId': 'wjob-1',
    'companyId': 'co-1',
    'playerId': 'player-2',
    'idempotencyKey': 'company-work-1',
    'grossWageGold': 30,
    'netWageGold': 27,
    'taxGold': 3,
    'requiredEnergy': 10,
    'productivityReward': 1,
    'status': 'paid',
    'workDate': '2026-05-06',
    'workedAt': '2026-05-06T12:06:00Z',
    'paidAt': '2026-05-06T12:06:01Z',
    'createdAt': '2026-05-06T12:06:00Z',
    'updatedAt': '2026-05-06T12:06:01Z',
  };
}

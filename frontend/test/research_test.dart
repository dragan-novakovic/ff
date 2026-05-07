import 'package:ff/models/GameAreas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses research dashboard and production speed bonus', () {
    final dashboard = ResearchDashboard.fromJson({
      'playerId': 'player-1',
      'citizenship': {
        'playerId': 'player-1',
        'countryId': 'country-1',
        'countryName': 'Freiland',
        'countryCode': 'FF',
        'status': 'active',
        'joinedAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'country': _scopeStateJson('country', 'country-1'),
      'companies': [
        {
          'companyId': 'co-1',
          'name': 'Forge Guild',
          'role': 'owner',
          'canManageResearch': true,
        }
      ],
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    expect(dashboard.citizenship?.countryName, 'Freiland');
    expect(dashboard.country?.availablePoints, 120);
    expect(dashboard.country?.productionSpeedBonusPercent, 10);
    expect(dashboard.country?.technologies.single.project?.canComplete, isTrue);
    expect(dashboard.companies.single.canManageResearch, isTrue);
  });

  test('parses research mutation state and production job research field', () {
    final mutation = ResearchMutationResult.fromJson({
      'completed': true,
      'message': 'Completed Agricultural Mechanization.',
      'project': _projectJson(),
      'state': _scopeStateJson('country', 'country-1'),
      'activeBonuses': [_bonusJson()],
      'updatedAt': '2026-05-06T12:12:00Z',
    });
    final job = ProductionJob.fromJson({
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
      'outputItemCategory': 'Food',
      'outputQuantity': 3,
      'durationSeconds': 81,
      'startedAt': '2026-05-06T12:00:00Z',
      'completesAt': '2026-05-06T12:01:21Z',
      'completedAt': null,
      'claimedAt': null,
      'createdAt': '2026-05-06T12:00:00Z',
      'updatedAt': '2026-05-06T12:00:00Z',
      'canClaim': false,
      'appliedBonus': null,
      'researchDurationReductionPercent': 10,
    });

    expect(mutation.state?.completedTechnologyIds, contains('agri-1'));
    expect(mutation.activeBonuses.single.totalValue, 10);
    expect(job.researchDurationReductionPercent, 10);
    expect(job.durationSeconds, 81);
  });
}

Map<String, dynamic> _scopeStateJson(String scopeType, String scopeId) {
  return {
    'scopeType': scopeType,
    'scopeId': scopeId,
    'actorPlayerId': 'player-1',
    'availablePoints': 120,
    'lifetimePoints': 180,
    'pointCap': 750,
    'hourlyPointRate': 15,
    'lastAccruedAt': '2026-05-06T12:00:00Z',
    'technologies': [
      {
        'technology': _technologyJson(scopeType),
        'status': 'ready',
        'isCompleted': false,
        'canStart': false,
        'blockedReason': 'Research already active.',
        'project': _projectJson(),
      }
    ],
    'activeProjects': [_projectJson()],
    'completedTechnologyIds': ['agri-1'],
    'bonuses': [_bonusJson()],
    'updatedAt': '2026-05-06T12:10:00Z',
  };
}

Map<String, dynamic> _technologyJson(String scopeType) {
  return {
    'technologyId': 'agri-1',
    'scopeType': scopeType,
    'track': 'industry',
    'name': 'Agricultural Mechanization',
    'description': 'Improves food factory throughput.',
    'tier': 1,
    'prerequisiteTechnologyIds': [],
    'requiredPoints': 100,
    'durationSeconds': 60,
    'bonus': {
      'bonusType': 'production_speed_percent',
      'bonusValue': 10,
      'bonusTarget': 'citizen_factories',
      'description': 'Factory production runs finish 10% faster.',
    },
    'updatedAt': '2026-05-06T12:00:00Z',
  };
}

Map<String, dynamic> _projectJson() {
  return {
    'projectId': 'project-1',
    'scopeType': 'country',
    'scopeId': 'country-1',
    'technologyId': 'agri-1',
    'status': 'active',
    'requiredPoints': 100,
    'contributedPoints': 100,
    'remainingPoints': 0,
    'progressPercent': 100,
    'durationSeconds': 60,
    'startedAt': '2026-05-06T12:00:00Z',
    'readyAt': '2026-05-06T12:01:00Z',
    'completedAt': null,
    'canComplete': true,
    'updatedAt': '2026-05-06T12:01:00Z',
  };
}

Map<String, dynamic> _bonusJson() {
  return {
    'bonusType': 'production_speed_percent',
    'bonusTarget': 'citizen_factories',
    'totalValue': 10,
    'sourceTechnologyIds': ['agri-1'],
    'description': 'Factory production runs finish 10% faster.',
    'updatedAt': '2026-05-06T12:01:00Z',
  };
}

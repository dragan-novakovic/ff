import 'package:ff/models/DailyObjectives.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses daily objectives summary from backend JSON', () {
    final summary = DailyObjectivesSummary.fromJson({
      'playerId': 'player-1',
      'resetDate': '2026-05-06',
      'resetAt': '2026-05-07T00:00:00Z',
      'updatedAt': '2026-05-06T12:00:00Z',
      'objectives': [
        {
          'objectiveId': 'daily-work-shift',
          'actionType': 'work',
          'title': 'Work a shift',
          'description': 'Complete one work action.',
          'currentCount': 1,
          'targetCount': 1,
          'rewards': {
            'gold': 20,
            'experience': 5,
            'strength': 0,
            'energy': 0,
          },
          'completed': true,
          'claimed': false,
          'completedAt': '2026-05-06T12:00:00Z',
          'claimedAt': null,
          'resetDate': '2026-05-06',
          'resetAt': '2026-05-07T00:00:00Z',
          'displayOrder': 10,
        }
      ],
    });

    expect(summary.playerId, 'player-1');
    expect(summary.resetDate, DateTime.parse('2026-05-06'));
    expect(summary.objectives, hasLength(1));
    expect(summary.claimableCount, 1);
    expect(summary.objectives.single.progress, 1);
    expect(summary.objectives.single.rewards.gold, 20);
    expect(summary.objectives.single.claimable, isTrue);
  });

  test('parses daily objective claim result with state and wallet', () {
    final result = DailyObjectiveClaimResult.fromJson({
      'completed': true,
      'message': 'Claimed Work a shift.',
      'rewards': {
        'gold': 20,
        'experience': 5,
        'strength': 0,
        'energy': 0,
      },
      'state': {
        'playerId': 'player-1',
        'level': 1,
        'experience': 15,
        'experienceToNextLevel': 85,
        'energy': 100,
        'maxEnergy': 100,
        'strength': 10,
        'gold': 100,
        'hasWorkedToday': true,
        'hasTrainedToday': false,
        'nextResetAt': '2026-05-07T00:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
        'lastEnergyRegeneratedAt': '2026-05-06T12:00:00Z',
        'nextEnergyRegenAt': null,
        'energyRegenSeconds': 300,
        'energyRegenAmount': 1,
        'hospitalCooldownUntil': null,
        'hospitalEnergyRestore': 50,
        'hospitalGoldCost': 30,
      },
      'objective': {
        'objectiveId': 'daily-work-shift',
        'actionType': 'work',
        'title': 'Work a shift',
        'description': 'Complete one work action.',
        'currentCount': 1,
        'targetCount': 1,
        'rewards': {
          'gold': 20,
          'experience': 5,
          'strength': 0,
          'energy': 0,
        },
        'completed': true,
        'claimed': true,
        'completedAt': '2026-05-06T12:00:00Z',
        'claimedAt': '2026-05-06T12:01:00Z',
        'resetDate': '2026-05-06',
        'resetAt': '2026-05-07T00:00:00Z',
        'displayOrder': 10,
      },
      'objectives': {
        'playerId': 'player-1',
        'resetDate': '2026-05-06',
        'resetAt': '2026-05-07T00:00:00Z',
        'updatedAt': '2026-05-06T12:01:00Z',
        'objectives': [
          {
            'objectiveId': 'daily-work-shift',
            'actionType': 'work',
            'title': 'Work a shift',
            'description': 'Complete one work action.',
            'currentCount': 1,
            'targetCount': 1,
            'rewards': {
              'gold': 20,
              'experience': 5,
              'strength': 0,
              'energy': 0,
            },
            'completed': true,
            'claimed': true,
            'completedAt': '2026-05-06T12:00:00Z',
            'claimedAt': '2026-05-06T12:01:00Z',
            'resetDate': '2026-05-06',
            'resetAt': '2026-05-07T00:00:00Z',
            'displayOrder': 10,
          }
        ],
      },
      'wallet': {
        'playerId': 'player-1',
        'walletGold': 145,
        'storageUsed': 0,
        'storageLimit': 100,
        'items': [],
        'updatedAt': '2026-05-06T12:01:00Z',
      },
    });

    expect(result.completed, isTrue);
    expect(result.state?.experience, 15);
    expect(result.objective?.claimed, isTrue);
    expect(result.objectives.claimableCount, 0);
    expect(result.wallet?.walletGold, 145);
  });
}

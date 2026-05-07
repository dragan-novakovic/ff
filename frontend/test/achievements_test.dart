import 'package:ff/models/Achievements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses achievements summary with progress and recent unlocks', () {
    final summary = AchievementsSummary.fromJson({
      'playerId': 'player-1',
      'totalUnlocked': 2,
      'totalAvailable': 4,
      'totalPoints': 35,
      'unclaimedCount': 1,
      'updatedAt': '2026-05-06T12:00:00Z',
      'achievements': [
        {
          'achievementId': 'first-work-shift',
          'actionType': 'work',
          'title': 'First Shift',
          'description': 'Complete your first work action.',
          'category': 'Work & Training',
          'medalName': 'Bronze Worker Medal',
          'medalRarity': 'bronze',
          'points': 10,
          'currentCount': 1,
          'targetCount': 1,
          'unlocked': true,
          'claimed': false,
          'unlockedAt': '2026-05-06T10:00:00Z',
          'claimedAt': null,
          'displayOrder': 10,
        },
        {
          'achievementId': 'steady-worker',
          'actionType': 'work',
          'title': 'Steady Worker',
          'description': 'Complete five work actions.',
          'category': 'Work & Training',
          'medalName': 'Silver Worker Medal',
          'medalRarity': 'silver',
          'points': 25,
          'currentCount': 2,
          'targetCount': 5,
          'unlocked': false,
          'claimed': false,
          'unlockedAt': null,
          'claimedAt': null,
          'displayOrder': 20,
        },
      ],
      'recentUnlocks': [
        {
          'achievementId': 'first-work-shift',
          'title': 'First Shift',
          'category': 'Work & Training',
          'medalName': 'Bronze Worker Medal',
          'medalRarity': 'bronze',
          'points': 10,
          'awardedAt': '2026-05-06T10:00:00Z',
          'claimed': false,
        },
      ],
    });

    expect(summary.playerId, 'player-1');
    expect(summary.progress, 0.5);
    expect(summary.unclaimedCount, 1);
    expect(summary.achievements.first.claimable, isTrue);
    expect(summary.achievements.last.progress, 0.4);
    expect(summary.recentUnlocks.single.medalName, 'Bronze Worker Medal');
  });

  test('parses achievement claim result', () {
    final result = AchievementClaimResult.fromJson({
      'completed': true,
      'message': 'Claimed Bronze Worker Medal.',
      'achievement': _achievementJson(claimed: true),
      'achievements': {
        'playerId': 'player-1',
        'totalUnlocked': 1,
        'totalAvailable': 1,
        'totalPoints': 10,
        'unclaimedCount': 0,
        'updatedAt': '2026-05-06T12:00:00Z',
        'achievements': [_achievementJson(claimed: true)],
        'recentUnlocks': [
          {
            'achievementId': 'first-work-shift',
            'title': 'First Shift',
            'category': 'Work & Training',
            'medalName': 'Bronze Worker Medal',
            'medalRarity': 'bronze',
            'points': 10,
            'awardedAt': '2026-05-06T10:00:00Z',
            'claimed': true,
          }
        ],
      },
    });

    expect(result.completed, isTrue);
    expect(result.achievement?.claimed, isTrue);
    expect(result.achievements.unclaimedCount, 0);
  });
}

Map<String, dynamic> _achievementJson({required bool claimed}) {
  return {
    'achievementId': 'first-work-shift',
    'actionType': 'work',
    'title': 'First Shift',
    'description': 'Complete your first work action.',
    'category': 'Work & Training',
    'medalName': 'Bronze Worker Medal',
    'medalRarity': 'bronze',
    'points': 10,
    'currentCount': 1,
    'targetCount': 1,
    'unlocked': true,
    'claimed': claimed,
    'unlockedAt': '2026-05-06T10:00:00Z',
    'claimedAt': claimed ? '2026-05-06T12:00:00Z' : null,
    'displayOrder': 10,
  };
}

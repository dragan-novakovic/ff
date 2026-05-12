import 'package:ff/models/TrainingGrounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses training grounds dashboard with recent sessions', () {
    final summary = TrainingGroundsSummary.fromJson({
      'playerId': 'player-1',
      'state': {
        'playerId': 'player-1',
        'level': 2,
        'experience': 125,
        'experienceToNextLevel': 75,
        'energy': 80,
        'maxEnergy': 100,
        'strength': 12,
        'gold': 150,
        'hasWorkedToday': false,
        'hasTrainedToday': true,
        'nextResetAt': '2026-05-13T00:00:00Z',
        'updatedAt': '2026-05-12T12:00:00Z',
        'lastEnergyRegeneratedAt': '2026-05-12T11:55:00Z',
        'nextEnergyRegenAt': '2026-05-12T12:05:00Z',
        'energyRegenSeconds': 300,
        'energyRegenAmount': 1,
        'hospitalCooldownUntil': null,
        'hospitalEnergyRestore': 50,
        'hospitalGoldCost': 30,
      },
      'canTrainToday': false,
      'hasTrainedToday': true,
      'nextResetAt': '2026-05-13T00:00:00Z',
      'strengthReward': 1,
      'experienceReward': 15,
      'recentSessions': [
        {
          'sessionId': 'training:player-1:2026-05-12',
          'playerId': 'player-1',
          'resetDate': '2026-05-12',
          'strengthBefore': 11,
          'strengthAfter': 12,
          'experienceBefore': 110,
          'experienceAfter': 125,
          'levelBefore': 2,
          'levelAfter': 2,
          'strengthGained': 1,
          'experienceGained': 15,
          'trainedAt': '2026-05-12T12:00:00Z',
        },
      ],
      'updatedAt': '2026-05-12T12:00:00Z',
    });

    expect(summary.playerId, 'player-1');
    expect(summary.canTrainToday, isFalse);
    expect(summary.strengthReward, 1);
    expect(summary.experienceReward, 15);
    expect(summary.state.strength, 12);
    expect(summary.recentSessions.single.strengthGained, 1);
    expect(summary.recentSessions.single.resetDate, '2026-05-12');
  });
}

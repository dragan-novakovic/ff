import 'package:ff/models/PlayerState.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses player state from backend JSON', () {
    final state = PlayerState.fromJson({
      'playerId': 'player-1',
      'level': 2,
      'experience': 125,
      'experienceToNextLevel': 75,
      'energy': 80,
      'maxEnergy': 100,
      'strength': 12,
      'gold': 150,
      'hasWorkedToday': true,
      'hasTrainedToday': false,
      'nextResetAt': '2026-05-07T00:00:00Z',
      'updatedAt': '2026-05-06T12:00:00Z',
      'lastEnergyRegeneratedAt': '2026-05-06T11:55:00Z',
      'nextEnergyRegenAt': '2026-05-06T12:05:00Z',
      'energyRegenSeconds': 300,
      'energyRegenAmount': 1,
      'hospitalCooldownUntil': '2099-05-06T12:30:00Z',
      'hospitalEnergyRestore': 50,
      'hospitalGoldCost': 30,
    });

    expect(state.playerId, 'player-1');
    expect(state.level, 2);
    expect(state.energyProgress, 0.8);
    expect(state.experienceProgress, 0.25);
    expect(state.hasWorkedToday, isTrue);
    expect(state.hasTrainedToday, isFalse);
    expect(state.nextEnergyRegenAt, DateTime.parse('2026-05-06T12:05:00Z'));
    expect(state.energyRegenSeconds, 300);
    expect(state.hospitalEnergyRestore, 50);
    expect(state.hospitalGoldCost, 30);
    expect(state.canRecoverAtHospital, isFalse);
  });

  test('parses player action response with updated state', () {
    final result = PlayerActionResult.fromJson({
      'completed': true,
      'message': 'Work complete.',
      'rewards': {'gold': 25, 'experience': 10, 'strength': 0, 'energy': 0},
      'state': {
        'playerId': 'player-1',
        'level': 1,
        'experience': 10,
        'experienceToNextLevel': 90,
        'energy': 100,
        'maxEnergy': 100,
        'strength': 10,
        'gold': 125,
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
    });

    expect(result.completed, isTrue);
    expect(result.rewards.gold, 25);
    expect(result.rewards.energy, 0);
    expect(result.state.gold, 125);
  });
}

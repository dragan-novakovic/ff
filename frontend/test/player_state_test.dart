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
    });

    expect(state.playerId, 'player-1');
    expect(state.level, 2);
    expect(state.energyProgress, 0.8);
    expect(state.experienceProgress, 0.25);
    expect(state.hasWorkedToday, isTrue);
    expect(state.hasTrainedToday, isFalse);
  });

  test('parses player action response with updated state', () {
    final result = PlayerActionResult.fromJson({
      'completed': true,
      'message': 'Work complete.',
      'rewards': {'gold': 25, 'experience': 10, 'strength': 0},
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
      },
    });

    expect(result.completed, isTrue);
    expect(result.rewards.gold, 25);
    expect(result.state.gold, 125);
  });
}

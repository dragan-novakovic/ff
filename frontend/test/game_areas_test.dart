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
}

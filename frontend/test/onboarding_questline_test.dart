import 'package:ff/models/OnboardingQuestline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses onboarding questline and current step', () {
    final questline = OnboardingQuestline.fromJson({
      'playerId': 'player-1',
      'status': 'in_progress',
      'completedCount': 1,
      'totalCount': 2,
      'completionPercent': 50,
      'updatedAt': '2026-05-06T12:00:00Z',
      'currentQuest': _questJson(
        questId: 'first-work',
        actionType: 'work',
        completed: false,
      ),
      'quests': [
        _questJson(
          questId: 'choose-country',
          actionType: 'choose_country',
          completed: true,
          currentCount: 1,
          completedAt: '2026-05-06T11:00:00Z',
        ),
        _questJson(
          questId: 'first-work',
          actionType: 'work',
          completed: false,
        ),
      ],
    });

    expect(questline.playerId, 'player-1');
    expect(questline.currentQuest?.questId, 'first-work');
    expect(questline.completionPercent, 50);
    expect(questline.quests.first.claimable, isTrue);
    expect(questline.quests.last.progress, 0);
  });

  test('parses onboarding claim result with player state and wallet', () {
    final result = OnboardingQuestClaimResult.fromJson({
      'completed': true,
      'message': 'Claimed Work your first shift.',
      'rewards': {'gold': 15, 'experience': 5, 'strength': 0, 'energy': 0},
      'state': _stateJson(),
      'quest': _questJson(
        questId: 'first-work',
        actionType: 'work',
        completed: true,
        claimed: true,
        currentCount: 1,
        completedAt: '2026-05-06T12:00:00Z',
        claimedAt: '2026-05-06T12:01:00Z',
      ),
      'questline': {
        'playerId': 'player-1',
        'status': 'in_progress',
        'completedCount': 1,
        'totalCount': 2,
        'completionPercent': 50,
        'updatedAt': '2026-05-06T12:01:00Z',
        'currentQuest': _questJson(
          questId: 'first-training',
          actionType: 'train',
          completed: false,
        ),
        'quests': [
          _questJson(
            questId: 'first-work',
            actionType: 'work',
            completed: true,
            claimed: true,
            currentCount: 1,
            completedAt: '2026-05-06T12:00:00Z',
            claimedAt: '2026-05-06T12:01:00Z',
          ),
          _questJson(
            questId: 'first-training',
            actionType: 'train',
            completed: false,
          ),
        ],
      },
      'wallet': {
        'playerId': 'player-1',
        'walletGold': 115,
        'storageUsed': 0,
        'storageLimit': 100,
        'items': [],
        'updatedAt': '2026-05-06T12:01:00Z',
      },
    });

    expect(result.completed, isTrue);
    expect(result.rewards.gold, 15);
    expect(result.state?.experience, 15);
    expect(result.quest?.claimed, isTrue);
    expect(result.questline.currentQuest?.actionType, 'train');
    expect(result.wallet?.walletGold, 115);
  });
}

Map<String, dynamic> _questJson({
  required String questId,
  required String actionType,
  required bool completed,
  bool claimed = false,
  bool skipped = false,
  int currentCount = 0,
  String? completedAt,
  String? claimedAt,
  String? skippedAt,
}) {
  return {
    'questId': questId,
    'actionType': actionType,
    'title': 'Quest $questId',
    'description': 'Do $actionType.',
    'guidance': 'Follow the highlighted action.',
    'route': '/home',
    'currentCount': currentCount,
    'targetCount': 1,
    'rewards': {'gold': 15, 'experience': 5, 'strength': 0, 'energy': 0},
    'completed': completed,
    'claimed': claimed,
    'skipped': skipped,
    'completedAt': completedAt,
    'claimedAt': claimedAt,
    'skippedAt': skippedAt,
    'displayOrder': 10,
  };
}

Map<String, dynamic> _stateJson() {
  return {
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
    'updatedAt': '2026-05-06T12:01:00Z',
    'lastEnergyRegeneratedAt': '2026-05-06T12:01:00Z',
    'nextEnergyRegenAt': null,
    'energyRegenSeconds': 300,
    'energyRegenAmount': 1,
    'hospitalCooldownUntil': null,
    'hospitalEnergyRestore': 50,
    'hospitalGoldCost': 30,
  };
}

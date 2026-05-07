import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/PlayerState.dart';

class OnboardingQuestline {
  final String playerId;
  final String status;
  final OnboardingQuest? currentQuest;
  final List<OnboardingQuest> quests;
  final int completedCount;
  final int totalCount;
  final int completionPercent;
  final DateTime updatedAt;

  OnboardingQuestline({
    required this.playerId,
    required this.status,
    required this.currentQuest,
    required this.quests,
    required this.completedCount,
    required this.totalCount,
    required this.completionPercent,
    required this.updatedAt,
  });

  factory OnboardingQuestline.fromJson(Map<String, dynamic> json) {
    final quests = _requiredList(json, 'quests')
        .map((quest) => OnboardingQuest.fromJson(_requiredMap(quest)))
        .toList();
    return OnboardingQuestline(
      playerId: _requiredString(json, 'playerId'),
      status: _requiredString(json, 'status'),
      currentQuest: json['currentQuest'] == null
          ? null
          : OnboardingQuest.fromJson(_requiredMap(json['currentQuest'])),
      quests: quests,
      completedCount: _requiredInt(json, 'completedCount'),
      totalCount: _requiredInt(json, 'totalCount'),
      completionPercent: _requiredInt(json, 'completionPercent'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  bool get isCompleted => status == 'completed' || currentQuest == null;

  int get claimableCount => quests.where((quest) => quest.claimable).length;
}

class OnboardingQuest {
  final String questId;
  final String actionType;
  final String title;
  final String description;
  final String guidance;
  final String? route;
  final int currentCount;
  final int targetCount;
  final PlayerRewards rewards;
  final bool completed;
  final bool claimed;
  final bool skipped;
  final DateTime? completedAt;
  final DateTime? claimedAt;
  final DateTime? skippedAt;
  final int displayOrder;

  OnboardingQuest({
    required this.questId,
    required this.actionType,
    required this.title,
    required this.description,
    required this.guidance,
    required this.route,
    required this.currentCount,
    required this.targetCount,
    required this.rewards,
    required this.completed,
    required this.claimed,
    required this.skipped,
    required this.completedAt,
    required this.claimedAt,
    required this.skippedAt,
    required this.displayOrder,
  });

  factory OnboardingQuest.fromJson(Map<String, dynamic> json) {
    return OnboardingQuest(
      questId: _requiredString(json, 'questId'),
      actionType: _requiredString(json, 'actionType'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      guidance: _requiredString(json, 'guidance'),
      route: _optionalString(json, 'route'),
      currentCount: _requiredInt(json, 'currentCount'),
      targetCount: _requiredInt(json, 'targetCount'),
      rewards: PlayerRewards.fromJson(_requiredMap(json['rewards'])),
      completed: _requiredBool(json, 'completed'),
      claimed: _requiredBool(json, 'claimed'),
      skipped: _requiredBool(json, 'skipped'),
      completedAt: _optionalDateTime(json, 'completedAt'),
      claimedAt: _optionalDateTime(json, 'claimedAt'),
      skippedAt: _optionalDateTime(json, 'skippedAt'),
      displayOrder: _requiredInt(json, 'displayOrder'),
    );
  }

  bool get claimable => completed && !claimed && !skipped;

  double get progress {
    if (targetCount <= 0) {
      return 0;
    }
    return (currentCount / targetCount).clamp(0, 1).toDouble();
  }
}

class OnboardingQuestClaimResult {
  final bool completed;
  final String message;
  final PlayerRewards rewards;
  final PlayerState? state;
  final OnboardingQuest? quest;
  final OnboardingQuestline questline;
  final InventorySummary? wallet;

  OnboardingQuestClaimResult({
    required this.completed,
    required this.message,
    required this.rewards,
    required this.state,
    required this.quest,
    required this.questline,
    required this.wallet,
  });

  factory OnboardingQuestClaimResult.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestClaimResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      rewards: PlayerRewards.fromJson(_requiredMap(json['rewards'])),
      state: json['state'] == null
          ? null
          : PlayerState.fromJson(_requiredMap(json['state'])),
      quest: json['quest'] == null
          ? null
          : OnboardingQuest.fromJson(_requiredMap(json['quest'])),
      questline: OnboardingQuestline.fromJson(_requiredMap(json['questline'])),
      wallet: json['wallet'] == null
          ? null
          : InventorySummary.fromJson(_requiredMap(json['wallet'])),
    );
  }
}

class OnboardingQuestSkipResult {
  final bool completed;
  final String message;
  final OnboardingQuest? quest;
  final OnboardingQuestline questline;

  OnboardingQuestSkipResult({
    required this.completed,
    required this.message,
    required this.quest,
    required this.questline,
  });

  factory OnboardingQuestSkipResult.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestSkipResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      quest: json['quest'] == null
          ? null
          : OnboardingQuest.fromJson(_requiredMap(json['quest'])),
      questline: OnboardingQuestline.fromJson(_requiredMap(json['questline'])),
    );
  }
}

Map<String, dynamic> _requiredMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  throw const FormatException('Invalid onboarding object.');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List<dynamic>) {
    return value;
  }

  throw FormatException('Missing onboarding list "$field".');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing onboarding string "$field".');
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }

  throw FormatException('Invalid onboarding string "$field".');
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }

  throw FormatException('Missing onboarding integer "$field".');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing onboarding bool "$field".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Missing onboarding date "$field".');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Invalid onboarding date "$field".');
}

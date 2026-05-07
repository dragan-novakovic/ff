class AchievementsSummary {
  final String playerId;
  final List<AchievementProgress> achievements;
  final List<AchievementUnlock> recentUnlocks;
  final int totalUnlocked;
  final int totalAvailable;
  final int totalPoints;
  final int unclaimedCount;
  final DateTime updatedAt;

  AchievementsSummary({
    required this.playerId,
    required this.achievements,
    required this.recentUnlocks,
    required this.totalUnlocked,
    required this.totalAvailable,
    required this.totalPoints,
    required this.unclaimedCount,
    required this.updatedAt,
  });

  factory AchievementsSummary.fromJson(Map<String, dynamic> json) {
    final achievements = _requiredList(json, 'achievements')
        .map((achievement) =>
            AchievementProgress.fromJson(_requiredMap(achievement)))
        .toList();
    final recentUnlocks = _requiredList(json, 'recentUnlocks')
        .map((unlock) => AchievementUnlock.fromJson(_requiredMap(unlock)))
        .toList();
    return AchievementsSummary(
      playerId: _requiredString(json, 'playerId'),
      achievements: achievements,
      recentUnlocks: recentUnlocks,
      totalUnlocked: _requiredInt(json, 'totalUnlocked'),
      totalAvailable: _requiredInt(json, 'totalAvailable'),
      totalPoints: _requiredInt(json, 'totalPoints'),
      unclaimedCount: _requiredInt(json, 'unclaimedCount'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  double get progress {
    if (totalAvailable <= 0) {
      return 0;
    }

    return (totalUnlocked / totalAvailable).clamp(0, 1).toDouble();
  }

  List<String> get categories {
    final values = achievements
        .map((achievement) => achievement.category)
        .toSet()
      ..removeWhere((category) => category.trim().isEmpty);
    final sorted = values.toList()..sort();
    return sorted;
  }
}

class AchievementProgress {
  final String achievementId;
  final String actionType;
  final String title;
  final String description;
  final String category;
  final String medalName;
  final String medalRarity;
  final int points;
  final int currentCount;
  final int targetCount;
  final bool unlocked;
  final bool claimed;
  final DateTime? unlockedAt;
  final DateTime? claimedAt;
  final int displayOrder;

  AchievementProgress({
    required this.achievementId,
    required this.actionType,
    required this.title,
    required this.description,
    required this.category,
    required this.medalName,
    required this.medalRarity,
    required this.points,
    required this.currentCount,
    required this.targetCount,
    required this.unlocked,
    required this.claimed,
    required this.unlockedAt,
    required this.claimedAt,
    required this.displayOrder,
  });

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementId: _requiredString(json, 'achievementId'),
      actionType: _requiredString(json, 'actionType'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      category: _requiredString(json, 'category'),
      medalName: _requiredString(json, 'medalName'),
      medalRarity: _requiredString(json, 'medalRarity'),
      points: _requiredInt(json, 'points'),
      currentCount: _requiredInt(json, 'currentCount'),
      targetCount: _requiredInt(json, 'targetCount'),
      unlocked: _requiredBool(json, 'unlocked'),
      claimed: _requiredBool(json, 'claimed'),
      unlockedAt: _optionalDateTime(json, 'unlockedAt'),
      claimedAt: _optionalDateTime(json, 'claimedAt'),
      displayOrder: _requiredInt(json, 'displayOrder'),
    );
  }

  bool get claimable => unlocked && !claimed;

  double get progress {
    if (targetCount <= 0) {
      return unlocked ? 1 : 0;
    }

    return (currentCount / targetCount).clamp(0, 1).toDouble();
  }

  String get progressLabel {
    if (unlocked) {
      return claimed ? 'Medal claimed' : 'Medal unlocked';
    }

    return '${currentCount.clamp(0, targetCount)}/$targetCount';
  }
}

class AchievementUnlock {
  final String achievementId;
  final String title;
  final String category;
  final String medalName;
  final String medalRarity;
  final int points;
  final DateTime awardedAt;
  final bool claimed;

  AchievementUnlock({
    required this.achievementId,
    required this.title,
    required this.category,
    required this.medalName,
    required this.medalRarity,
    required this.points,
    required this.awardedAt,
    required this.claimed,
  });

  factory AchievementUnlock.fromJson(Map<String, dynamic> json) {
    return AchievementUnlock(
      achievementId: _requiredString(json, 'achievementId'),
      title: _requiredString(json, 'title'),
      category: _requiredString(json, 'category'),
      medalName: _requiredString(json, 'medalName'),
      medalRarity: _requiredString(json, 'medalRarity'),
      points: _requiredInt(json, 'points'),
      awardedAt: _requiredDateTime(json, 'awardedAt'),
      claimed: _requiredBool(json, 'claimed'),
    );
  }
}

class AchievementClaimResult {
  final bool completed;
  final String message;
  final AchievementProgress? achievement;
  final AchievementsSummary achievements;

  AchievementClaimResult({
    required this.completed,
    required this.message,
    required this.achievement,
    required this.achievements,
  });

  factory AchievementClaimResult.fromJson(Map<String, dynamic> json) {
    final achievementData = json['achievement'];
    return AchievementClaimResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      achievement: achievementData == null
          ? null
          : AchievementProgress.fromJson(_requiredMap(achievementData)),
      achievements:
          AchievementsSummary.fromJson(_requiredMap(json['achievements'])),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required achievement field "$field".');
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

  throw FormatException('Missing required integer achievement field "$field".');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing required boolean achievement field "$field".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Missing required date achievement field "$field".');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Invalid date achievement field "$field".');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List<dynamic>) {
    return value;
  }

  throw FormatException('Missing required list achievement field "$field".');
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  throw const FormatException('Missing required achievement object.');
}

class PlayerState {
  final String playerId;
  final int level;
  final int experience;
  final int experienceToNextLevel;
  final int energy;
  final int maxEnergy;
  final int strength;
  final int gold;
  final bool hasWorkedToday;
  final bool hasTrainedToday;
  final DateTime nextResetAt;
  final DateTime updatedAt;

  PlayerState({
    required this.playerId,
    required this.level,
    required this.experience,
    required this.experienceToNextLevel,
    required this.energy,
    required this.maxEnergy,
    required this.strength,
    required this.gold,
    required this.hasWorkedToday,
    required this.hasTrainedToday,
    required this.nextResetAt,
    required this.updatedAt,
  });

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      playerId: _requiredString(json, 'playerId'),
      level: _requiredInt(json, 'level'),
      experience: _requiredInt(json, 'experience'),
      experienceToNextLevel: _requiredInt(json, 'experienceToNextLevel'),
      energy: _requiredInt(json, 'energy'),
      maxEnergy: _requiredInt(json, 'maxEnergy'),
      strength: _requiredInt(json, 'strength'),
      gold: _requiredInt(json, 'gold'),
      hasWorkedToday: _requiredBool(json, 'hasWorkedToday'),
      hasTrainedToday: _requiredBool(json, 'hasTrainedToday'),
      nextResetAt: _requiredDateTime(json, 'nextResetAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  double get energyProgress {
    if (maxEnergy <= 0) {
      return 0;
    }

    return (energy / maxEnergy).clamp(0, 1).toDouble();
  }

  double get experienceProgress {
    final levelStart = (level - 1) * 100;
    final levelEnd = level * 100;
    final levelSpan = levelEnd - levelStart;
    if (levelSpan <= 0) {
      return 0;
    }

    return ((experience - levelStart) / levelSpan).clamp(0, 1).toDouble();
  }
}

class PlayerActionResult {
  final bool completed;
  final String message;
  final PlayerRewards rewards;
  final PlayerState state;

  PlayerActionResult({
    required this.completed,
    required this.message,
    required this.rewards,
    required this.state,
  });

  factory PlayerActionResult.fromJson(Map<String, dynamic> json) {
    final rewardsData = json['rewards'];
    final stateData = json['state'];
    if (rewardsData is! Map<String, dynamic>) {
      throw const FormatException('Invalid player action rewards.');
    }
    if (stateData is! Map<String, dynamic>) {
      throw const FormatException('Invalid player action state.');
    }

    return PlayerActionResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      rewards: PlayerRewards.fromJson(rewardsData),
      state: PlayerState.fromJson(stateData),
    );
  }
}

class PlayerRewards {
  final int gold;
  final int experience;
  final int strength;

  PlayerRewards({
    required this.gold,
    required this.experience,
    required this.strength,
  });

  factory PlayerRewards.fromJson(Map<String, dynamic> json) {
    return PlayerRewards(
      gold: _requiredInt(json, 'gold'),
      experience: _requiredInt(json, 'experience'),
      strength: _requiredInt(json, 'strength'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required player state field "$field".');
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

  throw FormatException(
      'Missing required integer player state field "$field".');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }

  throw FormatException(
      'Missing required boolean player state field "$field".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Missing required date player state field "$field".');
}

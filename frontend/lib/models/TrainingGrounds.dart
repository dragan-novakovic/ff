import 'PlayerState.dart';

class TrainingGroundsSummary {
  final String playerId;
  final PlayerState state;
  final bool canTrainToday;
  final bool hasTrainedToday;
  final DateTime nextResetAt;
  final int strengthReward;
  final int experienceReward;
  final List<TrainingSession> recentSessions;
  final DateTime updatedAt;

  TrainingGroundsSummary({
    required this.playerId,
    required this.state,
    required this.canTrainToday,
    required this.hasTrainedToday,
    required this.nextResetAt,
    required this.strengthReward,
    required this.experienceReward,
    required this.recentSessions,
    required this.updatedAt,
  });

  factory TrainingGroundsSummary.fromJson(Map<String, dynamic> json) {
    final stateData = json['state'];
    final sessionsData = json['recentSessions'];
    if (stateData is! Map<String, dynamic>) {
      throw const FormatException('Invalid training grounds state.');
    }
    if (sessionsData is! List) {
      throw const FormatException('Invalid training grounds sessions.');
    }

    return TrainingGroundsSummary(
      playerId: _requiredString(json, 'playerId'),
      state: PlayerState.fromJson(stateData),
      canTrainToday: _requiredBool(json, 'canTrainToday'),
      hasTrainedToday: _requiredBool(json, 'hasTrainedToday'),
      nextResetAt: _requiredDateTime(json, 'nextResetAt'),
      strengthReward: _requiredInt(json, 'strengthReward'),
      experienceReward: _requiredInt(json, 'experienceReward'),
      recentSessions: sessionsData
          .whereType<Map<String, dynamic>>()
          .map(TrainingSession.fromJson)
          .toList(growable: false),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class TrainingSession {
  final String sessionId;
  final String playerId;
  final String resetDate;
  final int strengthBefore;
  final int strengthAfter;
  final int experienceBefore;
  final int experienceAfter;
  final int levelBefore;
  final int levelAfter;
  final int strengthGained;
  final int experienceGained;
  final DateTime trainedAt;

  TrainingSession({
    required this.sessionId,
    required this.playerId,
    required this.resetDate,
    required this.strengthBefore,
    required this.strengthAfter,
    required this.experienceBefore,
    required this.experienceAfter,
    required this.levelBefore,
    required this.levelAfter,
    required this.strengthGained,
    required this.experienceGained,
    required this.trainedAt,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      sessionId: _requiredString(json, 'sessionId'),
      playerId: _requiredString(json, 'playerId'),
      resetDate: _requiredString(json, 'resetDate'),
      strengthBefore: _requiredInt(json, 'strengthBefore'),
      strengthAfter: _requiredInt(json, 'strengthAfter'),
      experienceBefore: _requiredInt(json, 'experienceBefore'),
      experienceAfter: _requiredInt(json, 'experienceAfter'),
      levelBefore: _requiredInt(json, 'levelBefore'),
      levelAfter: _requiredInt(json, 'levelAfter'),
      strengthGained: _requiredInt(json, 'strengthGained'),
      experienceGained: _requiredInt(json, 'experienceGained'),
      trainedAt: _requiredDateTime(json, 'trainedAt'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required training grounds field "$field".');
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
      'Missing required integer training grounds field "$field".');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }

  throw FormatException(
      'Missing required boolean training grounds field "$field".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String) {
    return DateTime.parse(value);
  }

  throw FormatException(
      'Missing required date training grounds field "$field".');
}

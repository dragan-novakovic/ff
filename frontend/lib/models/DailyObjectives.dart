import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/PlayerState.dart';

class DailyObjectivesSummary {
  final String playerId;
  final DateTime resetDate;
  final DateTime resetAt;
  final List<DailyObjective> objectives;
  final DateTime updatedAt;

  DailyObjectivesSummary({
    required this.playerId,
    required this.resetDate,
    required this.resetAt,
    required this.objectives,
    required this.updatedAt,
  });

  factory DailyObjectivesSummary.fromJson(Map<String, dynamic> json) {
    final objectives = _requiredList(json, 'objectives')
        .map((objective) => DailyObjective.fromJson(_requiredMap(objective)))
        .toList();
    return DailyObjectivesSummary(
      playerId: _requiredString(json, 'playerId'),
      resetDate: _requiredDateTime(json, 'resetDate'),
      resetAt: _requiredDateTime(json, 'resetAt'),
      objectives: objectives,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  int get claimableCount =>
      objectives.where((objective) => objective.claimable).length;
}

class DailyObjective {
  final String objectiveId;
  final String actionType;
  final String title;
  final String description;
  final int currentCount;
  final int targetCount;
  final PlayerRewards rewards;
  final bool completed;
  final bool claimed;
  final DateTime? completedAt;
  final DateTime? claimedAt;
  final DateTime resetDate;
  final DateTime resetAt;
  final int displayOrder;

  DailyObjective({
    required this.objectiveId,
    required this.actionType,
    required this.title,
    required this.description,
    required this.currentCount,
    required this.targetCount,
    required this.rewards,
    required this.completed,
    required this.claimed,
    required this.completedAt,
    required this.claimedAt,
    required this.resetDate,
    required this.resetAt,
    required this.displayOrder,
  });

  factory DailyObjective.fromJson(Map<String, dynamic> json) {
    return DailyObjective(
      objectiveId: _requiredString(json, 'objectiveId'),
      actionType: _requiredString(json, 'actionType'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      currentCount: _requiredInt(json, 'currentCount'),
      targetCount: _requiredInt(json, 'targetCount'),
      rewards: PlayerRewards.fromJson(_requiredMap(json['rewards'])),
      completed: _requiredBool(json, 'completed'),
      claimed: _requiredBool(json, 'claimed'),
      completedAt: _optionalDateTime(json, 'completedAt'),
      claimedAt: _optionalDateTime(json, 'claimedAt'),
      resetDate: _requiredDateTime(json, 'resetDate'),
      resetAt: _requiredDateTime(json, 'resetAt'),
      displayOrder: _requiredInt(json, 'displayOrder'),
    );
  }

  bool get claimable => completed && !claimed;

  double get progress {
    if (targetCount <= 0) {
      return 0;
    }

    return (currentCount / targetCount).clamp(0, 1).toDouble();
  }
}

class DailyObjectiveClaimResult {
  final bool completed;
  final String message;
  final PlayerRewards rewards;
  final PlayerState? state;
  final DailyObjective? objective;
  final DailyObjectivesSummary objectives;
  final InventorySummary? wallet;

  DailyObjectiveClaimResult({
    required this.completed,
    required this.message,
    required this.rewards,
    required this.state,
    required this.objective,
    required this.objectives,
    required this.wallet,
  });

  factory DailyObjectiveClaimResult.fromJson(Map<String, dynamic> json) {
    final stateData = json['state'];
    final objectiveData = json['objective'];
    final walletData = json['wallet'];
    return DailyObjectiveClaimResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      rewards: PlayerRewards.fromJson(_requiredMap(json['rewards'])),
      state: stateData == null
          ? null
          : PlayerState.fromJson(_requiredMap(stateData)),
      objective: objectiveData == null
          ? null
          : DailyObjective.fromJson(_requiredMap(objectiveData)),
      objectives:
          DailyObjectivesSummary.fromJson(_requiredMap(json['objectives'])),
      wallet: walletData == null
          ? null
          : InventorySummary.fromJson(_requiredMap(walletData)),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required daily objective field "$field".');
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
      'Missing required integer daily objective field "$field".');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }

  throw FormatException(
      'Missing required boolean daily objective field "$field".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException(
      'Missing required date daily objective field "$field".');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Invalid date daily objective field "$field".');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List<dynamic>) {
    return value;
  }

  throw FormatException(
      'Missing required list daily objective field "$field".');
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  throw const FormatException('Missing required daily objective object.');
}

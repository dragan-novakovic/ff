class ActivityFeedSummary {
  final String playerId;
  final List<ActivityEvent> events;
  final int unreadCount;
  final DateTime updatedAt;

  ActivityFeedSummary({
    required this.playerId,
    required this.events,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ActivityFeedSummary.fromJson(Map<String, dynamic> json) {
    final events = _requiredList(json, 'events')
        .map((event) => ActivityEvent.fromJson(_requiredMap(event)))
        .toList();
    return ActivityFeedSummary(
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      events: events,
      unreadCount:
          _requiredInt(json, 'unreadCount', fallbackField: 'unread_count'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }

  ActivityFeedSummary copyWith({
    List<ActivityEvent>? events,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return ActivityFeedSummary(
      playerId: playerId,
      events: events ?? this.events,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ActivityEvent {
  final String eventId;
  final String playerId;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId;

  ActivityEvent({
    required this.eventId,
    required this.playerId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    required this.relatedId,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      eventId: _requiredString(json, 'eventId', fallbackField: 'event_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      type: _requiredString(json, 'type', fallbackField: 'eventType'),
      message: _requiredString(json, 'message'),
      isRead: _requiredBool(json, 'isRead', fallbackField: 'is_read'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      relatedId: _optionalNullableString(json, 'relatedId') ??
          _optionalNullableString(json, 'related_id'),
    );
  }

  ActivityEvent copyWith({bool? isRead}) {
    return ActivityEvent(
      eventId: eventId,
      playerId: playerId,
      type: type,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      relatedId: relatedId,
    );
  }
}

class ActivityReadResult {
  final bool completed;
  final String message;
  final ActivityEvent event;
  final int unreadCount;
  final DateTime updatedAt;

  ActivityReadResult({
    required this.completed,
    required this.message,
    required this.event,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ActivityReadResult.fromJson(Map<String, dynamic> json) {
    return ActivityReadResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      event: ActivityEvent.fromJson(_requiredMap(json['event'])),
      unreadCount:
          _requiredInt(json, 'unreadCount', fallbackField: 'unread_count'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class ActivityReadAllResult {
  final bool completed;
  final String message;
  final int markedReadCount;
  final int unreadCount;
  final DateTime updatedAt;

  ActivityReadAllResult({
    required this.completed,
    required this.message,
    required this.markedReadCount,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ActivityReadAllResult.fromJson(Map<String, dynamic> json) {
    return ActivityReadAllResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      markedReadCount: _requiredInt(json, 'markedReadCount',
          fallbackField: 'marked_read_count'),
      unreadCount:
          _requiredInt(json, 'unreadCount', fallbackField: 'unread_count'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

String _requiredString(
  Map<String, dynamic> json,
  String field, {
  String? fallbackField,
}) {
  final value =
      json[field] ?? (fallbackField == null ? null : json[fallbackField]);
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required activity field "$field".');
}

int _requiredInt(
  Map<String, dynamic> json,
  String field, {
  String? fallbackField,
}) {
  final value =
      json[field] ?? (fallbackField == null ? null : json[fallbackField]);
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

  throw FormatException('Missing required integer activity field "$field".');
}

bool _requiredBool(
  Map<String, dynamic> json,
  String field, {
  String? fallbackField,
}) {
  final value =
      json[field] ?? (fallbackField == null ? null : json[fallbackField]);
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing required boolean activity field "$field".');
}

DateTime _requiredDateTime(
  Map<String, dynamic> json,
  String field, {
  String? fallbackField,
}) {
  final value =
      json[field] ?? (fallbackField == null ? null : json[fallbackField]);
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Missing required date activity field "$field".');
}

String? _optionalNullableString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  return null;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List<dynamic>) {
    return value;
  }

  throw FormatException('Missing required list activity field "$field".');
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  throw const FormatException('Missing required object activity field.');
}

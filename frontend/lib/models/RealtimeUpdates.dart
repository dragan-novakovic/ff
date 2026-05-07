import 'ActivityFeed.dart';
import 'GameAreas.dart';
import 'MessageModel.dart';

class RealtimeUpdatesEnvelope {
  final String playerId;
  final DateTime? since;
  final DateTime generatedAt;
  final DateTime nextCursor;
  final int pollAfterSeconds;
  final bool hasChanges;
  final List<String> changedSections;
  final RealtimeActivityUpdate? activity;
  final RealtimeChatUpdate? chat;
  final RealtimeProductionUpdate? production;
  final RealtimeBattleUpdate? battles;
  final RealtimeMarketUpdate? market;
  final List<RealtimeUpdateError> errors;

  RealtimeUpdatesEnvelope({
    required this.playerId,
    required this.since,
    required this.generatedAt,
    required this.nextCursor,
    required this.pollAfterSeconds,
    required this.hasChanges,
    required this.changedSections,
    required this.activity,
    required this.chat,
    required this.production,
    required this.battles,
    required this.market,
    required this.errors,
  });

  bool get hasAnySection =>
      activity != null ||
      chat != null ||
      production != null ||
      battles != null ||
      market != null;

  factory RealtimeUpdatesEnvelope.fromJson(Map<String, dynamic> json) {
    return RealtimeUpdatesEnvelope(
      playerId: _requiredString(json, 'playerId'),
      since: _optionalDateTime(json, 'since'),
      generatedAt: _requiredDateTime(json, 'generatedAt'),
      nextCursor: _requiredDateTime(json, 'nextCursor'),
      pollAfterSeconds: _optionalInt(json, 'pollAfterSeconds', defaultValue: 8),
      hasChanges: _optionalBool(json, 'hasChanges'),
      changedSections: _optionalList(json, 'changedSections')
          .map((section) => section.toString())
          .toList(),
      activity: _optionalMap(json, 'activity') == null
          ? null
          : RealtimeActivityUpdate.fromJson(_optionalMap(json, 'activity')!),
      chat: _optionalMap(json, 'chat') == null
          ? null
          : RealtimeChatUpdate.fromJson(_optionalMap(json, 'chat')!),
      production: _optionalMap(json, 'production') == null
          ? null
          : RealtimeProductionUpdate.fromJson(
              _optionalMap(json, 'production')!),
      battles: _optionalMap(json, 'battles') == null
          ? null
          : RealtimeBattleUpdate.fromJson(_optionalMap(json, 'battles')!),
      market: _optionalMap(json, 'market') == null
          ? null
          : RealtimeMarketUpdate.fromJson(_optionalMap(json, 'market')!),
      errors: _optionalList(json, 'errors')
          .map((error) => RealtimeUpdateError.fromJson(_requiredMap(error)))
          .toList(),
    );
  }
}

class RealtimeActivityUpdate {
  final bool hasChanges;
  final ActivityFeedSummary feed;

  RealtimeActivityUpdate({
    required this.hasChanges,
    required this.feed,
  });

  factory RealtimeActivityUpdate.fromJson(Map<String, dynamic> json) {
    return RealtimeActivityUpdate(
      hasChanges: _optionalBool(json, 'hasChanges'),
      feed: ActivityFeedSummary.fromJson(json),
    );
  }
}

class RealtimeChatUpdate {
  final bool hasChanges;
  final String toId;
  final List<Message> messages;
  final DateTime updatedAt;

  RealtimeChatUpdate({
    required this.hasChanges,
    required this.toId,
    required this.messages,
    required this.updatedAt,
  });

  factory RealtimeChatUpdate.fromJson(Map<String, dynamic> json) {
    return RealtimeChatUpdate(
      hasChanges: _optionalBool(json, 'hasChanges'),
      toId: _requiredString(json, 'toId'),
      messages: _optionalList(json, 'messages')
          .map((message) => Message.fromJson(_requiredMap(message)))
          .toList(),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class RealtimeProductionUpdate {
  final bool hasChanges;
  final ProductionJobsResponse jobs;
  final List<ProductionJob> completedJobs;

  RealtimeProductionUpdate({
    required this.hasChanges,
    required this.jobs,
    required this.completedJobs,
  });

  bool get hasCompletedJobs => completedJobs.isNotEmpty;

  factory RealtimeProductionUpdate.fromJson(Map<String, dynamic> json) {
    return RealtimeProductionUpdate(
      hasChanges: _optionalBool(json, 'hasChanges'),
      jobs: ProductionJobsResponse.fromJson(json),
      completedJobs: _optionalList(json, 'completedJobs')
          .map((job) => ProductionJob.fromJson(_requiredMap(job)))
          .toList(),
    );
  }
}

class RealtimeBattleUpdate {
  final bool hasChanges;
  final CountryBattleList battles;

  RealtimeBattleUpdate({
    required this.hasChanges,
    required this.battles,
  });

  factory RealtimeBattleUpdate.fromJson(Map<String, dynamic> json) {
    return RealtimeBattleUpdate(
      hasChanges: _optionalBool(json, 'hasChanges'),
      battles: CountryBattleList.fromJson(json),
    );
  }
}

class RealtimeMarketUpdate {
  final bool hasChanges;
  final MarketListings listings;
  final PlayerMarketListings? playerListings;

  RealtimeMarketUpdate({
    required this.hasChanges,
    required this.listings,
    required this.playerListings,
  });

  factory RealtimeMarketUpdate.fromJson(Map<String, dynamic> json) {
    final playerListingsJson = _optionalMap(json, 'playerListings');
    return RealtimeMarketUpdate(
      hasChanges: _optionalBool(json, 'hasChanges'),
      listings: MarketListings.fromJson(json),
      playerListings: playerListingsJson == null
          ? null
          : PlayerMarketListings.fromJson(playerListingsJson),
    );
  }
}

class RealtimeUpdateError {
  final String section;
  final String message;

  RealtimeUpdateError({
    required this.section,
    required this.message,
  });

  factory RealtimeUpdateError.fromJson(Map<String, dynamic> json) {
    return RealtimeUpdateError(
      section: _requiredString(json, 'section'),
      message: _requiredString(json, 'message'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required realtime field "$field".');
}

int _optionalInt(
  Map<String, dynamic> json,
  String field, {
  int defaultValue = 0,
}) {
  final value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? defaultValue;
  }

  return defaultValue;
}

bool _optionalBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value is bool ? value : false;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('Missing required realtime date field "$field".');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  return null;
}

List<dynamic> _optionalList(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value is List<dynamic> ? value : const <dynamic>[];
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value is Map<String, dynamic> ? value : null;
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  throw const FormatException('Missing required realtime object field.');
}

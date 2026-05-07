class PushNotificationSettings {
  final String playerId;
  final bool isConfigured;
  final String? vapidPublicKey;
  final List<PushSubscriptionInfo> subscriptions;
  final DateTime updatedAt;

  PushNotificationSettings({
    required this.playerId,
    required this.isConfigured,
    required this.vapidPublicKey,
    required this.subscriptions,
    required this.updatedAt,
  });

  bool get hasEnabledSubscription =>
      subscriptions.any((subscription) => subscription.isEnabled);

  PushSubscriptionInfo? get latestEnabledSubscription {
    final enabled =
        subscriptions.where((subscription) => subscription.isEnabled);
    return enabled.isEmpty ? null : enabled.first;
  }

  factory PushNotificationSettings.fromJson(Map<String, dynamic> json) {
    return PushNotificationSettings(
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      isConfigured:
          _requiredBool(json, 'isConfigured', fallbackField: 'is_configured'),
      vapidPublicKey: _optionalString(json, 'vapidPublicKey') ??
          _optionalString(json, 'vapid_public_key'),
      subscriptions: _requiredList(json, 'subscriptions')
          .map((entry) => PushSubscriptionInfo.fromJson(_requiredMap(entry)))
          .toList(),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class PushSubscriptionInfo {
  final String subscriptionId;
  final String playerId;
  final String endpoint;
  final String? userAgent;
  final bool isEnabled;
  final int failureCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? disabledAt;

  PushSubscriptionInfo({
    required this.subscriptionId,
    required this.playerId,
    required this.endpoint,
    required this.userAgent,
    required this.isEnabled,
    required this.failureCount,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
    required this.disabledAt,
  });

  factory PushSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return PushSubscriptionInfo(
      subscriptionId: _requiredString(json, 'subscriptionId',
          fallbackField: 'subscription_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      endpoint: _requiredString(json, 'endpoint'),
      userAgent: _optionalString(json, 'userAgent') ??
          _optionalString(json, 'user_agent'),
      isEnabled: _requiredBool(json, 'isEnabled', fallbackField: 'is_enabled'),
      failureCount:
          _requiredInt(json, 'failureCount', fallbackField: 'failure_count'),
      lastError: _optionalString(json, 'lastError') ??
          _optionalString(json, 'last_error'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
      disabledAt: _optionalDateTime(json, 'disabledAt') ??
          _optionalDateTime(json, 'disabled_at'),
    );
  }
}

class PushSubscriptionMutationResult {
  final bool completed;
  final String message;
  final bool isConfigured;
  final PushSubscriptionInfo subscription;
  final DateTime updatedAt;

  PushSubscriptionMutationResult({
    required this.completed,
    required this.message,
    required this.isConfigured,
    required this.subscription,
    required this.updatedAt,
  });

  factory PushSubscriptionMutationResult.fromJson(Map<String, dynamic> json) {
    return PushSubscriptionMutationResult(
      completed: _requiredBool(json, 'completed'),
      message: _requiredString(json, 'message'),
      isConfigured:
          _requiredBool(json, 'isConfigured', fallbackField: 'is_configured'),
      subscription:
          PushSubscriptionInfo.fromJson(_requiredMap(json['subscription'])),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class PushDeliveryList {
  final String playerId;
  final List<PushDelivery> deliveries;
  final DateTime updatedAt;

  PushDeliveryList({
    required this.playerId,
    required this.deliveries,
    required this.updatedAt,
  });

  factory PushDeliveryList.fromJson(Map<String, dynamic> json) {
    return PushDeliveryList(
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      deliveries: _requiredList(json, 'deliveries')
          .map((entry) => PushDelivery.fromJson(_requiredMap(entry)))
          .toList(),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
    );
  }
}

class PushDelivery {
  final String deliveryId;
  final String eventId;
  final String playerId;
  final String subscriptionId;
  final String title;
  final String body;
  final String? relatedId;
  final String url;
  final String tag;
  final String status;
  final int attempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;
  final String? lastError;

  PushDelivery({
    required this.deliveryId,
    required this.eventId,
    required this.playerId,
    required this.subscriptionId,
    required this.title,
    required this.body,
    required this.relatedId,
    required this.url,
    required this.tag,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    required this.deliveredAt,
    required this.lastError,
  });

  factory PushDelivery.fromJson(Map<String, dynamic> json) {
    return PushDelivery(
      deliveryId:
          _requiredString(json, 'deliveryId', fallbackField: 'delivery_id'),
      eventId: _requiredString(json, 'eventId', fallbackField: 'event_id'),
      playerId: _requiredString(json, 'playerId', fallbackField: 'player_id'),
      subscriptionId: _requiredString(json, 'subscriptionId',
          fallbackField: 'subscription_id'),
      title: _requiredString(json, 'title'),
      body: _requiredString(json, 'body'),
      relatedId: _optionalString(json, 'relatedId') ??
          _optionalString(json, 'related_id'),
      url: _requiredString(json, 'url'),
      tag: _requiredString(json, 'tag'),
      status: _requiredString(json, 'status'),
      attempts: _requiredInt(json, 'attempts'),
      createdAt:
          _requiredDateTime(json, 'createdAt', fallbackField: 'created_at'),
      updatedAt:
          _requiredDateTime(json, 'updatedAt', fallbackField: 'updated_at'),
      deliveredAt: _optionalDateTime(json, 'deliveredAt') ??
          _optionalDateTime(json, 'delivered_at'),
      lastError: _optionalString(json, 'lastError') ??
          _optionalString(json, 'last_error'),
    );
  }
}

class BrowserPushSubscription {
  final bool supported;
  final bool subscribed;
  final String permission;
  final String? endpoint;
  final String? p256dh;
  final String? auth;
  final String? userAgent;
  final String? message;

  BrowserPushSubscription({
    required this.supported,
    required this.subscribed,
    required this.permission,
    this.endpoint,
    this.p256dh,
    this.auth,
    this.userAgent,
    this.message,
  });

  bool get canPersist =>
      supported &&
      subscribed &&
      endpoint != null &&
      p256dh != null &&
      auth != null;

  factory BrowserPushSubscription.unsupported(String message) {
    return BrowserPushSubscription(
      supported: false,
      subscribed: false,
      permission: 'unsupported',
      message: message,
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
  throw FormatException('Missing required push notification field "$field".');
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value is String && value.isNotEmpty ? value : null;
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
  throw FormatException('Missing required boolean push field "$field".');
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
  throw FormatException('Missing required integer push field "$field".');
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
  throw FormatException('Missing required date push field "$field".');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return null;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List<dynamic>) {
    return value;
  }
  throw FormatException('Missing required list push field "$field".');
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw const FormatException('Missing required object push field.');
}

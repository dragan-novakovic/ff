import 'User.dart';

class AccountSecurityProfile {
  final User user;
  final List<AccountSession> sessions;

  AccountSecurityProfile({required this.user, required this.sessions});

  AccountSecurityProfile.fromJson(Map<String, dynamic> json)
      : user = User.fromJson(_requiredMap(json, 'user')),
        sessions = _sessions(json['sessions']);
}

class AccountSession {
  final String sessionId;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;

  AccountSession({
    required this.sessionId,
    required this.createdAt,
    required this.expiresAt,
    required this.lastSeenAt,
    required this.revokedAt,
  });

  AccountSession.fromJson(Map<String, dynamic> json)
      : sessionId = _requiredString(json, 'sessionId'),
        createdAt = _date(json['created_at'] ?? json['createdAt']),
        expiresAt = _date(json['expires_at'] ?? json['expiresAt']),
        lastSeenAt = _date(json['last_seen_at'] ?? json['lastSeenAt']),
        revokedAt = _date(json['revoked_at'] ?? json['revokedAt']);

  bool get isActive =>
      revokedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now().toUtc()));
}

class AuthActionResult {
  final String message;
  final String? devToken;
  final DateTime? expiresAt;

  AuthActionResult({
    required this.message,
    this.devToken,
    this.expiresAt,
  });

  AuthActionResult.fromJson(Map<String, dynamic> json)
      : message = (json['message'] ?? 'Request completed.').toString(),
        devToken = (json['dev_token'] ?? json['devToken'])?.toString(),
        expiresAt = _date(json['expires_at'] ?? json['expiresAt']);
}

class SessionRevokeResult {
  final String message;
  final int revokedSessions;

  SessionRevokeResult({
    required this.message,
    required this.revokedSessions,
  });

  SessionRevokeResult.fromJson(Map<String, dynamic> json)
      : message = (json['message'] ?? 'Sessions revoked.').toString(),
        revokedSessions = _int(json['revokedSessions']);
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('Missing required field "$field".');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Missing required field "$field".');
}

List<AccountSession> _sessions(Object? value) {
  if (value is! List<dynamic>) {
    return [];
  }

  return value
      .whereType<Map<String, dynamic>>()
      .map(AccountSession.fromJson)
      .toList();
}

DateTime? _date(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value.toString())?.toUtc();
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class Message {
  final String id;
  final String fromId;
  final String toId;
  final String content;
  final DateTime? createdAt;

  Message(this.content, this.fromId, this.toId, {this.id = '', this.createdAt});

  Message.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        content = _requiredString(json, 'content'),
        toId = _requiredString(json, 'toId', fallbackField: 'to_id'),
        fromId = _requiredString(json, 'fromId', fallbackField: 'from_id'),
        createdAt = _optionalDateTime(json, 'createdAt') ??
            _optionalDateTime(json, 'created_at');

  static Map<String, Object?> toJson(Message msg) {
    return {
      'id': msg.id,
      'content': msg.content,
      'toId': msg.toId,
      'fromId': msg.fromId,
      if (msg.createdAt != null)
        'createdAt': msg.createdAt!.toUtc().toIso8601String(),
    };
  }

  @override
  String toString() {
    return '''MESSAGE {
      fromId:  ${this.fromId}
      toId:    ${this.toId}
      content: ${this.content}
      }''';
  }
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  return null;
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

  throw FormatException('Missing required message field "$field".');
}

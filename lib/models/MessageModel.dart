class Message {
  final String fromId;
  final String toId;
  final String content;

  Message(this.content, this.fromId, this.toId);

  Message.fromJson(Map<String, dynamic> json)
      : content = json['content'],
        toId = json['toId'],
        fromId = json['fromId'];

  static Map<String, Object?> toJson(Message msg) {
    return {'content': msg.content, 'toId': msg.toId, 'fromId': msg.fromId};
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

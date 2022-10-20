class Message {
  final String fromId;
  final String toId;
  final String content;

  Message(this.content, this.fromId, this.toId);

  Message.fromJson(Map<String, dynamic> json) : content = json['content'];

  @override
  String toString() {
    return '''MESSAGE {
      content: ${this.content}
      }''';
  }
}

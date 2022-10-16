class Message {
  final String content;

  Message(this.content);

  Message.fromJson(Map<String, dynamic> json) : content = json['content'];

  @override
  String toString() {
    return '''MESSAGE {
      content: ${this.content}
      }''';
  }
}

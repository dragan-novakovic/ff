import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:rxdart/rxdart.dart';

class MessageBloc extends Object {
  final _messagesCollection = FirebaseFirestore.instance.collection('messages');
  final _messagesController = BehaviorSubject<List<Message>>();

  Stream<List<Message>> get messages => _messagesController.stream;

  Future<List<Message>> fetchMessages() async {
    print("FIREBASE CONNECTION ISSUES");
    var messagesSnapshot = await _messagesCollection.get();

    List<Message> messages = messagesSnapshot.docs.map((doc) {
      return Message(doc["content"], doc["fromId"], doc["toId"]);
    }).toList();

    print(messages.length);
    if (messages.length > 0) {
      _messagesController.add(messages);
      return messages;
    } else {
      return [Message("test", '222', '11')];
    }
  }

  Future<void> sendMessage(Message msg) async {
    await _messagesCollection.add(Message.toJson(msg));
  }
}

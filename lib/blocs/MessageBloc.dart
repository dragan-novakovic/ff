import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:rxdart/rxdart.dart';

class MessageBloc extends Object {
  final _messagesCollection = FirebaseFirestore.instance.collection('messages');
  final _messagesController = BehaviorSubject<List<Message>>();
  final _meessageController = BehaviorSubject<String>();

  Stream<List<Message>> get messages => _messagesController.stream;
  Stream<String> get message => _meessageController.stream;

  Function(String) get changeMessage => _meessageController.sink.add;

  Future<List<Message>> fetchMessages() async {
    var messagesSnapshot = await _messagesCollection.get();

    List<Message> messages = messagesSnapshot.docs.map((doc) {
      return Message(doc["content"], doc["fromId"], doc["toId"]);
    }).toList();

    print("Inside block" + messages.length.toString());
    if (messages.length > 0) {
      _messagesController.add(messages);
      return messages;
    } else {
      return [Message("test", '222', '11')];
    }
  }

  void sendMessage(String msg) async {
    print("1 :" + msg);

    await _messagesCollection
        .add(Message.toJson(Message(msg, "fromId", "toId")));
  }
}

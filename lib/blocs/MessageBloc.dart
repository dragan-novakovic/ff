import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

class MessageBloc extends Object {
  final _messagesCollection = FirebaseFirestore.instance.collection('messages');
  final _usernameController = BehaviorSubject<String>();

  Stream<String> get username => _usernameController.stream;

  Future<List<Message>> fetchMessages() async {
    var messagesSnapshot = await _messagesCollection.get();

    List<Message> messages = messagesSnapshot.docs.map((doc) {
      return Message(doc["content"], doc["fromId"], doc["toId"]);
    }).toList();

    if (messages.length > 0) {
      return messages;
    } else {
      return [Message("test", '222', '11')];
    }
  }

  Future<void> sendMessage(Message msg) async {
    await _messagesCollection.add(Message.toJson(msg));
  }
}

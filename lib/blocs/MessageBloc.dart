import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class MessageBloc extends Object with ChangeNotifier {
  final _messagesCollection = FirebaseFirestore.instance.collection('messages');
  final _messagesController = BehaviorSubject<List<Message>>();
  final _meessageController = BehaviorSubject<String>();

  Stream<List<Message>> get messages => _messagesController.stream;
  Stream<String> get message => _meessageController.stream;

  Function(String) get changeMessage => _meessageController.sink.add;

  // fetch all group messages, chat messages for user id,
  // sperate entry contacts -> all Ids
  Future<void> fetchMessages({String? fromId, String? toId}) async {
    var messagesSnapshot = null;

    if (fromId != null && toId != null) {
      messagesSnapshot = await _messagesCollection
          .where('fromId', isEqualTo: fromId)
          .where('toId', isEqualTo: toId)
          .where('fromId', isEqualTo: toId)
          .where('toId', isEqualTo: fromId)
          .get();
    } else {
      messagesSnapshot = await _messagesCollection.get();
    }

    List<Message> messages = messagesSnapshot.docs.map((doc) {
      return Message(doc["content"], doc["fromId"], doc["toId"]);
    }).toList();

    print("Inside block" + messages.length.toString());
    if (messages.length > 0) {
      _messagesController.add(messages);
    }
  }

  Future<void> sendMessage(String msg) async {
    print("1 :" + msg);

    await _messagesCollection
        .add(Message.toJson(Message(msg, "fromId", "toId")));
    await this.fetchMessages();
  }
}

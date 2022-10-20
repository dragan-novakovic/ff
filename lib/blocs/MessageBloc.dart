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
    return [Message("test")];
  }

  Future<void> sendMessage() async {}
}

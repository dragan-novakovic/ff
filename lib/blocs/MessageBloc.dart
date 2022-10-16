import 'dart:async';
import 'package:ff/models/MessageModel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

class MessageBloc extends Object {
  final _firebaseAuth = FirebaseAuth.instance;
  final _emailController = BehaviorSubject<String>();
  final _usernameController = BehaviorSubject<String>();

  Stream<dynamic> get authStateChange => _firebaseAuth.authStateChanges();
  Stream<String> get username => _usernameController.stream;

  // change data
  Function(String) get changeEmail => _emailController.sink.add;

  Future<List<Message>> fetchMessages() async {
    return [Message("test")];
  }

  Future<void> sendMessage() async {}
}

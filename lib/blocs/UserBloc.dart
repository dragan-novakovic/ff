import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as FB;
import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';
import '../models/User.dart';

class UserBloc extends Object with ChangeNotifier {
  final _firebaseAuth = FB.FirebaseAuth.instance;
  final _usersCollection = FirebaseFirestore.instance.collection('users');
  final _userController = BehaviorSubject<User>();
  final _emailController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();
  final _usernameController = BehaviorSubject<String>();

  Stream<dynamic> get authStateChange => _firebaseAuth.authStateChanges();
  Stream<User> get userData => _userController.stream;
  Stream<String> get username => _usernameController.stream;

  // change data
  Function(String) get changeEmail => _emailController.sink.add;
  Function(String) get changePassword => _passwordController.sink.add;
  Function(String) get changeUsername => _usernameController.sink.add;
  Function(User) get addUser => _userController.sink.add;

  String? getCurrentUserId() {
    return _firebaseAuth.currentUser?.uid;
  }

  Future<void> createUserProfile(FB.UserCredential userProfile) async {
    if (userProfile.user == null) {
      throw "User is not registered";
    }

    String uid = userProfile.user!.uid;
    String email = userProfile.user?.email ?? "not set";
    String created_on = DateTime.now().toString();

    User user = User(uid, email, "", created_on);
    user.groups = [];
    user.contacts = [];
    user.first_name = "";
    user.last_name = "";

    await _usersCollection.add(User.toJson(user));
    _userController.add(user);
  }

  Future<void> fetchChatUserProfile(String uid) async {
    QuerySnapshot snapshot =
        await _usersCollection.where('uid', isEqualTo: uid).get();

    if (snapshot.docs.length > 0) {
      Map<String, dynamic> userData =
          snapshot.docs[0].data() as Map<String, dynamic>;

      User user =
          User(userData['uid'], userData['email'], userData['username'], "");

      user.contacts = (userData['contacts'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      user.groups = (userData['groups'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      user.first_name = userData['first_name'];
      user.last_name = userData['last_name'];
      _userController.sink.add(user);
    } else {
      throw 'No User Profile';
    }
  }

  Future<void> fetchUserProfile(String uid) async {
    QuerySnapshot snapshot =
        await _usersCollection.where('uid', isEqualTo: uid).get();

    if (snapshot.docs.length > 0) {
      Map<String, dynamic> userData =
          snapshot.docs[0].data() as Map<String, dynamic>;

      User user =
          User(userData['uid'], userData['email'], userData['username'], "");

      user.contacts = (userData['contacts'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      user.groups = (userData['groups'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      user.first_name = userData['first_name'];
      user.last_name = userData['last_name'];
      _userController.sink.add(user);
    } else {
      throw 'No User Profile';
    }
  }

  Future<void> submit() async {
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;

    print('Email is $validEmail, and password is $validPassword');
    try {
      FB.UserCredential credentials = await FB.FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: validEmail, password: validPassword);

      fetchUserProfile(credentials.user!.uid);
    } on FB.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
      print(e.toString());
    }
  }

  Future<String> register() async {
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;

    try {
      FB.UserCredential credentials =
          await FB.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: validEmail,
        password: validPassword,
      );
      createUserProfile(credentials);
      return "OK";
    } on FB.FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return ('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        return ('The account already exists for that email.');
      }
    } catch (e) {
      print(e);
      throw (e);
    } finally {
      print("Register tried");
      return "Zasto?";
    }
  }
}

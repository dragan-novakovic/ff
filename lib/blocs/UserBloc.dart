import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff/models/Inventory.dart';
import 'package:firebase_auth/firebase_auth.dart' as FB;
import 'package:rxdart/rxdart.dart';
import '../models/User.dart';

class Validators {
  final validateEmail =
      StreamTransformer<String, String>.fromHandlers(handleData: (email, sink) {
    if (email.contains('@')) {
      sink.add(email);
    } else {
      sink.addError('Enter a valid email');
    }
  });

  final validatePassword = StreamTransformer<String, String>.fromHandlers(
      handleData: (password, sink) {
    if (password.length > 4) {
      sink.add(password);
    } else {
      sink.addError('Invalid password, please enter more than 4 characters');
    }
  });
}

class LoginBloc extends Object with Validators {
  final _firebaseAuth = FB.FirebaseAuth.instance;
  final _usersCollection = FirebaseFirestore.instance.collection('users');
  final _userController = BehaviorSubject<User>();
  final _emailController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();
  final _usernameController = BehaviorSubject<String>();
  final _inventory = BehaviorSubject<UserInventory>();

  BehaviorSubject<UserInventory> get inventory => _inventory;
  Stream<dynamic> get authStateChange => _firebaseAuth.authStateChanges();
  Stream<User> get userData => _userController.stream;
  Stream<String> get email => _emailController.stream.transform(validateEmail);
  Stream<String> get password =>
      _passwordController.stream.transform(validatePassword);
  Stream<String> get username => _usernameController.stream;
  Stream<bool> get submitValid =>
      Rx.combineLatest2(email, password, (e, p) => true);
  Stream<bool> get submitValidRegister =>
      Rx.combineLatest3(email, password, username, (e, p, u) => true);

  // change data
  Function(String) get changeEmail => _emailController.sink.add;
  Function(String) get changePassword => _passwordController.sink.add;
  Function(String) get changeUsername => _usernameController.sink.add;

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

  Future<void> submit() async {
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;

    print('Email is $validEmail, and password is $validPassword');
    try {
      FB.UserCredential credentials = await FB.FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: validEmail, password: validPassword);

      if (credentials.user!.uid.isNotEmpty) {
        QuerySnapshot snapshot = await _usersCollection
            .where('uid', isEqualTo: credentials.user!.uid)
            .get();

        User user = User('123', 'e123', 'u123', 'sad');
        _userController.sink.add(user);
        print(await _userController.stream.length);
        if (snapshot.docs.length > 0) {
          // print("I am in");
          // Map<String, dynamic> userData =
          //     snapshot.docs[0].data() as Map<String, dynamic>;
          // print(userData);

          // User user = User(
          //     userData['uid'], userData['email'], userData['username'], "");

          // print(user);
          // user.contacts = userData['contacts'];
          // user.groups = userData['groups'];
          // print("3");
          // user.first_name = userData['first_name'];
          // print("4");
          // user.last_name = userData['last_name'];
          // print("2");

        } else {
          throw 'No User Profile';
        }
      }
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

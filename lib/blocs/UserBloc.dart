import 'dart:async';
import 'package:ff/models/Inventory.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localstorage/localstorage.dart';
//import 'package:ff/models/User.dart';
import 'package:rxdart/rxdart.dart';

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
  final _firebaseAuth = FirebaseAuth.instance;
  final _emailController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();
  final _usernameController = BehaviorSubject<String>();
  final _inventory = BehaviorSubject<UserInventory>();

  BehaviorSubject<UserInventory> get inventory => _inventory;
  Stream<dynamic> get authStateChange => _firebaseAuth.authStateChanges();
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

  Future<void> submit() async {
    print('GGGG');
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;
    final LocalStorage storage = new LocalStorage('local_storage');
    print('Email is $validEmail, and password is $validPassword');
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: validEmail!, password: validPassword!);

      print(credential.toString());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
    }
  }

  Future<String> register() async {
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;
    // final validUsername = _usernameController.value;

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: validEmail!,
        password: validPassword!,
      );

      return "OK";
    } on FirebaseAuthException catch (e) {
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

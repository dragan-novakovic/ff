import 'dart:async';
import 'package:ff/models/Inventory.dart';
import 'package:localstorage/localstorage.dart';
import 'package:ff/models/User.dart';
import 'package:ff/services/api.dart';
import 'package:rxdart/rxdart.dart';

class LoginBloc extends Object with Validators {
  final api = ApiProvider();
  final _emailController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();
  final _usernameController = BehaviorSubject<String>();
  final _inventory = BehaviorSubject<UserInventory>();

  BehaviorSubject<UserInventory> get inventory => _inventory;
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

  Future<User?> submit() async {
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;
    final LocalStorage storage = new LocalStorage('local_storage');
    // print('Email is $validEmail, and password is $validPassword');
    try {
      dynamic json = await api.post("/login",
          data: {"email": validEmail, "password": validPassword});

      storage.setItem('profile', json);
      User result = User.fromJson(json);
      return result;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<void> register() async {
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;
    final validUsername = _usernameController.value;

    try {
      await api.post("/user", data: {
        "email": validEmail,
        "username": validUsername,
        "password": validPassword
      });
    } catch (e) {
      // Propagate Error
      print('Error: $e');
      return null;
    }
  }

  Future<void> getInventory(String userInventoryId) async {
    try {
      dynamic json = await api.post("/storage", data: {
        "inventory_id": userInventoryId,
      });

      UserInventory userInventory = UserInventory.fromJson(json);
      //  print(userInventory);
      _inventory.add(userInventory);
      // return userInventory;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  void dispose() {
    _emailController.close();
    _passwordController.close();
    _usernameController.close();
    //_inventory.close();
  }
}

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

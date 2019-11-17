import 'dart:async';

import 'package:ff/models/User.dart';
import 'package:ff/services/api.dart';
import 'package:rxdart/rxdart.dart';

class LoginBloc extends Object with Validators {
  final _emailController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();

  Observable<String> get email =>
      _emailController.stream.transform(validateEmail);
  Observable<String> get password =>
      _passwordController.stream.transform(validatePassword);
  Observable<bool> get submitValid =>
      Observable.combineLatest2(email, password, (e, p) => true);

  // change data
  Function(String) get changeEmail => _emailController.sink.add;
  Function(String) get changePassword => _passwordController.sink.add;

  Future<User> submit() async {
    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;

    print('Email is $validEmail, and password is $validPassword');
    final api = ApiProvider();
    try {
      User data = await api.post("/login",
          data: {"email": validEmail, "password": validPassword});

      return data;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  void dispose() {
    _emailController.close();
    _passwordController.close();
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

import 'dart:async';
import 'package:localstorage/localstorage.dart';
import 'package:ff/models/User.dart';
import 'package:ff/services/api.dart';
import 'package:rxdart/rxdart.dart';

class LoginBloc extends Object with Validators {
  final api = ApiProvider();
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
    final LocalStorage storage = new LocalStorage('local_storage');

    // print('Email is $validEmail, and password is $validPassword');
    try {
      dynamic json = await api.post("/login",
          data: {"email": validEmail, "password": validPassword});

      storage.setItem('profile', json);

      User result = User.fromJson(json);
      // print(result);
      return result;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Future<PlayerFactories> getAll() async {}

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

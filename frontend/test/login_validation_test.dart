import 'package:ff/blocs/LoginBloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('login validators', () {
    test('accept valid email addresses', () {
      final validators = Validators();

      expectLater(
        Stream.value('player@example.com').transform(validators.validateEmail),
        emits('player@example.com'),
      );
    });

    test('reject invalid email addresses', () {
      final validators = Validators();

      expectLater(
        Stream.value('player').transform(validators.validateEmail),
        emitsError('Enter a valid email'),
      );
    });

    test('reject short passwords', () {
      final validators = Validators();

      expectLater(
        Stream.value('1234').transform(validators.validatePassword),
        emitsError('Invalid password, please enter more than 4 characters'),
      );
    });
  });
}

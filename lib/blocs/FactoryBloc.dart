import 'dart:async';

import 'package:ff/models/Factory.dart';
import 'package:ff/services/api.dart';
import 'package:rxdart/rxdart.dart';

class FactoryBloc extends Object {
  final BehaviorSubject<List<Factory>> _factories =
      BehaviorSubject<List<Factory>>();

  BehaviorSubject<List<Factory>> get factories => _factories;

  Future<List<Factory>> getAll() async {
    final api = ApiProvider();

    try {
      dynamic json = await api.getAll("/factories");
      List<Factory> response = Factories.fromJson(json).factories;

      _factories.sink.add(response);
      return response;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  dispose() {
    _factories.close();
  }
}

import 'dart:async';

import 'package:ff/models/Factory.dart';
import 'package:ff/models/User.dart';
import 'package:ff/services/api.dart';
import 'package:rxdart/rxdart.dart';

class FactoryBloc extends Object {
  final api = ApiProvider();
  final BehaviorSubject<List<Factory>> _factories =
      BehaviorSubject<List<Factory>>();
  final BehaviorSubject<List<PlayerFactory>> _playerFactories =
      BehaviorSubject<List<PlayerFactory>>();

  BehaviorSubject<List<Factory>> get factories => _factories;
  BehaviorSubject<List<PlayerFactory>> get playerFactories => _playerFactories;

  Future<List<Factory>> getAll() async {
    try {
      dynamic json = await api.getAll("/factories");
      List<Factory> response = Factories.fromJson(json).factories;

      _factories.add(response);
      return response;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<List<PlayerFactory>> getUserFactories(String userId) async {
    try {
      dynamic json = await api.post("/factories", data: {"id": userId});
      List<PlayerFactory> response =
          PlayerFactories.fromJson(json).playerFactories;

      _playerFactories.add(response);
      return response;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<void> buyFactorie(String userId, String factoryId) async {
    try {
      await api.post("/buyFactories",
          data: {"user_id": userId, "factory_id": factoryId});

      getUserFactories(userId);
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<String> upgradeFactory(String userId, String factoryId) async {
    try {
      String response = await api.post("/upgradefactory",
          data: {"user_id": userId, "factory_id": factoryId});

      //  getUserFactories(userId); refetch?
      return response;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<String> workFactory(String userId, String factoryId) async {
    try {
      String response = await api.post("/workFactories",
          data: {"user_id": userId, "factory_id": factoryId});

      //  getUserFactories(userId); refetch?
      return response;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  dispose() {
    // _factories.close();
    // _playerFactories.close();
  }
}

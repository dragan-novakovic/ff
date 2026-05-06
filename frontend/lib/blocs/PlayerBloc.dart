import 'package:flutter/foundation.dart';

import '../models/PlayerState.dart';
import '../services/backend_api.dart';

class PlayerBloc extends ChangeNotifier {
  PlayerBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  PlayerState? _state;
  String? _error;
  String? _notice;
  bool _isLoading = false;
  bool _isWorking = false;
  bool _isTraining = false;

  PlayerState? get state => _state;
  String? get error => _error;
  String? get notice => _notice;
  bool get isLoading => _isLoading;
  bool get isWorking => _isWorking;
  bool get isTraining => _isTraining;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    _state = null;
    _error = null;
    _notice = null;
    _isLoading = false;
    _isWorking = false;
    _isTraining = false;
    notifyListeners();
  }

  Future<void> loadState(String playerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _state = await _apiClient.fetchPlayerState(playerId);
    } on BackendApiException catch (e) {
      _error = e.message;
    } on Exception {
      _error = 'Could not load player state from backend services.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PlayerActionResult?> work(String playerId) async {
    if (_isWorking) {
      return null;
    }

    _isWorking = true;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      final result = await _apiClient.work(playerId);
      _state = result.state;
      _notice = result.message;
      return result;
    } on BackendApiException catch (e) {
      _error = e.message;
      return null;
    } on Exception {
      _error = 'Could not complete work action.';
      return null;
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  Future<PlayerActionResult?> train(String playerId) async {
    if (_isTraining) {
      return null;
    }

    _isTraining = true;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      final result = await _apiClient.train(playerId);
      _state = result.state;
      _notice = result.message;
      return result;
    } on BackendApiException catch (e) {
      _error = e.message;
      return null;
    } on Exception {
      _error = 'Could not complete training action.';
      return null;
    } finally {
      _isTraining = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

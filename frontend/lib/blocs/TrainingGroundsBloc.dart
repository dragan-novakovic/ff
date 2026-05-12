import 'package:flutter/foundation.dart';

import '../models/PlayerState.dart';
import '../models/TrainingGrounds.dart';
import '../services/backend_api.dart';

class TrainingGroundsBloc extends ChangeNotifier {
  TrainingGroundsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  TrainingGroundsSummary? _summary;
  PlayerActionResult? _lastTraining;
  String? _error;
  bool _isLoading = false;
  bool _isTraining = false;

  TrainingGroundsSummary? get summary => _summary;
  PlayerActionResult? get lastTraining => _lastTraining;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isTraining => _isTraining;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load(String playerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _apiClient.fetchTrainingGrounds(playerId);
    } on BackendApiException catch (e) {
      _error = e.message;
    } on Exception {
      _error = 'Could not load training grounds.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PlayerActionResult?> train(String playerId) async {
    if (_isTraining) {
      return null;
    }

    _isTraining = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiClient.train(playerId);
      _lastTraining = result;
      _summary = await _apiClient.fetchTrainingGrounds(playerId);
      return result;
    } on BackendApiException catch (e) {
      _error = e.message;
      return null;
    } on Exception {
      _error = 'Could not complete training.';
      return null;
    } finally {
      _isTraining = false;
      notifyListeners();
    }
  }

  void clear() {
    _summary = null;
    _lastTraining = null;
    _error = null;
    _isLoading = false;
    _isTraining = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

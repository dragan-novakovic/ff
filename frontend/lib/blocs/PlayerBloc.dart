import 'package:flutter/foundation.dart';

import '../models/DailyObjectives.dart';
import '../models/PlayerState.dart';
import '../services/backend_api.dart';

class PlayerBloc extends ChangeNotifier {
  PlayerBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  PlayerState? _state;
  DailyObjectivesSummary? _dailyObjectives;
  DailyObjectiveClaimResult? _lastObjectiveClaim;
  String? _error;
  String? _notice;
  bool _isLoading = false;
  bool _isLoadingObjectives = false;
  bool _isWorking = false;
  bool _isTraining = false;
  bool _isRecovering = false;
  final Set<String> _claimingObjectiveIds = {};

  PlayerState? get state => _state;
  DailyObjectivesSummary? get dailyObjectives => _dailyObjectives;
  DailyObjectiveClaimResult? get lastObjectiveClaim => _lastObjectiveClaim;
  String? get error => _error;
  String? get notice => _notice;
  bool get isLoading => _isLoading;
  bool get isLoadingObjectives => _isLoadingObjectives;
  bool get isWorking => _isWorking;
  bool get isTraining => _isTraining;
  bool get isRecovering => _isRecovering;
  Set<String> get claimingObjectiveIds =>
      Set.unmodifiable(_claimingObjectiveIds);

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    _state = null;
    _dailyObjectives = null;
    _lastObjectiveClaim = null;
    _error = null;
    _notice = null;
    _isLoading = false;
    _isLoadingObjectives = false;
    _isWorking = false;
    _isTraining = false;
    _isRecovering = false;
    _claimingObjectiveIds.clear();
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

  Future<void> loadDailyObjectives(String playerId) async {
    _isLoadingObjectives = true;
    _error = null;
    notifyListeners();

    try {
      _dailyObjectives = await _apiClient.fetchDailyObjectives(playerId);
    } on BackendApiException catch (e) {
      _error = e.message;
    } on Exception {
      _error = 'Could not load daily objectives.';
    } finally {
      _isLoadingObjectives = false;
      notifyListeners();
    }
  }

  Future<DailyObjectiveClaimResult?> claimDailyObjective({
    required String playerId,
    required String objectiveId,
  }) async {
    if (_claimingObjectiveIds.contains(objectiveId)) {
      return null;
    }

    _claimingObjectiveIds.add(objectiveId);
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      final result = await _apiClient.claimDailyObjective(
        playerId: playerId,
        objectiveId: objectiveId,
        idempotencyKey:
            'daily-objective-$playerId-$objectiveId-${DateTime.now().microsecondsSinceEpoch}',
      );
      _lastObjectiveClaim = result;
      _dailyObjectives = result.objectives;
      if (result.state != null) {
        _state = result.state;
      }
      _notice = result.message;
      return result;
    } on BackendApiException catch (e) {
      _error = e.message;
      return null;
    } on Exception {
      _error = 'Could not claim daily objective.';
      return null;
    } finally {
      _claimingObjectiveIds.remove(objectiveId);
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

  Future<PlayerActionResult?> recoverAtHospital(String playerId) async {
    if (_isRecovering) {
      return null;
    }

    _isRecovering = true;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      final result = await _apiClient.recoverAtHospital(
        playerId: playerId,
        idempotencyKey:
            'hospital-$playerId-${DateTime.now().microsecondsSinceEpoch}',
      );
      _state = result.state;
      _notice = result.message;
      return result;
    } on BackendApiException catch (e) {
      _error = e.message;
      return null;
    } on Exception {
      _error = 'Could not recover at the hospital.';
      return null;
    } finally {
      _isRecovering = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

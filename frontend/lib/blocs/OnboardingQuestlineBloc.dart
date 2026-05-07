import 'package:flutter/foundation.dart';

import '../models/OnboardingQuestline.dart';
import '../services/backend_api.dart';

class OnboardingQuestlineBloc extends ChangeNotifier {
  OnboardingQuestlineBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  OnboardingQuestline? _questline;
  OnboardingQuestClaimResult? _lastClaim;
  OnboardingQuestSkipResult? _lastSkip;
  String? _error;
  String? _notice;
  bool _isLoading = false;
  final Set<String> _claimingQuestIds = {};
  final Set<String> _skippingQuestIds = {};

  OnboardingQuestline? get questline => _questline;
  OnboardingQuestClaimResult? get lastClaim => _lastClaim;
  OnboardingQuestSkipResult? get lastSkip => _lastSkip;
  String? get error => _error;
  String? get notice => _notice;
  bool get isLoading => _isLoading;
  Set<String> get claimingQuestIds => Set.unmodifiable(_claimingQuestIds);
  Set<String> get skippingQuestIds => Set.unmodifiable(_skippingQuestIds);
  OnboardingQuest? get currentQuest => _questline?.currentQuest;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    _questline = null;
    _lastClaim = null;
    _lastSkip = null;
    _error = null;
    _notice = null;
    _isLoading = false;
    _claimingQuestIds.clear();
    _skippingQuestIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _questline = await _apiClient.fetchOnboardingQuestline(playerId);
    } on BackendApiException catch (e) {
      _error = e.message;
    } on Exception {
      _error = 'Could not load onboarding progress.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<OnboardingQuestClaimResult?> claim({
    required String playerId,
    required String questId,
  }) async {
    if (_claimingQuestIds.contains(questId)) {
      return null;
    }

    _claimingQuestIds.add(questId);
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      final result = await _apiClient.claimOnboardingQuest(
        playerId: playerId,
        questId: questId,
        idempotencyKey:
            'onboarding-$playerId-$questId-${DateTime.now().microsecondsSinceEpoch}',
      );
      _lastClaim = result;
      _questline = result.questline;
      _notice = result.message;
      return result;
    } on BackendApiException catch (e) {
      _error = e.message;
      return null;
    } on Exception {
      _error = 'Could not claim onboarding reward.';
      return null;
    } finally {
      _claimingQuestIds.remove(questId);
      notifyListeners();
    }
  }

  Future<OnboardingQuestSkipResult?> skip({
    required String playerId,
    required String questId,
  }) async {
    if (_skippingQuestIds.contains(questId)) {
      return null;
    }

    _skippingQuestIds.add(questId);
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      final result = await _apiClient.skipOnboardingQuest(
        playerId: playerId,
        questId: questId,
        idempotencyKey:
            'onboarding-skip-$playerId-$questId-${DateTime.now().microsecondsSinceEpoch}',
      );
      _lastSkip = result;
      _questline = result.questline;
      _notice = result.message;
      return result;
    } on BackendApiException catch (e) {
      _error = e.message;
      return null;
    } on Exception {
      _error = 'Could not skip onboarding step.';
      return null;
    } finally {
      _skippingQuestIds.remove(questId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

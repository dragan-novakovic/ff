import 'package:flutter/foundation.dart';

import '../models/Achievements.dart';
import '../services/backend_api.dart';

class AchievementsBloc extends ChangeNotifier {
  AchievementsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  AchievementsSummary? summary;
  AchievementClaimResult? lastClaim;
  String? error;
  bool isLoading = false;
  final Set<String> claimingAchievementIds = {};

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    summary = null;
    lastClaim = null;
    error = null;
    isLoading = false;
    claimingAchievementIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      summary = await _apiClient.fetchAchievements(playerId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load achievements.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<AchievementClaimResult?> claim({
    required String playerId,
    required String achievementId,
  }) async {
    if (claimingAchievementIds.contains(achievementId)) {
      return null;
    }

    claimingAchievementIds.add(achievementId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.claimAchievement(
        playerId: playerId,
        achievementId: achievementId,
        idempotencyKey:
            'achievement-$playerId-$achievementId-${DateTime.now().microsecondsSinceEpoch}',
      );
      lastClaim = result;
      summary = result.achievements;
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not claim achievement medal.';
      return null;
    } finally {
      claimingAchievementIds.remove(achievementId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

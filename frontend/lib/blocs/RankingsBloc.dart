import 'package:flutter/foundation.dart';

import '../models/GameAreas.dart';
import '../services/backend_api.dart';

class RankingsBloc extends ChangeNotifier {
  RankingsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  RankingsLeaderboard? leaderboard;
  PublicPlayerProfile? profile;
  RankingEntry? playerRanking;
  String? error;
  bool isLoadingLeaderboard = false;
  bool isLoadingProfile = false;
  bool isLoadingPlayerRanking = false;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    leaderboard = null;
    profile = null;
    playerRanking = null;
    error = null;
    isLoadingLeaderboard = false;
    isLoadingProfile = false;
    isLoadingPlayerRanking = false;
    notifyListeners();
  }

  Future<void> loadLeaderboard({
    String sortBy = 'level',
    int limit = 50,
  }) async {
    isLoadingLeaderboard = true;
    error = null;
    notifyListeners();

    try {
      leaderboard = await _apiClient.fetchRankingsLeaderboard(
        sortBy: sortBy,
        limit: limit,
      );
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load rankings.';
    } finally {
      isLoadingLeaderboard = false;
      notifyListeners();
    }
  }

  Future<void> loadPublicProfile(String playerId) async {
    isLoadingProfile = true;
    error = null;
    notifyListeners();

    try {
      profile = await _apiClient.fetchPublicProfile(playerId);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load public profile.';
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> loadPlayerRanking(
    String playerId, {
    String sortBy = 'level',
  }) async {
    isLoadingPlayerRanking = true;
    error = null;
    notifyListeners();

    try {
      playerRanking = await _apiClient.fetchPlayerRanking(
        playerId,
        sortBy: sortBy,
      );
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load player ranking.';
    } finally {
      isLoadingPlayerRanking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';

import '../models/ActivityFeed.dart';
import '../services/backend_api.dart';

class ActivityFeedBloc extends ChangeNotifier {
  ActivityFeedBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  ActivityFeedSummary? feed;
  ActivityReadResult? lastRead;
  ActivityReadAllResult? lastReadAll;
  String? error;
  bool isLoading = false;
  bool isMarkingAllRead = false;
  final Set<String> markingEventIds = {};

  int get unreadCount => feed?.unreadCount ?? 0;

  List<ActivityEvent> get events => feed?.events ?? const <ActivityEvent>[];

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void clear() {
    feed = null;
    lastRead = null;
    lastReadAll = null;
    error = null;
    isLoading = false;
    isMarkingAllRead = false;
    markingEventIds.clear();
    notifyListeners();
  }

  Future<void> load(String playerId, {int limit = 50}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      feed = await _apiClient.fetchActivityFeed(playerId, limit: limit);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load activity feed.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void applyRealtimeActivity(ActivityFeedSummary update, {int limit = 50}) {
    final currentFeed = feed;
    if (currentFeed == null) {
      feed = update.copyWith(
        events: update.events.take(limit).toList(),
      );
    } else {
      final merged = <String, ActivityEvent>{
        for (final event in currentFeed.events) event.eventId: event,
        for (final event in update.events) event.eventId: event,
      }.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      feed = currentFeed.copyWith(
        events: merged.take(limit).toList(),
        unreadCount: update.unreadCount,
        updatedAt: update.updatedAt,
      );
    }
    error = null;
    notifyListeners();
  }

  Future<ActivityReadResult?> markRead({
    required String playerId,
    required String eventId,
  }) async {
    if (markingEventIds.contains(eventId)) {
      return null;
    }

    markingEventIds.add(eventId);
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.markActivityRead(
        playerId: playerId,
        eventId: eventId,
      );
      lastRead = result;
      final currentFeed = feed;
      if (currentFeed != null) {
        feed = currentFeed.copyWith(
          events: currentFeed.events
              .map((event) => event.eventId == eventId ? result.event : event)
              .toList(),
          unreadCount: result.unreadCount,
          updatedAt: result.updatedAt,
        );
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not mark activity read.';
      return null;
    } finally {
      markingEventIds.remove(eventId);
      notifyListeners();
    }
  }

  Future<ActivityReadAllResult?> markAllRead(String playerId) async {
    if (isMarkingAllRead) {
      return null;
    }

    isMarkingAllRead = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.markAllActivityRead(playerId: playerId);
      lastReadAll = result;
      final currentFeed = feed;
      if (currentFeed != null) {
        feed = currentFeed.copyWith(
          events: currentFeed.events
              .map((event) => event.copyWith(isRead: true))
              .toList(),
          unreadCount: result.unreadCount,
          updatedAt: result.updatedAt,
        );
      }
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not mark all activity read.';
      return null;
    } finally {
      isMarkingAllRead = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/RealtimeUpdates.dart';
import '../services/backend_api.dart';

typedef RealtimeUpdateHandler = FutureOr<void> Function(
  RealtimeUpdatesEnvelope update,
);

class RealtimeUpdatesBloc extends ChangeNotifier {
  RealtimeUpdatesBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  StreamSubscription<RealtimeUpdatesEnvelope>? _subscription;
  RealtimeUpdatesEnvelope? lastUpdate;
  String? error;
  bool isSubscribed = false;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  void start({
    required String playerId,
    String? chatToId,
    int limit = 50,
    DateTime? since,
    RealtimeUpdateHandler? onUpdate,
  }) {
    stop();
    error = null;
    isSubscribed = true;
    notifyListeners();

    _subscription = _apiClient
        .subscribeRealtimeUpdates(
      playerId,
      since: since,
      chatToId: chatToId,
      limit: limit,
    )
        .listen(
      (update) {
        lastUpdate = update;
        error = update.errors.isEmpty
            ? null
            : update.errors.map((entry) => entry.message).join(' ');
        notifyListeners();

        if (onUpdate != null && update.hasAnySection) {
          unawaited(
            Future<void>.sync(() => onUpdate(update)).catchError((_) {}),
          );
        }
      },
      onError: (Object _) {
        error = 'Live updates are retrying.';
        notifyListeners();
      },
    );
  }

  Future<void> pollOnce({
    required String playerId,
    String? chatToId,
    int limit = 50,
    DateTime? since,
    RealtimeUpdateHandler? onUpdate,
  }) async {
    try {
      final update = await _apiClient.fetchRealtimeUpdates(
        playerId,
        since: since,
        chatToId: chatToId,
        limit: limit,
      );
      lastUpdate = update;
      error = update.errors.isEmpty
          ? null
          : update.errors.map((entry) => entry.message).join(' ');
      notifyListeners();
      if (onUpdate != null && update.hasAnySection) {
        await onUpdate(update);
      }
    } on BackendApiException catch (e) {
      error = e.message;
      notifyListeners();
    } on Exception {
      error = 'Could not load live updates.';
      notifyListeners();
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    isSubscribed = false;
  }

  @override
  void dispose() {
    stop();
    _apiClient.close();
    super.dispose();
  }
}

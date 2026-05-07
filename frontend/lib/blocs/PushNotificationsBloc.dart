import 'package:flutter/foundation.dart';

import '../models/PushNotifications.dart';
import '../services/backend_api.dart';
import '../services/browser_push.dart';

class PushNotificationsBloc extends ChangeNotifier {
  PushNotificationsBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  PushNotificationSettings? settings;
  PushDeliveryList? deliveries;
  PushSubscriptionMutationResult? lastMutation;
  BrowserPushSubscription? browserStatus;
  String? error;
  bool isLoading = false;
  bool isSaving = false;

  void setBearerToken(String? token) {
    _apiClient.bearerToken = token;
  }

  Future<void> load(String playerId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      settings = await _apiClient.fetchPushNotificationSettings(playerId);
      deliveries = await _apiClient.fetchPushDeliveries(playerId, limit: 20);
    } on BackendApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Could not load push notification settings.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PushSubscriptionMutationResult?> enable(String playerId) async {
    if (isSaving) {
      return null;
    }

    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final currentSettings =
          settings ?? await _apiClient.fetchPushNotificationSettings(playerId);
      settings = currentSettings;
      final publicKey = currentSettings.vapidPublicKey;
      if (!currentSettings.isConfigured ||
          publicKey == null ||
          publicKey.isEmpty) {
        error = 'Push notifications need VAPID keys configured on the backend.';
        return null;
      }

      final browserSubscription =
          await requestBrowserPushSubscription(publicKey);
      browserStatus = browserSubscription;
      if (!browserSubscription.canPersist) {
        error = browserSubscription.message ??
            'Browser push permission was not granted.';
        return null;
      }

      final result = await _apiClient.savePushSubscription(
        playerId: playerId,
        endpoint: browserSubscription.endpoint!,
        p256dh: browserSubscription.p256dh!,
        auth: browserSubscription.auth!,
        userAgent: browserSubscription.userAgent,
      );
      lastMutation = result;
      await load(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not enable push notifications.';
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<PushSubscriptionMutationResult?> disable(String playerId) async {
    if (isSaving) {
      return null;
    }

    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final browserSubscription = await unsubscribeBrowserPushSubscription();
      browserStatus = browserSubscription;
      final endpoint = browserSubscription.endpoint ??
          settings?.latestEnabledSubscription?.endpoint;
      if (endpoint == null || endpoint.isEmpty) {
        error = 'No enabled browser subscription was found.';
        return null;
      }

      final result = await _apiClient.disablePushSubscription(
        playerId: playerId,
        endpoint: endpoint,
      );
      lastMutation = result;
      await load(playerId);
      return result;
    } on BackendApiException catch (e) {
      error = e.message;
      return null;
    } on Exception {
      error = 'Could not disable push notifications.';
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }
}

import '../models/PushNotifications.dart';

Future<BrowserPushSubscription> requestBrowserPushSubscription(
  String vapidPublicKey,
) async {
  return BrowserPushSubscription.unsupported(
    'Browser push notifications are only available in supported web browsers.',
  );
}

Future<BrowserPushSubscription> unsubscribeBrowserPushSubscription() async {
  return BrowserPushSubscription.unsupported(
    'Browser push notifications are only available in supported web browsers.',
  );
}

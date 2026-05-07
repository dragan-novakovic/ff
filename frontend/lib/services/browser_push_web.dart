import 'dart:html' as html;
import 'dart:js_util' as js_util;

import '../models/PushNotifications.dart';

Future<BrowserPushSubscription> requestBrowserPushSubscription(
  String vapidPublicKey,
) async {
  try {
    final result = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(html.window, 'ffRequestPushSubscription', [
        vapidPublicKey,
      ]),
    );
    return _fromJsResult(result);
  } on Object catch (error) {
    return BrowserPushSubscription.unsupported(error.toString());
  }
}

Future<BrowserPushSubscription> unsubscribeBrowserPushSubscription() async {
  try {
    final result = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(html.window, 'ffUnsubscribePushSubscription', []),
    );
    return _fromJsResult(result);
  } on Object catch (error) {
    return BrowserPushSubscription.unsupported(error.toString());
  }
}

BrowserPushSubscription _fromJsResult(Object? result) {
  if (result == null) {
    return BrowserPushSubscription.unsupported('No browser push result.');
  }

  return BrowserPushSubscription(
    supported: _readBool(result, 'supported'),
    subscribed: _readBool(result, 'subscribed'),
    permission: _readString(result, 'permission') ?? 'default',
    endpoint: _readString(result, 'endpoint'),
    p256dh: _readString(result, 'p256dh'),
    auth: _readString(result, 'auth'),
    userAgent:
        _readString(result, 'userAgent') ?? html.window.navigator.userAgent,
    message: _readString(result, 'message'),
  );
}

bool _readBool(Object target, String property) {
  final value = js_util.getProperty<Object?>(target, property);
  return value is bool ? value : false;
}

String? _readString(Object target, String property) {
  final value = js_util.getProperty<Object?>(target, property);
  return value is String && value.isNotEmpty ? value : null;
}

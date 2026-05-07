import 'package:ff/models/PushNotifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses push notification settings', () {
    final settings = PushNotificationSettings.fromJson({
      'playerId': 'player-1',
      'isConfigured': true,
      'vapidPublicKey': 'BPublicKey',
      'updatedAt': '2026-05-08T10:00:00Z',
      'subscriptions': [
        {
          'subscriptionId': 'sub-1',
          'playerId': 'player-1',
          'endpoint': 'https://push.example/sub-1',
          'userAgent': 'Firefox',
          'isEnabled': true,
          'failureCount': 0,
          'lastError': null,
          'createdAt': '2026-05-08T09:00:00Z',
          'updatedAt': '2026-05-08T10:00:00Z',
          'disabledAt': null,
        }
      ],
    });

    expect(settings.playerId, 'player-1');
    expect(settings.isConfigured, isTrue);
    expect(settings.hasEnabledSubscription, isTrue);
    expect(settings.latestEnabledSubscription?.endpoint,
        'https://push.example/sub-1');
  });

  test('parses push subscription mutation result', () {
    final result = PushSubscriptionMutationResult.fromJson({
      'completed': true,
      'message': 'Push notifications are enabled for this browser.',
      'isConfigured': true,
      'updatedAt': '2026-05-08T10:01:00Z',
      'subscription': {
        'subscriptionId': 'sub-1',
        'playerId': 'player-1',
        'endpoint': 'https://push.example/sub-1',
        'userAgent': 'Firefox',
        'isEnabled': true,
        'failureCount': 0,
        'lastError': null,
        'createdAt': '2026-05-08T09:00:00Z',
        'updatedAt': '2026-05-08T10:01:00Z',
        'disabledAt': null,
      }
    });

    expect(result.completed, isTrue);
    expect(result.subscription.isEnabled, isTrue);
  });

  test('parses push delivery list', () {
    final deliveries = PushDeliveryList.fromJson({
      'playerId': 'player-1',
      'updatedAt': '2026-05-08T10:02:00Z',
      'deliveries': [
        {
          'deliveryId': 'delivery-1',
          'eventId': 'activity-1',
          'playerId': 'player-1',
          'subscriptionId': 'sub-1',
          'title': 'Production update',
          'body': 'Food production is ready.',
          'relatedId': 'job-1',
          'url': '/activity?eventId=activity-1',
          'tag': 'activity-1',
          'status': 'pending',
          'attempts': 0,
          'createdAt': '2026-05-08T10:01:00Z',
          'updatedAt': '2026-05-08T10:01:00Z',
          'deliveredAt': null,
          'lastError': null,
        }
      ],
    });

    expect(deliveries.deliveries.single.status, 'pending');
    expect(deliveries.deliveries.single.relatedId, 'job-1');
  });
}

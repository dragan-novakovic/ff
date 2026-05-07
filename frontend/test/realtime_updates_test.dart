import 'package:ff/models/RealtimeUpdates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses persisted realtime update envelope', () {
    final update = RealtimeUpdatesEnvelope.fromJson({
      'playerId': 'player-1',
      'since': '2026-05-06T12:00:00Z',
      'generatedAt': '2026-05-06T12:00:08Z',
      'nextCursor': '2026-05-06T12:00:08Z',
      'pollAfterSeconds': 8,
      'hasChanges': true,
      'changedSections': ['activity', 'chat', 'production', 'market'],
      'activity': {
        'hasChanges': true,
        'playerId': 'player-1',
        'unreadCount': 1,
        'updatedAt': '2026-05-06T12:00:08Z',
        'events': [
          {
            'eventId': 'activity-production-completed-job-1',
            'playerId': 'player-1',
            'type': 'production_completed',
            'message': 'Food production is complete and ready to claim.',
            'isRead': false,
            'createdAt': '2026-05-06T12:00:05Z',
            'relatedId': 'job-1',
          }
        ],
      },
      'chat': {
        'hasChanges': true,
        'toId': 'global',
        'updatedAt': '2026-05-06T12:00:07Z',
        'messages': [
          {
            'id': 'message-1',
            'fromId': 'player-2',
            'toId': 'global',
            'content': 'Fresh listing on the market.',
            'createdAt': '2026-05-06T12:00:07Z',
          }
        ],
      },
      'production': {
        'hasChanges': true,
        'playerId': 'player-1',
        'updatedAt': '2026-05-06T12:00:06Z',
        'jobs': [_productionJob()],
        'completedJobs': [_productionJob()],
      },
      'market': {
        'hasChanges': true,
        'updatedAt': '2026-05-06T12:00:08Z',
        'listings': [_marketListing()],
        'playerListings': {
          'sellerId': 'player-1',
          'updatedAt': '2026-05-06T12:00:08Z',
          'listings': [_marketListing()],
        },
      },
      'errors': [],
    });

    expect(update.hasChanges, isTrue);
    expect(update.activity?.feed.events.single.type, 'production_completed');
    expect(update.chat?.messages.single.createdAt,
        DateTime.parse('2026-05-06T12:00:07Z'));
    expect(update.production?.hasCompletedJobs, isTrue);
    expect(update.market?.playerListings?.sellerId, 'player-1');
    expect(update.nextCursor, DateTime.parse('2026-05-06T12:00:08Z'));
  });
}

Map<String, Object?> _productionJob() => {
      'jobId': 'job-1',
      'playerId': 'player-1',
      'factoryId': 'food-factory',
      'status': 'completed',
      'inputItemId': 'grain',
      'inputItemName': 'Grain',
      'inputItemCategory': 'Raw material',
      'inputQuantity': 2,
      'outputItemId': 'food',
      'outputItemName': 'Food',
      'outputItemCategory': 'Consumable',
      'outputQuantity': 3,
      'durationSeconds': 90,
      'startedAt': '2026-05-06T11:58:30Z',
      'completesAt': '2026-05-06T12:00:00Z',
      'completedAt': '2026-05-06T12:00:00Z',
      'claimedAt': null,
      'createdAt': '2026-05-06T11:58:30Z',
      'updatedAt': '2026-05-06T12:00:00Z',
      'canClaim': true,
    };

Map<String, Object?> _marketListing() => {
      'listingId': 'listing-1',
      'itemId': 'food',
      'itemName': 'Food',
      'category': 'Consumable',
      'quantity': 4,
      'pricePerUnit': 3,
      'sellerId': 'player-1',
      'status': 'open',
      'createdAt': '2026-05-06T12:00:00Z',
      'updatedAt': '2026-05-06T12:00:08Z',
    };

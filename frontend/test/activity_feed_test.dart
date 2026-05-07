import 'package:ff/models/ActivityFeed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses persisted activity feed response', () {
    final feed = ActivityFeedSummary.fromJson({
      'playerId': 'player-1',
      'unreadCount': 2,
      'updatedAt': '2026-05-06T12:10:00Z',
      'events': [
        {
          'eventId': 'activity-production-1',
          'playerId': 'player-1',
          'type': 'production_claim',
          'message': 'Claimed 3 Food from Food Factory.',
          'isRead': false,
          'createdAt': '2026-05-06T12:00:00Z',
          'relatedId': 'job-1',
        },
        {
          'eventId': 'activity-battle-1',
          'playerId': 'player-1',
          'type': 'battle_contribution',
          'message': 'Battle contribution dealt 42 damage.',
          'isRead': true,
          'createdAt': '2026-05-06T12:05:00Z',
          'relatedId': 'battle-1',
        },
      ],
    });

    expect(feed.playerId, 'player-1');
    expect(feed.unreadCount, 2);
    expect(feed.events, hasLength(2));
    expect(feed.events.first.type, 'production_claim');
    expect(feed.events.first.isRead, isFalse);
    expect(feed.events.last.relatedId, 'battle-1');
  });

  test('parses mark one activity read response', () {
    final result = ActivityReadResult.fromJson({
      'completed': true,
      'message': 'Activity event marked read.',
      'unreadCount': 1,
      'updatedAt': '2026-05-06T12:15:00Z',
      'event': {
        'eventId': 'activity-market-1',
        'playerId': 'player-1',
        'type': 'market_buy',
        'message': 'Bought 1 Food.',
        'isRead': true,
        'createdAt': '2026-05-06T12:12:00Z',
        'relatedId': 'listing-1',
      },
    });

    expect(result.completed, isTrue);
    expect(result.event.isRead, isTrue);
    expect(result.unreadCount, 1);
  });

  test('parses mark all activity read response with snake case fields', () {
    final result = ActivityReadAllResult.fromJson({
      'completed': true,
      'message': 'Marked 3 activity events read.',
      'marked_read_count': 3,
      'unread_count': 0,
      'updated_at': '2026-05-06T12:20:00Z',
    });

    expect(result.completed, isTrue);
    expect(result.markedReadCount, 3);
    expect(result.unreadCount, 0);
    expect(result.updatedAt, DateTime.parse('2026-05-06T12:20:00Z'));
  });
}

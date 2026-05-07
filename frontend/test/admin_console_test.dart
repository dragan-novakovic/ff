import 'package:ff/models/AdminConsole.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses admin player summary with persisted moderation and ledger data',
      () {
    final summary = AdminPlayerSummary.fromJson({
      'playerId': 'player-1',
      'identity': {
        'accountId': 'account-1',
        'playerId': 'player-1',
        'email': 'player@example.test',
        'username': 'PlayerOne',
        'createdAt': '2026-05-06T12:00:00Z',
        'lastLoginAt': '2026-05-06T12:15:00Z',
      },
      'progression': {
        'level': 4,
        'experience': 250,
        'strength': 15,
        'energy': 80,
        'maxEnergy': 100,
        'lastWorkDate': '2026-05-06',
        'lastTrainDate': '2026-05-05',
        'hospitalCooldownUntil': null,
        'createdAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:20:00Z',
      },
      'wallet': {
        'gold': 125,
        'storageLimit': 100,
        'createdAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:20:00Z',
      },
      'activeModerationRecords': [
        {
          'recordId': 'mod-1',
          'playerId': 'player-1',
          'type': 'suspension',
          'reason': 'Abusive chat',
          'active': true,
          'expiresAt': '2026-05-07T12:00:00Z',
          'createdBy': 'admin-1',
          'createdAt': '2026-05-06T12:30:00Z',
          'revokedBy': null,
          'revokedAt': null,
          'revocationReason': '',
        }
      ],
      'latestNotes': [],
      'latestLedgerEntries': [
        {
          'ledgerId': 'ledger-1',
          'playerId': 'player-1',
          'username': 'PlayerOne',
          'entryType': 'work_reward',
          'goldDelta': 25,
          'itemId': '',
          'itemDelta': 0,
          'description': 'Worked a shift.',
          'createdAt': '2026-05-06T12:25:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:40:00Z',
    });

    expect(summary.identity?.username, 'PlayerOne');
    expect(summary.progression?.level, 4);
    expect(summary.wallet?.gold, 125);
    expect(summary.activeModerationRecords.single.type, 'suspension');
    expect(summary.latestLedgerEntries.single.goldDelta, 25);
  });

  test('parses admin audit and content moderation queue responses', () {
    final audit = AdminAuditRecordList.fromJson({
      'playerId': 'player-1',
      'records': [
        {
          'auditId': 'audit-1',
          'actorAdminId': 'admin-1',
          'actionType': 'moderation.note.create',
          'targetPlayerId': 'player-1',
          'targetType': 'moderation_record',
          'targetId': 'mod-1',
          'details': '{"reason":"Support note"}',
          'createdAt': '2026-05-06T12:00:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    final queue = AdminContentModerationQueue.fromJson({
      'status': 'open',
      'items': [
        {
          'itemId': 'content-1',
          'sourceType': 'chat_message',
          'sourceId': 'message-1',
          'playerId': 'player-1',
          'content': 'Reported chat text',
          'reason': 'Harassment report',
          'status': 'open',
          'reportedBy': 'admin-1',
          'createdAt': '2026-05-06T12:00:00Z',
          'reviewedBy': null,
          'reviewedAt': null,
          'resolution': '',
          'reviewAction': 'none',
          'lastReportedAt': '2026-05-06T12:03:00Z',
          'reportCount': 2,
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    expect(audit.records.single.actionType, 'moderation.note.create');
    expect(queue.items.single.sourceType, 'chat_message');
    expect(queue.items.single.status, 'open');
    expect(queue.items.single.reportCount, 2);
    expect(queue.items.single.reviewAction, 'none');
  });

  test('parses admin economy balance dashboard metrics', () {
    final dashboard = AdminEconomyBalanceDashboard.fromJson({
      'days': 30,
      'from': '2026-05-01T00:00:00Z',
      'to': '2026-05-31T00:00:00Z',
      'gold': {
        'totalWalletGold': 1000,
        'walletCount': 4,
        'ledgerEntryCount': 8,
        'goldCreated': 500,
        'goldSunk': 125,
        'netGoldDelta': 375,
        'entryTypes': [
          {
            'entryType': 'battle_reward',
            'entryCount': 2,
            'goldCreated': 80,
            'goldSunk': 0,
            'netGoldDelta': 80,
          }
        ],
      },
      'items': {
        'itemKinds': 2,
        'totalQuantity': 70,
        'playerQuantity': 40,
        'companyQuantity': 30,
        'topItems': [
          {
            'itemId': 'grain',
            'name': 'Grain',
            'category': 'Raw material',
            'totalQuantity': 50,
            'playerQuantity': 25,
            'companyQuantity': 25,
            'holderCount': 3,
          }
        ],
      },
      'wages': {
        'workRecordCount': 3,
        'paidWorkRecordCount': 2,
        'pendingCreditWorkRecordCount': 1,
        'grossWages': 120,
        'netWages': 100,
        'taxGold': 20,
        'averageGrossWage': 40,
        'topCompanies': [
          {
            'companyId': 'co-1',
            'companyName': 'Foundry',
            'workRecordCount': 3,
            'grossWages': 120,
            'netWages': 100,
            'taxGold': 20,
          }
        ],
      },
      'prices': {
        'tradeCount': 2,
        'quantityTraded': 10,
        'goldVolume': 75,
        'averagePrice': 8,
        'minPrice': 5,
        'maxPrice': 10,
        'topItems': [
          {
            'itemId': 'food',
            'itemName': 'Food',
            'category': 'Consumable',
            'tradeCount': 2,
            'quantityTraded': 10,
            'goldVolume': 75,
            'averagePrice': 8,
            'minPrice': 5,
            'maxPrice': 10,
            'lastTradedAt': '2026-05-30T12:00:00Z',
          }
        ],
      },
      'taxes': {
        'entryCount': 4,
        'taxCollected': 60,
        'taxedGrossAmount': 600,
        'averageTaxRate': 10,
        'entryTypes': [
          {
            'entryType': 'income_tax',
            'entryCount': 2,
            'taxCollected': 40,
            'taxedGrossAmount': 400,
            'averageTaxRate': 10,
          }
        ],
        'countries': [
          {
            'countryId': 'freiland',
            'countryName': 'Freiland',
            'taxCollected': 60,
            'taxedGrossAmount': 600,
            'treasury': 500,
            'incomeTaxRate': 10,
            'marketTaxRate': 5,
            'productionTaxRate': 3,
          }
        ],
      },
      'factories': {
        'runCount': 2,
        'playerRunCount': 1,
        'companyRunCount': 1,
        'outputQuantity': 20,
        'topItems': [
          {
            'itemId': 'food',
            'runCount': 2,
            'outputQuantity': 20,
            'lastProducedAt': '2026-05-29T12:00:00Z',
          }
        ],
      },
      'battles': {
        'contributionCount': 3,
        'battleCount': 1,
        'wonContributionCount': 2,
        'goldRewards': 90,
        'experienceRewards': 45,
        'damage': 300,
        'energySpent': 30,
        'topBattles': [
          {
            'battleId': 'battle-1',
            'battleName': 'Border Clash',
            'contributionCount': 3,
            'goldRewards': 90,
            'experienceRewards': 45,
            'damage': 300,
            'lastContributionAt': '2026-05-28T12:00:00Z',
          }
        ],
      },
      'updatedAt': '2026-05-31T00:00:00Z',
    });

    expect(dashboard.gold.goldCreated, 500);
    expect(dashboard.items.topItems.single.companyQuantity, 25);
    expect(dashboard.wages.topCompanies.single.netWages, 100);
    expect(dashboard.prices.topItems.single.averagePrice, 8);
    expect(dashboard.taxes.countries.single.marketTaxRate, 5);
    expect(dashboard.factories.topItems.single.outputQuantity, 20);
    expect(dashboard.battles.topBattles.single.goldRewards, 90);
  });

  test('parses anti-abuse review queue responses', () {
    final queue = AdminAntiAbuseReviewQueue.fromJson({
      'status': 'open',
      'playerId': 'player-1',
      'items': [
        {
          'eventId': 'suspicious-1',
          'playerId': 'player-1',
          'username': 'PlayerOne',
          'actionType': 'market_buy',
          'severity': 'high',
          'ruleId': 'idempotency.market_buy',
          'reason': 'Idempotency key replay used a different request payload.',
          'subjectType': 'market_listing',
          'subjectId': 'listing-1',
          'route': '/players/{playerId}/market/listings/{listingId}/buy',
          'idempotencyKey': 'buy-key',
          'decision': 'blocked',
          'auditId': 'gateway-audit-1',
          'metadata': '{"windowCount":1}',
          'recentLedgerEntries': 2,
          'recentMarketFills': 1,
          'recentActivityEvents': 3,
          'status': 'open',
          'createdAt': '2026-05-06T12:00:00Z',
          'reviewedBy': null,
          'reviewedAt': null,
          'resolution': '',
        }
      ],
      'updatedAt': '2026-05-06T12:05:00Z',
    });

    expect(queue.items.single.ruleId, 'idempotency.market_buy');
    expect(queue.items.single.recentLedgerEntries, 2);
    expect(queue.items.single.status, 'open');
  });
}

import 'package:ff/models/ResourceLogistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses resource sites', () {
    final list = ResourceSiteList.fromJson({
      'updatedAt': '2026-05-08T00:00:00Z',
      'sites': [
        {
          'siteId': 'ironvale-iron-site',
          'regionId': 'ironvale',
          'countryId': 'freiland',
          'resourceId': 'iron',
          'resourceName': 'Iron Ore',
          'itemId': 'iron',
          'itemName': 'Iron',
          'itemCategory': 'Raw material',
          'siteName': 'Ironvale Mines',
          'terrain': 'Highlands',
          'baseYield': 8,
          'extractionSeconds': 45,
          'reserveRemaining': 1000,
          'reserveCapacity': 1200,
          'depletionPerRun': 8,
          'qualityPercent': 95,
          'extractionCount': 3,
          'isDepleted': false,
          'updatedAt': '2026-05-08T00:00:00Z',
        }
      ],
    });

    expect(list.sites.single.siteId, 'ironvale-iron-site');
    expect(list.sites.single.reserveRatio, closeTo(0.833, 0.01));
  });

  test('parses resource logistics dashboard', () {
    final dashboard = ResourceLogisticsDashboard.fromJson({
      'companyId': 'co-1',
      'inTransitQuantity': 2,
      'updatedAt': '2026-05-08T00:00:00Z',
      'extractions': [
        {
          'jobId': 'xjob-1',
          'companyId': 'co-1',
          'actorPlayerId': 'player-1',
          'siteId': 'ironvale-iron-site',
          'regionId': 'ironvale',
          'regionName': 'Ironvale Mines',
          'countryId': 'freiland',
          'resourceId': 'iron',
          'resourceName': 'Iron Ore',
          'itemId': 'iron',
          'itemName': 'Iron',
          'itemCategory': 'Raw material',
          'requestedRuns': 1,
          'baseYield': 8,
          'yieldQuantity': 8,
          'status': 'completed',
          'durationSeconds': 45,
          'startedAt': '2026-05-08T00:00:00Z',
          'completesAt': '2026-05-08T00:00:45Z',
          'completedAt': '2026-05-08T00:00:45Z',
          'claimedAt': null,
          'idempotencyKey': 'extract-1',
          'createdAt': '2026-05-08T00:00:00Z',
          'updatedAt': '2026-05-08T00:00:45Z',
          'canClaim': true,
        }
      ],
      'shipments': [
        {
          'shipmentId': 'ship-1',
          'companyId': 'co-1',
          'actorPlayerId': 'player-1',
          'itemId': 'iron',
          'itemName': 'Iron',
          'itemCategory': 'Raw material',
          'quantity': 2,
          'originRegionId': 'ironvale',
          'originRegionName': 'Ironvale Mines',
          'destinationRegionId': 'freyport',
          'destinationRegionName': 'Freyport Fuel Depots',
          'status': 'in_transit',
          'durationSeconds': 30,
          'dispatchedAt': '2026-05-08T00:00:00Z',
          'arrivesAt': '2026-05-08T00:00:30Z',
          'deliveredAt': null,
          'lastError': null,
          'createdAt': '2026-05-08T00:00:00Z',
          'updatedAt': '2026-05-08T00:00:00Z',
          'canDeliver': true,
        }
      ],
      'assets': {
        'companyId': 'co-1',
        'walletGold': 500,
        'storageUsed': 10,
        'storageLimit': 200,
        'inventory': [
          {
            'itemId': 'iron',
            'name': 'Iron',
            'category': 'Raw material',
            'quantity': 10,
            'description': 'Stored iron.'
          }
        ],
        'factories': [],
        'productionJobs': [],
        'workforceJobs': [],
        'workRecords': [],
        'updatedAt': '2026-05-08T00:00:00Z',
      },
    });

    expect(dashboard.extractions.single.canClaim, isTrue);
    expect(dashboard.shipments.single.canDeliver, isTrue);
    expect(dashboard.assets.inventory.single.quantity, 10);
  });
}

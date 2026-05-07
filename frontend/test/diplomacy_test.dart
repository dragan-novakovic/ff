import 'package:ff/models/GameAreas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses diplomacy status with treaties and relations', () {
    final status = DiplomacyStatus.fromJson({
      'playerId': 'player-1',
      'citizenship': {
        'playerId': 'player-1',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'status': 'active',
        'joinedAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-06T12:00:00Z',
      },
      'authorization': {
        'canPropose': true,
        'canRatify': true,
        'canTerminate': true,
        'role': 'citizen-congress',
        'message': 'Active citizen.',
      },
      'activeTreaties': [
        _treatyJson(
          treatyId: 'treaty-alliance-1',
          treatyType: 'alliance',
          status: 'active',
        ),
      ],
      'pendingTreaties': [
        _treatyJson(
          treatyId: 'treaty-trade-1',
          treatyType: 'trade_agreement',
          status: 'proposed',
        ),
      ],
      'relationships': [
        {
          'relationId': 'relation-freiland-nordheim-treaty-alliance-1',
          'countryId': 'freiland',
          'counterpartyCountryId': 'nordheim',
          'counterpartyCountryName': 'Nordheim',
          'counterpartyCountryCode': 'NRD',
          'relationshipType': 'allied',
          'direction': 'outbound',
          'sourceTreatyId': 'treaty-alliance-1',
          'activeUntil': '2099-05-06T12:00:00Z',
        }
      ],
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    expect(status.countryId, 'freiland');
    expect(status.authorization.canPropose, isTrue);
    expect(status.activeTreaties.single.displayType, 'Alliance');
    expect(status.pendingTreaties.single.isProposed, isTrue);
    expect(status.relationships.single.displayType, 'Allied');
  });

  test('parses diplomacy mutation result with treaty details', () {
    final result = DiplomacyMutationResult.fromJson({
      'completed': true,
      'message': 'Treaty ratified and activated.',
      'treaty': _treatyJson(
        treatyId: 'treaty-peace-1',
        treatyType: 'peace',
        status: 'active',
        treasuryAmount: 2500,
      ),
      'authorization': {
        'canPropose': true,
        'canRatify': true,
        'canTerminate': true,
        'role': 'office:president:President',
        'message': 'Office holder.',
      },
      'statusCode': 200,
      'updatedAt': '2026-05-06T12:15:00Z',
    });

    expect(result.completed, isTrue);
    expect(result.treaty?.treasuryAmount, 2500);
    expect(result.treaty?.isActive, isTrue);
    expect(result.authorization?.canTerminate, isTrue);
  });
}

Map<String, Object?> _treatyJson({
  required String treatyId,
  required String treatyType,
  required String status,
  int treasuryAmount = 0,
}) {
  return {
    'treatyId': treatyId,
    'initiatorCountryId': 'freiland',
    'initiatorCountryName': 'Freiland',
    'initiatorCountryCode': 'FRL',
    'targetCountryId': 'nordheim',
    'targetCountryName': 'Nordheim',
    'targetCountryCode': 'NRD',
    'treatyType': treatyType,
    'status': status,
    'title': 'Mutual accord',
    'terms': 'Persisted diplomatic terms.',
    'sourceLawId': null,
    'proposedByPlayerId': 'player-1',
    'proposedAt': '2026-05-06T12:00:00Z',
    'ratifiedByPlayerId': status == 'active' ? 'player-2' : null,
    'ratifiedAt': status == 'active' ? '2026-05-06T12:05:00Z' : null,
    'rejectedByPlayerId': null,
    'rejectedAt': null,
    'rejectionReason': '',
    'terminatedByPlayerId': null,
    'terminatedAt': null,
    'terminationReason': '',
    'startsAt': status == 'active' ? '2026-05-06T12:05:00Z' : null,
    'expiresAt': '2099-05-06T12:00:00Z',
    'durationDays': 90,
    'treasuryAmount': treasuryAmount,
    'treasuryTransferStatus':
        treasuryAmount > 0 ? 'transferred' : 'not_required',
    'createdAt': '2026-05-06T12:00:00Z',
    'updatedAt': '2026-05-06T12:05:00Z',
  };
}

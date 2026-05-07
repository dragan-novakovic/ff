import 'package:ff/models/GameAreas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses law proposal list with authorization and vote counts', () {
    final proposals = LawProposalList.fromJson({
      'proposals': [
        {
          'proposalId': 'law-proposal-freiland-tax-1',
          'countryId': 'freiland',
          'countryName': 'Freiland',
          'countryCode': 'FRL',
          'proposalType': 'tax_policy',
          'title': 'Lower market tax',
          'description': 'Reduce market taxes for traders.',
          'sponsorPlayerId': 'player-1',
          'status': 'voting',
          'votingStartsAt': '2026-05-06T12:00:00Z',
          'votingEndsAt': '2099-05-08T12:00:00Z',
          'resolvedAt': null,
          'executedAt': null,
          'approvalThresholdPercent': 50,
          'executionStatus': 'pending',
          'executionMessage': '',
          'resultLawId': null,
          'incomeTaxRate': 4,
          'marketTaxRate': 1,
          'productionTaxRate': 2,
          'treasuryAmount': null,
          'treasuryTargetPlayerId': null,
          'treasuryReason': '',
          'citizenshipRule': null,
          'yesVotes': 3,
          'noVotes': 1,
          'abstainVotes': 1,
          'voteCount': 5,
          'createdAt': '2026-05-06T12:00:00Z',
          'updatedAt': '2026-05-06T12:05:00Z',
        }
      ],
      'authorization': {
        'canCreateProposal': true,
        'canVote': true,
        'canResolve': false,
        'role': 'citizen-congress',
        'message': 'Active citizen.',
      },
      'updatedAt': '2026-05-06T12:10:00Z',
    });

    expect(proposals.authorization?.canVote, isTrue);
    expect(proposals.proposals.single.proposalType, 'tax_policy');
    expect(proposals.proposals.single.yesPercent, 75);
    expect(proposals.activeProposals, hasLength(1));
  });

  test('parses law proposal details execution history', () {
    final details = LawProposalDetails.fromJson({
      'proposal': {
        'proposalId': 'law-proposal-freiland-treasury-1',
        'countryId': 'freiland',
        'countryName': 'Freiland',
        'countryCode': 'FRL',
        'proposalType': 'treasury_spend',
        'title': 'Build clinics',
        'description': 'Spend treasury funds on clinics.',
        'sponsorPlayerId': 'player-1',
        'status': 'passed',
        'votingStartsAt': '2026-05-06T12:00:00Z',
        'votingEndsAt': '2026-05-08T12:00:00Z',
        'resolvedAt': '2026-05-08T12:01:00Z',
        'executedAt': '2026-05-08T12:01:00Z',
        'approvalThresholdPercent': 50,
        'executionStatus': 'executed',
        'executionMessage': 'Treasury spent 500 gold by congress law.',
        'resultLawId': 'law-law-proposal-freiland-treasury-1',
        'incomeTaxRate': null,
        'marketTaxRate': null,
        'productionTaxRate': null,
        'treasuryAmount': 500,
        'treasuryTargetPlayerId': 'player-2',
        'treasuryReason': 'Clinic construction',
        'citizenshipRule': null,
        'yesVotes': 5,
        'noVotes': 2,
        'abstainVotes': 0,
        'voteCount': 7,
        'createdAt': '2026-05-06T12:00:00Z',
        'updatedAt': '2026-05-08T12:01:00Z',
      },
      'votes': [
        {
          'voteId': 'vote-1',
          'proposalId': 'law-proposal-freiland-treasury-1',
          'voterPlayerId': 'player-1',
          'countryId': 'freiland',
          'choice': 'yes',
          'castAt': '2026-05-06T13:00:00Z',
        }
      ],
      'executions': [
        {
          'executionId': 'execution-1',
          'proposalId': 'law-proposal-freiland-treasury-1',
          'lawId': 'law-law-proposal-freiland-treasury-1',
          'executorPlayerId': 'system',
          'action': 'execute_treasury_spend',
          'status': 'executed',
          'message': 'Treasury spent 500 gold by congress law.',
          'createdAt': '2026-05-08T12:01:00Z',
        }
      ],
      'authorization': {
        'canCreateProposal': true,
        'canVote': true,
        'canResolve': true,
        'role': 'office:president:President',
        'message': 'Office holder.',
      },
      'updatedAt': '2026-05-08T12:02:00Z',
    });

    expect(details.proposal.treasuryAmount, 500);
    expect(details.votes.single.choice, 'yes');
    expect(details.executions.single.status, 'executed');
    expect(details.authorization?.canResolve, isTrue);
  });
}

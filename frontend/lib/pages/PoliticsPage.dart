import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PoliticsPage extends StatefulWidget {
  final User user;
  const PoliticsPage({super.key, required this.user});

  @override
  State<PoliticsPage> createState() => _PoliticsPageState();
}

class _PoliticsPageState extends State<PoliticsPage> {
  late final PoliticsBloc _politicsBloc;
  late final LoginBloc _loginBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;

  @override
  void initState() {
    super.initState();
    _politicsBloc = Provider.of<PoliticsBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _politicsBloc.setBearerToken(_loginBloc.currentToken);
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _politicsBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _createParty() async {
    final citizenship = _politicsBloc.status?.citizenship;
    if (citizenship == null) {
      _showMessage('Join a country before creating a political party.');
      return;
    }

    final result = await showDialog<_PartyFormResult>(
      context: context,
      builder: (context) => const _CreatePartyDialog(),
    );
    if (result == null) {
      return;
    }

    _politicsBloc.setBearerToken(_loginBloc.currentToken);
    final mutation = await _politicsBloc.createParty(
      playerId: widget.user.uid,
      countryId: citizenship.countryId,
      name: result.name,
      shortName: result.shortName,
      description: result.description,
      ideology: result.ideology,
    );
    if (mutation?.completed == true) {
      await _onboardingBloc.load(widget.user.uid);
    }
    _showMessage(mutation?.message ?? _politicsBloc.error);
  }

  Future<void> _joinParty(PoliticalParty party) async {
    _politicsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _politicsBloc.joinParty(
      playerId: widget.user.uid,
      partyId: party.partyId,
    );
    if (result?.completed == true) {
      await _onboardingBloc.load(widget.user.uid);
    }
    _showMessage(result?.message ?? _politicsBloc.error);
  }

  Future<void> _leaveParty(PoliticalParty party) async {
    _politicsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _politicsBloc.leaveParty(
      playerId: widget.user.uid,
      partyId: party.partyId,
    );
    _showMessage(result?.message ?? _politicsBloc.error);
  }

  Future<void> _loadElection(PoliticalElection election) async {
    await _politicsBloc.loadElection(election.electionId);
  }

  Future<void> _declareCandidacy(PoliticalElection election) async {
    final manifesto = await showDialog<String>(
      context: context,
      builder: (context) => _ManifestoDialog(election: election),
    );
    if (manifesto == null) {
      return;
    }

    final membership = _politicsBloc.status?.membership;
    final partyId = membership?.countryId == election.countryId
        ? membership?.partyId
        : null;
    _politicsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _politicsBloc.declareCandidacy(
      playerId: widget.user.uid,
      electionId: election.electionId,
      partyId: partyId,
      manifesto: manifesto,
    );
    _showMessage(result?.message ?? _politicsBloc.error);
  }

  Future<void> _vote(PoliticalElection election, Candidacy candidacy) async {
    _politicsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _politicsBloc.vote(
      playerId: widget.user.uid,
      electionId: election.electionId,
      candidacyId: candidacy.candidacyId,
    );
    _showMessage(result?.message ?? _politicsBloc.error);
  }

  void _showMessage(String? message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Politics & Elections')),
      body: Consumer<PoliticsBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.parties == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.parties == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final parties = bloc.parties?.parties ?? <PoliticalParty>[];
          final elections = bloc.elections?.elections ?? <PoliticalElection>[];
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OnboardingGuidanceCard(
                  questline: context.watch<OnboardingQuestlineBloc>().questline,
                  route: '/politics',
                ),
                _StatusCard(
                  status: bloc.status,
                  error: bloc.error,
                  isLoading: bloc.isLoading,
                  onCreateParty: _createParty,
                ),
                if (bloc.lastPartyMutation != null)
                  _MessageCard(message: bloc.lastPartyMutation!.message),
                _SectionHeader(
                  title: 'Political parties',
                  subtitle:
                      'Parties and memberships are persisted by the world service.',
                ),
                if (parties.isEmpty)
                  const _EmptyCard(
                    icon: Icons.how_to_vote_outlined,
                    message: 'No political parties exist yet.',
                  )
                else
                  ...parties.map((party) => _PartyCard(
                        party: party,
                        membership: bloc.status?.membership,
                        citizenship: bloc.status?.citizenship,
                        isUpdating:
                            bloc.updatingPartyIds.contains(party.partyId),
                        onJoin: () => _joinParty(party),
                        onLeave: () => _leaveParty(party),
                      )),
                _SectionHeader(
                  title: 'Elections',
                  subtitle:
                      'Citizens can declare candidacy and cast exactly one vote per election.',
                ),
                if (elections.isEmpty)
                  const _EmptyCard(
                    icon: Icons.ballot_outlined,
                    message: 'No current elections are available.',
                  )
                else
                  ...elections.map((election) => _ElectionCard(
                        election: election,
                        status: bloc.status,
                        isSelected:
                            bloc.selectedElection?.election.electionId ==
                                election.electionId,
                        isDeclaring: bloc.declaringElectionIds
                            .contains(election.electionId),
                        onDetails: () => _loadElection(election),
                        onDeclare: election.isOpen
                            ? () => _declareCandidacy(election)
                            : null,
                      )),
                if (bloc.selectedElection != null)
                  _ElectionDetailsCard(
                    details: bloc.selectedElection!,
                    results: bloc.selectedResults,
                    playerStatus: bloc.status,
                    isLoading: bloc.isLoadingElection,
                    votingCandidacyIds: bloc.votingCandidacyIds,
                    onVote: (candidacy) =>
                        _vote(bloc.selectedElection!.election, candidacy),
                  ),
                _SectionHeader(
                  title: 'Office holders',
                  subtitle: 'Resolved elections create persisted office terms.',
                ),
                _OfficeHoldersCard(holders: bloc.officeHolders),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final PlayerPoliticsStatus? status;
  final String? error;
  final bool isLoading;
  final VoidCallback onCreateParty;

  const _StatusCard({
    required this.status,
    required this.error,
    required this.isLoading,
    required this.onCreateParty,
  });

  @override
  Widget build(BuildContext context) {
    final citizenship = status?.citizenship;
    final membership = status?.membership;
    return Card(
      color: error == null ? Colors.blue.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  error == null ? Icons.account_balance : Icons.warning_amber,
                  color: error == null ? Colors.blue : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your political status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : onCreateParty,
                  icon: const Icon(Icons.add),
                  label: const Text('Create party'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(error ??
                (citizenship == null
                    ? 'Join a country on the World page to unlock parties, candidacy, and voting.'
                    : 'Citizen of ${citizenship.countryName}.')),
            const SizedBox(height: 8),
            Text(membership == null
                ? 'No active party membership.'
                : 'Member of ${membership.partyName} (${membership.role}).'),
          ],
        ),
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  final PoliticalParty party;
  final PoliticalPartyMembership? membership;
  final PlayerCitizenship? citizenship;
  final bool isUpdating;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  const _PartyCard({
    required this.party,
    required this.membership,
    required this.citizenship,
    required this.isUpdating,
    required this.onJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final isMember = membership?.partyId == party.partyId;
    final canJoin = citizenship?.countryId == party.countryId && !isMember;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${party.name} (${party.shortName})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(party.countryCode)),
              ],
            ),
            const SizedBox(height: 8),
            Text(party.description),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(party.ideology)),
                Chip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: Text('${Utils.number(party.memberCount)} members'),
                ),
                if (isMember)
                  const Chip(
                    avatar: Icon(Icons.check, size: 18),
                    label: Text('Your party'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isUpdating
                    ? null
                    : isMember
                        ? onLeave
                        : canJoin
                            ? onJoin
                            : null,
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isMember ? Icons.logout : Icons.login),
                label: Text(isUpdating
                    ? 'Saving...'
                    : isMember
                        ? 'Leave'
                        : 'Join'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElectionCard extends StatelessWidget {
  final PoliticalElection election;
  final PlayerPoliticsStatus? status;
  final bool isSelected;
  final bool isDeclaring;
  final VoidCallback onDetails;
  final VoidCallback? onDeclare;

  const _ElectionCard({
    required this.election,
    required this.status,
    required this.isSelected,
    required this.isDeclaring,
    required this.onDetails,
    required this.onDeclare,
  });

  @override
  Widget build(BuildContext context) {
    final canDeclare = status?.citizenship?.countryId == election.countryId &&
        onDeclare != null;
    final alreadyCandidate = status?.candidacies
            .any((candidacy) => candidacy.electionId == election.electionId) ??
        false;
    return Card(
      elevation: isSelected ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_vote, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    election.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(election.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(election.description),
            const SizedBox(height: 8),
            Text(
              '${election.countryName} • ${election.officeName} • '
              '${election.candidateCount} candidates • ${election.voteCount} votes',
            ),
            Text('Voting closes ${_formatDate(election.votingEndsAt)}.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline),
                  label: Text(isSelected ? 'Refresh details' : 'Details'),
                ),
                ElevatedButton.icon(
                  onPressed: isDeclaring || alreadyCandidate || !canDeclare
                      ? null
                      : onDeclare,
                  icon: isDeclaring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(alreadyCandidate ? Icons.check : Icons.campaign),
                  label: Text(alreadyCandidate
                      ? 'Declared'
                      : isDeclaring
                          ? 'Declaring...'
                          : 'Run'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ElectionDetailsCard extends StatelessWidget {
  final ElectionDetails details;
  final ElectionResults? results;
  final PlayerPoliticsStatus? playerStatus;
  final bool isLoading;
  final Set<String> votingCandidacyIds;
  final Future<void> Function(Candidacy candidacy) onVote;

  const _ElectionDetailsCard({
    required this.details,
    required this.results,
    required this.playerStatus,
    required this.isLoading,
    required this.votingCandidacyIds,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final election = details.election;
    final hasVoted = playerStatus?.hasVoted(election.electionId) ?? false;
    final canVote = election.isVoting &&
        playerStatus?.citizenship?.countryId == election.countryId &&
        !hasVoted;
    final resultByCandidacy = {
      for (final result in (results?.results ?? details.results))
        result.candidacyId: result
    };

    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Election details: ${election.title}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (details.candidacies.isEmpty)
              const Text('No citizens have declared candidacy yet.')
            else
              ...details.candidacies.map((candidacy) {
                final result = resultByCandidacy[candidacy.candidacyId];
                final isVoting =
                    votingCandidacyIds.contains(candidacy.candidacyId);
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text((result?.rank ?? 0).toString()),
                      ),
                      title: Text(candidacy.playerId),
                      subtitle: Text(
                        '${candidacy.partyShortName ?? 'IND'} • '
                        '${candidacy.manifesto}',
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: canVote && !isVoting
                            ? () => onVote(candidacy)
                            : null,
                        icon: isVoting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(hasVoted ? Icons.check : Icons.how_to_vote),
                        label: Text(
                          hasVoted
                              ? '${result?.votes ?? candidacy.voteCount} votes'
                              : isVoting
                                  ? 'Voting...'
                                  : 'Vote',
                        ),
                      ),
                    ),
                    if (candidacy != details.candidacies.last) const Divider(),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _OfficeHoldersCard extends StatelessWidget {
  final OfficeHolderList? holders;
  const _OfficeHoldersCard({required this.holders});

  @override
  Widget build(BuildContext context) {
    final officeHolders = holders?.officeHolders ?? <OfficeTerm>[];
    if (officeHolders.isEmpty) {
      return const _EmptyCard(
        icon: Icons.account_balance_outlined,
        message:
            'No active office holders yet. Resolved elections will appear here.',
      );
    }

    return Card(
      child: Column(
        children: officeHolders
            .map((holder) => ListTile(
                  leading: const Icon(Icons.workspace_premium),
                  title: Text('${holder.officeName}: ${holder.playerId}'),
                  subtitle: Text(
                    '${holder.countryName} • ${holder.partyName ?? 'Independent'} • '
                    'until ${_formatDate(holder.endsAt)}',
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _CreatePartyDialog extends StatefulWidget {
  const _CreatePartyDialog();

  @override
  State<_CreatePartyDialog> createState() => _CreatePartyDialogState();
}

class _CreatePartyDialogState extends State<_CreatePartyDialog> {
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _description = TextEditingController();
  final _ideology = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _description.dispose();
    _ideology.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create political party'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _shortName,
              decoration: const InputDecoration(labelText: 'Short name'),
              maxLength: 8,
            ),
            TextField(
              controller: _ideology,
              decoration: const InputDecoration(labelText: 'Ideology'),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _name.text.trim();
            final shortName = _shortName.text.trim();
            if (name.length < 3 || shortName.length < 2) {
              return;
            }

            Navigator.pop(
              context,
              _PartyFormResult(
                name: name,
                shortName: shortName,
                description: _description.text.trim(),
                ideology: _ideology.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _ManifestoDialog extends StatefulWidget {
  final PoliticalElection election;
  const _ManifestoDialog({required this.election});

  @override
  State<_ManifestoDialog> createState() => _ManifestoDialogState();
}

class _ManifestoDialogState extends State<_ManifestoDialog> {
  final _manifesto = TextEditingController();

  @override
  void dispose() {
    _manifesto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Run for ${widget.election.officeName}'),
      content: TextField(
        controller: _manifesto,
        decoration: const InputDecoration(labelText: 'Manifesto'),
        maxLines: 4,
        maxLength: 800,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _manifesto.text.trim().isEmpty
                ? 'A citizen candidacy focused on country growth.'
                : _manifesto.text.trim(),
          ),
          child: const Text('Declare'),
        ),
      ],
    );
  }
}

class _PartyFormResult {
  final String name;
  final String shortName;
  final String description;
  final String ideology;

  _PartyFormResult({
    required this.name,
    required this.shortName,
    required this.description,
    required this.ideology,
  });
}

class _MessageCard extends StatelessWidget {
  final String message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(message),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(message),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

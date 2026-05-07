import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CongressPage extends StatefulWidget {
  final User user;
  const CongressPage({super.key, required this.user});

  @override
  State<CongressPage> createState() => _CongressPageState();
}

class _CongressPageState extends State<CongressPage> {
  late final CongressBloc _congressBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _congressBloc = Provider.of<CongressBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _congressBloc.setBearerToken(_loginBloc.currentToken);
    await _congressBloc.load(widget.user.uid);
  }

  Future<void> _createProposal() async {
    final countryId = _congressBloc.countryId;
    if (countryId == null) {
      _showMessage('Join a country before opening congress proposals.');
      return;
    }

    final result = await showDialog<_LawProposalFormResult>(
      context: context,
      builder: (context) => const _CreateLawProposalDialog(),
    );
    if (result == null) {
      return;
    }

    _congressBloc.setBearerToken(_loginBloc.currentToken);
    final mutation = await _congressBloc.createProposal(
      playerId: widget.user.uid,
      countryId: countryId,
      proposalType: result.proposalType,
      title: result.title,
      description: result.description,
      incomeTaxRate: result.incomeTaxRate,
      marketTaxRate: result.marketTaxRate,
      productionTaxRate: result.productionTaxRate,
      treasuryAmount: result.treasuryAmount,
      treasuryTargetPlayerId: result.treasuryTargetPlayerId,
      treasuryReason: result.treasuryReason,
      citizenshipRule: result.citizenshipRule,
      votingHours: result.votingHours,
    );
    _showMessage(mutation?.message ?? _congressBloc.error);
  }

  Future<void> _loadProposal(LawProposal proposal) async {
    _congressBloc.setBearerToken(_loginBloc.currentToken);
    await _congressBloc.loadProposal(proposal.proposalId);
  }

  Future<void> _vote(LawProposal proposal, String choice) async {
    _congressBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _congressBloc.vote(
      playerId: widget.user.uid,
      proposalId: proposal.proposalId,
      choice: choice,
    );
    _showMessage(result?.message ?? _congressBloc.error);
  }

  Future<void> _resolve(LawProposal proposal) async {
    _congressBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _congressBloc.resolve(
      playerId: widget.user.uid,
      proposalId: proposal.proposalId,
    );
    _showMessage(result?.message ?? _congressBloc.error);
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
      appBar: AppBar(title: const Text('Congress & Laws')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProposal,
        icon: const Icon(Icons.gavel_outlined),
        label: const Text('Propose law'),
      ),
      body: Consumer<CongressBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.proposals == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.proposals == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final proposals = bloc.proposals?.proposals ?? <LawProposal>[];
          final active = proposals.where((proposal) => proposal.isVoting);
          final history = proposals.where((proposal) => !proposal.isVoting);
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CongressStatusCard(
                  status: bloc.politicsStatus,
                  authorization: bloc.proposals?.authorization,
                  error: bloc.error,
                  isLoading: bloc.isLoading,
                  onCreate: _createProposal,
                ),
                if (bloc.lastProposalMutation != null)
                  _MessageCard(message: bloc.lastProposalMutation!.message),
                const _SectionHeader(
                  title: 'Active proposals',
                  subtitle:
                      'Citizens vote once. Passed tax and treasury proposals execute against persisted country state.',
                ),
                if (active.isEmpty)
                  const _EmptyCard(
                    icon: Icons.how_to_vote_outlined,
                    message: 'No active law proposals are open.',
                  )
                else
                  ...active.map((proposal) => _LawProposalCard(
                        proposal: proposal,
                        authorization: bloc.proposals?.authorization,
                        isSelected:
                            bloc.selectedProposal?.proposal.proposalId ==
                                proposal.proposalId,
                        isVoting: bloc.votingProposalIds
                            .contains(proposal.proposalId),
                        onDetails: () => _loadProposal(proposal),
                        onVote: (choice) => _vote(proposal, choice),
                        onResolve: () => _resolve(proposal),
                      )),
                if (bloc.selectedProposal != null)
                  _LawProposalDetailsCard(
                    details: bloc.selectedProposal!,
                    playerId: widget.user.uid,
                    votingProposalIds: bloc.votingProposalIds,
                    isLoading: bloc.isLoadingProposal,
                    onVote: (choice) =>
                        _vote(bloc.selectedProposal!.proposal, choice),
                    onResolve: () => _resolve(bloc.selectedProposal!.proposal),
                  ),
                const _SectionHeader(
                  title: 'Active laws',
                  subtitle:
                      'Resolved proposals become persisted laws and execution history.',
                ),
                _LawListCard(laws: bloc.activeLaws?.laws ?? <Law>[]),
                const _SectionHeader(
                  title: 'Proposal history',
                  subtitle:
                      'Rejected, passed, and failed executions remain auditable.',
                ),
                if (history.isEmpty)
                  const _EmptyCard(
                    icon: Icons.history_outlined,
                    message: 'No resolved law proposals yet.',
                  )
                else
                  ...history.map((proposal) => _LawProposalCard(
                        proposal: proposal,
                        authorization: bloc.proposals?.authorization,
                        isSelected:
                            bloc.selectedProposal?.proposal.proposalId ==
                                proposal.proposalId,
                        isVoting: false,
                        onDetails: () => _loadProposal(proposal),
                        onVote: null,
                        onResolve: null,
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CongressStatusCard extends StatelessWidget {
  final PlayerPoliticsStatus? status;
  final CongressAuthorization? authorization;
  final String? error;
  final bool isLoading;
  final VoidCallback onCreate;

  const _CongressStatusCard({
    required this.status,
    required this.authorization,
    required this.error,
    required this.isLoading,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final citizenship = status?.citizenship;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    citizenship == null
                        ? 'No active citizenship'
                        : '${citizenship.countryName} Congress',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              authorization?.message ??
                  'Join a country to propose laws and vote in congress.',
            ),
            if (authorization?.role != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(label: Text('Role: ${authorization!.role}')),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  authorization?.canCreateProposal == true ? onCreate : null,
              icon: const Icon(Icons.add),
              label: const Text('Create persisted law proposal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LawProposalCard extends StatelessWidget {
  final LawProposal proposal;
  final CongressAuthorization? authorization;
  final bool isSelected;
  final bool isVoting;
  final VoidCallback onDetails;
  final ValueChanged<String>? onVote;
  final VoidCallback? onResolve;

  const _LawProposalCard({
    required this.proposal,
    required this.authorization,
    required this.isSelected,
    required this.isVoting,
    required this.onDetails,
    required this.onVote,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final canVote = onVote != null &&
        authorization?.canVote == true &&
        proposal.isVoting &&
        !isVoting;
    final canResolve = onResolve != null &&
        authorization?.canResolve == true &&
        proposal.status == 'voting';
    return Card(
      color: isSelected ? Colors.blue.withOpacity(0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    proposal.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(proposal.status)),
              ],
            ),
            Text(
              '${proposal.countryName} • ${proposal.typeLabel} • sponsor ${proposal.sponsorPlayerId}',
            ),
            const SizedBox(height: 8),
            Text(proposal.description),
            const SizedBox(height: 8),
            _VoteMeter(proposal: proposal),
            const SizedBox(height: 8),
            Text('Voting closes ${_formatDate(proposal.votingEndsAt)}.'),
            if (proposal.executionMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Result: ${proposal.executionMessage}'),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Details'),
                ),
                ElevatedButton(
                  onPressed: canVote ? () => onVote!('yes') : null,
                  child: const Text('Yes'),
                ),
                ElevatedButton(
                  onPressed: canVote ? () => onVote!('no') : null,
                  child: const Text('No'),
                ),
                OutlinedButton(
                  onPressed: canVote ? () => onVote!('abstain') : null,
                  child: const Text('Abstain'),
                ),
                OutlinedButton.icon(
                  onPressed: canResolve ? onResolve : null,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Resolve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LawProposalDetailsCard extends StatelessWidget {
  final LawProposalDetails details;
  final String playerId;
  final Set<String> votingProposalIds;
  final bool isLoading;
  final ValueChanged<String> onVote;
  final VoidCallback onResolve;

  const _LawProposalDetailsCard({
    required this.details,
    required this.playerId,
    required this.votingProposalIds,
    required this.isLoading,
    required this.onVote,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final proposal = details.proposal;
    final hasVoted = details.votes.any(
      (vote) => vote.voterPlayerId.toLowerCase() == playerId.toLowerCase(),
    );
    final canVote = proposal.isVoting &&
        details.authorization?.canVote == true &&
        !hasVoted &&
        !votingProposalIds.contains(proposal.proposalId);
    final canResolve = proposal.status == 'voting' &&
        details.authorization?.canResolve == true;
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Proposal details: ${proposal.title}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _ProposalPayload(proposal: proposal),
            const SizedBox(height: 12),
            _VoteMeter(proposal: proposal),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: canVote ? () => onVote('yes') : null,
                  child: const Text('Vote yes'),
                ),
                ElevatedButton(
                  onPressed: canVote ? () => onVote('no') : null,
                  child: const Text('Vote no'),
                ),
                OutlinedButton(
                  onPressed: canVote ? () => onVote('abstain') : null,
                  child: const Text('Abstain'),
                ),
                OutlinedButton.icon(
                  onPressed: canResolve ? onResolve : null,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Resolve proposal'),
                ),
              ],
            ),
            if (hasVoted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('You have already voted on this proposal.'),
              ),
            const Divider(height: 24),
            Text('Recent votes',
                style: Theme.of(context).textTheme.titleMedium),
            if (details.votes.isEmpty)
              const Text('No votes have been cast yet.')
            else
              ...details.votes.take(12).map(
                    (vote) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.how_to_vote_outlined),
                      title: Text('${vote.voterPlayerId}: ${vote.choice}'),
                      subtitle: Text(_formatDate(vote.castAt)),
                    ),
                  ),
            const Divider(height: 24),
            Text('Execution history',
                style: Theme.of(context).textTheme.titleMedium),
            if (details.executions.isEmpty)
              const Text('No execution result recorded yet.')
            else
              ...details.executions.map(
                (execution) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(execution.status == 'executed'
                      ? Icons.check_circle_outline
                      : Icons.info_outline),
                  title: Text('${execution.action}: ${execution.status}'),
                  subtitle: Text(
                    '${execution.message}\n${_formatDate(execution.createdAt)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProposalPayload extends StatelessWidget {
  final LawProposal proposal;
  const _ProposalPayload({required this.proposal});

  @override
  Widget build(BuildContext context) {
    if (proposal.proposalType == 'tax_policy') {
      return Text(
        'Tax policy: income ${proposal.incomeTaxRate}%, market ${proposal.marketTaxRate}%, production ${proposal.productionTaxRate}%.',
      );
    }

    if (proposal.proposalType == 'treasury_grant' ||
        proposal.proposalType == 'treasury_spend') {
      return Text(
        'Treasury spend: ${proposal.treasuryAmount ?? 0} gold'
        '${proposal.treasuryTargetPlayerId == null ? '' : ' to ${proposal.treasuryTargetPlayerId}'}'
        '${proposal.treasuryReason.isEmpty ? '' : ' — ${proposal.treasuryReason}'}',
      );
    }

    if (proposal.proposalType == 'citizenship_rule') {
      return Text('Citizenship rule: ${proposal.citizenshipRule ?? ''}');
    }

    return Text('Law type: ${proposal.typeLabel}');
  }
}

class _VoteMeter extends StatelessWidget {
  final LawProposal proposal;
  const _VoteMeter({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: proposal.decisionVotes == 0 ? 0 : proposal.yesPercent / 100,
          minHeight: 8,
        ),
        const SizedBox(height: 6),
        Text(
          '${proposal.yesVotes} yes • ${proposal.noVotes} no • ${proposal.abstainVotes} abstain '
          '(${proposal.yesPercent}% yes, needs ${proposal.approvalThresholdPercent}%)',
        ),
      ],
    );
  }
}

class _LawListCard extends StatelessWidget {
  final List<Law> laws;
  const _LawListCard({required this.laws});

  @override
  Widget build(BuildContext context) {
    if (laws.isEmpty) {
      return const _EmptyCard(
        icon: Icons.account_balance_outlined,
        message: 'No active laws have been enacted yet.',
      );
    }

    return Card(
      child: Column(
        children: laws
            .map((law) => ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(law.title),
                  subtitle: Text(
                    '${law.countryName} • ${law.proposalType.replaceAll('_', ' ')} • enacted ${_formatDate(law.enactedAt)}',
                  ),
                  trailing: Chip(label: Text(law.status)),
                ))
            .toList(),
      ),
    );
  }
}

class _CreateLawProposalDialog extends StatefulWidget {
  const _CreateLawProposalDialog();

  @override
  State<_CreateLawProposalDialog> createState() =>
      _CreateLawProposalDialogState();
}

class _CreateLawProposalDialogState extends State<_CreateLawProposalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _incomeController = TextEditingController(text: '5');
  final _marketController = TextEditingController(text: '2');
  final _productionController = TextEditingController(text: '1');
  final _amountController = TextEditingController();
  final _targetController = TextEditingController();
  final _reasonController = TextEditingController();
  final _citizenshipRuleController = TextEditingController();
  final _votingHoursController = TextEditingController(text: '48');
  String _proposalType = 'tax_policy';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _incomeController.dispose();
    _marketController.dispose();
    _productionController.dispose();
    _amountController.dispose();
    _targetController.dispose();
    _reasonController.dispose();
    _citizenshipRuleController.dispose();
    _votingHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create law proposal'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _proposalType,
                  decoration: const InputDecoration(labelText: 'Proposal type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'tax_policy',
                      child: Text('Tax policy change'),
                    ),
                    DropdownMenuItem(
                      value: 'treasury_spend',
                      child: Text('Treasury spend'),
                    ),
                    DropdownMenuItem(
                      value: 'treasury_grant',
                      child: Text('Treasury grant'),
                    ),
                    DropdownMenuItem(
                      value: 'citizenship_rule',
                      child: Text('Citizenship rule'),
                    ),
                    DropdownMenuItem(
                      value: 'war_declaration',
                      child: Text('War declaration record'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _proposalType = value);
                    }
                  },
                ),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().length < 3
                      ? 'Title must be at least 3 characters.'
                      : null,
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                if (_proposalType == 'tax_policy') ...[
                  _NumberField(
                    controller: _incomeController,
                    label: 'Income tax %',
                  ),
                  _NumberField(
                    controller: _marketController,
                    label: 'Market tax %',
                  ),
                  _NumberField(
                    controller: _productionController,
                    label: 'Production tax %',
                  ),
                ],
                if (_proposalType == 'treasury_spend' ||
                    _proposalType == 'treasury_grant') ...[
                  _NumberField(
                    controller: _amountController,
                    label: 'Treasury amount',
                    minValue: 1,
                    maxValue: 1000000000,
                  ),
                  TextFormField(
                    controller: _targetController,
                    decoration: const InputDecoration(
                      labelText: 'Target player (optional)',
                    ),
                  ),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
                ],
                if (_proposalType == 'citizenship_rule')
                  TextFormField(
                    controller: _citizenshipRuleController,
                    decoration:
                        const InputDecoration(labelText: 'Citizenship rule'),
                    maxLines: 2,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Citizenship rule is required.'
                        : null,
                  ),
                _NumberField(
                  controller: _votingHoursController,
                  label: 'Voting hours',
                  minValue: 1,
                  maxValue: 168,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _LawProposalFormResult(
        proposalType: _proposalType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        incomeTaxRate:
            _proposalType == 'tax_policy' ? _parseInt(_incomeController) : null,
        marketTaxRate:
            _proposalType == 'tax_policy' ? _parseInt(_marketController) : null,
        productionTaxRate: _proposalType == 'tax_policy'
            ? _parseInt(_productionController)
            : null,
        treasuryAmount: _proposalType == 'treasury_spend' ||
                _proposalType == 'treasury_grant'
            ? _parseInt(_amountController)
            : null,
        treasuryTargetPlayerId: _targetController.text.trim().isEmpty
            ? null
            : _targetController.text.trim(),
        treasuryReason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        citizenshipRule: _citizenshipRuleController.text.trim().isEmpty
            ? null
            : _citizenshipRuleController.text.trim(),
        votingHours: _parseInt(_votingHoursController),
      ),
    );
  }

  int? _parseInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minValue;
  final int maxValue;

  const _NumberField({
    required this.controller,
    required this.label,
    this.minValue = 0,
    this.maxValue = 50,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (value) {
        final parsed = int.tryParse(value?.trim() ?? '');
        if (parsed == null || parsed < minValue || parsed > maxValue) {
          return '$label must be between $minValue and $maxValue.';
        }
        return null;
      },
    );
  }
}

class _LawProposalFormResult {
  final String proposalType;
  final String title;
  final String description;
  final int? incomeTaxRate;
  final int? marketTaxRate;
  final int? productionTaxRate;
  final int? treasuryAmount;
  final String? treasuryTargetPlayerId;
  final String? treasuryReason;
  final String? citizenshipRule;
  final int? votingHours;

  _LawProposalFormResult({
    required this.proposalType,
    required this.title,
    required this.description,
    required this.incomeTaxRate,
    required this.marketTaxRate,
    required this.productionTaxRate,
    required this.treasuryAmount,
    required this.treasuryTargetPlayerId,
    required this.treasuryReason,
    required this.citizenshipRule,
    required this.votingHours,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
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

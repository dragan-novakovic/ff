import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiplomacyPage extends StatefulWidget {
  final User user;
  const DiplomacyPage({super.key, required this.user});

  @override
  State<DiplomacyPage> createState() => _DiplomacyPageState();
}

class _DiplomacyPageState extends State<DiplomacyPage> {
  late final DiplomacyBloc _diplomacyBloc;
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _diplomacyBloc = Provider.of<DiplomacyBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _diplomacyBloc.setBearerToken(_loginBloc.currentToken);
    await _diplomacyBloc.load(widget.user.uid);
  }

  Future<void> _proposeTreaty() async {
    final countryId = _diplomacyBloc.countryId;
    if (countryId == null) {
      _showMessage('Join a country before proposing treaties.');
      return;
    }

    final result = await showDialog<_TreatyFormResult>(
      context: context,
      builder: (context) => const _TreatyProposalDialog(),
    );
    if (result == null) {
      return;
    }

    _diplomacyBloc.setBearerToken(_loginBloc.currentToken);
    final mutation = await _diplomacyBloc.proposeTreaty(
      playerId: widget.user.uid,
      initiatorCountryId: countryId,
      targetCountryId: result.targetCountryId,
      treatyType: result.treatyType,
      title: result.title,
      terms: result.terms,
      durationDays: result.durationDays,
      treasuryAmount: result.treasuryAmount,
      sourceLawId: result.sourceLawId,
    );
    _showMessage(mutation?.message ?? _diplomacyBloc.error);
  }

  Future<void> _ratify(DiplomaticTreaty treaty) async {
    _diplomacyBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _diplomacyBloc.ratifyTreaty(
      playerId: widget.user.uid,
      treatyId: treaty.treatyId,
    );
    _showMessage(result?.message ?? _diplomacyBloc.error);
  }

  Future<void> _reject(DiplomaticTreaty treaty) async {
    final reason = await _reasonDialog(
      title: 'Reject treaty',
      label: 'Reason',
      defaultValue: 'Rejected by target country.',
    );
    if (reason == null) {
      return;
    }

    _diplomacyBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _diplomacyBloc.rejectTreaty(
      playerId: widget.user.uid,
      treatyId: treaty.treatyId,
      reason: reason,
    );
    _showMessage(result?.message ?? _diplomacyBloc.error);
  }

  Future<void> _terminate(DiplomaticTreaty treaty) async {
    final reason = await _reasonDialog(
      title: 'Terminate treaty',
      label: 'Reason',
      defaultValue: 'Terminated by treaty country.',
    );
    if (reason == null) {
      return;
    }

    _diplomacyBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _diplomacyBloc.terminateTreaty(
      playerId: widget.user.uid,
      treatyId: treaty.treatyId,
      reason: reason,
    );
    _showMessage(result?.message ?? _diplomacyBloc.error);
  }

  Future<String?> _reasonDialog({
    required String title,
    required String label,
    required String defaultValue,
  }) async {
    final controller = TextEditingController(text: defaultValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
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
      appBar: AppBar(title: const Text('Diplomacy & Treaties')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _proposeTreaty,
        icon: const Icon(Icons.handshake_outlined),
        label: const Text('Propose'),
      ),
      body: Consumer<DiplomacyBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.status == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.status == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final status = bloc.status;
          final countryId = status?.countryId;
          final active = status?.activeTreaties ?? <DiplomaticTreaty>[];
          final pending = status?.pendingTreaties ?? <DiplomaticTreaty>[];
          final relationships = status?.relationships ?? <DiplomaticRelation>[];
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DiplomacyStatusCard(
                  status: status,
                  error: bloc.error,
                  onPropose: _proposeTreaty,
                ),
                if (bloc.lastMutation != null)
                  _InfoCard(
                    icon: Icons.info_outline,
                    title: 'Latest action',
                    message: bloc.lastMutation!.message,
                  ),
                const _SectionHeader(
                  title: 'Active treaties',
                  subtitle:
                      'Alliances, peace, access, trade agreements, and embargoes are persisted by country.',
                ),
                if (active.isEmpty)
                  const _EmptyCard(
                    icon: Icons.public_off,
                    message: 'No active diplomacy treaties.',
                  )
                else
                  ...active.map((treaty) => _TreatyCard(
                        treaty: treaty,
                        countryId: countryId,
                        isMutating:
                            bloc.mutatingTreatyIds.contains(treaty.treatyId),
                        onRatify: null,
                        onReject: null,
                        onTerminate: status?.authorization.canTerminate == true
                            ? () => _terminate(treaty)
                            : null,
                      )),
                const _SectionHeader(
                  title: 'Pending ratification',
                  subtitle:
                      'Bilateral treaties activate only after the target country ratifies.',
                ),
                if (pending.isEmpty)
                  const _EmptyCard(
                    icon: Icons.hourglass_empty,
                    message: 'No treaty proposals are pending.',
                  )
                else
                  ...pending.map((treaty) {
                    final canRatify = countryId != null &&
                        treaty.isPendingFor(countryId) &&
                        status?.authorization.canRatify == true;
                    return _TreatyCard(
                      treaty: treaty,
                      countryId: countryId,
                      isMutating:
                          bloc.mutatingTreatyIds.contains(treaty.treatyId),
                      onRatify: canRatify ? () => _ratify(treaty) : null,
                      onReject: canRatify ? () => _reject(treaty) : null,
                      onTerminate: status?.authorization.canTerminate == true
                          ? () => _terminate(treaty)
                          : null,
                    );
                  }),
                const _SectionHeader(
                  title: 'Relations',
                  subtitle:
                      'Derived from active treaties and used by war and market checks.',
                ),
                if (relationships.isEmpty)
                  const _EmptyCard(
                    icon: Icons.travel_explore,
                    message: 'No active diplomatic relations.',
                  )
                else
                  ...relationships.map((relation) => _RelationTile(relation)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiplomacyStatusCard extends StatelessWidget {
  final DiplomacyStatus? status;
  final String? error;
  final VoidCallback onPropose;

  const _DiplomacyStatusCard({
    required this.status,
    required this.error,
    required this.onPropose,
  });

  @override
  Widget build(BuildContext context) {
    final citizenship = status?.citizenship;
    final authorization = status?.authorization;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diplomatic office',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(citizenship == null
                ? 'No active citizenship.'
                : '${citizenship.countryName} (${citizenship.countryCode})'),
            if (authorization != null) ...[
              const SizedBox(height: 8),
              Text(authorization.message),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: authorization?.canPropose == true ? onPropose : null,
              icon: const Icon(Icons.add),
              label: const Text('Propose treaty'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreatyCard extends StatelessWidget {
  final DiplomaticTreaty treaty;
  final String? countryId;
  final bool isMutating;
  final VoidCallback? onRatify;
  final VoidCallback? onReject;
  final VoidCallback? onTerminate;

  const _TreatyCard({
    required this.treaty,
    required this.countryId,
    required this.isMutating,
    required this.onRatify,
    required this.onReject,
    required this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    final counterparty = countryId == null
        ? treaty.targetCountryName
        : treaty.counterpartyName(countryId!);
    final expires = treaty.expiresAt == null
        ? 'No expiry set'
        : 'Expires ${MaterialLocalizations.of(context).formatShortDate(treaty.expiresAt!.toLocal())}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(treaty.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: Text(treaty.status)),
              ],
            ),
            Text('${treaty.displayType} with $counterparty'),
            const SizedBox(height: 8),
            Text(treaty.terms),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(expires)),
                if (treaty.treasuryAmount > 0)
                  Chip(label: Text('${treaty.treasuryAmount} gold transfer')),
                if (treaty.sourceLawId != null)
                  Chip(label: Text('Law: ${treaty.sourceLawId}')),
              ],
            ),
            if (isMutating) const LinearProgressIndicator(),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                if (onRatify != null)
                  TextButton(
                      onPressed: isMutating ? null : onRatify,
                      child: const Text('Ratify')),
                if (onReject != null)
                  TextButton(
                      onPressed: isMutating ? null : onReject,
                      child: const Text('Reject')),
                if (onTerminate != null)
                  TextButton(
                      onPressed: isMutating ? null : onTerminate,
                      child: const Text('Terminate')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationTile extends StatelessWidget {
  final DiplomaticRelation relation;
  const _RelationTile(this.relation);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.public),
        title: Text(
            '${relation.displayType}: ${relation.counterpartyCountryName} (${relation.counterpartyCountryCode})'),
        subtitle: Text('Direction: ${relation.direction}'),
      ),
    );
  }
}

class _TreatyProposalDialog extends StatefulWidget {
  const _TreatyProposalDialog();

  @override
  State<_TreatyProposalDialog> createState() => _TreatyProposalDialogState();
}

class _TreatyProposalDialogState extends State<_TreatyProposalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _titleController = TextEditingController();
  final _termsController = TextEditingController();
  final _durationController = TextEditingController(text: '90');
  final _treasuryController = TextEditingController(text: '0');
  final _lawController = TextEditingController();
  String _treatyType = 'alliance';

  @override
  void dispose() {
    _targetController.dispose();
    _titleController.dispose();
    _termsController.dispose();
    _durationController.dispose();
    _treasuryController.dispose();
    _lawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Propose treaty'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _treatyType,
                decoration: const InputDecoration(labelText: 'Treaty type'),
                items: const [
                  DropdownMenuItem(value: 'alliance', child: Text('Alliance')),
                  DropdownMenuItem(value: 'embargo', child: Text('Embargo')),
                  DropdownMenuItem(value: 'peace', child: Text('Peace')),
                  DropdownMenuItem(
                      value: 'military_access', child: Text('Military access')),
                  DropdownMenuItem(
                      value: 'trade_agreement', child: Text('Trade agreement')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _treatyType = value);
                  }
                },
              ),
              TextFormField(
                controller: _targetController,
                decoration: const InputDecoration(
                  labelText: 'Target country id',
                  hintText: 'freiland, nordheim, solara',
                ),
                validator: _required,
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                maxLength: 120,
                validator: _required,
              ),
              TextFormField(
                controller: _termsController,
                decoration: const InputDecoration(labelText: 'Terms'),
                maxLength: 2000,
                maxLines: 3,
                validator: _required,
              ),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration days'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _treasuryController,
                decoration: const InputDecoration(
                    labelText: 'Treasury transfer gold (optional)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _lawController,
                decoration: const InputDecoration(
                    labelText: 'Source law id (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Propose'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _TreatyFormResult(
        targetCountryId: _targetController.text.trim(),
        treatyType: _treatyType,
        title: _titleController.text.trim(),
        terms: _termsController.text.trim(),
        durationDays: int.tryParse(_durationController.text.trim()) ?? 90,
        treasuryAmount: int.tryParse(_treasuryController.text.trim()) ?? 0,
        sourceLawId: _lawController.text.trim().isEmpty
            ? null
            : _lawController.text.trim(),
      ),
    );
  }
}

class _TreatyFormResult {
  final String targetCountryId;
  final String treatyType;
  final String title;
  final String terms;
  final int durationDays;
  final int treasuryAmount;
  final String? sourceLawId;

  _TreatyFormResult({
    required this.targetCountryId,
    required this.treatyType,
    required this.title,
    required this.terms,
    required this.durationDays,
    required this.treasuryAmount,
    required this.sourceLawId,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
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
        padding: const EdgeInsets.all(20),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(message),
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
            const SizedBox(height: 12),
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

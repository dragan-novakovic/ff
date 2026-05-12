import 'dart:math';

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MilitaryUnitsPage extends StatefulWidget {
  final User user;
  const MilitaryUnitsPage({super.key, required this.user});

  @override
  State<MilitaryUnitsPage> createState() => _MilitaryUnitsPageState();
}

class _MilitaryUnitsPageState extends State<MilitaryUnitsPage> {
  late final MilitaryUnitsBloc _unitsBloc;
  late final LoginBloc _loginBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;
  final Random _random = Random();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _orderTitleController = TextEditingController();
  final TextEditingController _orderDescriptionController =
      TextEditingController();
  final TextEditingController _targetBattleController = TextEditingController();
  final TextEditingController _divisionCampaignController =
      TextEditingController();
  final TextEditingController _divisionNameController = TextEditingController();
  final TextEditingController _divisionMemberCountController =
      TextEditingController(text: '5');
  final TextEditingController _divisionStrengthController =
      TextEditingController(text: '100');
  final TextEditingController _deploymentCampaignController =
      TextEditingController();
  final TextEditingController _deploymentDivisionController =
      TextEditingController();
  final TextEditingController _deploymentTargetBattleController =
      TextEditingController();
  final TextEditingController _deploymentTitleController =
      TextEditingController();
  final TextEditingController _deploymentDescriptionController =
      TextEditingController();
  final TextEditingController _deploymentTroopsController =
      TextEditingController(text: '10');
  String _orderType = 'general';
  String _divisionRole = 'infantry';
  String _deploymentOrderType = 'assault';

  @override
  void initState() {
    super.initState();
    _unitsBloc = Provider.of<MilitaryUnitsBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderTitleController.dispose();
    _orderDescriptionController.dispose();
    _targetBattleController.dispose();
    _divisionCampaignController.dispose();
    _divisionNameController.dispose();
    _divisionMemberCountController.dispose();
    _divisionStrengthController.dispose();
    _deploymentCampaignController.dispose();
    _deploymentDivisionController.dispose();
    _deploymentTargetBattleController.dispose();
    _deploymentTitleController.dispose();
    _deploymentDescriptionController.dispose();
    _deploymentTroopsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _unitsBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _showDetails(MilitaryUnit unit) async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    await _unitsBloc.loadDetails(
      playerId: widget.user.uid,
      unitId: unit.unitId,
    );
  }

  Future<void> _createUnit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Unit name is required.');
      return;
    }

    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.create(
      playerId: widget.user.uid,
      name: name,
      description: _descriptionController.text.trim(),
      idempotencyKey: _idempotencyKey(),
    );
    if (result?.completed == true) {
      _nameController.clear();
      _descriptionController.clear();
      await _onboardingBloc.load(widget.user.uid);
    }
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _joinUnit(MilitaryUnit unit) async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.join(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      idempotencyKey: _idempotencyKey(),
    );
    if (result?.completed == true) {
      await _onboardingBloc.load(widget.user.uid);
    }
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _leaveUnit(MilitaryUnit unit) async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.leave(
      playerId: widget.user.uid,
      unitId: unit.unitId,
    );
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _issueOrder(MilitaryUnit unit) async {
    final title = _orderTitleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Order title is required.');
      return;
    }

    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.issueOrder(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      title: title,
      description: _orderDescriptionController.text.trim(),
      orderType: _orderType,
      targetBattleId: _targetBattleController.text.trim().isEmpty
          ? null
          : _targetBattleController.text.trim(),
      idempotencyKey: _idempotencyKey(),
    );
    if (result?.completed == true) {
      _orderTitleController.clear();
      _orderDescriptionController.clear();
      _targetBattleController.clear();
    }
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _completeOrder(MilitaryUnit unit, UnitOrder order) async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.completeOrder(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      orderId: order.orderId,
    );
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _cancelOrder(MilitaryUnit unit, UnitOrder order) async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.cancelOrder(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      orderId: order.orderId,
    );
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _createDivision(MilitaryUnit unit) async {
    final campaignId = _divisionCampaignController.text.trim();
    final name = _divisionNameController.text.trim();
    if (campaignId.isEmpty || name.isEmpty) {
      _showMessage('Campaign id and division name are required.');
      return;
    }

    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.createDivision(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      campaignId: campaignId,
      name: name,
      divisionRole: _divisionRole,
      memberCount: int.tryParse(_divisionMemberCountController.text) ?? 1,
      assignedStrength: int.tryParse(_divisionStrengthController.text) ?? 1,
      idempotencyKey: _idempotencyKey(),
    );
    if (result?.completed == true) {
      _divisionNameController.clear();
    }
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _issueDeploymentOrder(MilitaryUnit unit) async {
    final title = _deploymentTitleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Deployment title is required.');
      return;
    }

    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.issueDeploymentOrder(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      campaignId: _emptyToNull(_deploymentCampaignController.text),
      divisionId: _emptyToNull(_deploymentDivisionController.text),
      targetBattleId: _emptyToNull(_deploymentTargetBattleController.text),
      orderType: _deploymentOrderType,
      title: title,
      description: _deploymentDescriptionController.text.trim(),
      troopCommitment: int.tryParse(_deploymentTroopsController.text) ?? 1,
      idempotencyKey: _idempotencyKey(),
    );
    if (result?.completed == true) {
      _deploymentTitleController.clear();
      _deploymentDescriptionController.clear();
    }
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _executeDeploymentOrder(
      MilitaryUnit unit, DeploymentOrder order) async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.executeDeploymentOrder(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      orderId: order.deploymentOrderId,
    );
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  Future<void> _cancelDeploymentOrder(
      MilitaryUnit unit, DeploymentOrder order) async {
    _unitsBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _unitsBloc.cancelDeploymentOrder(
      playerId: widget.user.uid,
      unitId: unit.unitId,
      orderId: order.deploymentOrderId,
    );
    _showMessage(result?.message ?? _unitsBloc.error);
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _idempotencyKey() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}';
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
    return GameScaffold(
      title: 'Unit HQ',
      subtitle: 'Crews, orders, divisions, deployments, and damage totals',
      icon: Icons.groups_2,
      body: Consumer<MilitaryUnitsBloc>(
        builder: (context, bloc, _) {
          final unitList = bloc.units;
          if (bloc.isLoading && unitList == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && unitList == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OnboardingGuidanceCard(
                  questline: context.watch<OnboardingQuestlineBloc>().questline,
                  route: '/military-units',
                ),
                _UnitHero(
                  error: bloc.error,
                  myUnits: unitList?.myUnits.length ?? 0,
                  totalUnits: unitList?.units.length ?? 0,
                  leaderboardRows: bloc.leaderboard?.entries.length ?? 0,
                ),
                _CreateUnitCard(
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  isCreating: bloc.isCreating,
                  onCreate: _createUnit,
                ),
                if (bloc.lastMutation != null)
                  _MutationCard(
                    completed: bloc.lastMutation!.completed,
                    message: bloc.lastMutation!.message,
                  ),
                if (bloc.lastOrderMutation != null)
                  _MutationCard(
                    completed: bloc.lastOrderMutation!.completed,
                    message: bloc.lastOrderMutation!.message,
                  ),
                if (bloc.lastDivisionMutation != null)
                  _MutationCard(
                    completed: bloc.lastDivisionMutation!.completed,
                    message: bloc.lastDivisionMutation!.message,
                  ),
                if (bloc.lastDeploymentOrderMutation != null)
                  _MutationCard(
                    completed: bloc.lastDeploymentOrderMutation!.completed,
                    message: bloc.lastDeploymentOrderMutation!.message,
                  ),
                _SectionHeader(
                  title: 'My unit',
                  subtitle:
                      'Membership and roles are persisted by the world service.',
                ),
                if ((unitList?.myUnits ?? []).isEmpty)
                  const _EmptyCard(
                    icon: Icons.group_off,
                    message:
                        'You are not in a military unit. Create or join one below.',
                  )
                else
                  ...(unitList?.myUnits ?? []).map(
                    (unit) => _UnitCard(
                      unit: unit,
                      isSelected:
                          bloc.selectedDetails?.unit.unitId == unit.unitId,
                      isJoining: bloc.joiningUnitIds.contains(unit.unitId),
                      isLeaving: bloc.leavingUnitIds.contains(unit.unitId),
                      onDetails: () => _showDetails(unit),
                      onJoin: null,
                      onLeave: () => _leaveUnit(unit),
                    ),
                  ),
                _SectionHeader(
                  title: 'Browse units',
                  subtitle:
                      'Join a unit in your citizen country to add battle damage to its totals.',
                ),
                if ((unitList?.units ?? []).isEmpty)
                  const _EmptyCard(
                    icon: Icons.shield_outlined,
                    message: 'No military units have been created yet.',
                  )
                else
                  ...(unitList?.units ?? []).map(
                    (unit) => _UnitCard(
                      unit: unit,
                      isSelected:
                          bloc.selectedDetails?.unit.unitId == unit.unitId,
                      isJoining: bloc.joiningUnitIds.contains(unit.unitId),
                      isLeaving: bloc.leavingUnitIds.contains(unit.unitId),
                      onDetails: () => _showDetails(unit),
                      onJoin: unit.isMember ? null : () => _joinUnit(unit),
                      onLeave: unit.isMember ? () => _leaveUnit(unit) : null,
                    ),
                  ),
                if (bloc.selectedDetails != null)
                  _UnitDetailsCard(
                    details: bloc.selectedDetails!,
                    contributions: bloc.selectedContributions,
                    isLoading: bloc.isLoadingDetails,
                    isOrdering: bloc.orderingUnitIds
                        .contains(bloc.selectedDetails!.unit.unitId),
                    isCreatingDivision: bloc.creatingDivisionUnitIds
                        .contains(bloc.selectedDetails!.unit.unitId),
                    isIssuingDeployment: bloc.deploymentOrderingUnitIds
                        .contains(bloc.selectedDetails!.unit.unitId),
                    updatingOrderIds: bloc.updatingOrderIds,
                    updatingDeploymentOrderIds: bloc.updatingDeploymentOrderIds,
                    orderTitleController: _orderTitleController,
                    orderDescriptionController: _orderDescriptionController,
                    targetBattleController: _targetBattleController,
                    divisionCampaignController: _divisionCampaignController,
                    divisionNameController: _divisionNameController,
                    divisionMemberCountController:
                        _divisionMemberCountController,
                    divisionStrengthController: _divisionStrengthController,
                    deploymentCampaignController: _deploymentCampaignController,
                    deploymentDivisionController: _deploymentDivisionController,
                    deploymentTargetBattleController:
                        _deploymentTargetBattleController,
                    deploymentTitleController: _deploymentTitleController,
                    deploymentDescriptionController:
                        _deploymentDescriptionController,
                    deploymentTroopsController: _deploymentTroopsController,
                    orderType: _orderType,
                    divisionRole: _divisionRole,
                    deploymentOrderType: _deploymentOrderType,
                    onOrderTypeChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _orderType = value);
                    },
                    onDivisionRoleChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _divisionRole = value);
                    },
                    onDeploymentOrderTypeChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _deploymentOrderType = value);
                    },
                    onIssueOrder: () => _issueOrder(bloc.selectedDetails!.unit),
                    onCompleteOrder: (order) =>
                        _completeOrder(bloc.selectedDetails!.unit, order),
                    onCancelOrder: (order) =>
                        _cancelOrder(bloc.selectedDetails!.unit, order),
                    onCreateDivision: () =>
                        _createDivision(bloc.selectedDetails!.unit),
                    onIssueDeploymentOrder: () =>
                        _issueDeploymentOrder(bloc.selectedDetails!.unit),
                    onExecuteDeploymentOrder: (order) =>
                        _executeDeploymentOrder(
                            bloc.selectedDetails!.unit, order),
                    onCancelDeploymentOrder: (order) => _cancelDeploymentOrder(
                        bloc.selectedDetails!.unit, order),
                  ),
                _SectionHeader(
                  title: 'Unit battle leaderboard',
                  subtitle:
                      'Damage totals update automatically when members contribute to battles.',
                ),
                _LeaderboardCard(leaderboard: bloc.leaderboard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UnitHero extends StatelessWidget {
  final String? error;
  final int myUnits;
  final int totalUnits;
  final int leaderboardRows;

  const _UnitHero({
    required this.error,
    required this.myUnits,
    required this.totalUnits,
    required this.leaderboardRows,
  });

  @override
  Widget build(BuildContext context) {
    return GameHero(
      eyebrow: error == null ? 'Crew Command' : 'Unit Alert',
      title: 'Military units and crews',
      subtitle: error ??
          'Create or join persisted units, publish officer orders, form campaign divisions, issue deployments, and feed unit battle leaderboards.',
      icon: error == null ? Icons.military_tech : Icons.warning_amber,
      accent: error == null ? GameColors.violet : GameColors.amber,
      stats: [
        GameStat(
          label: 'my units',
          value: myUnits.toString(),
          icon: Icons.verified_user,
          color: GameColors.emerald,
        ),
        GameStat(
          label: 'open crews',
          value: totalUnits.toString(),
          icon: Icons.groups_2,
          color: GameColors.violet,
        ),
        GameStat(
          label: 'damage rows',
          value: leaderboardRows.toString(),
          icon: Icons.leaderboard,
          color: GameColors.cyan,
        ),
      ],
    );
  }
}

class _CreateUnitCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool isCreating;
  final VoidCallback onCreate;

  const _CreateUnitCard({
    required this.nameController,
    required this.descriptionController,
    required this.isCreating,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create unit', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Unit name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isCreating ? null : onCreate,
              icon: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(isCreating ? 'Creating...' : 'Create unit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final MilitaryUnit unit;
  final bool isSelected;
  final bool isJoining;
  final bool isLeaving;
  final VoidCallback onDetails;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;

  const _UnitCard({
    required this.unit,
    required this.isSelected,
    required this.isJoining,
    required this.isLeaving,
    required this.onDetails,
    required this.onJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(unit.isMember ? Icons.verified_user : Icons.shield),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unit.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(unit.countryCode)),
              ],
            ),
            const SizedBox(height: 8),
            Text(unit.description.isEmpty
                ? 'No unit description has been posted.'
                : unit.description),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${unit.memberCount} members')),
                Chip(
                  label: Text(
                    '${Utils.number(unit.totalBattleDamage)} battle damage',
                  ),
                ),
                if (unit.viewerRole != null)
                  Chip(label: Text('Role: ${unit.viewerRole}')),
                if (unit.activeOrderCount > 0)
                  Chip(label: Text('${unit.activeOrderCount} active orders')),
              ],
            ),
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
                if (onJoin != null)
                  ElevatedButton.icon(
                    onPressed: isJoining ? null : onJoin,
                    icon: isJoining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(isJoining ? 'Joining...' : 'Join'),
                  ),
                if (onLeave != null)
                  OutlinedButton.icon(
                    onPressed: isLeaving ? null : onLeave,
                    icon: isLeaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: Text(isLeaving ? 'Leaving...' : 'Leave'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitDetailsCard extends StatelessWidget {
  final MilitaryUnitDetails details;
  final UnitBattleContributions? contributions;
  final bool isLoading;
  final bool isOrdering;
  final bool isCreatingDivision;
  final bool isIssuingDeployment;
  final Set<String> updatingOrderIds;
  final Set<String> updatingDeploymentOrderIds;
  final TextEditingController orderTitleController;
  final TextEditingController orderDescriptionController;
  final TextEditingController targetBattleController;
  final TextEditingController divisionCampaignController;
  final TextEditingController divisionNameController;
  final TextEditingController divisionMemberCountController;
  final TextEditingController divisionStrengthController;
  final TextEditingController deploymentCampaignController;
  final TextEditingController deploymentDivisionController;
  final TextEditingController deploymentTargetBattleController;
  final TextEditingController deploymentTitleController;
  final TextEditingController deploymentDescriptionController;
  final TextEditingController deploymentTroopsController;
  final String orderType;
  final String divisionRole;
  final String deploymentOrderType;
  final ValueChanged<String?> onOrderTypeChanged;
  final ValueChanged<String?> onDivisionRoleChanged;
  final ValueChanged<String?> onDeploymentOrderTypeChanged;
  final VoidCallback onIssueOrder;
  final ValueChanged<UnitOrder> onCompleteOrder;
  final ValueChanged<UnitOrder> onCancelOrder;
  final VoidCallback onCreateDivision;
  final VoidCallback onIssueDeploymentOrder;
  final ValueChanged<DeploymentOrder> onExecuteDeploymentOrder;
  final ValueChanged<DeploymentOrder> onCancelDeploymentOrder;

  const _UnitDetailsCard({
    required this.details,
    required this.contributions,
    required this.isLoading,
    required this.isOrdering,
    required this.isCreatingDivision,
    required this.isIssuingDeployment,
    required this.updatingOrderIds,
    required this.updatingDeploymentOrderIds,
    required this.orderTitleController,
    required this.orderDescriptionController,
    required this.targetBattleController,
    required this.divisionCampaignController,
    required this.divisionNameController,
    required this.divisionMemberCountController,
    required this.divisionStrengthController,
    required this.deploymentCampaignController,
    required this.deploymentDivisionController,
    required this.deploymentTargetBattleController,
    required this.deploymentTitleController,
    required this.deploymentDescriptionController,
    required this.deploymentTroopsController,
    required this.orderType,
    required this.divisionRole,
    required this.deploymentOrderType,
    required this.onOrderTypeChanged,
    required this.onDivisionRoleChanged,
    required this.onDeploymentOrderTypeChanged,
    required this.onIssueOrder,
    required this.onCompleteOrder,
    required this.onCancelOrder,
    required this.onCreateDivision,
    required this.onIssueDeploymentOrder,
    required this.onExecuteDeploymentOrder,
    required this.onCancelDeploymentOrder,
  });

  @override
  Widget build(BuildContext context) {
    final unit = details.unit;
    return Card(
      color: GameColors.panelAlt.withOpacity(0.84),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Unit detail: ${unit.name}',
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
            Text('Country: ${unit.countryName} • Status: ${unit.status}'),
            Text(
              'Total battle damage: ${Utils.number(unit.totalBattleDamage)}',
            ),
            const SizedBox(height: 16),
            Text('Members', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (details.members.isEmpty)
              const Text('No members are recorded.')
            else
              ...details.members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(member.role == 'commander'
                      ? Icons.military_tech
                      : Icons.person),
                  title: Text(member.playerId),
                  subtitle: Text(
                    '${member.role} • ${member.isActive ? 'active' : 'left'}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Orders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (unit.canManageOrders)
              _OrderForm(
                titleController: orderTitleController,
                descriptionController: orderDescriptionController,
                targetBattleController: targetBattleController,
                orderType: orderType,
                isOrdering: isOrdering,
                onOrderTypeChanged: onOrderTypeChanged,
                onIssueOrder: onIssueOrder,
              ),
            if (details.orders.isEmpty)
              const Text('No orders have been issued.')
            else
              ...details.orders.map(
                (order) => _OrderTile(
                  order: order,
                  canManage: unit.canManageOrders,
                  isUpdating: updatingOrderIds.contains(order.orderId),
                  onComplete: () => onCompleteOrder(order),
                  onCancel: () => onCancelOrder(order),
                ),
              ),
            const SizedBox(height: 16),
            Text('Campaign divisions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (unit.canManageOrders)
              _DivisionForm(
                campaignController: divisionCampaignController,
                nameController: divisionNameController,
                memberCountController: divisionMemberCountController,
                strengthController: divisionStrengthController,
                divisionRole: divisionRole,
                isCreating: isCreatingDivision,
                onDivisionRoleChanged: onDivisionRoleChanged,
                onCreate: onCreateDivision,
              ),
            if (details.divisions.isEmpty)
              const Text('No campaign divisions have been formed yet.')
            else
              ...details.divisions.map((division) => _DivisionTile(division)),
            const SizedBox(height: 16),
            Text('Deployment orders',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (unit.canManageOrders)
              _DeploymentOrderForm(
                campaignController: deploymentCampaignController,
                divisionController: deploymentDivisionController,
                targetBattleController: deploymentTargetBattleController,
                titleController: deploymentTitleController,
                descriptionController: deploymentDescriptionController,
                troopController: deploymentTroopsController,
                orderType: deploymentOrderType,
                isIssuing: isIssuingDeployment,
                onOrderTypeChanged: onDeploymentOrderTypeChanged,
                onIssue: onIssueDeploymentOrder,
              ),
            if (details.deploymentOrders.isEmpty)
              const Text('No deployment orders have been issued yet.')
            else
              ...details.deploymentOrders.map(
                (order) => _DeploymentOrderTile(
                  order: order,
                  canManage: unit.canManageOrders,
                  isUpdating: updatingDeploymentOrderIds
                      .contains(order.deploymentOrderId),
                  onExecute: () => onExecuteDeploymentOrder(order),
                  onCancel: () => onCancelDeploymentOrder(order),
                ),
              ),
            const SizedBox(height: 16),
            Text('Battle totals',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (details.battleTotals.isEmpty)
              const Text('This unit has no battle totals yet.')
            else
              ...details.battleTotals.map((total) => _BattleTotalTile(total)),
            const SizedBox(height: 16),
            Text('Recent unit contributions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if ((contributions?.contributions ?? []).isEmpty)
              const Text('No member battle contributions are recorded yet.')
            else
              ...(contributions?.contributions ?? [])
                  .map((contribution) => _ContributionTile(contribution)),
          ],
        ),
      ),
    );
  }
}

class _OrderForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController targetBattleController;
  final String orderType;
  final bool isOrdering;
  final ValueChanged<String?> onOrderTypeChanged;
  final VoidCallback onIssueOrder;

  const _OrderForm({
    required this.titleController,
    required this.descriptionController,
    required this.targetBattleController,
    required this.orderType,
    required this.isOrdering,
    required this.onOrderTypeChanged,
    required this.onIssueOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: orderType,
            decoration: const InputDecoration(
              labelText: 'Order type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('General')),
              DropdownMenuItem(value: 'attack', child: Text('Attack')),
              DropdownMenuItem(value: 'defend', child: Text('Defend')),
              DropdownMenuItem(value: 'rally', child: Text('Rally')),
            ],
            onChanged: onOrderTypeChanged,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Order title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Order description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: targetBattleController,
            decoration: const InputDecoration(
              labelText: 'Target battle id (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: isOrdering ? null : onIssueOrder,
              icon: isOrdering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.assignment),
              label: Text(isOrdering ? 'Issuing...' : 'Issue order'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final UnitOrder order;
  final bool canManage;
  final bool isUpdating;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _OrderTile({
    required this.order,
    required this.canManage,
    required this.isUpdating,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          Icon(order.isActive ? Icons.assignment : Icons.assignment_turned_in),
      title: Text(order.title),
      subtitle: Text(
        '${order.orderType} • ${order.status}'
        '${order.targetBattleId == null ? '' : ' • target ${order.targetBattleId}'}\n'
        '${order.description}',
      ),
      isThreeLine: order.description.isNotEmpty,
      trailing: canManage && order.isActive
          ? Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Complete',
                  onPressed: isUpdating ? null : onComplete,
                  icon: const Icon(Icons.check),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: isUpdating ? null : onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : null,
    );
  }
}

class _DivisionForm extends StatelessWidget {
  final TextEditingController campaignController;
  final TextEditingController nameController;
  final TextEditingController memberCountController;
  final TextEditingController strengthController;
  final String divisionRole;
  final bool isCreating;
  final ValueChanged<String?> onDivisionRoleChanged;
  final VoidCallback onCreate;

  const _DivisionForm({
    required this.campaignController,
    required this.nameController,
    required this.memberCountController,
    required this.strengthController,
    required this.divisionRole,
    required this.isCreating,
    required this.onDivisionRoleChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          TextField(
            controller: campaignController,
            decoration: const InputDecoration(
              labelText: 'Campaign id',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Division name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: divisionRole,
            decoration: const InputDecoration(
              labelText: 'Division role',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'infantry', child: Text('Infantry')),
              DropdownMenuItem(value: 'armor', child: Text('Armor')),
              DropdownMenuItem(value: 'support', child: Text('Support')),
              DropdownMenuItem(value: 'recon', child: Text('Recon')),
            ],
            onChanged: onDivisionRoleChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: memberCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Members',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: strengthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Strength',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: isCreating ? null : onCreate,
              icon: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.groups_2),
              label: Text(isCreating ? 'Creating...' : 'Create division'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DivisionTile extends StatelessWidget {
  final UnitDivision division;
  const _DivisionTile(this.division);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.groups_2),
      title: Text(division.name),
      subtitle: Text(
        '${division.campaignName} • ${division.divisionRole} • '
        '${division.status}\n'
        '${division.memberCount} members • '
        '${Utils.number(division.assignedStrength)} strength',
      ),
      isThreeLine: true,
      trailing: Text(division.isDeployed ? 'Deployed' : 'Ready'),
    );
  }
}

class _DeploymentOrderForm extends StatelessWidget {
  final TextEditingController campaignController;
  final TextEditingController divisionController;
  final TextEditingController targetBattleController;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController troopController;
  final String orderType;
  final bool isIssuing;
  final ValueChanged<String?> onOrderTypeChanged;
  final VoidCallback onIssue;

  const _DeploymentOrderForm({
    required this.campaignController,
    required this.divisionController,
    required this.targetBattleController,
    required this.titleController,
    required this.descriptionController,
    required this.troopController,
    required this.orderType,
    required this.isIssuing,
    required this.onOrderTypeChanged,
    required this.onIssue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: orderType,
            decoration: const InputDecoration(
              labelText: 'Deployment type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'assault', child: Text('Assault')),
              DropdownMenuItem(value: 'defense', child: Text('Defense')),
              DropdownMenuItem(value: 'reserve', child: Text('Reserve')),
              DropdownMenuItem(value: 'redeploy', child: Text('Redeploy')),
            ],
            onChanged: onOrderTypeChanged,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Deployment title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Deployment description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: campaignController,
            decoration: const InputDecoration(
              labelText: 'Campaign id (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: divisionController,
            decoration: const InputDecoration(
              labelText: 'Division id (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: targetBattleController,
            decoration: const InputDecoration(
              labelText: 'Target battle id (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: troopController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Troop commitment',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: isIssuing ? null : onIssue,
              icon: isIssuing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(isIssuing ? 'Issuing...' : 'Issue deployment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeploymentOrderTile extends StatelessWidget {
  final DeploymentOrder order;
  final bool canManage;
  final bool isUpdating;
  final VoidCallback onExecute;
  final VoidCallback onCancel;

  const _DeploymentOrderTile({
    required this.order,
    required this.canManage,
    required this.isUpdating,
    required this.onExecute,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(order.isIssued ? Icons.send : Icons.done_all),
      title: Text(order.title),
      subtitle: Text(
        '${order.orderType} • ${order.status} • '
        '${order.troopCommitment} troops\n'
        '${order.campaignId == null ? '' : 'campaign ${order.campaignId} • '}'
        '${order.targetBattleId == null ? '' : 'target ${order.targetBattleId} • '}'
        '${order.description}',
      ),
      isThreeLine: true,
      trailing: canManage && order.isIssued
          ? Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Execute',
                  onPressed: isUpdating ? null : onExecute,
                  icon: const Icon(Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: isUpdating ? null : onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : null,
    );
  }
}

class _BattleTotalTile extends StatelessWidget {
  final UnitBattleTotal total;
  const _BattleTotalTile(this.total);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.local_fire_department),
      title: Text(
          '${total.battleName} • ${Utils.number(total.totalDamage)} damage'),
      subtitle: Text(
        '${total.countryCode} ${total.side} • ${total.contributionCount} attacks • ${total.memberCount} contributors',
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  final UnitBattleContribution contribution;
  const _ContributionTile(this.contribution);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.flash_on),
      title: Text(
        '${contribution.playerId} dealt ${Utils.number(contribution.damage)} damage',
      ),
      subtitle: Text(
        '${contribution.battleName} • ${contribution.energySpent} energy • ${contribution.countryCode}',
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final MilitaryUnitLeaderboard? leaderboard;
  const _LeaderboardCard({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    final entries = leaderboard?.entries ?? [];
    if (entries.isEmpty) {
      return const _EmptyCard(
        icon: Icons.leaderboard,
        message: 'No unit battle leaderboard entries yet.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: entries
              .map(
                (entry) => ListTile(
                  leading: const Icon(Icons.leaderboard),
                  title: Text(entry.unitName),
                  subtitle: Text(
                    '${entry.battleName} • ${entry.countryCode} • ${entry.contributionCount} attacks',
                  ),
                  trailing: Text(Utils.number(entry.totalDamage)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MutationCard extends StatelessWidget {
  final bool completed;
  final String message;
  const _MutationCard({required this.completed, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: completed
          ? GameColors.emerald.withOpacity(0.12)
          : GameColors.amber.withOpacity(0.12),
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : Icons.info_outline,
          color: completed ? Colors.green : Colors.orange,
        ),
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
      child: GameSectionTitle(title: title, subtitle: subtitle),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return GameEmptyState(
      icon: icon,
      message: message,
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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

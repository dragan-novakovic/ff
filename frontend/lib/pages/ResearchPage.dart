import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ResearchPage extends StatefulWidget {
  final User user;

  const ResearchPage({super.key, required this.user});

  @override
  State<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends State<ResearchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final login = context.read<LoginBloc>();
    final bloc = context.read<ResearchBloc>();
    bloc.setBearerToken(login.currentToken);
    await bloc.load(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Research'),
        actions: [
          IconButton(
            tooltip: 'Refresh research',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Consumer<ResearchBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.dashboard == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final dashboard = bloc.dashboard;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (bloc.error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        bloc.error!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ),
                if (bloc.lastMutation != null)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(bloc.lastMutation!.message),
                    ),
                  ),
                if (dashboard == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Research data is not loaded yet.'),
                    ),
                  )
                else ...[
                  _countrySection(context, bloc, dashboard),
                  const SizedBox(height: 16),
                  _companySection(context, bloc, dashboard),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _countrySection(
    BuildContext context,
    ResearchBloc bloc,
    ResearchDashboard dashboard,
  ) {
    final citizenship = dashboard.citizenship;
    final state = dashboard.country;
    if (citizenship == null || state == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Join a country to participate in national research.'),
        ),
      );
    }

    return _scopeCard(
      context: context,
      bloc: bloc,
      title: '${citizenship.countryName} research',
      subtitle: 'Country technologies and policy bonuses',
      state: state,
      canManage: true,
      permissionHint: 'Country officials with policy permission can mutate.',
    );
  }

  Widget _companySection(
    BuildContext context,
    ResearchBloc bloc,
    ResearchDashboard dashboard,
  ) {
    final selected = bloc.selectedCompanyResearch;
    final selectedSummary = selected == null
        ? null
        : _findCompany(dashboard.companies, selected.scopeId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Company research',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (dashboard.companies.isEmpty)
              const Text('Join or create a company to unlock company research.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: dashboard.companies.map((company) {
                  final selectedCompany =
                      company.companyId == selected?.scopeId;
                  return ChoiceChip(
                    label: Text(company.name),
                    selected: selectedCompany,
                    onSelected: (_) async {
                      final login = context.read<LoginBloc>();
                      bloc.setBearerToken(login.currentToken);
                      await bloc.loadCompany(company.companyId);
                    },
                  );
                }).toList(),
              ),
            if (bloc.isLoadingCompany)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              _scopeCard(
                context: context,
                bloc: bloc,
                title:
                    '${selectedSummary?.name ?? selected.scopeId} technology',
                subtitle: selectedSummary?.canManageResearch == true
                    ? 'You can manage this company research tree.'
                    : 'Owners and managers can mutate company research.',
                state: selected,
                canManage: selectedSummary?.canManageResearch == true,
                permissionHint:
                    'Requires company owner or manager upgrade permission.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scopeCard({
    required BuildContext context,
    required ResearchBloc bloc,
    required String title,
    required String subtitle,
    required ResearchScopeState state,
    required bool canManage,
    required String permissionHint,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${state.availablePoints} RP available')),
                Chip(label: Text('${state.hourlyPointRate} RP/hour')),
                Chip(label: Text('Cap ${state.pointCap}')),
                if (state.productionSpeedBonusPercent > 0)
                  Chip(
                    avatar: const Icon(Icons.speed, size: 18),
                    label:
                        Text('-${state.productionSpeedBonusPercent}% duration'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              permissionHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 28),
            if (state.bonuses.isNotEmpty) ...[
              const Text(
                'Active bonuses',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...state.bonuses.map((bonus) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.auto_awesome),
                    title: Text(
                      '${bonus.totalValue}% ${_bonusLabel(bonus.bonusType)}',
                    ),
                    subtitle: Text(bonus.description),
                  )),
              const Divider(height: 28),
            ],
            ...state.technologies.map((node) {
              final project = node.project;
              final busy = bloc.operationKeys.any((operation) {
                if (operation ==
                    '${state.scopeType}:${state.scopeId}:start:${node.technology.technologyId}') {
                  return true;
                }
                final projectId = project?.projectId;
                return projectId != null &&
                    (operation ==
                            '${state.scopeType}:${state.scopeId}:contribute:$projectId' ||
                        operation ==
                            '${state.scopeType}:${state.scopeId}:complete:$projectId');
              });
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              node.technology.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Chip(label: Text(node.status)),
                        ],
                      ),
                      Text(node.technology.description),
                      const SizedBox(height: 8),
                      Text(
                        '${node.technology.requiredPoints} RP • ${_formatDuration(node.technology.durationSeconds)} • ${node.technology.bonus.description}',
                      ),
                      if (node.blockedReason != null &&
                          !node.isCompleted &&
                          !node.canStart)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            node.blockedReason!,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      if (project != null) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: project.progress),
                        const SizedBox(height: 6),
                        Text(
                          '${project.contributedPoints}/${project.requiredPoints} RP contributed; ready ${_formatDate(project.readyAt)}',
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (node.canStart && !node.isCompleted)
                            ElevatedButton(
                              onPressed: canManage && !busy
                                  ? () => _start(bloc, state, node)
                                  : null,
                              child: const Text('Start'),
                            ),
                          if (project != null && project.remainingPoints > 0)
                            ElevatedButton(
                              onPressed: canManage &&
                                      !busy &&
                                      state.availablePoints > 0
                                  ? () => _contribute(bloc, state, project)
                                  : null,
                              child: Text(
                                'Contribute ${_contributionAmount(state, project)} RP',
                              ),
                            ),
                          if (project != null && project.canComplete)
                            ElevatedButton(
                              onPressed: canManage && !busy
                                  ? () => _complete(bloc, state, project)
                                  : null,
                              child: const Text('Complete'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _start(
    ResearchBloc bloc,
    ResearchScopeState state,
    ResearchTechnologyNode node,
  ) async {
    await bloc.start(
      scopeType: state.scopeType,
      scopeId: state.scopeId,
      technologyId: node.technology.technologyId,
      idempotencyKey: _idempotencyKey(
        state,
        'start',
        node.technology.technologyId,
      ),
    );
  }

  Future<void> _contribute(
    ResearchBloc bloc,
    ResearchScopeState state,
    ResearchProject project,
  ) async {
    await bloc.contribute(
      scopeType: state.scopeType,
      scopeId: state.scopeId,
      projectId: project.projectId,
      points: _contributionAmount(state, project),
      idempotencyKey: _idempotencyKey(state, 'contribute', project.projectId),
    );
  }

  Future<void> _complete(
    ResearchBloc bloc,
    ResearchScopeState state,
    ResearchProject project,
  ) async {
    await bloc.complete(
      scopeType: state.scopeType,
      scopeId: state.scopeId,
      projectId: project.projectId,
      idempotencyKey: _idempotencyKey(state, 'complete', project.projectId),
    );
  }

  int _contributionAmount(ResearchScopeState state, ResearchProject project) {
    final amount = state.availablePoints < 25 ? state.availablePoints : 25;
    return amount < project.remainingPoints ? amount : project.remainingPoints;
  }

  ResearchCompanyScopeSummary? _findCompany(
    List<ResearchCompanyScopeSummary> companies,
    String companyId,
  ) {
    for (final company in companies) {
      if (company.companyId == companyId) {
        return company;
      }
    }

    return null;
  }

  String _idempotencyKey(
    ResearchScopeState state,
    String action,
    String targetId,
  ) {
    return 'research:${state.scopeType}:${state.scopeId}:$action:$targetId:${DateTime.now().microsecondsSinceEpoch}';
  }

  String _bonusLabel(String bonusType) {
    switch (bonusType) {
      case 'production_speed_percent':
        return 'production speed';
      case 'defense_percent':
        return 'defense';
      case 'health_capacity_percent':
        return 'health capacity';
      case 'market_fee_reduction_percent':
        return 'market fee reduction';
      default:
        return bonusType.replaceAll('_', ' ');
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}

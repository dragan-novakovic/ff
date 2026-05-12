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
      backgroundColor: const Color(0xFF08111E),
      appBar: AppBar(
        title: const Text('Research'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (bloc.error != null)
                  _ResearchMessageCard(
                    message: bloc.error!,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                  ),
                if (bloc.lastMutation != null)
                  _ResearchMessageCard(
                    message: bloc.lastMutation!.message,
                    icon: Icons.auto_awesome,
                    color: const Color(0xFF22C55E),
                  ),
                if (dashboard == null)
                  _ResearchEmptyState(onRetry: _load)
                else ...[
                  _ResearchHero(dashboard: dashboard),
                  const SizedBox(height: 16),
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
      return const _LockedResearchPanel(
        icon: Icons.flag,
        title: 'National research locked',
        message: 'Join a country to enter the national technology tree.',
      );
    }

    return _ResearchScopePanel(
      title: '${citizenship.countryName} technology tree',
      subtitle: 'Country-wide policies, production, and combat bonuses.',
      emblem: citizenship.countryCode,
      state: state,
      canManage: true,
      permissionHint: 'Country officials with policy permission can mutate.',
      operationKeys: bloc.operationKeys,
      onStart: (node) => _start(bloc, state, node),
      onContribute: (project) => _contribute(bloc, state, project),
      onComplete: (project) => _complete(bloc, state, project),
      contributionAmount: (project) => _contributionAmount(state, project),
      bonusLabel: _bonusLabel,
      formatDuration: _formatDuration,
      formatDate: _formatDate,
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
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              icon: Icons.factory,
              title: 'Company labs',
              subtitle:
                  'Select a company to inspect its production technology tree.',
            ),
            const SizedBox(height: 16),
            if (dashboard.companies.isEmpty)
              const _InlineLockedMessage(
                icon: Icons.business_center,
                message: 'Join or create a company to unlock company research.',
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: dashboard.companies.map((company) {
                  final selectedCompany =
                      company.companyId == selected?.scopeId;
                  return ChoiceChip(
                    label: Text(company.name),
                    selected: selectedCompany,
                    avatar: Icon(
                      company.canManageResearch
                          ? Icons.admin_panel_settings
                          : Icons.visibility,
                      size: 18,
                    ),
                    selectedColor: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF172A44),
                    labelStyle: TextStyle(
                      color: selectedCompany ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
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
              _ResearchScopePanel(
                title: '${selectedSummary?.name ?? selected.scopeId} tree',
                subtitle: selectedSummary?.canManageResearch == true
                    ? 'You can manage this company research tree.'
                    : 'Owners and managers can mutate company research.',
                emblem: selectedSummary?.role?.toUpperCase() ?? 'CO',
                state: selected,
                canManage: selectedSummary?.canManageResearch == true,
                permissionHint:
                    'Requires company owner or manager upgrade permission.',
                operationKeys: bloc.operationKeys,
                onStart: (node) => _start(bloc, selected, node),
                onContribute: (project) => _contribute(bloc, selected, project),
                onComplete: (project) => _complete(bloc, selected, project),
                contributionAmount: (project) =>
                    _contributionAmount(selected, project),
                bonusLabel: _bonusLabel,
                formatDuration: _formatDuration,
                formatDate: _formatDate,
              ),
            ],
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

class _ResearchHero extends StatelessWidget {
  final ResearchDashboard dashboard;

  const _ResearchHero({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final country = dashboard.country;
    final completed = country?.completedTechnologyIds.length ?? 0;
    final total = country?.technologies.length ?? 0;
    final availablePoints = country?.availablePoints ?? 0;
    final hourlyRate = country?.hourlyPointRate ?? 0;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1020),
              Color(0xFF1E3A8A),
              Color(0xFF7C2D12),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -26,
              child: Icon(
                Icons.account_tree,
                size: 170,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -18,
              child: Icon(
                Icons.science,
                size: 118,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.psychology,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const Spacer(),
                      _NeonPill(
                        label: country == null
                            ? 'No country lab'
                            : '${dashboard.citizenship?.countryCode ?? 'NAT'} lab online',
                        color: const Color(0xFF67E8F9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Technology Nexus',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock national and company bonuses through branching research paths. Each node is backed by live research projects and points.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroStat(
                        icon: Icons.bolt,
                        label: 'RP ready',
                        value: availablePoints.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.speed,
                        label: 'RP/hour',
                        value: hourlyRate.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.verified,
                        label: 'Unlocked',
                        value: '$completed/$total',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchScopePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emblem;
  final ResearchScopeState state;
  final bool canManage;
  final String permissionHint;
  final Set<String> operationKeys;
  final Future<void> Function(ResearchTechnologyNode node) onStart;
  final Future<void> Function(ResearchProject project) onContribute;
  final Future<void> Function(ResearchProject project) onComplete;
  final int Function(ResearchProject project) contributionAmount;
  final String Function(String bonusType) bonusLabel;
  final String Function(int seconds) formatDuration;
  final String Function(DateTime dateTime) formatDate;

  const _ResearchScopePanel({
    required this.title,
    required this.subtitle,
    required this.emblem,
    required this.state,
    required this.canManage,
    required this.permissionHint,
    required this.operationKeys,
    required this.onStart,
    required this.onContribute,
    required this.onComplete,
    required this.contributionAmount,
    required this.bonusLabel,
    required this.formatDuration,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final tracks = _groupByTrack(state.technologies);
    final completed = state.completedTechnologyIds.length;
    final total = state.technologies.length;
    final completionProgress = total == 0 ? 0.0 : (completed / total);

    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScopeHeader(
              title: title,
              subtitle: subtitle,
              emblem: emblem,
              canManage: canManage,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ResourceChip(
                  icon: Icons.bolt,
                  label: '${state.availablePoints} RP available',
                  color: const Color(0xFF67E8F9),
                ),
                _ResourceChip(
                  icon: Icons.schedule,
                  label: '${state.hourlyPointRate} RP/hour',
                  color: const Color(0xFFA78BFA),
                ),
                _ResourceChip(
                  icon: Icons.inventory_2,
                  label: 'Cap ${state.pointCap}',
                  color: const Color(0xFFFBBF24),
                ),
                if (state.productionSpeedBonusPercent > 0)
                  _ResourceChip(
                    icon: Icons.speed,
                    label: '-${state.productionSpeedBonusPercent}% duration',
                    color: const Color(0xFF34D399),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _CompletionBar(
              completed: completed,
              total: total,
              progress: completionProgress,
            ),
            const SizedBox(height: 10),
            Text(
              permissionHint,
              style: TextStyle(color: Colors.white.withOpacity(0.60)),
            ),
            if (state.bonuses.isNotEmpty) ...[
              const SizedBox(height: 18),
              _ActiveBonuses(
                bonuses: state.bonuses,
                bonusLabel: bonusLabel,
              ),
            ],
            const SizedBox(height: 20),
            if (state.technologies.isEmpty)
              const _InlineLockedMessage(
                icon: Icons.account_tree,
                message: 'No technologies are available for this scope yet.',
              )
            else
              ...tracks.entries.map((entry) {
                return _TechnologyTrack(
                  track: entry.key,
                  nodes: entry.value,
                  state: state,
                  canManage: canManage,
                  operationKeys: operationKeys,
                  onStart: onStart,
                  onContribute: onContribute,
                  onComplete: onComplete,
                  contributionAmount: contributionAmount,
                  formatDuration: formatDuration,
                  formatDate: formatDate,
                );
              }),
          ],
        ),
      ),
    );
  }

  Map<String, List<ResearchTechnologyNode>> _groupByTrack(
    List<ResearchTechnologyNode> nodes,
  ) {
    final tracks = <String, List<ResearchTechnologyNode>>{};
    for (final node in nodes) {
      tracks.putIfAbsent(node.technology.track, () => []).add(node);
    }
    for (final nodes in tracks.values) {
      nodes.sort((a, b) {
        final tierCompare = a.technology.tier.compareTo(b.technology.tier);
        if (tierCompare != 0) {
          return tierCompare;
        }
        return a.technology.name.compareTo(b.technology.name);
      });
    }
    return tracks;
  }
}

class _TechnologyTrack extends StatelessWidget {
  final String track;
  final List<ResearchTechnologyNode> nodes;
  final ResearchScopeState state;
  final bool canManage;
  final Set<String> operationKeys;
  final Future<void> Function(ResearchTechnologyNode node) onStart;
  final Future<void> Function(ResearchProject project) onContribute;
  final Future<void> Function(ResearchProject project) onComplete;
  final int Function(ResearchProject project) contributionAmount;
  final String Function(int seconds) formatDuration;
  final String Function(DateTime dateTime) formatDate;

  const _TechnologyTrack({
    required this.track,
    required this.nodes,
    required this.state,
    required this.canManage,
    required this.operationKeys,
    required this.onStart,
    required this.onContribute,
    required this.onComplete,
    required this.contributionAmount,
    required this.formatDuration,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1728),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_trackIcon(track), color: _trackColor(track)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_titleCase(track)} branch',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${nodes.length} nodes',
                style: TextStyle(color: Colors.white.withOpacity(0.62)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final width = wide ? 320.0 : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: wide ? Axis.horizontal : Axis.vertical,
                physics: wide
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _nodeWidgets(width, wide),
                      )
                    : Column(children: _nodeWidgets(width, wide)),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _nodeWidgets(double width, bool wide) {
    final widgets = <Widget>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      widgets.add(SizedBox(
        width: width,
        child: _TechnologyNodeCard(
          node: node,
          state: state,
          canManage: canManage,
          busy: _isBusy(node),
          onStart: () => onStart(node),
          onContribute:
              node.project == null ? null : () => onContribute(node.project!),
          onComplete:
              node.project == null ? null : () => onComplete(node.project!),
          contributionAmount:
              node.project == null ? 0 : contributionAmount(node.project!),
          formatDuration: formatDuration,
          formatDate: formatDate,
        ),
      ));
      if (index < nodes.length - 1) {
        widgets.add(wide
            ? _TreeConnector.horizontal(color: _trackColor(track))
            : _TreeConnector.vertical(color: _trackColor(track)));
      }
    }
    return widgets;
  }

  bool _isBusy(ResearchTechnologyNode node) {
    final technologyId = node.technology.technologyId;
    if (operationKeys.contains(
      '${state.scopeType}:${state.scopeId}:start:$technologyId',
    )) {
      return true;
    }

    final projectId = node.project?.projectId;
    return projectId != null &&
        (operationKeys.contains(
              '${state.scopeType}:${state.scopeId}:contribute:$projectId',
            ) ||
            operationKeys.contains(
              '${state.scopeType}:${state.scopeId}:complete:$projectId',
            ));
  }
}

class _TechnologyNodeCard extends StatelessWidget {
  final ResearchTechnologyNode node;
  final ResearchScopeState state;
  final bool canManage;
  final bool busy;
  final Future<void> Function() onStart;
  final Future<void> Function()? onContribute;
  final Future<void> Function()? onComplete;
  final int contributionAmount;
  final String Function(int seconds) formatDuration;
  final String Function(DateTime dateTime) formatDate;

  const _TechnologyNodeCard({
    required this.node,
    required this.state,
    required this.canManage,
    required this.busy,
    required this.onStart,
    required this.onContribute,
    required this.onComplete,
    required this.contributionAmount,
    required this.formatDuration,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final project = node.project;
    final color = _statusColor(node);
    final locked = node.isLocked;
    final canContribute = project != null &&
        project.remainingPoints > 0 &&
        canManage &&
        !busy &&
        state.availablePoints > 0;
    final canComplete =
        project != null && project.canComplete && canManage && !busy;

    return AnimatedOpacity(
      opacity: locked ? 0.72 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.20),
              const Color(0xFF111827),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.52), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(node.isCompleted ? 0.26 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NodeIcon(node: node, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              node.technology.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _TierBadge(tier: node.technology.tier),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _StatusBadge(node: node, color: color),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              node.technology.description,
              style: TextStyle(color: Colors.white.withOpacity(0.72)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat(
                  icon: Icons.bolt,
                  label: '${node.technology.requiredPoints} RP',
                ),
                _MiniStat(
                  icon: Icons.timer,
                  label: formatDuration(node.technology.durationSeconds),
                ),
                _MiniStat(
                  icon: Icons.auto_awesome,
                  label: '+${node.technology.bonus.bonusValue}%',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              node.technology.bonus.description,
              style: TextStyle(
                color: const Color(0xFFFDE68A).withOpacity(0.92),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (node.technology.prerequisiteTechnologyIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Requires: ${node.technology.prerequisiteTechnologyIds.join(', ')}',
                style: TextStyle(color: Colors.white.withOpacity(0.50)),
              ),
            ],
            if (node.blockedReason != null &&
                !node.isCompleted &&
                !node.canStart) ...[
              const SizedBox(height: 8),
              _BlockedReason(message: node.blockedReason!),
            ],
            if (project != null) ...[
              const SizedBox(height: 14),
              _ProjectProgress(project: project, formatDate: formatDate),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (busy)
                  const _BusyChip()
                else ...[
                  if (node.canStart && !node.isCompleted)
                    ElevatedButton.icon(
                      onPressed: canManage ? onStart : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start node'),
                    ),
                  if (project != null && project.remainingPoints > 0)
                    ElevatedButton.icon(
                      onPressed: canContribute ? onContribute : null,
                      icon: const Icon(Icons.add),
                      label: Text('Add $contributionAmount RP'),
                    ),
                  if (project != null && project.canComplete)
                    ElevatedButton.icon(
                      onPressed: canComplete ? onComplete : null,
                      icon: const Icon(Icons.verified),
                      label: const Text('Unlock'),
                    ),
                ],
              ],
            ),
            if (!canManage && !node.isCompleted) ...[
              const SizedBox(height: 8),
              Text(
                'View only - management permission required.',
                style: TextStyle(color: Colors.white.withOpacity(0.52)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectProgress extends StatelessWidget {
  final ResearchProject project;
  final String Function(DateTime dateTime) formatDate;

  const _ProjectProgress({required this.project, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.construction, color: Color(0xFF67E8F9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${project.contributedPoints}/${project.requiredPoints} RP infused',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${project.progressPercent}%',
                style: const TextStyle(
                  color: Color(0xFF67E8F9),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: project.progress,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF67E8F9)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            project.canComplete
                ? 'Breakthrough ready to unlock.'
                : 'Ready at ${formatDate(project.readyAt)}',
            style: TextStyle(color: Colors.white.withOpacity(0.64)),
          ),
        ],
      ),
    );
  }
}

class _ResearchMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _ResearchMessageCard({
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchEmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ResearchEmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F2136),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.science, color: Color(0xFF67E8F9), size: 52),
            const SizedBox(height: 14),
            const Text(
              'Research nexus offline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Load backend research data to show technology branches and projects.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.68)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Load research'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedResearchPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _LockedResearchPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _InlineLockedMessage(icon: icon, message: '$title - $message'),
      ),
    );
  }
}

class _InlineLockedMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineLockedMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.66)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emblem;
  final bool canManage;

  const _ScopeHeader({
    required this.title,
    required this.subtitle,
    required this.emblem,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF38BDF8), Color(0xFFA78BFA)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              emblem.length > 3 ? emblem.substring(0, 3) : emblem,
              style: const TextStyle(
                color: Color(0xFF08111E),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.66)),
              ),
            ],
          ),
        ),
        _NeonPill(
          label: canManage ? 'Control' : 'View',
          color: canManage ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
        ),
      ],
    );
  }
}

class _ActiveBonuses extends StatelessWidget {
  final List<ResearchBonus> bonuses;
  final String Function(String bonusType) bonusLabel;

  const _ActiveBonuses({required this.bonuses, required this.bonusLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101B2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF22C55E)),
              SizedBox(width: 8),
              Text(
                'Active bonuses',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...bonuses.map((bonus) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+${bonus.totalValue}% ',
                    style: const TextStyle(
                      color: Color(0xFF86EFAC),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${bonusLabel(bonus.bonusType)} - ${bonus.description}',
                      style: TextStyle(color: Colors.white.withOpacity(0.72)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  final int completed;
  final int total;
  final double progress;

  const _CompletionBar({
    required this.completed,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree, color: Color(0xFF67E8F9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tree mastery',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$completed/$total nodes',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF67E8F9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ResourceChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonPill extends StatelessWidget {
  final String label;
  final Color color;

  const _NeonPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.72)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NodeIcon extends StatelessWidget {
  final ResearchTechnologyNode node;
  final Color color;

  const _NodeIcon({required this.node, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.62)),
      ),
      child: Icon(_nodeIcon(node), color: color, size: 28),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final int tier;

  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'T$tier',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ResearchTechnologyNode node;
  final Color color;

  const _StatusBadge({required this.node, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.34)),
      ),
      child: Text(
        _statusLabel(node),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.68), size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.74)),
          ),
        ],
      ),
    );
  }
}

class _BlockedReason extends StatelessWidget {
  final String message;

  const _BlockedReason({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock, color: Color(0xFFFBBF24), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white.withOpacity(0.66)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusyChip extends StatelessWidget {
  const _BusyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Syncing', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _TreeConnector extends StatelessWidget {
  final Color color;
  final bool horizontal;

  const _TreeConnector.horizontal({required this.color}) : horizontal = true;
  const _TreeConnector.vertical({required this.color}) : horizontal = false;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return SizedBox(
        width: 42,
        height: 160,
        child: Center(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: color.withOpacity(0.55),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: Center(
        child: Container(
          width: 3,
          decoration: BoxDecoration(
            color: color.withOpacity(0.55),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

Color _statusColor(ResearchTechnologyNode node) {
  if (node.isCompleted) {
    return const Color(0xFF22C55E);
  }
  if (node.project?.canComplete == true || node.status == 'ready') {
    return const Color(0xFFFBBF24);
  }
  if (node.project != null || node.status == 'active') {
    return const Color(0xFF38BDF8);
  }
  if (node.canStart) {
    return const Color(0xFFA78BFA);
  }
  return const Color(0xFF94A3B8);
}

String _statusLabel(ResearchTechnologyNode node) {
  if (node.isCompleted) {
    return 'Unlocked';
  }
  if (node.project?.canComplete == true || node.status == 'ready') {
    return 'Breakthrough ready';
  }
  if (node.project != null || node.status == 'active') {
    return 'Researching';
  }
  if (node.canStart) {
    return 'Available';
  }
  return 'Locked';
}

IconData _nodeIcon(ResearchTechnologyNode node) {
  if (node.isCompleted) {
    return Icons.verified;
  }
  if (node.project?.canComplete == true || node.status == 'ready') {
    return Icons.auto_awesome;
  }
  if (node.project != null || node.status == 'active') {
    return Icons.science;
  }
  if (node.canStart) {
    return Icons.play_circle_fill;
  }
  return Icons.lock;
}

IconData _trackIcon(String track) {
  switch (track) {
    case 'industry':
      return Icons.factory;
    case 'military':
      return Icons.security;
    case 'economy':
      return Icons.account_balance;
    case 'medicine':
      return Icons.local_hospital;
    default:
      return Icons.account_tree;
  }
}

Color _trackColor(String track) {
  switch (track) {
    case 'industry':
      return const Color(0xFF22C55E);
    case 'military':
      return const Color(0xFFF97316);
    case 'economy':
      return const Color(0xFFFBBF24);
    case 'medicine':
      return const Color(0xFF38BDF8);
    default:
      return const Color(0xFFA78BFA);
  }
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value.split('_').map((part) {
    if (part.isEmpty) {
      return part;
    }
    return '${part[0].toUpperCase()}${part.substring(1)}';
  }).join(' ');
}

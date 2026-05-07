import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart' hide PlayerFactory;
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CompaniesPage extends StatefulWidget {
  final User user;
  const CompaniesPage({super.key, required this.user});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  late final CompaniesBloc _companiesBloc;
  late final LoginBloc _loginBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _companiesBloc = Provider.of<CompaniesBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _companiesBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _createCompany() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Company name is required.');
      return;
    }

    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.create(
      playerId: widget.user.uid,
      name: name,
      description: _descriptionController.text.trim(),
    );
    if (result != null && result.completed) {
      _nameController.clear();
      _descriptionController.clear();
      await _onboardingBloc.load(widget.user.uid);
    }
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _joinCompany(CompanySummary company) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.join(
      playerId: widget.user.uid,
      companyId: company.companyId,
    );
    if (result?.completed == true) {
      await _onboardingBloc.load(widget.user.uid);
    }
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _selectCompany(CompanySummary company) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    await _companiesBloc.loadCompany(company.companyId);
    _showMessage(_companiesBloc.error);
  }

  Future<void> _setMemberRole(
    CompanyDetail company,
    CompanyMember member,
    String role,
  ) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.updateMemberRole(
      companyId: company.companyId,
      playerId: member.playerId,
      role: role,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _removeMember(
      CompanyDetail company, CompanyMember member) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.removeMember(
      companyId: company.companyId,
      playerId: member.playerId,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _produce(CompanyDetail company, PlayerFactory factory) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.produce(
      companyId: company.companyId,
      factoryId: factory.factoryId,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _claim(CompanyDetail company, ProductionJob job) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.claim(
      companyId: company.companyId,
      jobId: job.jobId,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _upgradeHq(CompanyDetail company) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.upgradeHq(
      companyId: company.companyId,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _setSpecialization(
    CompanyDetail company,
    CompanySpecializationOption option,
  ) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.setSpecialization(
      companyId: company.companyId,
      specialization: option.specialization,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _postJob(
    CompanyDetail company, {
    required String title,
    required String description,
    required int wageGold,
    required int requiredEnergy,
    required int dailyLimit,
    required int productivityReward,
  }) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.postJob(
      companyId: company.companyId,
      title: title,
      description: description,
      wageGold: wageGold,
      requiredEnergy: requiredEnergy,
      dailyLimit: dailyLimit,
      productivityReward: productivityReward,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _setJobActive(
    CompanyDetail company,
    CompanyJobPosting job,
    bool isActive,
  ) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.setJobActive(
      companyId: company.companyId,
      job: job,
      isActive: isActive,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _closeJob(CompanyDetail company, CompanyJobPosting job) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _companiesBloc.closeJob(
      companyId: company.companyId,
      jobId: job.jobId,
    );
    _showMessage(result?.message ?? _companiesBloc.error);
  }

  Future<void> _workJob(CompanyDetail company, CompanyJobPosting job) async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    final idempotencyKey =
        'company-work-${job.jobId}-${DateTime.now().microsecondsSinceEpoch}';
    final result = await _companiesBloc.workJob(
      playerId: widget.user.uid,
      companyId: company.companyId,
      jobId: job.jobId,
      idempotencyKey: idempotencyKey,
    );
    if (result?.completed == true) {
      await _onboardingBloc.load(widget.user.uid);
    }
    _showMessage(result?.message ?? _companiesBloc.error);
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
      appBar: AppBar(title: const Text('Companies')),
      body: Consumer<CompaniesBloc>(
        builder: (context, bloc, _) {
          final portfolio = bloc.portfolio;
          if (bloc.isLoading && portfolio == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && portfolio == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OnboardingGuidanceCard(
                  questline: context.watch<OnboardingQuestlineBloc>().questline,
                  route: '/companies',
                ),
                _CreateCompanyCard(
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  isCreating: bloc.isCreating,
                  onCreate: _createCompany,
                ),
                if (bloc.error != null)
                  _NoticeCard(
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                    message: bloc.error!,
                  ),
                if (bloc.lastMutation != null)
                  _NoticeCard(
                    icon: bloc.lastMutation!.completed
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: bloc.lastMutation!.completed
                        ? Colors.green
                        : Colors.blue,
                    message: bloc.lastMutation!.message,
                  ),
                if (bloc.lastProduction != null)
                  _NoticeCard(
                    icon: Icons.factory,
                    color: Colors.blue,
                    message: bloc.lastProduction!.message,
                  ),
                if (bloc.lastClaim != null)
                  _NoticeCard(
                    icon: Icons.inventory_2,
                    color: Colors.green,
                    message: bloc.lastClaim!.message,
                  ),
                if (bloc.lastUpgrade != null)
                  _NoticeCard(
                    icon: Icons.trending_up,
                    color: Colors.deepPurple,
                    message: bloc.lastUpgrade!.message,
                  ),
                if (bloc.lastJobMutation != null)
                  _NoticeCard(
                    icon: Icons.work,
                    color: Colors.indigo,
                    message: bloc.lastJobMutation!.message,
                  ),
                if (bloc.lastWork != null)
                  _NoticeCard(
                    icon: Icons.payments,
                    color: Colors.green,
                    message: bloc.lastWork!.message,
                  ),
                _SectionHeader(
                  title: 'Company directory',
                  subtitle:
                      'Companies, memberships, factories, wallet and inventory are persisted by the backend.',
                ),
                if (portfolio == null || portfolio.companies.isEmpty)
                  const _EmptyCard(
                    icon: Icons.business_outlined,
                    message: 'No companies exist yet. Found one above.',
                  )
                else
                  ...portfolio.companies.map(
                    (company) => _CompanyCard(
                      company: company,
                      isJoining:
                          bloc.joiningCompanyIds.contains(company.companyId),
                      onJoin: () => _joinCompany(company),
                      onDetails: company.isMember
                          ? () => _selectCompany(company)
                          : null,
                    ),
                  ),
                if (bloc.isLoadingDetails)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (bloc.selectedCompany != null)
                  _CompanyDetailCard(
                    company: bloc.selectedCompany!,
                    currentPlayerId: widget.user.uid,
                    updatingMemberIds: bloc.updatingMemberIds,
                    producingFactoryIds: bloc.producingFactoryIds,
                    claimingJobIds: bloc.claimingJobIds,
                    isUpgradingHq: bloc.isUpgradingHq,
                    isSpecializing: bloc.specializingCompanyIds
                        .contains(bloc.selectedCompany!.companyId),
                    updatingJobIds: bloc.updatingJobIds,
                    workingJobIds: bloc.workingJobIds,
                    isPostingJob: bloc.isPostingJob,
                    onSetRole: _setMemberRole,
                    onRemoveMember: _removeMember,
                    onProduce: _produce,
                    onClaim: _claim,
                    onUpgradeHq: _upgradeHq,
                    onSetSpecialization: _setSpecialization,
                    onPostJob: _postJob,
                    onSetJobActive: _setJobActive,
                    onCloseJob: _closeJob,
                    onWorkJob: _workJob,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CreateCompanyCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool isCreating;
  final VoidCallback onCreate;

  const _CreateCompanyCard({
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
            Row(
              children: [
                const Icon(Icons.add_business, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Found a company',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
                  : const Icon(Icons.business),
              label: Text(isCreating ? 'Creating...' : 'Create company'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final CompanySummary company;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback? onDetails;

  const _CompanyCard({
    required this.company,
    required this.isJoining,
    required this.onJoin,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          company.isMember ? Icons.verified : Icons.business,
          color: company.isMember ? Colors.green : Colors.blue,
        ),
        title: Text(company.name),
        subtitle: Text(
          '${company.description}\n'
          'HQ L${company.hqLevel} ${company.specialization} • '
          '${company.memberCount} members • ${company.factoryCount}/${company.factorySlots} factories • '
          '${Utils.number(company.walletGold)} gold',
        ),
        isThreeLine: true,
        trailing: company.isMember
            ? Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(company.role ?? 'member')),
                  ElevatedButton(
                    onPressed: onDetails,
                    child: const Text('Manage'),
                  ),
                ],
              )
            : ElevatedButton.icon(
                onPressed: isJoining ? null : onJoin,
                icon: isJoining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add),
                label: Text(isJoining ? 'Joining...' : 'Join'),
              ),
      ),
    );
  }
}

class _CompanyDetailCard extends StatelessWidget {
  final CompanyDetail company;
  final String currentPlayerId;
  final Set<String> updatingMemberIds;
  final Set<String> producingFactoryIds;
  final Set<String> claimingJobIds;
  final bool isUpgradingHq;
  final bool isSpecializing;
  final Set<String> updatingJobIds;
  final Set<String> workingJobIds;
  final bool isPostingJob;
  final Future<void> Function(
    CompanyDetail company,
    CompanyMember member,
    String role,
  ) onSetRole;
  final Future<void> Function(CompanyDetail company, CompanyMember member)
      onRemoveMember;
  final Future<void> Function(CompanyDetail company, PlayerFactory factory)
      onProduce;
  final Future<void> Function(CompanyDetail company, ProductionJob job) onClaim;
  final Future<void> Function(CompanyDetail company) onUpgradeHq;
  final Future<void> Function(
    CompanyDetail company,
    CompanySpecializationOption option,
  ) onSetSpecialization;
  final Future<void> Function(
    CompanyDetail company, {
    required String title,
    required String description,
    required int wageGold,
    required int requiredEnergy,
    required int dailyLimit,
    required int productivityReward,
  }) onPostJob;
  final Future<void> Function(
    CompanyDetail company,
    CompanyJobPosting job,
    bool isActive,
  ) onSetJobActive;
  final Future<void> Function(CompanyDetail company, CompanyJobPosting job)
      onCloseJob;
  final Future<void> Function(CompanyDetail company, CompanyJobPosting job)
      onWorkJob;

  const _CompanyDetailCard({
    required this.company,
    required this.currentPlayerId,
    required this.updatingMemberIds,
    required this.producingFactoryIds,
    required this.claimingJobIds,
    required this.isUpgradingHq,
    required this.isSpecializing,
    required this.updatingJobIds,
    required this.workingJobIds,
    required this.isPostingJob,
    required this.onSetRole,
    required this.onRemoveMember,
    required this.onProduce,
    required this.onClaim,
    required this.onUpgradeHq,
    required this.onSetSpecialization,
    required this.onPostJob,
    required this.onSetJobActive,
    required this.onCloseJob,
    required this.onWorkJob,
  });

  @override
  Widget build(BuildContext context) {
    final assets = company.assets;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.domain, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    company.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Chip(label: Text(company.role ?? 'member')),
              ],
            ),
            const SizedBox(height: 8),
            Text(company.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.payments,
                  label: '${Utils.number(assets.walletGold)} gold',
                ),
                _InfoChip(
                  icon: Icons.inventory_2,
                  label: '${assets.storageUsed}/${assets.storageLimit} storage',
                ),
                _InfoChip(
                  icon: Icons.factory,
                  label:
                      '${assets.upgrades.usedFactorySlots}/${assets.upgrades.factorySlots} factory slots',
                ),
                _InfoChip(
                  icon: Icons.trending_up,
                  label:
                      'HQ L${assets.upgrades.hqLevel} • +${assets.upgrades.productivityBonusPercent}% productivity',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CompanyUpgradesSection(
              upgrades: assets.upgrades,
              canManageSpecialization:
                  company.permissions.canManageSpecialization,
              isUpgradingHq: isUpgradingHq,
              isSpecializing: isSpecializing,
              onUpgradeHq: () => onUpgradeHq(company),
              onSetSpecialization: (option) =>
                  onSetSpecialization(company, option),
            ),
            const SizedBox(height: 16),
            _SectionHeader(title: 'Members', subtitle: 'Owner-managed roles'),
            ...company.members.map(
              (member) => _MemberTile(
                company: company,
                member: member,
                currentPlayerId: currentPlayerId,
                isUpdating: updatingMemberIds
                    .contains('${company.companyId}:${member.playerId}'),
                onSetRole: onSetRole,
                onRemoveMember: onRemoveMember,
              ),
            ),
            const SizedBox(height: 16),
            _CompanyWorkforceSection(
              company: company,
              isPostingJob: isPostingJob,
              updatingJobIds: updatingJobIds,
              workingJobIds: workingJobIds,
              onPostJob: onPostJob,
              onSetJobActive: onSetJobActive,
              onCloseJob: onCloseJob,
              onWorkJob: onWorkJob,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Company inventory',
              subtitle: 'Consumed and produced by company-owned factories',
            ),
            if (assets.inventory.isEmpty)
              const _EmptyCard(
                icon: Icons.inventory_2_outlined,
                message: 'Company inventory is empty.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: assets.inventory
                    .map(
                      (item) => Chip(
                        avatar: const Icon(Icons.inventory, size: 18),
                        label: Text('${item.quantity} ${item.name}'),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Company factories',
              subtitle: 'Managers can start persisted company production jobs',
            ),
            if (assets.factories.isEmpty)
              const _EmptyCard(
                icon: Icons.factory_outlined,
                message: 'No company factories are owned yet.',
              )
            else
              ...assets.factories.map(
                (factory) => _CompanyFactoryCard(
                  company: company,
                  factory: factory,
                  jobs: assets
                      .jobsForFactory(factory.factoryId)
                      .where((job) => job.isVisibleOnFactory)
                      .toList(),
                  isProducing: producingFactoryIds.contains(factory.factoryId),
                  claimingJobIds: claimingJobIds,
                  onProduce: onProduce,
                  onClaim: onClaim,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompanyUpgradesSection extends StatelessWidget {
  final CompanyUpgradeState upgrades;
  final bool canManageSpecialization;
  final bool isUpgradingHq;
  final bool isSpecializing;
  final VoidCallback onUpgradeHq;
  final Future<void> Function(CompanySpecializationOption option)
      onSetSpecialization;

  const _CompanyUpgradesSection({
    required this.upgrades,
    required this.canManageSpecialization,
    required this.isUpgradingHq,
    required this.isSpecializing,
    required this.onUpgradeHq,
    required this.onSetSpecialization,
  });

  @override
  Widget build(BuildContext context) {
    final quote = upgrades.nextHqUpgrade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'HQ upgrades & specialization',
          subtitle:
              'Costs, slots, storage and productivity bonuses come from persisted company state.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.domain,
                      label: 'HQ level ${upgrades.hqLevel}',
                    ),
                    _InfoChip(
                      icon: Icons.inventory_2,
                      label:
                          '${upgrades.storageUsed}/${upgrades.storageLimit} storage',
                    ),
                    _InfoChip(
                      icon: Icons.factory,
                      label:
                          '${upgrades.usedFactorySlots}/${upgrades.factorySlots} factory slots',
                    ),
                    _InfoChip(
                      icon: Icons.trending_up,
                      label: '+${upgrades.productivityBonusPercent}% base',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quote.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Next: ${Utils.number(quote.goldCost)} gold + '
                  '${quote.requiredItemQuantity} ${quote.requiredItemName} • '
                  'storage ${quote.storageLimitAfterUpgrade}, '
                  'slots ${quote.factorySlotsAfterUpgrade}, '
                  '+${quote.productivityBonusPercentAfterUpgrade}% productivity',
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: upgrades.canManageUpgrades &&
                          quote.canUpgrade &&
                          !isUpgradingHq
                      ? onUpgradeHq
                      : null,
                  icon: isUpgradingHq
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upgrade),
                  label: Text(isUpgradingHq ? 'Upgrading...' : 'Upgrade HQ'),
                ),
              ],
            ),
          ),
        ),
        if (upgrades.specializationOptions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: upgrades.specializationOptions
                .map(
                  (option) => ChoiceChip(
                    label: Text(
                      option.isSelected
                          ? '${option.name} (active)'
                          : option.name,
                    ),
                    selected: option.isSelected,
                    onSelected: option.isSelected ||
                            !canManageSpecialization ||
                            isSpecializing
                        ? null
                        : (_) {
                            onSetSpecialization(option);
                          },
                    avatar: Icon(
                      option.isSelected ? Icons.check : Icons.auto_awesome,
                      size: 18,
                    ),
                  ),
                )
                .toList(),
          ),
        if (upgrades.specializationOptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              upgrades.specializationOptions
                  .map(
                    (option) =>
                        '${option.name}: +${option.productivityBonusPercent}% ${option.affectedCategory}',
                  )
                  .join(' • '),
            ),
          ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final CompanyDetail company;
  final CompanyMember member;
  final String currentPlayerId;
  final bool isUpdating;
  final Future<void> Function(
    CompanyDetail company,
    CompanyMember member,
    String role,
  ) onSetRole;
  final Future<void> Function(CompanyDetail company, CompanyMember member)
      onRemoveMember;

  const _MemberTile({
    required this.company,
    required this.member,
    required this.currentPlayerId,
    required this.isUpdating,
    required this.onSetRole,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role == 'owner';
    final isSelf =
        member.playerId.toLowerCase() == currentPlayerId.toLowerCase();
    final canEdit = company.role == 'owner' && !isOwner;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isOwner ? Icons.workspace_premium : Icons.person),
      title: Text(member.playerId),
      subtitle: Text('${member.role} • joined ${_formatDate(member.joinedAt)}'),
      trailing: isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Wrap(
              spacing: 4,
              children: [
                if (canEdit && member.role != 'manager')
                  TextButton(
                    onPressed: () => onSetRole(company, member, 'manager'),
                    child: const Text('Manager'),
                  ),
                if (canEdit && member.role != 'member')
                  TextButton(
                    onPressed: () => onSetRole(company, member, 'member'),
                    child: const Text('Member'),
                  ),
                if (!isOwner && (canEdit || isSelf))
                  TextButton(
                    onPressed: () => onRemoveMember(company, member),
                    child: Text(isSelf ? 'Leave' : 'Remove'),
                  ),
              ],
            ),
    );
  }
}

class _CompanyWorkforceSection extends StatefulWidget {
  final CompanyDetail company;
  final bool isPostingJob;
  final Set<String> updatingJobIds;
  final Set<String> workingJobIds;
  final Future<void> Function(
    CompanyDetail company, {
    required String title,
    required String description,
    required int wageGold,
    required int requiredEnergy,
    required int dailyLimit,
    required int productivityReward,
  }) onPostJob;
  final Future<void> Function(
    CompanyDetail company,
    CompanyJobPosting job,
    bool isActive,
  ) onSetJobActive;
  final Future<void> Function(CompanyDetail company, CompanyJobPosting job)
      onCloseJob;
  final Future<void> Function(CompanyDetail company, CompanyJobPosting job)
      onWorkJob;

  const _CompanyWorkforceSection({
    required this.company,
    required this.isPostingJob,
    required this.updatingJobIds,
    required this.workingJobIds,
    required this.onPostJob,
    required this.onSetJobActive,
    required this.onCloseJob,
    required this.onWorkJob,
  });

  @override
  State<_CompanyWorkforceSection> createState() =>
      _CompanyWorkforceSectionState();
}

class _CompanyWorkforceSectionState extends State<_CompanyWorkforceSection> {
  final TextEditingController _titleController =
      TextEditingController(text: 'Factory shift');
  final TextEditingController _descriptionController =
      TextEditingController(text: 'Help the company produce goods.');
  final TextEditingController _wageController =
      TextEditingController(text: '25');
  final TextEditingController _energyController =
      TextEditingController(text: '0');
  final TextEditingController _dailyLimitController =
      TextEditingController(text: '1');
  final TextEditingController _productivityController =
      TextEditingController(text: '1');

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _wageController.dispose();
    _energyController.dispose();
    _dailyLimitController.dispose();
    _productivityController.dispose();
    super.dispose();
  }

  Future<void> _submitJob() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showLocalMessage('Job title is required.');
      return;
    }

    final wage = _parseInt(_wageController.text, 'wage', minimum: 1);
    final energy =
        _parseInt(_energyController.text, 'required energy', minimum: 0);
    final dailyLimit =
        _parseInt(_dailyLimitController.text, 'daily limit', minimum: 1);
    final productivity =
        _parseInt(_productivityController.text, 'productivity', minimum: 1);
    if (wage == null ||
        energy == null ||
        dailyLimit == null ||
        productivity == null) {
      return;
    }

    await widget.onPostJob(
      widget.company,
      title: title,
      description: _descriptionController.text.trim(),
      wageGold: wage,
      requiredEnergy: energy,
      dailyLimit: dailyLimit,
      productivityReward: productivity,
    );
  }

  int? _parseInt(String value, String label, {required int minimum}) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < minimum) {
      _showLocalMessage('$label must be at least $minimum.');
      return null;
    }

    return parsed;
  }

  void _showLocalMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = widget.company.assets.workforceJobs;
    final recentRecords = widget.company.assets.workRecords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Workforce jobs',
          subtitle:
              'Company wages are paid from the company wallet and labor credits are persisted in inventory.',
        ),
        if (widget.company.canManage)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Post a job',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NumberField(
                        controller: _wageController,
                        label: 'Wage gold',
                      ),
                      _NumberField(
                        controller: _energyController,
                        label: 'Required energy',
                      ),
                      _NumberField(
                        controller: _dailyLimitController,
                        label: 'Daily limit',
                      ),
                      _NumberField(
                        controller: _productivityController,
                        label: 'Labor credit',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: widget.isPostingJob ? null : _submitJob,
                    icon: widget.isPostingJob
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.post_add),
                    label:
                        Text(widget.isPostingJob ? 'Posting...' : 'Post job'),
                  ),
                ],
              ),
            ),
          ),
        if (jobs.isEmpty)
          const _EmptyCard(
            icon: Icons.work_outline,
            message: 'No workforce jobs are posted.',
          )
        else
          ...jobs.map(
            (job) => _CompanyJobTile(
              company: widget.company,
              job: job,
              isUpdating: widget.updatingJobIds.contains(job.jobId),
              isWorking: widget.workingJobIds.contains(job.jobId),
              onSetJobActive: widget.onSetJobActive,
              onCloseJob: widget.onCloseJob,
              onWorkJob: widget.onWorkJob,
            ),
          ),
        if (recentRecords.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Recent work records',
              style: Theme.of(context).textTheme.titleMedium),
          ...recentRecords.take(5).map(
                (record) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    record.status == 'paid'
                        ? Icons.check_circle
                        : Icons.pending_actions,
                    color:
                        record.status == 'paid' ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                      '${record.playerId} earned ${record.netWageGold} gold'),
                  subtitle: Text(
                    '${record.status} • tax ${record.taxGold} • '
                    '${_formatDate(record.workedAt)} ${_formatTime(record.workedAt)}',
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NumberField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CompanyJobTile extends StatelessWidget {
  final CompanyDetail company;
  final CompanyJobPosting job;
  final bool isUpdating;
  final bool isWorking;
  final Future<void> Function(
    CompanyDetail company,
    CompanyJobPosting job,
    bool isActive,
  ) onSetJobActive;
  final Future<void> Function(CompanyDetail company, CompanyJobPosting job)
      onCloseJob;
  final Future<void> Function(CompanyDetail company, CompanyJobPosting job)
      onWorkJob;

  const _CompanyJobTile({
    required this.company,
    required this.job,
    required this.isUpdating,
    required this.isWorking,
    required this.onSetJobActive,
    required this.onCloseJob,
    required this.onWorkJob,
  });

  @override
  Widget build(BuildContext context) {
    final canWork = job.isActive && !job.isDailyLimitReached && !isWorking;
    return Card(
      child: ListTile(
        leading: Icon(
          job.isActive ? Icons.work : Icons.work_off,
          color: job.isActive ? Colors.green : Colors.blueGrey,
        ),
        title: Text(job.title),
        subtitle: Text(
          '${job.description}\n'
          '${Utils.number(job.wageGold)} gold wage • '
          '${job.requiredEnergy} energy required • '
          '${job.todayWorkCount}/${job.dailyLimit} today • '
          '+${job.productivityReward} labor credit • ${job.status}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 6,
          children: [
            if (company.canManage && job.status != 'closed')
              TextButton(
                onPressed: isUpdating
                    ? null
                    : () => onSetJobActive(company, job, !job.isActive),
                child: Text(job.isActive ? 'Pause' : 'Activate'),
              ),
            if (company.canManage && job.status != 'closed')
              TextButton(
                onPressed: isUpdating ? null : () => onCloseJob(company, job),
                child: const Text('Close'),
              ),
            ElevatedButton.icon(
              onPressed: canWork ? () => onWorkJob(company, job) : null,
              icon: isWorking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments),
              label: Text(isWorking
                  ? 'Working...'
                  : job.isDailyLimitReached
                      ? 'Limit reached'
                      : 'Work'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyFactoryCard extends StatelessWidget {
  final CompanyDetail company;
  final PlayerFactory factory;
  final List<ProductionJob> jobs;
  final bool isProducing;
  final Set<String> claimingJobIds;
  final Future<void> Function(CompanyDetail company, PlayerFactory factory)
      onProduce;
  final Future<void> Function(CompanyDetail company, ProductionJob job) onClaim;

  const _CompanyFactoryCard({
    required this.company,
    required this.factory,
    required this.jobs,
    required this.isProducing,
    required this.claimingJobIds,
    required this.onProduce,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.factory, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${factory.name} L${factory.level}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('Runs: ${factory.productionCount}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${factory.inputQuantity} ${factory.inputItemId} → '
            '${factory.outputQuantity} ${factory.outputItemId}',
          ),
          Text('Queue: ${factory.queueDepth}/${factory.maxQueueDepth}'),
          const SizedBox(height: 8),
          if (jobs.isNotEmpty)
            ...jobs.map(
              (job) => _CompanyProductionJobTile(
                job: job,
                isClaiming: claimingJobIds.contains(job.jobId),
                onClaim: () => onClaim(company, job),
              ),
            ),
          ElevatedButton.icon(
            onPressed: company.canManage && factory.canProduce && !isProducing
                ? () => onProduce(company, factory)
                : null,
            icon: isProducing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(isProducing ? 'Starting...' : 'Start production'),
          ),
        ],
      ),
    );
  }
}

class _CompanyProductionJobTile extends StatelessWidget {
  final ProductionJob job;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _CompanyProductionJobTile({
    required this.job,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        job.isReady ? Icons.check_circle : Icons.hourglass_bottom,
        color: job.isReady ? Colors.green : Colors.blueGrey,
      ),
      title:
          Text('${job.outputQuantity} ${job.outputItemName} • ${job.status}'),
      subtitle: Text(_jobTimingText(job)),
      trailing: job.isReady
          ? ElevatedButton(
              onPressed: isClaiming ? null : onClaim,
              child: Text(isClaiming ? 'Claiming...' : 'Claim'),
            )
          : null,
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(message),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
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

String _jobTimingText(ProductionJob job) {
  if (job.isReady) {
    return 'Ready to claim since ${_formatTime(job.completedAt ?? job.completesAt)}.';
  }

  if (job.status == 'queued') {
    return 'Queued: starts ${_formatTime(job.startedAt)}, ready ${_formatTime(job.completesAt)}.';
  }

  final remaining = job.remaining;
  return 'Cooling down: ready in ${_formatDuration(remaining)} (${_formatTime(job.completesAt)}).';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  if (minutes <= 0) {
    return '${seconds}s';
  }
  return '${minutes}m ${seconds}s';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

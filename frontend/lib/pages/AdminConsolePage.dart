import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/AdminConsole.dart';
import 'package:ff/services/backend_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  static const _configuredAdminToken = String.fromEnvironment(
    'FF_ADMIN_TOKEN',
    defaultValue: '',
  );

  final BackendApiClient _apiClient = BackendApiClient();
  final TextEditingController _tokenController =
      TextEditingController(text: _configuredAdminToken);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _suspensionHoursController =
      TextEditingController(text: '24');
  final TextEditingController _contentResolutionController =
      TextEditingController();

  AdminPlayerSearchResponse? _search;
  AdminPlayerSummary? _summary;
  AdminAuditRecordList? _audit;
  AdminEconomyLedgerAuditResponse? _ledger;
  AdminEconomyBalanceDashboard? _economyDashboard;
  AdminContentModerationQueue? _contentQueue;
  AdminAntiAbuseReviewQueue? _antiAbuseQueue;
  String? _selectedPlayerId;
  String _selectedAction = 'note';
  bool _loading = false;
  String? _error;
  String? _message;

  String get _adminToken => _tokenController.text.trim();

  @override
  void initState() {
    super.initState();
    if (_adminToken.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAdminData());
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    _tokenController.dispose();
    _searchController.dispose();
    _reasonController.dispose();
    _suspensionHoursController.dispose();
    _contentResolutionController.dispose();
    super.dispose();
  }

  Future<void> _refreshAdminData() async {
    if (!_ensureToken()) {
      return;
    }

    await _runAdminRequest(() async {
      _economyDashboard = await _apiClient.fetchAdminEconomyDashboard(
        adminToken: _adminToken,
      );
      _audit = await _apiClient.fetchAdminAuditRecords(
        adminToken: _adminToken,
        playerId: _selectedPlayerId,
      );
      _contentQueue = await _apiClient.fetchAdminContentQueue(
        adminToken: _adminToken,
      );
      _antiAbuseQueue = await _apiClient.fetchAdminAntiAbuseQueue(
        adminToken: _adminToken,
        playerId: _selectedPlayerId,
      );
      if (_selectedPlayerId != null) {
        _ledger = await _apiClient.fetchAdminEconomyLedger(
          adminToken: _adminToken,
          playerId: _selectedPlayerId,
        );
      }
    });
  }

  Future<void> _searchPlayers() async {
    if (!_ensureToken()) {
      return;
    }

    await _runAdminRequest(() async {
      _search = await _apiClient.searchAdminPlayers(
        adminToken: _adminToken,
        query: _searchController.text,
      );
      _message = 'Found ${_search!.players.length} player(s).';
    });
  }

  Future<void> _selectPlayer(String playerId) async {
    if (!_ensureToken()) {
      return;
    }

    await _runAdminRequest(() async {
      _selectedPlayerId = playerId;
      _summary = await _apiClient.fetchAdminPlayerSummary(
        adminToken: _adminToken,
        playerId: playerId,
      );
      _audit = await _apiClient.fetchAdminAuditRecords(
        adminToken: _adminToken,
        playerId: playerId,
      );
      _ledger = await _apiClient.fetchAdminEconomyLedger(
        adminToken: _adminToken,
        playerId: playerId,
      );
      _antiAbuseQueue = await _apiClient.fetchAdminAntiAbuseQueue(
        adminToken: _adminToken,
        playerId: playerId,
      );
    });
  }

  Future<void> _createModerationRecord() async {
    final playerId = _selectedPlayerId;
    if (!_ensureToken() || playerId == null) {
      setState(() {
        _error = 'Select a player before taking moderation action.';
      });
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _error = 'A moderation reason is required.';
      });
      return;
    }

    DateTime? expiresAt;
    if (_selectedAction == 'suspension') {
      final hours = int.tryParse(_suspensionHoursController.text.trim());
      if (hours == null || hours <= 0) {
        setState(() {
          _error = 'Suspensions require a positive number of hours.';
        });
        return;
      }
      expiresAt = DateTime.now().toUtc().add(Duration(hours: hours));
    }

    await _runAdminRequest(() async {
      await _apiClient.createAdminModerationRecord(
        adminToken: _adminToken,
        playerId: playerId,
        type: _selectedAction,
        reason: reason,
        expiresAt: expiresAt,
      );
      _reasonController.clear();
      _summary = await _apiClient.fetchAdminPlayerSummary(
        adminToken: _adminToken,
        playerId: playerId,
      );
      _audit = await _apiClient.fetchAdminAuditRecords(
        adminToken: _adminToken,
        playerId: playerId,
      );
      _message = 'Moderation record saved.';
    });
  }

  Future<void> _reviewContentItem(
    AdminContentModerationItem item,
    String status,
    String action,
    String defaultResolution,
  ) async {
    if (!_ensureToken()) {
      return;
    }

    final resolution = _contentResolutionController.text.trim().isEmpty
        ? defaultResolution
        : _contentResolutionController.text.trim();
    await _runAdminRequest(() async {
      await _apiClient.reviewAdminContentQueueItem(
        adminToken: _adminToken,
        itemId: item.itemId,
        status: status,
        action: action,
        resolution: resolution,
      );
      _contentResolutionController.clear();
      _contentQueue = await _apiClient.fetchAdminContentQueue(
        adminToken: _adminToken,
      );
      _audit = await _apiClient.fetchAdminAuditRecords(
        adminToken: _adminToken,
        playerId: _selectedPlayerId,
      );
      _message = 'Content review saved.';
    });
  }

  Future<void> _reviewAntiAbuseEvent(
    AdminAntiAbuseReviewItem item,
    String status,
    String resolution,
  ) async {
    if (!_ensureToken()) {
      return;
    }

    await _runAdminRequest(() async {
      await _apiClient.reviewAdminAntiAbuseEvent(
        adminToken: _adminToken,
        eventId: item.eventId,
        status: status,
        resolution: resolution,
      );
      _antiAbuseQueue = await _apiClient.fetchAdminAntiAbuseQueue(
        adminToken: _adminToken,
        playerId: _selectedPlayerId,
      );
      _audit = await _apiClient.fetchAdminAuditRecords(
        adminToken: _adminToken,
        playerId: _selectedPlayerId,
      );
      _message = 'Anti-abuse review saved.';
    });
  }

  Future<void> _runAdminRequest(Future<void> Function() request) async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      _apiClient.bearerToken =
          Provider.of<LoginBloc>(context, listen: false).currentToken;
      await request();
    } on BackendApiException catch (e) {
      _error = e.message;
    } on Exception {
      _error = 'Could not reach admin services.';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _ensureToken() {
    if (_adminToken.isNotEmpty) {
      return true;
    }

    setState(() {
      _error = 'Enter or configure an admin token before loading tools.';
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin console'),
        actions: [
          if (_adminToken.isNotEmpty)
            IconButton(
              tooltip: 'Refresh admin data',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _refreshAdminData,
            ),
        ],
      ),
      body: _adminToken.isEmpty ? _lockedState(context) : _console(context),
    );
  }

  Widget _lockedState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Admin tools are locked',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure --dart-define=FF_ADMIN_TOKEN=... or enter an admin token. '
                  'No admin requests are made until a token is available.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin token',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _refreshAdminData(),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _refreshAdminData,
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Unlock console'),
                ),
                if (_error != null) _statusText(_error!, Colors.redAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _console(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) _statusText(_error!, Colors.redAccent),
          if (_message != null) _statusText(_message!, Colors.green),
          _searchCard(context),
          if (_summary != null) _summaryCard(context, _summary!),
          _moderationCard(context),
          _economyDashboardCard(context),
          _auditCard(context),
          _economyCard(context),
          _contentQueueCard(context),
          _antiAbuseQueueCard(context),
        ],
      ),
    );
  }

  Widget _searchCard(BuildContext context) {
    final players = _search?.players ?? const <AdminPlayerSearchEntry>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player search',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Player id, username, or email',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchPlayers(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _searchPlayers,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (players.isEmpty)
              const Text('No players loaded yet.')
            else
              ...players.map(
                (player) => ListTile(
                  leading: Icon(
                    player.activeModerationCount > 0
                        ? Icons.gavel
                        : Icons.person,
                  ),
                  title: Text('${player.username} (${player.playerId})'),
                  subtitle: Text(
                    'Level ${player.level ?? '-'} • ${player.walletGold ?? '-'} gold • ${player.email}',
                  ),
                  trailing: player.activeModerationCount > 0
                      ? Chip(
                          label: Text('${player.activeModerationCount} active'),
                          backgroundColor: Colors.orange.shade100,
                        )
                      : null,
                  selected: player.playerId == _selectedPlayerId,
                  onTap: _loading ? null : () => _selectPlayer(player.playerId),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, AdminPlayerSummary summary) {
    final identity = summary.identity;
    final progression = summary.progression;
    final wallet = summary.wallet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player summary',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(identity?.username ?? summary.playerId,
                style: Theme.of(context).textTheme.titleMedium),
            Text(identity?.email ?? 'No identity row'),
            const Divider(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Level', progression?.level.toString() ?? '-'),
                _metric('XP', progression?.experience.toString() ?? '-'),
                _metric('Strength', progression?.strength.toString() ?? '-'),
                _metric('Energy',
                    '${progression?.energy ?? '-'}/${progression?.maxEnergy ?? '-'}'),
                _metric('Gold', wallet?.gold.toString() ?? '-'),
                _metric('Active moderation',
                    summary.activeModerationRecords.length.toString()),
              ],
            ),
            if (summary.activeModerationRecords.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Active moderation'),
              ...summary.activeModerationRecords.map(_moderationTile),
            ],
            if (summary.latestNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Latest notes'),
              ...summary.latestNotes.map(_moderationTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moderationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Moderation action',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_selectedPlayerId == null
                ? 'Select a player to create bans, suspensions, or notes.'
                : 'Target: $_selectedPlayerId'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAction,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'note', child: Text('Moderator note')),
                DropdownMenuItem(value: 'ban', child: Text('Ban')),
                DropdownMenuItem(
                    value: 'suspension', child: Text('Suspension')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAction = value ?? 'note';
                });
              },
            ),
            if (_selectedAction == 'suspension') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _suspensionHoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Suspension hours',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason / note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading || _selectedPlayerId == null
                  ? null
                  : _createModerationRecord,
              icon: const Icon(Icons.save),
              label: const Text('Persist moderation record'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _auditCard(BuildContext context) {
    final records = _audit?.records ?? const <AdminAuditRecord>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin audit', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Text('No audit records yet.')
            else
              ...records.take(10).map(
                    (record) => ListTile(
                      dense: true,
                      title: Text(record.actionType),
                      subtitle: Text(
                        '${record.actorAdminId} • ${record.targetPlayerId ?? record.targetType}\n${record.details}',
                      ),
                      trailing: Text(_formatDate(record.createdAt)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _economyDashboardCard(BuildContext context) {
    final dashboard = _economyDashboard;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Economy balance dashboard',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (dashboard == null)
              const Text(
                  'Unlock or refresh admin tools to load real economy metrics.')
            else ...[
              Text(
                '${dashboard.days}-day window: ${_formatDate(dashboard.from)} – ${_formatDate(dashboard.to)}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metric('Wallet gold',
                      '${dashboard.gold.totalWalletGold} across ${dashboard.gold.walletCount} wallets'),
                  _metric(
                      'Gold created', dashboard.gold.goldCreated.toString()),
                  _metric('Gold sunk', dashboard.gold.goldSunk.toString()),
                  _metric(
                      'Net gold', _signedNumber(dashboard.gold.netGoldDelta)),
                  _metric('Items',
                      '${dashboard.items.totalQuantity} units / ${dashboard.items.itemKinds} kinds'),
                  _metric('Wages paid',
                      '${dashboard.wages.netWages} net (${dashboard.wages.taxGold} tax)'),
                  _metric('Taxes collected',
                      dashboard.taxes.taxCollected.toString()),
                  _metric('Factory output',
                      '${dashboard.factories.outputQuantity} units'),
                  _metric('Battle rewards',
                      dashboard.battles.goldRewards.toString()),
                ],
              ),
              _dashboardRows<AdminGoldEntryTypeFlow>(
                'Gold by ledger type',
                dashboard.gold.entryTypes.take(5).toList(),
                (entry) => ListTile(
                  dense: true,
                  title: Text(entry.entryType),
                  subtitle: Text('${entry.entryCount} ledger rows'),
                  trailing: Text(
                    '${_signedNumber(entry.netGoldDelta)} net',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
              _dashboardRows<AdminItemSupplyEntry>(
                'Top item supply',
                dashboard.items.topItems.take(5).toList(),
                (item) => ListTile(
                  dense: true,
                  title: Text('${item.name} (${item.itemId})'),
                  subtitle:
                      Text('${item.category} • ${item.holderCount} holder(s)'),
                  trailing: Text(
                    '${item.totalQuantity}\nP ${item.playerQuantity} / C ${item.companyQuantity}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
              _dashboardRows<AdminMarketPriceItemSummary>(
                'Price history',
                dashboard.prices.topItems.take(5).toList(),
                (item) => ListTile(
                  dense: true,
                  title: Text('${item.itemName} avg ${item.averagePrice}g'),
                  subtitle: Text(
                      '${item.quantityTraded} traded • ${item.tradeCount} trade(s)'),
                  trailing: Text('${item.minPrice}–${item.maxPrice}g'),
                ),
              ),
              _dashboardRows<AdminWageCompanySummary>(
                'Wages by company',
                dashboard.wages.topCompanies.take(5).toList(),
                (company) => ListTile(
                  dense: true,
                  title: Text(company.companyName),
                  subtitle: Text('${company.workRecordCount} work record(s)'),
                  trailing: Text(
                    '${company.netWages} net\n${company.taxGold} tax',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
              _dashboardRows<AdminCountryTaxSummary>(
                'Taxes by country',
                dashboard.taxes.countries.take(5).toList(),
                (country) => ListTile(
                  dense: true,
                  title: Text(country.countryName),
                  subtitle: Text(
                      'Rates I/M/P ${country.incomeTaxRate}/${country.marketTaxRate}/${country.productionTaxRate}%'),
                  trailing: Text(
                    '${country.taxCollected} tax\n${country.treasury} treasury',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
              _dashboardRows<AdminFactoryOutputItemSummary>(
                'Factory output by item',
                dashboard.factories.topItems.take(5).toList(),
                (item) => ListTile(
                  dense: true,
                  title: Text(item.itemId),
                  subtitle: Text('${item.runCount} run(s)'),
                  trailing: Text(item.outputQuantity.toString()),
                ),
              ),
              _dashboardRows<AdminBattleRewardByBattle>(
                'Battle rewards',
                dashboard.battles.topBattles.take(5).toList(),
                (battle) => ListTile(
                  dense: true,
                  title: Text(battle.battleName),
                  subtitle: Text('${battle.contributionCount} contribution(s)'),
                  trailing: Text(
                    '${battle.goldRewards}g\n${battle.damage} dmg',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _economyCard(BuildContext context) {
    final entries = _ledger?.entries ?? const <AdminEconomyLedgerEntry>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Economy audit',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_selectedPlayerId == null)
              const Text('Select a player to load focused economy ledger rows.')
            else if (entries.isEmpty)
              const Text('No economy ledger rows for selected player.')
            else
              ...entries.map(
                (entry) => ListTile(
                  dense: true,
                  title: Text('${entry.entryType}: ${entry.goldDelta} gold'),
                  subtitle: Text(entry.description),
                  trailing: Text(_formatDate(entry.createdAt)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contentQueueCard(BuildContext context) {
    final items = _contentQueue?.items ?? const <AdminContentModerationItem>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Content moderation queue',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _contentResolutionController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Resolution note for next action',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No open content reports.')
            else
              ...items.take(10).map(
                    (item) => Card(
                      color: item.status == 'open'
                          ? Colors.orange.shade50
                          : Colors.grey.shade100,
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.report),
                            title: Text(
                                '${item.sourceType} from ${item.playerId}'),
                            subtitle: Text(
                              [
                                item.reason,
                                '${item.reportCount} report(s) • action ${item.reviewAction}',
                                item.content,
                                if (item.resolution.isNotEmpty)
                                  'Resolution: ${item.resolution}',
                              ].join('\n'),
                            ),
                            trailing: Chip(label: Text(item.status)),
                          ),
                          ButtonBar(
                            children: [
                              TextButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _reviewContentItem(
                                          item,
                                          'dismissed',
                                          'none',
                                          'Dismissed after moderator review.',
                                        ),
                                icon: const Icon(Icons.close),
                                label: const Text('Dismiss'),
                              ),
                              TextButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _reviewContentItem(
                                          item,
                                          'resolved',
                                          'none',
                                          'Resolved after moderator review.',
                                        ),
                                icon: const Icon(Icons.check),
                                label: const Text('Resolve'),
                              ),
                              TextButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _reviewContentItem(
                                          item,
                                          'removed',
                                          'remove',
                                          'Removed content for policy violation.',
                                        ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove content'),
                              ),
                              TextButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _reviewContentItem(
                                          item,
                                          'resolved',
                                          'restore',
                                          'Restored content after review.',
                                        ),
                                icon: const Icon(Icons.restore),
                                label: const Text('Restore'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _antiAbuseQueueCard(BuildContext context) {
    final items = _antiAbuseQueue?.items ?? const <AdminAntiAbuseReviewItem>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anti-abuse review queue',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Persisted suspicious gameplay, trade, rate, and idempotency events.',
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No open anti-abuse events.')
            else
              ...items.take(10).map(
                    (item) => Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.security),
                            title:
                                Text('${item.actionType} • ${item.severity}'),
                            subtitle: Text(
                              '${item.playerId} ${item.username.isEmpty ? '' : '(${item.username})'}\n'
                              '${item.ruleId}: ${item.reason}\n'
                              'Ledger ${item.recentLedgerEntries} • market ${item.recentMarketFills} • activity ${item.recentActivityEvents}',
                            ),
                            trailing: Chip(label: Text(item.status)),
                          ),
                          ButtonBar(
                            alignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _reviewAntiAbuseEvent(
                                          item,
                                          'confirmed',
                                          'Confirmed suspicious activity after admin review.',
                                        ),
                                icon: const Icon(Icons.gpp_bad_outlined),
                                label: const Text('Confirm'),
                              ),
                              TextButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _reviewAntiAbuseEvent(
                                          item,
                                          'dismissed',
                                          'Dismissed after admin review.',
                                        ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Dismiss'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.blue.shade50,
    );
  }

  Widget _dashboardRows<T>(
    String title,
    List<T> rows,
    Widget Function(T item) builder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No persisted rows in this window.'),
            )
          else
            ...rows.map(builder),
        ],
      ),
    );
  }

  Widget _moderationTile(AdminModerationRecord record) {
    return ListTile(
      dense: true,
      leading: Icon(record.type == 'note' ? Icons.note : Icons.gavel),
      title: Text('${record.type}: ${record.reason}'),
      subtitle: Text(
        '${record.createdBy} • ${_formatDate(record.createdAt)}'
        '${record.expiresAt == null ? '' : ' • expires ${_formatDate(record.expiresAt)}'}',
      ),
    );
  }

  Widget _statusText(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _signedNumber(int value) {
    return value > 0 ? '+$value' : value.toString();
  }
}

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/ResourceLogisticsBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/ResourceLogistics.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ResourceLogisticsPage extends StatefulWidget {
  final User user;
  const ResourceLogisticsPage({super.key, required this.user});

  @override
  State<ResourceLogisticsPage> createState() => _ResourceLogisticsPageState();
}

class _ResourceLogisticsPageState extends State<ResourceLogisticsPage> {
  late final LoginBloc _loginBloc;
  late final CompaniesBloc _companiesBloc;
  late final ResourceLogisticsBloc _resourceBloc;
  String? _selectedCompanyId;
  String? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _companiesBloc = Provider.of<CompaniesBloc>(context, listen: false);
    _resourceBloc = Provider.of<ResourceLogisticsBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _companiesBloc.setBearerToken(_loginBloc.currentToken);
    _resourceBloc.setBearerToken(_loginBloc.currentToken);

    await _companiesBloc.load(widget.user.uid);
    final companies = _memberCompanies(_companiesBloc);
    if (!companies.any((company) => company.companyId == _selectedCompanyId)) {
      _selectedCompanyId = companies.isEmpty ? null : companies.first.companyId;
    }

    await _resourceBloc.load(companyId: _selectedCompanyId);
    final sites = _resourceBloc.resourceSites?.sites ?? const <ResourceSite>[];
    if (!sites.any((site) => site.siteId == _selectedSiteId)) {
      _selectedSiteId = sites.isEmpty ? null : sites.first.siteId;
    }
  }

  Future<void> _selectCompany(String? companyId) async {
    if (companyId == null) {
      return;
    }

    setState(() => _selectedCompanyId = companyId);
    _resourceBloc.setBearerToken(_loginBloc.currentToken);
    await _resourceBloc.loadDashboard(companyId);
  }

  Future<void> _startExtraction() async {
    final companyId = _selectedCompanyId;
    final site = _selectedSite;
    if (companyId == null || site == null) {
      _showMessage('Select a company and resource site first.');
      return;
    }

    _resourceBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _resourceBloc.startExtraction(
      companyId: companyId,
      site: site,
    );
    _showMessage(result?.message ?? _resourceBloc.error);
  }

  Future<void> _claimExtraction(CompanyExtractionJob job) async {
    final companyId = _selectedCompanyId;
    if (companyId == null) {
      _showMessage('Select a company before claiming extraction output.');
      return;
    }

    _resourceBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _resourceBloc.claimExtraction(
      companyId: companyId,
      job: job,
    );
    _showMessage(result?.message ?? _resourceBloc.error);
  }

  Future<void> _dispatchShipment() async {
    final companyId = _selectedCompanyId;
    final dashboard = _resourceBloc.dashboard;
    final sites = _resourceBloc.resourceSites?.sites ?? const <ResourceSite>[];
    if (companyId == null || dashboard == null || sites.length < 2) {
      _showMessage(
        'Need a company and at least two resource sites to dispatch.',
      );
      return;
    }

    final inventory = dashboard.assets.inventory
        .where((entry) => entry.quantity > 0)
        .toList();
    final item = inventory.isEmpty ? null : inventory.first;
    if (item == null) {
      _showMessage('Company inventory has no item available to ship.');
      return;
    }

    final origin = _selectedSite ?? sites.first;
    final destination = sites.firstWhere(
      (site) => site.regionId != origin.regionId,
      orElse: () => sites.last,
    );
    _resourceBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _resourceBloc.dispatchShipment(
      companyId: companyId,
      item: item,
      origin: origin,
      destination: destination,
      quantity: 1,
    );
    _showMessage(result?.message ?? _resourceBloc.error);
  }

  Future<void> _deliverShipment(CompanyShipment shipment) async {
    final companyId = _selectedCompanyId;
    if (companyId == null) {
      _showMessage('Select a company before delivering shipments.');
      return;
    }

    _resourceBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _resourceBloc.deliverShipment(
      companyId: companyId,
      shipment: shipment,
    );
    _showMessage(result?.message ?? _resourceBloc.error);
  }

  ResourceSite? get _selectedSite {
    final sites = _resourceBloc.resourceSites?.sites ?? const <ResourceSite>[];
    if (sites.isEmpty) {
      return null;
    }

    return sites.firstWhere(
      (site) => site.siteId == _selectedSiteId,
      orElse: () => sites.first,
    );
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
      backgroundColor: const Color(0xFF08111E),
      appBar: AppBar(
        title: const Text('Resources & logistics'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh logistics',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Consumer2<CompaniesBloc, ResourceLogisticsBloc>(
        builder: (context, companiesBloc, resourceBloc, _) {
          if ((companiesBloc.isLoading && companiesBloc.portfolio == null) ||
              (resourceBloc.isLoading && resourceBloc.resourceSites == null)) {
            return const Center(child: CircularProgressIndicator());
          }

          final companies = _memberCompanies(companiesBloc);
          final sites =
              resourceBloc.resourceSites?.sites ?? const <ResourceSite>[];
          final dashboard =
              resourceBloc.dashboard?.companyId == _selectedCompanyId
                  ? resourceBloc.dashboard
                  : null;
          final selectedCompany = _companyFor(companies, _selectedCompanyId);

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (companiesBloc.error != null)
                  _LogisticsMessageCard(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    message: companiesBloc.error!,
                  ),
                if (resourceBloc.error != null)
                  _LogisticsMessageCard(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    message: resourceBloc.error!,
                  ),
                if (resourceBloc.lastExtraction != null)
                  _ExtractionNotice(result: resourceBloc.lastExtraction!),
                if (resourceBloc.lastClaim != null)
                  _ExtractionClaimNotice(result: resourceBloc.lastClaim!),
                if (resourceBloc.lastShipment != null)
                  _ShipmentNotice(result: resourceBloc.lastShipment!),
                _LogisticsHero(
                  companies: companies,
                  selectedCompany: selectedCompany,
                  sites: sites,
                  dashboard: dashboard,
                ),
                const SizedBox(height: 16),
                _SelectorCard(
                  companies: companies,
                  selectedCompanyId: _selectedCompanyId,
                  onCompanyChanged: _selectCompany,
                  sites: sites,
                  selectedSiteId: _selectedSiteId,
                  onSiteChanged: (siteId) {
                    setState(() => _selectedSiteId = siteId);
                  },
                  isMutating: resourceBloc.isMutating,
                  onStartExtraction: _startExtraction,
                  onDispatchShipment: _dispatchShipment,
                ),
                const SizedBox(height: 16),
                _SitesCard(sites: sites, selectedSiteId: _selectedSiteId),
                if (dashboard != null) ...[
                  const SizedBox(height: 16),
                  _AssetsCard(assets: dashboard.assets),
                  const SizedBox(height: 16),
                  _ExtractionsCard(
                    jobs: dashboard.extractions,
                    claimingIds: resourceBloc.claimingExtractionIds,
                    onClaim: _claimExtraction,
                  ),
                  const SizedBox(height: 16),
                  _ShipmentsCard(
                    shipments: dashboard.shipments,
                    deliveringIds: resourceBloc.deliveringShipmentIds,
                    onDeliver: _deliverShipment,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  const _EmptyLogisticsPanel(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogisticsHero extends StatelessWidget {
  final List<CompanySummary> companies;
  final CompanySummary? selectedCompany;
  final List<ResourceSite> sites;
  final ResourceLogisticsDashboard? dashboard;

  const _LogisticsHero({
    required this.companies,
    required this.selectedCompany,
    required this.sites,
    required this.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    final readyExtractions =
        dashboard?.extractions.where((job) => job.canClaim).length ?? 0;
    final activeExtractions =
        dashboard?.extractions.where((job) => !job.isClaimed).length ?? 0;
    final activeShipments = dashboard?.shipments
            .where((shipment) => !shipment.isDelivered)
            .length ??
        0;
    final inTransit = dashboard?.inTransitQuantity ?? 0;
    final companyName = selectedCompany?.name ?? 'Company logistics network';

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
              Color(0xFF164E63),
              Color(0xFF365314),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -26,
              child: Icon(
                Icons.local_shipping,
                size: 176,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -24,
              child: Icon(
                Icons.terrain,
                size: 126,
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
                          Icons.conveyor_belt,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const Spacer(),
                      _NeonPill(
                        label: readyExtractions > 0
                            ? '$readyExtractions ready'
                            : dashboard == null
                                ? 'Select company'
                                : activeShipments > 0
                                    ? 'In transit'
                                    : 'Operational',
                        color: readyExtractions > 0
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF67E8F9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Resource Logistics',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$companyName coordinates extraction sites, company storage, and shipments across regions.',
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
                        icon: Icons.business,
                        label: 'Companies',
                        value: companies.length.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.terrain,
                        label: 'Sites',
                        value: sites.length.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.handyman,
                        label: 'Extraction',
                        value: activeExtractions.toString(),
                      ),
                      _HeroStat(
                        icon: Icons.inventory_2,
                        label: 'In transit',
                        value: Utils.number(inTransit),
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

class _SelectorCard extends StatelessWidget {
  final List<CompanySummary> companies;
  final String? selectedCompanyId;
  final ValueChanged<String?> onCompanyChanged;
  final List<ResourceSite> sites;
  final String? selectedSiteId;
  final ValueChanged<String?> onSiteChanged;
  final bool isMutating;
  final VoidCallback onStartExtraction;
  final VoidCallback onDispatchShipment;

  const _SelectorCard({
    required this.companies,
    required this.selectedCompanyId,
    required this.onCompanyChanged,
    required this.sites,
    required this.selectedSiteId,
    required this.onSiteChanged,
    required this.isMutating,
    required this.onStartExtraction,
    required this.onDispatchShipment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.route,
                    color: Color(0xFF67E8F9),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operate resource network',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Choose a company, select a site, then run extraction or shipping orders.',
                        style: TextStyle(color: Color(0xFFA7B3C5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DarkDropdown(
              label: 'Company',
              icon: Icons.business,
              value: companies.any(
                (company) => company.companyId == selectedCompanyId,
              )
                  ? selectedCompanyId
                  : null,
              items: companies
                  .map(
                    (company) => DropdownMenuItem(
                      value: company.companyId,
                      child: Text(company.name),
                    ),
                  )
                  .toList(),
              onChanged: companies.isEmpty ? null : onCompanyChanged,
            ),
            const SizedBox(height: 12),
            _DarkDropdown(
              label: 'Resource site',
              icon: Icons.terrain,
              value: sites.any((site) => site.siteId == selectedSiteId)
                  ? selectedSiteId
                  : null,
              items: sites
                  .map(
                    (site) => DropdownMenuItem(
                      value: site.siteId,
                      child: Text('${site.siteName} (${site.itemName})'),
                    ),
                  )
                  .toList(),
              onChanged: sites.isEmpty ? null : onSiteChanged,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: isMutating ? null : onStartExtraction,
                  icon: isMutating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.construction),
                  label:
                      Text(isMutating ? 'Processing...' : 'Start extraction'),
                ),
                OutlinedButton.icon(
                  onPressed: isMutating ? null : onDispatchShipment,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Dispatch shipment'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF67E8F9),
                    side: BorderSide(
                      color: const Color(0xFF67E8F9).withOpacity(0.45),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  const _DarkDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF0F2136),
      iconEnabledColor: Colors.white70,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.66)),
        prefixIcon: Icon(icon, color: const Color(0xFF67E8F9)),
        filled: true,
        fillColor: const Color(0xFF0B1728),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF67E8F9)),
        ),
      ),
    );
  }
}

class _SitesCard extends StatelessWidget {
  final List<ResourceSite> sites;
  final String? selectedSiteId;

  const _SitesCard({required this.sites, required this.selectedSiteId});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.terrain,
      title: 'World resource sites',
      subtitle: '${sites.length} extraction site(s) available',
      color: const Color(0xFFA3E635),
      child: sites.isEmpty
          ? const _InlineEmpty(
              icon: Icons.public_off,
              message: 'No resource sites available.',
            )
          : Column(
              children: sites
                  .map(
                    (site) => _ResourceSiteTile(
                      site: site,
                      isSelected: site.siteId == selectedSiteId,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ResourceSiteTile extends StatelessWidget {
  final ResourceSite site;
  final bool isSelected;

  const _ResourceSiteTile({required this.site, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = site.isDepleted
        ? Colors.redAccent
        : isSelected
            ? const Color(0xFF67E8F9)
            : const Color(0xFFA3E635);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(isSelected ? 0.45 : 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_resourceIcon(site), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            site.siteName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const _NeonPill(
                            label: 'Selected',
                            color: Color(0xFF67E8F9),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${site.resourceName} -> ${site.itemName}',
                      style: TextStyle(color: Colors.white.withOpacity(0.66)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(
                icon: Icons.trending_up,
                label: '${site.baseYield} yield',
              ),
              _MiniStat(
                icon: Icons.workspace_premium,
                label: '${site.qualityPercent}% quality',
              ),
              _MiniStat(
                icon: Icons.timer,
                label: _formatDuration(
                  Duration(seconds: site.extractionSeconds),
                ),
              ),
              _MiniStat(
                icon: Icons.done_all,
                label: '${site.extractionCount} runs',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressLine(
            label: site.isDepleted ? 'Reserve depleted' : 'Reserve remaining',
            valueLabel:
                '${Utils.number(site.reserveRemaining)}/${Utils.number(site.reserveCapacity)}',
            value: site.reserveRatio,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _AssetsCard extends StatelessWidget {
  final CompanyAssets assets;

  const _AssetsCard({required this.assets});

  @override
  Widget build(BuildContext context) {
    final storageRatio = assets.storageLimit <= 0
        ? 0.0
        : (assets.storageUsed / assets.storageLimit).clamp(0, 1).toDouble();

    return _SectionCard(
      icon: Icons.inventory_2,
      title: 'Company storage',
      subtitle: 'Wallet, storage pressure, and movable inventory',
      color: const Color(0xFF67E8F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(
                icon: Icons.monetization_on,
                label: '${Utils.number(assets.walletGold)} gold',
              ),
              _MiniStat(
                icon: Icons.inventory,
                label: '${assets.inventory.length} item stacks',
              ),
              _MiniStat(
                icon: Icons.warehouse,
                label: '${assets.storageUsed}/${assets.storageLimit} storage',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressLine(
            label: 'Storage capacity',
            valueLabel: '${assets.storageUsed}/${assets.storageLimit}',
            value: storageRatio,
            color: storageRatio > 0.85
                ? Colors.orangeAccent
                : const Color(0xFF67E8F9),
          ),
          const SizedBox(height: 14),
          if (assets.inventory.isEmpty)
            const _InlineEmpty(
              icon: Icons.inventory_2_outlined,
              message: 'Company storage is empty.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  assets.inventory.map((item) => _InventoryChip(item)).toList(),
            ),
        ],
      ),
    );
  }
}

class _InventoryChip extends StatelessWidget {
  final InventoryItem item;

  const _InventoryChip(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _itemIcon(item),
            color: const Color(0xFF67E8F9),
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            '${item.name}: ${Utils.number(item.quantity)}',
            style: TextStyle(color: Colors.white.withOpacity(0.78)),
          ),
        ],
      ),
    );
  }
}

class _ExtractionsCard extends StatelessWidget {
  final List<CompanyExtractionJob> jobs;
  final Set<String> claimingIds;
  final ValueChanged<CompanyExtractionJob> onClaim;

  const _ExtractionsCard({
    required this.jobs,
    required this.claimingIds,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final readyCount = jobs.where((job) => job.canClaim).length;

    return _SectionCard(
      icon: Icons.handyman,
      title: 'Extraction queue',
      subtitle: readyCount > 0
          ? '$readyCount job(s) ready to claim'
          : '${jobs.length} extraction job(s)',
      color: const Color(0xFFA3E635),
      child: jobs.isEmpty
          ? const _InlineEmpty(
              icon: Icons.construction,
              message: 'No extraction jobs yet.',
            )
          : Column(
              children: jobs
                  .map(
                    (job) => _ExtractionJobTile(
                      job: job,
                      isClaiming: claimingIds.contains(job.jobId),
                      onClaim: () => onClaim(job),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ExtractionJobTile extends StatelessWidget {
  final CompanyExtractionJob job;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _ExtractionJobTile({
    required this.job,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final color = job.canClaim
        ? const Color(0xFF22C55E)
        : job.isClaimed
            ? Colors.white54
            : const Color(0xFF38BDF8);
    final progress = job.canClaim || job.isClaimed
        ? 1.0
        : _timeProgress(job.startedAt, job.completesAt);

    return _TimelineTile(
      color: color,
      icon: job.canClaim
          ? Icons.check_circle
          : job.isClaimed
              ? Icons.inventory_2
              : Icons.hourglass_bottom,
      title: '${job.resourceName} -> ${job.itemName} x${job.yieldQuantity}',
      subtitle: '${_titleCase(job.status)} in ${job.regionName}',
      progressLabel: job.canClaim
          ? 'Output ready'
          : job.isClaimed
              ? 'Claimed'
              : 'Ready ${_format(job.completesAt)}',
      progress: progress,
      stats: [
        _MiniStat(icon: Icons.input, label: '${job.requestedRuns} run(s)'),
        _MiniStat(icon: Icons.output, label: '${job.baseYield} base yield'),
        _MiniStat(
          icon: Icons.timer,
          label: _formatDuration(Duration(seconds: job.durationSeconds)),
        ),
      ],
      trailing: job.canClaim
          ? ElevatedButton.icon(
              onPressed: isClaiming ? null : onClaim,
              icon: isClaiming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory),
              label: Text(isClaiming ? 'Claiming...' : 'Claim'),
            )
          : null,
    );
  }
}

class _ShipmentsCard extends StatelessWidget {
  final List<CompanyShipment> shipments;
  final Set<String> deliveringIds;
  final ValueChanged<CompanyShipment> onDeliver;

  const _ShipmentsCard({
    required this.shipments,
    required this.deliveringIds,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    final readyCount =
        shipments.where((shipment) => shipment.canDeliver).length;

    return _SectionCard(
      icon: Icons.local_shipping,
      title: 'Shipping lanes',
      subtitle: readyCount > 0
          ? '$readyCount shipment(s) ready to deliver'
          : '${shipments.length} shipment(s)',
      color: const Color(0xFF67E8F9),
      child: shipments.isEmpty
          ? const _InlineEmpty(
              icon: Icons.local_shipping_outlined,
              message: 'No shipments dispatched yet.',
            )
          : Column(
              children: shipments
                  .map(
                    (shipment) => _ShipmentTile(
                      shipment: shipment,
                      isDelivering: deliveringIds.contains(shipment.shipmentId),
                      onDeliver: () => onDeliver(shipment),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ShipmentTile extends StatelessWidget {
  final CompanyShipment shipment;
  final bool isDelivering;
  final VoidCallback onDeliver;

  const _ShipmentTile({
    required this.shipment,
    required this.isDelivering,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    final color = shipment.canDeliver
        ? const Color(0xFF22C55E)
        : shipment.isDelivered
            ? Colors.white54
            : const Color(0xFF38BDF8);
    final progress = shipment.canDeliver || shipment.isDelivered
        ? 1.0
        : _timeProgress(shipment.dispatchedAt, shipment.arrivesAt);

    return _TimelineTile(
      color: color,
      icon: shipment.canDeliver
          ? Icons.check_circle
          : shipment.isDelivered
              ? Icons.markunread_mailbox
              : Icons.local_shipping,
      title: '${shipment.itemName} x${shipment.quantity}',
      subtitle:
          '${shipment.originRegionName} -> ${shipment.destinationRegionName}',
      progressLabel: shipment.canDeliver
          ? 'Shipment arrived'
          : shipment.isDelivered
              ? 'Delivered'
              : 'Arrives ${_format(shipment.arrivesAt)}',
      progress: progress,
      stats: [
        _MiniStat(icon: Icons.route, label: _titleCase(shipment.status)),
        _MiniStat(
          icon: Icons.timer,
          label: _formatDuration(Duration(seconds: shipment.durationSeconds)),
        ),
        if (shipment.lastError != null)
          _MiniStat(icon: Icons.warning, label: shipment.lastError!),
      ],
      trailing: shipment.canDeliver
          ? ElevatedButton.icon(
              onPressed: isDelivering ? null : onDeliver,
              icon: isDelivering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory),
              label: Text(isDelivering ? 'Delivering...' : 'Deliver'),
            )
          : null,
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String progressLabel;
  final double progress;
  final List<Widget> stats;
  final Widget? trailing;

  const _TimelineTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.progress,
    required this.stats,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.64)),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: stats),
          const SizedBox(height: 10),
          _ProgressLine(
            label: progressLabel,
            valueLabel: '${(progress * 100).round()}%',
            value: progress,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withOpacity(0.42)),
                  ),
                  child: Icon(icon, color: color),
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
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.64)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1728),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractionNotice extends StatelessWidget {
  final ExtractionMutationResult result;

  const _ExtractionNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _LogisticsMessageCard(
      message:
          '${result.message} ${result.extraction.resourceName} extraction is queued for ${_format(result.extraction.completesAt)}.',
      icon: result.completed ? Icons.construction : Icons.info_outline,
      color:
          result.completed ? const Color(0xFF22C55E) : const Color(0xFFF97316),
    );
  }
}

class _ExtractionClaimNotice extends StatelessWidget {
  final ExtractionClaimResult result;

  const _ExtractionClaimNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    final depletion = result.resourceDepletion == null
        ? ''
        : ' Reserve now ${Utils.number(result.resourceDepletion!.site.reserveRemaining)}.';
    return _LogisticsMessageCard(
      message:
          '${result.message} Claimed ${result.extraction.yieldQuantity} ${result.extraction.itemName}. Depleted ${result.depletionAmount} reserve.$depletion',
      icon: Icons.inventory_2,
      color: const Color(0xFF22C55E),
    );
  }
}

class _ShipmentNotice extends StatelessWidget {
  final ShipmentMutationResult result;

  const _ShipmentNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    return _LogisticsMessageCard(
      message:
          '${result.message} ${result.shipment.itemName} x${result.shipment.quantity}: ${result.shipment.originRegionName} -> ${result.shipment.destinationRegionName}.',
      icon: result.completed ? Icons.local_shipping : Icons.info_outline,
      color:
          result.completed ? const Color(0xFF22C55E) : const Color(0xFFF97316),
    );
  }
}

class _LogisticsMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _LogisticsMessageCard({
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

class _EmptyLogisticsPanel extends StatelessWidget {
  const _EmptyLogisticsPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.business_center_outlined,
              color: Color(0xFF67E8F9),
              size: 54,
            ),
            const SizedBox(height: 14),
            const Text(
              'No company logistics selected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join or create a company to manage extraction jobs, inventory, and regional shipments.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.66)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.55)),
          const SizedBox(width: 10),
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

class _ProgressLine extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  const _ProgressLine({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(color: Colors.white.withOpacity(0.66)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 9,
            backgroundColor: Colors.white.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

List<CompanySummary> _memberCompanies(CompaniesBloc bloc) {
  return bloc.portfolio?.companies
          .where((company) => company.isMember)
          .toList() ??
      const <CompanySummary>[];
}

CompanySummary? _companyFor(List<CompanySummary> companies, String? companyId) {
  for (final company in companies) {
    if (company.companyId == companyId) {
      return company;
    }
  }
  return null;
}

IconData _resourceIcon(ResourceSite site) {
  final category = site.itemCategory.toLowerCase();
  final resource = site.resourceName.toLowerCase();
  if (category.contains('food') || resource.contains('grain')) {
    return Icons.grass;
  }
  if (category.contains('weapon') || resource.contains('iron')) {
    return Icons.hardware;
  }
  if (resource.contains('oil') || resource.contains('fuel')) {
    return Icons.oil_barrel;
  }
  return Icons.terrain;
}

IconData _itemIcon(InventoryItem item) {
  final category = item.category.toLowerCase();
  if (category.contains('food')) {
    return Icons.restaurant;
  }
  if (category.contains('weapon')) {
    return Icons.gpp_good;
  }
  if (category.contains('resource') || category.contains('raw')) {
    return Icons.terrain;
  }
  return Icons.inventory_2;
}

double _timeProgress(DateTime startedAt, DateTime completesAt) {
  final totalSeconds = completesAt.difference(startedAt).inSeconds;
  if (totalSeconds <= 0) {
    return 1;
  }
  final elapsedSeconds = DateTime.now().difference(startedAt).inSeconds;
  return (elapsedSeconds / totalSeconds).clamp(0, 1).toDouble();
}

String _format(DateTime value) {
  return DateFormat.yMd().add_Hm().format(value.toLocal());
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  if (minutes <= 0) {
    return '${seconds}s';
  }
  return '${minutes}m ${seconds}s';
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

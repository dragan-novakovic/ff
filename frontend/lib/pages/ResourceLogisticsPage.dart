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
    final companies = _companiesBloc.portfolio?.companies
            .where((company) => company.isMember)
            .toList() ??
        const <CompanySummary>[];
    _selectedCompanyId ??= companies.isEmpty ? null : companies.first.companyId;
    await _resourceBloc.load(companyId: _selectedCompanyId);
    final sites = _resourceBloc.resourceSites?.sites ?? const <ResourceSite>[];
    _selectedSiteId ??= sites.isEmpty ? null : sites.first.siteId;
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
          'Need a company and at least two resource sites to dispatch.');
      return;
    }
    final item = dashboard.assets.inventory
        .where((entry) => entry.quantity > 0)
        .cast<InventoryItem?>()
        .firstWhere((entry) => entry != null, orElse: () => null);
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
      appBar: AppBar(title: const Text('Resources & logistics')),
      body: Consumer2<CompaniesBloc, ResourceLogisticsBloc>(
        builder: (context, companiesBloc, resourceBloc, _) {
          final companies = companiesBloc.portfolio?.companies
                  .where((company) => company.isMember)
                  .toList() ??
              const <CompanySummary>[];
          final sites =
              resourceBloc.resourceSites?.sites ?? const <ResourceSite>[];
          final dashboard = resourceBloc.dashboard;

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (resourceBloc.error != null)
                  _NoticeCard(
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                    message: resourceBloc.error!,
                  ),
                _SelectorCard(
                  companies: companies,
                  selectedCompanyId: _selectedCompanyId,
                  onCompanyChanged: _selectCompany,
                  sites: sites,
                  selectedSiteId: _selectedSiteId,
                  onSiteChanged: (siteId) =>
                      setState(() => _selectedSiteId = siteId),
                  onStartExtraction:
                      resourceBloc.isMutating ? null : _startExtraction,
                  onDispatchShipment:
                      resourceBloc.isMutating ? null : _dispatchShipment,
                ),
                _SitesCard(sites: sites),
                if (dashboard != null) ...[
                  _AssetsCard(assets: dashboard.assets),
                  _ExtractionsCard(
                    jobs: dashboard.extractions,
                    claimingIds: resourceBloc.claimingExtractionIds,
                    onClaim: _claimExtraction,
                  ),
                  _ShipmentsCard(
                    shipments: dashboard.shipments,
                    deliveringIds: resourceBloc.deliveringShipmentIds,
                    onDeliver: _deliverShipment,
                  ),
                ] else if (!resourceBloc.isLoading)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.business),
                      title: Text('Select a company to view logistics.'),
                    ),
                  ),
              ],
            ),
          );
        },
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
  final VoidCallback? onStartExtraction;
  final VoidCallback? onDispatchShipment;

  const _SelectorCard({
    required this.companies,
    required this.selectedCompanyId,
    required this.onCompanyChanged,
    required this.sites,
    required this.selectedSiteId,
    required this.onSiteChanged,
    required this.onStartExtraction,
    required this.onDispatchShipment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operate company resources',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: companies
                      .any((company) => company.companyId == selectedCompanyId)
                  ? selectedCompanyId
                  : null,
              items: companies
                  .map((company) => DropdownMenuItem(
                        value: company.companyId,
                        child: Text(company.name),
                      ))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Company'),
              onChanged: companies.isEmpty ? null : onCompanyChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: sites.any((site) => site.siteId == selectedSiteId)
                  ? selectedSiteId
                  : null,
              items: sites
                  .map((site) => DropdownMenuItem(
                        value: site.siteId,
                        child: Text('${site.siteName} (${site.itemName})'),
                      ))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Resource site'),
              onChanged: sites.isEmpty ? null : onSiteChanged,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: onStartExtraction,
                  icon: const Icon(Icons.construction),
                  label: const Text('Start extraction'),
                ),
                OutlinedButton.icon(
                  onPressed: onDispatchShipment,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Dispatch shipment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SitesCard extends StatelessWidget {
  final List<ResourceSite> sites;
  const _SitesCard({required this.sites});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.terrain),
        title: Text('World resource sites (${sites.length})'),
        children: sites.isEmpty
            ? const [ListTile(title: Text('No resource sites available.'))]
            : sites
                .map((site) => ListTile(
                      title: Text(site.siteName),
                      subtitle: Text(
                        '${site.resourceName} - yield ${site.baseYield} - reserve ${Utils.number(site.reserveRemaining)}/${Utils.number(site.reserveCapacity)}',
                      ),
                      trailing: SizedBox(
                        width: 72,
                        child:
                            LinearProgressIndicator(value: site.reserveRatio),
                      ),
                    ))
                .toList(),
      ),
    );
  }
}

class _AssetsCard extends StatelessWidget {
  final CompanyAssets assets;
  const _AssetsCard({required this.assets});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2),
        title: Text(
            'Company storage ${assets.storageUsed}/${assets.storageLimit}'),
        subtitle: Text(
          assets.inventory.isEmpty
              ? 'No inventory yet.'
              : assets.inventory
                  .map((item) => '${item.name}: ${Utils.number(item.quantity)}')
                  .join('  |  '),
        ),
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
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.handyman),
        title: Text('Extraction jobs (${jobs.length})'),
        children: jobs.isEmpty
            ? const [ListTile(title: Text('No extraction jobs yet.'))]
            : jobs
                .map((job) => ListTile(
                      title: Text(
                          '${job.resourceName} -> ${job.itemName} x${job.yieldQuantity}'),
                      subtitle: Text(
                        '${job.status} - completes ${_format(job.completesAt)}',
                      ),
                      trailing: job.canClaim && !claimingIds.contains(job.jobId)
                          ? ElevatedButton(
                              onPressed: () => onClaim(job),
                              child: const Text('Claim'),
                            )
                          : null,
                    ))
                .toList(),
      ),
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
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.local_shipping),
        title: Text('Shipments (${shipments.length})'),
        children: shipments.isEmpty
            ? const [ListTile(title: Text('No shipments dispatched yet.'))]
            : shipments
                .map((shipment) => ListTile(
                      title: Text(
                        '${shipment.itemName} x${shipment.quantity} to ${shipment.destinationRegionName}',
                      ),
                      subtitle: Text([
                        shipment.status,
                        'arrives ${_format(shipment.arrivesAt)}',
                        if (shipment.lastError != null) shipment.lastError!,
                      ].join(' - ')),
                      trailing: shipment.canDeliver &&
                              !deliveringIds.contains(shipment.shipmentId)
                          ? ElevatedButton(
                              onPressed: () => onDeliver(shipment),
                              child: const Text('Deliver'),
                            )
                          : null,
                    ))
                .toList(),
      ),
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
      color: color.withOpacity(0.08),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(message),
      ),
    );
  }
}

String _format(DateTime value) {
  return DateFormat.yMd().add_Hm().format(value.toLocal());
}

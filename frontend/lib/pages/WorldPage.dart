import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorldPage extends StatefulWidget {
  final User user;
  const WorldPage({super.key, required this.user});

  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage> {
  late final WorldBloc _worldBloc;
  late final LoginBloc _loginBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;

  @override
  void initState() {
    super.initState();
    _worldBloc = Provider.of<WorldBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _worldBloc.setBearerToken(_loginBloc.currentToken);
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await Future.wait([
      _worldBloc.load(widget.user.uid),
      _onboardingBloc.load(widget.user.uid),
    ]);
  }

  Future<void> _join(WorldCountry country) async {
    await _applyCitizenship(country, isJoin: true);
  }

  Future<void> _change(WorldCountry country) async {
    await _applyCitizenship(country, isJoin: false);
  }

  Future<void> _applyCitizenship(
    WorldCountry country, {
    required bool isJoin,
  }) async {
    _worldBloc.setBearerToken(_loginBloc.currentToken);
    final result = isJoin
        ? await _worldBloc.join(
            playerId: widget.user.uid,
            countryId: country.countryId,
          )
        : await _worldBloc.change(
            playerId: widget.user.uid,
            countryId: country.countryId,
          );
    if (result?.completed == true) {
      await _onboardingBloc.load(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _worldBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _editPolicy(CountryTreasury treasury) async {
    final incomeController = TextEditingController(
      text: treasury.policy.incomeTaxRate.toString(),
    );
    final marketController = TextEditingController(
      text: treasury.policy.marketTaxRate.toString(),
    );
    final productionController = TextEditingController(
      text: treasury.policy.productionTaxRate.toString(),
    );

    final result = await showDialog<CountryTaxPolicyUpdateResult?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update ${treasury.name} tax policy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TaxRateField(
                controller: incomeController,
                label: 'Income tax %',
              ),
              _TaxRateField(
                controller: marketController,
                label: 'Market tax %',
              ),
              _TaxRateField(
                controller: productionController,
                label: 'Production tax %',
              ),
              const SizedBox(height: 8),
              const Text('Rates must be between 0% and 50%.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final income = int.tryParse(incomeController.text.trim());
                final market = int.tryParse(marketController.text.trim());
                final production =
                    int.tryParse(productionController.text.trim());
                final rates = [income, market, production];
                if (rates
                    .any((rate) => rate == null || rate < 0 || rate > 50)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Tax rates must be whole numbers from 0 to 50.'),
                    ),
                  );
                  return;
                }

                _worldBloc.setBearerToken(_loginBloc.currentToken);
                final update = await _worldBloc.updateTaxPolicy(
                  countryId: treasury.countryId,
                  incomeTaxRate: income!,
                  marketTaxRate: market!,
                  productionTaxRate: production!,
                );
                if (context.mounted) {
                  Navigator.of(context).pop(update);
                }
              },
              child: const Text('Save policy'),
            ),
          ],
        );
      },
    );

    incomeController.dispose();
    marketController.dispose();
    productionController.dispose();

    if (!mounted) {
      return;
    }

    final message = result?.message ?? _worldBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('World')),
      body: Consumer<WorldBloc>(
        builder: (context, bloc, _) {
          final catalog = bloc.catalog;
          if (bloc.isLoading && catalog == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && catalog == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          if (catalog == null) {
            return _ErrorState(
              message: 'World countries have not loaded yet.',
              onRetry: _load,
            );
          }

          final regionsByCountry = <String, List<WorldRegion>>{};
          for (final region in bloc.regions?.regions ?? <WorldRegion>[]) {
            regionsByCountry
                .putIfAbsent(region.countryId, () => [])
                .add(region);
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OnboardingGuidanceCard(
                  questline: context.watch<OnboardingQuestlineBloc>().questline,
                  route: '/world',
                ),
                _CitizenshipCard(
                  citizenship: bloc.citizenship,
                  lastMutation: bloc.lastMutation,
                ),
                const SizedBox(height: 12),
                if (bloc.treasury != null) ...[
                  _TreasuryCard(
                    treasury: bloc.treasury!,
                    isUpdating: bloc.isUpdatingPolicy,
                    onEdit: bloc.treasury!.authorization.canUpdatePolicy
                        ? () => _editPolicy(bloc.treasury!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                ...catalog.countries.map((country) {
                  final countryRegions = regionsByCountry[country.countryId] ??
                      (country.regions.isEmpty
                          ? <WorldRegion>[]
                          : country.regions);
                  final isCurrent =
                      bloc.citizenship?.countryId == country.countryId;
                  final hasCitizenship = bloc.citizenship != null;
                  return _CountryCard(
                    country: country,
                    regions: countryRegions,
                    isCurrent: isCurrent,
                    isUpdating:
                        bloc.updatingCountryIds.contains(country.countryId),
                    actionLabel: hasCitizenship ? 'Change country' : 'Join',
                    onAction: isCurrent
                        ? null
                        : () =>
                            hasCitizenship ? _change(country) : _join(country),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CitizenshipCard extends StatelessWidget {
  final PlayerCitizenship? citizenship;
  final CitizenshipMutationResult? lastMutation;
  const _CitizenshipCard({
    required this.citizenship,
    required this.lastMutation,
  });

  @override
  Widget build(BuildContext context) {
    final current = citizenship;
    return Card(
      color: current == null ? Colors.orange.shade50 : Colors.green.shade50,
      child: ListTile(
        leading: Icon(
          current == null ? Icons.flag_outlined : Icons.verified_user,
          color: current == null ? Colors.orange : Colors.green,
        ),
        title: Text(
          current == null
              ? 'No citizenship assigned'
              : '${current.countryName} citizenship (${current.status})',
        ),
        subtitle: Text(
          current == null
              ? 'Choose a country below to persist your citizenship.'
              : 'Joined ${_formatDate(current.joinedAt)}. ${lastMutation?.message ?? 'Citizenship is persisted in the world service.'}',
        ),
      ),
    );
  }
}

class _TreasuryCard extends StatelessWidget {
  final CountryTreasury treasury;
  final bool isUpdating;
  final VoidCallback? onEdit;

  const _TreasuryCard({
    required this.treasury,
    required this.isUpdating,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final recent = treasury.recentLedger.take(3).toList();
    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${treasury.name} treasury',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (onEdit != null)
                  ElevatedButton.icon(
                    onPressed: isUpdating ? null : onEdit,
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.tune),
                    label: Text(isUpdating ? 'Saving...' : 'Policy'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.savings,
                  label: '${Utils.number(treasury.treasury)} gold',
                ),
                _InfoChip(
                  icon: Icons.work,
                  label: '${treasury.policy.incomeTaxRate}% income',
                ),
                _InfoChip(
                  icon: Icons.storefront,
                  label: '${treasury.policy.marketTaxRate}% market',
                ),
                _InfoChip(
                  icon: Icons.factory,
                  label: '${treasury.policy.productionTaxRate}% production',
                ),
                _InfoChip(
                  icon: Icons.receipt_long,
                  label:
                      '${Utils.number(treasury.recentTaxCollected)} recent tax',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(treasury.authorization.message),
            const SizedBox(height: 12),
            Text(
              'Recent tax collection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const Text('No tax has been collected yet.')
            else
              ...recent.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments),
                  title: Text('${entry.goldDelta} gold • ${entry.entryType}'),
                  subtitle: Text(entry.description),
                  trailing: Text('${entry.taxRate}%'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaxRateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TaxRateField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _CountryCard extends StatelessWidget {
  final WorldCountry country;
  final List<WorldRegion> regions;
  final bool isCurrent;
  final bool isUpdating;
  final String actionLabel;
  final VoidCallback? onAction;

  const _CountryCard({
    required this.country,
    required this.regions,
    required this.isCurrent,
    required this.isUpdating,
    required this.actionLabel,
    required this.onAction,
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
                const Icon(Icons.public, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${country.name} (${country.code})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isCurrent)
                  const Chip(
                    avatar: Icon(Icons.check, size: 18),
                    label: Text('Current'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(country.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.account_balance,
                  label: country.government,
                ),
                _InfoChip(
                  icon: Icons.percent,
                  label: '${country.taxRate}% tax',
                ),
                _InfoChip(
                  icon: Icons.savings,
                  label: '${Utils.number(country.treasury)} treasury',
                ),
                _InfoChip(
                  icon: Icons.groups,
                  label: '${country.citizenCount} citizens',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Regions (${regions.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (regions.isEmpty)
              const Text('No regions are registered for this country yet.')
            else
              ...regions.map((region) => _RegionTile(region: region)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isUpdating ? null : onAction,
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isCurrent ? Icons.check : Icons.flag),
                label: Text(
                  isCurrent
                      ? 'Current citizenship'
                      : isUpdating
                          ? 'Saving...'
                          : actionLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  final WorldRegion region;
  const _RegionTile({required this.region});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(region.isCapital ? Icons.location_city : Icons.terrain),
      title: Text(region.name),
      subtitle: Text(
        '${region.terrain} • ${region.resourceFocus} • '
        '${Utils.number(region.population)} population',
      ),
      trailing: Text('Infra ${region.infrastructure}'),
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
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/GameScaffold.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CountryTreasuryPage extends StatefulWidget {
  final User user;

  const CountryTreasuryPage({super.key, required this.user});

  @override
  State<CountryTreasuryPage> createState() => _CountryTreasuryPageState();
}

class _CountryTreasuryPageState extends State<CountryTreasuryPage> {
  late final LoginBloc _loginBloc;
  late final WorldBloc _worldBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _worldBloc = Provider.of<WorldBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _worldBloc.setBearerToken(_loginBloc.currentToken);
    await _worldBloc.load(widget.user.uid);
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GameColors.panel,
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
          contentTextStyle: const TextStyle(color: GameColors.textMuted),
          title: Text('Update ${treasury.code} budget policy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TaxRateField(
                controller: incomeController,
                label: 'Income tax %',
                icon: Icons.work,
              ),
              _TaxRateField(
                controller: marketController,
                label: 'Market tax %',
                icon: Icons.storefront,
              ),
              _TaxRateField(
                controller: productionController,
                label: 'Production tax %',
                icon: Icons.factory,
              ),
              const SizedBox(height: 8),
              const Text('Rates must be whole numbers from 0% to 50%.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final income = int.tryParse(incomeController.text.trim());
                final market = int.tryParse(marketController.text.trim());
                final production =
                    int.tryParse(productionController.text.trim());
                final rates = [income, market, production];
                if (rates
                    .any((rate) => rate == null || rate < 0 || rate > 50)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
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
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(update);
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save policy'),
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
    return GameScaffold(
      title: 'Country Treasury',
      subtitle: 'Budget reserves, taxes, and recent public ledger changes',
      icon: Icons.account_balance,
      actions: [
        IconButton(
          tooltip: 'Refresh treasury',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Consumer<WorldBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.treasury == null && bloc.catalog == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null &&
              bloc.treasury == null &&
              (bloc.catalog == null || bloc.citizenship != null)) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          final treasury = bloc.treasury;
          if (bloc.citizenship == null || treasury == null) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GameHero(
                    eyebrow: 'No citizenship',
                    title: 'Join a country to unlock treasury operations',
                    subtitle:
                        'The national budget is tied to your citizenship. Pick a country before managing taxes or reading budget ledgers.',
                    icon: Icons.public_off,
                    accent: GameColors.amber,
                    stats: const [
                      GameStat(
                        label: 'status',
                        value: 'unassigned',
                        icon: Icons.person_search,
                        color: GameColors.amber,
                      ),
                    ],
                  ),
                  GamePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Treasury access requires an active citizenship.',
                          style: TextStyle(color: GameColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed('/world')
                              .then((_) => _load()),
                          icon: const Icon(Icons.flag),
                          label: const Text('Choose citizenship'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: _TreasuryBoard(
              treasury: treasury,
              isUpdating: bloc.isUpdatingPolicy,
              onEditPolicy: treasury.authorization.canUpdatePolicy
                  ? () => _editPolicy(treasury)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _TreasuryBoard extends StatelessWidget {
  final CountryTreasury treasury;
  final bool isUpdating;
  final VoidCallback? onEditPolicy;

  const _TreasuryBoard({
    required this.treasury,
    required this.isUpdating,
    required this.onEditPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final inflow = treasury.recentLedger
        .where((entry) => entry.goldDelta > 0)
        .fold<int>(0, (sum, entry) => sum + entry.goldDelta);
    final outflow = treasury.recentLedger
        .where((entry) => entry.goldDelta < 0)
        .fold<int>(0, (sum, entry) => sum + entry.goldDelta.abs());
    final net = inflow - outflow;
    final updated =
        DateFormat.yMMMd().add_Hm().format(treasury.updatedAt.toLocal());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GameHero(
          eyebrow: '${treasury.code} national budget',
          title: treasury.name,
          subtitle:
              'Treasury balance, tax posture, and recent ledger activity from the country service.',
          icon: Icons.account_balance,
          accent: GameColors.amber,
          stats: [
            GameStat(
              label: 'treasury',
              value: '${Utils.number(treasury.treasury)}g',
              icon: Icons.savings,
              color: GameColors.amber,
            ),
            GameStat(
              label: 'recent net',
              value: '${net >= 0 ? '+' : '-'}${Utils.number(net.abs())}g',
              icon: net >= 0 ? Icons.trending_up : Icons.trending_down,
              color: net >= 0 ? GameColors.emerald : GameColors.crimson,
            ),
            GameStat(
              label: 'entries',
              value: treasury.recentLedger.length.toString(),
              icon: Icons.receipt_long,
              color: GameColors.cyan,
            ),
          ],
        ),
        GameNotice(
          icon: treasury.authorization.canUpdatePolicy
              ? Icons.verified_user
              : Icons.lock_outline,
          message: treasury.authorization.message,
          color: treasury.authorization.canUpdatePolicy
              ? GameColors.emerald
              : GameColors.amber,
        ),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart, color: GameColors.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Budget posture',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (isUpdating)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GameStatPill(
                    stat: GameStat(
                      label: 'inflow',
                      value: '+${Utils.number(inflow)}g',
                      icon: Icons.arrow_downward,
                      color: GameColors.emerald,
                    ),
                  ),
                  GameStatPill(
                    stat: GameStat(
                      label: 'outflow',
                      value: '-${Utils.number(outflow)}g',
                      icon: Icons.arrow_upward,
                      color: GameColors.crimson,
                    ),
                  ),
                  GameStatPill(
                    stat: GameStat(
                      label: 'updated',
                      value: updated,
                      icon: Icons.update,
                      color: GameColors.violet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _budgetSummary(treasury.policy, net),
                style: const TextStyle(
                  color: GameColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        GameSectionTitle(
          title: 'Tax policy',
          subtitle: treasury.authorization.role == null
              ? 'Current public rates for national income.'
              : 'Authorized as ${treasury.authorization.role}.',
        ),
        GamePanel(
          child: Column(
            children: [
              _TaxPolicyRow(
                icon: Icons.work,
                label: 'Income tax',
                rate: treasury.policy.incomeTaxRate,
                color: GameColors.emerald,
              ),
              const Divider(color: GameColors.border),
              _TaxPolicyRow(
                icon: Icons.storefront,
                label: 'Market tax',
                rate: treasury.policy.marketTaxRate,
                color: GameColors.cyan,
              ),
              const Divider(color: GameColors.border),
              _TaxPolicyRow(
                icon: Icons.factory,
                label: 'Production tax',
                rate: treasury.policy.productionTaxRate,
                color: GameColors.violet,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: isUpdating ? null : onEditPolicy,
                  icon: const Icon(Icons.edit),
                  label: Text(
                    onEditPolicy == null ? 'Policy locked' : 'Update policy',
                  ),
                ),
              ),
            ],
          ),
        ),
        GameSectionTitle(
          title: 'Recent ledger',
          subtitle:
              'Recent persisted tax, fee, and budget transactions for this country.',
        ),
        if (treasury.recentLedger.isEmpty)
          const GameEmptyState(
            icon: Icons.receipt_long,
            message: 'No recent treasury ledger entries have been recorded.',
          )
        else
          ...treasury.recentLedger
              .map((entry) => _LedgerEntryCard(entry: entry)),
      ],
    );
  }
}

class _TaxPolicyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int rate;
  final Color color;

  const _TaxPolicyRow({
    required this.icon,
    required this.label,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.16),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _taxMood(rate),
                style: const TextStyle(color: GameColors.textMuted),
              ),
            ],
          ),
        ),
        Text(
          '$rate%',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _LedgerEntryCard extends StatelessWidget {
  final CountryTreasuryLedgerEntry entry;

  const _LedgerEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.goldDelta >= 0;
    final color = isPositive ? GameColors.emerald : GameColors.crimson;
    return GamePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.40)),
            ),
            child: Icon(
              isPositive ? Icons.add_card : Icons.payments_outlined,
              color: color,
            ),
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
                        _entryTypeLabel(entry.entryType),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : '-'}${Utils.number(entry.goldDelta.abs())}g',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.description,
                  style: const TextStyle(
                    color: GameColors.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LedgerChip(
                      icon: Icons.percent,
                      label: '${entry.taxRate}% tax',
                    ),
                    _LedgerChip(
                      icon: Icons.account_balance_wallet,
                      label: '${Utils.number(entry.grossAmount)}g gross',
                    ),
                    _LedgerChip(
                      icon: Icons.schedule,
                      label: DateFormat.MMMd()
                          .add_Hm()
                          .format(entry.createdAt.toLocal()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LedgerChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: GameColors.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GameColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: GameColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: GameColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxRateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _TaxRateField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixText: '%',
        ),
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
            const Icon(
              Icons.error_outline,
              size: 48,
              color: GameColors.crimson,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
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

String _budgetSummary(CountryTaxPolicy policy, int recentNet) {
  final averageRate =
      (policy.incomeTaxRate + policy.marketTaxRate + policy.productionTaxRate) /
          3;
  final posture = averageRate >= 25
      ? 'high-revenue'
      : averageRate >= 12
          ? 'balanced'
          : 'growth-friendly';
  final movement = recentNet >= 0 ? 'positive' : 'negative';
  return 'The current $posture posture averages ${averageRate.toStringAsFixed(1)}% across major taxes. Recent ledger movement is $movement, based only on persisted treasury entries.';
}

String _taxMood(int rate) {
  if (rate >= 30) {
    return 'Aggressive revenue stance';
  }
  if (rate >= 15) {
    return 'Balanced public funding';
  }
  if (rate > 0) {
    return 'Low-friction growth policy';
  }
  return 'No tax collected for this channel';
}

String _entryTypeLabel(String entryType) {
  return entryType
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

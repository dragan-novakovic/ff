import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PushNotificationsBloc.dart';
import 'package:ff/models/PushNotifications.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PushNotificationsPage extends StatefulWidget {
  final User user;
  const PushNotificationsPage({super.key, required this.user});

  @override
  State<PushNotificationsPage> createState() => _PushNotificationsPageState();
}

class _PushNotificationsPageState extends State<PushNotificationsPage> {
  late final LoginBloc _loginBloc;
  late final PushNotificationsBloc _pushBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _pushBloc = Provider.of<PushNotificationsBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _pushBloc.setBearerToken(_loginBloc.currentToken);
    await _pushBloc.load(widget.user.uid);
  }

  Future<void> _enable() async {
    _pushBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _pushBloc.enable(widget.user.uid);
    if (!mounted) {
      return;
    }
    _showMessage(result?.message ?? _pushBloc.error);
  }

  Future<void> _disable() async {
    _pushBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _pushBloc.disable(widget.user.uid);
    if (!mounted) {
      return;
    }
    _showMessage(result?.message ?? _pushBloc.error);
  }

  void _showMessage(String? message) {
    if (message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PushNotificationsBloc>(
      builder: (context, bloc, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Push notifications')),
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(
                  bloc: bloc,
                  onEnable: _enable,
                  onDisable: _disable,
                  onRefresh: _load,
                ),
                if (bloc.error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading:
                          const Icon(Icons.warning_amber, color: Colors.red),
                      title: Text(bloc.error!),
                    ),
                  ),
                _SubscriptionsCard(settings: bloc.settings),
                _DeliveriesCard(deliveries: bloc.deliveries),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final PushNotificationsBloc bloc;
  final Future<void> Function() onEnable;
  final Future<void> Function() onDisable;
  final Future<void> Function() onRefresh;

  const _StatusCard({
    required this.bloc,
    required this.onEnable,
    required this.onDisable,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final settings = bloc.settings;
    final enabled = settings?.hasEnabledSubscription ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  enabled ? Icons.notifications_active : Icons.notifications,
                  color: enabled ? Colors.green : Colors.blueGrey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    enabled
                        ? 'This browser receives push notifications.'
                        : 'Enable push notifications for this browser.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              settings == null
                  ? 'Load settings to see browser push support.'
                  : settings.isConfigured
                      ? 'Backend push keys are configured. You can subscribe this browser.'
                      : 'Backend push keys are not configured yet. Add FF_PUSH_VAPID_PUBLIC_KEY and FF_PUSH_VAPID_PRIVATE_KEY to send real Web Push notifications.',
            ),
            if (bloc.browserStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                'Browser permission: ${bloc.browserStatus!.permission}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: bloc.isSaving || settings?.isConfigured != true
                      ? null
                      : onEnable,
                  icon: bloc.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active),
                  label: const Text('Enable'),
                ),
                OutlinedButton.icon(
                  onPressed: bloc.isSaving || !enabled ? null : onDisable,
                  icon: const Icon(Icons.notifications_off),
                  label: const Text('Disable'),
                ),
                TextButton.icon(
                  onPressed: bloc.isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionsCard extends StatelessWidget {
  final PushNotificationSettings? settings;

  const _SubscriptionsCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final subscriptions =
        settings?.subscriptions ?? const <PushSubscriptionInfo>[];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.devices),
        title: Text('Browser subscriptions (${subscriptions.length})'),
        children: subscriptions.isEmpty
            ? const [
                ListTile(
                  title: Text('No browsers are subscribed yet.'),
                )
              ]
            : subscriptions
                .map(
                  (subscription) => ListTile(
                    leading: Icon(
                      subscription.isEnabled
                          ? Icons.check_circle
                          : Icons.remove_circle,
                      color:
                          subscription.isEnabled ? Colors.green : Colors.grey,
                    ),
                    title: Text(_shortEndpoint(subscription.endpoint)),
                    subtitle: Text([
                      subscription.isEnabled ? 'Enabled' : 'Disabled',
                      'failures ${subscription.failureCount}',
                      'updated ${_format(subscription.updatedAt)}',
                      if (subscription.lastError != null)
                        'last error ${subscription.lastError}',
                    ].join(' - ')),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _DeliveriesCard extends StatelessWidget {
  final PushDeliveryList? deliveries;

  const _DeliveriesCard({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    final rows = deliveries?.deliveries ?? const <PushDelivery>[];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.outbox),
        title: Text('Recent push deliveries (${rows.length})'),
        children: rows.isEmpty
            ? const [
                ListTile(
                  title: Text('No push deliveries yet.'),
                )
              ]
            : rows
                .map(
                  (delivery) => ListTile(
                    leading: Icon(_iconForStatus(delivery.status)),
                    title: Text(delivery.title),
                    subtitle: Text([
                      delivery.status,
                      'attempts ${delivery.attempts}',
                      _format(delivery.updatedAt),
                      if (delivery.lastError != null) delivery.lastError!,
                    ].join(' - ')),
                  ),
                )
                .toList(),
      ),
    );
  }
}

String _shortEndpoint(String endpoint) {
  if (endpoint.length <= 48) {
    return endpoint;
  }
  return '${endpoint.substring(0, 32)}...${endpoint.substring(endpoint.length - 12)}';
}

IconData _iconForStatus(String status) {
  return switch (status) {
    'delivered' => Icons.check_circle,
    'failed' || 'abandoned' => Icons.error,
    'sending' => Icons.sync,
    _ => Icons.schedule,
  };
}

String _format(DateTime value) {
  return DateFormat.yMd().add_Hm().format(value.toLocal());
}

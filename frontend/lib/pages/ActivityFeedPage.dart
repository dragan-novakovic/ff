import 'package:ff/blocs/ActivityFeedBloc.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/models/ActivityFeed.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ActivityFeedPage extends StatefulWidget {
  final User user;
  const ActivityFeedPage({super.key, required this.user});

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  late final ActivityFeedBloc _activityFeedBloc;
  late final LoginBloc _loginBloc;
  late final RealtimeUpdatesBloc _realtimeBloc;

  @override
  void initState() {
    super.initState();
    _activityFeedBloc = Provider.of<ActivityFeedBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _realtimeBloc = RealtimeUpdatesBloc();
    _load();
    _startRealtime();
  }

  Future<void> _load() async {
    _activityFeedBloc.setBearerToken(_loginBloc.currentToken);
    await _activityFeedBloc.load(widget.user.uid);
  }

  void _startRealtime() {
    _realtimeBloc.setBearerToken(_loginBloc.currentToken);
    _realtimeBloc.start(
      playerId: widget.user.uid,
      limit: 50,
      onUpdate: (update) {
        final activity = update.activity;
        if (activity != null) {
          _activityFeedBloc.applyRealtimeActivity(activity.feed, limit: 50);
        }
      },
    );
  }

  Future<void> _markRead(ActivityEvent event) async {
    _activityFeedBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _activityFeedBloc.markRead(
      playerId: widget.user.uid,
      eventId: event.eventId,
    );
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _activityFeedBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _markAllRead() async {
    _activityFeedBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _activityFeedBloc.markAllRead(widget.user.uid);
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _activityFeedBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _realtimeBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityFeedBloc>(
      builder: (context, bloc, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Activity'),
            actions: [
              TextButton.icon(
                onPressed: bloc.unreadCount > 0 && !bloc.isMarkingAllRead
                    ? _markAllRead
                    : null,
                icon: bloc.isMarkingAllRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: const Text('Mark all read'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: _ActivityFeedBody(
              bloc: bloc,
              onRetry: _load,
              onMarkRead: _markRead,
            ),
          ),
        );
      },
    );
  }
}

class _ActivityFeedBody extends StatelessWidget {
  final ActivityFeedBloc bloc;
  final Future<void> Function() onRetry;
  final Future<void> Function(ActivityEvent event) onMarkRead;

  const _ActivityFeedBody({
    required this.bloc,
    required this.onRetry,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc.isLoading && bloc.feed == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bloc.error != null && bloc.feed == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.notifications_off, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            bloc.error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    final events = bloc.events;
    if (events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          Icon(Icons.notifications_none, size: 48, color: Colors.blueGrey),
          SizedBox(height: 16),
          Text(
            'No activity yet. Complete gameplay actions to build your feed.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active),
            title: Text('${bloc.unreadCount} unread notifications'),
            subtitle:
                Text('Last synced ${_formatTimestamp(bloc.feed!.updatedAt)}'),
          ),
        ),
        if (bloc.error != null)
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.red),
              title: Text(bloc.error!),
            ),
          ),
        ...events.map(
          (event) => _ActivityEventCard(
            event: event,
            isMarkingRead: bloc.markingEventIds.contains(event.eventId),
            onMarkRead: () => onMarkRead(event),
          ),
        ),
      ],
    );
  }
}

class _ActivityEventCard extends StatelessWidget {
  final ActivityEvent event;
  final bool isMarkingRead;
  final Future<void> Function() onMarkRead;

  const _ActivityEventCard({
    required this.event,
    required this.isMarkingRead,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: event.isRead ? null : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: event.isRead ? Colors.grey : Colors.blue,
          child: Icon(_iconForType(event.type), color: Colors.white),
        ),
        title: Text(
          event.message,
          style: TextStyle(
            fontWeight: event.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          [
            _labelForType(event.type),
            _formatTimestamp(event.createdAt),
            if (event.relatedId != null) 'ref ${event.relatedId}',
          ].join(' • '),
        ),
        trailing: event.isRead
            ? const Icon(Icons.done, color: Colors.green)
            : TextButton(
                onPressed: isMarkingRead ? null : onMarkRead,
                child: isMarkingRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Read'),
              ),
      ),
    );
  }
}

IconData _iconForType(String type) {
  if (type.contains('production')) {
    return Icons.factory;
  }
  if (type.contains('battle') || type.contains('mission')) {
    return Icons.shield;
  }
  if (type.contains('weapon')) {
    return Icons.handyman;
  }
  if (type.contains('market')) {
    return Icons.store;
  }
  return Icons.notifications;
}

String _labelForType(String type) {
  return type
      .split(RegExp(r'[_\-:.]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _formatTimestamp(DateTime timestamp) {
  return DateFormat.yMMMd().add_Hm().format(timestamp.toLocal());
}

import 'package:ff/blocs/ActivityFeedBloc.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/components/GameScaffold.dart';
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
        return GameScaffold(
          title: 'Notifications Center',
          subtitle: 'Live activity, unread alerts, and action receipts',
          icon: Icons.notifications_active,
          actions: [
            IconButton(
              tooltip: 'Refresh notifications',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
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
              label: const Text('Clear'),
            ),
          ],
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
          GameNotice(
            icon: Icons.notifications_off,
            message: bloc.error!,
            color: GameColors.crimson,
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
          GameHero(
            eyebrow: 'Quiet command room',
            title: 'No notifications yet',
            subtitle:
                'Complete gameplay actions and backend activity events will appear here in real time.',
            icon: Icons.notifications_none,
            accent: GameColors.cyan,
          ),
          SizedBox(height: 12),
          GameEmptyState(
            icon: Icons.inbox,
            message: 'Your notification feed is empty.',
          ),
        ],
      );
    }

    final feed = bloc.feed!;
    final categoryCounts = _categoryCounts(events);
    final unreadEvents = events.where((event) => !event.isRead).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        GameHero(
          eyebrow: 'Command alerts',
          title: '${bloc.unreadCount} unread notifications',
          subtitle:
              'Production receipts, battles, market actions, social updates, and system alerts from the notification service.',
          icon: Icons.campaign,
          accent: bloc.unreadCount > 0 ? GameColors.amber : GameColors.emerald,
          stats: [
            GameStat(
              label: 'visible alerts',
              value: '${events.length}',
              icon: Icons.view_list,
              color: GameColors.cyan,
            ),
            GameStat(
              label: 'unread',
              value: '${unreadEvents.length}',
              icon: Icons.mark_email_unread,
              color:
                  unreadEvents.isEmpty ? GameColors.emerald : GameColors.amber,
            ),
            GameStat(
              label: 'last sync',
              value: DateFormat.Hm().format(feed.updatedAt.toLocal()),
              icon: Icons.sync,
              color: GameColors.violet,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (bloc.error != null)
          GameNotice(
            icon: Icons.warning_amber,
            message: bloc.error!,
            color: GameColors.amber,
          ),
        _NotificationOverview(
          categoryCounts: categoryCounts,
          updatedAt: feed.updatedAt,
        ),
        const GameSectionTitle(
          title: 'Inbox stream',
          subtitle: 'Tap read on individual alerts or clear the whole feed.',
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
    final color = _colorForType(event.type);
    return GamePanel(
      borderColor: event.isRead ? GameColors.border : color.withOpacity(0.55),
      color: event.isRead ? GameColors.panel : color.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.38)),
                ),
                child: Icon(_iconForType(event.type), color: color),
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
                            _labelForType(event.type),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                          ),
                        ),
                        _ReadBadge(isRead: event.isRead, color: color),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.message,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            event.isRead ? FontWeight.w700 : FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          icon: Icons.schedule,
                          label: _formatTimestamp(event.createdAt),
                          color: GameColors.cyan,
                        ),
                        if (event.relatedId != null)
                          _MetaPill(
                            icon: Icons.tag,
                            label: event.relatedId!,
                            color: GameColors.violet,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!event.isRead) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isMarkingRead ? null : onMarkRead,
                icon: isMarkingRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done),
                label: Text(isMarkingRead ? 'Marking...' : 'Mark read'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationOverview extends StatelessWidget {
  final Map<String, int> categoryCounts;
  final DateTime updatedAt;

  const _NotificationOverview({
    required this.categoryCounts,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final categories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Signal board',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last synchronized ${_formatTimestamp(updatedAt)}',
            style: const TextStyle(color: GameColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Text(
              'No categories yet.',
              style: TextStyle(color: GameColors.textMuted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories
                  .take(6)
                  .map(
                    (entry) => GameStatPill(
                      stat: GameStat(
                        label: entry.key,
                        value: '${entry.value}',
                        icon: _iconForType(entry.key),
                        color: _colorForType(entry.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ReadBadge extends StatelessWidget {
  final bool isRead;
  final Color color;

  const _ReadBadge({required this.isRead, required this.color});

  @override
  Widget build(BuildContext context) {
    final badgeColor = isRead ? GameColors.emerald : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Text(
        isRead ? 'READ' : 'NEW',
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GameColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
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

IconData _iconForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('production')) {
    return Icons.factory;
  }
  if (normalized.contains('battle') || normalized.contains('mission')) {
    return Icons.shield;
  }
  if (normalized.contains('weapon')) {
    return Icons.handyman;
  }
  if (normalized.contains('market') || normalized.contains('trade')) {
    return Icons.store;
  }
  return Icons.notifications;
}

Color _colorForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('production')) {
    return GameColors.amber;
  }
  if (normalized.contains('battle') || normalized.contains('mission')) {
    return GameColors.crimson;
  }
  if (normalized.contains('weapon')) {
    return GameColors.violet;
  }
  if (normalized.contains('market') || normalized.contains('trade')) {
    return GameColors.emerald;
  }
  if (normalized.contains('social') ||
      normalized.contains('comment') ||
      normalized.contains('chat')) {
    return GameColors.cyan;
  }
  return GameColors.cyan;
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

Map<String, int> _categoryCounts(List<ActivityEvent> events) {
  final counts = <String, int>{};
  for (final event in events) {
    final label = _labelForType(event.type);
    counts[label] = (counts[label] ?? 0) + 1;
  }
  return counts;
}

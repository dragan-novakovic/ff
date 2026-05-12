import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const _bbmBackground = Color(0xFF07100D);
const _bbmPanel = Color(0xFF101A16);
const _bbmIncoming = Color(0xFF17221D);
const _bbmOutgoing = Color(0xFF123A25);
const _bbmGreen = Color(0xFF24D366);
const _bbmLime = Color(0xFFA3E635);
const _bbmBlue = Color(0xFF38BDF8);
const _bbmMuted = Color(0xFF9AA8A1);

class TextBoxBody extends StatelessWidget {
  final String? currentUserId;
  final VoidCallback onRetry;
  final Future<void> Function(Message message) onReport;
  const TextBoxBody({
    super.key,
    required this.currentUserId,
    required this.onRetry,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final messageBloc = Provider.of<MessageBloc>(context);
    return StreamBuilder<List<Message>>(
      stream: messageBloc.messages,
      builder: (context, AsyncSnapshot<List<Message>> snapshot) {
        if (snapshot.hasError) {
          return _BbmErrorState(
            message: snapshot.error.toString(),
            onRetry: onRetry,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return const _BbmEmptyState();
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF07100D),
                Color(0xFF0A1612),
                Color(0xFF07100D),
              ],
            ),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final showDayChip = _shouldShowDayChip(messages, index);
              return Column(
                children: [
                  if (showDayChip) _DayChip(date: message.createdAt),
                  TextBox(
                    message: message,
                    currentUserId: currentUserId,
                    onReport: onReport,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class TextBox extends StatelessWidget {
  final Message message;
  final String? currentUserId;
  final Future<void> Function(Message message) onReport;

  const TextBox({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = currentUserId != null && currentUserId == message.fromId;
    final sender = _senderLabel(message.fromId, isMine);
    final bubbleColor = isMine ? _bbmOutgoing : _bbmIncoming;
    final accent = isMine ? _bbmGreen : _bbmBlue;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMine ? 20 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 20),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            border: Border.all(color: accent.withOpacity(0.26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.24),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _bbmGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.35,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _messageTime(message.createdAt),
                    style: const TextStyle(color: _bbmMuted, fontSize: 11),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 7),
                    const Text(
                      'D',
                      style: TextStyle(
                        color: _bbmLime,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.done_all, color: _bbmLime, size: 14),
                  ],
                  if (!isMine && message.id.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onReport(message),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              color: _bbmMuted,
                              size: 14,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Report',
                              style: TextStyle(
                                color: _bbmMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime? date;

  const _DayChip({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _bbmPanel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        _dayLabel(date),
        style: const TextStyle(
          color: _bbmMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BbmEmptyState extends StatelessWidget {
  const _BbmEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _bbmPanel,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _bbmGreen.withOpacity(0.24)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, color: _bbmGreen, size: 50),
              SizedBox(height: 14),
              Text(
                'No messages yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Start the conversation and it will appear in classic messenger bubbles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _bbmMuted, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BbmErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BbmErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _bbmPanel,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bbmGreen,
                  foregroundColor: _bbmBackground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _shouldShowDayChip(List<Message> messages, int index) {
  final current = messages[index].createdAt;
  if (index == 0) {
    return current != null;
  }
  final previous = messages[index - 1].createdAt;
  if (current == null || previous == null) {
    return false;
  }

  final currentLocal = current.toLocal();
  final previousLocal = previous.toLocal();
  return currentLocal.year != previousLocal.year ||
      currentLocal.month != previousLocal.month ||
      currentLocal.day != previousLocal.day;
}

String _senderLabel(String fromId, bool isMine) {
  if (isMine) {
    return 'You';
  }
  if (fromId == 'system') {
    return 'System';
  }
  return 'PIN ${_bbmPin(fromId)}';
}

String _messageTime(DateTime? value) {
  if (value == null) {
    return 'just now';
  }
  return DateFormat.Hm().format(value.toLocal());
}

String _dayLabel(DateTime? value) {
  if (value == null) {
    return 'Today';
  }

  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(local.year, local.month, local.day);
  if (messageDay == today) {
    return 'Today';
  }
  if (messageDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return DateFormat.yMMMd().format(local);
}

String _bbmPin(String value) {
  final hash = value.hashCode.abs().toRadixString(16).toUpperCase();
  return hash.padLeft(8, '0').substring(0, 8);
}

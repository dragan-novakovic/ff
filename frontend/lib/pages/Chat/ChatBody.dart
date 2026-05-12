import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/components/MessageInput.dart';
import 'package:ff/components/TextBoxBody.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _bbmBackground = Color(0xFF07100D);
const _bbmPanel = Color(0xFF101A16);
const _bbmPanelAlt = Color(0xFF14241E);
const _bbmGreen = Color(0xFF24D366);
const _bbmLime = Color(0xFFA3E635);
const _bbmBlue = Color(0xFF38BDF8);
const _bbmMuted = Color(0xFF9AA8A1);

class ChatBody extends StatefulWidget {
  final String? userId;
  final String? contactId;
  const ChatBody({super.key, this.userId, this.contactId});

  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> {
  late final RealtimeUpdatesBloc _realtimeBloc;

  String get _toId =>
      widget.contactId == null || widget.contactId!.trim().isEmpty
          ? 'global'
          : widget.contactId!.trim();

  @override
  void initState() {
    super.initState();
    _realtimeBloc = RealtimeUpdatesBloc();
    _loadMessages();
    _startRealtime();
  }

  @override
  void didUpdateWidget(ChatBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.contactId != widget.contactId) {
      _loadMessages();
      _startRealtime();
    }
  }

  void _loadMessages() {
    final messageBloc = Provider.of<MessageBloc>(context, listen: false);
    if (widget.userId != null && _toId != 'global') {
      messageBloc.fetchMessages(fromId: widget.userId, toId: _toId);
      return;
    }

    messageBloc.fetchMessages(toId: _toId);
  }

  void _startRealtime() {
    final userId = widget.userId;
    if (userId == null || userId.trim().isEmpty) {
      _realtimeBloc.stop();
      return;
    }

    final loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _realtimeBloc.setBearerToken(loginBloc.currentToken);
    _realtimeBloc.start(
      playerId: userId,
      chatToId: _toId,
      onUpdate: (update) {
        final chat = update.chat;
        if (chat != null) {
          Provider.of<MessageBloc>(context, listen: false)
              .applyRealtimeChat(chat);
        }
      },
    );
  }

  Future<void> _reportMessage(Message message) async {
    final playerId = widget.userId;
    if (playerId == null || playerId.isEmpty) {
      _showMessage('Sign in before reporting messages.');
      return;
    }

    final reason = await _promptReportReason();
    if (reason == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final result =
        await Provider.of<MessageBloc>(context, listen: false).reportMessage(
      playerId: playerId,
      messageId: message.id,
      reason: reason,
    );
    if (!mounted) {
      return;
    }
    _showMessage(result?.message ?? 'Could not submit content report.');
  }

  Future<String?> _promptReportReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bbmPanel,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
        contentTextStyle: const TextStyle(color: _bbmMuted),
        title: const Text('Report message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Reason',
            labelStyle: const TextStyle(color: _bbmMuted),
            filled: true,
            fillColor: _bbmPanelAlt,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _bbmGreen),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _bbmGreen,
              foregroundColor: _bbmBackground,
            ),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Submit report'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) {
      return null;
    }
    if (reason.length < 5 || reason.length > 500) {
      _showMessage('Report reason must be between 5 and 500 characters.');
      return null;
    }
    return reason;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _realtimeBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bbmBackground,
      child: Column(
        children: [
          _BbmConversationHeader(
              contactId: _toId, currentUserId: widget.userId),
          Expanded(
            child: TextBoxBody(
              currentUserId: widget.userId,
              onRetry: _loadMessages,
              onReport: _reportMessage,
            ),
          ),
          MessageInput(
            key: ValueKey('${widget.userId}:$_toId'),
            fromId: widget.userId,
            toId: _toId,
          ),
        ],
      ),
    );
  }
}

class _BbmConversationHeader extends StatelessWidget {
  final String contactId;
  final String? currentUserId;

  const _BbmConversationHeader({
    required this.contactId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isGlobal = contactId == 'global';
    final color = isGlobal ? _bbmBlue : _bbmGreen;
    final title = isGlobal ? 'Global Chat' : contactId;
    final subtitle = isGlobal
        ? 'World broadcast - every citizen can read this channel'
        : 'Direct conversation - PIN ${_bbmPin(contactId)}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bbmPanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withOpacity(0.48)),
                ),
                child:
                    Icon(isGlobal ? Icons.public : Icons.person, color: color),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _bbmGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bbmPanel, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _bbmMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BbmStatusPill(
            label: currentUserId == null ? 'Offline' : 'Live',
            color: currentUserId == null ? Colors.orangeAccent : _bbmGreen,
          ),
        ],
      ),
    );
  }
}

class _BbmStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _BbmStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.64)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _bbmPin(String value) {
  final hash = value.hashCode.abs().toRadixString(16).toUpperCase();
  return hash.padLeft(8, '0').substring(0, 8);
}

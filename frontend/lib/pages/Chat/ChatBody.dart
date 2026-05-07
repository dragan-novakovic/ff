import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/components/MessageInput.dart';
import 'package:ff/components/TextBoxBody.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        title: const Text('Report message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
    return Column(children: [
      Expanded(flex: 1, child: infoBox(_toId)),
      Expanded(
        flex: 8,
        child: TextBoxBody(
          currentUserId: widget.userId,
          onRetry: _loadMessages,
          onReport: _reportMessage,
        ),
      ),
      Expanded(
        flex: 1,
        child: MessageInput(
          key: ValueKey('${widget.userId}:$_toId'),
          fromId: widget.userId,
          toId: _toId,
        ),
      )
    ]);
  }
}

// info widget
Widget infoBox(String contactId) {
  final title = contactId == 'global' ? 'Global chat' : contactId;
  final subtitle = contactId == 'global'
      ? 'Messages sent here are visible to everyone.'
      : 'Direct conversation';

  return Container(
    decoration: BoxDecoration(
        gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color.fromARGB(255, 51, 133, 200),
        Color.fromARGB(255, 7, 82, 143),
      ],
    )),
    child: Row(
      children: [
        Container(
          child: ClipRRect(
              borderRadius: BorderRadius.all(
                  Radius.circular(2.0)), //add border radius here
              child: Image(image: AssetImage('assets/images/avatar.png'))),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
              child: Text(
                title,
                textAlign: TextAlign.left,
                style: TextStyle(
                    color: Color.fromARGB(255, 233, 231, 231),
                    fontSize: 18.0,
                    fontWeight: FontWeight.w500),
              ),
            )),
            Container(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
              child: Text(
                subtitle,
                style: TextStyle(
                    color: Color.fromARGB(255, 233, 231, 231),
                    fontWeight: FontWeight.w300),
              ),
            ))
          ],
        )
      ],
    ),
  );
}

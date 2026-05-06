import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/components/MessageInput.dart';
import 'package:ff/components/TextBoxBody.dart';
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
  String get _toId =>
      widget.contactId == null || widget.contactId!.trim().isEmpty
          ? 'global'
          : widget.contactId!.trim();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(ChatBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.contactId != widget.contactId) {
      _loadMessages();
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

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(flex: 1, child: infoBox(_toId)),
      Expanded(
        flex: 8,
        child: TextBoxBody(
          currentUserId: widget.userId,
          onRetry: _loadMessages,
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

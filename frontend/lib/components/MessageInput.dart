import 'package:ff/blocs/MessageBloc.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MessageInput extends StatefulWidget {
  final String? fromId;
  final String toId;
  const MessageInput({
    required Key key,
    required this.fromId,
    required this.toId,
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _inputController = TextEditingController();

  Future<void> _send(MessageBloc messageBloc) async {
    final fromId = widget.fromId;
    final content = _inputController.text.trim();
    if (fromId == null || fromId.isEmpty || content.isEmpty) {
      return;
    }

    await messageBloc.sendMessage(content, fromId, widget.toId);
    _inputController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final messageBloc = Provider.of<MessageBloc>(context);
    final canSend = widget.fromId != null && widget.fromId!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: Colors.grey[800]),
      padding: EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<String>(
                stream: messageBloc.message,
                builder: (context, snapshot) {
                  return TextField(
                    controller: _inputController,
                    enabled: canSend,
                    onChanged: messageBloc.changeMessage,
                    onSubmitted: (_) => _send(messageBloc),
                    decoration: InputDecoration(
                        labelText: canSend
                            ? 'Message ${widget.toId}'
                            : 'Sign in to send messages',
                        filled: true,
                        fillColor: Colors.white70,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: EdgeInsets.only(
                            left: 0, right: 0, top: 0, bottom: 0),
                        icon: IconButton(
                          onPressed: canSend ? () => _send(messageBloc) : null,
                          icon: Icon(
                            Icons.send,
                            color: Colors.white70,
                            size: 32.0,
                          ),
                        )),
                  );
                }),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}

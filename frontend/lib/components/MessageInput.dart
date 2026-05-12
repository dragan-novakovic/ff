import 'package:ff/blocs/MessageBloc.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _bbmBackground = Color(0xFF07100D);
const _bbmPanel = Color(0xFF101A16);
const _bbmPanelAlt = Color(0xFF14241E);
const _bbmGreen = Color(0xFF24D366);
const _bbmMuted = Color(0xFF9AA8A1);

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
  bool _isSending = false;

  Future<void> _send(MessageBloc messageBloc) async {
    final fromId = widget.fromId;
    final content = _inputController.text.trim();
    if (fromId == null || fromId.isEmpty || content.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    await messageBloc.sendMessage(content, fromId, widget.toId);
    if (!mounted) {
      return;
    }

    _inputController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final messageBloc = Provider.of<MessageBloc>(context);
    final canSend = widget.fromId != null && widget.fromId!.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: _bbmBackground,
          border:
              Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _bbmPanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.add, color: _bbmMuted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StreamBuilder<String>(
                stream: messageBloc.message,
                builder: (context, snapshot) {
                  return TextField(
                    controller: _inputController,
                    enabled: canSend && !_isSending,
                    onChanged: messageBloc.changeMessage,
                    onSubmitted: (_) => _send(messageBloc),
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _bbmGreen,
                    decoration: InputDecoration(
                      hintText: canSend
                          ? 'Message ${widget.toId == 'global' ? 'Global Chat' : widget.toId}'
                          : 'Sign in to send messages',
                      hintStyle: const TextStyle(color: _bbmMuted),
                      filled: true,
                      fillColor: _bbmPanelAlt,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: _bbmGreen),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.06)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: canSend ? _bbmGreen : _bbmPanel,
                borderRadius: BorderRadius.circular(16),
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: _bbmGreen.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                onPressed:
                    canSend && !_isSending ? () => _send(messageBloc) : null,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _bbmBackground,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                color: _bbmBackground,
                disabledColor: _bbmMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}

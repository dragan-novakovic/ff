import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    MessageBloc _messageBloc = Provider.of<MessageBloc>(context);
    return StreamBuilder<List<Message>>(
        stream: _messageBloc.messages,
        builder: (context, AsyncSnapshot<List<Message>> snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  SizedBox(height: 12),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasData) {
            final messages = snapshot.data ?? [];
            if (messages.isEmpty) {
              return Center(
                child: Text(
                  'No messages yet. Start the conversation.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              );
            }

            return Container(
              decoration:
                  BoxDecoration(color: Color.fromARGB(255, 209, 209, 209)),
              child: CustomScrollView(
                slivers: [
                  SliverList(
                      delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                    return TextBox(
                      message: messages[index],
                      currentUserId: currentUserId,
                      onReport: onReport,
                    );
                  }, childCount: messages.length))
                ],
              ),
            );
          }

          return Center(
            child: CircularProgressIndicator(),
          );
        });
  }
}

// Widget TextBox(List<Message> messagesList, int index) {}
class TextBox extends StatelessWidget {
  final Message message;
  final String? currentUserId;
  final Future<void> Function(Message message) onReport;
  const TextBox(
      {super.key,
      required this.message,
      required this.currentUserId,
      required this.onReport});

  @override
  Widget build(BuildContext context) {
    final isMine = currentUserId != null && currentUserId == message.fromId;
    final sender = isMine
        ? 'You'
        : message.fromId == 'system'
            ? 'System'
            : message.fromId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: isMine ? Colors.blue.shade50 : Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(message.content),
                if (!isMine && message.id.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onReport(message),
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Report'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

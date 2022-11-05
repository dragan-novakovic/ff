import 'package:ff/blocs/MessageBloc.dart';
import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  const MessageInput({super.key});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  MessageBloc _messageBloc = MessageBloc();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<Object>(
                stream: _messageBloc.message,
                builder: (context, snapshot) {
                  return TextField(
                    onChanged: _messageBloc.changeMessage,
                    onSubmitted: _messageBloc.sendMessage,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Enter Message',
                        isDense: true, // Added this
                        contentPadding: EdgeInsets.all(10),
                        suffixIcon: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12.0),
                          child: Icon(
                            Icons.send,
                            color: Colors.blue,
                            size: 30.0,
                            semanticLabel:
                                'Text to announce in accessibility modes',
                          ), // myIcon is a 48px-wide widget.
                        )),
                  );
                }),
          )
        ],
      ),
    );
  }
}

//Expanded(child: TextField())
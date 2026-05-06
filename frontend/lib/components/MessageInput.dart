import 'package:ff/blocs/MessageBloc.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MessageInput extends StatefulWidget {
  final Function parentFunc;
  const MessageInput({required Key key, required this.parentFunc})
      : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  TextEditingController _inputController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    MessageBloc _messageBloc = Provider.of<MessageBloc>(context);
    String? route = ModalRoute.of(context)?.settings.name as String;
    print("ROUTTEEEEE: " + route);
    return Container(
      decoration: BoxDecoration(color: Colors.grey[800]),
      padding: EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<Object>(
                stream: _messageBloc.message,
                builder: (context, snapshot) {
                  return TextField(
                    controller: _inputController,
                    onChanged: _messageBloc.changeMessage,
                    //  onSubmitted: _messageBloc.sendMessage,
                    decoration: InputDecoration(
                        labelText: 'Enter Message',
                        filled: true,
                        fillColor: Colors.white70,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: EdgeInsets.only(
                            left: 0, right: 0, top: 0, bottom: 0),
                        icon: IconButton(
                          onPressed: (() {
                            _messageBloc.sendMessage(
                                _inputController.text, "ne", "ne");
                            _inputController.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
                          }),
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
}

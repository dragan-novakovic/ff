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
      margin: EdgeInsets.symmetric(vertical: 10.0),
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
                        contentPadding: EdgeInsets.all(6),
                        suffixIcon: IconButton(
                          onPressed: (() {
                            _messageBloc.sendMessage(
                                _inputController.text, "ne", "ne");
                            _inputController.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
                          }),
                          icon: Padding(
                            padding:
                                const EdgeInsetsDirectional.only(end: 12.0),
                            child: Icon(
                              Icons.send,
                              color: Colors.blue,
                              size: 30.0,
                            ),
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

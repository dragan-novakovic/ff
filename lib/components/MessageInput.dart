import 'package:ff/blocs/MessageBloc.dart';
import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final MessageBloc messageBloc;
  final Function parentFunc;
  const MessageInput(
      {required Key key, required this.parentFunc, required this.messageBloc})
      : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  TextEditingController _inputController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<Object>(
                stream: widget.messageBloc.message,
                builder: (context, snapshot) {
                  return TextField(
                    controller: _inputController,
                    onChanged: widget.messageBloc.changeMessage,
                    onSubmitted: widget.messageBloc.sendMessage,
                    decoration: InputDecoration(
                        labelText: 'Enter Message',
                        contentPadding: EdgeInsets.all(6),
                        suffixIcon: IconButton(
                          onPressed: (() {
                            widget.messageBloc
                                .sendMessage(_inputController.text);
                            _inputController.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
                            widget.messageBloc
                                .changeMessage(_inputController.text);
                            widget.parentFunc();
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

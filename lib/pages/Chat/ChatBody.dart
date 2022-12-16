import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/MessageInput.dart';
import 'package:ff/components/TextBoxBody.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class ChatBody extends StatefulWidget {
  String? userId;
  ChatBody({super.key, String? userId});
  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> {
  int counter = 0;

  void updateCounter() {
    setState(() {
      counter++;
    });
  }

  @override
  void initState() {
    super.initState();
    MessageBloc _messageBloc = Provider.of<MessageBloc>(context, listen: false);
    LoginBloc _userBloc = Provider.of<LoginBloc>(context, listen: false);
    if (widget.userId != null) {
      _messageBloc.fetchMessages(userId: widget.userId);
      _userBloc.fetchChatUserProfile(widget.userId as String);
    } else {
      _messageBloc.fetchMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(children: [
      Expanded(flex: 1, child: infoBox()),
      Expanded(flex: 8, child: TextBoxBody()),
      Expanded(
          flex: 1,
          child: MessageInput(
            key: UniqueKey(),
            parentFunc: updateCounter,
          ))
    ]));
  }
}

// info widget
Widget infoBox() {
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
                "John Doe",
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
                "Test de BBM en cours 🔥",
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

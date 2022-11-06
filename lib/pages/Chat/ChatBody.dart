import 'package:ff/blocs/MessageBloc.dart';
import 'package:ff/components/MessageInput.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:flutter/material.dart';

class ChatBody extends StatefulWidget {
  const ChatBody({super.key});

  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> {
  MessageBloc _messageBloc = MessageBloc();
  int counter = 0;

  void updateCounter() {
    setState(() {
      counter++;
    });
  }

  @override
  void initState() {
    super.initState();
    _messageBloc.fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(children: [
      Expanded(flex: 1, child: infoBox()),
      Expanded(flex: 8, child: renderText(_messageBloc)),
      Expanded(
          flex: 1,
          child: MessageInput(
              key: UniqueKey(),
              parentFunc: updateCounter,
              messageBloc: _messageBloc))
    ]));
  }
}

Widget infoBox() {
  return Container(
    decoration: BoxDecoration(color: Colors.amber),
    child: Row(
      children: [
        Container(
          child: CircleAvatar(
            radius: 50,
            child: ClipOval(child: Text("J.D.")),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [Text("John Doe"), Text("Status: Online")],
        )
      ],
    ),
  );
}

Widget renderText(MessageBloc messageBloc) {
  print("DA LI JE PROBLEM U FUNKCIJI ILI U STREAMU?");
  return StreamBuilder<Object>(
      stream: messageBloc.messages,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasError) {
          return Text("ERRRR");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("Loading");
        }

        print("Data lenght: " + snapshot.data.length.toString());

        return Container(
          height: 200,
          child: CustomScrollView(
            slivers: [
              SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                return TextBox(snapshot.data, index);
              }, childCount: snapshot.data.length))
            ],
          ),
        );
      });
}

Widget TextBox(List<Message> messagesList, int index) {
  print("DA LI TEXT DODJE OVDE?");
  Message message = messagesList[index];

  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Container(
      decoration: BoxDecoration(
          color: Colors.grey, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(message.fromId), Text(message.content)],
          ),
          Text("Date")
        ],
      ),
    ),
  );
}

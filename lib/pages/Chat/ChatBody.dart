import 'package:ff/components/MessageInput.dart';
import 'package:flutter/material.dart';

class ChatBody extends StatefulWidget {
  const ChatBody({super.key});

  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(children: [
      Expanded(flex: 1, child: infoBox()),
      Expanded(flex: 8, child: renderText()),
      Expanded(flex: 1, child: MessageInput())
    ]));
  }
}

Widget infoBox() {
  return Container(
    decoration: BoxDecoration(color: Colors.amber),
    child: Row(
      children: [
        Text("Icon"),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [Text("Name"), Text("Status")],
        )
      ],
    ),
  );
}

Widget renderText() {
  return Container(
    height: 200,
    child: CustomScrollView(
      slivers: [
        SliverList(
            delegate:
                SliverChildBuilderDelegate((BuildContext context, int index) {
          return TextBox();
        }, childCount: 30))
      ],
    ),
  );
}

Widget TextBox() {
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
            children: [Text("John Doe"), Text("content of the message")],
          ),
          Text("Info")
        ],
      ),
    ),
  );
}

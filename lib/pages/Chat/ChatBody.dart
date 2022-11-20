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

Widget renderText(MessageBloc messageBloc) {
  messageBloc.messages.listen((event) {
    print(event.last.toString());
  });
  return StreamBuilder<Object>(
      stream: messageBloc.messages,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasError) {
          return Text("ERRRR");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        print("Data lenght: " + snapshot.data.length.toString());

        return Container(
          decoration: BoxDecoration(color: Color.fromARGB(255, 209, 209, 209)),
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
  Message message = messagesList[index];

  bool isOther = index % 2 == 0;

  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: FractionallySizedBox(
      alignment: isOther ? Alignment.centerLeft : Alignment.centerRight,
      widthFactor: 0.8,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
            color: Color.fromARGB(255, 242, 242, 242),
            borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 16, 8, 16),
          child: isOther
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            child: ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(
                                    2.0)), //add border radius here
                                child: Image(
                                    image: AssetImage(
                                        'assets/images/avatar.png'))),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "John Doe", //message.fromId
                                  style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(message.content)
                              ],
                            ),
                          )
                        ],
                      ),
                      Text("10:14")
                    ])
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "John Doe", //message.fromId
                            style: TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.w600),
                          ),
                          Text(message.content)
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                          child: Text("10:14"),
                        ),
                        Container(
                          child: ClipRRect(
                              borderRadius: BorderRadius.all(Radius.circular(
                                  2.0)), //add border radius here
                              child: Image(
                                  image:
                                      AssetImage('assets/images/avatar.png'))),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

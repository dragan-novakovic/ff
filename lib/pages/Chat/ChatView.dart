import 'package:ff/pages/Chat/ChatBody.dart';
import 'package:flutter/material.dart';
import 'package:responsive_scaffold_nullsafe/responsive_scaffold.dart';

import '../../components/NavTile.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
        title: Text("Inbox"),
        drawer: dashboardDrawer(context, widget),
        body: ChatBody());
  }
}

Widget dashboardDrawer(context, widget) => ListView(
      children: <Widget>[
        Container(
          height: 200,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.5, 0.9],
                  colors: [Colors.blue.shade300, Colors.lightBlue])),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[],
          ),
        ),
        Container(
          // height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      '100',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24.0),
                    ),
                    subtitle: Text(
                      "ENERGY",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      "9999",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24.0),
                    ),
                    subtitle: Text(
                      "GOLD",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Inbox",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, widget, title: "Djura", subtitle: "Unread"),
              navTile(context, widget, title: "Mika", subtitle: "Unread"),
            ],
          ),
        ),
      ],
    );

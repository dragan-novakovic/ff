import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/pages/Chat/ChatBody.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_scaffold_nullsafe/responsive_scaffold.dart';
import '../../components/NavTile.dart';
import '../../models/User.dart';

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

Widget dashboardDrawer(context, widget) {
  LoginBloc _loginBloc = Provider.of(context);
  return ListView(
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
      InkWell(
        child: StreamBuilder(
            stream: _loginBloc.userData,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                print(snapshot.data);
                User user = snapshot.data as User;
                return ExpansionTile(
                  title: Text(
                    "Inbox",
                    style: TextStyle(color: Colors.blue, fontSize: 12.0),
                  ),
                  children: fetchInboxList(context, widget, user.contacts),
                );
              }

              return Text('LOOOADING INBOX');
            }),
      ),
    ],
  );
}

List<Widget> fetchInboxList(context, widget, List<String>? data) {
  if (data != null && data.isNotEmpty) {
    return data
        .map(
            (name) => navTile(context, widget, title: name, subtitle: "Unread"))
        .toList();
  }

  return [];
}

import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/pages/Chat/ChatBody.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final loginBloc = Provider.of<LoginBloc>(context);
    return StreamBuilder(
      stream: loginBloc.userData,
      initialData: loginBloc.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data as User?;
        return Scaffold(
          appBar: AppBar(title: Text('Inbox')),
          drawer: Drawer(child: chatDrawer(context, user)),
          body: ChatBody(
            userId: user?.uid,
            contactId: 'global',
          ),
        );
      },
    );
  }
}

Widget chatDrawer(BuildContext context, User? user) {
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
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            "Inbox",
            style: TextStyle(color: Colors.blue, fontSize: 12.0),
          ),
          children: user == null
              ? [ListTile(title: Text('Loading inbox...'))]
              : fetchInboxList(context, user.contacts, user.uid),
        ),
      ),
    ],
  );
}

List<Widget> fetchInboxList(context, List<String>? data, String userId) {
  final contacts = <String>['global', ...?data]
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .toList();

  return contacts
      .map((name) => navTile(context, null,
          title: name,
          subtitle: name == 'global' ? "World chat" : "Direct chat",
          route: '/inbox/chat',
          props: name,
          userId: userId))
      .toList();
}

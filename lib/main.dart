import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/pages/Login.dart';
import 'package:ff/pages/Missions.dart';
import 'package:flutter/material.dart';

import 'pages/Inventory.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setUpLocators();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        '/': (context) => Login(),
        '/storage': (context) {
          final dynamic args = ModalRoute.of(context).settings.arguments;
          return StoragePage(
            inventoryId: args['id'],
          );
        },
        '/missions': (context) => MissionsPage(),
      },
    );
  }
}

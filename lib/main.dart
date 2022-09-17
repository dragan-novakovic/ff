import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/pages/Login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        // '/storage': (context) {
        //   final dynamic args = ModalRoute.of(context)?.settings.arguments;
        //   return StoragePage(
        //     inventoryId: args['id'],
        //   );
        // },
        // '/missions': (context) => MissionsPage(),
      },
    );
  }
}

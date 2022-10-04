import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/models/User.dart';
import 'package:ff/pages/Dashboard.dart';
import 'package:ff/pages/Login.dart';
import 'package:firebase_auth/firebase_auth.dart' as FB;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'blocs/UserBloc.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setUpLocators();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  LoginBloc _loginBloc = LoginBloc();
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
        '/': (context) => StreamBuilder(
            stream: _loginBloc.authStateChange,
            builder: (context, snapshot) {
              print("MAIN.dart| printing data!!!!!!");
              if (snapshot.hasData) {
                FB.User FBuserData = snapshot.data;
                User userData = User(FBuserData.uid, "", "", "", "",
                    PlayerData(FBuserData.uid, 100, 100, 1000, "", ""));
                if (userData.id.isNotEmpty) {
                  print("DASHBOARD SCREEN");
                  return Dashboard(user: userData);
                }
              }

              if (snapshot.hasError) {
                print(snapshot.error);
              }
              return Login();
            }),
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

import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/models/User.dart';
import 'package:ff/pages/Chat/ChatView.dart';
import 'package:ff/pages/Dashboard.dart';
import 'package:ff/pages/Login/Login.dart';
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
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        '/': (context) => StreamBuilder(
            stream: _loginBloc.userData,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                User userData = snapshot.data as User;

                if (userData.uid.isNotEmpty) {
                  return Dashboard(user: userData);
                }
              }

              if (snapshot.hasError) {
                print(snapshot.error);
              }
              return Login();
            }),
        '/inbox': (context) {
          final dynamic args = ModalRoute.of(context)?.settings.arguments;
          //args['id']
          return ChatView();
        }
      },
    );
  }
}

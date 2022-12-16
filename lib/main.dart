import 'package:ff/pages/Chat/ChatBody.dart';
import 'package:ff/pages/Chat/ChatView.dart';
import 'package:ff/pages/Dashboard.dart';
import 'package:ff/pages/Login/Login.dart';
import 'package:firebase_auth/firebase_auth.dart' as Auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'blocs/MessageBloc.dart';
import 'blocs/LoginBloc.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LoginBloc()),
      ChangeNotifierProvider(create: (_) => MessageBloc()),
    ],
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      home: LoginGate(),
      routes: {
        '/inbox': (context) => ChatView(),
        '/inbox/:id': (context) {
          final dynamic args = ModalRoute.of(context)?.settings.arguments;
          return ChatBody(userId: args['id']);
        }
      },
    );
  }
}

class LoginGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    LoginBloc _loginBloc = Provider.of<LoginBloc>(context);
    return StreamBuilder(
        stream: _loginBloc.authStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('There is an error');
            print(snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            print("Loading....");
          }
          if (snapshot.hasData) {
            Auth.User userData = snapshot.data as Auth.User;
            print('==${userData}');
            return Dashboard(uid: userData.uid);
          }

          return Login();
        });
  }
}

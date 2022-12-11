import 'package:ff/models/User.dart';
import 'package:ff/pages/Chat/ChatView.dart';
import 'package:ff/pages/Dashboard.dart';
import 'package:ff/pages/Login/Login.dart';
import 'package:firebase_auth/firebase_auth.dart' as Auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'blocs/UserBloc.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
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
      home: ChangeNotifierProvider(
          create: (context) => LoginBloc(), child: LoginGate()),
      routes: {
        '/inbox': (context) {
          // final dynamic args = ModalRoute.of(context)?.settings.arguments;
          //args['id']
          return ChatView();
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

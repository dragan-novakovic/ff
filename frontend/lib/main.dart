import 'package:ff/pages/Chat/ChatBody.dart';
import 'package:ff/pages/Chat/ChatView.dart';
import 'package:ff/pages/Dashboard.dart';
import 'package:ff/pages/FactoriesPage.dart';
import 'package:ff/pages/InventoryPage.dart';
import 'package:ff/pages/Login/Login.dart';
import 'package:ff/pages/MarketPage.dart';
import 'package:ff/pages/MissionsPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'blocs/GameAreaBlocs.dart';
import 'blocs/MessageBloc.dart';
import 'blocs/LoginBloc.dart';
import 'blocs/PlayerBloc.dart';
import 'models/User.dart';

void main() {
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LoginBloc()),
      ChangeNotifierProvider(create: (_) => MessageBloc()),
      ChangeNotifierProvider(create: (_) => PlayerBloc()),
      ChangeNotifierProvider(create: (_) => InventoryBloc()),
      ChangeNotifierProvider(create: (_) => FactoriesBloc()),
      ChangeNotifierProvider(create: (_) => MarketBloc()),
      ChangeNotifierProvider(create: (_) => MissionsBloc()),
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
        '/home': (context) => AuthenticatedHome(),
        '/inventory': (context) => AuthenticatedGamePage(
              builder: (user) => InventoryPage(user: user),
            ),
        '/factories': (context) => AuthenticatedGamePage(
              builder: (user) => FactoriesPage(user: user),
            ),
        '/market': (context) => AuthenticatedGamePage(
              builder: (user) => MarketPage(user: user),
            ),
        '/missions': (context) => AuthenticatedGamePage(
              builder: (user) => MissionsPage(user: user),
            ),
        '/inbox': (context) => ChatView(),
        '/inbox/chat': (context) {
          //  LoginBloc _userBloc = Provider.of<LoginBloc>(context);
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return ChatBody(
            contactId: args?['id'],
            userId: args?['userId'],
          );
        }
      },
    );
  }
}

class AuthenticatedGamePage extends StatelessWidget {
  final Widget Function(User user) builder;
  const AuthenticatedGamePage({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final loginBloc = Provider.of<LoginBloc>(context);
    return StreamBuilder(
      stream: loginBloc.authStateChange,
      initialData: loginBloc.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return builder(user);
        }

        return Login();
      },
    );
  }
}

class LoginGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    LoginBloc _loginBloc = Provider.of<LoginBloc>(context);
    return StreamBuilder<bool>(
      stream: _loginBloc.isRestoringSession,
      initialData: true,
      builder: (context, restoringSnapshot) {
        if (restoringSnapshot.data == true) {
          return const AuthLoadingScreen();
        }

        return StreamBuilder(
            stream: _loginBloc.authStateChange,
            initialData: _loginBloc.currentUser,
            builder: (context, snapshot) {
              final userData = snapshot.data;
              if (userData != null) {
                return Dashboard(uid: userData.uid);
              }

              return Login();
            });
      },
    );
  }
}

class AuthenticatedHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loginBloc = Provider.of<LoginBloc>(context);
    return StreamBuilder(
        stream: loginBloc.authStateChange,
        initialData: loginBloc.currentUser,
        builder: (context, snapshot) {
          final userData = snapshot.data;
          if (userData != null) {
            return Dashboard(uid: userData.uid);
          }

          return Login();
        });
  }
}

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

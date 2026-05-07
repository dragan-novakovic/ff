import 'package:ff/pages/Chat/ChatBody.dart';
import 'package:ff/pages/Chat/ChatView.dart';
import 'package:ff/pages/ActivityFeedPage.dart';
import 'package:ff/pages/AchievementsPage.dart';
import 'package:ff/pages/AdminConsolePage.dart';
import 'package:ff/pages/AccountSecurityPage.dart';
import 'package:ff/pages/CompaniesPage.dart';
import 'package:ff/pages/CongressPage.dart';
import 'package:ff/pages/CountryBattlesPage.dart';
import 'package:ff/pages/Dashboard.dart';
import 'package:ff/pages/diplomacy_page.dart';
import 'package:ff/pages/FactoriesPage.dart';
import 'package:ff/pages/InventoryPage.dart';
import 'package:ff/pages/Login/Login.dart';
import 'package:ff/pages/MarketPage.dart';
import 'package:ff/pages/MilitaryUnitsPage.dart';
import 'package:ff/pages/NewspapersPage.dart';
import 'package:ff/pages/MissionsPage.dart';
import 'package:ff/pages/PoliticsPage.dart';
import 'package:ff/pages/PublicProfilePage.dart';
import 'package:ff/pages/PushNotificationsPage.dart';
import 'package:ff/pages/RankingsPage.dart';
import 'package:ff/pages/ResearchPage.dart';
import 'package:ff/pages/ResourceLogisticsPage.dart';
import 'package:ff/pages/TerritoryPage.dart';
import 'package:ff/pages/WorldPage.dart';
import 'package:ff/pages/WorkforcePage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'blocs/GameAreaBlocs.dart';
import 'blocs/MessageBloc.dart';
import 'blocs/ActivityFeedBloc.dart';
import 'blocs/AchievementsBloc.dart';
import 'blocs/LoginBloc.dart';
import 'blocs/OnboardingQuestlineBloc.dart';
import 'blocs/PlayerBloc.dart';
import 'blocs/PushNotificationsBloc.dart';
import 'blocs/RankingsBloc.dart';
import 'blocs/ResourceLogisticsBloc.dart';
import 'models/User.dart';

void main() {
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LoginBloc()),
      ChangeNotifierProvider(create: (_) => MessageBloc()),
      ChangeNotifierProvider(create: (_) => PlayerBloc()),
      ChangeNotifierProvider(create: (_) => OnboardingQuestlineBloc()),
      ChangeNotifierProvider(create: (_) => InventoryBloc()),
      ChangeNotifierProvider(create: (_) => FactoriesBloc()),
      ChangeNotifierProvider(create: (_) => MarketBloc()),
      ChangeNotifierProvider(create: (_) => WorkforceBloc()),
      ChangeNotifierProvider(create: (_) => MissionsBloc()),
      ChangeNotifierProvider(create: (_) => CountryBattlesBloc()),
      ChangeNotifierProvider(create: (_) => MilitaryUnitsBloc()),
      ChangeNotifierProvider(create: (_) => CompaniesBloc()),
      ChangeNotifierProvider(create: (_) => PoliticsBloc()),
      ChangeNotifierProvider(create: (_) => CongressBloc()),
      ChangeNotifierProvider(create: (_) => DiplomacyBloc()),
      ChangeNotifierProvider(create: (_) => RankingsBloc()),
      ChangeNotifierProvider(create: (_) => WorldBloc()),
      ChangeNotifierProvider(create: (_) => TerritoryBloc()),
      ChangeNotifierProvider(create: (_) => ActivityFeedBloc()),
      ChangeNotifierProvider(create: (_) => PushNotificationsBloc()),
      ChangeNotifierProvider(create: (_) => AchievementsBloc()),
      ChangeNotifierProvider(create: (_) => NewspapersBloc()),
      ChangeNotifierProvider(create: (_) => ResearchBloc()),
      ChangeNotifierProvider(create: (_) => ResourceLogisticsBloc()),
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
        '/research': (context) => AuthenticatedGamePage(
              builder: (user) => ResearchPage(user: user),
            ),
        '/resource-logistics': (context) => AuthenticatedGamePage(
              builder: (user) => ResourceLogisticsPage(user: user),
            ),
        '/companies': (context) => AuthenticatedGamePage(
              builder: (user) => CompaniesPage(user: user),
            ),
        '/market': (context) => AuthenticatedGamePage(
              builder: (user) => MarketPage(user: user),
            ),
        '/workforce': (context) => AuthenticatedGamePage(
              builder: (user) => WorkforcePage(user: user),
            ),
        '/missions': (context) => AuthenticatedGamePage(
              builder: (user) => MissionsPage(user: user),
            ),
        '/activity': (context) => AuthenticatedGamePage(
              builder: (user) => ActivityFeedPage(user: user),
            ),
        '/push-notifications': (context) => AuthenticatedGamePage(
              builder: (user) => PushNotificationsPage(user: user),
            ),
        '/achievements': (context) => AuthenticatedGamePage(
              builder: (user) => AchievementsPage(user: user),
            ),
        '/media': (context) => AuthenticatedGamePage(
              builder: (user) => NewspapersPage(user: user),
            ),
        '/media/newspapers': (context) => AuthenticatedGamePage(
              builder: (user) => NewspapersPage(user: user),
            ),
        '/world': (context) => AuthenticatedGamePage(
              builder: (user) => WorldPage(user: user),
            ),
        '/territory': (context) => AuthenticatedGamePage(
              builder: (user) => TerritoryPage(user: user),
            ),
        '/country-battles': (context) => AuthenticatedGamePage(
              builder: (user) => CountryBattlesPage(user: user),
            ),
        '/military-units': (context) => AuthenticatedGamePage(
              builder: (user) => MilitaryUnitsPage(user: user),
            ),
        '/politics': (context) => AuthenticatedGamePage(
              builder: (user) => PoliticsPage(user: user),
            ),
        '/congress': (context) => AuthenticatedGamePage(
              builder: (user) => CongressPage(user: user),
            ),
        '/diplomacy': (context) => AuthenticatedGamePage(
              builder: (user) => DiplomacyPage(user: user),
            ),
        '/rankings': (context) => AuthenticatedGamePage(
              builder: (_) => const RankingsPage(),
            ),
        '/profile': (context) => AuthenticatedGamePage(
              builder: (user) {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                final playerId =
                    (args?['playerId'] ?? args?['id'] ?? user.uid).toString();
                return PublicProfilePage(playerId: playerId);
              },
            ),
        '/admin': (context) => AuthenticatedGamePage(
              builder: (_) => const AdminConsolePage(),
            ),
        '/account/security': (context) => AuthenticatedGamePage(
              builder: (user) => AccountSecurityPage(user: user),
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

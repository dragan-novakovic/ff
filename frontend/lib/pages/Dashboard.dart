import 'package:ff/blocs/AchievementsBloc.dart';
import 'package:ff/blocs/ActivityFeedBloc.dart';
import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/blocs/PushNotificationsBloc.dart';
import 'package:ff/blocs/RealtimeUpdatesBloc.dart';
import 'package:ff/components/OnboardingGuidanceCard.dart';
import 'package:ff/models/Achievements.dart';
import 'package:ff/models/DailyObjectives.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/OnboardingQuestline.dart';
import 'package:ff/models/PlayerState.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../blocs/LoginBloc.dart';
import '../components/InfoBox.dart';

class Dashboard extends StatefulWidget {
  final String uid;
  Dashboard({required String this.uid});

  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  late final LoginBloc _loginBloc;
  late final PlayerBloc _playerBloc;
  late final InventoryBloc _inventoryBloc;
  late final WorldBloc _worldBloc;
  late final TerritoryBloc _territoryBloc;
  late final PoliticsBloc _politicsBloc;
  late final DiplomacyBloc _diplomacyBloc;
  late final ActivityFeedBloc _activityFeedBloc;
  late final AchievementsBloc _achievementsBloc;
  late final OnboardingQuestlineBloc _onboardingBloc;
  late final PushNotificationsBloc _pushNotificationsBloc;
  late final RealtimeUpdatesBloc _realtimeBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
    _inventoryBloc = Provider.of<InventoryBloc>(context, listen: false);
    _worldBloc = Provider.of<WorldBloc>(context, listen: false);
    _territoryBloc = Provider.of<TerritoryBloc>(context, listen: false);
    _politicsBloc = Provider.of<PoliticsBloc>(context, listen: false);
    _diplomacyBloc = Provider.of<DiplomacyBloc>(context, listen: false);
    _activityFeedBloc = Provider.of<ActivityFeedBloc>(context, listen: false);
    _achievementsBloc = Provider.of<AchievementsBloc>(context, listen: false);
    _onboardingBloc =
        Provider.of<OnboardingQuestlineBloc>(context, listen: false);
    _pushNotificationsBloc =
        Provider.of<PushNotificationsBloc>(context, listen: false);
    _realtimeBloc = RealtimeUpdatesBloc();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final successMessage = _loginBloc.takeSuccessMessage();
      if (successMessage == null) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    });
    _loadProfile();
    _loadPlayerState();
    _loadDailyObjectives();
    _loadOnboardingQuestline();
    _loadEconomyWallet();
    _loadActivityFeed();
    _loadAchievements();
    _loadPushNotifications();
    _startRealtime();
  }

  Future<void> _loadProfile() async {
    try {
      await _loginBloc.fetchUserProfile(widget.uid);
    } on UserProfileNotFoundException {
      // The stream receives the backend error and the UI renders the retry state.
    }
  }

  Future<void> _loadPlayerState() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    await _playerBloc.loadState(widget.uid);
  }

  Future<void> _loadEconomyWallet() async {
    _inventoryBloc.setBearerToken(_loginBloc.currentToken);
    await _inventoryBloc.load(widget.uid);
  }

  Future<void> _loadDailyObjectives() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    await _playerBloc.loadDailyObjectives(widget.uid);
  }

  Future<void> _loadOnboardingQuestline() async {
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    await _onboardingBloc.load(widget.uid);
  }

  Future<void> _loadActivityFeed() async {
    _activityFeedBloc.setBearerToken(_loginBloc.currentToken);
    await _activityFeedBloc.load(widget.uid, limit: 10);
  }

  Future<void> _loadAchievements() async {
    _achievementsBloc.setBearerToken(_loginBloc.currentToken);
    await _achievementsBloc.load(widget.uid);
  }

  Future<void> _loadPushNotifications() async {
    _pushNotificationsBloc.setBearerToken(_loginBloc.currentToken);
    await _pushNotificationsBloc.load(widget.uid);
  }

  void _startRealtime() {
    _realtimeBloc.setBearerToken(_loginBloc.currentToken);
    _realtimeBloc.start(
      playerId: widget.uid,
      chatToId: 'global',
      limit: 10,
      onUpdate: (update) async {
        final activity = update.activity;
        if (activity != null) {
          _activityFeedBloc.applyRealtimeActivity(activity.feed, limit: 10);
        }
      },
    );
  }

  Future<void> _work() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.work(widget.uid);
    if (result != null) {
      await _loadDailyObjectives();
      await _loadOnboardingQuestline();
      await _loadEconomyWallet();
      await _loadAchievements();
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _playerBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _train() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.train(widget.uid);
    if (result != null) {
      await _loadDailyObjectives();
      await _loadOnboardingQuestline();
      await _loadAchievements();
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _playerBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _recoverAtHospital() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.recoverAtHospital(widget.uid);
    if (result != null) {
      await _loadDailyObjectives();
      await _loadEconomyWallet();
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _playerBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _claimDailyObjective(DailyObjective objective) async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.claimDailyObjective(
      playerId: widget.uid,
      objectiveId: objective.objectiveId,
    );
    if (result != null && (result.wallet != null || result.rewards.gold > 0)) {
      await _loadEconomyWallet();
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _playerBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _claimOnboardingQuest(OnboardingQuest quest) async {
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _onboardingBloc.claim(
      playerId: widget.uid,
      questId: quest.questId,
    );
    if (result != null) {
      if (result.state != null) {
        await _loadPlayerState();
      }
      if (result.wallet != null || result.rewards.gold > 0) {
        await _loadEconomyWallet();
      }
      await _loadAchievements();
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _onboardingBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _skipOnboardingQuest(OnboardingQuest quest) async {
    _onboardingBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _onboardingBloc.skip(
      playerId: widget.uid,
      questId: quest.questId,
    );
    if (result != null) {
      await _loadAchievements();
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? _onboardingBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _logout() async {
    _realtimeBloc.stop();
    _playerBloc.clear();
    _inventoryBloc.clear();
    _worldBloc.clear();
    _territoryBloc.clear();
    _politicsBloc.clear();
    _diplomacyBloc.clear();
    _activityFeedBloc.clear();
    _achievementsBloc.clear();
    _onboardingBloc.clear();
    await _loginBloc.logout();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out.')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  void dispose() {
    _realtimeBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LoginBloc loginBloc = Provider.of<LoginBloc>(context);

    return StreamBuilder(
        stream: loginBloc.userData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _dashboardScaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load your profile.',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasData) {
            final user = snapshot.data as User;
            return Consumer4<PlayerBloc, InventoryBloc, OnboardingQuestlineBloc,
                AchievementsBloc>(
              builder: (context, playerBloc, inventoryBloc, onboardingBloc,
                  achievementsBloc, _) {
                return _dashboardScaffold(
                  drawer: Drawer(
                      child: dashboardDrawer(context, user, playerBloc.state,
                          inventoryBloc.inventory)),
                  body: dashboardBody(
                    context,
                    user,
                    playerBloc,
                    inventoryBloc: inventoryBloc,
                    onboardingBloc: onboardingBloc,
                    achievementsBloc: achievementsBloc,
                    onRetry: _loadPlayerState,
                    onWork: _work,
                    onTrain: _train,
                    onRecoverAtHospital: _recoverAtHospital,
                    onRefreshDailyObjectives: _loadDailyObjectives,
                    onClaimDailyObjective: _claimDailyObjective,
                    onClaimOnboardingQuest: _claimOnboardingQuest,
                    onSkipOnboardingQuest: _skipOnboardingQuest,
                  ),
                );
              },
            );
          }

          return _dashboardScaffold(
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your home page...'),
                ],
              ),
            ),
          );
        });
  }

  Widget _dashboardScaffold({required Widget body, Widget? drawer}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Consumer<ActivityFeedBloc>(
              builder: (context, activityBloc, _) {
                final unreadCount = activityBloc.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            onPressed: () async {
              await Navigator.pushNamed(context, '/activity');
              if (mounted) {
                await _loadActivityFeed();
              }
            },
          ),
          IconButton(
            tooltip: 'Account security',
            icon: const Icon(Icons.security),
            onPressed: () {
              Navigator.pushNamed(context, '/account/security');
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: drawer,
      body: body,
    );
  }
}

Widget navTile(context, widget,
        {required String title,
        required String subtitle,
        String? route,
        String? props}) =>
    InkWell(
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(color: Colors.blue, fontSize: 12.0),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 18.0),
        ),
      ),
      onTap: () {
        if (route != null) {
          if (props != null) {
            Navigator.pushNamed(context, route, arguments: {'id': props});
          } else {
            Navigator.pushNamed(context, route);
          }

          return;
        }
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //       builder: (context) => FactoriesPage(userId: widget.user.id)),
        // );
      },
    );

Widget dashboardDrawer(
        context, User user, PlayerState? state, InventorySummary? inventory) =>
    ListView(
      children: <Widget>[
        Container(
          height: 250,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.5, 0.9],
                  colors: [Colors.blue.shade300, Colors.lightBlue])),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  CircularPercentIndicator(
                    radius: 100.0,
                    lineWidth: 10.0,
                    percent: 0.1,
                    center: CircleAvatar(
                      radius: 90,
                      child: ClipOval(
                        child: Image(
                            image: AssetImage('assets/images/avatar.png')),
                      ),
                    ),
                    reverse: true,
                    backgroundColor: Colors.white,
                    progressColor: Colors.blue.shade900,
                  ),
                ],
              ),
              Text(
                '${user.username}',
                style: TextStyle(fontSize: 22.0, color: Colors.white),
              ),
              Text(
                '${user.email}',
                style: TextStyle(fontSize: 14.0, color: Colors.grey.shade900),
              ),
            ],
          ),
        ),
        Container(
          // height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      state == null
                          ? '--'
                          : '${state.energy}/${state.maxEnergy}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24.0),
                    ),
                    subtitle: Text(
                      "ENERGY",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      inventory == null
                          ? '--'
                          : Utils.number(inventory.walletGold),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24.0),
                    ),
                    subtitle: Text(
                      "GOLD",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Inventory",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Storage", subtitle: "Inventory", route: '/inventory'),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "My Buildings",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Development",
                  subtitle: "Factories",
                  route: '/factories'),
              navTile(context, user,
                  title: "Development",
                  subtitle: "Research",
                  route: '/research'),
              navTile(context, user,
                  title: "Development",
                  subtitle: "Resources & Logistics",
                  route: '/resource-logistics'),
              navTile(context, user,
                  title: "Development", subtitle: "Training Grounds"),
              navTile(context, user,
                  title: "Development",
                  subtitle: "Buildings",
                  route: '/factories')
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Market",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Market", subtitle: "Food", route: '/market'),
              navTile(context, user,
                  title: "Market", subtitle: "Weapon", route: '/market'),
              navTile(context, user,
                  title: "Market", subtitle: "Factories", route: '/market'),
              navTile(context, user,
                  title: "Labor", subtitle: "Workforce", route: '/workforce')
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Missions",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Battle", subtitle: "Chapter I", route: '/missions'),
              navTile(context, user,
                  title: "Daily", subtitle: "Objectives", route: '/home'),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "World",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Countries", subtitle: "Citizenship", route: '/world'),
              navTile(context, user,
                  title: "Map", subtitle: "Territory", route: '/territory'),
              navTile(context, user,
                  title: "Countries",
                  subtitle: "Battles",
                  route: '/country-battles'),
              navTile(context, user,
                  title: "Military",
                  subtitle: "Units",
                  route: '/military-units'),
              navTile(context, user,
                  title: "Politics",
                  subtitle: "Parties & Elections",
                  route: '/politics'),
              navTile(context, user,
                  title: "Congress",
                  subtitle: "Laws & Votes",
                  route: '/congress'),
              navTile(context, user,
                  title: "Diplomacy",
                  subtitle: "Treaties & Relations",
                  route: '/diplomacy'),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Community",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Organizations",
                  subtitle: "Companies",
                  route: '/companies'),
              navTile(context, user,
                  title: "Organizations",
                  subtitle: "Jobs",
                  route: '/workforce'),
              navTile(context, user,
                  title: "Leaderboard",
                  subtitle: "Rankings",
                  route: '/rankings'),
              navTile(context, user,
                  title: "Medals",
                  subtitle: "Achievements",
                  route: '/achievements'),
              navTile(context, user,
                  title: "Profile", subtitle: "Public", route: '/profile'),
              navTile(context, user,
                  title: "Notifications",
                  subtitle: "Activity",
                  route: '/activity'),
              navTile(context, user,
                  title: "Notifications",
                  subtitle: "Push",
                  route: '/push-notifications'),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Media",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Press",
                  subtitle: "Newspapers",
                  route: '/media/newspapers'),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Operations",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Account",
                  subtitle: "Security",
                  route: '/account/security'),
              navTile(context, user,
                  title: "Admin", subtitle: "Moderation", route: '/admin'),
            ],
          ),
        ),
        InkWell(
          child: ExpansionTile(
            title: Text(
              "Channels",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user, title: "Channel", subtitle: "Global"),
              navTile(context, user, title: "Channel", subtitle: "Guild"),
              navTile(context, user,
                  title: 'Chat', subtitle: "Inbox", route: '/inbox')
            ],
          ),
        ),
      ],
    );

// Widget endDashboardDrawer(context, widget) => ListView(children: <Widget>[]);

Widget dashboardBody(
  BuildContext context,
  User user,
  PlayerBloc playerBloc, {
  required InventoryBloc inventoryBloc,
  required OnboardingQuestlineBloc onboardingBloc,
  required AchievementsBloc achievementsBloc,
  required Future<void> Function() onRetry,
  required Future<void> Function() onWork,
  required Future<void> Function() onTrain,
  required Future<void> Function() onRecoverAtHospital,
  required Future<void> Function() onRefreshDailyObjectives,
  required Future<void> Function(DailyObjective objective)
      onClaimDailyObjective,
  required Future<void> Function(OnboardingQuest quest) onClaimOnboardingQuest,
  required Future<void> Function(OnboardingQuest quest) onSkipOnboardingQuest,
}) {
  final state = playerBloc.state;
  if (state == null) {
    return _dashboardStatePlaceholder(
      context,
      isLoading: playerBloc.isLoading,
      error: playerBloc.error,
      onRetry: onRetry,
    );
  }

  return SingleChildScrollView(
    child: Column(
      children: <Widget>[
        Card(
          margin: EdgeInsets.all(12.0),
          child: ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Welcome, ${user.username}'),
            subtitle: Text('You are logged in. Your game state is synced.'),
          ),
        ),
        if (playerBloc.error != null)
          Card(
            margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            color: Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: Colors.redAccent),
              title: Text(playerBloc.error!),
              trailing: TextButton(
                onPressed: playerBloc.isLoading ? null : onRetry,
                child: Text('Retry'),
              ),
            ),
          ),
        if (onboardingBloc.error != null)
          Card(
            margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            color: Colors.orange.shade50,
            child: ListTile(
              leading: Icon(Icons.tour, color: Colors.orange.shade700),
              title: Text(onboardingBloc.error!),
            ),
          ),
        OnboardingGuidanceCard(
          questline: onboardingBloc.questline,
          onClaim: onClaimOnboardingQuest,
          onSkip: onSkipOnboardingQuest,
          onNavigate: onboardingBloc.currentQuest?.route == null
              ? null
              : () => Navigator.pushNamed(
                    context,
                    onboardingBloc.currentQuest!.route!,
                  ),
        ),
        _progressionCard(context, state, inventoryBloc.inventory),
        _achievementsSummaryCard(
          context,
          achievementsBloc.summary,
          isLoading: achievementsBloc.isLoading,
          error: achievementsBloc.error,
        ),
        _dailyActionsCard(
          state,
          isWorking: playerBloc.isWorking,
          isTraining: playerBloc.isTraining,
          isRecovering: playerBloc.isRecovering,
          onWork: onWork,
          onTrain: onTrain,
          onRecoverAtHospital: onRecoverAtHospital,
        ),
        _dailyObjectivesCard(
          playerBloc.dailyObjectives,
          isLoading: playerBloc.isLoadingObjectives,
          claimingObjectiveIds: playerBloc.claimingObjectiveIds,
          onRefresh: onRefreshDailyObjectives,
          onClaim: onClaimDailyObjective,
        ),
        InfoBox(),
      ],
    ),
  );
}

Widget _dashboardStatePlaceholder(
  BuildContext context, {
  required bool isLoading,
  required String? error,
  required Future<void> Function() onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading your player state...'),
          ] else ...[
            Icon(
              error == null ? Icons.info_outline : Icons.error_outline,
              size: 48,
              color: error == null ? Colors.blueGrey : Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              error ?? 'Player state is not loaded yet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Load player state'),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _progressionCard(
    BuildContext context, PlayerState state, InventorySummary? inventory) {
  return Card(
    margin: EdgeInsets.all(12.0),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Player progression',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statTile(
                icon: Icons.bolt,
                label: 'Energy',
                value: '${state.energy}/${state.maxEnergy}',
                subtitle: _energyRegenSubtitle(state),
                progress: state.energyProgress,
              ),
              _statTile(
                icon: Icons.military_tech,
                label: 'Level',
                value: '${state.level}',
                subtitle: '${state.experienceToNextLevel} XP to next level',
                progress: state.experienceProgress,
              ),
              _statTile(
                icon: Icons.fitness_center,
                label: 'Strength',
                value: '${state.strength}',
              ),
              _statTile(
                icon: Icons.paid,
                label: 'Wallet gold',
                value: inventory == null
                    ? '--'
                    : Utils.number(inventory.walletGold),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _achievementsSummaryCard(
  BuildContext context,
  AchievementsSummary? summary, {
  required bool isLoading,
  required String? error,
}) {
  return Card(
    margin: EdgeInsets.all(12.0),
    child: InkWell(
      onTap: () => Navigator.pushNamed(context, '/achievements'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Achievements & medals',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null && summary == null)
              Text(error, style: const TextStyle(color: Colors.redAccent))
            else if (summary == null)
              const Text(
                'Open the medal cabinet to load persisted achievements.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              LinearProgressIndicator(value: summary.progress, minHeight: 8),
              const SizedBox(height: 8),
              Text(
                '${summary.totalUnlocked}/${summary.totalAvailable} unlocked • ${summary.totalPoints} points • ${summary.unclaimedCount} claimable',
                style: const TextStyle(color: Colors.grey),
              ),
              if (summary.recentUnlocks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: summary.recentUnlocks.take(3).map((unlock) {
                    return Chip(
                      avatar: Icon(
                        Icons.military_tech,
                        color: _achievementRarityColor(unlock.medalRarity),
                        size: 18,
                      ),
                      label: Text(unlock.title),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}

Widget _statTile({
  required IconData icon,
  required String label,
  required String value,
  String? subtitle,
  double? progress,
}) {
  return Container(
    width: 250,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.blue.shade100),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
        if (progress != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
        ],
      ],
    ),
  );
}

Widget _dailyActionsCard(
  PlayerState state, {
  required bool isWorking,
  required bool isTraining,
  required bool isRecovering,
  required Future<void> Function() onWork,
  required Future<void> Function() onTrain,
  required Future<void> Function() onRecoverAtHospital,
}) {
  return Card(
    margin: EdgeInsets.all(12.0),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Player actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _dailyActionTile(
            icon: Icons.work,
            title: 'Work',
            subtitle: state.hasWorkedToday
                ? 'Done today. Resets ${_formatReset(state.nextResetAt)}.'
                : 'Earn 25 gold and 10 XP.',
            completed: state.hasWorkedToday,
            isLoading: isWorking,
            actionLabel: 'Work',
            onPressed: state.hasWorkedToday ? null : onWork,
          ),
          const Divider(),
          _dailyActionTile(
            icon: Icons.fitness_center,
            title: 'Train',
            subtitle: state.hasTrainedToday
                ? 'Done today. Resets ${_formatReset(state.nextResetAt)}.'
                : 'Gain 1 strength and 15 XP.',
            completed: state.hasTrainedToday,
            isLoading: isTraining,
            actionLabel: 'Train',
            onPressed: state.hasTrainedToday ? null : onTrain,
          ),
          const Divider(),
          _hospitalActionTile(
            state,
            isLoading: isRecovering,
            onPressed: state.canRecoverAtHospital ? onRecoverAtHospital : null,
          ),
        ],
      ),
    ),
  );
}

Widget _dailyObjectivesCard(
  DailyObjectivesSummary? summary, {
  required bool isLoading,
  required Set<String> claimingObjectiveIds,
  required Future<void> Function() onRefresh,
  required Future<void> Function(DailyObjective objective) onClaim,
}) {
  final objectives = summary?.objectives ?? const <DailyObjective>[];
  return Card(
    margin: EdgeInsets.all(12.0),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_circle, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daily objectives',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Refresh objectives',
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary == null
                ? 'Load today\'s objectives to track real gameplay progress.'
                : 'Resets ${_formatReset(summary.resetAt)}. ${summary.claimableCount} reward(s) ready.',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (summary == null && !isLoading)
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.flag),
              label: const Text('Load objectives'),
            )
          else
            ...objectives.map((objective) {
              final isClaiming =
                  claimingObjectiveIds.contains(objective.objectiveId);
              return Column(
                children: [
                  _dailyObjectiveTile(
                    objective,
                    isClaiming: isClaiming,
                    onClaim:
                        objective.claimable ? () => onClaim(objective) : null,
                  ),
                  if (objective != objectives.last) const Divider(),
                ],
              );
            }),
        ],
      ),
    ),
  );
}

Widget _dailyObjectiveTile(
  DailyObjective objective, {
  required bool isClaiming,
  required Future<void> Function()? onClaim,
}) {
  final statusIcon = objective.claimed
      ? Icons.verified
      : objective.completed
          ? Icons.card_giftcard
          : Icons.timelapse;
  final statusColor = objective.claimed
      ? Colors.green
      : objective.completed
          ? Colors.orange
          : Colors.blueGrey;
  final buttonLabel = objective.claimed
      ? 'Claimed'
      : objective.completed
          ? 'Claim'
          : '${objective.currentCount}/${objective.targetCount}';
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(statusIcon, color: statusColor),
    title: Text(objective.title),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(objective.description),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: objective.progress),
        const SizedBox(height: 4),
        Text(
          '${objective.currentCount}/${objective.targetCount} • ${_rewardsText(objective.rewards)}',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    ),
    trailing: ElevatedButton.icon(
      onPressed: isClaiming ? null : onClaim,
      icon: isClaiming
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(objective.claimed ? Icons.check : Icons.redeem),
      label: Text(buttonLabel),
    ),
  );
}

Widget _hospitalActionTile(
  PlayerState state, {
  required bool isLoading,
  required Future<void> Function()? onPressed,
}) {
  final isFull = state.isEnergyFull;
  final isCoolingDown = state.isHospitalCoolingDown;
  final buttonLabel = isFull
      ? 'Full'
      : isCoolingDown
          ? 'Cooldown'
          : 'Recover';
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      isFull ? Icons.check_circle : Icons.local_hospital,
      color: isFull ? Colors.green : Colors.redAccent,
    ),
    title: const Text('Hospital recovery'),
    subtitle: Text(_hospitalSubtitle(state)),
    trailing: ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isFull ? Icons.check : Icons.healing),
      label: Text(buttonLabel),
    ),
  );
}

Widget _dailyActionTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool completed,
  required bool isLoading,
  required String actionLabel,
  required Future<void> Function()? onPressed,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(completed ? Icons.check_circle : icon,
        color: completed ? Colors.green : Colors.blue),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(completed ? Icons.check : Icons.play_arrow),
      label: Text(completed ? 'Done' : actionLabel),
    ),
  );
}

String _formatReset(DateTime resetAt) {
  return DateFormat('EEE HH:mm').format(resetAt.toLocal());
}

String _energyRegenSubtitle(PlayerState state) {
  if (state.isEnergyFull) {
    return 'Passive regeneration is capped at full energy.';
  }

  final nextRegenAt = state.nextEnergyRegenAt;
  final amount = state.energyRegenAmount <= 0 ? 1 : state.energyRegenAmount;
  if (nextRegenAt != null) {
    return 'Next +$amount energy at ${_formatReset(nextRegenAt)}.';
  }

  if (state.energyRegenSeconds > 0) {
    return 'Regenerates +$amount energy every ${_formatSeconds(state.energyRegenSeconds)}.';
  }

  return 'Passive energy regeneration is active.';
}

String _hospitalSubtitle(PlayerState state) {
  if (state.isEnergyFull) {
    return 'Energy is full. Hospital recovery is not needed.';
  }

  final cooldownUntil = state.hospitalCooldownUntil;
  if (cooldownUntil != null && cooldownUntil.isAfter(DateTime.now())) {
    return 'Next recovery available ${_formatReset(cooldownUntil)}.';
  }

  final restore = state.hospitalEnergyRestore <= 0
      ? state.maxEnergy - state.energy
      : state.hospitalEnergyRestore;
  final cost = state.hospitalGoldCost;
  final costText = cost > 0 ? ' for $cost gold' : '';
  return 'Recover up to $restore energy$costText.';
}

String _rewardsText(PlayerRewards rewards) {
  final parts = <String>[];
  if (rewards.gold > 0) {
    parts.add('${rewards.gold} gold');
  }
  if (rewards.experience > 0) {
    parts.add('${rewards.experience} XP');
  }
  if (rewards.strength > 0) {
    parts.add('${rewards.strength} strength');
  }
  if (rewards.energy > 0) {
    parts.add('${rewards.energy} energy');
  }

  return parts.isEmpty ? 'No reward' : parts.join(', ');
}

String _formatSeconds(int seconds) {
  if (seconds >= 60 && seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  return seconds == 1 ? '1 second' : '$seconds seconds';
}

Color _achievementRarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'gold':
      return Colors.amber.shade700;
    case 'silver':
      return Colors.blueGrey;
    case 'platinum':
      return Colors.lightBlue.shade700;
    default:
      return Colors.brown;
  }
}

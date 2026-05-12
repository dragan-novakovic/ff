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
      backgroundColor: const Color(0xFF08111E),
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
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
    Opacity(
      opacity: route == null ? 0.58 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: route == null
                ? null
                : () {
                    if (props != null) {
                      Navigator.pushNamed(context, route, arguments: {
                        'id': props,
                      });
                    } else {
                      Navigator.pushNamed(context, route);
                    }
                  },
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4ECF7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _drawerDestinationIcon(subtitle, route),
                      color: const Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (route == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

Widget dashboardDrawer(
    context, User user, PlayerState? state, InventorySummary? inventory) {
  return DecoratedBox(
    decoration: const BoxDecoration(color: Color(0xFFF4F7FB)),
    child: SafeArea(
      child: Column(
        children: [
          _drawerHeader(user, state, inventory),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              children: <Widget>[
                _drawerSection(
                  context,
                  title: 'Inventory',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Storage',
                        subtitle: 'Inventory',
                        route: '/inventory'),
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'My Buildings',
                  icon: Icons.domain_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Development',
                        subtitle: 'Factories',
                        route: '/factories'),
                    navTile(context, user,
                        title: 'Development',
                        subtitle: 'Research',
                        route: '/research'),
                    navTile(context, user,
                        title: 'Development',
                        subtitle: 'Resources & Logistics',
                        route: '/resource-logistics'),
                    navTile(context, user,
                        title: 'Development',
                        subtitle: 'Training Grounds',
                        route: '/training-grounds'),
                    navTile(context, user,
                        title: 'Development',
                        subtitle: 'Buildings',
                        route: '/factories')
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'Market',
                  icon: Icons.storefront_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Market', subtitle: 'Food', route: '/market'),
                    navTile(context, user,
                        title: 'Market', subtitle: 'Weapon', route: '/market'),
                    navTile(context, user,
                        title: 'Market',
                        subtitle: 'Factories',
                        route: '/market'),
                    navTile(context, user,
                        title: 'Contracts',
                        subtitle: 'Company Contracts',
                        route: '/company-contracts'),
                    navTile(context, user,
                        title: 'Labor',
                        subtitle: 'Exchange',
                        route: '/workforce')
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'Missions',
                  icon: Icons.flag_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Battle',
                        subtitle: 'Chapter I',
                        route: '/missions'),
                    navTile(context, user,
                        title: 'Daily',
                        subtitle: 'Objectives',
                        route: '/daily-campaigns'),
                    navTile(context, user,
                        title: 'Tutorial',
                        subtitle: 'Advisor',
                        route: '/advisor'),
                    navTile(context, user,
                        title: 'Hospital',
                        subtitle: 'Recovery Center',
                        route: '/recovery-center'),
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'World',
                  icon: Icons.public_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Countries',
                        subtitle: 'Citizenship',
                        route: '/world'),
                    navTile(context, user,
                        title: 'Budget',
                        subtitle: 'Treasury',
                        route: '/treasury'),
                    navTile(context, user,
                        title: 'Map',
                        subtitle: 'Territory',
                        route: '/territory'),
                    navTile(context, user,
                        title: 'Power',
                        subtitle: 'Country Rankings',
                        route: '/country-rankings'),
                    navTile(context, user,
                        title: 'War Room',
                        subtitle: 'Campaigns',
                        route: '/country-battles'),
                    navTile(context, user,
                        title: 'Reports',
                        subtitle: 'Battle Reports',
                        route: '/battle-reports'),
                    navTile(context, user,
                        title: 'Military',
                        subtitle: 'Unit HQ',
                        route: '/military-units'),
                    navTile(context, user,
                        title: 'Politics',
                        subtitle: 'Parties & Elections',
                        route: '/politics'),
                    navTile(context, user,
                        title: 'Congress',
                        subtitle: 'Laws & Votes',
                        route: '/congress'),
                    navTile(context, user,
                        title: 'Diplomacy',
                        subtitle: 'Treaties & Relations',
                        route: '/diplomacy'),
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'Community',
                  icon: Icons.groups_2_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Organizations',
                        subtitle: 'Companies',
                        route: '/companies'),
                    navTile(context, user,
                        title: 'Organizations',
                        subtitle: 'Labor Exchange',
                        route: '/workforce'),
                    navTile(context, user,
                        title: 'Hall of Fame',
                        subtitle: 'Rankings',
                        route: '/rankings'),
                    navTile(context, user,
                        title: 'Medals',
                        subtitle: 'Achievements',
                        route: '/achievements'),
                    navTile(context, user,
                        title: 'Citizen',
                        subtitle: 'Dossier',
                        route: '/profile'),
                    navTile(context, user,
                        title: 'Notifications',
                        subtitle: 'Activity',
                        route: '/activity'),
                    navTile(context, user,
                        title: 'Notifications',
                        subtitle: 'Push',
                        route: '/push-notifications'),
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'Media',
                  icon: Icons.newspaper_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Press',
                        subtitle: 'Newspapers',
                        route: '/media/newspapers'),
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'Operations',
                  icon: Icons.admin_panel_settings_outlined,
                  children: [
                    navTile(context, user,
                        title: 'Account',
                        subtitle: 'Security',
                        route: '/account/security'),
                    navTile(context, user,
                        title: 'Admin',
                        subtitle: 'Moderation',
                        route: '/admin'),
                  ],
                ),
                _drawerSection(
                  context,
                  title: 'Channels',
                  icon: Icons.chat_bubble_outline_rounded,
                  children: [
                    navTile(context, user,
                        title: 'Channel', subtitle: 'Global'),
                    navTile(context, user, title: 'Channel', subtitle: 'Guild'),
                    navTile(context, user,
                        title: 'Chat', subtitle: 'Inbox', route: '/inbox')
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _drawerHeader(
    User user, PlayerState? state, InventorySummary? inventory) {
  final energyText =
      state == null ? '--' : '${state.energy}/${state.maxEnergy}';
  final goldText =
      inventory == null ? '--' : Utils.number(inventory.walletGold);
  final detailText =
      state == null ? 'Loading citizen data' : 'Level ${state.level} citizen';

  return Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0F172A),
          Color(0xFF1D4ED8),
          Color(0xFF38BDF8),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.blue.shade900.withOpacity(0.22),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircularPercentIndicator(
              radius: 66,
              lineWidth: 7,
              percent: state?.energyProgress ?? 0,
              circularStrokeCap: CircularStrokeCap.round,
              backgroundColor: Colors.white.withOpacity(0.22),
              progressColor: const Color(0xFFFACC15),
              center: CircleAvatar(
                radius: 27,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: Image(
                    image: const AssetImage('assets/images/avatar.png'),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Text(
                      detailText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _drawerMetric(
                icon: Icons.bolt_rounded,
                label: 'Energy',
                value: energyText,
                color: const Color(0xFFFACC15),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _drawerMetric(
                icon: Icons.monetization_on_outlined,
                label: 'Gold',
                value: goldText,
                color: const Color(0xFFFDE68A),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _drawerMetric({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.16)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.76),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _drawerSection(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<Widget> children,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF0369A1), size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          iconColor: const Color(0xFF2563EB),
          collapsedIconColor: const Color(0xFF64748B),
          children: children,
        ),
      ),
    ),
  );
}

IconData _drawerDestinationIcon(String subtitle, String? route) {
  switch (route) {
    case '/inventory':
      return Icons.inventory_2_outlined;
    case '/advisor':
      return Icons.assistant_outlined;
    case '/factories':
      return Icons.factory_outlined;
    case '/research':
      return Icons.science_outlined;
    case '/resource-logistics':
      return Icons.local_shipping_outlined;
    case '/market':
      return Icons.storefront_outlined;
    case '/company-contracts':
      return Icons.handshake_outlined;
    case '/workforce':
      return Icons.engineering_outlined;
    case '/missions':
      return Icons.flag_outlined;
    case '/daily-campaigns':
      return Icons.checklist_rtl_outlined;
    case '/training-grounds':
      return Icons.fitness_center_outlined;
    case '/recovery-center':
      return Icons.local_hospital_outlined;
    case '/home':
      return Icons.checklist_rtl_outlined;
    case '/world':
      return Icons.public_outlined;
    case '/treasury':
      return Icons.account_balance_outlined;
    case '/territory':
      return Icons.map_outlined;
    case '/country-rankings':
      return Icons.leaderboard_outlined;
    case '/country-battles':
      return Icons.shield_outlined;
    case '/battle-reports':
      return Icons.receipt_long_outlined;
    case '/military-units':
      return Icons.groups_3_outlined;
    case '/politics':
      return Icons.how_to_vote_outlined;
    case '/congress':
      return Icons.gavel_outlined;
    case '/diplomacy':
      return Icons.handshake_outlined;
    case '/companies':
      return Icons.business_center_outlined;
    case '/rankings':
      return Icons.leaderboard_outlined;
    case '/achievements':
      return Icons.emoji_events_outlined;
    case '/profile':
      return Icons.person_outline;
    case '/activity':
      return Icons.notifications_none_outlined;
    case '/push-notifications':
      return Icons.notification_add_outlined;
    case '/media/newspapers':
      return Icons.newspaper_outlined;
    case '/account/security':
      return Icons.security_outlined;
    case '/admin':
      return Icons.admin_panel_settings_outlined;
    case '/inbox':
      return Icons.chat_bubble_outline_rounded;
  }

  switch (subtitle.toLowerCase()) {
    case 'global':
      return Icons.public_outlined;
    case 'guild':
      return Icons.groups_outlined;
    case 'training grounds':
      return Icons.fitness_center_outlined;
    default:
      return Icons.grid_view_rounded;
  }
}

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
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _homeHero(user, state, inventoryBloc.inventory),
        const SizedBox(height: 16),
        if (playerBloc.error != null)
          _dashboardMessageCard(
            message: playerBloc.error!,
            icon: Icons.warning_amber_rounded,
            color: Colors.redAccent,
            action: TextButton(
              onPressed: playerBloc.isLoading ? null : onRetry,
              child: const Text('Retry'),
            ),
          ),
        if (onboardingBloc.error != null)
          _dashboardMessageCard(
            message: onboardingBloc.error!,
            icon: Icons.tour,
            color: const Color(0xFFF97316),
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
        const SizedBox(height: 12),
        _advisorPulseCard(
          context,
          state: state,
          inventory: inventoryBloc.inventory,
          dailyObjectives: playerBloc.dailyObjectives,
          questline: onboardingBloc.questline,
          achievements: achievementsBloc.summary,
        ),
        const SizedBox(height: 16),
        _progressionCard(context, state, inventoryBloc.inventory),
        const SizedBox(height: 16),
        _achievementsSummaryCard(
          context,
          achievementsBloc.summary,
          isLoading: achievementsBloc.isLoading,
          error: achievementsBloc.error,
        ),
        const SizedBox(height: 16),
        _dailyActionsCard(
          state,
          isWorking: playerBloc.isWorking,
          isTraining: playerBloc.isTraining,
          isRecovering: playerBloc.isRecovering,
          onWork: onWork,
          onTrain: onTrain,
          onRecoverAtHospital: onRecoverAtHospital,
        ),
        const SizedBox(height: 16),
        _dailyObjectivesCard(
          playerBloc.dailyObjectives,
          isLoading: playerBloc.isLoadingObjectives,
          claimingObjectiveIds: playerBloc.claimingObjectiveIds,
          onRefresh: onRefreshDailyObjectives,
          onClaim: onClaimDailyObjective,
        ),
        const SizedBox(height: 16),
        const InfoBox(),
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
      child: Card(
        color: const Color(0xFF0F2136),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Loading your command center...',
                  style: TextStyle(color: Colors.white),
                ),
              ] else ...[
                Icon(
                  error == null ? Icons.info_outline : Icons.error_outline,
                  size: 48,
                  color: error == null
                      ? const Color(0xFF67E8F9)
                      : Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  error ?? 'Player state is not loaded yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
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
      ),
    ),
  );
}

Widget _homeHero(User user, PlayerState state, InventorySummary? inventory) {
  return Card(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1020),
            Color(0xFF1E3A8A),
            Color(0xFF7C2D12),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -32,
            child: Icon(
              Icons.public,
              size: 178,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -22,
            child: Icon(
              Icons.military_tech,
              size: 124,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const Spacer(),
                    const _DashboardPill(
                      label: 'Synced',
                      color: Color(0xFF86EFAC),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Command Center',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome, ${user.username}. Your citizen is ready for today\'s economy, training, missions, and national objectives.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DashboardHeroStat(
                      icon: Icons.bolt,
                      label: 'Energy',
                      value: '${state.energy}/${state.maxEnergy}',
                    ),
                    _DashboardHeroStat(
                      icon: Icons.military_tech,
                      label: 'Level',
                      value: state.level.toString(),
                    ),
                    _DashboardHeroStat(
                      icon: Icons.fitness_center,
                      label: 'Strength',
                      value: state.strength.toString(),
                    ),
                    _DashboardHeroStat(
                      icon: Icons.monetization_on,
                      label: 'Gold',
                      value: inventory == null
                          ? '--'
                          : Utils.number(inventory.walletGold),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DashboardProgressLine(
                  label: 'Experience toward next level',
                  valueLabel: '${state.experienceToNextLevel} XP needed',
                  value: state.experienceProgress,
                  color: const Color(0xFFFBBF24),
                  bright: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _advisorPulseCard(
  BuildContext context, {
  required PlayerState state,
  required InventorySummary? inventory,
  required DailyObjectivesSummary? dailyObjectives,
  required OnboardingQuestline? questline,
  required AchievementsSummary? achievements,
}) {
  final signals = _advisorSignalCount(
    state: state,
    inventory: inventory,
    dailyObjectives: dailyObjectives,
    questline: questline,
    achievements: achievements,
  );
  final currentQuest = questline?.currentQuest;
  final headline = currentQuest == null
      ? 'Advisor is watching your next best move'
      : currentQuest.claimable
          ? 'Tutorial reward is ready to claim'
          : 'Tutorial focus: ${currentQuest.title}';
  final detail = currentQuest == null
      ? 'Open the advisor for adaptive priorities from player, economy, daily objective, achievement, battle, and notification state.'
      : currentQuest.claimable
          ? currentQuest.description
          : currentQuest.guidance;

  return Card(
    color: const Color(0xFF0F2136),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.14),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: const Color(0xFF38BDF8).withOpacity(0.32),
              ),
            ),
            child: const Icon(Icons.assistant, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$signals signals',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.66),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/advisor'),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Open advisor'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

int _advisorSignalCount({
  required PlayerState state,
  required InventorySummary? inventory,
  required DailyObjectivesSummary? dailyObjectives,
  required OnboardingQuestline? questline,
  required AchievementsSummary? achievements,
}) {
  var count = 0;
  if (questline?.currentQuest != null) {
    count++;
  }
  if (dailyObjectives != null && dailyObjectives.claimableCount > 0) {
    count++;
  }
  if (achievements != null && achievements.unclaimedCount > 0) {
    count++;
  }
  if (!state.hasWorkedToday) {
    count++;
  }
  if (!state.hasTrainedToday) {
    count++;
  }
  if (state.canRecoverAtHospital || state.energyProgress < 0.35) {
    count++;
  }
  if (inventory != null &&
      inventory.storageLimit > 0 &&
      inventory.storageUsed / inventory.storageLimit >= 0.8) {
    count++;
  }
  return count;
}

Widget _dashboardMessageCard({
  required String message,
  required IconData icon,
  required Color color,
  Widget? action,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    color: color.withOpacity(0.12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (action != null) action,
        ],
      ),
    ),
  );
}

Widget _progressionCard(
    BuildContext context, PlayerState state, InventorySummary? inventory) {
  return Card(
    color: const Color(0xFF0F2136),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeader(
            icon: Icons.trending_up,
            title: 'Citizen progression',
            subtitle: 'Core stats, regeneration, and economy readiness.',
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
                color: const Color(0xFF22C55E),
              ),
              _statTile(
                icon: Icons.military_tech,
                label: 'Level',
                value: '${state.level}',
                subtitle: '${state.experienceToNextLevel} XP to next level',
                progress: state.experienceProgress,
                color: const Color(0xFFFBBF24),
              ),
              _statTile(
                icon: Icons.fitness_center,
                label: 'Strength',
                value: '${state.strength}',
                subtitle: state.hasTrainedToday
                    ? 'Daily training complete.'
                    : 'Training available today.',
                color: const Color(0xFFA78BFA),
              ),
              _statTile(
                icon: Icons.paid,
                label: 'Wallet gold',
                value: inventory == null
                    ? '--'
                    : Utils.number(inventory.walletGold),
                subtitle: inventory == null
                    ? 'Vault still loading.'
                    : '${inventory.storageUsed}/${inventory.storageLimit} storage slots used.',
                color: const Color(0xFF38BDF8),
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
    color: const Color(0xFF0F2136),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => Navigator.pushNamed(context, '/achievements'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _DashboardSectionHeader(
                    icon: Icons.emoji_events,
                    title: 'Medal cabinet',
                    subtitle: 'Persistent achievements and claimable rewards.',
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null && summary == null)
              Text(error, style: const TextStyle(color: Colors.redAccent))
            else if (summary == null)
              Text(
                'Open the medal cabinet to load persisted achievements.',
                style: TextStyle(color: Colors.white.withOpacity(0.64)),
              )
            else ...[
              _DashboardProgressLine(
                label: 'Achievement mastery',
                valueLabel:
                    '${summary.totalUnlocked}/${summary.totalAvailable} medals',
                value: summary.progress,
                color: const Color(0xFFFBBF24),
              ),
              const SizedBox(height: 8),
              Text(
                '${summary.totalPoints} points - ${summary.unclaimedCount} claimable reward(s)',
                style: TextStyle(color: Colors.white.withOpacity(0.64)),
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
                      backgroundColor: Colors.white.withOpacity(0.10),
                      labelStyle: const TextStyle(color: Colors.white),
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
  required Color color,
  String? subtitle,
  double? progress,
}) {
  return Container(
    width: 260,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0B1728),
      border: Border.all(color: color.withOpacity(0.36)),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.62)),
          ),
        ],
        if (progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
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
    color: const Color(0xFF0F2136),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeader(
            icon: Icons.flash_on,
            title: 'Daily command queue',
            subtitle: 'Spend today\'s action windows before the daily reset.',
          ),
          const SizedBox(height: 16),
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
            color: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 12),
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
            color: const Color(0xFFA78BFA),
          ),
          const SizedBox(height: 12),
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
    color: const Color(0xFF0F2136),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _DashboardSectionHeader(
                  icon: Icons.flag_circle,
                  title: 'Daily objectives',
                  subtitle: 'Complete real gameplay tasks and claim rewards.',
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
                    : const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary == null
                ? 'Load today\'s objectives to track real gameplay progress.'
                : 'Resets ${_formatReset(summary.resetAt)}. ${summary.claimableCount} reward(s) ready.',
            style: TextStyle(color: Colors.white.withOpacity(0.64)),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _dailyObjectiveTile(
                  objective,
                  isClaiming: isClaiming,
                  onClaim:
                      objective.claimable ? () => onClaim(objective) : null,
                ),
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
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0B1728),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: statusColor.withOpacity(0.28)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.14),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                objective.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                objective.description,
                style: TextStyle(color: Colors.white.withOpacity(0.66)),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: objective.progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${objective.currentCount}/${objective.targetCount} - ${_rewardsText(objective.rewards)}',
                style: TextStyle(color: Colors.white.withOpacity(0.56)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
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
      ],
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
  final color = isFull ? const Color(0xFF22C55E) : Colors.redAccent;
  return _dashboardActionPanel(
    icon: isFull ? Icons.check_circle : Icons.local_hospital,
    title: 'Hospital recovery',
    subtitle: _hospitalSubtitle(state),
    completed: isFull,
    isLoading: isLoading,
    actionLabel: buttonLabel,
    onPressed: onPressed,
    color: color,
    loadingIcon: Icons.healing,
  );
}

Widget _dashboardActionPanel({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool completed,
  required bool isLoading,
  required String actionLabel,
  required Future<void> Function()? onPressed,
  required Color color,
  required IconData loadingIcon,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0B1728),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.28)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(completed ? Icons.check_circle : icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.64)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(completed ? Icons.check : loadingIcon),
          label: Text(completed ? 'Done' : actionLabel),
        ),
      ],
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
  required Color color,
}) {
  return _dashboardActionPanel(
    icon: icon,
    title: title,
    subtitle: subtitle,
    completed: completed,
    isLoading: isLoading,
    actionLabel: actionLabel,
    onPressed: onPressed,
    color: completed ? const Color(0xFF22C55E) : color,
    loadingIcon: Icons.play_arrow,
  );
}

class _DashboardSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DashboardSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.66)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardHeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DashboardHeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPill extends StatelessWidget {
  final String label;
  final Color color;

  const _DashboardPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.72)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DashboardProgressLine extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;
  final bool bright;

  const _DashboardProgressLine({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
    this.bright = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = bright ? Colors.white : Colors.white.withOpacity(0.82);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(color: Colors.white.withOpacity(0.66)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 9,
            backgroundColor: Colors.white.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
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

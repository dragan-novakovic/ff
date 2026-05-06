import 'package:ff/blocs/PlayerBloc.dart';
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

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _playerBloc = Provider.of<PlayerBloc>(context, listen: false);
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

  Future<void> _work() async {
    _playerBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _playerBloc.work(widget.uid);
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

  Future<void> _logout() async {
    _playerBloc.clear();
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
            return Consumer<PlayerBloc>(
              builder: (context, playerBloc, _) {
                return _dashboardScaffold(
                  drawer: Drawer(
                      child: dashboardDrawer(context, user, playerBloc.state)),
                  body: dashboardBody(
                    context,
                    user,
                    playerBloc,
                    onRetry: _loadPlayerState,
                    onWork: _work,
                    onTrain: _train,
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
            icon: const Icon(Icons.notifications),
            onPressed: () {},
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

Widget dashboardDrawer(context, User user, PlayerState? state) => ListView(
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
                      state == null ? '--' : Utils.number(state.gold),
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
              "My Buildings",
              style: TextStyle(color: Colors.blue, fontSize: 12.0),
            ),
            children: <Widget>[
              navTile(context, user,
                  title: "Development", subtitle: "Factories"),
              navTile(context, user,
                  title: "Development", subtitle: "Training Grounds"),
              navTile(context, user,
                  title: "Development", subtitle: "Buildings")
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
              navTile(context, user, title: "Market", subtitle: "Food"),
              navTile(context, user, title: "Market", subtitle: "Weapon"),
              navTile(context, user, title: "Market", subtitle: "Factories")
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
  required Future<void> Function() onRetry,
  required Future<void> Function() onWork,
  required Future<void> Function() onTrain,
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
        _progressionCard(context, state),
        _dailyActionsCard(
          state,
          isWorking: playerBloc.isWorking,
          isTraining: playerBloc.isTraining,
          onWork: onWork,
          onTrain: onTrain,
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

Widget _progressionCard(BuildContext context, PlayerState state) {
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
                label: 'Gold',
                value: Utils.number(state.gold),
              ),
            ],
          ),
        ],
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
  required Future<void> Function() onWork,
  required Future<void> Function() onTrain,
}) {
  return Card(
    margin: EdgeInsets.all(12.0),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily actions',
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
        ],
      ),
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

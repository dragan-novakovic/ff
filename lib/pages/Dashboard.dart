import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:responsive_scaffold_nullsafe/responsive_scaffold.dart';

import '../blocs/LoginBloc.dart';
import '../components/InfoBox.dart';

class Dashboard extends StatefulWidget {
  final String uid;
  Dashboard({required String this.uid});

  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  @override
  void initState() {
    super.initState();
    LoginBloc _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _loginBloc
        .fetchUserProfile(widget.uid)
        .then((value) => {print('who is faster? me?')});
  }

  @override
  Widget build(BuildContext context) {
    LoginBloc _loginBloc = Provider.of<LoginBloc>(context);

    return StreamBuilder(
        stream: _loginBloc.userData,
        builder: (context, snapshot) {
          print('or me?');
          if (snapshot.hasError) {
            print('There is an error');
            print(snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            print("Loading....");
          }
          if (snapshot.hasData) {
            //fix this
            return ResponsiveScaffold(
                title: Text('Dashboard'),
                drawer: dashboardDrawer(context, snapshot.data as User),
                endIcon: Icons.filter_list,
                // endDrawer: endDashboardDrawer(context, widget),
                trailing: IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () {},
                ),
                body: dashboardBody(context, snapshot.data as User));
          }

          return Text("Real Loading I guess? Before the re-build?");
        });
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

Widget dashboardDrawer(context, User user) => ListView(
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
                      '100',
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
                      Utils.number(12000),
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

Widget dashboardBody(context, user) => Column(
      children: <Widget>[
        InfoBox(),
        Column(
          children: <Widget>[
            Container(
              child: ListTile(
                title: Text("You did't work today"),
                leading: Icon(Icons.access_time),
              ),
            ),
            Container(
              child: ListTile(
                title: Text("You did't train today"),
                leading: Icon(Icons.access_time),
              ),
            ),
            Container(
              child: ListTile(
                title: Text("Go to Battle"),
                leading: Icon(Icons.access_alarm),
              ),
            )
          ],
        ),
      ],
    );

import 'package:ff/models/User.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:responsive_scaffold_nullsafe/responsive_scaffold.dart';

class Dashboard extends StatefulWidget {
  Dashboard({required this.user});
  final User user;

  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
        title: Text('Dashboard'),
        drawer: dashboardDrawer(context, widget),
        endIcon: Icons.filter_list,
        // endDrawer: endDashboardDrawer(context, widget),
        trailing: IconButton(
          icon: Icon(Icons.notifications),
          onPressed: () {},
        ),
        body: dashboardBody(context, widget));
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

Widget dashboardDrawer(context, widget) => ListView(
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
                        child: Image.network(
                          'https://placeimg.com/200/200/people',
                          width: 200,
                          height: 200,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    reverse: true,
                    backgroundColor: Colors.white,
                    progressColor: Colors.blue.shade900,
                  ),
                ],
              ),
              Text(
                '${widget.user.username}',
                style: TextStyle(fontSize: 22.0, color: Colors.white),
              ),
              Text(
                '${widget.user.email}',
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
                      '${widget.user.playerData.energy}',
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
                      Utils.number(widget.user.playerData.gold),
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
              navTile(context, widget,
                  title: "Development", subtitle: "Factories"),
              navTile(context, widget,
                  title: "Development", subtitle: "Training Grounds"),
              navTile(context, widget,
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
              navTile(context, widget, title: "Market", subtitle: "Food"),
              navTile(context, widget, title: "Market", subtitle: "Weapon"),
              navTile(context, widget, title: "Market", subtitle: "Factories")
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
              navTile(context, widget,
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
              navTile(context, widget, title: "Channel", subtitle: "Global"),
              navTile(context, widget, title: "Channel", subtitle: "Guild"),
              navTile(context, widget,
                  title: 'Chat', subtitle: "Inbox", route: '/inbox')
            ],
          ),
        ),
      ],
    );

// Widget endDashboardDrawer(context, widget) => ListView(children: <Widget>[]);

Widget dashboardBody(context, widget) => Column(
      children: <Widget>[
        Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                color: Colors.blueAccent),
            margin: EdgeInsets.all(12),
            height: 160,
            width: MediaQuery.of(context).size.width - 40,
            child: Column(children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                    alignment: Alignment.topLeft,
                    child: Text(
                      "News:",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    )),
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.vertical,
                  children: <Widget>[
                    ListTile(
                      title: Text("Added Player Inventory"),
                      dense: true,
                      leading: Icon(
                        Icons.fiber_manual_record,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                    ListTile(
                      title: Text(
                          "New factory resourses, added weapon quality and gold reward"),
                      dense: true,
                      leading: Icon(
                        Icons.fiber_manual_record,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                    ListTile(
                      title: Text(
                          "Storage implemented, with maximum starting capacity of 100"),
                      dense: true,
                      leading: Icon(
                        Icons.fiber_manual_record,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ])),
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

//import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff/models/User.dart';
import 'package:ff/pages/Factories.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:responsive_scaffold/responsive_scaffold.dart';

class Dashboard extends StatefulWidget {
  Dashboard({@required this.user});
  final User user;

  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: Text('Dashboard'),
      drawer: ListView(
        children: <Widget>[
          Container(
            height: 200,
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
                        radius: 40,
                        child: ClipOval(
                          child: Image.network(
                            'https://placeimg.com/200/200/people',
                            width: 100,
                            height: 100,
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
                SizedBox(
                  height: 20,
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
                    title: "Development", subtitle: "Buildings"),
                navTile(context, widget,
                    title: "Development", subtitle: "Storage")
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
                navTile(context, widget,
                    title: "Development", subtitle: "Factories"),
                navTile(context, widget,
                    title: "Development", subtitle: "Buildings"),
                navTile(context, widget,
                    title: "Development", subtitle: "Storage")
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
                navTile(context, widget,
                    title: "Development", subtitle: "Factories"),
                navTile(context, widget,
                    title: "Development", subtitle: "Buildings"),
                navTile(context, widget,
                    title: "Development", subtitle: "Storage")
              ],
            ),
          ),
        ],
      ),
      endIcon: Icons.filter_list,
      endDrawer: ListView(
        children: <Widget>[],
      ),
      trailing: IconButton(
        icon: Icon(Icons.search),
        onPressed: () {},
      ),
      body: Column(
        children: <Widget>[
          Center(
            child: Container(
                color: Colors.blueAccent,
                margin: EdgeInsets.all(8),
                height: 100,
                width: MediaQuery.of(context).size.width - 40,
                child: Text("News")),
          ),
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
              )
            ],
          ),
        ],
      ),
    );
  }
}

Widget navTile(context, widget, {String title, String subtitle}) => InkWell(
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
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => FactoriesPage(userId: widget.user.id)),
        );
      },
    );

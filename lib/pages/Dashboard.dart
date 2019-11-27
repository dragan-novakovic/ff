//import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff/models/User.dart';
import 'package:ff/pages/Factories.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
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
                    CircleAvatar(
                      minRadius: 60,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                          backgroundImage: NetworkImage(
                              "http://via.placeholder.com/400x400")),
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
            child: ListTile(
              title: Text(
                "Development",
                style: TextStyle(color: Colors.blue, fontSize: 12.0),
              ),
              subtitle: Text(
                "Factories",
                style: TextStyle(fontSize: 18.0),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        FactoriesPage(userId: widget.user.id)),
              );
            },
          ),
          Divider(),
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

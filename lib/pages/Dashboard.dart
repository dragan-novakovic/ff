//import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff/models/User.dart';
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
                    colors: [Colors.red, Colors.deepOrange.shade300])),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    CircleAvatar(
                      minRadius: 60,
                      backgroundColor: Colors.deepOrange.shade300,
                      child: CircleAvatar(
                          backgroundImage: NetworkImage(
                              "http://via.placeholder.com/350x150")),
                    ),
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  '${widget.user.username}',
                  style: TextStyle(fontSize: 22.0, color: Colors.white),
                ),
                Text(
                  '${widget.user.email}',
                  style: TextStyle(fontSize: 14.0, color: Colors.red.shade700),
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
                    color: Colors.deepOrange.shade300,
                    child: ListTile(
                      title: Text(
                        "50",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24.0),
                      ),
                      subtitle: Text(
                        "FACTORIES",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.red,
                    child: ListTile(
                      title: Text(
                        "34524",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24.0),
                      ),
                      subtitle: Text(
                        "GOLD",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(
              "Email",
              style: TextStyle(color: Colors.deepOrange, fontSize: 12.0),
            ),
            subtitle: Text(
              "ram@kumar.com",
              style: TextStyle(fontSize: 18.0),
            ),
          ),
          Divider(),
          ListTile(
            title: Text(
              "Phone",
              style: TextStyle(color: Colors.deepOrange, fontSize: 12.0),
            ),
            subtitle: Text(
              "+977 9818225533",
              style: TextStyle(fontSize: 18.0),
            ),
          ),
          Divider(),
          ListTile(
            title: Text(
              "Twitter",
              style: TextStyle(color: Colors.deepOrange, fontSize: 12.0),
            ),
            subtitle: Text(
              "@ramkumar",
              style: TextStyle(fontSize: 18.0),
            ),
          ),
          Divider(),
          ListTile(
            title: Text(
              "Facebook",
              style: TextStyle(color: Colors.deepOrange, fontSize: 12.0),
            ),
            subtitle: Text(
              "facebook.com/ramkumar",
              style: TextStyle(fontSize: 18.0),
            ),
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
      body: Center(
        child: GridView.count(
          primary: false,
          crossAxisSpacing: 10.0,
          crossAxisCount: 3,
          children: <Widget>[
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(5.0),
              alignment: Alignment.center,
              child: Text(
                "Grid Elemanı",
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

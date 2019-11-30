import 'package:flutter/material.dart';

import 'package:responsive_scaffold/responsive_scaffold.dart';

class MissionsPage extends StatefulWidget {
  @override
  _MissionsState createState() => _MissionsState();
}

class _MissionsState extends State<MissionsPage> {
  var _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ResponsiveListScaffold.builder(
        scaffoldKey: _scaffoldKey,
        detailBuilder: (BuildContext context, int index, bool tablet) {
          return _detailScreen(tablet, context, index);
        },
        nullItems: Center(child: CircularProgressIndicator()),
        emptyItems: Center(child: Text("No Items Found")),
        slivers: <Widget>[
          SliverAppBar(
            title: Text("Missions"),
          ),
        ],
        itemCount: 5,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            leading: Icon(Icons.check_circle),
            title: Text("Campign $index"),
            subtitle: Text("Reqirments:\n 10x Weapons 10 Food 10 Energy"),
            isThreeLine: true,
            trailing: RaisedButton(
              onPressed: () {},
              child: Text("Battle"),
            ),
          );
        },
        bottomNavigationBar: BottomAppBar(
          elevation: 0.0,
          child: Container(
            child: IconButton(
              icon: Icon(Icons.share),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
  }
}

_detailScreen(tablet, context, index) => DetailsScreen(
      // appBar: AppBar(
      //   elevation: 0.0,
      //   title: Text("Details"),
      //   actions: [
      //     IconButton(
      //       icon: Icon(Icons.share),
      //       onPressed: () {},
      //     ),
      //     IconButton(
      //       icon: Icon(Icons.delete),
      //       onPressed: () {
      //         if (!tablet) Navigator.of(context).pop();
      //       },
      //     ),
      //   ],
      // ),
      body: Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          title: Text("Details"),
          automaticallyImplyLeading: !tablet,
          actions: [
            IconButton(
              icon: Icon(Icons.share),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                if (!tablet) Navigator.of(context).pop();
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          elevation: 0.0,
          child: Container(
            child: IconButton(
              icon: Icon(Icons.close),
              onPressed: () {},
            ),
          ),
        ),
        body: Container(
          child: Center(
            child: Text("Item: $index"),
          ),
        ),
      ),
    );

//import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/ImageSelector.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class StoragePage extends StatefulWidget {
  @override
  StoragePageState createState() => StoragePageState();
}

class StoragePageState extends State<StoragePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Storage"),
      ),
      body: GridView.count(
        crossAxisCount: 3,
        children: List.generate(100, (index) {
          return Container(
            margin: EdgeInsets.all(10.0),
            padding: EdgeInsets.all(2.0),
            decoration:
                BoxDecoration(border: Border.all(color: Colors.blueAccent)),
            child: Column(
              children: <Widget>[
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Text(
                        'Food',
                      ),
                      Text(
                        'Q1',
                      )
                    ],
                  ),
                ),
                Container(
                  height: 70,
                  child: ImageSelector.getIcon('weapon'),
                ),
                Container(
                    child: Center(
                  child: Text("1,000"),
                ))
              ],
            ),
          );
        }),
      ),
    );
  }
}

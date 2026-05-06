import 'package:flutter/material.dart';

class InfoBox extends StatefulWidget {
  const InfoBox({super.key});

  @override
  State<InfoBox> createState() => _InfoBoxState();
}

class _InfoBoxState extends State<InfoBox> {
  @override
  Widget build(BuildContext context) {
    return Container(
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
                    size: 18,
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
        ]));
  }
}

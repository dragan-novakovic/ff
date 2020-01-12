//import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff/blocs/UserBloc.dart';
import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/models/Inventory.dart';
import 'package:ff/models/User.dart';
import 'package:ff/utils/ImageSelector.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class StoragePage extends StatefulWidget {
  StoragePage({@required this.inventoryId});
  final String inventoryId;
  @override
  StoragePageState createState() => StoragePageState();
}

class StoragePageState extends State<StoragePage> {
  LoginBloc bloc;

  @override
  void initState() {
    super.initState();
    print(widget.inventoryId);
    bloc = sl.get<LoginBloc>();
    bloc.getInventory(widget.inventoryId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Storage"),
      ),
      body: StreamBuilder<UserInventory>(
          stream: bloc.inventory,
          builder: (context, snapshot) {
            print(snapshot);
            return Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text("Capacity"),
                    Padding(
                      padding: EdgeInsets.all(15.0),
                      child: new LinearPercentIndicator(
                        width: 250,
                        animation: true,
                        lineHeight: 20.0,
                        animationDuration: 2500,
                        percent: 50 / snapshot.data?.capacity ?? 0,
                        center: Text("50/${snapshot.data?.capacity}"),
                        linearStrokeCap: LinearStrokeCap.roundAll,
                        progressColor: Colors.green,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    children: List.generate(100, (index) {
                      return Container(
                        margin: EdgeInsets.all(10.0),
                        padding: EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent)),
                        child: Column(
                          children: <Widget>[
                            Container(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                ),
              ],
            );
          }),
    );
  }
}

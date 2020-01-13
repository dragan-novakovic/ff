//import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff/blocs/UserBloc.dart';
import 'package:ff/blocs/rootBloc.dart';
import 'package:ff/models/Inventory.dart';
import 'package:ff/utils/ImageSelector.dart';
import 'package:ff/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                    children: [
                      itemSlot("food", snapshot.data?.foodQ1, "Q1"),
                      itemSlot("weapon", snapshot.data?.weaponQ1, "Q1"),
                    ],
                  ),
                ),
              ],
            );
          }),
    );
  }
}

Widget itemSlot(String item, int amount, String quality) => Container(
      margin: EdgeInsets.all(10.0),
      padding: EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: new BorderRadius.all(new Radius.circular(10.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.8),
            blurRadius: 30.0,
            spreadRadius: 2.0,
            offset: Offset(
              10.0,
              10.0,
            ),
          )
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(
                  toBeginningOfSentenceCase(item),
                ),
                Text(
                  quality,
                )
              ],
            ),
          ),
          Container(
            height: 70,
            child: ImageSelector.getIcon(item),
          ),
          Container(
              child: Center(
            child: Text(amount.toString()),
          ))
        ],
      ),
    );

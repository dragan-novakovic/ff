import 'package:ff/utils/ImageSelector.dart';
import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String text;
  final dynamic amount;
  final double height;
  final String img;
  final bool mini;

  ItemCard(
      {this.text = "Item",
      this.amount = "+50/h",
      this.height = 100,
      this.img = "gold-l",
      this.mini = false});

  @override
  Widget build(BuildContext context) {
    return mini
        ? (Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.all(Radius.elliptical(4, 4))),
            child: Column(
              children: <Widget>[
                // Padding(
                //   padding: const EdgeInsets.only(top: 2.0, bottom: 6),
                //   child: Text(
                //     text,
                //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                //   ),
                // ),
                Container(
                  margin: EdgeInsets.all(1),
                  height: height,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 1),
                      color: Colors.grey.shade300),
                  child: ImageSelector.getIcon(img),
                ),
                Text(
                  amount,
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ))
        : (Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.all(Radius.elliptical(8, 8))),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2.0, bottom: 6),
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w400),
                ),
                Container(
                  margin: EdgeInsets.all(8),
                  height: height,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 1),
                      color: Colors.grey.shade300),
                  child: ImageSelector.getIcon(img),
                ),
              ],
            ),
          ));
  }
}

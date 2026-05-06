import 'package:ff/components/NavTile.dart';
import 'package:flutter/material.dart';

class NavExpansionTile extends StatelessWidget {
  final dynamic props;
  const NavExpansionTile({super.key, this.props});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: ExpansionTile(
        title: Text(
          "Global",
          style: TextStyle(color: Colors.blue, fontSize: 12.0),
        ),
        children: <Widget>[
          navTile(context, props, title: "Info", subtitle: "Chat"),
          navTile(context, props, title: "Trade", subtitle: "Chat"),
        ],
      ),
    );
  }
}

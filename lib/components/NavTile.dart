import 'package:flutter/material.dart';

Widget navTile(context, widget,
        {required String title,
        required String subtitle,
        String? route,
        String? props,
        String? userId}) =>
    InkWell(
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
        if (route != null) {
          if (props != null) {
            if (userId != null) {
              Navigator.pushNamed(context, route,
                  arguments: {'id': props, 'userId': userId});
            }
            Navigator.pushNamed(context, route, arguments: {'id': props});
          } else {
            Navigator.pushNamed(context, route);
          }

          return;
        }
      },
    );

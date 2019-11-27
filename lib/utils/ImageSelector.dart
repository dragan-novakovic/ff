import 'package:flutter/material.dart';

class ImageSelector {
  static getImage(String name) {
    switch (name) {
      case "Basic 1":
        return img('assets/images/factories/food1.png');
      case "Medium 1":
        return img('assets/images/factories/hospital1.png');
      case "Big 1":
        return img('assets/images/factories/submarine1.png');
      default:
        return Image(
            image: AssetImage('assets/images/factories/aircraft1.png'));
    }
  }
}

Widget img(String url) => Image(image: AssetImage(url));

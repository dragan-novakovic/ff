import 'package:flutter/material.dart';

class ImageSelector {
  static getImage(String name, int level) {
    switch ('$name${level.toString()}') {
      case "Food Factory1":
        return img('assets/images/factories/food1.png');
      case "Weapon Factory1":
        return img('assets/images/factories/weapons1.png');
      case "Storage1":
        return img('assets/images/factories/normal-storage.png');
      default:
        return Image(
            image: AssetImage('assets/images/factories/aircraft1.png'));
    }
  }

  static getIcon(String name) {
    switch (name) {
      case "weapon":
        return img('assets/images/weapons.png');
      case "food":
        return img('assets/images/food(1).png');
      case "gold-s":
        return img('assets/images/gold-icon-s.png');
      case "gold-l":
        return img('assets/images/store_2.png');
      case "exp":
        return img('assets/images/xp-s.png');
      default:
        return img('assets/images/xp-s.png');
    }
  }
}

Widget img(String url) => Image(image: AssetImage(url));

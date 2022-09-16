import 'package:flutter/material.dart';

class SigninButton extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final Function onPressed;

  const SigninButton({
    Key? key,
    required this.child,
    this.width = double.infinity,
    this.height = 50.0,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 50.0,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          gradient: LinearGradient(
            colors: <Color>[
              Color.fromRGBO(10, 12, 240, 0.91),
              Color.fromRGBO(22, 82, 200, 0.8)
            ],
          )),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: () {},
            child: Center(
              child: child,
            )),
      ),
    );
  }
}

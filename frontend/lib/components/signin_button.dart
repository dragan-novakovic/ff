import 'package:flutter/material.dart';

class SigninButton extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final void Function()? onPressed;

  const SigninButton({
    Key? key,
    required this.child,
    this.width = double.infinity,
    this.height = 50.0,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromRGBO(22, 82, 200, 0.9),
          disabledBackgroundColor: Colors.grey.shade400,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.0),
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}

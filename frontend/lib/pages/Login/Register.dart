import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/signin_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Login.dart';

class MyCustomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = new Path();
    path.lineTo(0.0, size.height - 20);

    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.25, size.height - 30.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint =
        Offset(size.width - (size.width / 3.25), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, size.height - 40);
    path.lineTo(size.width, 0.0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper oldClipper) {
    return false;
  }
}

class Register extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Register> {
  @override
  Widget build(BuildContext context) {
    LoginBloc _loginBloc = Provider.of<LoginBloc>(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: <Widget>[
          ClipPath(
            clipper: MyCustomClipper(),
            child: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                colors: <Color>[
                  Color.fromRGBO(10, 12, 240, 0.91),
                  Color.fromRGBO(22, 82, 200, 0.8)
                ],
              )),
              padding: EdgeInsets.only(top: 80),
              width: MediaQuery.of(context).size.width,
              height: 200,
              child: Column(
                children: <Widget>[
                  Text(
                    "E - GAME ",
                    textScaler: TextScaler.linear(1.5),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 40, top: 20),
            child: Column(
              children: <Widget>[
                emailField(_loginBloc),
                usernameField(_loginBloc),
                passwordField(_loginBloc),
                submitButton(_loginBloc)
              ],
            ),
          )
        ],
      ),
    );
  }
}

Widget emailField(LoginBloc bloc) {
  return StreamBuilder(
    stream: bloc.email,
    builder: (context, snapshot) {
      return TextField(
        onChanged: bloc.changeEmail,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          hintText: 'ypu@example.com',
          labelText: 'Email Address',
          errorText: snapshot.hasError ? snapshot.error.toString() : null,
        ),
      );
    },
  );
}

Widget usernameField(LoginBloc bloc) {
  return StreamBuilder(
    stream: bloc.username,
    builder: (context, snapshot) {
      return TextField(
        onChanged: bloc.changeUsername,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          hintText: 'Username',
          labelText: 'Username',
          //errorText: snapshot.error,
        ),
      );
    },
  );
}

Widget passwordField(LoginBloc bloc) {
  return StreamBuilder(
      stream: bloc.password,
      builder: (context, snapshot) {
        return TextField(
          obscureText: true,
          onChanged: bloc.changePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) async => _handleRegisterSubmit(context, bloc),
          decoration: InputDecoration(
            hintText: 'Password',
            labelText: 'Password',
            errorText: snapshot.hasError ? snapshot.error.toString() : null,
          ),
        );
      });
}

Widget submitButton(LoginBloc bloc) {
  return StreamBuilder(
      stream: bloc.submitValidRegister,
      builder: (context, snapshot) {
        final canSubmit = snapshot.hasData && snapshot.data == true;
        return Column(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(top: 30),
              child: SigninButton(
                child: Text(
                  "Register",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      fontFamily: 'Roboto'),
                ),
                onPressed: canSubmit
                    ? () async => _handleRegisterSubmit(context, bloc)
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Text("Already have an Account ?"),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Login(),
                        ),
                      );
                    },
                    child: Text(
                      "Login here",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  )
                ],
              ),
            )
          ],
        );
      });
}

Future<void> _handleRegisterSubmit(BuildContext context, LoginBloc bloc) async {
  final message = await bloc.register();
  if (!context.mounted) {
    return;
  }

  if (message == null) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

import 'package:ff/blocs/UserBloc.dart';
import 'package:ff/models/User.dart';
import 'package:ff/pages/Dashboard.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  LoginBloc _loginBloc = new LoginBloc();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 100, 30, 100),
          child: Column(
            children: <Widget>[
              Text("Login"),
              Expanded(
                child: Column(
                  children: <Widget>[
                    emailField(_loginBloc),
                    passwordField(_loginBloc),
                    submitButton(_loginBloc)
                  ],
                ),
              )
            ],
          ),
        ),
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
          errorText: snapshot.error,
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
          decoration: InputDecoration(
            hintText: 'Password',
            labelText: 'Password',
            errorText: snapshot.error,
          ),
        );
      });
}

Widget submitButton(LoginBloc bloc) {
  return StreamBuilder(
    stream: bloc.submitValid,
    builder: (context, snapshot) {
      return RaisedButton(
        child: Text('Login'),
        color: Colors.blue,
        onPressed: snapshot.hasData
            ? () async {
                User user = await bloc.submit();
                //  print('Me: $user');

                if (user != null) {
                  // print("AM going");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Dashboard(
                        user: user,
                      ),
                    ),
                  );
                }
              }
            : null,
      );
    },
  );
}

import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/components/signin_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Register.dart';

const _demoLoginEmail = String.fromEnvironment(
  'FF_DEMO_LOGIN_EMAIL',
  defaultValue: 'demo@ff.local',
);
const _demoLoginPassword = String.fromEnvironment(
  'FF_DEMO_LOGIN_PASSWORD',
  defaultValue: 'secret',
);
const _showDemoLoginButton = bool.fromEnvironment(
  'FF_SHOW_DEMO_LOGIN',
  defaultValue: kDebugMode,
);

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

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
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
              height: 220,
              child: Column(
                children: <Widget>[
                  Text(
                    "E - GAME",
                    textScaler: TextScaler.linear(1.8),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 40, top: 100),
            child: Column(
              children: <Widget>[
                emailField(_loginBloc),
                passwordField(_loginBloc),
                authError(_loginBloc),
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

Widget passwordField(LoginBloc bloc) {
  return StreamBuilder(
      stream: bloc.password,
      builder: (context, snapshot) {
        return TextField(
          obscureText: true,
          onChanged: bloc.changePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) async => _handleLoginSubmit(context, bloc),
          decoration: InputDecoration(
            hintText: 'Password',
            labelText: 'Password',
            errorText: snapshot.hasError ? snapshot.error.toString() : null,
          ),
        );
      });
}

Widget authError(LoginBloc bloc) {
  return StreamBuilder<String?>(
    stream: bloc.authError,
    builder: (context, snapshot) {
      final message = snapshot.data;
      if (message == null || message.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    },
  );
}

Widget submitButton(LoginBloc bloc) {
  return StreamBuilder(
      stream: bloc.submitValid,
      builder: (context, snapshot) {
        final canSubmit = snapshot.hasData && snapshot.data == true;
        return Column(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(top: 30),
              child: SigninButton(
                onPressed: canSubmit
                    ? () async => _handleLoginSubmit(context, bloc)
                    : null,
                child: Text(
                  "Login",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      fontFamily: 'Roboto'),
                ),
              ),
            ),
            if (_showDemoLoginButton)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: () async => _handleDemoLoginSubmit(context, bloc),
                  icon: const Icon(Icons.login),
                  label: const Text('Login as demo'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Text("Don't have an Account ?"),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Register(),
                        ),
                      );
                    },
                    child: Text(
                      "Register here",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  )
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showPasswordResetDialog(context, bloc),
              child: const Text('Forgot password?'),
            ),
          ],
        );
      });
}

Future<void> _handleDemoLoginSubmit(
    BuildContext context, LoginBloc bloc) async {
  final message = await bloc.submitWithCredentials(
    email: _demoLoginEmail,
    password: _demoLoginPassword,
  );
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

Future<void> _handleLoginSubmit(BuildContext context, LoginBloc bloc) async {
  final message = await bloc.submit();
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

Future<void> _showPasswordResetDialog(
    BuildContext context, LoginBloc bloc) async {
  final emailController = TextEditingController();
  final tokenController = TextEditingController();
  final passwordController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Reset password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Account email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Reset token',
                  helperText: 'In dev, the token is returned and logged.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              final result = await bloc.requestPasswordReset(
                emailController.text.trim(),
              );
              if (!dialogContext.mounted) {
                return;
              }
              if (result.devToken != null) {
                tokenController.text = result.devToken!;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            },
            child: const Text('Request token'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await bloc.confirmPasswordReset(
                token: tokenController.text.trim(),
                password: passwordController.text,
              );
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      );
    },
  );

  emailController.dispose();
  tokenController.dispose();
  passwordController.dispose();
}

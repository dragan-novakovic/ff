import 'dart:async';
import 'package:ff/models/AuthSecurity.dart';
import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/User.dart';
import '../services/backend_api.dart';

class Validators {
  final validateEmail =
      StreamTransformer<String, String>.fromHandlers(handleData: (email, sink) {
    if (email.contains('@')) {
      sink.add(email);
    } else {
      sink.addError('Enter a valid email');
    }
  });

  final validatePassword = StreamTransformer<String, String>.fromHandlers(
      handleData: (password, sink) {
    if (password.length > 4) {
      sink.add(password);
    } else {
      sink.addError('Invalid password, please enter more than 4 characters');
    }
  });
}

class UserProfileNotFoundException implements Exception {}

class LoginBloc extends Validators with ChangeNotifier {
  LoginBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient() {
    _apiClient.onUnauthorized = _refreshCurrentSession;
    _restoreSession();
  }

  static const _tokenKey = 'ff.auth.token';
  static const _refreshTokenKey = 'ff.auth.refreshToken';
  static const _userIdKey = 'ff.auth.userId';

  final BackendApiClient _apiClient;
  final _authController = BehaviorSubject<User?>.seeded(null);
  final _userController = BehaviorSubject<User>();
  final _emailController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();
  final _usernameController = BehaviorSubject<String>();
  final _authErrorController = BehaviorSubject<String?>.seeded(null);
  final _isRestoringSessionController = BehaviorSubject<bool>.seeded(true);
  String? _currentToken;
  String? _currentRefreshToken;
  bool _isRefreshingSession = false;
  String? _pendingSuccessMessage;

  Stream<User?> get authStateChange => _authController.stream;
  Stream<User> get userData => _userController.stream;
  Stream<String> get email => _emailController.stream.transform(validateEmail);
  Stream<String> get password =>
      _passwordController.stream.transform(validatePassword);
  Stream<String> get username => _usernameController.stream;
  Stream<String?> get authError => _authErrorController.stream;
  Stream<bool> get isRestoringSession => _isRestoringSessionController.stream;
  Stream<bool> get submitValid =>
      Rx.combineLatest2(email, password, (e, p) => true);
  Stream<bool> get submitValidRegister =>
      Rx.combineLatest3(email, password, username, (e, p, u) => true);

  // change data
  Function(String) get changeEmail => _changeEmail;
  Function(String) get changePassword => _changePassword;
  Function(String) get changeUsername => _changeUsername;
  Function(User) get addUser => _userController.sink.add;

  void _changeEmail(String email) {
    _authErrorController.add(null);
    _emailController.add(email);
  }

  void _changePassword(String password) {
    _authErrorController.add(null);
    _passwordController.add(password);
  }

  void _changeUsername(String username) {
    _authErrorController.add(null);
    _usernameController.add(username);
  }

  Future<String?> getCurrentUserId() async {
    return _authController.valueOrNull?.uid;
  }

  Future<void> fetchChatUserProfile(String uid) async {
    await fetchUserProfile(uid);
  }

  Future<void> fetchUserProfile(String uid) async {
    try {
      final user = await _apiClient.fetchUserProfile(uid);
      _userController.add(user);
      _authController.add(user);
    } on BackendApiException catch (e) {
      _userController.addError(e.message);
      throw UserProfileNotFoundException();
    }
  }

  Future<String?> submit() async {
    if (!_emailController.hasValue || !_passwordController.hasValue) {
      const message = 'Enter your email and password.';
      _authErrorController.add(message);
      return message;
    }

    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;

    try {
      _authErrorController.add(null);
      final session = await _apiClient.login(
        email: validEmail,
        password: validPassword,
      );
      await _setSession(session);
      _pendingSuccessMessage = 'Login successful.';
      return null;
    } on BackendApiException catch (e) {
      final message = e.message;
      _authErrorController.add(message);
      return message;
    } on UserProfileNotFoundException {
      const message = 'Signed in, but no game profile was found.';
      _authErrorController.add(message);
      return message;
    } on Exception {
      const message = 'Could not reach backend services.';
      _authErrorController.add(message);
      return message;
    }
  }

  Future<String?> register() async {
    if (!_emailController.hasValue || !_passwordController.hasValue) {
      const message = 'Enter your email and password.';
      _authErrorController.add(message);
      return message;
    }

    final validEmail = _emailController.value;
    final validPassword = _passwordController.value;
    final validUsername =
        _usernameController.hasValue ? _usernameController.value : "";

    try {
      _authErrorController.add(null);
      final session = await _apiClient.register(
        email: validEmail,
        password: validPassword,
        username: validUsername,
      );
      await _setSession(session);
      _pendingSuccessMessage = 'Registration successful.';
      return null;
    } on BackendApiException catch (e) {
      final message = e.message;
      _authErrorController.add(message);
      return message;
    } on Exception {
      const message = 'Could not reach backend services.';
      _authErrorController.add(message);
      return message;
    }
  }

  Future<void> logout() async {
    final refreshToken = _currentRefreshToken;
    try {
      await _apiClient.logout(refreshToken: refreshToken);
    } on Exception {
      // Local logout must still succeed if the backend is unavailable.
    }
    _currentToken = null;
    _currentRefreshToken = null;
    _apiClient.bearerToken = null;
    _apiClient.refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    _authController.add(null);
  }

  String? get currentToken => _currentToken;

  String? get currentRefreshToken => _currentRefreshToken;

  User? get currentUser => _authController.valueOrNull;

  bool get isSignedIn => currentUser != null;

  String? takeSuccessMessage() {
    final message = _pendingSuccessMessage;
    _pendingSuccessMessage = null;
    return message;
  }

  void setAuthError(String message) {
    _authErrorController.add(message);
  }

  Future<AccountSecurityProfile> fetchAccountSecurity() async {
    return _apiClient.fetchAccountSecurity();
  }

  Future<AuthActionResult> requestEmailVerification() async {
    return _apiClient.requestEmailVerification();
  }

  Future<AuthActionResult> confirmEmailVerification(String token) async {
    final result = await _apiClient.confirmEmailVerification(token: token);
    final currentUser = _authController.valueOrNull;
    if (currentUser != null) {
      await fetchUserProfile(currentUser.uid);
    }
    return result;
  }

  Future<AuthActionResult> requestPasswordReset(String email) async {
    return _apiClient.requestPasswordReset(email: email);
  }

  Future<AuthActionResult> confirmPasswordReset({
    required String token,
    required String password,
  }) async {
    return _apiClient.confirmPasswordReset(token: token, password: password);
  }

  Future<SessionRevokeResult> revokeAllSessions() async {
    final result = await _apiClient.revokeAllSessions();
    await logout();
    return result;
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final userId = prefs.getString(_userIdKey);
      _currentRefreshToken = refreshToken;
      _apiClient.refreshToken = refreshToken;
      if ((token == null ||
              token.isEmpty ||
              userId == null ||
              userId.isEmpty) &&
          refreshToken != null &&
          refreshToken.isNotEmpty) {
        await _refreshCurrentSession();
        return;
      }

      if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
        return;
      }

      _currentToken = token;
      _apiClient.bearerToken = token;
      final user = await _apiClient.fetchUserProfile(userId);
      _userController.add(user);
      _authController.add(user);
    } on Exception {
      await _clearStoredSession();
      _currentToken = null;
      _currentRefreshToken = null;
      _apiClient.bearerToken = null;
      _apiClient.refreshToken = null;
      _authController.add(null);
    } finally {
      _isRestoringSessionController.add(false);
    }
  }

  Future<void> _setSession(AuthSession session) async {
    _currentToken = session.token;
    _currentRefreshToken = session.refreshToken.isNotEmpty
        ? session.refreshToken
        : _currentRefreshToken;
    _apiClient.bearerToken = session.token;
    _apiClient.refreshToken = _currentRefreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    if (_currentRefreshToken != null && _currentRefreshToken!.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, _currentRefreshToken!);
    }
    await prefs.setString(_userIdKey, session.user.uid);
    _userController.add(session.user);
    _authController.add(session.user);
  }

  Future<bool> _refreshCurrentSession() async {
    if (_isRefreshingSession) {
      return false;
    }

    final refreshToken = _currentRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    _isRefreshingSession = true;
    try {
      final session = await _apiClient.refresh(refreshToken: refreshToken);
      await _setSession(session);
      return true;
    } on Exception {
      await _clearStoredSession();
      _currentToken = null;
      _currentRefreshToken = null;
      _apiClient.bearerToken = null;
      _apiClient.refreshToken = null;
      _authController.add(null);
      return false;
    } finally {
      _isRefreshingSession = false;
    }
  }

  Future<void> _clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
  }

  @override
  void dispose() {
    _authController.close();
    _userController.close();
    _emailController.close();
    _passwordController.close();
    _usernameController.close();
    _authErrorController.close();
    _isRestoringSessionController.close();
    _apiClient.close();
    super.dispose();
  }
}

import 'dart:convert';

import 'package:ff/models/MessageModel.dart';
import 'package:ff/models/PlayerState.dart';
import 'package:ff/models/User.dart';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;

  BackendApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthSession {
  final String token;
  final User user;

  AuthSession({required this.token, required this.user});
}

class BackendApiClient {
  BackendApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = Uri.parse(
          baseUrl ??
              const String.fromEnvironment(
                'FF_API_BASE_URL',
                defaultValue: 'http://127.0.0.1:5124',
              ),
        );

  final http.Client _client;
  final Uri _baseUrl;
  String? bearerToken;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    return _authSessionFromJson(data);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final data = await _post('/auth/register', {
      'email': email,
      'password': password,
      'username': username,
    });

    return _authSessionFromJson(data);
  }

  Future<User> fetchUserProfile(String uid) async {
    final data = await _get('/players/$uid');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid player response from backend.');
    }

    return _userFromJson(data);
  }

  Future<PlayerState> fetchPlayerState(String playerId) async {
    final data = await _get('/players/$playerId/state');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid player state response from backend.');
    }

    return _playerStateFromJson(data);
  }

  Future<PlayerActionResult> work(String playerId) async {
    final data = await _post('/players/$playerId/work', {});
    return _playerActionFromJson(data);
  }

  Future<PlayerActionResult> train(String playerId) async {
    final data = await _post('/players/$playerId/train', {});
    return _playerActionFromJson(data);
  }

  Future<List<Message>> fetchMessages({String? fromId, String? toId}) async {
    final query = <String, String>{};
    if (fromId != null && fromId.isNotEmpty) {
      query['fromId'] = fromId;
    }
    if (toId != null && toId.isNotEmpty) {
      query['toId'] = toId;
    }

    final data = await _get('/messages', queryParameters: query);
    if (data is! List<dynamic>) {
      throw BackendApiException('Invalid messages response from backend.');
    }

    return data.map((message) {
      if (message is! Map<String, dynamic>) {
        throw BackendApiException('Invalid messages response from backend.');
      }

      return _messageFromJson(message);
    }).toList();
  }

  Future<Message> sendMessage({
    required String content,
    required String fromId,
    required String toId,
  }) async {
    final data = await _post('/messages', {
      'content': content,
      'fromId': fromId,
      'toId': toId,
    });

    return _messageFromJson(data);
  }

  void close() {
    _client.close();
  }

  AuthSession _authSessionFromJson(Map<String, dynamic> data) {
    final userData = data['user'];
    if (userData is! Map<String, dynamic>) {
      throw BackendApiException('Invalid auth response from backend.');
    }

    return AuthSession(
      token: data['token']?.toString() ?? '',
      user: _userFromJson(userData),
    );
  }

  User _userFromJson(Map<String, dynamic> data) {
    try {
      return User.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  Message _messageFromJson(Map<String, dynamic> data) {
    try {
      return Message.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerState _playerStateFromJson(Map<String, dynamic> data) {
    try {
      return PlayerState.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerActionResult _playerActionFromJson(Map<String, dynamic> data) {
    try {
      return PlayerActionResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _client.get(
      _uri(path, queryParameters),
      headers: _headers(),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode(body),
    );
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid response from backend.');
    }

    return data;
  }

  Map<String, String> _headers({String? contentType}) {
    final headers = <String, String>{};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    final token = bearerToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUrl.replace(
      pathSegments: [
        ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...normalizedPath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  dynamic _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    var message = 'Backend request failed.';
    if (body is Map<String, dynamic>) {
      message = body['message']?.toString() ??
          body['error']?.toString() ??
          body['title']?.toString() ??
          message;
    }

    throw BackendApiException(message, statusCode: response.statusCode);
  }
}

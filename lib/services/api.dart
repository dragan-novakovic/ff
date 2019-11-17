import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/User.dart';

class ApiProvider {
  final String _endpoint = 'http://localhost:8080/login';
  final Dio _dio = Dio();

  Future<User> login() async {
    try {
      Response response = await _dio.post(_endpoint,
          data: json.encode(
              {"email": "dragan.qwerty@gmail.com", "password": "123456"}));
      print(response);

      return response.data;
    } catch (e) {
      print(e);
      return e;
    }
  }
}

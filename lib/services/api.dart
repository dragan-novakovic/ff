import 'dart:convert';

import 'package:dio/dio.dart';

class ApiProvider<T> {
  final String _baseline = "http://localhost:8080";
  final Dio _dio = Dio();

  //Future<T> getOne() async {}

  //Future<T> getAll() async {}

  Future<T> post(
    String endpoint, {
    Map<String, dynamic> data,
  }) async {
    try {
      Response response = await _dio.post(_baseline + endpoint,
          data: json.encode(data),
          options: Options(headers: {"Content-Type": "application/json"}));

      print(response);
      return response.data;
    } catch (e) {
      print(e);
      return e;
    }
  }

  // Future<T> patch() async {}

  Future<void> delete() async {}
}

// import 'dart:convert';

// import 'package:dio/dio.dart';

// class ApiProvider<T> {
//   final String _baseline = "http://10.0.2.2:8080";
//   final Dio _dio = Dio();

//   //Future<T> getOne() async {}

//   Future<dynamic> getAll(String endpoint) async {
//     try {
//       Response response = await _dio.get(_baseline + endpoint);

//       return response.data;
//     } catch (e) {
//       print("Error" + e.toString());
//       return e.toString();
//     }
//   }

//   Future post(
//     String endpoint, {
//     Map<String, dynamic> data,
//   }) async {
//     try {
//       // print("API begin " + _baseline + endpoint);
//       Response response =
//           await _dio.post(_baseline + endpoint, data: json.encode(data));

//       // print('printing response');
//       // print('b' + response.data.toString());

//       return response.data;
//     } catch (e) {
//       print("Error" + e.toString());
//       return e;
//     }
//   }

//   // Future<T> patch() async {}

//   Future<void> delete() async {}
// }

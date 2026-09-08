import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: '',
          ).ifEmpty(() => _localApiBaseUrl);

  final String baseUrl;
  String? token;

  static String get _localApiBaseUrl =>
      'http://${Platform.isAndroid ? '10.0.2.2' : '127.0.0.1'}:3000/api';

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$baseUrl$path');
    final response = switch (method) {
      'GET' =>
        await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15)),
      'POST' =>
        await http
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
      'PATCH' =>
        await http
            .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
      'DELETE' =>
        await http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 15)),
      _ => throw ArgumentError('Unsupported HTTP method: $method'),
    };
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message'] as String? ?? 'Request failed',
        response.statusCode,
      );
    }
    return data;
  }
}

extension on String {
  String ifEmpty(String Function() fallback) => isEmpty ? fallback() : this;
}

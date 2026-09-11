import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

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

  static String get _localApiBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:3000/api';
    }
    return 'http://${Platform.isAndroid ? '10.0.2.2' : '127.0.0.1'}:3000/api';
  }

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
    Map<String, dynamic> data;
    if (response.body.trim().isEmpty) {
      data = <String, dynamic>{};
    } else {
      try {
        final decoded = jsonDecode(response.body);
        data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'message': decoded.toString()};
      } on FormatException {
        data = <String, dynamic>{
          'message': response.statusCode == 429
              ? 'Too many requests. Please wait and try again.'
              : 'The server returned an invalid response. Please try again.',
        };
      }
    }
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

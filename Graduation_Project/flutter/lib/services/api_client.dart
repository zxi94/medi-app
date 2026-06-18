import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
  }) async {
    return _execute(() => _client.get(
          _uri(path),
          headers: _headers(token),
        ));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    return _execute(() => _client.post(
          _uri(path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    return _execute(() => _client.put(
          _uri(path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    return _execute(() => _client.patch(
          _uri(path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    return _execute(() => _client.delete(
          _uri(path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  /// Wraps every HTTP call to catch network-level errors (no server, no route)
  /// and convert them into a typed [ApiException].
  Future<Map<String, dynamic>> _execute(
    Future<http.Response> Function() call,
  ) async {
    try {
      final response = await call();
      return _parse(response);
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to server (${ApiConfig.baseUrl}). '
        'Is the backend running? [${e.message}]',
      );
    } on HttpException catch (e) {
      throw ApiException('HTTP error: ${e.message}');
    }
  }

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _parse(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } on FormatException {
        throw ApiException(
          'Server returned an invalid response.',
          statusCode: response.statusCode,
        );
      }
    }

    final success = body['success'] == true;
    if (response.statusCode >= 200 && response.statusCode < 300 && success) {
      return body;
    }

    final error = body['error'];
    final message = body['message'] as String? ??
        (error is Map<String, dynamic> ? error['message'] as String? : null) ??
        'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://snaphere.duckdns.org',
);

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    String baseUrl = defaultApiBaseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _root = _normalizeRoot(baseUrl);

  final http.Client _client;
  final String _root;
  final Duration timeout;

  Future<Object?> get(
    String path, {
    Map<String, String> query = const {},
    String? accessToken,
  }) => request('GET', path, query: query, accessToken: accessToken);

  Future<Object?> post(String path, {Object? body, String? accessToken}) =>
      request('POST', path, body: body, accessToken: accessToken);

  Future<Object?> patch(String path, {Object? body, String? accessToken}) =>
      request('PATCH', path, body: body, accessToken: accessToken);

  Future<Object?> delete(String path, {String? accessToken}) =>
      request('DELETE', path, accessToken: accessToken);

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String> query = const {},
    Object? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$_root$path')
        .replace(queryParameters: query.isEmpty ? null : query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'accept': 'application/json',
        'accept-language': 'ko-KR',
        if (accessToken != null) 'authorization': 'Bearer $accessToken',
      });
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(timeout);
    if (response.bodyBytes.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      throw ApiException(
        '요청을 처리하지 못했습니다. (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        '서버 응답 형식이 올바르지 않습니다.',
        statusCode: response.statusCode,
      );
    }
    final envelope = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{'data': decoded};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawError = envelope['error'];
      final error = rawError is Map
          ? Map<String, Object?>.from(rawError)
          : const <String, Object?>{};
      throw ApiException(
        error['message'] as String? ??
            error['messageKey'] as String? ??
            '요청을 처리하지 못했습니다. (${response.statusCode})',
        statusCode: response.statusCode,
        code: error['code'] as String?,
      );
    }
    return envelope.containsKey('data') ? envelope['data'] : decoded;
  }

  static String _normalizeRoot(String value) {
    final base = value.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.endsWith('/api/v1')) return base;
    if (base.endsWith('/api')) return '$base/v1';
    return '$base/api/v1';
  }
}

Map<String, Object?> jsonMap(Object? value) =>
    Map<String, Object?>.from(value! as Map);

List<Map<String, Object?>> jsonMapList(Object? value) => (value as List? ?? [])
    .map((item) => Map<String, Object?>.from(item as Map))
    .toList(growable: false);

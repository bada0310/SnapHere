import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/domain/auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    http.Client? client,
    String baseUrl = defaultApiBaseUrl,
    FlutterSecureStorage? storage,
  }) : _api = ApiClient(client: client, baseUrl: baseUrl),
       _storage = storage ?? const FlutterSecureStorage();

  static const _deviceIdKey = 'snaphere.auth.device-id';
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession> exchangeGoogleCredential(
    GoogleIdentityCredential credential,
  ) async {
    var phase = 'device-id';
    try {
      final deviceId = await _deviceId();
      phase = 'http';
      final response = await _api.post(
        '/auth/google',
        body: {
          'idToken': credential.idToken,
          'deviceId': deviceId,
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
        },
      );
      phase = 'response-map';
      final data = jsonMap(response);
      phase = 'session-map';
      try {
        return _sessionFromAuthResult(data);
      } on Object {
        final tokens = data['tokens'];
        final user = data['user'];
        debugPrint(
          'SnapHereAuth responseShape '
          'tokens=${tokens is Map} '
          'access=${tokens is Map && tokens['accessToken'] is String} '
          'refresh=${tokens is Map && tokens['refreshToken'] is String} '
          'user=${user is Map} '
          'userId=${user is Map && user['userId'] is String} '
          'email=${user is Map && (user['email'] == null || user['email'] is String)} '
          'nickname=${user is Map && (user['nickname'] == null || user['nickname'] is String)} '
          'photo=${user is Map && (user['profileImageUrl'] == null || user['profileImageUrl'] is String)} '
          'onboarding=${data['onboardingRequired'] is bool}',
        );
        rethrow;
      }
    } on ApiException catch (error) {
      if (kDebugMode) {
        final code = error.code;
        final safeCode =
            code != null && RegExp(r'^[A-Z][A-Z0-9_]{0,63}$').hasMatch(code)
            ? code
            : 'UNKNOWN';
        debugPrint(
          'Google token exchange failed: HTTP ${error.statusCode}, $safeCode',
        );
      }
      throw switch (error.code) {
        'AUTH_AUDIENCE_MISMATCH' => const AuthFailure(
          '앱과 서버의 Google 로그인 설정이 일치하지 않아요. 서버 설정 반영 후 다시 시도해 주세요.',
        ),
        'AUTH_INVALID_GOOGLE_TOKEN' => const AuthFailure(
          'Google 인증을 확인하지 못했어요. 다시 로그인해 주세요.',
        ),
        'USER_RECOVERY_EXPIRED' => const AuthFailure(
          '계정 복구 기간이 지났어요. 관리자에게 문의해 주세요.',
        ),
        _ => AuthFailure(
          error.statusCode != null && error.statusCode! >= 500
              ? '로그인 서버에 오류가 발생했어요. 잠시 후 다시 시도해 주세요.'
              : '서버에서 로그인을 처리하지 못했어요. 다시 시도해 주세요.',
        ),
      };
    } on TimeoutException {
      throw const AuthFailure('로그인 서버의 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.');
    } on SocketException {
      throw const AuthFailure('로그인 서버에 연결할 수 없어요. 네트워크와 서버 연결을 확인해 주세요.');
    } on http.ClientException {
      throw const AuthFailure('로그인 서버에 연결할 수 없어요. 네트워크와 서버 연결을 확인해 주세요.');
    } on Object catch (error) {
      debugPrint('SnapHereAuth exchangePhase=$phase type=${error.runtimeType}');
      rethrow;
    }
  }

  @override
  Future<AuthSession> completeProfile({
    required String accessToken,
    required String refreshToken,
    required ProfileSubmission submission,
  }) async {
    var data = jsonMap(
      await _api.post(
        '/auth/onboarding',
        accessToken: accessToken,
        body: {
          'nickname': submission.nickname,
          'termsVersion': submission.consents.termsVersion,
          'locale': 'ko-KR',
        },
      ),
    );
    if (submission.bio != null) {
      final updated = jsonMap(
        await _api.patch(
          '/me',
          accessToken: accessToken,
          body: {'bio': submission.bio},
        ),
      );
      final profile = jsonMap(updated['profile']);
      final user = jsonMap(profile['user']);
      data = {...user, 'email': updated['email'] ?? data['email']};
    }
    return AuthSession.authenticated(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: _user(data, needsProfileSetup: false),
    );
  }

  @override
  Future<AuthSession> refreshSession(String refreshToken) async {
    final tokens = jsonMap(
      await _api.post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken, 'deviceId': await _deviceId()},
      ),
    );
    final accessToken = tokens['accessToken']! as String;
    final me = jsonMap(await _api.get('/me', accessToken: accessToken));
    final profile = jsonMap(me['profile']);
    final user = jsonMap(profile['user']);
    return AuthSession.authenticated(
      accessToken: accessToken,
      refreshToken: tokens['refreshToken']! as String,
      user: AuthUser(
        id: user['userId']! as String,
        email: me['email'] as String? ?? '',
        nickname: user['nickname'] as String?,
        photoUrl: user['profileImageUrl'] as String?,
        bio: user['bio'] as String?,
        needsProfileSetup: false,
      ),
    );
  }

  @override
  Future<void> signOut(String accessToken) =>
      _api.post('/auth/logout', accessToken: accessToken);

  @override
  Future<void> deleteAccount(
    String accessToken, {
    required String contentAction,
  }) => _api.post(
    '/me/deletion',
    accessToken: accessToken,
    body: {'contentAction': contentAction},
  );

  AuthSession _sessionFromAuthResult(Map<String, Object?> data) {
    final tokens = jsonMap(data['tokens']);
    return AuthSession.authenticated(
      accessToken: tokens['accessToken']! as String,
      refreshToken: tokens['refreshToken']! as String,
      user: _user(
        jsonMap(data['user']),
        needsProfileSetup: data['onboardingRequired'] as bool? ?? false,
      ),
    );
  }

  AuthUser _user(
    Map<String, Object?> json, {
    required bool needsProfileSetup,
  }) => AuthUser(
    id: json['userId']! as String,
    email: json['email'] as String? ?? '',
    nickname: json['nickname'] as String?,
    photoUrl: json['profileImageUrl'] as String?,
    needsProfileSetup: needsProfileSetup,
  );

  Future<String> _deviceId() async {
    final saved = await _storage.read(key: _deviceIdKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final generated = 'flutter-${base64Url.encode(bytes).replaceAll('=', '')}';
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }
}

class ApiLegalDocumentRepository implements LegalDocumentRepository {
  ApiLegalDocumentRepository({
    http.Client? client,
    String baseUrl = defaultApiBaseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<LegalDocument> fetch(LegalDocumentType type) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/legal/${type.path}'),
      headers: const {'accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthFailure('약관 문서를 불러오지 못했습니다. (${response.statusCode})');
    }
    final json = Map<String, Object?>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    return LegalDocument(
      type: type,
      title: json['title']! as String,
      version: json['version']! as String,
      effectiveDate: DateTime.parse(json['effectiveDate']! as String),
      sections: (json['sections']! as List)
          .map((value) => Map<String, Object?>.from(value as Map))
          .map(
            (section) => LegalSection(
              heading: section['heading']! as String,
              body: section['body']! as String,
            ),
          )
          .toList(growable: false),
    );
  }
}

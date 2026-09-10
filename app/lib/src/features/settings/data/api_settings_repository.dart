import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/settings/domain/app_locale.dart';
import 'package:snap_here/src/features/settings/domain/settings_repository.dart';

class ApiSettingsRepository implements SettingsRepository {
  ApiSettingsRepository({required this.accessToken, ApiClient? client})
    : _client = client ?? ApiClient();

  final String? accessToken;
  final ApiClient _client;

  @override
  Future<UserSettings> fetchSettings() async {
    // `/me`는 프로필·언어·알림 설정을 한 번에 준다 (UserDtos.MyProfile).
    final data = jsonMap(
      await _guard(() => _client.get('/me', accessToken: _requireToken())),
    );
    final preferences = data['notificationPreferences'];
    return UserSettings(
      locale: AppLocale.fromCode(data['locale'] as String?),
      notifications: preferences == null
          ? const NotificationPreferences()
          : NotificationPreferences.fromJson(jsonMap(preferences)),
    );
  }

  @override
  Future<AppLocale> updateLocale(AppLocale locale) async {
    // 누락은 변경 없음, null은 필드 제거다. 언어만 보낸다.
    final data = jsonMap(
      await _guard(
        () => _client.patch(
          '/me',
          body: {'locale': locale.code},
          accessToken: _requireToken(),
        ),
      ),
    );
    return AppLocale.fromCode(data['locale'] as String? ?? locale.code);
  }

  @override
  Future<NotificationPreferences> updateNotifications(
    NotificationPreferences preferences,
  ) async {
    final data = jsonMap(
      await _guard(
        () => _client.patch(
          '/me/notification-preferences',
          body: preferences.toJson(),
          accessToken: _requireToken(),
        ),
      ),
    );
    return NotificationPreferences.fromJson(data);
  }

  String _requireToken() {
    final token = accessToken;
    if (token == null) throw const SettingsFailure('로그인이 필요한 기능이에요.');
    return token;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw SettingsFailure(error.message);
    } on SettingsFailure {
      rethrow;
    } on Object {
      throw const SettingsFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

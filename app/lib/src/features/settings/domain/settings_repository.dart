import 'package:snap_here/src/features/settings/domain/app_locale.dart';

abstract interface class SettingsRepository {
  Future<UserSettings> fetchSettings();

  /// 표시 언어를 저장한다 (API-USER-002, `users.locale`).
  Future<AppLocale> updateLocale(AppLocale locale);

  /// 알림 수신 설정을 저장한다 (`PATCH /me/notification-preferences`).
  Future<NotificationPreferences> updateNotifications(
    NotificationPreferences preferences,
  );
}

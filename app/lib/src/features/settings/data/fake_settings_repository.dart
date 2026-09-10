import 'package:snap_here/src/features/settings/domain/app_locale.dart';
import 'package:snap_here/src/features/settings/domain/settings_repository.dart';

class FakeSettingsRepository implements SettingsRepository {
  var _settings = const UserSettings(
    locale: AppLocale.ko,
    notifications: NotificationPreferences(),
  );

  @override
  Future<UserSettings> fetchSettings() async => _settings;

  @override
  Future<AppLocale> updateLocale(AppLocale locale) async {
    _settings = _settings.copyWith(locale: locale);
    return locale;
  }

  @override
  Future<NotificationPreferences> updateNotifications(
    NotificationPreferences preferences,
  ) async {
    _settings = _settings.copyWith(notifications: preferences);
    return preferences;
  }
}

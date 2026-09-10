import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snap_here/src/features/activity/application/activity_providers.dart';
import 'package:snap_here/src/features/activity/domain/activity_models.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/settings/data/api_settings_repository.dart';
import 'package:snap_here/src/features/settings/data/fake_settings_repository.dart';
import 'package:snap_here/src/features/settings/domain/app_locale.dart';
import 'package:snap_here/src/features/settings/domain/settings_repository.dart';

/// `pubspec.yaml`의 `version`과 맞춘다. `package_info_plus`를 새로 넣지 않으려고
/// 상수로 두었으니 버전을 올릴 때 함께 고친다.
const appVersionName = '0.1.0';

const _translateAllKey = 'settings.translate_all';
const _deviceIdKey = 'settings.device_id';

const _useFakeSettings = bool.fromEnvironment(
  'USE_FAKE_SETTINGS',
  defaultValue: false,
);

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  if (_useFakeSettings) return FakeSettingsRepository();
  return ApiSettingsRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  );
});

/// 표시 언어와 알림 수신 설정. 둘 다 `/me`에서 함께 온다.
class UserSettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() =>
      ref.watch(settingsRepositoryProvider).fetchSettings();

  /// 스위치·선택은 누르자마자 반영하고 실패하면 되돌린다.
  Future<String?> selectLocale(AppLocale locale) => _apply(
    optimistic: (current) => current.copyWith(locale: locale),
    send: (repository) async => repository.updateLocale(locale),
    merge: (current, saved) => current.copyWith(locale: saved),
  );

  Future<String?> setPushEnabled(bool enabled) async {
    final error = await _apply(
      optimistic: (current) =>
          current.copyWith(notifications: NotificationPreferences.all(enabled)),
      send: (repository) async =>
          repository.updateNotifications(NotificationPreferences.all(enabled)),
      merge: (current, saved) => current.copyWith(notifications: saved),
    );
    // 알림을 켰으면 이 기기를 등록해 둔다 (API-USER-003). FCM 토큰은 아직 없어
    // 기기 식별자만 올린다 — 토큰이 붙으면 같은 엔드포인트에 함께 보내면 된다.
    if (error == null && enabled) await _registerDevice();
    return error;
  }

  Future<void> _registerDevice() async {
    try {
      await ref
          .read(activityRepositoryProvider)
          .registerDevice(
            deviceId: await _deviceId(),
            platform: Platform.isIOS ? 'IOS' : 'ANDROID',
            appVersion: appVersionName,
          );
    } on ActivityFailure {
      // 등록 실패가 설정 화면을 막을 이유는 없다. 다음에 켤 때 다시 시도한다.
    }
  }

  /// 기기 식별자. 플러그인을 새로 넣지 않고 최초 1회 만들어 보관한다.
  Future<String> _deviceId() async {
    const storage = FlutterSecureStorage();
    final stored = await storage.read(key: _deviceIdKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final created = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await storage.write(key: _deviceIdKey, value: created);
    return created;
  }

  Future<String?> _apply<T>({
    required UserSettings Function(UserSettings current) optimistic,
    required Future<T> Function(SettingsRepository repository) send,
    required UserSettings Function(UserSettings current, T saved) merge,
  }) async {
    final current = state.value;
    if (current == null) return null;

    state = AsyncData(optimistic(current));
    try {
      final saved = await send(ref.read(settingsRepositoryProvider));
      state = AsyncData(merge(state.value ?? current, saved));
      return null;
    } on SettingsFailure catch (error) {
      state = AsyncData(current);
      return error.message;
    }
  }
}

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsController, UserSettings>(
      UserSettingsController.new,
    );

/// 전체 번역 표시 여부.
///
/// 서버에 해당 필드가 없다 — `users.locale`은 표시 언어일 뿐이고, 원문을 볼지
/// 번역문을 볼지는 보는 사람의 취향이라 기기에 남긴다. 실제 번역문은 게시글
/// 응답의 `translations`에서 오는데 지금은 서버가 null을 보낸다 (SYS-010).
class TranslateAllController extends AsyncNotifier<bool> {
  static const _storage = FlutterSecureStorage();

  @override
  Future<bool> build() async =>
      await _storage.read(key: _translateAllKey) == 'true';

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    await _storage.write(key: _translateAllKey, value: '$enabled');
  }
}

final translateAllProvider =
    AsyncNotifierProvider<TranslateAllController, bool>(
      TranslateAllController.new,
    );

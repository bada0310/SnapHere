import 'package:flutter/foundation.dart';

/// 명세 `2. 공통 규약`의 지원 언어다 — `ko-KR | en-US | zh-CN | ja-JP`.
///
/// `Accept-Language` 헤더와 `users.locale`이 같은 목록을 쓰고, 지원하지 않는 값이
/// 오면 `ko-KR`로 되돌린다 (SYS-010, SYS-012).
enum AppLocale {
  ko('ko-KR', '한국어'),
  en('en-US', 'English'),
  zh('zh-CN', '简体中文'),
  ja('ja-JP', '日本語');

  const AppLocale(this.code, this.label);

  /// 서버에 보내는 값.
  final String code;

  /// 설정 화면에 보이는 이름. 각 언어를 그 언어로 적는다.
  final String label;

  /// `ko`, `ko-KR`, `ko_KR` 어느 형태로 와도 받는다. 모르면 한국어로 떨어뜨린다.
  static AppLocale fromCode(String? value) {
    if (value == null || value.isEmpty) return ko;
    final normalized = value.replaceAll('_', '-').toLowerCase();
    for (final locale in values) {
      if (locale.code.toLowerCase() == normalized) return locale;
    }
    final language = normalized.split('-').first;
    for (final locale in values) {
      if (locale.code.toLowerCase().startsWith('$language-')) return locale;
    }
    return ko;
  }
}

/// 알림 수신 설정. 서버는 종류별로 나눠 두었고(`postLike`·`follow`·`badgeEarned`)
/// Figma `07_설정`은 `푸시 알림` 한 줄만 그린다. 화면의 스위치는 셋을 함께 켜고 끈다.
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.postLike = true,
    this.follow = true,
    this.badgeEarned = true,
  });

  factory NotificationPreferences.fromJson(Map<String, Object?> json) =>
      NotificationPreferences(
        postLike: json['postLike'] as bool? ?? true,
        follow: json['follow'] as bool? ?? true,
        badgeEarned: json['badgeEarned'] as bool? ?? true,
      );

  factory NotificationPreferences.all(bool enabled) => NotificationPreferences(
    postLike: enabled,
    follow: enabled,
    badgeEarned: enabled,
  );

  final bool postLike;
  final bool follow;
  final bool badgeEarned;

  /// 하나라도 켜져 있으면 켠 것으로 본다. 끄면 셋 다 끈다.
  bool get anyEnabled => postLike || follow || badgeEarned;

  Map<String, Object?> toJson() => {
    'postLike': postLike,
    'follow': follow,
    'badgeEarned': badgeEarned,
  };
}

@immutable
class UserSettings {
  const UserSettings({required this.locale, required this.notifications});

  final AppLocale locale;
  final NotificationPreferences notifications;

  UserSettings copyWith({
    AppLocale? locale,
    NotificationPreferences? notifications,
  }) => UserSettings(
    locale: locale ?? this.locale,
    notifications: notifications ?? this.notifications,
  );
}

class SettingsFailure implements Exception {
  const SettingsFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

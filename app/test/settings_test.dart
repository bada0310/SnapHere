import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/features/settings/domain/app_locale.dart';

void main() {
  group('AppLocale', () {
    test('명세가 정한 네 가지만 있다', () {
      expect(AppLocale.values.map((locale) => locale.code), [
        'ko-KR',
        'en-US',
        'zh-CN',
        'ja-JP',
      ]);
    });

    test('각 언어 이름은 그 언어로 적는다', () {
      expect(AppLocale.ko.label, '한국어');
      expect(AppLocale.en.label, 'English');
      expect(AppLocale.zh.label, '简体中文');
      expect(AppLocale.ja.label, '日本語');
    });

    test('정확한 코드를 알아본다', () {
      expect(AppLocale.fromCode('en-US'), AppLocale.en);
      expect(AppLocale.fromCode('ja-JP'), AppLocale.ja);
    });

    test('대소문자와 밑줄 표기를 받아준다', () {
      expect(AppLocale.fromCode('EN-us'), AppLocale.en);
      expect(AppLocale.fromCode('zh_CN'), AppLocale.zh);
    });

    // `users.locale` 기본값이 'ko'라 지역 없는 코드가 올 수 있다.
    test('지역 없는 언어 코드도 받아준다', () {
      expect(AppLocale.fromCode('ko'), AppLocale.ko);
      expect(AppLocale.fromCode('en'), AppLocale.en);
    });

    test('지원하지 않으면 한국어로 폴백한다', () {
      expect(AppLocale.fromCode('fr-FR'), AppLocale.ko);
      expect(AppLocale.fromCode(''), AppLocale.ko);
      expect(AppLocale.fromCode(null), AppLocale.ko);
    });
  });

  group('NotificationPreferences', () {
    test('하나라도 켜져 있으면 켠 것으로 본다', () {
      expect(
        const NotificationPreferences(
          postLike: false,
          follow: true,
          badgeEarned: false,
        ).anyEnabled,
        isTrue,
      );
    });

    test('셋 다 꺼져야 끈 것이다', () {
      expect(NotificationPreferences.all(false).anyEnabled, isFalse);
    });

    test('한 줄 스위치는 셋을 함께 바꾼다', () {
      final on = NotificationPreferences.all(true);
      expect([on.postLike, on.follow, on.badgeEarned], [true, true, true]);
    });

    test('응답에 없는 항목은 켜진 것으로 둔다', () {
      final preferences = NotificationPreferences.fromJson(const {
        'postLike': false,
      });
      expect(preferences.postLike, isFalse);
      expect(preferences.follow, isTrue);
      expect(preferences.badgeEarned, isTrue);
    });

    test('toJson은 서버 필드명을 그대로 쓴다', () {
      expect(NotificationPreferences.all(false).toJson(), {
        'postLike': false,
        'follow': false,
        'badgeEarned': false,
      });
    });
  });
}

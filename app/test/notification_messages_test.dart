import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/features/notification/domain/notification_messages.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';

AppNotification build({
  required String key,
  Map<String, Object?> params = const {},
  NotificationType type = NotificationType.system,
  NotificationTarget target = NotificationTarget.none,
  String? targetId,
}) => AppNotification(
  notificationId: 'ntf_1',
  type: type,
  target: target,
  targetId: targetId,
  messageKey: key,
  messageParams: params,
  isRead: false,
);

void main() {
  group('알림 문구 조립', () {
    test('좋아요', () {
      expect(
        buildNotificationMessage(
          build(
            key: 'notification.post.like',
            params: const {'actorNickname': '서울여행러'},
          ),
        ),
        '서울여행러님이 회원님의 게시글을 좋아합니다',
      );
    });

    test('댓글은 발췌가 있으면 인용까지 붙인다', () {
      expect(
        buildNotificationMessage(
          build(
            key: 'notification.post.comment',
            params: const {
              'actorNickname': 'Emily',
              'excerpt': 'Where is this?',
            },
          ),
        ),
        'Emily님이 댓글을 남겼어요: "Where is this?"',
      );
    });

    test('댓글 발췌가 없으면 인용을 생략한다', () {
      expect(
        buildNotificationMessage(
          build(
            key: 'notification.post.comment',
            params: const {'actorNickname': 'Emily'},
          ),
        ),
        'Emily님이 댓글을 남겼어요',
      );
    });

    test('뱃지', () {
      expect(
        buildNotificationMessage(
          build(
            key: 'notification.badge.earned',
            params: const {'badgeName': '2026 전주 한옥마을 봄축제'},
          ),
        ),
        '2026 전주 한옥마을 봄축제 뱃지를 획득했어요!',
      );
    });

    // 백엔드가 새 알림 종류를 추가해도 목록에 빈 줄이 생기면 안 된다.
    test('모르는 키는 서버가 보낸 text로 떨어진다', () {
      expect(
        buildNotificationMessage(
          build(key: 'notification.unknown', params: const {'text': '새 소식'}),
        ),
        '새 소식',
      );
    });

    test('모르는 키에 text도 없으면 기본 문구를 쓴다', () {
      expect(
        buildNotificationMessage(build(key: 'notification.unknown')),
        '새 알림이 있어요',
      );
    });

    test('닉네임이 없어도 문장이 깨지지 않는다', () {
      expect(
        buildNotificationMessage(build(key: 'notification.follow')),
        '누군가님이 팔로우했어요',
      );
    });
  });

  group('알림 이동 대상', () {
    test('게시글 알림은 사진 상세로 간다', () {
      expect(
        build(
          key: 'k',
          target: NotificationTarget.post,
          targetId: 'pst_1',
        ).destination,
        '/photos/pst_1',
      );
    });

    test('뱃지 알림은 수집함으로 간다', () {
      expect(
        build(key: 'k', target: NotificationTarget.badge).destination,
        '/profile/badges',
      );
    });

    test('대상이 없는 공지는 이동하지 않는다', () {
      expect(build(key: 'k').destination, isNull);
    });

    test('대상 ID가 비면 이동하지 않는다', () {
      expect(
        build(key: 'k', target: NotificationTarget.post).destination,
        isNull,
      );
    });
  });

  group('알림 타입 파싱', () {
    test('ERD에 아직 없는 COMMENT · NEW_POST도 받는다', () {
      expect(NotificationType.fromJson('COMMENT'), NotificationType.comment);
      expect(NotificationType.fromJson('NEW_POST'), NotificationType.newPost);
    });

    test('모르는 값은 system으로 떨어뜨린다', () {
      expect(NotificationType.fromJson('WHATEVER'), NotificationType.system);
      expect(NotificationType.fromJson(null), NotificationType.system);
    });
  });
}

import 'package:snap_here/src/features/notification/domain/notification_models.dart';

/// 알림 문구 조립 (NTF-009, SYS-010).
///
/// 서버가 `messageKey`와 `messageParams`만 주므로 한국어 문장은 여기서 만든다.
/// 키를 모르면 서버가 함께 보낸 `text` 파라미터로 떨어뜨려, 백엔드가 새 알림을
/// 추가해도 목록에 빈 줄이 생기지 않게 한다.
String buildNotificationMessage(AppNotification notification) {
  final params = notification.messageParams;
  final actor = params['actorNickname']?.toString() ?? '누군가';
  final excerpt = params['excerpt']?.toString();
  final badge = params['badgeName']?.toString() ?? '뱃지';

  return switch (notification.messageKey) {
    'notification.post.like' => '$actor님이 회원님의 게시글을 좋아합니다',
    'notification.post.comment' =>
      excerpt == null ? '$actor님이 댓글을 남겼어요' : '$actor님이 댓글을 남겼어요: "$excerpt"',
    'notification.follow' => '$actor님이 팔로우했어요',
    'notification.post.new' => '팔로잉하는 $actor님이 새 게시글을 올렸어요',
    'notification.badge.earned' => '$badge 뱃지를 획득했어요!',
    'notification.system' => params['text']?.toString() ?? '새 소식이 있어요',
    _ => params['text']?.toString() ?? '새 알림이 있어요',
  };
}

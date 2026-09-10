import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';
import 'package:snap_here/src/features/notification/domain/notification_repository.dart';

/// Figma `07_알림_목록`의 여섯 줄을 그대로 만든다.
///
/// 백엔드 `NotificationController`가 없는 동안 화면·동선을 검증하기 위한 대역이다.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository() {
    final now = DateTime.now();
    _items.addAll([
      _make(
        id: 'ntf_1',
        type: NotificationType.postLike,
        target: NotificationTarget.post,
        targetId: 'pst_1',
        key: 'notification.post.like',
        params: const {'actorNickname': '서울여행러'},
        at: now.subtract(const Duration(hours: 2)),
      ),
      _make(
        id: 'ntf_2',
        type: NotificationType.comment,
        target: NotificationTarget.post,
        targetId: 'pst_1',
        key: 'notification.post.comment',
        params: const {'actorNickname': 'Emily', 'excerpt': 'Where is this?'},
        at: now.subtract(const Duration(hours: 5)),
      ),
      _make(
        id: 'ntf_3',
        type: NotificationType.follow,
        target: NotificationTarget.user,
        targetId: 'usr_9',
        key: 'notification.follow',
        params: const {'actorNickname': '제주사진가'},
        at: now.subtract(const Duration(days: 1)),
        read: true,
      ),
      _make(
        id: 'ntf_4',
        type: NotificationType.newPost,
        target: NotificationTarget.post,
        targetId: 'pst_2',
        key: 'notification.post.new',
        params: const {'actorNickname': '서울여행러'},
        at: now.subtract(const Duration(days: 2)),
        read: true,
      ),
      _make(
        id: 'ntf_5',
        type: NotificationType.badgeEarned,
        target: NotificationTarget.badge,
        key: 'notification.badge.earned',
        params: const {'badgeName': '2026 전주 한옥마을 봄축제'},
        at: now.subtract(const Duration(days: 3)),
        read: true,
      ),
      _make(
        id: 'ntf_6',
        type: NotificationType.system,
        target: NotificationTarget.none,
        key: 'notification.system',
        params: const {'text': '이번 주 부산 불꽃축제가 시작돼요!'},
        at: now.subtract(const Duration(days: 5)),
        read: true,
      ),
    ]);
  }

  final _items = <AppNotification>[];

  @override
  Future<CursorPage<AppNotification>> fetchNotifications({
    String? cursor,
  }) async => CursorPage(items: List.unmodifiable(_items));

  @override
  Future<int> fetchUnreadCount() async =>
      _items.where((item) => !item.isRead).length;

  @override
  Future<void> markRead(String notificationId) async {
    final index = _items.indexWhere(
      (item) => item.notificationId == notificationId,
    );
    if (index >= 0) _items[index] = _items[index].copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead() async {
    for (var index = 0; index < _items.length; index++) {
      _items[index] = _items[index].copyWith(isRead: true);
    }
  }

  AppNotification _make({
    required String id,
    required NotificationType type,
    required NotificationTarget target,
    required String key,
    required Map<String, Object?> params,
    required DateTime at,
    String? targetId,
    bool read = false,
  }) => AppNotification(
    notificationId: id,
    type: type,
    target: target,
    targetId: targetId,
    messageKey: key,
    messageParams: params,
    isRead: read,
    createdAt: at,
  );
}

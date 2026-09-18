import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';
import 'package:snap_here/src/features/notification/domain/notification_repository.dart';

/// 서버 알림 기능을 사용하지 않을 때 샘플 데이터 없이 빈 알림함을 제공한다.
class EmptyNotificationRepository implements NotificationRepository {
  const EmptyNotificationRepository();

  @override
  Future<CursorPage<AppNotification>> fetchNotifications({
    String? cursor,
  }) async => const CursorPage(items: []);

  @override
  Future<int> fetchUnreadCount() async => 0;

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<void> markAllRead() async {}
}

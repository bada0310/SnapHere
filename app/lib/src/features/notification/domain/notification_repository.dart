import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';

abstract interface class NotificationRepository {
  Future<CursorPage<AppNotification>> fetchNotifications({String? cursor});

  Future<int> fetchUnreadCount();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();
}

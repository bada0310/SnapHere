import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/notification/data/api_notification_repository.dart';
import 'package:snap_here/src/features/notification/data/empty_notification_repository.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';
import 'package:snap_here/src/features/notification/domain/notification_repository.dart';

/// 알림 API가 제공되기 전까지 알림함은 빈 상태로 유지한다.
const _enableNotificationsApi = bool.fromEnvironment(
  'ENABLE_NOTIFICATIONS_API',
  defaultValue: false,
);

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (!_enableNotificationsApi) return const EmptyNotificationRepository();
  return ApiNotificationRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  );
});

final notificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final page = await ref
      .watch(notificationRepositoryProvider)
      .fetchNotifications();
  return page.items;
});

/// 탭 배지용 안읽은 수 (NTF-012).
final unreadNotificationCountProvider = FutureProvider<int>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchUnreadCount(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/notification/data/api_notification_repository.dart';
import 'package:snap_here/src/features/notification/data/fake_notification_repository.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';
import 'package:snap_here/src/features/notification/domain/notification_repository.dart';

/// 다른 기능과 달리 기본값이 true다. 백엔드에 `NotificationController`가 아직 없어
/// API를 부르면 화면이 항상 오류로 끝난다. 컨트롤러가 올라오면 false로 바꾼다.
const _useFakeNotifications = bool.fromEnvironment(
  'USE_FAKE_NOTIFICATIONS',
  defaultValue: true,
);

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (_useFakeNotifications) return FakeNotificationRepository();
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

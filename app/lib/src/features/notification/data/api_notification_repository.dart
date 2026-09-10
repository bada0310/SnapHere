import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';
import 'package:snap_here/src/features/notification/domain/notification_repository.dart';

/// 명세 API-NTF-001~004에 맞춰 미리 붙여 둔다.
///
/// 백엔드에 `NotificationController`가 아직 없어 지금은 `USE_FAKE_NOTIFICATIONS`가
/// 기본으로 켜져 있다. 컨트롤러가 올라오면 그 상수만 false로 바꾸면 된다.
class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository({required this.accessToken, ApiClient? client})
    : _client = client ?? ApiClient();

  final String? accessToken;
  final ApiClient _client;

  @override
  Future<CursorPage<AppNotification>> fetchNotifications({
    String? cursor,
  }) async {
    final data = jsonMap(
      await _guard(
        () => _client.get(
          '/notifications',
          query: {'cursor': ?cursor},
          accessToken: _requireToken(),
        ),
      ),
    );
    return CursorPage(
      items: jsonMapList(data['items'])
          .map(AppNotification.fromJson)
          .toList(growable: false),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    final data = jsonMap(
      await _guard(
        () => _client.get(
          '/notifications/unread-count',
          accessToken: _requireToken(),
        ),
      ),
    );
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String notificationId) => _guard(
    () => _client.patch(
      '/notifications/$notificationId/read',
      accessToken: _requireToken(),
    ),
  );

  @override
  Future<void> markAllRead() => _guard(
    () => _client.post('/notifications/read-all', accessToken: _requireToken()),
  );

  String _requireToken() {
    final token = accessToken;
    if (token == null) throw const NotificationFailure('로그인이 필요한 기능이에요.');
    return token;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw NotificationFailure(error.message);
    } on NotificationFailure {
      rethrow;
    } on Object {
      throw const NotificationFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

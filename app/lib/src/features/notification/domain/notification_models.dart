import 'package:flutter/foundation.dart';

/// ERD `notification_type`은 아직 `POST_LIKE · FOLLOW · BADGE_EARNED · SYSTEM`
/// 네 가지다. Figma `07_알림_목록`은 여기에 댓글과 팔로잉 새 글을 더 그리고 있어
/// 두 값을 미리 두되, 모르는 값이 와도 `system`으로 떨어뜨려 목록이 깨지지 않게 한다.
enum NotificationType {
  postLike,
  comment,
  follow,
  newPost,
  badgeEarned,
  system;

  factory NotificationType.fromJson(String? value) => switch (value) {
    'POST_LIKE' => postLike,
    'COMMENT' => comment,
    'FOLLOW' => follow,
    'NEW_POST' => newPost,
    'BADGE_EARNED' => badgeEarned,
    _ => system,
  };
}

enum NotificationTarget {
  post,
  user,
  badge,
  none;

  factory NotificationTarget.fromJson(String? value) => switch (value) {
    'POST' => post,
    'USER' => user,
    'BADGE' => badge,
    _ => none,
  };
}

@immutable
class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.type,
    required this.target,
    required this.messageKey,
    required this.isRead,
    this.targetId,
    this.messageParams = const {},
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, Object?> json) =>
      AppNotification(
        notificationId: json['notificationId']! as String,
        type: NotificationType.fromJson(json['type'] as String?),
        target: NotificationTarget.fromJson(json['targetType'] as String?),
        targetId: json['targetId'] as String?,
        messageKey: json['messageKey'] as String? ?? '',
        messageParams: Map<String, Object?>.from(
          (json['messageParams'] as Map?) ?? const {},
        ),
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  final String notificationId;
  final NotificationType type;
  final NotificationTarget target;
  final String? targetId;

  /// 서버는 완성 문장을 주지 않는다. 키와 파라미터로 앱이 조립한다 (NTF-009, SYS-010).
  final String messageKey;
  final Map<String, Object?> messageParams;
  final bool isRead;
  final DateTime? createdAt;

  /// 눌렀을 때 갈 곳. 목적지를 모르면 null이라 행이 눌리지 않는다.
  String? get destination => switch (target) {
    NotificationTarget.post when targetId != null => '/photos/$targetId',
    NotificationTarget.user when targetId != null => '/users/$targetId',
    NotificationTarget.badge => '/profile/badges',
    _ => null,
  };

  AppNotification copyWith({bool? isRead}) => AppNotification(
    notificationId: notificationId,
    type: type,
    target: target,
    targetId: targetId,
    messageKey: messageKey,
    messageParams: messageParams,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}

class NotificationFailure implements Exception {
  const NotificationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

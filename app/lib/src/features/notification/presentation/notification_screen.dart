import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/relative_time.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/notification/application/notification_providers.dart';
import 'package:snap_here/src/features/notification/domain/notification_messages.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';

/// Figma `Wireframe_v3 / 07 Shared Detail / 07_알림_목록`.
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(ref),
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => NetworkErrorView(
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyStateView(
                icon: Icons.notifications_none,
                title: '아직 알림이 없어요',
                description: '새 소식이 오면 여기에 모아 둘게요',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) => _NotificationTile(
                    notification: items[index],
                    onTap: () => _open(context, ref, items[index]),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref
      ..invalidate(notificationsProvider)
      ..invalidate(unreadNotificationCountProvider);
  }

  /// 읽음 처리와 이동은 한 동작이다 (NTF-013). 목적지가 없는 공지는 읽음만 남긴다.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (!notification.isRead) {
      await ref
          .read(notificationRepositoryProvider)
          .markRead(notification.notificationId);
      ref
        ..invalidate(notificationsProvider)
        ..invalidate(unreadNotificationCountProvider);
    }
    final destination = notification.destination;
    if (destination != null && context.mounted) context.push(destination);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = _paletteOf(notification.type);
    return Material(
      // 안읽음은 배경으로만 구분한다. 점을 따로 두면 줄이 복잡해진다.
      color: notification.isRead ? AppColors.card : AppColors.brandSubtle,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(palette.icon, size: 20, color: palette.foreground),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buildNotificationMessage(notification),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    if (notification.createdAt != null)
                      Text(
                        formatRelativeTime(notification.createdAt!),
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),
              if (notification.destination != null)
                const DesignIcon('chevron', size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color background, Color foreground}) _paletteOf(
  NotificationType type,
) => switch (type) {
  NotificationType.postLike => (
    icon: Icons.favorite_border,
    background: Color(0xFFFDE8EF),
    foreground: Color(0xFFE05A87),
  ),
  NotificationType.comment => (
    icon: Icons.chat_bubble_outline,
    background: Color(0xFFFFF4D6),
    foreground: Color(0xFFB98317),
  ),
  NotificationType.follow => (
    icon: Icons.person_outline,
    background: Color(0xFFE4F0FF),
    foreground: Color(0xFF3B7BD1),
  ),
  NotificationType.newPost => (
    icon: Icons.photo_camera_outlined,
    background: Color(0xFFE3F7EC),
    foreground: Color(0xFF2E9A66),
  ),
  NotificationType.badgeEarned => (
    icon: Icons.workspace_premium_outlined,
    background: Color(0xFFEFE7FD),
    foreground: Color(0xFF7A5BC7),
  ),
  NotificationType.system => (
    icon: Icons.campaign_outlined,
    background: Color(0xFFFFEDDF),
    foreground: Color(0xFFCC7A2B),
  ),
};

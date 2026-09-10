import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/app/router/login_navigation.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/social/application/social_providers.dart';

class FollowButton extends ConsumerWidget {
  const FollowButton({
    required this.userId,
    required this.initialFollowing,
    this.fullWidth = false,
    super.key,
  });
  final String userId;
  final bool initialFollowing;
  final bool fullWidth;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    if (session?.user?.id == userId) return const SizedBox.shrink();
    final status =
        ref.watch(followStateProvider)[userId] ??
        (following: initialFollowing, busy: false);
    return SizedBox(
      width: fullWidth ? double.infinity : 72,
      height: fullWidth ? 42 : 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          backgroundColor: status.following ? AppColors.brand : Colors.white,
          foregroundColor: status.following ? Colors.white : AppColors.brand,
        ),
        onPressed: status.busy
            ? null
            : () => _toggleFollow(context, ref, session?.isAuthenticated),
        child: status.busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                status.following ? '팔로잉' : '팔로우',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    bool? isAuthenticated,
  ) async {
    if (isAuthenticated != true) {
      requestLogin(context);
      return;
    }
    try {
      await ref
          .read(followStateProvider.notifier)
          .toggle(userId, initialFollowing: initialFollowing);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('팔로우를 변경하지 못했어요. $error')));
    }
  }
}

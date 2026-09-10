import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/activity/application/activity_providers.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';

/// 계정 삭제 확인 (USER-011 계열).
///
/// 게시물을 익명으로 남길지 함께 지울지는 되돌릴 수 없어서 삭제 버튼 한 번으로
/// 처리하지 않고 두 갈래를 명시적으로 고르게 한다. 기존 프로필 설정 시트에 있던
/// 흐름을 07_설정 화면으로 옮기면서 그대로 가져왔다.
Future<void> confirmAccountDeletion(BuildContext context, WidgetRef ref) async {
  final contentAction = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('계정을 삭제할까요?'),
      content: Consumer(
        builder: (context, ref, _) {
          // 무엇이 사라지는지 먼저 보여준다 (API-USER-008).
          final preview = ref.watch(deletionPreviewProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview.maybeWhen(
                data: (data) => Text(
                  '사진 ${data.postCount}장 · 댓글 ${data.commentCount}개 · '
                  '팔로워 ${data.followerCount}명 · 뱃지 ${data.badgeCount}개가 영향을 받아요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                preview.maybeWhen(
                  data: (data) =>
                      '${data.gracePeriodDays}일 복구 유예 후 게시물을 익명으로 보존할지, 모두 삭제할지 선택해 주세요.',
                  orElse: () => '30일 복구 유예 후 게시물을 익명으로 보존할지, 모두 삭제할지 선택해 주세요.',
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'KEEP_ANONYMIZED'),
          child: const Text('익명으로 보존'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, 'DELETE_ALL'),
          child: const Text('게시물도 삭제'),
        ),
      ],
    ),
  );
  if (contentAction == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(contentAction: contentAction);
  } on Object catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('$error')));
  }
}

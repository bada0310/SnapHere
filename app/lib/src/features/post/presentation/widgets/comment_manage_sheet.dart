import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';

enum CommentManageAction { edit, delete }

/// Figma `07_댓글_관리_메뉴` · `07_대댓글_관리_메뉴`.
Future<CommentManageAction?> showCommentManageSheet(
  BuildContext context, {
  required bool isReply,
}) {
  final noun = isReply ? '답글' : '댓글';
  return showModalBottomSheet<CommentManageAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  _SheetTitle(label: '$noun 관리'),
                  const Divider(height: 1),
                  _SheetItem(
                    label: '$noun 수정',
                    onTap: () =>
                        Navigator.of(context).pop(CommentManageAction.edit),
                  ),
                  const Divider(height: 1),
                  _SheetItem(
                    label: '$noun 삭제',
                    destructive: true,
                    onTap: () =>
                        Navigator.of(context).pop(CommentManageAction.delete),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: _SheetItem(
                label: '취소',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      color: destructive ? const Color(0xFFFDECEC) : null,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: destructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
    ),
  );
}

/// Figma `07_댓글_삭제확인`. 문구가 자식 댓글 이야기를 하는 이유는 부모를 지워도
/// 대댓글은 남기 때문이다 (CMU-017).
Future<bool> confirmCommentDeletion(
  BuildContext context, {
  required bool isReply,
}) async {
  final noun = isReply ? '답글' : '댓글';
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text('$noun을 삭제할까요?'),
      content: Text(
        isReply ? '삭제한 답글은 복구할 수 없습니다.' : '삭제한 댓글과 연결된 대댓글은 복구할 수 없습니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return result ?? false;
}

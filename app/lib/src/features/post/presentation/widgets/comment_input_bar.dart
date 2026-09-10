import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/post/application/comment_composer.dart';

/// Figma `07_게시글_상세 / InputBar`와 `12 Comment CRUD Prototype`의 입력 줄.
///
/// 답글·수정일 때 위에 안내 줄과 취소가 붙는 것 말고는 세 상태가 같은 줄을 쓴다.
class CommentInputBar extends StatelessWidget {
  const CommentInputBar({
    required this.composer,
    required this.controller,
    required this.onSubmit,
    this.myProfileImageUrl,
    super.key,
  });

  final CommentComposer composer;
  final TextEditingController controller;
  final Future<void> Function() onSubmit;
  final String? myProfileImageUrl;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: composer,
    builder: (context, state, _) => Material(
      color: AppColors.card,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.banner != null)
              _ComposerBanner(
                label: state.banner!,
                onCancel: () {
                  controller.clear();
                  composer.cancel();
                },
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ProfileAvatar(url: myProfileImageUrl, size: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !state.isSubmitting,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: state.hintText,
                        counterText: '',
                        // 여러 줄로 늘어나야 해서 전역 고정 높이를 푼다.
                        constraints: const BoxConstraints(minHeight: 38),
                        fillColor: AppColors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _SubmitButton(
                    label: state.submitLabel,
                    busy: state.isSubmitting,
                    onPressed: onSubmit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ComposerBanner extends StatelessWidget {
  const _ComposerBanner({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.brandSubtle,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        GestureDetector(
          onTap: onCancel,
          child: Text(
            '취소',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

/// 전송 중에는 자리를 유지한 채 스피너로 바꾼다. 버튼이 사라지면 줄 폭이 흔들린다.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    child: busy
        ? const Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : TextButton(onPressed: onPressed, child: Text(label)),
  );
}

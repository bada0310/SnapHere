import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/relative_time.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';

/// Figma `07_댓글_상세_목록`의 한 줄. 대댓글은 같은 위젯을 들여쓰기만 해서 쓴다.
class CommentTile extends StatelessWidget {
  const CommentTile({
    required this.comment,
    required this.isMine,
    this.onReply,
    this.onManage,
    this.indented = false,
    super.key,
  });

  final Comment comment;
  final bool isMine;
  final VoidCallback? onReply;

  /// `07_댓글_관리_메뉴` 바텀시트를 여는 `⋯`. 남의 댓글이면 없다.
  final VoidCallback? onManage;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        indented ? AppSpacing.xxl : AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            url: comment.author.profileImageUrl,
            size: indented ? 24 : 32,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(comment: comment, isMine: isMine),
                const SizedBox(height: AppSpacing.xs),
                _Body(comment: comment),
                if (!comment.isDeleted) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Actions(likeCount: comment.likeCount, onReply: onReply),
                ],
              ],
            ),
          ),
          if (isMine && !comment.isDeleted && onManage != null)
            IconButton(
              tooltip: '댓글 관리',
              onPressed: onManage,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.more_horiz,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.comment, required this.isMine});

  final Comment comment;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isMine ? '${comment.author.nickname} (나)' : comment.author.nickname,
          style: text.labelLarge,
        ),
        if (comment.createdAt != null)
          Text(formatRelativeTime(comment.createdAt!), style: text.bodySmall),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // 서버는 삭제된 댓글의 본문을 null로 준다. 문구는 앱이 만든다 (CMU-017, SYS-010).
    if (comment.isDeleted) {
      return Text(
        '삭제된 댓글입니다',
        style: text.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Text(comment.content ?? '', style: text.bodyMedium);
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.likeCount, this.onReply});

  final int likeCount;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AppColors.textSecondary);
    return Row(
      children: [
        // 댓글 좋아요 API(CMU-009·010)가 아직 없어 숫자만 보여준다.
        Text('좋아요 $likeCount', style: style),
        if (onReply != null) ...[
          const SizedBox(width: AppSpacing.lg),
          GestureDetector(
            onTap: onReply,
            behavior: HitTestBehavior.opaque,
            child: Text('답글 달기', style: style),
          ),
        ],
      ],
    );
  }
}

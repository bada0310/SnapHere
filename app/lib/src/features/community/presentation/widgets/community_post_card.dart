import 'package:flutter/material.dart';
import 'package:snap_here/src/core/ui/relative_time.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';

/// Figma `DS/Components / Content/PostCard` (`Feed/PostCard`).
/// `03_커뮤니티_전체`와 `03_커뮤니티_검색결과`가 같은 카드를 쓴다.
///
/// 412px 프레임 기준 실측값:
/// 카드 너비 380 · padding 16 · 자식 간격 12 · radius 16 · 테두리 1px #E8ECEF
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({required this.post, this.onTap, super.key});

  /// `AuthorRow`가 hug로 계산되는 높이 = 아바타 크기.
  static const avatarSize = 34.0;

  /// `MediaArea` 348 × 160.
  static const mediaAspectRatio = 348 / 160;

  final CommunityPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              _Header(post: post),
              _Thumbnail(post: post),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Text(post.title, style: textTheme.titleMedium),
                  Text(
                    post.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              _Footer(post: post),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Figma의 AuthorRow는 hug라 아바타(34) 높이를 따라간다.
    // 높이를 강제하면 닉네임+장소 두 줄이 2px 넘쳐서 고정하지 않는다.
    return Row(
      spacing: AppSpacing.sm,
      children: [
        _Avatar(author: post.author),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.author.nickname,
                style: textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
              if (post.locationLabel case final label?)
                Row(
                  spacing: AppSpacing.xs,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    Expanded(
                      child: Text(
                        label,
                        style: textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (post.badge case final badge?) _BadgeChip(label: badge.label),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.author});

  final CommunityAuthor author;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CommunityPostCard.avatarSize,
      height: CommunityPostCard.avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        author.avatarLabel,
        // Figma: Inter Bold 12. DS 타이포 6단계에 없는 값이라 직접 지정한다.
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        // Figma: Inter Bold 10.
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: CommunityPostCard.mediaAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // API 연동 전에는 URL이 없어 자리 표시자를 그린다.
            if (post.thumbnailUrl case final url?)
              Image.network(url, fit: BoxFit.cover)
            else
              const ColoredBox(
                color: AppColors.brandSubtle,
                child: Icon(
                  Icons.photo_outlined,
                  size: 40,
                  color: AppColors.textSecondary,
                ),
              ),
            if (post.imageCount > 1)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _ImageCountChip(count: post.imageCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageCountChip extends StatelessWidget {
  const _ImageCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 12,
            color: Colors.white,
          ),
          Text(
            '+${count - 1}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      spacing: AppSpacing.xs,
      children: [
        const Icon(
          Icons.favorite_border,
          size: 16,
          color: AppColors.textSecondary,
        ),
        Text('${post.likeCount}', style: textTheme.bodySmall),
        const SizedBox(width: AppSpacing.sm),
        const Icon(
          Icons.chat_bubble_outline,
          size: 16,
          color: AppColors.textSecondary,
        ),
        Text('${post.commentCount}', style: textTheme.bodySmall),
        const Spacer(),
        Text(formatRelativeTime(post.createdAt), style: textTheme.bodySmall),
      ],
    );
  }
}

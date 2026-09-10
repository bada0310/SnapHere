import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/relative_time.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/post/application/post_providers.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/domain/post_repository.dart';
import 'package:snap_here/src/features/post/presentation/widgets/post_photo_carousel.dart';
import 'package:snap_here/src/features/post/presentation/widgets/report_reason_sheet.dart';
import 'package:snap_here/src/features/post/presentation/widgets/tier_badge.dart';
import 'package:snap_here/src/features/social/presentation/follow_button.dart';

/// Figma `Wireframe_v3 / 07 Shared Detail / 07_게시글_상세`.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postDetailProvider(postId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('게시글'),
        actions: [
          post.maybeWhen(
            data: (detail) => _OverflowMenu(detail: detail),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: post.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => NetworkErrorView(
          onRetry: () => ref.invalidate(postDetailProvider(postId)),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(postDetailProvider(postId)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              PostPhotoCarousel(images: detail.images),
              _PostInfo(detail: detail),
              const SizedBox(height: AppSpacing.sm),
              _CommentsEntry(detail: detail),
            ],
          ),
        ),
      ),
    );
  }
}

/// 사진 아래 본문 덩어리. Figma `ScrollContainer / PostInfo`에 해당한다.
class _PostInfo extends ConsumerWidget {
  const _PostInfo({required this.detail});

  final PostDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(detail: detail),
          const SizedBox(height: AppSpacing.md),
          Text(detail.title, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          if (detail.place != null) _PlaceRow(detail: detail),
          if (detail.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(detail.body, style: text.bodyMedium),
          ],
          if (detail.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _TagRow(tags: detail.tags),
          ],
          const SizedBox(height: AppSpacing.lg),
          _ReactionRow(detail: detail),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.detail});

  final PostDetail detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.push('/users/${detail.author.userId}'),
          child: ProfileAvatar(url: detail.author.profileImageUrl, size: 36),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.author.nickname, style: text.labelLarge),
              if (detail.createdAt != null)
                Text(
                  formatRelativeTime(detail.createdAt!),
                  style: text.bodySmall,
                ),
            ],
          ),
        ),
        FollowButton(userId: detail.author.userId, initialFollowing: false),
      ],
    );
  }
}

/// 장소명과 위치 신뢰도 배지를 한 줄에 둔다 (PST-033, PST-046, PLC-012).
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.detail});

  final PostDetail detail;

  @override
  Widget build(BuildContext context) {
    final place = detail.place!;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.push('/places/${place.placeId}'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                place.title,
                style: text.labelLarge?.copyWith(color: AppColors.brand),
              ),
              if (place.addr1 != null)
                Text(' · ${place.addr1}', style: text.bodySmall),
            ],
          ),
        ),
        if (detail.tierResult != null) TierBadge(result: detail.tierResult!),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags});

  final List<PostTag> tags;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final tag in tags)
        GestureDetector(
          onTap: () => context.push('/community/search?tag=${tag.name}'),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tag.locked) ...[
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 14,
                    color: Color(0xFF9A6B12),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(tag.name, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
    ],
  );
}

/// 좋아요·댓글 수와 저장. 누르자마자 화면을 바꾸고 실패하면 되돌린다.
class _ReactionRow extends ConsumerStatefulWidget {
  const _ReactionRow({required this.detail});

  final PostDetail detail;

  @override
  ConsumerState<_ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends ConsumerState<_ReactionRow> {
  late bool _liked = widget.detail.isLiked ?? false;
  late int _likeCount = widget.detail.likeCount;
  late bool _bookmarked = widget.detail.isBookmarked ?? false;
  var _busy = false;

  Future<void> _toggleLike() async {
    if (_busy) return;
    final previous = (liked: _liked, count: _likeCount);
    setState(() {
      _busy = true;
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      final result = await ref
          .read(postRepositoryProvider)
          .setLiked(widget.detail.postId, _liked);
      if (!mounted) return;
      setState(() {
        _liked = result.isLiked;
        _likeCount = result.likeCount;
      });
    } on PostFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _liked = previous.liked;
        _likeCount = previous.count;
      });
      _notify(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBookmark() async {
    if (_busy) return;
    final previous = _bookmarked;
    setState(() {
      _busy = true;
      _bookmarked = !_bookmarked;
    });
    try {
      final saved = await ref
          .read(postRepositoryProvider)
          .setBookmarked(widget.detail.postId, _bookmarked);
      if (mounted) setState(() => _bookmarked = saved);
    } on PostFailure catch (error) {
      if (!mounted) return;
      setState(() => _bookmarked = previous);
      _notify(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconCount(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          color: _liked ? AppColors.brand : AppColors.textSecondary,
          label: '$_likeCount',
          onTap: _toggleLike,
        ),
        const SizedBox(width: AppSpacing.lg),
        _IconCount(
          icon: Icons.chat_bubble_outline,
          color: AppColors.textSecondary,
          label: '${widget.detail.commentCount}',
          onTap: () => context.push('/photos/${widget.detail.postId}/comments'),
        ),
        const Spacer(),
        IconButton(
          tooltip: _bookmarked ? '저장 해제' : '저장',
          onPressed: _toggleBookmark,
          icon: Icon(
            _bookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: _bookmarked ? AppColors.brand : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _IconCount extends StatelessWidget {
  const _IconCount({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

/// `댓글 N개` 줄. 누르면 `12 Comment CRUD Prototype`의 댓글 화면으로 간다.
class _CommentsEntry extends StatelessWidget {
  const _CommentsEntry({required this.detail});

  final PostDetail detail;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    child: InkWell(
      onTap: () => context.push('/photos/${detail.postId}/comments'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '댓글 ${detail.commentCount}개',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const DesignIcon('chevron', size: 18),
          ],
        ),
      ),
    ),
  );
}

/// 본인 글이면 수정·삭제, 아니면 신고 (PST-036~038, PST-043).
class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.detail});

  final PostDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).value?.user;
    final isMine = me != null && me.id == detail.author.userId;
    return PopupMenuButton<String>(
      tooltip: '더보기',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => _run(context, ref, value),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'share', child: Text('공유')),
        if (isMine) ...[
          const PopupMenuItem(value: 'edit', child: Text('수정')),
          const PopupMenuItem(value: 'delete', child: Text('삭제')),
        ] else
          const PopupMenuItem(value: 'report', child: Text('신고')),
      ],
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, String action) async {
    final repository = ref.read(postRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'share':
        await _share(repository, messenger);
      case 'edit':
        messenger.showSnackBar(
          const SnackBar(content: Text('게시글 수정은 준비 중이에요.')),
        );
      case 'delete':
        final ok = await _confirm(
          context,
          '게시글을 삭제할까요?',
          '삭제한 게시글은 복구할 수 없습니다.',
        );
        if (!ok || !context.mounted) return;
        try {
          await repository.deletePost(detail.postId);
          if (context.mounted) context.pop();
        } on PostFailure catch (error) {
          messenger.showSnackBar(SnackBar(content: Text(error.message)));
        }
      case 'report':
        final reason = await showReportReasonSheet(context);
        if (reason == null) return;
        try {
          await repository.report(detail.postId, reason: reason.code);
          messenger.showSnackBar(const SnackBar(content: Text('신고를 접수했어요.')));
        } on PostFailure catch (error) {
          messenger.showSnackBar(SnackBar(content: Text(error.message)));
        }
    }
  }

  /// 외부 공유 링크 (CMU-019·020). 공유 시트 패키지를 새로 넣지 않고 주소를
  /// 클립보드에 담는다 — 링크 자체가 앱 없이 열리는 공개 페이지다.
  Future<void> _share(
    PostRepository repository,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final metadata = await repository.fetchShareMetadata(detail.postId);
      if (metadata.shareUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('공유 주소를 만들지 못했어요.')),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: metadata.shareUrl));
      messenger.showSnackBar(const SnackBar(content: Text('공유 링크를 복사했어요.')));
    } on PostFailure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/post/application/comment_composer.dart';
import 'package:snap_here/src/features/post/application/comment_providers.dart';
import 'package:snap_here/src/features/post/application/post_providers.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/presentation/widgets/comment_input_bar.dart';
import 'package:snap_here/src/features/post/presentation/widgets/comment_manage_sheet.dart';
import 'package:snap_here/src/features/post/presentation/widgets/comment_tile.dart';

/// Figma `12 Comment CRUD Prototype`. 댓글은 게시글 상세와 별도 화면이다
/// (`07_댓글_상세_목록`의 앱바가 `‹ 댓글`이다).
class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _input = TextEditingController();
  late final CommentComposer _composer;

  @override
  void initState() {
    super.initState();
    _composer = CommentComposer(
      ref.read(postRepositoryProvider),
      widget.postId,
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(commentThreadsProvider(widget.postId));
    ref.invalidate(postDetailProvider(widget.postId));
  }

  Future<void> _submit() async {
    final error = await _composer.submit(_input.text);
    if (!mounted) return;
    if (error != null) {
      // 실패해도 입력은 지우지 않는다. 다시 누르면 그대로 보낸다.
      _notify(error);
      return;
    }
    _input.clear();
    FocusScope.of(context).unfocus();
    _refresh();
  }

  void _startReply(Comment parent) {
    _input.clear();
    _composer.startReply(
      parentId: parent.commentId,
      nickname: parent.author.nickname,
    );
  }

  Future<void> _manage(Comment comment, {required bool isReply}) async {
    final action = await showCommentManageSheet(context, isReply: isReply);
    if (!mounted || action == null) return;
    switch (action) {
      case CommentManageAction.edit:
        _input.text = comment.content ?? '';
        _composer.startEdit(commentId: comment.commentId);
      case CommentManageAction.delete:
        await _delete(comment, isReply: isReply);
    }
  }

  Future<void> _delete(Comment comment, {required bool isReply}) async {
    final confirmed = await confirmCommentDeletion(context, isReply: isReply);
    if (!mounted || !confirmed) return;
    try {
      await ref.read(postRepositoryProvider).deleteComment(comment.commentId);
      if (!mounted) return;
      _refresh();
    } on PostFailure catch (error) {
      if (mounted) _notify(error.message);
    }
  }

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(commentThreadsProvider(widget.postId));
    final post = ref.watch(postDetailProvider(widget.postId));
    final me = ref.watch(authControllerProvider).value?.user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('댓글'),
      ),
      body: Column(
        children: [
          post.maybeWhen(
            data: (detail) =>
                _PostSummaryCard(detail: detail, onTap: () => context.pop()),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: threads.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => NetworkErrorView(onRetry: _refresh),
              data: (items) => items.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.chat_bubble_outline,
                      title: '아직 댓글이 없어요',
                      description: '첫 댓글을 남겨 보세요',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: _ThreadList(
                        threads: items,
                        myUserId: me?.id,
                        onReply: _startReply,
                        onManage: _manage,
                      ),
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommentInputBar(
        composer: _composer,
        controller: _input,
        onSubmit: _submit,
        myProfileImageUrl: me?.photoUrl,
      ),
    );
  }
}

class _ThreadList extends StatelessWidget {
  const _ThreadList({
    required this.threads,
    required this.myUserId,
    required this.onReply,
    required this.onManage,
  });

  final List<CommentThread> threads;
  final String? myUserId;
  final void Function(Comment parent) onReply;
  final Future<void> Function(Comment comment, {required bool isReply})
  onManage;

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: threads.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (_, index) {
      final thread = threads[index];
      return ColoredBox(
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommentTile(
              comment: thread.parent,
              isMine: thread.parent.author.userId == myUserId,
              onReply: () => onReply(thread.parent),
              onManage: () => onManage(thread.parent, isReply: false),
            ),
            for (final reply in thread.replies)
              CommentTile(
                comment: reply,
                isMine: reply.author.userId == myUserId,
                indented: true,
                onReply: () => onReply(thread.parent),
                onManage: () => onManage(reply, isReply: true),
              ),
          ],
        ),
      );
    },
  );
}

/// 어느 글의 댓글인지 알려주는 머리 카드. 누르면 게시글로 돌아간다.
class _PostSummaryCard extends StatelessWidget {
  const _PostSummaryCard({required this.detail, required this.onTap});

  final PostDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.card,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox.square(
                  dimension: 44,
                  child: RemoteImage(
                    url: detail.images.isEmpty
                        ? null
                        : detail.images.first.thumbnailUrl ??
                              detail.images.first.imageUrl,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge,
                    ),
                    Text(
                      [
                        detail.author.nickname,
                        if (detail.place != null) detail.place!.title,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const DesignIcon('chevron', size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

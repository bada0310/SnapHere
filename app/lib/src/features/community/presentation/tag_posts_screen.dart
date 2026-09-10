import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/community/application/community_providers.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_post_card.dart';

/// 태그를 누르면 열리는 목록 (API-CMU-013, SCH-007).
///
/// 게시글 상세의 해시태그와 검색 결과의 태그 칩이 모두 여기로 온다.
class TagPostsScreen extends ConsumerWidget {
  const TagPostsScreen({required this.tagId, this.tagName, super.key});

  final String tagId;
  final String? tagName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(tagPostsProvider(tagId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: Text(tagName == null ? '태그' : '#$tagName'),
      ),
      body: posts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => NetworkErrorView(
          onRetry: () => ref.invalidate(tagPostsProvider(tagId)),
        ),
        data: (items) => items.isEmpty
            ? const EmptyStateView(
                title: '이 태그의 사진이 아직 없어요',
                description: '이 태그를 달아 첫 사진을 올려 보세요',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(tagPostsProvider(tagId)),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, index) => CommunityPostCard(
                    post: items[index],
                    onTap: () => context.push('/photos/${items[index].postId}'),
                  ),
                ),
              ),
      ),
    );
  }
}

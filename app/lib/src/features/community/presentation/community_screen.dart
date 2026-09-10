import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/social/presentation/follow_button.dart';
import 'package:snap_here/src/features/social/application/social_providers.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/community/application/community_providers.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_empty_state.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_post_card.dart';

/// Figma `03_커뮤니티_전체` / `03_커뮤니티_팔로잉_빈상태`.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(communityFeedTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('커뮤니티', style: Theme.of(context).textTheme.headlineSmall),
        actions: [
          IconButton(
            tooltip: '알림',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: _SearchEntry(onTap: () => context.push('/community/search')),
          ),
          _FeedTabBar(
            selected: tab,
            onSelected: (value) =>
                ref.read(communityFeedTabProvider.notifier).select(value),
          ),
          Expanded(child: _FeedBody(tab: tab)),
        ],
      ),
    );
  }
}

/// 눌러서 검색 화면으로 넘어가는 읽기 전용 검색창.
/// 실제 입력은 `03_커뮤니티_검색_포커스`에서 한다.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        // Figma `SearchBar`: 높이 38 · radius 10 · padding 좌 10 / 우 14
        height: 38,
        padding: const EdgeInsets.only(left: 10, right: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '검색어를 입력하세요',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTabBar extends StatelessWidget {
  const _FeedTabBar({required this.selected, required this.onSelected});

  final CommunityFeedTab selected;
  final ValueChanged<CommunityFeedTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (final tab in CommunityFeedTab.values)
            Expanded(
              child: _FeedTabButton(
                label: switch (tab) {
                  CommunityFeedTab.all => '전체',
                  CommunityFeedTab.following => '팔로잉',
                },
                isSelected: tab == selected,
                onTap: () => onSelected(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedTabButton extends StatelessWidget {
  const _FeedTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.brand : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.tab});

  final CommunityFeedTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(communityFeedProvider);

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _FeedError(
        message: '$error',
        onRetry: () => ref.invalidate(communityFeedProvider),
      ),
      data: (data) {
        if (data.isEmpty) {
          // Figma가 그린 빈 상태는 팔로잉 탭(`03_커뮤니티_팔로잉_빈상태`) 하나다.
          // 전체 탭이 비는 경우의 화면은 `08 Error & Empty States`의
          // `08_상태_게시글없음`이라 그 섹션 작업에서 맞춘다.
          return tab == CommunityFeedTab.following
              ? const _FollowingEmptyState()
              : const CommunityEmptyState(
                  icon: Icons.photo_outlined,
                  title: '아직 게시글이 없어요',
                  description: '첫 번째 스냅을 올려보세요.',
                );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(communityFeedProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            itemCount: data.posts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SortRow(sectionTitle: data.sectionTitle);
              }
              final post = data.posts[index - 1];
              return CommunityPostCard(
                post: post,
                onTap: () => context.push('/photos/${post.postId}'),
              );
            },
          ),
        );
      },
    );
  }
}

/// "인기 스냅" 라벨 + 정렬 드롭다운.
class _SortRow extends ConsumerWidget {
  const _SortRow({required this.sectionTitle});

  final String? sectionTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(communitySortProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          sectionTitle ?? '',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<CommunitySort>(
            value: sort,
            isDense: true,
            borderRadius: BorderRadius.circular(AppRadius.md),
            style: Theme.of(context).textTheme.bodyMedium,
            items: [
              for (final option in CommunitySort.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              ref.read(communitySortProvider.notifier).select(value);
            },
          ),
        ),
      ],
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CommunityEmptyState(
      icon: Icons.error_outline,
      title: '피드를 불러오지 못했어요',
      description: message,
      actionLabel: '다시 시도',
      onAction: onRetry,
      actionStyle: CommunityEmptyActionStyle.outlined,
    );
  }
}

/// 팔로잉이 없을 때는 빈 화면 대신 추천 사용자를 함께 보여준다 (결정 8번, SOC-005).
class _FollowingEmptyState extends ConsumerWidget {
  const _FollowingEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommended = ref.watch(recommendedUsersProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        CommunityEmptyState(
          icon: Icons.people_outline,
          title: '팔로잉 중인 사용자가 없어요',
          description: '관심 있는 여행자를 팔로우해 보세요.\n새로운 여행 소식을 먼저 볼 수 있어요.',
          actionLabel: '사용자 찾기',
          onAction: () => context.push('/community/search'),
        ),
        recommended.maybeWhen(
          data: (users) => users.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '이런 여행자는 어때요?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final user in users)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ProfileAvatar(url: user.imageUrl, size: 44),
                        title: Text(user.nickname),
                        subtitle: user.bio == null || user.bio!.isEmpty
                            ? null
                            : Text(
                                user.bio!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: FollowButton(
                          userId: user.userId,
                          initialFollowing: user.isFollowing,
                        ),
                        onTap: () => context.push('/users/${user.userId}'),
                      ),
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

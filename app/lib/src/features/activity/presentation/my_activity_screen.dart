import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/relative_time.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/activity/application/activity_providers.dart';
import 'package:snap_here/src/features/activity/domain/activity_models.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_post_card.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';

/// 마이페이지에서 들어오는 내 활동 모음.
///
/// 저장함(USER-007) · 좋아요(USER-006) · 방문(VST-001·002)이 각각 다른 화면일
/// 필요가 없어서 탭 하나로 묶었다.
enum ActivityTab {
  saved('저장함'),
  liked('좋아요'),
  visits('방문');

  const ActivityTab(this.label);

  final String label;

  static ActivityTab fromName(String? value) => values.firstWhere(
    (tab) => tab.name == value,
    orElse: () => ActivityTab.saved,
  );
}

class MyActivityScreen extends StatelessWidget {
  const MyActivityScreen({this.initialTab = ActivityTab.saved, super.key});

  final ActivityTab initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: ActivityTab.values.length,
    initialIndex: ActivityTab.values.indexOf(initialTab),
    child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('내 활동'),
        bottom: TabBar(
          tabs: [for (final tab in ActivityTab.values) Tab(text: tab.label)],
        ),
      ),
      body: const TabBarView(
        children: [_SavedTab(), _LikedTab(), _VisitsTab()],
      ),
    ),
  );
}

/// 저장함은 사진과 장소를 함께 담는다 (CMU-023, PLC-015).
class _SavedTab extends ConsumerWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(bookmarkedPostsProvider);
    final places = ref.watch(bookmarkedPlacesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref
        ..invalidate(bookmarkedPostsProvider)
        ..invalidate(bookmarkedPlacesProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          places.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '저장한 장소',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final place in items) _PlaceRow(place: place),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          posts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => NetworkErrorView(
              onRetry: () => ref.invalidate(bookmarkedPostsProvider),
            ),
            data: (items) => items.isEmpty && places.value?.isEmpty != false
                ? const EmptyStateView(
                    icon: Icons.bookmark_border,
                    title: '저장한 항목이 없어요',
                    description: '마음에 드는 사진과 장소를 저장해 두세요',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items.isNotEmpty)
                        Text(
                          '저장한 사진',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final post in items) ...[
                        CommunityPostCard(
                          post: post,
                          onTap: () => context.push('/photos/${post.postId}'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LikedTab extends ConsumerWidget {
  const _LikedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(likedPostsProvider);
    return posts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          NetworkErrorView(onRetry: () => ref.invalidate(likedPostsProvider)),
      data: (items) => items.isEmpty
          ? const EmptyStateView(
              icon: Icons.favorite_border,
              title: '좋아요한 사진이 없어요',
              description: '마음에 드는 사진에 좋아요를 눌러 보세요',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(likedPostsProvider),
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
    );
  }
}

class _VisitsTab extends ConsumerWidget {
  const _VisitsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider);
    return visits.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          NetworkErrorView(onRetry: () => ref.invalidate(visitsProvider)),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref
          ..invalidate(visitsProvider)
          ..invalidate(visitStatsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const _VisitStatsCard(),
            const SizedBox(height: AppSpacing.lg),
            if (items.isEmpty)
              const EmptyStateView(
                icon: Icons.place_outlined,
                title: '아직 방문 기록이 없어요',
                description: '장소에서 사진을 올리면 방문으로 기록돼요',
              )
            else
              for (final visit in items) _VisitRow(visit: visit),
          ],
        ),
      ),
    );
  }
}

/// 17개 시도 중 몇 곳을 다녀왔는지 (VST-002).
class _VisitStatsCard extends ConsumerWidget {
  const _VisitStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(visitStatsProvider);
    return stats.maybeWhen(
      data: (data) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '전국 ${data.totalRegionCount}곳 중 ${data.visitedRegionCount}곳',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: data.progress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox.square(
        dimension: 44,
        child: RemoteImage(url: visit.place.imageUrl),
      ),
    ),
    title: Text(
      visit.place.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: visit.visitedOn == null
        ? null
        : Text(formatRelativeTime(visit.visitedOn!)),
    trailing: const DesignIcon('chevron', size: 18),
    onTap: () => context.push('/places/${visit.place.placeId}'),
  );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final PlaceSummary place;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox.square(
        dimension: 44,
        child: RemoteImage(url: place.imageUrl),
      ),
    ),
    title: Text(place.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: place.addr1 == null
        ? null
        : Text(place.addr1!, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const DesignIcon('chevron', size: 18),
    onTap: () => context.push('/places/${place.placeId}'),
  );
}

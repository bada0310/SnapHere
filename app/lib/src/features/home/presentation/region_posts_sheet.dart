import 'package:flutter/material.dart';
import 'package:snap_here/src/core/ui/relative_time.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/paged_sliver.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/explore/domain/explore_models.dart';
import 'package:snap_here/src/features/home/application/home_map_providers.dart';

class RegionPostsSheet extends ConsumerWidget {
  const RegionPostsSheet({
    required this.region,
    required this.scrollController,
    required this.onClose,
    super.key,
  });
  final RegionOverview region;
  final ScrollController scrollController;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(homeMapRepositoryProvider);
    return Material(
      color: Colors.white,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        region.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '게시글 ${region.postCount}개',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '지역 게시글 닫기',
                        onPressed: onClose,
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PagedSliver<CommunityPost>(
            key: ValueKey((repository, region.areaCode)),
            load: (cursor) =>
                repository.fetchRegionPosts(region.areaCode, cursor: cursor),
            itemId: (post) => post.postId,
            empty: const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('이번 주 이 지역의 게시글이 없어요.', textAlign: TextAlign.center),
            ),
            sliverBuilder: (posts) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => MapPostCard(post: posts[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapPostCard extends StatelessWidget {
  const MapPostCard({required this.post, super.key});
  final CommunityPost post;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/photos/${post.postId}'),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 90,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RemoteImage(url: post.thumbnailUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.placeName ?? post.regionName ?? '여행 스냅',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              context.push('/users/${post.author.userId}'),
                          child: Row(
                            children: [
                              ProfileAvatar(
                                url: post.author.profileImageUrl,
                                size: 20,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  post.author.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border,
                        size: 14,
                        color: AppColors.error,
                      ),
                      Text(
                        '${post.likeCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRelativeTime(post.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
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

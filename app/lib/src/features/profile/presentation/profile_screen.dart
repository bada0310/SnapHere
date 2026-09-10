import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/paged_sliver.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/profile/application/profile_providers.dart';
import 'package:snap_here/src/features/profile/domain/profile_models.dart';
import 'package:snap_here/src/features/social/presentation/follow_button.dart';

/// Figma 92:1932 / 92:2173 / 92:2340.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.userId, super.key});
  final String? userId;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).value;
    final own = widget.userId == null || widget.userId == session?.user?.id;
    final AsyncValue<ProfileSnapshot?> profile = own
        ? ref.watch(profileSnapshotProvider)
        : ref.watch(publicProfileProvider(widget.userId!));
    final repository = ref.watch(profileRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(own ? '마이' : '프로필'),
        leading: own ? null : const DesignBackButton(),
        toolbarHeight: 48,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: own
            ? [
                IconButton(
                  tooltip: '알림',
                  onPressed: () => context.push('/notifications'),
                  icon: const DesignIcon('bell', size: 20),
                ),
                IconButton(
                  tooltip: '내 활동',
                  onPressed: () => context.push('/me/activity'),
                  icon: const Icon(Icons.bookmark_border, size: 20),
                ),
                IconButton(
                  tooltip: '설정',
                  onPressed: () => context.push('/settings'),
                  icon: const DesignIcon('settings', size: 20),
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _revision++);
          if (own) {
            ref.invalidate(profileSnapshotProvider);
            await ref
                .read(profileSnapshotProvider.future)
                .then<void>((_) {}, onError: (Object _, StackTrace _) {});
          } else {
            ref.invalidate(publicProfileProvider(widget.userId!));
            await ref
                .read(publicProfileProvider(widget.userId!).future)
                .then<void>((_) {}, onError: (Object _, StackTrace _) {});
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: profile.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: RetryMessage(
                    message: '프로필을 불러오지 못했어요',
                    onRetry: () {
                      if (own) {
                        ref.invalidate(profileSnapshotProvider);
                      } else {
                        ref.invalidate(publicProfileProvider(widget.userId!));
                      }
                    },
                  ),
                ),
                data: (data) => data == null
                    ? const SizedBox.shrink()
                    : _ProfileHeader(profile: data, own: own),
              ),
            ),
            if (profile.value case final data?) ...[
              SliverToBoxAdapter(
                child: own
                    ? Material(
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                alignment: Alignment.center,
                                constraints: const BoxConstraints(
                                  minHeight: 46,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.brand,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '내 게시글',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () =>
                                    context.push('/profile/badges'),
                                child: const Text(
                                  '수집한 뱃지',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          '게시글',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              PagedSliver<CommunityPost>(
                key: ValueKey((repository, data.userId, _revision)),
                load: (cursor) =>
                    repository.fetchPosts(data.userId, cursor: cursor),
                itemId: (post) => post.postId,
                empty: _EmptyPosts(own: own),
                sliverBuilder: (posts) => SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: own
                      ? SliverList.separated(
                          itemCount: posts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) =>
                              ProfilePostCard(post: posts[index]),
                        )
                      : SliverGrid.builder(
                          itemCount: posts.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 240,
                                mainAxisExtent: 218,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemBuilder: (_, index) => ProfilePostCard(
                            post: posts[index],
                            compact: true,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.own});
  final ProfileSnapshot profile;
  final bool own;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfileAvatar(url: profile.imageUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.nickname,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.bio?.isNotEmpty == true
                          ? profile.bio!
                          : '아직 소개가 없어요',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                _Metric(label: '게시글', count: profile.stats.postCount),
                _Metric(
                  label: '팔로워',
                  count: profile.stats.followerCount,
                  onTap: () =>
                      context.push('/users/${profile.userId}/followers'),
                ),
                _Metric(
                  label: '팔로잉',
                  count: profile.stats.followingCount,
                  onTap: () =>
                      context.push('/users/${profile.userId}/following'),
                ),
                if (own)
                  _Metric(
                    label: '뱃지',
                    count: profile.stats.badgeCount,
                    onTap: () => context.push('/profile/badges'),
                  ),
              ],
            ),
          ),
          if (!own) ...[
            const SizedBox(height: 16),
            FollowButton(
              userId: profile.userId,
              initialFollowing: profile.isFollowing,
              fullWidth: true,
            ),
          ],
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.count, this.onTap});
  final String label;
  final int count;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${formatCount(count)} $label',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: onTap == null ? AppColors.textPrimary : AppColors.brand,
            ),
          ),
        ),
      ),
    ),
  );
}

String formatCount(int value) => '$value'.replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

class ProfilePostCard extends StatelessWidget {
  const ProfilePostCard({required this.post, this.compact = false, super.key});
  final CommunityPost post;
  final bool compact;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/photos/${post.postId}'),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (compact) ...[
                  ProfileAvatar(url: post.author.profileImageUrl, size: 24),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    compact
                        ? post.author.nickname
                        : post.locationLabel ?? '여행 스냅',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: compact
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: compact ? 100 : 160,
                child: RemoteImage(url: post.thumbnailUrl),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 13 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyPosts extends StatelessWidget {
  const _EmptyPosts({required this.own});
  final bool own;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0xFFE9EEF2),
          child: DesignIcon('camera', size: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          '아직 게시글이 없어요',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (own) ...[
          const SizedBox(height: 8),
          const Text(
            '첫 여행 사진을 올려 보세요',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.push('/upload'),
            child: const Text('첫 사진 올리기'),
          ),
        ],
      ],
    ),
  );
}

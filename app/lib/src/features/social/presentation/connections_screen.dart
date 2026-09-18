import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/app/router/shell_navigation.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/paged_sliver.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/profile/application/profile_providers.dart';
import 'package:snap_here/src/features/social/application/social_providers.dart';
import 'package:snap_here/src/features/social/data/api_social_repository.dart';
import 'package:snap_here/src/features/social/presentation/follow_button.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({
    required this.userId,
    required this.kind,
    super.key,
  });
  final String userId;
  final ConnectionKind kind;
  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  int _revision = 0;
  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(socialRepositoryProvider);
    final profile = ref.watch(publicProfileProvider(widget.userId)).value;
    final followers = widget.kind == ConnectionKind.followers;
    final label = followers ? '팔로워' : '팔로잉';
    final count = followers
        ? profile?.stats.followerCount
        : profile?.stats.followingCount;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        toolbarHeight: 48,
        title: Text('$label${count == null ? '' : ' $count'}'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _revision++);
          ref.invalidate(publicProfileProvider(widget.userId));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            PagedSliver<SocialUser>(
              key: ValueKey((
                repository,
                widget.userId,
                widget.kind,
                _revision,
              )),
              load: (cursor) => repository.fetchConnections(
                widget.userId,
                widget.kind,
                cursor: cursor,
              ),
              itemId: (user) => user.userId,
              empty: Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: Text(followers ? '아직 팔로워가 없어요' : '아직 팔로잉이 없어요'),
                ),
              ),
              sliverBuilder: (users) => SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          followers ? 12 : 16,
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            openShellRoute(context, '/users/${user.userId}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ProfileAvatar(
                                url: user.imageUrl,
                                size: followers ? 40 : 48,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.nickname,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.postCount == null
                                          ? user.bio ?? '여행자'
                                          : '게시글 ${user.postCount}개',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FollowButton(
                                userId: user.userId,
                                initialFollowing: user.isFollowing,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

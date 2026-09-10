import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';

/// 통합 검색의 타입별 상위 묶음 (SCH-003).
class SearchSection extends StatelessWidget {
  const SearchSection({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: AppSpacing.lg),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      ...children,
    ],
  );
}

/// 검색어가 지역명이면 그 지역 피드로 넘어갈 수 있게 한다 (SCH-008).
class MatchedRegionCard extends StatelessWidget {
  const MatchedRegionCard({required this.region, super.key});

  final SearchedRegion region;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.brandSubtle,
    child: ListTile(
      leading: const Icon(Icons.map_outlined, color: AppColors.brand),
      title: Text('${region.name} 지역으로 보기'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/regions/${region.areaCode}'),
    ),
  );
}

class SearchPlaceRow extends StatelessWidget {
  const SearchPlaceRow({required this.place, super.key});

  final SearchedPlace place;

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
    subtitle: Text(
      [
        if (place.addr1 != null) place.addr1!,
        '사진 ${place.postCount}장',
      ].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    onTap: () => context.push('/places/${place.placeId}'),
  );
}

class SearchUserRow extends StatelessWidget {
  const SearchUserRow({required this.user, super.key});

  final SearchedUser user;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: ProfileAvatar(url: user.profileImageUrl, size: 44),
    title: Text(user.nickname, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: user.bio == null || user.bio!.isEmpty
        ? null
        : Text(user.bio!, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: () => context.push('/users/${user.userId}'),
  );
}

class SearchTagWrap extends StatelessWidget {
  const SearchTagWrap({required this.tags, super.key});

  final List<SearchedTag> tags;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final tag in tags)
        ActionChip(
          label: Text('#${tag.name}'),
          backgroundColor: AppColors.brandSubtle,
          side: BorderSide.none,
          onPressed: () => context.push('/tags/${tag.tagId}?name=${tag.name}'),
        ),
    ],
  );
}

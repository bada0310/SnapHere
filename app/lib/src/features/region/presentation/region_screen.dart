import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_post_card.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/region/application/region_providers.dart';

/// 시도별 사진 피드와 추천 관광지 (PLC-001~003, PST-004).
///
/// 지도·랭킹·검색의 지역 결과가 모두 이 화면으로 들어온다.
class RegionScreen extends ConsumerStatefulWidget {
  const RegionScreen({required this.areaCode, super.key});

  final int areaCode;

  @override
  ConsumerState<RegionScreen> createState() => _RegionScreenState();
}

class _RegionScreenState extends ConsumerState<RegionScreen> {
  @override
  void initState() {
    super.initState();
    // 다른 지역에서 넘어왔을 때 이전 시군구 선택이 남지 않게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(selectedSigunguProvider.notifier).select(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(regionsProvider);
    final name = regions.maybeWhen(
      data: (items) => items
          .where((region) => region.areaCode == widget.areaCode)
          .map((region) => region.name)
          .firstOrNull,
      orElse: () => null,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: const DesignBackButton(),
          title: Text(name ?? '지역'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '사진'),
              Tab(text: '관광지'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RegionPosts(areaCode: widget.areaCode),
            _RegionPlaces(areaCode: widget.areaCode),
          ],
        ),
      ),
    );
  }
}

class _RegionPosts extends ConsumerWidget {
  const _RegionPosts({required this.areaCode});

  final int areaCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(regionPostsProvider(areaCode));
    return posts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => NetworkErrorView(
        onRetry: () => ref.invalidate(regionPostsProvider(areaCode)),
      ),
      data: (items) => items.isEmpty
          ? EmptyStateView(
              title: '이 지역에 아직 사진이 없어요',
              description: '첫 사진을 올려 보세요',
              actionLabel: '사진 올리기',
              onAction: () => context.push('/upload'),
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(regionPostsProvider(areaCode)),
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

class _RegionPlaces extends ConsumerWidget {
  const _RegionPlaces({required this.areaCode});

  final int areaCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(regionPlacesProvider(areaCode));
    return Column(
      children: [
        _SigunguFilter(areaCode: areaCode),
        Expanded(
          child: places.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => NetworkErrorView(
              onRetry: () => ref.invalidate(regionPlacesProvider(areaCode)),
            ),
            data: (items) => items.isEmpty
                ? const EmptyStateView(
                    icon: Icons.place_outlined,
                    title: '조건에 맞는 관광지가 없어요',
                    description: '다른 시군구를 골라 보세요',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) => _PlaceRow(place: items[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// 시군구 필터 (API-PLC-002). 첫 칩은 시도 전체다.
class _SigunguFilter extends ConsumerWidget {
  const _SigunguFilter({required this.areaCode});

  final int areaCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sigungu = ref.watch(sigunguProvider(areaCode));
    final selected = ref.watch(selectedSigunguProvider);

    return sigungu.maybeWhen(
      data: (items) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            _FilterChip(
              label: '전체',
              selected: selected == null,
              onTap: () =>
                  ref.read(selectedSigunguProvider.notifier).select(null),
            ),
            for (final item in items)
              _FilterChip(
                label: item.name,
                selected: selected == item.sigunguCode,
                onTap: () => ref
                    .read(selectedSigunguProvider.notifier)
                    .select(item.sigunguCode),
              ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.sm),
    child: Center(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: AppColors.brand,
        backgroundColor: AppColors.card,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
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
        dimension: 48,
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
    trailing: const DesignIcon('chevron', size: 18),
    onTap: () => context.push('/places/${place.placeId}'),
  );
}

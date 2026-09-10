import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/place/application/place_providers.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/place/presentation/widgets/place_photo_grid.dart';

/// Figma `Wireframe_v3 / 07 Shared Detail / 07_장소_상세`.
class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({required this.placeId, super.key});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(placeDetailProvider(placeId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('장소'),
        actions: [
          place.maybeWhen(
            data: (detail) => _BookmarkButton(detail: detail),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: place.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => NetworkErrorView(
          onRetry: () => ref.invalidate(placeDetailProvider(placeId)),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(placeDetailProvider(placeId)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: RemoteImage(url: detail.place.imageUrl),
              ),
              _PlaceHeader(detail: detail),
              const SizedBox(height: AppSpacing.sm),
              PlacePhotoGrid(placeId: placeId),
              const SizedBox(height: AppSpacing.sm),
              _VisitorsSection(placeId: placeId),
              if (detail.nearbyPlaces.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _NearbySection(places: detail.nearbyPlaces),
              ],
              if (detail.overview != null && detail.overview!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _OverviewSection(detail: detail),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceHeader extends StatelessWidget {
  const _PlaceHeader({required this.detail});

  final PlaceDetail detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.place.title, style: text.headlineMedium),
          if (detail.place.addr1 != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(detail.place.addr1!, style: text.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          _StatsRow(detail: detail),
          if (detail.place.lat != null && detail.place.lng != null) ...[
            const SizedBox(height: AppSpacing.md),
            _MapLink(place: detail.place),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            // UploadScreen이 아직 placeId 프리필을 받지 않아 업로드 흐름의
            // GPS 장소 매칭에 맡긴다.
            onPressed: () => context.push('/upload'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('이 장소에 사진 올리기'),
          ),
        ],
      ),
    );
  }
}

/// 방문자 수와 지역·전국 랭킹 (VST-005, RNK-002).
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.detail});

  final PlaceDetail detail;

  @override
  Widget build(BuildContext context) {
    final ranking = detail.ranking;
    final items = <String>[
      '게시글 ${detail.place.postCount}개',
      '방문자 ${detail.place.visitCount}명',
      if (ranking != null && ranking.rank > 0) '랭킹 ${ranking.rank}위',
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0)
            Text('·', style: Theme.of(context).textTheme.bodySmall),
          Text(items[index], style: Theme.of(context).textTheme.bodySmall),
        ],
        if (ranking?.change != null && ranking!.change != 0)
          _RankingChange(change: ranking.change!),
      ],
    );
  }
}

/// 순위 변동 표시 (RNK-009). 신규 진입이면 이전 순위가 없어 아무것도 그리지 않는다.
class _RankingChange extends StatelessWidget {
  const _RankingChange({required this.change});

  final int change;

  @override
  Widget build(BuildContext context) {
    final rose = change > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          rose ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: 16,
          color: rose ? AppColors.brand : AppColors.textSecondary,
        ),
        Text('${change.abs()}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MapLink extends StatelessWidget {
  const _MapLink({required this.place});

  final PlaceSummary place;

  @override
  Widget build(BuildContext context) => GestureDetector(
    // MapScreen이 좌표 파라미터를 아직 받지 않는다.
    onTap: () => context.push('/map'),
    behavior: HitTestBehavior.opaque,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.place_outlined, size: 16, color: AppColors.brand),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '지도에서 보기',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.brand),
        ),
      ],
    ),
  );
}

/// 주변 장소를 거리순으로 (MAP-026).
class _NearbySection extends StatelessWidget {
  const _NearbySection({required this.places});

  final List<PlaceSummary> places;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.card,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text('주변 장소', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final place in places)
          ListTile(
            dense: true,
            title: Text(place.title),
            subtitle: place.distanceM == null
                ? null
                : Text('${place.distanceM}m'),
            trailing: const DesignIcon('chevron', size: 18),
            onTap: () => context.push('/places/${place.placeId}'),
          ),
      ],
    ),
  );
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.detail});

  final PlaceDetail detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('관광 정보', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(detail.overview!, style: text.bodyMedium),
          if (detail.tel != null && detail.tel!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('문의 ${detail.tel}', style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _BookmarkButton extends ConsumerStatefulWidget {
  const _BookmarkButton({required this.detail});

  final PlaceDetail detail;

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton> {
  late bool _saved = widget.detail.place.isBookmarked ?? false;
  var _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final previous = _saved;
    setState(() {
      _busy = true;
      _saved = !_saved;
    });
    try {
      final result = await ref
          .read(placeRepositoryProvider)
          .setBookmarked(widget.detail.place.placeId, _saved);
      if (mounted) setState(() => _saved = result);
    } on PlaceFailure catch (error) {
      if (!mounted) return;
      setState(() => _saved = previous);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _saved ? '저장 해제' : '저장',
    onPressed: _toggle,
    icon: Icon(
      _saved ? Icons.bookmark : Icons.bookmark_border,
      color: _saved ? AppColors.brand : AppColors.textSecondary,
    ),
  );
}

/// 이 장소를 다녀간 사람 (VST-004, VST-005).
class _VisitorsSection extends ConsumerWidget {
  const _VisitorsSection({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitors = ref.watch(placeVisitorsProvider(placeId));
    return visitors.maybeWhen(
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Container(
              color: AppColors.card,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '다녀간 사람',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, index) =>
                          _VisitorAvatar(visitor: items[index]),
                    ),
                  ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _VisitorAvatar extends StatelessWidget {
  const _VisitorAvatar({required this.visitor});

  final PlaceVisitor visitor;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/users/${visitor.userId}'),
    child: SizedBox(
      width: 56,
      child: Column(
        children: [
          ProfileAvatar(url: visitor.profileImageUrl, size: 44),
          const SizedBox(height: AppSpacing.xs),
          Text(
            visitor.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

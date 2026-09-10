import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/rankings/application/ranking_providers.dart';
import 'package:snap_here/src/features/rankings/domain/ranking_models.dart';

/// 장소 랭킹 (RNK-001~013).
///
/// 순위는 서버가 사전 집계해 결정적으로 정렬해 준다. 앱은 다시 정렬하지 않는다 (RNK-007).
class RankingsScreen extends ConsumerWidget {
  const RankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankings = ref.watch(placeRankingsProvider);
    final filter = ref.watch(rankingFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('랭킹'),
      ),
      body: Column(
        children: [
          _PeriodFilter(selected: filter.period),
          Expanded(
            child: rankings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => NetworkErrorView(
                onRetry: () => ref.invalidate(placeRankingsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.emoji_events_outlined,
                      title: '아직 랭킹이 없어요',
                      description: '사진이 쌓이면 순위가 만들어져요',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(placeRankingsProvider),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                        children: [
                          for (final entry in items) _RankingRow(entry: entry),
                          const _RecommendationSection(),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodFilter extends ConsumerWidget {
  const _PeriodFilter({required this.selected});

  final RankingPeriod selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        for (final period in RankingPeriod.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: ChoiceChip(
                label: Text(period.label),
                selected: period == selected,
                showCheckmark: false,
                selectedColor: AppColors.brand,
                backgroundColor: AppColors.card,
                side: const BorderSide(color: AppColors.border),
                onSelected: (_) => ref
                    .read(rankingFilterProvider.notifier)
                    .selectPeriod(period),
              ),
            ),
          ),
      ],
    ),
  );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry});

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.card,
      child: InkWell(
        onTap: () => context.push('/places/${entry.place.placeId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: entry.rank <= 3
                        ? AppColors.brand
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RankChange(entry: entry),
              const SizedBox(width: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox.square(
                  dimension: 48,
                  child: RemoteImage(url: entry.place.imageUrl),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.place.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge,
                    ),
                    Text(
                      '사진 ${entry.place.postCount}장 · 방문 ${entry.place.visitCount}명',
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

/// 순위 변동 (RNK-009). 신규 진입은 화살표 대신 `NEW`로 구분한다 (RNK-010).
class _RankChange extends StatelessWidget {
  const _RankChange({required this.entry});

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (entry.isNew) {
      return Text('NEW', style: style?.copyWith(color: AppColors.brand));
    }
    final change = entry.change ?? 0;
    if (change == 0) {
      return Text('–', style: style);
    }
    final rose = change > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          rose ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: 16,
          color: rose ? AppColors.brand : AppColors.textSecondary,
        ),
        Text('${change.abs()}', style: style),
      ],
    );
  }
}

/// 추천 장소 (RNK-011~013). 데이터가 부족하면 서버가 대체 목록을 준다.
class _RecommendationSection extends ConsumerWidget {
  const _RecommendationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(placeRecommendationsProvider);
    return recommendations.maybeWhen(
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(top: AppSpacing.lg),
              color: AppColors.card,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '지금 가 볼 만한 곳',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox.square(
                          dimension: 44,
                          child: RemoteImage(url: item.place.imageUrl),
                        ),
                      ),
                      title: Text(
                        item.place.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(item.reasonLabel),
                      onTap: () =>
                          context.push('/places/${item.place.placeId}'),
                    ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

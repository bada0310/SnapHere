import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/rankings/data/api_ranking_repository.dart';
import 'package:snap_here/src/features/rankings/domain/ranking_models.dart';

final rankingRepositoryProvider = Provider<ApiRankingRepository>(
  (ref) => ApiRankingRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  ),
);

/// 랭킹 화면의 기간·범위 선택.
@immutable
class RankingFilter {
  const RankingFilter({
    this.scope = RankingScope.national,
    this.period = RankingPeriod.weekly,
    this.areaCode,
  });

  final RankingScope scope;
  final RankingPeriod period;
  final int? areaCode;

  RankingFilter copyWith({
    RankingScope? scope,
    RankingPeriod? period,
    int? areaCode,
    bool clearArea = false,
  }) => RankingFilter(
    scope: scope ?? this.scope,
    period: period ?? this.period,
    areaCode: clearArea ? null : areaCode ?? this.areaCode,
  );
}

class RankingFilterNotifier extends Notifier<RankingFilter> {
  @override
  RankingFilter build() => const RankingFilter();

  void selectPeriod(RankingPeriod period) =>
      state = state.copyWith(period: period);

  /// 전국으로 돌아가면 지역 코드도 함께 비운다.
  void selectScope(RankingScope scope, {int? areaCode}) =>
      state = state.copyWith(
        scope: scope,
        areaCode: areaCode,
        clearArea: scope == RankingScope.national,
      );
}

final rankingFilterProvider =
    NotifierProvider<RankingFilterNotifier, RankingFilter>(
      RankingFilterNotifier.new,
    );

final placeRankingsProvider = FutureProvider<List<RankingEntry>>((ref) {
  final filter = ref.watch(rankingFilterProvider);
  return ref
      .watch(rankingRepositoryProvider)
      .fetchPlaceRankings(
        scope: filter.scope,
        period: filter.period,
        areaCode: filter.areaCode,
      );
});

final placeRecommendationsProvider = FutureProvider<List<PlaceRecommendation>>((
  ref,
) {
  final filter = ref.watch(rankingFilterProvider);
  return ref
      .watch(rankingRepositoryProvider)
      .fetchRecommendations(areaCode: filter.areaCode);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/region/data/api_region_repository.dart';
import 'package:snap_here/src/features/region/domain/region_models.dart';

final regionRepositoryProvider = Provider<ApiRegionRepository>(
  (ref) => ApiRegionRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  ),
);

final regionsProvider = FutureProvider<List<Region>>(
  (ref) => ref.watch(regionRepositoryProvider).fetchRegions(),
);

final sigunguProvider = FutureProvider.family<List<Sigungu>, int>(
  (ref, areaCode) => ref.watch(regionRepositoryProvider).fetchSigungu(areaCode),
);

/// 지역 화면에서 고른 시군구. null이면 시도 전체다.
final selectedSigunguProvider = NotifierProvider<SelectedSigunguNotifier, int?>(
  SelectedSigunguNotifier.new,
);

class SelectedSigunguNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? sigunguCode) => state = sigunguCode;
}

final regionPlacesProvider = FutureProvider.family<List<PlaceSummary>, int>((
  ref,
  areaCode,
) async {
  final page = await ref
      .watch(regionRepositoryProvider)
      .fetchPlaces(
        areaCode: areaCode,
        sigunguCode: ref.watch(selectedSigunguProvider),
      );
  return page.items;
});

final regionPostsProvider = FutureProvider.family<List<CommunityPost>, int>((
  ref,
  areaCode,
) async {
  final page = await ref
      .watch(regionRepositoryProvider)
      .fetchPosts(areaCode: areaCode);
  return page.items;
});

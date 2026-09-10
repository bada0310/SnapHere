import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/place/data/api_place_repository.dart';
import 'package:snap_here/src/features/place/data/fake_place_repository.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/place/domain/place_repository.dart';

const _useFakePlaces = bool.fromEnvironment(
  'USE_FAKE_PLACES',
  defaultValue: false,
);

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  if (_useFakePlaces) return FakePlaceRepository();
  return ApiPlaceRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  );
});

final placeDetailProvider = FutureProvider.family<PlaceDetail, String>(
  (ref, placeId) => ref.watch(placeRepositoryProvider).fetchPlace(placeId),
);

final placePostsProvider = FutureProvider.family<List<PlacePost>, String>((
  ref,
  placeId,
) async {
  final page = await ref
      .watch(placeRepositoryProvider)
      .fetchPlacePosts(placeId);
  return page.items;
});

final placeVisitorsProvider = FutureProvider.family<List<PlaceVisitor>, String>(
  (ref, placeId) => ref.watch(placeRepositoryProvider).fetchVisitors(placeId),
);

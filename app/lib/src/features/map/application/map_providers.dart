import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/map/data/api_map_repository.dart';
import 'package:snap_here/src/features/map/domain/map_models.dart';

final mapRepositoryProvider = Provider<ApiMapRepository>(
  (ref) => ApiMapRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  ),
);

/// 지금 화면에 보이는 범위. 카메라가 멈출 때만 갱신한다.
final mapViewportProvider = NotifierProvider<MapViewportNotifier, MapViewport?>(
  MapViewportNotifier.new,
);

class MapViewportNotifier extends Notifier<MapViewport?> {
  @override
  MapViewport? build() => null;

  void update(MapViewport viewport) {
    if (state != viewport) state = viewport;
  }
}

final heatmapProvider = FutureProvider<HeatmapResult?>((ref) async {
  final viewport = ref.watch(mapViewportProvider);
  if (viewport == null) return null;
  return ref.watch(mapRepositoryProvider).fetchHeatmap(viewport);
});

final photoMarkersProvider = FutureProvider<List<PhotoMarker>>((ref) async {
  final viewport = ref.watch(mapViewportProvider);
  if (viewport == null) return const [];
  return ref.watch(mapRepositoryProvider).fetchPhotoMarkers(viewport);
});

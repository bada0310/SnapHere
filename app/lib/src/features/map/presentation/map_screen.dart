import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/map/application/map_providers.dart';
import 'package:snap_here/src/features/map/domain/map_models.dart';
import 'package:snap_here/src/features/map/presentation/snap_map.dart';

/// 지도 탐색 (MAP-002~004, MAP-009~014).
///
/// 카메라가 멈출 때마다 보이는 사각형과 줌을 서버에 넘기고, 서버가 격자로 묶어
/// 돌려준 셀을 마커로 그린다. 격자 계산을 앱에서 하지 않는 이유는 줌 구간별
/// 셀 크기를 서버가 정하기 때문이다 (결정 DEC-20260905-004).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _controller;
  var _zoom = koreaCamera.zoom;

  Future<void> _syncViewport() async {
    final controller = _controller;
    if (controller == null) return;
    final region = await controller.getVisibleRegion();
    if (!mounted) return;
    ref
        .read(mapViewportProvider.notifier)
        .update(
          MapViewport(
            west: region.southwest.longitude,
            south: region.southwest.latitude,
            east: region.northeast.longitude,
            north: region.northeast.latitude,
            zoom: _zoom.round(),
          ),
        );
  }

  Future<void> _openCell(String cellKey) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final detail = await ref
          .read(mapRepositoryProvider)
          .fetchCellDetail(cellKey);
      if (!mounted) return;
      if (detail.postIds.isNotEmpty) {
        context.push('/photos/${detail.postIds.first}');
      } else if (detail.placeId != null) {
        context.push('/places/${detail.placeId}');
      }
    } on MapFailure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Set<Marker> _markers(HeatmapResult? heatmap, List<PhotoMarker> photos) {
    final markers = <Marker>{};
    for (final cell in heatmap?.cells ?? const <HeatmapCell>[]) {
      markers.add(
        Marker(
          markerId: MarkerId('cell_${cell.cellKey}'),
          position: LatLng(cell.lat, cell.lng),
          infoWindow: InfoWindow(title: '사진 ${cell.postCount}장'),
          onTap: () => _openCell(cell.cellKey),
        ),
      );
    }
    for (final photo in photos) {
      if (photo.postId == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('photo_${photo.cellKey}'),
          position: LatLng(photo.lat, photo.lng),
          onTap: () => context.push('/photos/${photo.postId}'),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final heatmap = ref.watch(heatmapProvider);
    final photos = ref.watch(photoMarkersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('지도 탐색'),
      ),
      body: Stack(
        children: [
          SnapMap(
            markers: _markers(heatmap.value, photos.value ?? const []),
            onCreated: (controller) {
              _controller = controller;
              _syncViewport();
            },
            onCameraMove: (position) => _zoom = position.zoom,
            onCameraIdle: _syncViewport,
          ),
          if (heatmap.isLoading)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (heatmap.hasError)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: LoadErrorView(
                      title: '지도를 불러올 수 없어요',
                      onRetry: () => ref.invalidate(heatmapProvider),
                    ),
                  ),
                ),
              ),
            ),
          if (heatmap.value?.fallbackApplied ?? false)
            const _MapNotice(text: '최근 1시간 사진이 적어 24시간 기준으로 보여드려요'),
        ],
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/paged_sliver.dart';
import 'package:snap_here/src/features/explore/application/explore_providers.dart';
import 'package:snap_here/src/features/explore/domain/explore_models.dart';
import 'package:snap_here/src/features/home/presentation/region_posts_sheet.dart';
import 'package:snap_here/src/features/map/application/map_providers.dart';
import 'package:snap_here/src/features/map/domain/map_models.dart';
import 'package:snap_here/src/features/map/presentation/photo_marker_layer.dart';
import 'package:snap_here/src/features/map/presentation/snap_map.dart';

/// Figma 92:312 / 92:380 / 92:446 / 92:561.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _map;
  final _sheet = DraggableScrollableController();
  int? _areaCode;
  double _extent = .58;
  MapViewport? _viewport;
  double _zoom = koreaCamera.zoom;
  int _viewportGeneration = 0;
  bool _mapActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_mapActive && _viewport != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapActive) return;
        ref.invalidate(viewportPhotoMarkersProvider(_viewport!));
        ref.invalidate(mapRegionsProvider);
      });
    }
    _mapActive = active;
  }

  Future<void> _syncViewport() async {
    final map = _map;
    if (map == null) return;
    final generation = ++_viewportGeneration;
    try {
      final region = await map.getVisibleRegion();
      if (!mounted || generation != _viewportGeneration) return;
      final viewport = MapViewport(
        west: region.southwest.longitude,
        south: region.southwest.latitude,
        east: region.northeast.longitude,
        north: region.northeast.latitude,
        zoom: _zoom.floor(),
      );
      // 플랫폼 지도 생성 직후에는 아직 유효한 범위가 없을 수 있다.
      if (viewport.west >= viewport.east || viewport.south >= viewport.north) {
        return;
      }
      if (_viewport != viewport) setState(() => _viewport = viewport);
    } on Object {
      // 다음 카메라 idle에서 다시 동기화한다.
    }
  }

  void _cameraMoved(CameraPosition position) {
    _viewportGeneration++;
    _zoom = position.zoom;
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _select(RegionOverview region) async {
    setState(() {
      _areaCode = region.areaCode;
      _extent = .58;
    });
    // 같은 지역을 다시 선택해도 실제 시트 높이와 지도 padding을 맞춘다.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _areaCode != region.areaCode) return;
    if (_sheet.isAttached && (_sheet.size - .58).abs() > .01) {
      await _sheet.animateTo(
        .58,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (!mounted || _areaCode != region.areaCode) return;
    if (region.latitude != null && region.longitude != null) {
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(region.latitude!, region.longitude!),
          8.5,
        ),
      );
    }
  }

  Future<void> _chooseRegion(List<RegionOverview> regions) async {
    final selected = await showModalBottomSheet<RegionOverview>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: ListView(
            children: [
              const ListTile(
                title: Text(
                  '지역 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              for (final region in regions)
                ListTile(
                  title: Text(region.name),
                  trailing: Text('${region.postCount}개'),
                  selected: region.areaCode == _areaCode,
                  onTap: () => Navigator.pop(context, region),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) _select(selected);
  }

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(mapRegionsProvider);
    final photos = _viewport == null
        ? const AsyncData<List<PhotoMarker>>([])
        : ref.watch(viewportPhotoMarkersProvider(_viewport!));
    final items = regions.value ?? const <RegionOverview>[];
    final selected = items
        .where((region) => region.areaCode == _areaCode)
        .firstOrNull;
    final expanded = selected != null && _extent > .82;

    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _areaCode != null) setState(() => _areaCode = null);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: PhotoMarkerLayer(
                    photos: photos.value ?? const [],
                    builder: (photoMarkers) => SnapMap(
                      markers: photoMarkers,
                      onCreated: (controller) {
                        _map = controller;
                        _syncViewport();
                      },
                      onCameraMove: _cameraMoved,
                      onCameraIdle: _syncViewport,
                      onTap: (_) {
                        if (selected != null) setState(() => _areaCode = null);
                      },
                      padding: EdgeInsets.only(
                        top: expanded ? 0 : 60,
                        bottom: selected == null
                            ? 0
                            : constraints.maxHeight * _extent,
                      ),
                    ),
                  ),
                ),
                if (!expanded)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Material(
                      color: Colors.white,
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Text(
                              'SnapHere',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.surface,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(0, 30),
                                ),
                                onPressed: () => _chooseRegion(items),
                                child: Text(
                                  '📍 ${selected?.name ?? '지역 선택'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '알림',
                              onPressed: () => context.push('/notifications'),
                              icon: const DesignIcon('bell', size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (regions.isLoading || photos.isLoading)
                  const Positioned(
                    top: 52,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(),
                  ),
                if (regions.hasError || photos.hasError)
                  Positioned(
                    top: 64,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: RetryMessage(
                          message: regions.hasError
                              ? '지역 데이터를 불러오지 못했어요'
                              : '지도 사진을 불러오지 못했어요',
                          onRetry: () {
                            ref.invalidate(mapRegionsProvider);
                            if (_viewport != null) {
                              ref.invalidate(
                                viewportPhotoMarkersProvider(_viewport!),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                if (regions.hasValue && items.isEmpty)
                  const Positioned(
                    top: 64,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('등록된 지역이 없어요.'),
                      ),
                    ),
                  ),
                if (selected != null && !expanded)
                  Positioned(
                    top: 68,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${selected.name} 선택 · 게시글 ${selected.postCount}개',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (selected == null)
                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: FloatingActionButton.small(
                      heroTag: 'regions',
                      tooltip: '지역 목록',
                      onPressed: () => _chooseRegion(items),
                      child: const Icon(Icons.list),
                    ),
                  ),
                if (selected != null)
                  NotificationListener<DraggableScrollableNotification>(
                    onNotification: (notification) {
                      if ((notification.extent - _extent).abs() > .003) {
                        setState(() => _extent = notification.extent);
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                      controller: _sheet,
                      initialChildSize: .58,
                      minChildSize: .25,
                      maxChildSize: .90,
                      snap: true,
                      snapSizes: const [.58],
                      builder: (_, controller) => RegionPostsSheet(
                        region: selected,
                        scrollController: controller,
                        onClose: () => setState(() => _areaCode = null),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

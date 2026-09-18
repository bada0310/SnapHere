import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/features/map/domain/map_models.dart';
import 'package:snap_here/src/features/map/presentation/photo_marker.dart';

/// API 후보 배열을 로컬에서 교체한다. 사진 교체는 API 조회를 발생시키지 않는다.
class PhotoMarkerLayer extends ConsumerStatefulWidget {
  const PhotoMarkerLayer({
    required this.photos,
    required this.zoom,
    required this.builder,
    super.key,
  });

  final List<PhotoMarker> photos;
  final int zoom;
  final Widget Function(Set<Marker> markers) builder;

  @override
  ConsumerState<PhotoMarkerLayer> createState() => _PhotoMarkerLayerState();
}

class _PhotoMarkerLayerState extends ConsumerState<PhotoMarkerLayer> {
  Timer? _rotation;
  int _elapsedMs = 0;
  bool _active = true;
  final _displayed =
      <String, ({PhotoMarkerCandidate candidate, BitmapDescriptor icon})>{};

  void _syncRotation() {
    final rotating =
        _active &&
        widget.zoom < 14 &&
        widget.photos.any((photo) => photo.candidates.length > 1);
    if (rotating && _rotation == null) {
      _rotation = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) setState(() => _elapsedMs += 3000);
      });
    } else if (!rotating) {
      _rotation?.cancel();
      _rotation = null;
      _elapsedMs = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    _syncRotation();
  }

  @override
  void didUpdateWidget(PhotoMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRotation();
  }

  @override
  void dispose() {
    _rotation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    _displayed.removeWhere(
      (key, _) => !widget.photos.any((photo) => photo.cellKey == key),
    );
    for (final photo in widget.photos) {
      if (photo.candidates.isEmpty) continue;
      final interval = photo.rotationIntervalMs > 0
          ? photo.rotationIntervalMs
          : 3000;
      final index = widget.zoom >= 14
          ? 0
          : (_elapsedMs ~/ interval) % photo.candidates.length;
      final candidate = photo.candidates[index];
      final icon = ref
          .watch(photoMarkerIconProvider(candidate.thumbnailUrl))
          .value;
      if (widget.zoom < 14 && photo.candidates.length > 1) {
        final next = photo.candidates[(index + 1) % photo.candidates.length];
        ref.watch(photoMarkerIconProvider(next.thumbnailUrl));
      }
      if (icon != null) {
        _displayed[photo.cellKey] = (candidate: candidate, icon: icon);
      }
      final displayed = _displayed[photo.cellKey];
      if (displayed == null ||
          !photo.candidates.any(
            (item) =>
                item.postId == displayed.candidate.postId &&
                item.thumbnailUrl == displayed.candidate.thumbnailUrl,
          )) {
        continue;
      }
      markers.add(
        Marker(
          markerId: MarkerId('photo_${photo.cellKey}'),
          position: LatLng(photo.lat, photo.lng),
          icon: displayed.icon,
          anchor: const Offset(.5, 1),
          zIndexInt: 2,
          consumeTapEvents: true,
          onTap: () => context.push('/photos/${displayed.candidate.postId}'),
        ),
      );
    }
    return widget.builder(markers);
  }
}

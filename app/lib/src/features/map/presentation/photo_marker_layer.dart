import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/features/map/domain/map_models.dart';
import 'package:snap_here/src/features/map/presentation/photo_marker.dart';

/// 각 집계 셀의 최상위 대표 사진 한 장만 고정 표시한다.
class PhotoMarkerLayer extends ConsumerWidget {
  const PhotoMarkerLayer({
    required this.photos,
    required this.builder,
    super.key,
  });

  final List<PhotoMarker> photos;
  final Widget Function(Set<Marker> markers) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markers = <Marker>{};
    for (final photo in photos) {
      final candidate = photo.candidates.firstOrNull;
      if (candidate == null) continue;
      final icon = ref
          .watch(
            photoMarkerIconProvider((
              url: candidate.thumbnailUrl,
              count: photo.postCount,
              countIsLowerBound: photo.postCountIsLowerBound,
            )),
          )
          .value;
      if (icon == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('photo_${photo.cellKey}'),
          position: LatLng(photo.lat, photo.lng),
          icon: icon,
          anchor: const Offset(.5, .5),
          zIndexInt: 2,
          consumeTapEvents: true,
          onTap: () => context.push('/photos/${candidate.postId}'),
        ),
      );
    }
    return builder(markers);
  }
}

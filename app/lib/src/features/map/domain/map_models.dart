import 'package:flutter/foundation.dart';

/// 히트맵 조회 범위. 서버는 화면에 보이는 사각형과 줌만 받는다 (MAP-009~014).
@immutable
class MapViewport {
  const MapViewport({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    required this.zoom,
  });

  final double west;
  final double south;
  final double east;
  final double north;
  final int zoom;

  Map<String, String> toQuery() => {
    'west': '$west',
    'south': '$south',
    'east': '$east',
    'north': '$north',
    'zoom': '$zoom',
  };

  @override
  bool operator ==(Object other) =>
      other is MapViewport &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(west, south, east, north, zoom);
}

@immutable
class HeatmapCell {
  const HeatmapCell({
    required this.cellKey,
    required this.lat,
    required this.lng,
    required this.postCount,
    this.intensity = 0,
    this.visitCount = 0,
  });

  factory HeatmapCell.fromJson(Map<String, Object?> json) => HeatmapCell(
    cellKey: json['cellKey'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0,
    postCount: (json['postCount'] as num?)?.toInt() ?? 0,
    intensity: (json['intensity'] as num?)?.toDouble() ?? 0,
    visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
  );

  final String cellKey;
  final double lat;
  final double lng;
  final int postCount;
  final double intensity;
  final int visitCount;
}

@immutable
class HeatmapResult {
  const HeatmapResult({
    required this.cells,
    this.maxCount = 0,
    this.fallbackApplied = false,
    this.truncated = false,
  });

  factory HeatmapResult.fromJson(Map<String, Object?> json) => HeatmapResult(
    cells: ((json['cells'] as List?) ?? const [])
        .map(
          (item) =>
              HeatmapCell.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false),
    maxCount: (json['maxCount'] as num?)?.toInt() ?? 0,
    fallbackApplied: json['fallbackApplied'] as bool? ?? false,
    truncated: json['truncated'] as bool? ?? false,
  );

  final List<HeatmapCell> cells;
  final int maxCount;

  /// 최근 1시간 글이 적어 24시간으로 넓혀 준 경우다 (결정 DEC-20260905-004).
  final bool fallbackApplied;

  /// 셀이 500개를 넘어 상위만 돌려준 경우다.
  final bool truncated;
}

@immutable
class PhotoMarkerCandidate {
  const PhotoMarkerCandidate({
    required this.postId,
    required this.thumbnailUrl,
    this.lat,
    this.lng,
  });

  final String postId;
  final String thumbnailUrl;
  final double? lat;
  final double? lng;
}

/// 셀 위에 얹는 대표 사진과 로컬 교체 후보 (MAP-020~023).
@immutable
class PhotoMarker {
  const PhotoMarker({
    required this.cellKey,
    required this.lat,
    required this.lng,
    this.postCount = 1,
    this.postCountIsLowerBound = false,
    this.candidates = const [],
  });

  factory PhotoMarker.fromJson(Map<String, Object?> json) {
    final rawCandidates = (json['candidates'] as List?) ?? const [];
    final parsedCandidates = rawCandidates
        .whereType<Map>()
        .map((item) {
          final data = Map<String, Object?>.from(item);
          final place = data['place'] is Map
              ? Map<String, Object?>.from(data['place'] as Map)
              : const <String, Object?>{};
          return PhotoMarkerCandidate(
            postId: data['postId'] as String? ?? '',
            thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
            lat: (place['lat'] as num?)?.toDouble(),
            lng: (place['lng'] as num?)?.toDouble(),
          );
        })
        .where((item) => item.postId.isNotEmpty && item.thumbnailUrl.isNotEmpty)
        .toList(growable: false);
    final representative = parsedCandidates.firstOrNull;
    final exactPostCount = (json['postCount'] as num?)?.toInt();
    final legacyResponse = exactPostCount == null;
    final fallbackCount = parsedCandidates.isEmpty
        ? 1
        : parsedCandidates.length;
    return PhotoMarker(
      cellKey: json['cellKey'] as String? ?? '',
      lat: legacyResponse && representative?.lat != null
          ? representative!.lat!
          : (json['lat'] as num?)?.toDouble() ?? 0,
      lng: legacyResponse && representative?.lng != null
          ? representative!.lng!
          : (json['lng'] as num?)?.toDouble() ?? 0,
      postCount: exactPostCount ?? fallbackCount,
      postCountIsLowerBound: legacyResponse && parsedCandidates.length >= 10,
      candidates: List.unmodifiable(parsedCandidates.take(1)),
    );
  }

  final String cellKey;
  final double lat;
  final double lng;
  final int postCount;
  final bool postCountIsLowerBound;
  final List<PhotoMarkerCandidate> candidates;
}

class MapFailure implements Exception {
  const MapFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

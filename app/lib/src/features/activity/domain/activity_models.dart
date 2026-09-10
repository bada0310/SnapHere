import 'package:flutter/foundation.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';

/// 저장함이 담는 대상 (API-USER-007). 서버 `BookmarkTargetType`과 값이 같아야 한다.
enum BookmarkTarget {
  post('POST', '사진'),
  place('PLACE', '장소');

  const BookmarkTarget(this.code, this.label);

  final String code;
  final String label;
}

/// 방문 한 건 (API-VST-001).
@immutable
class Visit {
  const Visit({
    required this.visitId,
    required this.place,
    this.postId,
    this.visitedOn,
  });

  factory Visit.fromJson(Map<String, Object?> json) => Visit(
    visitId: json['visitId']! as String,
    place: PlaceSummary.fromJson(
      Map<String, Object?>.from(json['place']! as Map),
    ),
    postId: json['postId'] as String?,
    visitedOn: DateTime.tryParse(json['visitedOn'] as String? ?? ''),
  );

  final String visitId;
  final PlaceSummary place;
  final String? postId;
  final DateTime? visitedOn;
}

/// 시도별 방문 집계 (API-VST-002).
@immutable
class VisitRegionStat {
  const VisitRegionStat({
    required this.regionName,
    required this.areaCode,
    required this.visitCount,
    required this.placeCount,
  });

  factory VisitRegionStat.fromJson(Map<String, Object?> json) {
    final region = Map<String, Object?>.from(json['region']! as Map);
    return VisitRegionStat(
      regionName: region['nameKo'] as String? ?? '지역',
      areaCode: (region['areaCode'] as num?)?.toInt() ?? 0,
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
      placeCount: (json['placeCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String regionName;
  final int areaCode;
  final int visitCount;
  final int placeCount;
}

@immutable
class VisitStats {
  const VisitStats({
    required this.visitedRegionCount,
    required this.totalRegionCount,
    required this.progress,
    this.regions = const [],
  });

  factory VisitStats.fromJson(Map<String, Object?> json) => VisitStats(
    visitedRegionCount: (json['visitedRegionCount'] as num?)?.toInt() ?? 0,
    totalRegionCount: (json['totalRegionCount'] as num?)?.toInt() ?? 17,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    regions: ((json['regions'] as List?) ?? const [])
        .map(
          (item) =>
              VisitRegionStat.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false),
  );

  final int visitedRegionCount;
  final int totalRegionCount;
  final double progress;
  final List<VisitRegionStat> regions;
}

/// 계정 삭제 시 사라지는 것들 (API-USER-008).
@immutable
class DeletionPreview {
  const DeletionPreview({
    required this.postCount,
    required this.commentCount,
    required this.followerCount,
    required this.badgeCount,
    required this.gracePeriodDays,
  });

  factory DeletionPreview.fromJson(Map<String, Object?> json) =>
      DeletionPreview(
        postCount: (json['postCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
        badgeCount: (json['badgeCount'] as num?)?.toInt() ?? 0,
        gracePeriodDays: (json['gracePeriodDays'] as num?)?.toInt() ?? 30,
      );

  final int postCount;
  final int commentCount;
  final int followerCount;
  final int badgeCount;
  final int gracePeriodDays;
}

class ActivityFailure implements Exception {
  const ActivityFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

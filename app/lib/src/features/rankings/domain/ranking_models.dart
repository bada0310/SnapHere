import 'package:flutter/foundation.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';

/// 랭킹 기간 (RNK-004). 서버 `RankingPeriod`와 값이 같아야 한다.
enum RankingPeriod {
  daily('DAILY', '오늘'),
  weekly('WEEKLY', '이번 주'),
  monthly('MONTHLY', '이번 달'),
  all('ALL', '전체');

  const RankingPeriod(this.code, this.label);

  final String code;
  final String label;
}

/// 전국·지역 (RNK-002, RNK-003).
enum RankingScope {
  national('NATIONAL', '전국'),
  region('REGION', '지역');

  const RankingScope(this.code, this.label);

  final String code;
  final String label;
}

@immutable
class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.place,
    this.previousRank,
    this.change,
    this.period,
    this.theme,
  });

  factory RankingEntry.fromJson(Map<String, Object?> json) => RankingEntry(
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    place: PlaceSummary.fromJson(
      Map<String, Object?>.from(json['place']! as Map),
    ),
    previousRank: (json['previousRank'] as num?)?.toInt(),
    change: (json['change'] as num?)?.toInt(),
    period: json['period'] as String?,
    theme: json['theme'] as String?,
  );

  final int rank;
  final PlaceSummary place;
  final int? previousRank;

  /// 서버가 계산해 준다. 양수면 순위가 올랐다는 뜻이다 (RNK-009).
  final int? change;
  final String? period;
  final String? theme;

  /// 이전 순위가 없으면 이번에 처음 들어온 장소다 (RNK-010).
  bool get isNew => previousRank == null;
}

/// 추천 장소와 그 사유 코드 (RNK-011, RNK-012).
@immutable
class PlaceRecommendation {
  const PlaceRecommendation({
    required this.place,
    required this.reasonCode,
    this.reasonParams = const {},
  });

  factory PlaceRecommendation.fromJson(Map<String, Object?> json) =>
      PlaceRecommendation(
        place: PlaceSummary.fromJson(
          Map<String, Object?>.from(json['place']! as Map),
        ),
        reasonCode: json['reasonCode'] as String? ?? '',
        reasonParams: Map<String, Object?>.from(
          (json['reasonParams'] as Map?) ?? const {},
        ),
      );

  final PlaceSummary place;
  final String reasonCode;
  final Map<String, Object?> reasonParams;

  /// 서버는 코드만 준다. 문장은 앱이 만든다 (SYS-010).
  String get reasonLabel => switch (reasonCode) {
    'TRENDING' => '요즘 뜨는 곳',
    'NEARBY' => '가까운 곳',
    'SEASONAL' => '지금 계절에 좋은 곳',
    'POPULAR_IN_REGION' => '이 지역 인기',
    'CURATED' => '에디터 추천',
    _ => '추천',
  };
}

class RankingFailure implements Exception {
  const RankingFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

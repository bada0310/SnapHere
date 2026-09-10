import 'package:flutter/foundation.dart';

@immutable
class PlaceSummary {
  const PlaceSummary({
    required this.placeId,
    required this.title,
    this.addr1,
    this.imageUrl,
    this.lat,
    this.lng,
    this.postCount = 0,
    this.visitCount = 0,
    this.distanceM,
    this.isBookmarked,
  });

  factory PlaceSummary.fromJson(Map<String, Object?> json) => PlaceSummary(
    placeId: json['placeId']! as String,
    title: json['title'] as String? ?? '장소',
    addr1: json['addr1'] as String?,
    imageUrl: json['imageUrl'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    postCount: (json['postCount'] as num?)?.toInt() ?? 0,
    visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
    distanceM: (json['distanceM'] as num?)?.toInt(),
    isBookmarked: json['isBookmarked'] as bool?,
  );

  final String placeId;
  final String title;
  final String? addr1;
  final String? imageUrl;
  final double? lat;
  final double? lng;
  final int postCount;
  final int visitCount;
  final int? distanceM;
  final bool? isBookmarked;
}

/// 사전 집계된 장소 랭킹 한 줄 (RNK-002, RNK-009).
@immutable
class PlaceRanking {
  const PlaceRanking({
    required this.rank,
    this.previousRank,
    this.period,
    this.theme,
  });

  factory PlaceRanking.fromJson(Map<String, Object?> json) => PlaceRanking(
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    previousRank: (json['previousRank'] as num?)?.toInt(),
    period: json['period'] as String?,
    theme: json['theme'] as String?,
  );

  final int rank;
  final int? previousRank;
  final String? period;
  final String? theme;

  /// 양수면 순위가 올랐다는 뜻이다. 이전 순위가 없으면 신규 진입이라 null이다.
  int? get change => previousRank == null ? null : previousRank! - rank;
}

@immutable
class PlacePost {
  const PlacePost({
    required this.postId,
    this.thumbnailUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

  factory PlacePost.fromJson(Map<String, Object?> json) => PlacePost(
    postId: json['postId']! as String,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );

  final String postId;
  final String? thumbnailUrl;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;
}

@immutable
class PlaceDetail {
  const PlaceDetail({
    required this.place,
    this.overview,
    this.tel,
    this.homepage,
    this.verifyRadiusM = 0,
    this.viewCount = 0,
    this.ranking,
    this.nearbyPlaces = const [],
    this.recentPosts = const [],
  });

  factory PlaceDetail.fromJson(Map<String, Object?> json) => PlaceDetail(
    place: PlaceSummary.fromJson(
      Map<String, Object?>.from(json['place']! as Map),
    ),
    overview: json['overview'] as String?,
    tel: json['tel'] as String?,
    homepage: json['homepage'] as String?,
    verifyRadiusM: (json['verifyRadiusM'] as num?)?.toInt() ?? 0,
    viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    ranking: json['ranking'] == null
        ? null
        : PlaceRanking.fromJson(
            Map<String, Object?>.from(json['ranking']! as Map),
          ),
    nearbyPlaces: ((json['nearbyPlaces'] as List?) ?? const [])
        .map(
          (item) =>
              PlaceSummary.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false),
    recentPosts: ((json['recentPosts'] as List?) ?? const [])
        .map(
          (item) => PlacePost.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false),
  );

  final PlaceSummary place;
  final String? overview;
  final String? tel;
  final String? homepage;
  final int verifyRadiusM;
  final int viewCount;
  final PlaceRanking? ranking;
  final List<PlaceSummary> nearbyPlaces;
  final List<PlacePost> recentPosts;
}

/// 그 장소에 다녀간 사람 (API-VST-004).
@immutable
class PlaceVisitor {
  const PlaceVisitor({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
  });

  factory PlaceVisitor.fromJson(Map<String, Object?> json) => PlaceVisitor(
    userId: json['userId']! as String,
    nickname: json['nickname'] as String? ?? '여행자',
    profileImageUrl: json['profileImageUrl'] as String?,
  );

  final String userId;
  final String nickname;
  final String? profileImageUrl;
}

class PlaceFailure implements Exception {
  const PlaceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

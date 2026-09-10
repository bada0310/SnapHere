import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/place/domain/place_repository.dart';

/// Figma `07_장소_상세`의 예시 값이다.
class FakePlaceRepository implements PlaceRepository {
  var _bookmarked = false;

  @override
  Future<PlaceDetail> fetchPlace(String placeId) async => PlaceDetail(
    place: PlaceSummary(
      placeId: placeId,
      title: '전주 한옥마을',
      addr1: '전북 전주시 완산구 기린로 99',
      lat: 35.8150,
      lng: 127.1530,
      postCount: 2431,
      visitCount: 1820,
      isBookmarked: _bookmarked,
    ),
    overview: '전주 한옥마을은 700여 채의 한옥이 모여 있는 국내 최대 한옥 군락지입니다.',
    verifyRadiusM: 300,
    viewCount: 18240,
    ranking: const PlaceRanking(rank: 3, previousRank: 5, period: 'WEEKLY'),
    recentPosts: const [
      PlacePost(postId: 'pst_1'),
      PlacePost(postId: 'pst_2'),
      PlacePost(postId: 'pst_3'),
    ],
    nearbyPlaces: const [
      PlaceSummary(placeId: 'plc_2', title: '경기전', distanceM: 320),
      PlaceSummary(placeId: 'plc_3', title: '전동성당', distanceM: 540),
    ],
  );

  @override
  Future<CursorPage<PlacePost>> fetchPlacePosts(
    String placeId, {
    String? cursor,
  }) async => const CursorPage(
    items: [
      PlacePost(postId: 'pst_1'),
      PlacePost(postId: 'pst_2'),
      PlacePost(postId: 'pst_3'),
    ],
  );

  @override
  Future<bool> setBookmarked(String placeId, bool bookmarked) async {
    _bookmarked = bookmarked;
    return bookmarked;
  }

  @override
  Future<List<PlaceVisitor>> fetchVisitors(String placeId) async => const [
    PlaceVisitor(userId: 'usr_1', nickname: '너구리여행자'),
    PlaceVisitor(userId: 'usr_2', nickname: 'seoul_trip'),
  ];
}

import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';

abstract interface class PlaceRepository {
  Future<PlaceDetail> fetchPlace(String placeId);

  Future<CursorPage<PlacePost>> fetchPlacePosts(
    String placeId, {
    String? cursor,
  });

  /// 멱등 PUT/DELETE다. 서버가 최종 상태를 돌려준다 (API-PLC-008, PLC-009).
  Future<bool> setBookmarked(String placeId, bool bookmarked);

  /// 그 장소를 다녀간 사람 목록 (API-VST-004).
  Future<List<PlaceVisitor>> fetchVisitors(String placeId);
}

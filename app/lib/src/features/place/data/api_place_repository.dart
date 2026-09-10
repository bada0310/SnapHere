import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/place/domain/place_repository.dart';

class ApiPlaceRepository implements PlaceRepository {
  ApiPlaceRepository({this.accessToken, ApiClient? client})
    : _client = client ?? ApiClient();

  final String? accessToken;
  final ApiClient _client;

  @override
  Future<PlaceDetail> fetchPlace(String placeId) async => PlaceDetail.fromJson(
    jsonMap(
      await _guard(
        () => _client.get('/places/$placeId', accessToken: accessToken),
      ),
    ),
  );

  @override
  Future<CursorPage<PlacePost>> fetchPlacePosts(
    String placeId, {
    String? cursor,
  }) async {
    final data = jsonMap(
      await _guard(
        () => _client.get(
          '/places/$placeId/posts',
          query: {'cursor': ?cursor},
          accessToken: accessToken,
        ),
      ),
    );
    return CursorPage(
      items: jsonMapList(data['items'])
          .map(PlacePost.fromJson)
          .toList(growable: false),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  @override
  Future<bool> setBookmarked(String placeId, bool bookmarked) async {
    final token = accessToken;
    if (token == null) throw const PlaceFailure('로그인이 필요한 기능이에요.');
    final data = jsonMap(
      await _guard(
        () => _client.request(
          bookmarked ? 'PUT' : 'DELETE',
          '/places/$placeId/bookmark',
          accessToken: token,
        ),
      ),
    );
    return data['isBookmarked'] as bool? ?? bookmarked;
  }

  @override
  Future<List<PlaceVisitor>> fetchVisitors(String placeId) async {
    final page = jsonMap(
      await _guard(
        () => _client.get(
          '/places/$placeId/visitors',
          query: const {'size': '20'},
          accessToken: accessToken,
        ),
      ),
    );
    return jsonMapList(page['items'])
        .map(PlaceVisitor.fromJson)
        .toList(growable: false);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw PlaceFailure(error.message);
    } on PlaceFailure {
      rethrow;
    } on Object {
      throw const PlaceFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

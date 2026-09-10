import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/community/data/post_page_reader.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/region/domain/region_models.dart';

class ApiRegionRepository {
  ApiRegionRepository({this.accessToken, ApiClient? api})
    : _api = api ?? ApiClient();

  final String? accessToken;
  final ApiClient _api;

  /// API-PLC-001. 24시간 캐시 대상이라 자주 불러도 부담이 적다.
  Future<List<Region>> fetchRegions() async => _guard(
    () async =>
        jsonMapList(await _api.get('/regions'))
            .map(Region.fromJson)
            .toList(growable: false),
  );

  /// API-PLC-002.
  Future<List<Sigungu>> fetchSigungu(int areaCode) async => _guard(
    () async =>
        jsonMapList(await _api.get('/regions/$areaCode/sigungu'))
            .map(Sigungu.fromJson)
            .toList(growable: false),
  );

  /// API-PLC-003. 시군구를 고르면 좁혀서 조회한다.
  Future<CursorPage<PlaceSummary>> fetchPlaces({
    required int areaCode,
    int? sigunguCode,
    String? cursor,
  }) async => _guard(() async {
    final page = jsonMap(
      await _api.get(
        '/places',
        query: {
          'areaCode': '$areaCode',
          'sigunguCode': ?sigunguCode?.toString(),
          'cursor': ?cursor,
        },
        accessToken: accessToken,
      ),
    );
    return CursorPage(
      items: jsonMapList(page['items'])
          .map(PlaceSummary.fromJson)
          .toList(growable: false),
      nextCursor: page['hasNext'] == true
          ? page['nextCursor'] as String?
          : null,
    );
  });

  /// 지역 피드. `/posts`는 시도 단위 필터를 받는다 (API-PST-004).
  Future<CursorPage<CommunityPost>> fetchPosts({
    required int areaCode,
    String? cursor,
  }) => _guard(
    () => PostPageReader(
      _api,
      accessToken: accessToken,
    ).fetch('/posts', query: {'areaCode': '$areaCode'}, cursor: cursor),
  );

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw RegionFailure(error.message);
    } on Object {
      throw const RegionFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

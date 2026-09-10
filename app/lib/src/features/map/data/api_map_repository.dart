import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/map/domain/map_models.dart';

class ApiMapRepository {
  ApiMapRepository({this.accessToken, ApiClient? api})
    : _api = api ?? ApiClient();

  final String? accessToken;
  final ApiClient _api;

  /// API-MAP-002.
  Future<HeatmapResult> fetchHeatmap(MapViewport viewport) => _guard(
    () async => HeatmapResult.fromJson(
      jsonMap(
        await _api.get(
          '/map/heatmap',
          query: viewport.toQuery(),
          accessToken: accessToken,
        ),
      ),
    ),
  );

  /// API-MAP-003.
  Future<List<PhotoMarker>> fetchPhotoMarkers(MapViewport viewport) => _guard(
    () async => jsonMapList(
      await _api.get(
        '/map/photo-markers',
        query: viewport.toQuery(),
        accessToken: accessToken,
      ),
    ).map(PhotoMarker.fromJson).toList(growable: false),
  );

  /// API-MAP-004. 셀을 눌렀을 때의 대표 장소와 사진.
  Future<({String? placeId, List<String> postIds})> fetchCellDetail(
    String cellKey,
  ) => _guard(() async {
    final data = jsonMap(
      await _api.get('/map/cells/$cellKey', accessToken: accessToken),
    );
    final topPlace = data['topPlace'];
    return (
      placeId: topPlace == null
          ? null
          : jsonMap(topPlace)['placeId'] as String?,
      postIds: jsonMapList(data['samplePosts'])
          .map((post) => post['postId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
    );
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw MapFailure(error.message);
    } on Object {
      throw const MapFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/rankings/domain/ranking_models.dart';

class ApiRankingRepository {
  ApiRankingRepository({this.accessToken, ApiClient? api})
    : _api = api ?? ApiClient();

  final String? accessToken;
  final ApiClient _api;

  /// API-RNK-001. 사전 집계된 결과라 정렬을 앱에서 하지 않는다 (RNK-007).
  Future<List<RankingEntry>> fetchPlaceRankings({
    required RankingScope scope,
    required RankingPeriod period,
    int? areaCode,
    String? theme,
  }) => _guard(() async {
    final page = jsonMap(
      await _api.get(
        '/rankings/places',
        query: {
          'scope': scope.code,
          'period': period.code,
          'areaCode': ?areaCode?.toString(),
          'theme': ?theme,
          'size': '30',
        },
        accessToken: accessToken,
      ),
    );
    return jsonMapList(page['items'])
        .map(RankingEntry.fromJson)
        .toList(growable: false);
  });

  /// API-RNK-002.
  Future<List<PlaceRecommendation>> fetchRecommendations({int? areaCode}) =>
      _guard(() async {
        final items = jsonMapList(
          await _api.get(
            '/recommendations/places',
            query: {'areaCode': ?areaCode?.toString(), 'limit': '10'},
            accessToken: accessToken,
          ),
        );
        return items.map(PlaceRecommendation.fromJson).toList(growable: false);
      });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw RankingFailure(error.message);
    } on Object {
      throw const RankingFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

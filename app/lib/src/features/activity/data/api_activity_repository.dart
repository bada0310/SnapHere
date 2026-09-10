import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/activity/domain/activity_models.dart';
import 'package:snap_here/src/features/community/data/post_page_reader.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';

/// `내 활동` — 저장함·좋아요·방문 기록처럼 `/me` 아래에 모인 목록들.
class ApiActivityRepository {
  ApiActivityRepository({required this.accessToken, ApiClient? api})
    : _api = api ?? ApiClient();

  final String? accessToken;
  final ApiClient _api;

  /// API-USER-006.
  Future<List<CommunityPost>> fetchLikedPosts() => _guard(() async {
    final page = await PostPageReader(
      _api,
      accessToken: _requireToken(),
    ).fetch('/me/liked-posts');
    return page.items;
  });

  /// API-USER-007. 저장함은 사진과 장소를 한 엔드포인트에서 타입으로 나눈다.
  Future<List<CommunityPost>> fetchBookmarkedPosts() => _guard(() async {
    final page = jsonMap(
      await _api.get(
        '/me/bookmarks',
        query: {'type': BookmarkTarget.post.code, 'size': '20'},
        accessToken: _requireToken(),
      ),
    );
    final reader = PostPageReader(_api, accessToken: accessToken);
    final summaries = jsonMapList(page['items'])
        .map((item) => item['post'])
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);
    return Future.wait(summaries.map(reader.hydrate));
  });

  Future<List<PlaceSummary>> fetchBookmarkedPlaces() => _guard(() async {
    final page = jsonMap(
      await _api.get(
        '/me/bookmarks',
        query: {'type': BookmarkTarget.place.code, 'size': '20'},
        accessToken: _requireToken(),
      ),
    );
    return jsonMapList(page['items'])
        .map((item) => item['place'])
        .whereType<Map<Object?, Object?>>()
        .map((place) => PlaceSummary.fromJson(Map<String, Object?>.from(place)))
        .toList(growable: false);
  });

  /// API-VST-001.
  Future<List<Visit>> fetchVisits() => _guard(() async {
    final page = jsonMap(
      await _api.get(
        '/me/visits',
        query: const {'size': '30'},
        accessToken: _requireToken(),
      ),
    );
    return jsonMapList(page['items'])
        .map(Visit.fromJson)
        .toList(growable: false);
  });

  /// API-VST-002.
  Future<VisitStats> fetchVisitStats() => _guard(
    () async => VisitStats.fromJson(
      jsonMap(await _api.get('/me/visit-stats', accessToken: _requireToken())),
    ),
  );

  /// API-USER-011.
  Future<List<PlaceSummary>> fetchRecentPlaces() => _guard(
    () async => jsonMapList(
      await _api.get('/me/recent-places', accessToken: _requireToken()),
    ).map(PlaceSummary.fromJson).toList(growable: false),
  );

  /// API-USER-008. 삭제 확인 전에 무엇이 사라지는지 보여주려고 미리 받는다.
  Future<DeletionPreview> fetchDeletionPreview() => _guard(
    () async => DeletionPreview.fromJson(
      jsonMap(
        await _api.get('/me/deletion-preview', accessToken: _requireToken()),
      ),
    ),
  );

  /// API-AUTH-005.
  Future<void> logoutAllDevices() =>
      _guard(() => _api.post('/auth/logout-all', accessToken: _requireToken()));

  /// API-USER-003. FCM 토큰이 없어도 기기 자체는 등록해 둔다.
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String appVersion,
    String? fcmToken,
  }) => _guard(
    () => _api.request(
      'PUT',
      '/me/device',
      body: {
        'deviceId': deviceId,
        'platform': platform,
        'appVersion': appVersion,
        'fcmToken': ?fcmToken,
      },
      accessToken: _requireToken(),
    ),
  );

  String _requireToken() {
    final token = accessToken;
    if (token == null) throw const ActivityFailure('로그인이 필요한 기능이에요.');
    return token;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw ActivityFailure(error.message);
    } on ActivityFailure {
      rethrow;
    } on Object {
      throw const ActivityFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

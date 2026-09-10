import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';

enum ConnectionKind { followers, following }

class SocialUser {
  const SocialUser({
    required this.userId,
    required this.nickname,
    required this.isFollowing,
    this.imageUrl,
    this.bio,
    this.postCount,
  });
  final String userId;
  final String nickname;
  final String? imageUrl;
  final String? bio;
  final int? postCount;
  final bool isFollowing;
}

class ApiSocialRepository {
  ApiSocialRepository({ApiClient? api, this.accessToken})
    : _api = api ?? ApiClient();
  final ApiClient _api;
  final String? accessToken;

  Future<bool> setFollowing(String userId, {required bool following}) async {
    if (accessToken == null) {
      throw const ApiException('로그인이 필요합니다.', statusCode: 401);
    }
    final data = jsonMap(
      await _api.request(
        following ? 'PUT' : 'DELETE',
        '/users/$userId/follow',
        accessToken: accessToken,
      ),
    );
    return data['isFollowing']! as bool;
  }

  Future<CursorPage<SocialUser>> fetchConnections(
    String userId,
    ConnectionKind kind, {
    String? cursor,
  }) async {
    final page = jsonMap(
      await _api.get(
        '/users/$userId/${kind.name}',
        accessToken: accessToken,
        query: {'size': '12', 'cursor': ?cursor},
      ),
    );
    final rows = jsonMapList(page['items']);
    final users = <SocialUser>[];
    for (var start = 0; start < rows.length; start += 4) {
      users.addAll(await Future.wait(rows.skip(start).take(4).map(_user)));
    }
    return CursorPage(
      items: users,
      nextCursor: page['hasNext'] == true
          ? page['nextCursor'] as String?
          : null,
    );
  }

  Future<SocialUser> _user(Map<String, Object?> row) async {
    int? postCount;
    // 팔로우 목록 요약에는 게시글 수가 없어 공개 프로필에서 보충한다.
    try {
      final profile = jsonMap(
        await _api.get('/users/${row['userId']}', accessToken: accessToken),
      );
      postCount = (jsonMap(profile['stats'])['postCount'] as num).toInt();
    } on ApiException {
      // 통계 조회 실패를 0개로 오인시키지 않고 소개만 표시한다.
    }
    return SocialUser(
      userId: row['userId']! as String,
      nickname: row['nickname'] as String? ?? '여행자',
      imageUrl: row['profileImageUrl'] as String?,
      bio: row['bio'] as String?,
      isFollowing: row['isFollowing'] == true,
      postCount: postCount,
    );
  }

  /// 팔로잉이 없을 때 보여줄 추천 사용자 (API-SOC-005, 결정 8번).
  Future<List<SocialUser>> fetchRecommendations() async {
    final items = jsonMapList(
      await _api.get(
        '/users/recommendations',
        query: const {'limit': '10'},
        accessToken: accessToken,
      ),
    );
    return Future.wait(items.map(_user));
  }
}

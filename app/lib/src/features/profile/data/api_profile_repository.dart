import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/community/data/post_page_reader.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/profile/domain/profile_models.dart';

class ApiProfileRepository {
  ApiProfileRepository({this.accessToken, ApiClient? api})
    : _api = api ?? ApiClient();

  final String? accessToken;
  final ApiClient _api;

  Future<ProfileSnapshot> fetchMe() async {
    final data = jsonMap(await _api.get('/me', accessToken: accessToken));
    return _profile(jsonMap(data['profile']));
  }

  Future<ProfileSnapshot> fetchUser(String userId) async => _profile(
    jsonMap(await _api.get('/users/$userId', accessToken: accessToken)),
  );

  Future<ProfileSnapshot> updateProfile({
    required String nickname,
    required String? bio,
  }) async {
    final token = accessToken;
    if (token == null) throw const ApiException('로그인이 필요해요.');
    final data = jsonMap(
      await _api.patch(
        '/me',
        accessToken: token,
        body: {'nickname': nickname, 'bio': bio},
      ),
    );
    return _profile(jsonMap(data['profile']));
  }

  Future<CursorPage<CommunityPost>> fetchPosts(
    String userId, {
    String? cursor,
  }) => PostPageReader(
    _api,
    accessToken: accessToken,
  ).fetch('/users/$userId/posts', cursor: cursor);

  ProfileSnapshot _profile(Map<String, Object?> profile) {
    final user = jsonMap(profile['user']);
    final stats = jsonMap(profile['stats']);
    return ProfileSnapshot(
      userId: user['userId'] as String? ?? '',
      nickname: user['nickname'] as String? ?? '여행자',
      imageUrl: user['profileImageUrl'] as String?,
      isFollowing: user['isFollowing'] == true,
      bio: user['bio'] as String?,
      stats: ProfileStats(
        postCount: (stats['postCount'] as num? ?? 0).toInt(),
        followerCount: (stats['followerCount'] as num? ?? 0).toInt(),
        followingCount: (stats['followingCount'] as num? ?? 0).toInt(),
        badgeCount: (stats['badgeCount'] as num? ?? 0).toInt(),
      ),
    );
  }
}

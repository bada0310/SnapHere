import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/community/data/post_page_reader.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/community/domain/community_repository.dart';
import 'package:snap_here/src/features/post/domain/post_id.dart';

class ApiCommunityRepository implements CommunityRepository {
  ApiCommunityRepository({ApiClient? api, this.accessToken, this.currentUserId})
    : _api = api ?? ApiClient();

  final ApiClient _api;
  final String? accessToken;
  final String? currentUserId;

  @override
  Future<CommunityFeed> fetchFeed({
    required CommunityFeedTab tab,
    required CommunitySort sort,
  }) async {
    if (tab == CommunityFeedTab.following) {
      if (accessToken == null) {
        return const CommunityFeed(posts: [], sectionTitle: '팔로잉 스냅');
      }
      try {
        final result = jsonMap(
          await _api.get(
            '/feeds/following',
            query: const {'size': '30'},
            accessToken: accessToken,
          ),
        );
        final page = jsonMap(result['page']);
        final posts = await Future.wait(jsonMapList(page['items']).map(_hydrate));
        return CommunityFeed(posts: posts, sectionTitle: '팔로잉 스냅');
      } on ApiException {
        // 이전 서버에는 팔로잉 집계 피드가 없다. 이미 제공하던 팔로잉 목록과
        // 사용자별 게시글 목록을 조합해, 배포 순서와 관계없이 탭을 사용할 수 있게 한다.
        return CommunityFeed(
          posts: await _followingFallback(),
          sectionTitle: '팔로잉 스냅',
        );
      }
    }
    final path = sort == CommunitySort.latest
        ? '/feeds/recent'
        : '/posts/popular';
    final query = <String, String>{'size': '30'};
    if (path.endsWith('popular')) query['period'] = 'WEEKLY';
    final page = jsonMap(
      await _api.get(path, query: query, accessToken: accessToken),
    );
    final summaries = jsonMapList(page['items']);
    final posts = await Future.wait(summaries.map(_hydrate));
    return CommunityFeed(
      sectionTitle: sort == CommunitySort.latest ? '최신 스냅' : '인기 스냅',
      posts: posts,
    );
  }

  Future<List<CommunityPost>> _followingFallback() async {
    final userId = currentUserId;
    if (userId == null) return const [];
    try {
      final page = jsonMap(
        await _api.get(
          '/users/$userId/following',
          query: const {'size': '30'},
          accessToken: accessToken,
        ),
      );
      final users = jsonMapList(page['items']);
      final reader = PostPageReader(_api, accessToken: accessToken);
      final pages = await Future.wait(
        users.map((user) async {
          final id = user['userId'] as String?;
          if (id == null || id.isEmpty) return const <CommunityPost>[];
          try {
            return (await reader.fetch('/users/$id/posts')).items;
          } on ApiException {
            return const <CommunityPost>[];
          }
        }),
      );
      final posts = pages.expand((items) => items).toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return posts.take(30).toList(growable: false);
    } on ApiException {
      return const [];
    }
  }

  Future<CommunityPost> _hydrate(Map<String, Object?> summary) async {
    final postId = postApiId(summary['postId']! as String);
    try {
      final detail = jsonMap(
        await _api.get('/posts/$postId', accessToken: accessToken),
      );
      return _post(summary, content: detail['content'] as String? ?? '');
    } on ApiException {
      return _post(summary);
    }
  }

  CommunityPost _post(Map<String, Object?> json, {String content = ''}) {
    final author = jsonMap(json['author']);
    final place = json['place'] is Map ? jsonMap(json['place']) : null;
    final normalized = content.trim();
    final title = normalized.isEmpty
        ? (place?['title'] as String? ?? '여행 스냅')
        : normalized.split('\n').first;
    final lines = normalized.split('\n');
    final body = lines.length <= 1 ? '' : lines.skip(1).join('\n').trim();
    return CommunityPost(
      postId: json['postId']! as String,
      author: CommunityAuthor(
        userId: author['userId']! as String,
        nickname: author['nickname'] as String? ?? '여행자',
        profileImageUrl: author['profileImageUrl'] as String?,
      ),
      title: title,
      content: body,
      placeName: place?['title'] as String?,
      regionName: place?['addr1'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageCount: (json['imageCount'] as num? ?? 0).toInt(),
      likeCount: (json['likeCount'] as num? ?? 0).toInt(),
      commentCount: (json['commentCount'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }

  /// `03_커뮤니티_검색_포커스`. 최근 검색어는 서버(Redis)에, 추천은 인기 검색어에서 온다
  /// (API-SCH-002, API-SCH-003).
  @override
  Future<CommunitySearchSuggestions> fetchSearchSuggestions() async {
    final popular = await _popularKeywords();
    final tags = await _popularTags();
    // 최근 검색어는 로그인해야 있다. 비회원은 추천만 보여준다 (SCH-011).
    final recent = accessToken == null
        ? const <String>[]
        : await _recentKeywords();
    return CommunitySearchSuggestions(
      recent: recent,
      recommended: popular,
      popularTags: tags,
    );
  }

  /// 인기 해시태그 (API-CMU-012). 검색어 집계(SCH-002)와는 다른 목록이다.
  Future<List<SearchedTag>> _popularTags() async {
    try {
      return jsonMapList(
        await _api.get('/tags/popular', query: const {'limit': '10'}),
      ).map(SearchedTag.fromJson).toList(growable: false);
    } on ApiException {
      return const [];
    }
  }

  Future<List<String>> _popularKeywords() async {
    final items = jsonMapList(
      await _api.get('/search/popular', query: const {'limit': '10'}),
    );
    return items
        .map((item) => item['keyword'] as String? ?? '')
        .where((keyword) => keyword.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> _recentKeywords() async {
    try {
      final items = jsonMapList(
        await _api.get('/me/recent-searches', accessToken: accessToken),
      );
      return items
          .map((item) => item['keyword'] as String? ?? '')
          .where((keyword) => keyword.isNotEmpty)
          .toList(growable: false);
    } on ApiException {
      // 최근 검색어는 부가 정보다. 실패해도 검색 화면 자체는 열려야 한다.
      return const [];
    }
  }

  @override
  Future<void> removeRecentKeyword(String keyword) => _api.delete(
    '/me/recent-searches?keyword=${Uri.encodeQueryComponent(keyword)}',
    accessToken: accessToken,
  );

  @override
  Future<void> clearRecentKeywords() =>
      _api.delete('/me/recent-searches', accessToken: accessToken);

  /// 통합 검색 (API-SCH-001). 장소·게시글·사용자·태그를 한 번에 받는다.
  @override
  Future<CommunitySearchResult> search({
    required String keyword,
    required CommunitySearchFilter filter,
  }) async {
    final value = keyword.trim();
    if (value.isEmpty) return const CommunitySearchResult.empty();

    final result = jsonMap(
      await _api.get(
        '/search',
        query: {'q': value, 'size': '20', 'types': ?_typesOf(filter)},
        accessToken: accessToken,
      ),
    );

    final posts = await Future.wait(
      _sectionItems(result['posts']).map(_hydrate),
    );
    final region = result['matchedRegion'];
    return CommunitySearchResult(
      posts: posts,
      totalCount: _sectionTotal(result['posts']) ?? posts.length,
      places: _sectionItems(result['places'])
          .map(SearchedPlace.fromJson)
          .toList(growable: false),
      users: _sectionItems(result['users'])
          .map(SearchedUser.fromJson)
          .toList(growable: false),
      tags: _sectionItems(result['tags'])
          .map(SearchedTag.fromJson)
          .toList(growable: false),
      matchedRegion: region == null
          ? null
          : SearchedRegion.fromJson(jsonMap(region)),
    );
  }

  /// 필터 칩을 서버의 `types` 파라미터로 옮긴다. `전체`는 지정하지 않는다.
  String? _typesOf(CommunitySearchFilter filter) => switch (filter) {
    CommunitySearchFilter.all => null,
    CommunitySearchFilter.region => 'PLACE',
    CommunitySearchFilter.place => 'PLACE',
  };

  List<Map<String, Object?>> _sectionItems(Object? section) =>
      section == null ? const [] : jsonMapList(jsonMap(section)['items']);

  int? _sectionTotal(Object? section) => section == null
      ? null
      : (jsonMap(section)['totalApproximate'] as num?)?.toInt();

  @override
  Future<List<CommunityPost>> fetchTagPosts(String tagId) async {
    final page = await PostPageReader(
      _api,
      accessToken: accessToken,
    ).fetch('/tags/$tagId/posts');
    return page.items;
  }
}

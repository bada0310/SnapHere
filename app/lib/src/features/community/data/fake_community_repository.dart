import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/community/domain/community_repository.dart';

/// API가 없는 동안 화면을 완성하기 위한 메모리 구현체.
///
/// 문구와 숫자는 Figma `Wireframe_v3 / 03 Community`의 값을 그대로 썼다.
/// 이미지 URL은 실제 에셋이 없으므로 null이고, 화면은 자리 표시자를 그린다.
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository();

  static const _latency = Duration(milliseconds: 250);

  /// 더미 게시글의 작성 시각. 고정 날짜를 쓰면 시간이 지날수록 카드의
  /// "N시간 전"이 Figma와 멀어지므로 현재 시각 기준으로 만든다.
  static DateTime _ago(Duration elapsed) => DateTime.now().subtract(elapsed);

  final List<String> _recent = ['전주 한옥마을', '야경', '서울 궁궐'];

  static final _minsu = CommunityAuthor(userId: 'u-1', nickname: '민수_Kim');
  static final _hyewon = CommunityAuthor(
    userId: 'u-2',
    nickname: 'travel_hyewon',
  );
  static final _yejin = CommunityAuthor(userId: 'u-3', nickname: 'yejin_go');
  static final _dahye = CommunityAuthor(
    userId: 'u-4',
    nickname: 'dahye_travel',
  );

  static List<CommunityPost> get _feedPosts => <CommunityPost>[
    CommunityPost(
      postId: 'p-1',
      author: _minsu,
      placeName: '경복궁 근정전',
      regionName: '서울',
      badge: const CommunityBadge(label: '스냅 챌린지'),
      title: '한복 입고 인생 사진 남기기 🌸',
      content:
          '날씨 좋은 날 경복궁 다녀왔어요. 근정전 앞 광장에서 찍은 사진인데 정말 마음에 드네요. '
          '다들 한복 입고 방문해보세요!',
      likeCount: 142,
      commentCount: 28,
      imageCount: 5,
      createdAt: _ago(const Duration(hours: 2)),
    ),
    CommunityPost(
      postId: 'p-2',
      author: _hyewon,
      placeName: '해운대 미포철길',
      regionName: '부산',
      title: '바다와 나란히 걷는 철길',
      content: '해가 질 무렵 미포철길을 걸었어요. 파도 소리랑 같이 걷다 보면 시간 가는 줄 모릅니다.',
      likeCount: 98,
      commentCount: 12,
      createdAt: _ago(const Duration(hours: 5)),
    ),
  ];

  static List<CommunityPost> get _searchPosts => <CommunityPost>[
    CommunityPost(
      postId: 'p-3',
      author: _yejin,
      regionName: '전북 전주',
      title: '고풍스러운 붉은 벽돌의 정취 ⛪',
      content:
          '경기전 맞은편에 의젓이 아름다운 로매네스크 양식의 성당입니다. '
          '전주 한옥마을 초입에 있어서 들르기 좋은 곳이에요!',
      likeCount: 78,
      commentCount: 9,
      createdAt: _ago(const Duration(hours: 3)),
    ),
    CommunityPost(
      postId: 'p-4',
      author: _dahye,
      regionName: '전북 전주',
      title: '한옥 지붕이 내려다보이는 카페 전망',
      content: '한옥마을 전망대 카페에서 마시는 시원한 오미자차 한 잔. 지붕 너머로 해가 지는 모습이 좋아요.',
      likeCount: 64,
      commentCount: 7,
      imageCount: 4,
      createdAt: _ago(const Duration(hours: 6)),
    ),
  ];

  @override
  Future<CommunityFeed> fetchFeed({
    required CommunityFeedTab tab,
    required CommunitySort sort,
  }) async {
    await Future<void>.delayed(_latency);
    // Figma `03_커뮤니티_팔로잉_빈상태` — 팔로잉 탭은 빈 상태로 그려져 있다.
    if (tab == CommunityFeedTab.following) {
      return const CommunityFeed(posts: []);
    }
    return CommunityFeed(sectionTitle: '인기 스냅', posts: _feedPosts);
  }

  @override
  Future<CommunitySearchSuggestions> fetchSearchSuggestions() async {
    await Future<void>.delayed(_latency);
    return CommunitySearchSuggestions(
      recent: List.unmodifiable(_recent),
      recommended: const ['부산 해운대', '제주 성산일출봉', '경주 불국사'],
    );
  }

  @override
  Future<void> removeRecentKeyword(String keyword) async {
    await Future<void>.delayed(_latency);
    _recent.remove(keyword);
  }

  @override
  Future<void> clearRecentKeywords() async {
    await Future<void>.delayed(_latency);
    _recent.clear();
  }

  @override
  Future<CommunitySearchResult> search({
    required String keyword,
    required CommunitySearchFilter filter,
  }) async {
    await Future<void>.delayed(_latency);
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const CommunitySearchResult.empty();

    final matched = _searchPosts
        .where(
          (post) =>
              post.title.contains(trimmed) ||
              post.content.contains(trimmed) ||
              (post.regionName?.contains(trimmed) ?? false) ||
              (post.placeName?.contains(trimmed) ?? false) ||
              post.author.nickname.contains(trimmed),
        )
        .toList();

    if (matched.isEmpty) return const CommunitySearchResult.empty();

    // Figma `03_커뮤니티_검색결과`가 "검색 결과 24건"으로 그려져 있어
    // 목록 길이와 총 건수가 다른 경우를 화면이 견디는지 확인할 수 있게 맞춘다.
    return CommunitySearchResult(posts: matched, totalCount: 24);
  }

  @override
  Future<List<CommunityPost>> fetchTagPosts(String tagId) async =>
      (await fetchFeed(
        tab: CommunityFeedTab.all,
        sort: CommunitySort.latest,
      )).posts;
}

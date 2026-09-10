import 'package:snap_here/src/features/community/domain/community_models.dart';

/// 커뮤니티 화면이 서버에 기대하는 계약.
///
/// 인증(`features/auth`)과 같은 방식으로, 화면은 이 인터페이스에만 의존한다.
/// 백엔드 API가 나오면 `data/api_community_repository.dart`를 추가하고
/// provider에서 구현체만 바꾼다. 화면 코드는 건드리지 않는다.
abstract interface class CommunityRepository {
  /// `03_커뮤니티_전체` / 팔로잉 탭의 피드.
  Future<CommunityFeed> fetchFeed({
    required CommunityFeedTab tab,
    required CommunitySort sort,
  });

  /// `03_커뮤니티_검색_포커스`의 최근·추천 검색어.
  Future<CommunitySearchSuggestions> fetchSearchSuggestions();

  /// 최근 검색어 칩의 `×`.
  Future<void> removeRecentKeyword(String keyword);

  /// 최근 검색어의 "전체 삭제".
  Future<void> clearRecentKeywords();

  /// `03_커뮤니티_검색결과` / `03_커뮤니티_검색_없음`.
  Future<CommunitySearchResult> search({
    required String keyword,
    required CommunitySearchFilter filter,
  });

  /// 태그를 눌렀을 때의 게시글 목록 (API-CMU-013).
  Future<List<CommunityPost>> fetchTagPosts(String tagId);
}

/// 커뮤니티 요청이 실패했을 때 화면에 보여줄 메시지를 담는다.
class CommunityFailure implements Exception {
  const CommunityFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

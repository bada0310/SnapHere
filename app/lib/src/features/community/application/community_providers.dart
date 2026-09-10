import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/community/data/api_community_repository.dart';
import 'package:snap_here/src/features/community/data/fake_community_repository.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/community/domain/community_repository.dart';

/// 인증(`auth_controller.dart`)과 같은 방식으로 더미/실제 구현을 고른다.
const _useFakeCommunity = bool.fromEnvironment(
  'USE_FAKE_COMMUNITY',
  defaultValue: false,
);

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  if (_useFakeCommunity) return FakeCommunityRepository();
  return ApiCommunityRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  );
});

/// `03_커뮤니티_전체`의 상단 탭 선택 상태.
final communityFeedTabProvider =
    NotifierProvider<CommunityFeedTabNotifier, CommunityFeedTab>(
      CommunityFeedTabNotifier.new,
    );

class CommunityFeedTabNotifier extends Notifier<CommunityFeedTab> {
  @override
  CommunityFeedTab build() => CommunityFeedTab.all;

  void select(CommunityFeedTab tab) => state = tab;
}

/// 목록 위 정렬 드롭다운 상태.
final communitySortProvider =
    NotifierProvider<CommunitySortNotifier, CommunitySort>(
      CommunitySortNotifier.new,
    );

class CommunitySortNotifier extends Notifier<CommunitySort> {
  @override
  CommunitySort build() => CommunitySort.latest;

  void select(CommunitySort sort) => state = sort;
}

/// 선택된 탭과 정렬에 맞는 피드.
final communityFeedProvider = FutureProvider<CommunityFeed>((ref) {
  final tab = ref.watch(communityFeedTabProvider);
  final sort = ref.watch(communitySortProvider);
  return ref.watch(communityRepositoryProvider).fetchFeed(tab: tab, sort: sort);
});

/// `03_커뮤니티_검색_포커스`의 최근·추천 검색어.
final communitySearchSuggestionsProvider =
    FutureProvider<CommunitySearchSuggestions>(
      (ref) => ref.watch(communityRepositoryProvider).fetchSearchSuggestions(),
    );

/// 검색 화면에서 확정된 검색어. 비어 있으면 아직 검색 전(포커스 상태)이다.
final communityKeywordProvider =
    NotifierProvider<CommunityKeywordNotifier, String>(
      CommunityKeywordNotifier.new,
    );

class CommunityKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';

  void submit(String keyword) => state = keyword.trim();

  void clear() => state = '';
}

/// `03_커뮤니티_검색결과`의 필터 칩 선택 상태.
final communitySearchFilterProvider =
    NotifierProvider<CommunitySearchFilterNotifier, CommunitySearchFilter>(
      CommunitySearchFilterNotifier.new,
    );

class CommunitySearchFilterNotifier extends Notifier<CommunitySearchFilter> {
  @override
  CommunitySearchFilter build() => CommunitySearchFilter.all;

  void select(CommunitySearchFilter filter) => state = filter;
}

/// 검색어가 비어 있으면 검색을 실행하지 않고 null을 돌려준다.
final communitySearchResultProvider = FutureProvider<CommunitySearchResult?>((
  ref,
) async {
  final keyword = ref.watch(communityKeywordProvider);
  if (keyword.isEmpty) return null;
  final filter = ref.watch(communitySearchFilterProvider);
  return ref
      .watch(communityRepositoryProvider)
      .search(keyword: keyword, filter: filter);
});

/// 최근 검색어 삭제 동작. 성공하면 최근·추천 목록을 다시 읽는다.
final communityRecentKeywordActionsProvider =
    Provider<CommunityRecentKeywordActions>(
      (ref) => CommunityRecentKeywordActions(ref),
    );

class CommunityRecentKeywordActions {
  CommunityRecentKeywordActions(this._ref);

  final Ref _ref;

  Future<void> remove(String keyword) async {
    await _ref.read(communityRepositoryProvider).removeRecentKeyword(keyword);
    _ref.invalidate(communitySearchSuggestionsProvider);
  }

  Future<void> clearAll() async {
    await _ref.read(communityRepositoryProvider).clearRecentKeywords();
    _ref.invalidate(communitySearchSuggestionsProvider);
  }
}

/// 태그 게시글 (API-CMU-013).
final tagPostsProvider = FutureProvider.family<List<CommunityPost>, String>(
  (ref, tagId) => ref.watch(communityRepositoryProvider).fetchTagPosts(tagId),
);

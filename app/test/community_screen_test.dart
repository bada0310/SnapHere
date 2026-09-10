import 'package:flutter/material.dart';
import 'package:snap_here/src/core/ui/relative_time.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/community/application/community_providers.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/community/domain/community_repository.dart';
import 'package:snap_here/src/features/community/presentation/community_screen.dart';
import 'package:snap_here/src/features/community/presentation/community_search_screen.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_post_card.dart';

/// 지연 없이 즉시 응답하는 테스트용 저장소.
class _StubCommunityRepository implements CommunityRepository {
  _StubCommunityRepository({
    this.feedPosts = const [],
    this.searchPosts = const [],
  });

  final List<CommunityPost> feedPosts;
  final List<CommunityPost> searchPosts;
  List<String> recent = ['전주 한옥마을'];

  @override
  Future<CommunityFeed> fetchFeed({
    required CommunityFeedTab tab,
    required CommunitySort sort,
  }) async {
    if (tab == CommunityFeedTab.following) {
      return const CommunityFeed(posts: []);
    }
    return CommunityFeed(sectionTitle: '인기 스냅', posts: feedPosts);
  }

  @override
  Future<CommunitySearchSuggestions> fetchSearchSuggestions() async =>
      CommunitySearchSuggestions(
        recent: List.of(recent),
        recommended: const ['부산 해운대'],
      );

  @override
  Future<void> removeRecentKeyword(String keyword) async =>
      recent = recent.where((it) => it != keyword).toList();

  @override
  Future<void> clearRecentKeywords() async => recent = [];

  @override
  Future<CommunitySearchResult> search({
    required String keyword,
    required CommunitySearchFilter filter,
  }) async {
    if (searchPosts.isEmpty) return const CommunitySearchResult.empty();
    return CommunitySearchResult(posts: searchPosts, totalCount: 24);
  }

  @override
  Future<List<CommunityPost>> fetchTagPosts(String tagId) async => const [];
}

CommunityPost _post({String id = 'p-1', int imageCount = 1}) => CommunityPost(
  postId: id,
  author: const CommunityAuthor(userId: 'u-1', nickname: '민수_Kim'),
  placeName: '경복궁 근정전',
  regionName: '서울',
  badge: const CommunityBadge(label: '스냅 챌린지'),
  title: '한복 입고 인생 사진 남기기',
  content: '경복궁 다녀왔어요.',
  likeCount: 142,
  commentCount: 28,
  imageCount: imageCount,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

Widget _wrap(Widget child, _StubCommunityRepository repository) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(
        path: '/community/search',
        builder: (_, _) => const CommunitySearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const Scaffold(body: Text('알림')),
      ),
      GoRoute(
        path: '/photos/:id',
        builder: (_, _) => const Scaffold(body: Text('사진 상세')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [communityRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  group('CommunityScreen', () {
    testWidgets('전체 탭은 섹션 제목과 게시글 카드를 보여준다', (tester) async {
      final repository = _StubCommunityRepository(feedPosts: [_post()]);
      await tester.pumpWidget(_wrap(const CommunityScreen(), repository));
      await tester.pumpAndSettle();

      expect(find.text('커뮤니티'), findsOneWidget);
      expect(find.text('인기 스냅'), findsOneWidget);
      expect(find.byType(CommunityPostCard), findsOneWidget);
      expect(find.text('민수_Kim'), findsOneWidget);
      expect(find.text('경복궁 근정전 · 서울'), findsOneWidget);
      expect(find.text('스냅 챌린지'), findsOneWidget);
      expect(find.text('142'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
    });

    testWidgets('팔로잉 탭은 빈 상태를 보여준다', (tester) async {
      final repository = _StubCommunityRepository(feedPosts: [_post()]);
      await tester.pumpWidget(_wrap(const CommunityScreen(), repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('팔로잉'));
      await tester.pumpAndSettle();

      expect(find.text('팔로잉 중인 사용자가 없어요'), findsOneWidget);
      expect(find.text('사용자 찾기'), findsOneWidget);
      expect(find.byType(CommunityPostCard), findsNothing);
    });

    testWidgets('사진이 여러 장이면 +N 칩을 보여준다', (tester) async {
      final repository = _StubCommunityRepository(
        feedPosts: [_post(imageCount: 5)],
      );
      await tester.pumpWidget(_wrap(const CommunityScreen(), repository));
      await tester.pumpAndSettle();

      expect(find.text('+4'), findsOneWidget);
    });

    testWidgets('검색창을 누르면 검색 화면으로 이동한다', (tester) async {
      final repository = _StubCommunityRepository(feedPosts: [_post()]);
      await tester.pumpWidget(_wrap(const CommunityScreen(), repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('검색어를 입력하세요'));
      await tester.pumpAndSettle();

      expect(find.text('최근 검색어'), findsOneWidget);
      expect(find.text('추천 검색어'), findsOneWidget);
    });
  });

  group('CommunitySearchScreen', () {
    testWidgets('최근·추천 검색어 칩을 보여주고 전체 삭제가 동작한다', (tester) async {
      final repository = _StubCommunityRepository();
      await tester.pumpWidget(_wrap(const CommunitySearchScreen(), repository));
      await tester.pumpAndSettle();

      expect(find.text('전주 한옥마을'), findsOneWidget);
      expect(find.text('부산 해운대'), findsOneWidget);

      await tester.tap(find.text('전체 삭제'));
      await tester.pumpAndSettle();

      expect(find.text('전주 한옥마을'), findsNothing);
      expect(find.text('최근 검색어가 없어요.'), findsOneWidget);
    });

    testWidgets('결과가 있으면 필터 칩과 건수를 보여준다', (tester) async {
      final repository = _StubCommunityRepository(searchPosts: [_post()]);
      await tester.pumpWidget(_wrap(const CommunitySearchScreen(), repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '전주');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('작성자'), findsOneWidget);
      expect(find.text('지역'), findsOneWidget);
      expect(find.text('장소'), findsOneWidget);
      expect(find.textContaining('검색 결과'), findsOneWidget);
      expect(find.byType(CommunityPostCard), findsOneWidget);
    });

    testWidgets('결과가 없으면 빈 상태를 보여준다', (tester) async {
      final repository = _StubCommunityRepository();
      await tester.pumpWidget(_wrap(const CommunitySearchScreen(), repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '아무검색어없는곳');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('검색 결과가 없어요'), findsOneWidget);
      expect(find.text('검색어 수정'), findsOneWidget);
      expect(find.byType(CommunityPostCard), findsNothing);
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 9, 1, 12);

    test('경과 시간에 맞는 라벨을 만든다', () {
      expect(formatRelativeTime(now, now: now), '방금 전');
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 30)), now: now),
        '30분 전',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 2)), now: now),
        '2시간 전',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 3)), now: now),
        '3일 전',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 30)), now: now),
        '2026.8.2',
      );
    });
  });
}

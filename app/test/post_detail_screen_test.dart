import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/post/application/post_providers.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/domain/post_repository.dart';
import 'package:snap_here/src/features/post/presentation/post_detail_screen.dart';

/// 팔로우 버튼이 세션을 보므로 로그인 상태를 고정한다.
class _ReadyAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession.authenticated(
    accessToken: 'test',
    refreshToken: 'test',
    user: AuthUser(
      id: 'u1',
      email: 'test@example.test',
      nickname: '여행자',
      needsProfileSetup: false,
    ),
  );
}

class _StubPostRepository implements PostRepository {
  _StubPostRepository({this.failLike = false});

  final bool failLike;
  bool? lastLiked;
  bool? lastBookmarked;

  @override
  Future<PostDetail> fetchPost(String postId) async => detail;

  @override
  Future<({int likeCount, bool isLiked})> setLiked(
    String postId,
    bool liked,
  ) async {
    lastLiked = liked;
    if (failLike) throw const PostFailure('좋아요에 실패했어요.');
    return (likeCount: liked ? 143 : 142, isLiked: liked);
  }

  @override
  Future<bool> setBookmarked(String postId, bool bookmarked) async {
    lastBookmarked = bookmarked;
    return bookmarked;
  }

  @override
  Future<CursorPage<CommentThread>> fetchComments(
    String postId, {
    String? cursor,
  }) async => const CursorPage(items: []);

  @override
  Future<Comment> addComment(String postId, String content) =>
      throw UnimplementedError();

  @override
  Future<Comment> addReply(String commentId, String content) =>
      throw UnimplementedError();

  @override
  Future<Comment> editComment(String commentId, String content) =>
      throw UnimplementedError();

  @override
  Future<void> deleteComment(String commentId) => throw UnimplementedError();

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<void> report(
    String postId, {
    required String reason,
    String? detail,
  }) async {}

  @override
  Future<ShareMetadata> fetchShareMetadata(String postId) async =>
      const ShareMetadata(shareUrl: 'https://snaphere.test/p/1', title: '테스트');
}

final detail = PostDetail(
  postId: 'pst_1',
  author: const PostAuthor(userId: 'usr_1', nickname: '너구리여행자'),
  place: const PostPlace(placeId: 'plc_1', title: '전주 한옥마을', addr1: '전북 전주시'),
  images: const [PostImage(postImageId: 'img_1', imageUrl: '')],
  content: '전주 한옥마을의 봄\n날씨 좋은 날 경복궁을 다녀왔어요.',
  tags: const [PostTag(tagId: 't1', name: '2026 전주 한옥마을 봄축제', locked: true)],
  likeCount: 142,
  commentCount: 28,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  tierResult: const TierResult(
    tier: TrustTier.high,
    distanceM: 24,
    verifyRadiusM: 300,
    withinRadius: true,
  ),
  isLiked: false,
  isBookmarked: false,
);

void main() {
  Future<_StubPostRepository> mount(
    WidgetTester tester, {
    bool failLike = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _StubPostRepository(failLike: failLike);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PostDetailScreen(postId: 'pst_1'),
        ),
        GoRoute(
          path: '/photos/pst_1/comments',
          builder: (_, _) => const Scaffold(body: Text('comments-screen')),
        ),
        GoRoute(
          path: '/places/plc_1',
          builder: (_, _) => const Scaffold(body: Text('place-screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_ReadyAuth.new),
          postRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('제목과 본문을 나눠 보여준다', (tester) async {
    await mount(tester);
    expect(find.text('전주 한옥마을의 봄'), findsOneWidget);
    expect(find.text('날씨 좋은 날 경복궁을 다녀왔어요.'), findsOneWidget);
  });

  testWidgets('장소·태그·반응 수를 보여준다', (tester) async {
    await mount(tester);
    expect(find.text('전주 한옥마을'), findsOneWidget);
    expect(find.text('2026 전주 한옥마을 봄축제'), findsOneWidget);
    expect(find.text('142'), findsOneWidget);
    expect(find.text('댓글 28개'), findsOneWidget);
  });

  testWidgets('신뢰 등급 배지를 누르면 판정 기준을 연다', (tester) async {
    await mount(tester);
    await tester.tap(find.text('위치 높음'));
    await tester.pumpAndSettle();
    expect(find.text('위치 신뢰도 높음'), findsOneWidget);
    expect(find.text('등급은 이렇게 정해져요'), findsOneWidget);
  });

  testWidgets('좋아요를 누르면 즉시 숫자가 오른다', (tester) async {
    final repository = await mount(tester);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(find.text('143'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(repository.lastLiked, isTrue);
  });

  testWidgets('좋아요가 실패하면 숫자를 되돌린다', (tester) async {
    await mount(tester, failLike: true);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(find.text('142'), findsOneWidget);
    expect(find.text('좋아요에 실패했어요.'), findsOneWidget);
  });

  testWidgets('저장을 누르면 아이콘이 채워진다', (tester) async {
    final repository = await mount(tester);
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(repository.lastBookmarked, isTrue);
  });

  testWidgets('댓글 줄을 누르면 댓글 화면으로 간다', (tester) async {
    await mount(tester);
    await tester.tap(find.text('댓글 28개'));
    await tester.pumpAndSettle();
    expect(find.text('comments-screen'), findsOneWidget);
  });

  testWidgets('장소를 누르면 장소 상세로 간다', (tester) async {
    await mount(tester);
    await tester.tap(find.text('전주 한옥마을'));
    await tester.pumpAndSettle();
    expect(find.text('place-screen'), findsOneWidget);
  });
}

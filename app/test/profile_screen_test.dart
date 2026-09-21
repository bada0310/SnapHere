import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/profile/application/profile_providers.dart';
import 'package:snap_here/src/features/profile/data/api_profile_repository.dart';
import 'package:snap_here/src/features/profile/domain/profile_models.dart';
import 'package:snap_here/src/features/profile/presentation/profile_screen.dart';

class ReadyAuth extends AuthController {
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

class ProfileStub extends ApiProfileRepository {
  ProfileStub({this.posts = const []});
  final List<CommunityPost> posts;
  @override
  Future<ProfileSnapshot> fetchMe() async => snapshot;
  @override
  Future<ProfileSnapshot> fetchUser(String userId) async => ProfileSnapshot(
    userId: userId,
    nickname: snapshot.nickname,
    bio: snapshot.bio,
    stats: snapshot.stats,
  );
  @override
  Future<CursorPage<CommunityPost>> fetchPosts(
    String userId, {
    String? cursor,
  }) async => CursorPage(items: posts);
}

const snapshot = ProfileSnapshot(
  userId: 'u1',
  nickname: '여행하는 너구리',
  bio: '전북 여행을 좋아하는 사진가',
  stats: ProfileStats(
    postCount: 24,
    followerCount: 1342,
    followingCount: 89,
    badgeCount: 12,
  ),
);

void main() {
  Future<void> mount(
    WidgetTester tester, {
    List<CommunityPost> posts = const [],
    String? userId,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ProfileScreen(userId: userId),
        ),
        GoRoute(
          path: '/upload',
          builder: (_, _) => const Scaffold(body: Text('upload-destination')),
        ),
        GoRoute(
          path: '/profile/badges',
          builder: (_, _) => const Scaffold(body: Text('badge-destination')),
        ),
        GoRoute(
          path: '/users/u1/followers',
          builder: (_, _) =>
              const Scaffold(body: Text('followers-destination')),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(
            body: Column(children: [Text('로그아웃'), Text('계정 삭제')]),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(ReadyAuth.new),
          profileRepositoryProvider.overrideWithValue(
            ProfileStub(posts: posts),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('profile shows API stats, 64px avatar and empty upload action', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('여행하는 너구리'), findsOneWidget);
    expect(find.text('1,342 팔로워'), findsOneWidget);
    expect(tester.getSize(find.byType(ProfileAvatar)), const Size(64, 64));
    expect(find.text('아직 게시글이 없어요'), findsOneWidget);
    expect(find.text('로그아웃'), findsNothing);
    await tester.tap(find.text('첫 사진 올리기'));
    await tester.pumpAndSettle();
    expect(find.text('upload-destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile follower metric and badge tab navigate', (tester) async {
    await mount(tester);
    await tester.tap(find.text('1,342 팔로워'));
    await tester.pumpAndSettle();
    expect(find.text('followers-destination'), findsOneWidget);
    GoRouter.of(tester.element(find.text('followers-destination'))).go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 뱃지'));
    await tester.pumpAndSettle();
    expect(find.text('수집한 뱃지'), findsOneWidget);
    await tester.tap(find.text('수집한 뱃지'));
    await tester.pumpAndSettle();
    expect(find.text('badge-destination'), findsOneWidget);
  });

  testWidgets('own post uses a square photo card and keeps settings actions', (
    tester,
  ) async {
    await mount(
      tester,
      posts: [
        CommunityPost(
          postId: 'pst_1',
          author: const CommunityAuthor(userId: 'u1', nickname: '여행자'),
          title: '한복 투어 대성공!',
          content: '여행 기록',
          likeCount: 1,
          commentCount: 0,
          createdAt: DateTime(2026),
          placeName: '경복궁',
        ),
      ],
    );
    expect(find.text('한복 투어 대성공!'), findsOneWidget);
    final image = find.descendant(
      of: find.byType(ProfilePostCard),
      matching: find.byType(RemoteImage),
    );
    expect(
      tester.getSize(image.first).height,
      tester.getSize(image.first).width,
    );
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.text('계정 삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public profile uses two columns and a 42px follow action', (
    tester,
  ) async {
    await mount(
      tester,
      userId: 'u2',
      posts: List.generate(
        2,
        (index) => CommunityPost(
          postId: 'pst_$index',
          author: const CommunityAuthor(userId: 'u2', nickname: '여행자'),
          title: '여행 $index',
          content: '',
          likeCount: 0,
          commentCount: 0,
          createdAt: DateTime(2026),
        ),
      ),
    );
    expect(find.byTooltip('설정'), findsNothing);
    expect(find.text('로그아웃'), findsNothing);
    final cards = find.byType(ProfilePostCard);
    expect(cards, findsNWidgets(2));
    expect(tester.getTopLeft(cards.first).dy, tester.getTopLeft(cards.last).dy);
    final photo = find
        .descendant(of: cards.first, matching: find.byType(RemoteImage))
        .last;
    expect(tester.getSize(photo).height, tester.getSize(photo).width);
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, '팔로우')).height,
      42,
    );
    expect(tester.takeException(), isNull);
  });
}

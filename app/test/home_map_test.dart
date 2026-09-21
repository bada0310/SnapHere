import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/explore/application/explore_providers.dart';
import 'package:snap_here/src/features/explore/domain/explore_models.dart';
import 'package:snap_here/src/features/home/application/home_map_providers.dart';
import 'package:snap_here/src/features/home/data/home_map_repository.dart';
import 'package:snap_here/src/features/home/presentation/home_screen.dart';
import 'package:snap_here/src/features/home/presentation/region_posts_sheet.dart';
import 'package:snap_here/src/features/map/application/map_configuration.dart';

class _Repository extends HomeMapRepository {
  int? areaCode;
  bool empty = false;
  @override
  Future<CursorPage<CommunityPost>> fetchRegionPosts(
    int areaCode, {
    String? cursor,
  }) async {
    this.areaCode = areaCode;
    return CursorPage(
      items: empty
          ? []
          : [
              CommunityPost(
                postId: 'pst_1',
                author: const CommunityAuthor(userId: 'u1', nickname: '너구리즈'),
                title: '한옥마을 야경 최고!',
                content: '전주의 밤',
                placeName: '전주 한옥마을',
                likeCount: 128,
                commentCount: 0,
                createdAt: DateTime.now(),
              ),
            ],
    );
  }
}

void main() {
  Future<_Repository> mount(WidgetTester tester, {bool empty = false}) async {
    await tester.binding.setSurfaceSize(const Size(412, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository()..empty = empty;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/photos/:postId',
          builder: (_, _) => const Scaffold(body: Text('post detail')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapConfiguredProvider.overrideWith((_) async => false),
          mapRegionsProvider.overrideWith(
            (_) async => const [
              RegionOverview(areaCode: 37, name: '전북', postCount: 128),
              RegionOverview(areaCode: 1, name: '서울', postCount: 0),
            ],
          ),
          homeMapRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('system back closes a region sheet before leaving home', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('지역 목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전북'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RegionPostsSheet), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reselecting a collapsed region restores the actual sheet snap height',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('지역 목록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전북'));
      await tester.pumpAndSettle();
      final initialTop = tester.getTopLeft(find.byType(RegionPostsSheet)).dy;
      await tester.drag(find.byType(RegionPostsSheet), const Offset(0, 260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('📍 전북'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전북').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(RegionPostsSheet)).dy,
        closeTo(initialTop, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching between regions keeps one draggable sheet attached', (
    tester,
  ) async {
    final repository = await mount(tester);
    await tester.tap(find.byTooltip('지역 목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전북'));
    await tester.pumpAndSettle();
    expect(repository.areaCode, 37);

    await tester.tap(find.text('📍 전북'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('서울').last);
    await tester.pumpAndSettle();

    expect(repository.areaCode, 1);
    expect(find.byType(RegionPostsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'region selection loads filtered posts, supports sheet expansion and close',
    (tester) async {
      final repository = await mount(tester);
      await tester.tap(find.byTooltip('지역 목록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전북'));
      await tester.pumpAndSettle();
      expect(repository.areaCode, 37);
      expect(find.text('전북 선택 · 게시글 128개'), findsOneWidget);
      expect(find.text('한옥마을 야경 최고!'), findsOneWidget);
      final image = find
          .descendant(
            of: find.byType(MapPostCard),
            matching: find.byType(RemoteImage),
          )
          .first;
      expect(tester.getSize(image), const Size(90, 90));
      final initialTop = tester.getTopLeft(find.byType(RegionPostsSheet)).dy;
      await tester.drag(find.byType(RegionPostsSheet), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(RegionPostsSheet)).dy,
        lessThan(initialTop),
      );
      await tester.tap(find.byTooltip('지역 게시글 닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(RegionPostsSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty selected region has recoverable feedback', (tester) async {
    await mount(tester, empty: true);
    await tester.tap(find.byTooltip('지역 목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('서울'));
    await tester.pumpAndSettle();
    expect(find.text('이번 주 이 지역의 게시글이 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home map does not expose current-location controls', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byTooltip('현재 위치'), findsNothing);
    await tester.tap(find.byTooltip('지역 목록'));
    await tester.pumpAndSettle();
    expect(find.text('현재 위치로 이동'), findsNothing);
  });
}

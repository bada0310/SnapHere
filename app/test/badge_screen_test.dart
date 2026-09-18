import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/badges/application/badge_preview_providers.dart';
import 'package:snap_here/src/features/badges/application/badge_providers.dart';
import 'package:snap_here/src/features/badges/domain/badge_models.dart';
import 'package:snap_here/src/features/badges/presentation/badge_collection_screen.dart';
import 'package:snap_here/src/features/badges/presentation/visit_map_panel.dart';

final earnedBadge = CollectedBadge(
  id: 'bdg_1',
  name: '첫 여행',
  description: '첫 여행 사진으로 획득',
  earned: true,
  earnedAt: DateTime(2026, 9, 18, 5, 30),
);

void main() {
  Future<void> mount(
    WidgetTester tester, {
    int count = 1,
    Size surface = const Size(412, 893),
    Future<BadgeCollection> Function()? load,
    VoidCallback? onMapQuery,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final items = [
      for (var index = 0; index < count; index++)
        index == 0
            ? earnedBadge
            : CollectedBadge(
                id: 'bdg_${index + 1}',
                name: '수집 뱃지 ${index + 1}',
                earned: true,
              ),
      const CollectedBadge(id: 'locked', name: '아직 미획득', earned: false),
    ];
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const BadgeCollectionScreen()),
        GoRoute(
          path: '/photos/pst_1',
          builder: (_, _) => const Scaffold(body: Text('source-post')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          badgePreviewEnabledProvider.overrideWithValue(false),
          visitMapProvider.overrideWith((_) async {
            onMapQuery?.call();
            throw StateError('수집함에서 방문 지도를 조회하면 안 된다.');
          }),
          badgeCollectionProvider.overrideWith((_) async {
            if (load != null) return load();
            return BadgeCollection(
              items: items,
              earnedCount: count,
              obtainableCount: count + 1,
              progress: count / (count + 1),
            );
          }),
          badgeDetailProvider.overrideWith(
            (_, id) async => BadgeDetail(
              badge: items.singleWhere((badge) => badge.id == id),
              currentValue: 1,
              targetValue: 1,
              earnedCount: 5,
              sourcePostId: id == earnedBadge.id ? 'pst_1' : null,
            ),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final count in [1, 3, 4, 7]) {
    testWidgets(
      '$count earned badges form an image-only square three-column grid',
      (tester) async {
        final surface = count == 7
            ? const Size(360, 260)
            : const Size(412, 893);
        var mapQueries = 0;
        await mount(
          tester,
          count: count,
          surface: surface,
          onMapQuery: () => mapQueries++,
        );
        expect(find.byType(VisitMapPanel), findsNothing);
        expect(find.text('내 뱃지 목록'), findsNothing);
        expect(find.byKey(const Key('badge-tile-locked')), findsNothing);
        expect(find.text(earnedBadge.name), findsNothing);
        expect(find.textContaining('획득 시각'), findsNothing);
        final first = tester.getRect(find.byKey(const Key('badge-tile-bdg_1')));
        final expectedWidth = (surface.width - 32 - 24) / 3;
        expect(first.width, closeTo(expectedWidth, .001));
        expect(first.height, closeTo(first.width, .001));
        expect(first.left, 16);
        for (var index = 0; index < (count == 7 ? 6 : count); index++) {
          final tile = find.byKey(Key('badge-tile-bdg_${index + 1}'));
          final rect = tester.getRect(tile);
          expect(rect.width, closeTo(expectedWidth, .001));
          expect(rect.height, closeTo(expectedWidth, .001));
          expect(
            rect.left,
            closeTo(16 + (index % 3) * (expectedWidth + 12), .001),
          );
          expect(
            rect.top,
            closeTo(first.top + (index ~/ 3) * (expectedWidth + 12), .001),
          );
          expect(
            find.descendant(of: tile, matching: find.byType(Text)),
            findsNothing,
          );
          expect(
            tester
                .widget<RemoteImage>(
                  find.descendant(of: tile, matching: find.byType(RemoteImage)),
                )
                .fit,
            BoxFit.contain,
          );
        }
        if (count == 7) {
          final last = find.byKey(const Key('badge-tile-bdg_7'));
          final viewport = tester.getRect(find.byType(CustomScrollView));
          expect(last, findsNothing);
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -250),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(last).overlaps(viewport), true);
          final scrollOffset = tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels;
          expect(tester.getRect(last).left, first.left);
          expect(tester.getSize(last), Size(expectedWidth, expectedWidth));
          expect(
            tester.getRect(last).top,
            closeTo(first.top + 2 * (expectedWidth + 12) - scrollOffset, .001),
          );
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(find.text('수집 뱃지 7'), findsOneWidget);
        }
        expect(mapQueries, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'image tile retains an accessible name and opens the correct detail and source post',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);
      final tile = find.byKey(const Key('badge-tile-bdg_1'));
      expect(tester.getSemantics(tile).label, earnedBadge.name);
      semantics.dispose();
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(earnedBadge.name), findsOneWidget);
      expect(find.text(earnedBadge.description!), findsOneWidget);
      expect(find.text('획득 시각 2026.09.18 05:30'), findsOneWidget);
      expect(find.text('진행 1 / 1 · 5명 획득'), findsOneWidget);
      await tester.tap(find.text('뱃지를 획득한 게시글 보기'));
      await tester.pumpAndSettle();
      expect(find.text('source-post'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty collection keeps guidance without a visit map', (
    tester,
  ) async {
    await mount(tester, count: 0);
    expect(find.textContaining('아직 수집한 뱃지가 없어요'), findsOneWidget);
    expect(find.byType(VisitMapPanel), findsNothing);
    expect(find.byType(SliverGrid), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'collection API failure retries and pull-to-refresh never queries the visit map',
    (tester) async {
      var queries = 0;
      var mapQueries = 0;
      await mount(
        tester,
        onMapQuery: () => mapQueries++,
        load: () async {
          if (++queries == 1) throw StateError('API failure');
          return BadgeCollection(
            items: [earnedBadge],
            earnedCount: 1,
            obtainableCount: 2,
            progress: .5,
          );
        },
      );
      expect(find.text('뱃지를 불러오지 못했어요'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('badge-tile-bdg_1')), findsOneWidget);
      expect(queries, 2);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(queries, 3);
      expect(mapQueries, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RemoteImage preserves cover by default and supports contain with the existing error fallback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              SizedBox.square(
                dimension: 100,
                child: RemoteImage(url: 'https://example.invalid/default.webp'),
              ),
              SizedBox.square(
                dimension: 100,
                child: RemoteImage(
                  url: 'https://example.invalid/badge.webp',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.widgetList<Image>(find.byType(Image)).map((image) => image.fit),
        [BoxFit.cover, BoxFit.contain],
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.photo_outlined), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}

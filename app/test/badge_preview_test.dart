import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/badges/application/badge_preview_providers.dart';
import 'package:snap_here/src/features/badges/application/badge_providers.dart';
import 'package:snap_here/src/features/badges/data/api_badge_repository.dart';
import 'package:snap_here/src/features/badges/domain/badge_models.dart';
import 'package:snap_here/src/features/badges/presentation/badge_collection_screen.dart';
import 'package:snap_here/src/features/badges/presentation/badge_preview_sheet.dart';

const _owned = CollectedBadge(id: 'owned', name: '원래 획득한 뱃지', earned: true);
const _first = CollectedBadge(
  id: 'first',
  name: '강릉커피축제',
  description: '강릉 행사 참여',
  earned: false,
);
const _second = CollectedBadge(
  id: 'second',
  name: '사천에어쇼',
  description: '사천 행사 참여',
  iconUrl: 'https://example.invalid/forbidden.webp',
  earned: false,
);

AuthSession _session(String id) => AuthSession.authenticated(
  accessToken: 'test-token',
  refreshToken: 'test-refresh',
  user: AuthUser(
    id: id,
    email: 'test@example.invalid',
    needsProfileSetup: false,
  ),
);

class _PreviewAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => _session('owner-1');

  void change(AuthSession? session) => state = AsyncData(session);
}

class _ApiFixture {
  _ApiFixture({
    this.items = const [_owned, _first, _second],
    this.failures = 0,
  });

  final List<CollectedBadge> items;
  int failures;
  final requests = <http.Request>[];

  ApiBadgeRepository get repository => ApiBadgeRepository(
    accessToken: 'test-token',
    api: ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET', reason: '미리보기는 서버 기록을 쓰지 않는다.');
        if (request.url.path == '/api/v1/users/me/badges') {
          if (failures > 0) {
            failures--;
            return http.Response('{}', 500);
          }
          return _response({
            'items': items.map(_badgeJson).toList(),
            'earnedCount': items.where((badge) => badge.earned).length,
            'obtainableCount': items.length,
            'progress': 0,
          });
        }
        final id = request.url.path.split('/').last;
        final badge = items.singleWhere((badge) => badge.id == id);
        return _response({
          'badge': _badgeJson(badge),
          'currentValue': 2,
          'targetValue': 5,
          'earnedCount': 29,
          'sourcePostId': badge.earned ? 'pst_owned' : null,
        });
      }),
    ),
  );
}

Map<String, Object?> _badgeJson(CollectedBadge badge) => {
  'badgeId': badge.id,
  'name': badge.name,
  'description': badge.description,
  'iconUrl': badge.iconUrl,
  'earned': badge.earned,
  'earnedAt': badge.earnedAt?.toIso8601String(),
};

http.Response _response(Object data) =>
    http.Response.bytes(utf8.encode(jsonEncode({'data': data})), 200);

ProviderContainer _container(_ApiFixture fixture, {bool enabled = true}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authControllerProvider.overrideWith(_PreviewAuth.new),
      badgePreviewEnabledProvider.overrideWithValue(enabled),
      badgeRepositoryProvider.overrideWithValue(fixture.repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen(displayedBadgeCollectionProvider, (_, _) {});
  return container;
}

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester,
    _ApiFixture fixture, {
    bool enabled = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const BadgeCollectionScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authControllerProvider.overrideWith(_PreviewAuth.new),
          badgePreviewEnabledProvider.overrideWithValue(enabled),
          badgeRepositoryProvider.overrideWithValue(fixture.repository),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(BadgeCollectionScreen)),
    );
  }

  Future<void> choose(WidgetTester tester, CollectedBadge badge) async {
    await tester.tap(find.byKey(const Key('badge-preview-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('badge-preview-search')),
      badge.name,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('badge-preview-choice-${badge.id}')));
    await tester.pumpAndSettle();
  }

  for (final configuration in [
    (name: 'default build', enabled: badgePreviewAllowed(requested: false)),
    (
      name: 'release build even with the flag enabled',
      enabled: badgePreviewAllowed(requested: true, debugBuild: false),
    ),
  ]) {
    testWidgets('${configuration.name} blocks preview UI and state', (
      tester,
    ) async {
      final fixture = _ApiFixture();
      final container = await mount(
        tester,
        fixture,
        enabled: configuration.enabled,
      );
      container.read(badgePreviewProvider.notifier).select(_first);
      await tester.pumpAndSettle();
      expect(find.text('획득 미리보기'), findsNothing);
      expect(find.text(_first.name), findsNothing);
      expect(find.byKey(const Key('badge-tile-first')), findsNothing);
      expect(container.read(badgePreviewProvider), isNull);
      expect(fixture.requests.map((request) => request.method), ['GET']);
    });
  }

  testWidgets('search, select, detail and clear only overlay GET responses', (
    tester,
  ) async {
    final fixture = _ApiFixture();
    final container = await mount(tester, fixture);
    await choose(tester, _first);
    expect(find.byType(BadgePreviewSheet), findsNothing);
    expect(find.byKey(const Key('badge-tile-first')), findsOneWidget);
    expect(find.byKey(const Key('badge-tile-second')), findsNothing);
    expect(find.text(_first.name), findsNothing);
    final selection = container.read(badgePreviewProvider)!;
    final time = selection.earnedAt.toLocal();
    expect(find.textContaining('획득 시각'), findsNothing);
    final raw = container.read(badgeCollectionProvider).requireValue;
    final shown = container.read(displayedBadgeCollectionProvider).requireValue;
    expect(
      raw.items.singleWhere((badge) => badge.id == _first.id).earned,
      false,
    );
    expect(
      shown.items.singleWhere((badge) => badge.id == _first.id).earnedAt,
      selection.earnedAt,
    );
    expect(find.byIcon(Icons.photo_outlined), findsWidgets);
    await tester.tap(find.byKey(const Key('badge-tile-first')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('badge-preview-detail-notice')),
      findsOneWidget,
    );
    expect(find.text('진행 5 / 5 · 29명 획득'), findsOneWidget);
    expect(find.text(_first.name), findsOneWidget);
    expect(
      find.textContaining(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      ),
      findsOneWidget,
    );
    expect(find.text(_first.description!), findsOneWidget);
    expect(find.text('뱃지를 획득한 게시글 보기'), findsNothing);
    final detail = container
        .read(displayedBadgeDetailProvider(_first.id))
        .requireValue;
    expect(detail.badge.earnedAt, selection.earnedAt);
    expect(detail.earnedCount, 29);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await choose(tester, _second);
    expect(find.byKey(const Key('badge-tile-first')), findsNothing);
    expect(find.byKey(const Key('badge-tile-second')), findsOneWidget);
    await tester.tap(find.byKey(const Key('badge-preview-clear')));
    await tester.pumpAndSettle();
    expect(find.text(_first.name), findsNothing);
    expect(find.byKey(const Key('badge-tile-first')), findsNothing);
    expect(find.byKey(const Key('badge-tile-second')), findsNothing);
    expect(container.read(badgePreviewProvider), isNull);
    expect(fixture.requests.map((request) => request.method), ['GET', 'GET']);
    expect(tester.takeException(), isNull);
  });

  test(
    'replacement, account switch, logout and restart discard the selection',
    () async {
      final fixture = _ApiFixture();
      final container = _container(fixture);
      await container.read(authControllerProvider.future);
      await container.read(badgeCollectionProvider.future);
      final controller = container.read(badgePreviewProvider.notifier);
      container.listen(displayedBadgeDetailProvider(_first.id), (_, _) {});
      container.listen(displayedBadgeDetailProvider(_second.id), (_, _) {});
      await container.read(badgeDetailProvider(_first.id).future);
      await container.read(badgeDetailProvider(_second.id).future);
      controller.select(_first);
      expect(
        container
            .read(displayedBadgeDetailProvider(_first.id))
            .requireValue
            .currentValue,
        5,
      );
      controller.select(_second);
      final shown = container
          .read(displayedBadgeCollectionProvider)
          .requireValue;
      expect(
        shown.items.singleWhere((badge) => badge.id == _first.id).earned,
        false,
      );
      expect(
        shown.items.singleWhere((badge) => badge.id == _second.id).earned,
        true,
      );
      expect(shown.earnedCount, 2);
      expect(shown.progress, closeTo(2 / 3, .0001));
      final previousDetail = container
          .read(displayedBadgeDetailProvider(_first.id))
          .requireValue;
      final selectedDetail = container
          .read(displayedBadgeDetailProvider(_second.id))
          .requireValue;
      expect(previousDetail.badge.earned, false);
      expect(previousDetail.currentValue, 2);
      expect(selectedDetail.currentValue, 5);
      expect(
        selectedDetail.badge.earnedAt,
        shown.items.singleWhere((badge) => badge.id == _second.id).earnedAt,
      );
      expect(selectedDetail.earnedCount, 29);
      controller.select(_owned);
      expect(container.read(badgePreviewProvider)?.badgeId, _second.id);
      controller.clear();
      expect(
        container
            .read(displayedBadgeCollectionProvider)
            .requireValue
            .earnedCount,
        1,
      );
      expect(
        container
            .read(displayedBadgeDetailProvider(_second.id))
            .requireValue
            .currentValue,
        2,
      );
      final auth =
          container.read(authControllerProvider.notifier) as _PreviewAuth;
      for (final nextSession in [
        _session('owner-2'),
        const AuthSession.guest(),
        null,
      ]) {
        auth.change(_session('owner-1'));
        container.read(badgePreviewProvider);
        controller.select(_first);
        expect(container.read(badgePreviewProvider), isNotNull);
        auth.change(nextSession);
        expect(container.read(badgePreviewProvider), isNull);
        expect(
          container
              .read(displayedBadgeDetailProvider(_first.id))
              .requireValue
              .badge
              .earned,
          false,
        );
      }
      auth.change(_session('owner-1'));
      container.read(badgePreviewProvider);
      controller.select(_first);
      final restarted = _container(_ApiFixture());
      await restarted.read(authControllerProvider.future);
      expect(restarted.read(badgePreviewProvider), isNull);
      expect(
        fixture.requests.every((request) => request.method == 'GET'),
        true,
      );
    },
  );

  testWidgets(
    'picker retries failed API loading and supports no search matches',
    (tester) async {
      await mount(tester, _ApiFixture(failures: 1));
      await tester.tap(find.byKey(const Key('badge-preview-open')));
      await tester.pumpAndSettle();
      final picker = find.byType(BadgePreviewSheet);
      expect(
        find.descendant(of: picker, matching: find.text('뱃지를 불러오지 못했어요')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: picker, matching: find.text('다시 시도')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('badge-preview-choice-first')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('badge-preview-choice-owned')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('badge-preview-search')),
        '없는 이름',
      );
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty catalog provides no synthetic badge choices', (
    tester,
  ) async {
    await mount(tester, _ApiFixture(items: const []));
    await tester.tap(find.byKey(const Key('badge-preview-open')));
    await tester.pumpAndSettle();
    expect(find.text('미리보기할 미획득 뱃지가 없어요'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed preview image falls back without blocking the badge', (
    tester,
  ) async {
    await mount(tester, _ApiFixture());
    await choose(tester, _second);
    expect(find.byKey(const Key('badge-tile-second')), findsOneWidget);
    expect(find.text(_second.name), findsNothing);
    expect(find.byIcon(Icons.photo_outlined), findsWidgets);
    await tester.tap(find.byKey(const Key('badge-tile-second')));
    await tester.pumpAndSettle();
    expect(find.text('진행 5 / 5 · 29명 획득'), findsOneWidget);
    expect(find.byIcon(Icons.photo_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

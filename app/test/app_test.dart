import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/app.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/data/asset_legal_document_repository.dart';
import 'package:snap_here/src/features/auth/data/fake_auth_repository.dart';
import 'package:snap_here/src/features/auth/data/google_identity_client.dart';
import 'package:snap_here/src/features/auth/data/session_store.dart';
import 'package:snap_here/src/features/home/presentation/home_screen.dart';
import 'package:snap_here/src/features/explore/application/explore_providers.dart';
import 'package:snap_here/src/features/map/application/map_configuration.dart';
import 'package:snap_here/src/features/auth/presentation/onboarding_screen.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';

class _DelayedAuth extends AuthController {
  _DelayedAuth(this.initialSession);

  final Future<AuthSession?> initialSession;

  @override
  Future<AuthSession?> build() => initialSession;

  void beginLoading() => state = const AsyncLoading();
}

void main() {
  testWidgets('saved login never renders onboarding during startup', (
    tester,
  ) async {
    final startup = Completer<AuthSession?>();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => _DelayedAuth(startup.future)),
        mapConfiguredProvider.overrideWith((_) async => false),
        mapRegionsProvider.overrideWith((_) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SnapHereApp(),
      ),
    );
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    startup.complete(
      const AuthSession.authenticated(
        accessToken: 'saved-access',
        refreshToken: 'saved-refresh',
        user: AuthUser(
          id: 'saved-user',
          email: 'saved@example.test',
          needsProfileSetup: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    (container.read(authControllerProvider.notifier) as _DelayedAuth)
        .beginLoading();
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cold-start zero-height viewport does not produce negative constraints',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('auth and permission flow reaches the main navigation shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 이 테스트는 인증·라우팅만 검증한다. 네이티브 지도와 HTTP는 개별 테스트에서 검증한다.
          mapConfiguredProvider.overrideWith((_) async => false),
          mapRegionsProvider.overrideWith((_) async => const []),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          googleIdentityClientProvider.overrideWithValue(
            const FakeGoogleIdentityClient(),
          ),
          legalDocumentRepositoryProvider.overrideWithValue(
            AssetLegalDocumentRepository(),
          ),
          sessionStoreProvider.overrideWithValue(MemorySessionStore()),
        ],
        child: const SnapHereApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지도에서 관광지를 탐색하세요'), findsOneWidget);

    expect(find.text('이미 계정이 있으신가요? '), findsNothing);
    await tester.tap(find.text('로그인 또는 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('Google로 계속하기'), findsOneWidget);

    await tester.tap(find.text('Google로 계속하기'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 설정'), findsOneWidget);

    final completeButton = find.text('완료');
    await tester.ensureVisible(completeButton);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '완료'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).first, '여행토끼');
    await tester.tap(find.text('[필수] 서비스 이용약관 동의'));
    await tester.tap(find.text('[필수] 개인정보 수집·이용 동의'));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '완료'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(completeButton);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

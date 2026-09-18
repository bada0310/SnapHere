import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/data/fake_auth_repository.dart';
import 'package:snap_here/src/features/auth/data/google_identity_client.dart';
import 'package:snap_here/src/features/auth/data/session_store.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/domain/auth_repository.dart';

class _FailedIdentity extends FakeGoogleIdentityClient {
  const _FailedIdentity({required this.cancelled});
  final bool cancelled;
  @override
  Future<GoogleIdentityCredential> signIn() async =>
      throw AuthFailure('인증 실패', isCancellation: cancelled);
}

const _activeSession = AuthSession.authenticated(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  user: AuthUser(
    id: 'user-1',
    email: 'test@example.test',
    needsProfileSetup: false,
  ),
);

class _LogoutRepository extends FakeAuthRepository {
  Future<void> Function()? endSession;
  final signedOutTokens = <String>[];
  int refreshCalls = 0;

  @override
  Future<AuthSession> refreshSession(String refreshToken) async {
    refreshCalls++;
    return _activeSession;
  }

  @override
  Future<void> signOut(String accessToken) async {
    signedOutTokens.add(accessToken);
    await endSession?.call();
  }
}

class _LogoutIdentity extends FakeGoogleIdentityClient {
  Future<void> Function()? endSession;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await endSession?.call();
  }
}

class _LogoutStore extends MemorySessionStore {
  bool failClear = false;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    if (failClear) throw StateError('secure storage unavailable');
    await super.clear();
  }
}

void main() {
  Future<
    ({
      ProviderContainer container,
      _LogoutRepository repository,
      _LogoutIdentity identity,
      _LogoutStore store,
    })
  >
  logoutFixture({AuthSession session = _activeSession}) async {
    final repository = _LogoutRepository();
    final identity = _LogoutIdentity();
    final store = _LogoutStore();
    await store.write(session);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        googleIdentityClientProvider.overrideWithValue(identity),
        sessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return (
      container: container,
      repository: repository,
      identity: identity,
      store: store,
    );
  }

  test(
    'logout ends both external sessions and removes the saved login',
    () async {
      final fixture = await logoutFixture();
      final result = await fixture.container
          .read(authControllerProvider.notifier)
          .signOut();

      expect(result.serverSessionEnded, isTrue);
      expect(result.googleSessionEnded, isTrue);
      expect(fixture.repository.signedOutTokens, ['test-access']);
      expect(fixture.identity.signOutCalls, 1);
      expect(fixture.container.read(authControllerProvider).value, isNull);
      expect(await fixture.store.read(), isNull);
    },
  );

  for (final failure in [
    const ApiException('expired token', statusCode: 401),
    const ApiException('server unavailable', statusCode: 500),
    StateError('offline'),
  ]) {
    test(
      'server logout failure $failure still clears the app and Google sessions',
      () async {
        final fixture = await logoutFixture();
        fixture.repository.endSession = () async => throw failure;
        final result = await fixture.container
            .read(authControllerProvider.notifier)
            .signOut();

        expect(result.serverSessionEnded, isFalse);
        expect(result.googleSessionEnded, isTrue);
        expect(fixture.identity.signOutCalls, 1);
        expect(fixture.container.read(authControllerProvider).value, isNull);
        expect(await fixture.store.read(), isNull);

        // 재시작 때 저장된 이전 세션을 복원하지 않는다.
        fixture.container.invalidate(authControllerProvider);
        expect(
          await fixture.container.read(authControllerProvider.future),
          isNull,
        );
        expect(fixture.repository.refreshCalls, 1);
      },
    );
  }

  test('Google logout failure still revokes the server session and clears local login', () async {
    final fixture = await logoutFixture();
    fixture.identity.endSession = () async =>
        throw StateError('Google initialization failed');
    final result = await fixture.container
        .read(authControllerProvider.notifier)
        .signOut();

    expect(result.serverSessionEnded, isTrue);
    expect(result.googleSessionEnded, isFalse);
    expect(fixture.repository.signedOutTokens, ['test-access']);
    expect(fixture.container.read(authControllerProvider).value, isNull);
    expect(await fixture.store.read(), isNull);
  });

  testWidgets(
    'unresponsive external services time out together and late failures do not restore login',
    (tester) async {
      final fixture = await logoutFixture();
      final serverGate = Completer<void>();
      final googleGate = Completer<void>();
      fixture.repository.endSession = () => serverGate.future;
      fixture.identity.endSession = () => googleGate.future;

      final logout = fixture.container
          .read(authControllerProvider.notifier)
          .signOut();
      await tester.pump();
      expect(await fixture.store.read(), isNull);
      expect(fixture.repository.signedOutTokens, ['test-access']);
      expect(fixture.identity.signOutCalls, 1);

      await tester.pump(const Duration(seconds: 5));
      final result = await logout;
      expect(result.serverSessionEnded, isFalse);
      expect(result.googleSessionEnded, isFalse);
      expect(fixture.container.read(authControllerProvider).value, isNull);

      serverGate.completeError(StateError('late server failure'));
      googleGate.completeError(StateError('late Google failure'));
      await tester.pump();
      expect(fixture.container.read(authControllerProvider).value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'concurrent logout calls share one session deletion and external cleanup',
    () async {
      final fixture = await logoutFixture();
      final serverGate = Completer<void>();
      fixture.repository.endSession = () => serverGate.future;
      final controller = fixture.container.read(
        authControllerProvider.notifier,
      );
      final first = controller.signOut();
      final second = controller.signOut();
      expect(identical(first, second), isTrue);
      serverGate.complete();
      await Future.wait([first, second]);

      expect(fixture.store.clearCalls, 1);
      expect(fixture.repository.signedOutTokens, ['test-access']);
      expect(fixture.identity.signOutCalls, 1);
    },
  );

  test(
    'failed secure-store deletion is reported and logout can be retried',
    () async {
      final fixture = await logoutFixture();
      fixture.store.failClear = true;
      final controller = fixture.container.read(
        authControllerProvider.notifier,
      );
      await expectLater(controller.signOut(), throwsA(isA<AuthFailure>()));
      expect(
        fixture.container.read(authControllerProvider).value?.isAuthenticated,
        isTrue,
      );
      expect((await fixture.store.read())?.accessToken, 'test-access');
      expect(fixture.repository.signedOutTokens, isEmpty);
      expect(fixture.identity.signOutCalls, 0);

      fixture.store.failClear = false;
      await controller.signOut();
      expect(fixture.container.read(authControllerProvider).value, isNull);
      expect(await fixture.store.read(), isNull);
    },
  );

  test(
    'confirmed all-device logout only needs local and Google cleanup',
    () async {
      final fixture = await logoutFixture();
      final result = await fixture.container
          .read(authControllerProvider.notifier)
          .signOut(serverSessionAlreadyEnded: true);
      expect(result.serverSessionEnded, isTrue);
      expect(fixture.repository.signedOutTokens, isEmpty);
      expect(fixture.identity.signOutCalls, 1);
      expect(fixture.container.read(authControllerProvider).value, isNull);
      expect(await fixture.store.read(), isNull);
    },
  );

  test('guest logout does not initialize external sign-in services', () async {
    final fixture = await logoutFixture(session: const AuthSession.guest());
    await fixture.container.read(authControllerProvider.notifier).signOut();
    expect(fixture.repository.signedOutTokens, isEmpty);
    expect(fixture.identity.signOutCalls, 0);
    expect(fixture.container.read(authControllerProvider).value, isNull);
    expect(await fixture.store.read(), isNull);
  });

  for (final cancelled in [true, false]) {
    test(
      'guest session survives Google ${cancelled ? 'cancellation' : 'failure'}',
      () async {
        final store = MemorySessionStore();
        await store.write(const AuthSession.guest());
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            googleIdentityClientProvider.overrideWithValue(
              _FailedIdentity(cancelled: cancelled),
            ),
            sessionStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        await container.read(authControllerProvider.future);
        final completed = await container
            .read(authControllerProvider.notifier)
            .signInWithGoogle();
        expect(completed, isFalse);
        expect(container.read(authControllerProvider).value?.isGuest, true);
        expect(container.read(authControllerProvider).hasError, !cancelled);
        expect((await store.read())?.isGuest, true);
      },
    );
  }
  test(
    'Google sign-in and profile completion persist an active session',
    () async {
      final store = MemorySessionStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          googleIdentityClientProvider.overrideWithValue(
            const FakeGoogleIdentityClient(),
          ),
          sessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);

      expect(await controller.signInWithGoogle(), isTrue);
      expect(
        container.read(authControllerProvider).value?.user?.needsProfileSetup,
        isTrue,
      );

      await controller.completeProfile(
        ProfileSubmission(
          nickname: '여행토끼',
          bio: null,
          consents: ConsentRecord(
            termsVersion: 'terms-1',
            privacyVersion: 'privacy-1',
            marketingAccepted: false,
            acceptedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
      );

      final active = container.read(authControllerProvider).requireValue;
      expect(active?.user?.needsProfileSetup, isFalse);
      expect(active?.user?.nickname, '여행토끼');
      expect((await store.read())?.accessToken, active?.accessToken);

      await controller.deleteAccount(contentAction: 'KEEP_ANONYMIZED');
      expect(container.read(authControllerProvider).value, isNull);
      expect(await store.read(), isNull);
    },
  );
}

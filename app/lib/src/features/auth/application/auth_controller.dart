import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/data/api_auth_repository.dart';
import 'package:snap_here/src/features/auth/data/fake_auth_repository.dart';
import 'package:snap_here/src/features/auth/data/google_identity_client.dart';
import 'package:snap_here/src/features/auth/data/session_store.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/domain/auth_repository.dart';

const _useFakeAuth = bool.fromEnvironment('USE_FAKE_AUTH', defaultValue: false);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => _useFakeAuth ? FakeAuthRepository() : ApiAuthRepository(),
);

final googleIdentityClientProvider = Provider<GoogleIdentityClient>(
  (ref) => _useFakeAuth
      ? const FakeGoogleIdentityClient()
      : AndroidGoogleIdentityClient(),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final legalDocumentRepositoryProvider = Provider<LegalDocumentRepository>(
  (ref) => FakeLegalDocumentRepository(),
);

final legalDocumentProvider =
    FutureProvider.family<LegalDocument, LegalDocumentType>(
      (ref, type) => ref.watch(legalDocumentRepositoryProvider).fetch(type),
    );

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);
  Future<SignOutResult>? _signOutOperation;

  @override
  Future<AuthSession?> build() async {
    final saved = await _store.read();
    if (saved == null || saved.isGuest) return saved;
    if (_useFakeAuth) return saved;
    final refreshToken = saved.refreshToken;
    if (refreshToken == null) {
      await _store.clear();
      return null;
    }
    try {
      final refreshed = await _repository.refreshSession(refreshToken);
      await _store.write(refreshed);
      return refreshed;
    } on Object {
      await _store.clear();
      return null;
    }
  }

  Future<bool> signInWithGoogle() async {
    final previous = state.value;
    state = const AsyncLoading();
    try {
      final credential = await ref.read(googleIdentityClientProvider).signIn();
      final session = await _repository.exchangeGoogleCredential(credential);
      await _store.write(session);
      state = AsyncData(session);
      return true;
    } on AuthFailure catch (error, stackTrace) {
      if (error.isCancellation) {
        state = AsyncData(previous);
        return false;
      }
      state = AsyncError(error, stackTrace);
    } on Object catch (error, stackTrace) {
      state = AsyncError(const AuthFailure('로그인 중 오류가 발생했습니다.'), stackTrace);
    }
    return false;
  }

  Future<void> continueAsGuest() async {
    const session = AuthSession.guest();
    await _store.write(session);
    state = const AsyncData(session);
  }

  Future<void> completeProfile(ProfileSubmission submission) async {
    final current = state.value;
    final accessToken = current?.accessToken;
    final refreshToken = current?.refreshToken;
    if (accessToken == null || refreshToken == null) {
      state = AsyncError(
        const AuthFailure('로그인 세션이 만료되었습니다. 다시 로그인해 주세요.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    try {
      final session = await _repository.completeProfile(
        accessToken: accessToken,
        refreshToken: refreshToken,
        submission: submission,
      );
      await _store.write(session);
      state = AsyncData(session);
    } on Object catch (error, stackTrace) {
      final failure = error is AuthFailure
          ? error
          : const AuthFailure('프로필 저장에 실패했습니다.');
      state = AsyncData(current);
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

  Future<SignOutResult> signOut({bool serverSessionAlreadyEnded = false}) {
    return _signOutOperation ??= _performSignOut(
      serverSessionAlreadyEnded: serverSessionAlreadyEnded,
    ).whenComplete(() => _signOutOperation = null);
  }

  Future<SignOutResult> _performSignOut({
    required bool serverSessionAlreadyEnded,
  }) async {
    final current = state.value;
    final accessToken = current?.accessToken;
    final repository = _repository;
    final identity = ref.read(googleIdentityClientProvider);
    try {
      await _store.clear();
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AuthFailure('기기에 저장된 로그인 정보를 지우지 못했어요. 다시 시도해 주세요.'),
        stackTrace,
      );
    }

    // 한 서비스의 실패가 다른 서비스나 로컬 로그아웃을 막지 않도록 한다.
    final ended = await Future.wait([
      if (accessToken == null || serverSessionAlreadyEnded)
        Future.value(true)
      else
        _tryEndSession(() => repository.signOut(accessToken)),
      if (current?.isAuthenticated == true)
        _tryEndSession(identity.signOut)
      else
        Future.value(true),
    ]);
    state = const AsyncData(null);
    return SignOutResult(
      serverSessionEnded: ended[0],
      googleSessionEnded: ended[1],
    );
  }

  Future<bool> _tryEndSession(Future<void> Function() endSession) async {
    try {
      await endSession().timeout(const Duration(seconds: 5));
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> deleteAccount({required String contentAction}) async {
    final current = state.value;
    final accessToken = current?.accessToken;
    if (accessToken == null) {
      throw const AuthFailure('삭제할 로그인 계정이 없습니다.');
    }
    state = const AsyncLoading();
    try {
      await _repository.deleteAccount(
        accessToken,
        contentAction: contentAction,
      );
      await ref.read(googleIdentityClientProvider).disconnect();
      await _store.clear();
      state = const AsyncData(null);
    } on Object catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(
        error is AuthFailure ? error : const AuthFailure('계정 삭제에 실패했습니다.'),
        stackTrace,
      );
    }
  }
}

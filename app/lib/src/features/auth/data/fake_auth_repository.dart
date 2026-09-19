import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/domain/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AuthUser? _registeredUser;

  @override
  Future<AuthSession> exchangeGoogleCredential(
    GoogleIdentityCredential credential,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final user =
        _registeredUser ??
        AuthUser(
          id: credential.subject,
          email: credential.email,
          displayName: credential.displayName,
          photoUrl: credential.photoUrl,
          needsProfileSetup: true,
        );
    return AuthSession.authenticated(
      accessToken: 'fake-access-token-${credential.subject}',
      refreshToken: 'fake-refresh-token-${credential.subject}',
      user: user,
    );
  }

  @override
  Future<AuthSession> completeProfile({
    required String accessToken,
    required String refreshToken,
    required ProfileSubmission submission,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final current = _registeredUser;
    _registeredUser = AuthUser(
      id: current?.id ?? 'google-demo-user',
      email: current?.email ?? 'traveler@example.com',
      displayName: current?.displayName,
      photoUrl: current?.photoUrl,
      nickname: submission.nickname,
      bio: submission.bio,
      needsProfileSetup: false,
    );
    return AuthSession.authenticated(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: _registeredUser!,
    );
  }

  @override
  Future<AuthSession> refreshSession(String refreshToken) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final user = _registeredUser;
    if (user == null) {
      throw const AuthFailure('저장된 데모 세션이 만료되었습니다.');
    }
    return AuthSession.authenticated(
      accessToken: 'refreshed-fake-access-token',
      refreshToken: refreshToken,
      user: user,
    );
  }

  @override
  Future<void> signOut(String accessToken) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> deleteAccount(
    String accessToken, {
    required String contentAction,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _registeredUser = null;
  }
}

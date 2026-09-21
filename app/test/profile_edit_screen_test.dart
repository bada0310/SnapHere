import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/profile/application/profile_providers.dart';
import 'package:snap_here/src/features/profile/data/api_profile_repository.dart';
import 'package:snap_here/src/features/profile/domain/profile_models.dart';
import 'package:snap_here/src/features/profile/presentation/profile_edit_screen.dart';

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

class _ProfileRepository extends ApiProfileRepository {
  String? nickname;
  String? bio;

  @override
  Future<ProfileSnapshot> fetchMe() async => _snapshot;

  @override
  Future<ProfileSnapshot> updateProfile({
    required String nickname,
    required String? bio,
  }) async {
    this.nickname = nickname;
    this.bio = bio;
    return _snapshot;
  }
}

const _snapshot = ProfileSnapshot(
  userId: 'u1',
  nickname: '기존닉네임',
  bio: '기존 소개',
  stats: ProfileStats(
    postCount: 1,
    followerCount: 2,
    followingCount: 3,
    badgeCount: 4,
  ),
);

void main() {
  testWidgets('기존 회원은 가입 약관 화면 없이 프로필을 편집한다', (tester) async {
    final repository = _ProfileRepository();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileEditScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_ReadyAuth.new),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('프로필 편집'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.first).controller!.text, '기존닉네임');
    await tester.enterText(fields.first, '새닉네임');
    await tester.enterText(fields.last, '새 소개');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repository.nickname, '새닉네임');
    expect(repository.bio, '새 소개');
    expect(tester.takeException(), isNull);
  });
}

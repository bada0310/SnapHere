import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app.dart';
import 'package:snap_here/src/app/router/app_router.dart';
import 'package:snap_here/src/app/router/login_navigation.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/activity/application/activity_providers.dart';
import 'package:snap_here/src/features/activity/data/api_activity_repository.dart';
import 'package:snap_here/src/features/activity/domain/activity_models.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/domain/auth_repository.dart';
import 'package:snap_here/src/features/auth/presentation/login_required_screen.dart';
import 'package:snap_here/src/features/auth/presentation/login_screen.dart';
import 'package:snap_here/src/features/auth/presentation/onboarding_screen.dart';
import 'package:snap_here/src/features/badges/presentation/badge_collection_screen.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/community/application/community_providers.dart';
import 'package:snap_here/src/features/community/data/fake_community_repository.dart';
import 'package:snap_here/src/features/community/presentation/tag_posts_screen.dart';
import 'package:snap_here/src/features/explore/application/explore_providers.dart';
import 'package:snap_here/src/features/home/presentation/home_screen.dart';
import 'package:snap_here/src/features/map/application/map_configuration.dart';
import 'package:snap_here/src/features/notification/presentation/notification_screen.dart';
import 'package:snap_here/src/features/notification/application/notification_providers.dart';
import 'package:snap_here/src/features/notification/data/empty_notification_repository.dart';
import 'package:snap_here/src/features/notification/domain/notification_models.dart';
import 'package:snap_here/src/features/profile/application/profile_providers.dart';
import 'package:snap_here/src/features/profile/data/api_profile_repository.dart';
import 'package:snap_here/src/features/profile/domain/profile_models.dart';
import 'package:snap_here/src/features/profile/presentation/profile_screen.dart';
import 'package:snap_here/src/features/post/application/post_providers.dart';
import 'package:snap_here/src/features/post/data/fake_post_repository.dart';
import 'package:snap_here/src/features/post/presentation/comments_screen.dart';
import 'package:snap_here/src/features/post/presentation/post_detail_screen.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/social/presentation/connections_screen.dart';
import 'package:snap_here/src/features/settings/application/settings_providers.dart';
import 'package:snap_here/src/features/settings/domain/app_locale.dart';
import 'package:snap_here/src/features/settings/presentation/settings_screen.dart';
import 'package:snap_here/src/features/settings/presentation/widgets/settings_section.dart';

class _GuestAuth extends AuthController {
  Completer<void>? signOutGate;
  int signOutCalls = 0;
  SignOutResult signOutResult = const SignOutResult();
  bool serverSessionAlreadyEnded = false;

  @override
  Future<AuthSession?> build() async => const AuthSession.guest();

  @override
  Future<bool> signInWithGoogle() async => false;

  void finishLogin() => state = const AsyncData(
    AuthSession.authenticated(
      accessToken: 'test',
      refreshToken: 'test',
      user: AuthUser(
        id: 'u1',
        email: 'test@example.test',
        needsProfileSetup: false,
      ),
    ),
  );

  @override
  Future<SignOutResult> signOut({
    bool serverSessionAlreadyEnded = false,
  }) async {
    signOutCalls++;
    this.serverSessionAlreadyEnded = serverSessionAlreadyEnded;
    if (signOutGate case final gate?) await gate.future;
    state = const AsyncData(null);
    return signOutResult;
  }
}

class _LogoutActivity extends ApiActivityRepository {
  _LogoutActivity({this.fail = false}) : super(accessToken: 'test');

  final bool fail;
  int calls = 0;

  @override
  Future<void> logoutAllDevices() async {
    calls++;
    if (fail) throw const ActivityFailure('네트워크에 연결할 수 없어요.');
  }
}

class _ReadySettings extends UserSettingsController {
  @override
  Future<UserSettings> build() async => const UserSettings(
    locale: AppLocale.ko,
    notifications: NotificationPreferences(),
  );
}

class _NavigationNotifications extends EmptyNotificationRepository {
  const _NavigationNotifications();

  @override
  Future<CursorPage<AppNotification>> fetchNotifications({
    String? cursor,
  }) async => const CursorPage(
    items: [
      AppNotification(
        notificationId: 'test-follow',
        type: NotificationType.follow,
        target: NotificationTarget.user,
        targetId: 'u2',
        messageKey: 'notification.follow',
        messageParams: {'actorNickname': '제주사진가'},
        isRead: true,
      ),
      AppNotification(
        notificationId: 'test-badge',
        type: NotificationType.badgeEarned,
        target: NotificationTarget.badge,
        messageKey: 'notification.badge.earned',
        messageParams: {'badgeName': '테스트 행사'},
        isRead: true,
      ),
      AppNotification(
        notificationId: 'test-post',
        type: NotificationType.postLike,
        target: NotificationTarget.post,
        targetId: 'pst_1',
        messageKey: 'notification.post.like',
        messageParams: {'actorNickname': '테스트 작성자'},
        isRead: true,
      ),
    ],
  );
}

class _Profiles extends ApiProfileRepository {
  ProfileSnapshot profile(String id) => ProfileSnapshot(
    userId: id,
    nickname: '테스트 여행자',
    stats: const ProfileStats(
      postCount: 0,
      followerCount: 1,
      followingCount: 2,
      badgeCount: 0,
    ),
  );
  @override
  Future<ProfileSnapshot> fetchMe() async => profile('u1');
  @override
  Future<ProfileSnapshot> fetchUser(String userId) async => profile(userId);
  @override
  Future<CursorPage<CommunityPost>> fetchPosts(
    String userId, {
    String? cursor,
  }) async => const CursorPage(items: []);
}

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Size size = const Size(412, 893),
    bool withTagFixture = false,
    bool withSearchUserFixture = false,
    _LogoutActivity? logoutActivity,
    bool withNotificationFixture = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_GuestAuth.new),
        mapConfiguredProvider.overrideWith((_) async => false),
        mapRegionsProvider.overrideWith((_) async => const []),
        profileRepositoryProvider.overrideWithValue(_Profiles()),
        userSettingsProvider.overrideWith(_ReadySettings.new),
        if (withNotificationFixture)
          notificationRepositoryProvider.overrideWithValue(
            const _NavigationNotifications(),
          ),
        if (logoutActivity != null)
          activityRepositoryProvider.overrideWithValue(logoutActivity),
        if (withTagFixture) ...[
          postRepositoryProvider.overrideWithValue(FakePostRepository()),
          communityRepositoryProvider.overrideWithValue(
            FakeCommunityRepository(),
          ),
        ],
        if (withSearchUserFixture)
          communitySearchResultProvider.overrideWith(
            (_) async => const CommunitySearchResult(
              posts: [],
              totalCount: 1,
              users: [SearchedUser(userId: 'u2', nickname: '검색 여행자')],
            ),
          ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SnapHereApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  test('login return locations stay inside the app and avoid entry loops', () {
    for (final value in [
      null,
      '',
      'https://example.test',
      '//example.test',
      '/login',
      '/login-required',
      '/profile-setup',
      '/onboarding',
      r'/\example.test',
    ]) {
      expect(loginReturnLocation(value), '/home');
    }
    expect(loginReturnLocation('/users/u2?tab=posts'), '/users/u2?tab=posts');
  });

  testWidgets(
    'guest My prompt preserves home and opens a reachable login screen',
    (tester) async {
      final container = await mount(tester);
      final router = container.read(appRouterProvider);
      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginRequiredScreen), findsOneWidget);
      expect(find.text('전북 게시글'), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('로그인하러 가기'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Google로 계속하기'), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byType(LoginScreen)))
            .uri
            .queryParameters['from'],
        '/profile',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public profile follow prompt cancels back to the same profile', (
    tester,
  ) async {
    final container = await mount(tester);
    final router = container.read(appRouterProvider);
    router.push('/users/u2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LoginRequiredScreen>(find.byType(LoginRequiredScreen))
          .returnTo,
      '/users/u2',
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(
      GoRouterState.of(tester.element(find.text('테스트 여행자'))).uri.path,
      '/users/u2',
    );
    expect(find.text('테스트 여행자'), findsOneWidget);
  });

  testWidgets(
    'search to post to tag opens tag posts without duplicate navigator keys',
    (tester) async {
      final container = await mount(tester, withTagFixture: true);
      final router = container.read(appRouterProvider);
      router.go('/community/search');
      await tester.pumpAndSettle();
      router.push('/photos/pst_1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026 전주 한옥마을 봄축제'));
      await tester.pumpAndSettle();
      expect(find.byType(TagPostsScreen), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byType(TagPostsScreen))).uri.path,
        '/tags/tag_1',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('post detail author opens profile without duplicate shell keys', (
    tester,
  ) async {
    final container = await mount(tester, withTagFixture: true);
    final router = container.read(appRouterProvider);
    router.push('/photos/pst_1');
    await tester.pumpAndSettle();
    final authorAvatar = find.descendant(
      of: find.byType(PostDetailScreen),
      matching: find.byType(ProfileAvatar),
    );
    await tester.tap(authorAvatar.first);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final searchLocation in ['/search', '/community/search']) {
    testWidgets('search user opens profile from $searchLocation', (
      tester,
    ) async {
      final container = await mount(tester, withSearchUserFixture: true);
      container.read(appRouterProvider).push(searchLocation);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '여행자');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('검색 여행자'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('post detail comments open without duplicate parent page keys', (
    tester,
  ) async {
    final container = await mount(tester, withTagFixture: true);
    container.read(appRouterProvider).push('/photos/pst_1');
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('댓글 28개'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('댓글 28개'));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile opens badges and follower list inside its shell', (
    tester,
  ) async {
    final container = await mount(tester);
    (container.read(authControllerProvider.notifier) as _GuestAuth)
        .finishLogin();
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('수집한 뱃지').first);
    await tester.pumpAndSettle();
    expect(find.byType(BadgeCollectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go('/users/u2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 팔로워'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow notification opens the sender profile', (tester) async {
    final container = await mount(tester, withNotificationFixture: true);
    (container.read(authControllerProvider.notifier) as _GuestAuth)
        .finishLogin();
    await tester.pumpAndSettle();
    container.read(appRouterProvider).push('/notifications');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationScreen), findsOneWidget);
    await tester.tap(find.text('제주사진가님이 팔로우했어요'));
    await tester.pumpAndSettle();
    expect(find.text('테스트 여행자'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('badge notification opens the badge collection', (tester) async {
    final container = await mount(tester, withNotificationFixture: true);
    (container.read(authControllerProvider.notifier) as _GuestAuth)
        .finishLogin();
    await tester.pumpAndSettle();
    container.read(appRouterProvider).push('/notifications');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationScreen), findsOneWidget);
    await tester.tap(find.text('테스트 행사 뱃지를 획득했어요!'));
    await tester.pumpAndSettle();
    expect(find.text('수집한 뱃지'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post notification opens detail and returns to notifications', (
    tester,
  ) async {
    final container = await mount(
      tester,
      withTagFixture: true,
      withNotificationFixture: true,
    );
    (container.read(authControllerProvider.notifier) as _GuestAuth)
        .finishLogin();
    await tester.pumpAndSettle();
    container.read(appRouterProvider).push('/notifications');
    await tester.pumpAndSettle();
    await tester.tap(find.text('테스트 작성자님이 회원님의 게시글을 좋아합니다'));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationScreen), findsOneWidget);
  });

  testWidgets(
    'default notification inbox has no sample notifications or unread count',
    (tester) async {
      final container = await mount(tester);
      (container.read(authControllerProvider.notifier) as _GuestAuth)
          .finishLogin();
      await tester.pumpAndSettle();
      container.read(appRouterProvider).push('/notifications');
      await tester.pumpAndSettle();

      expect(find.text('아직 알림이 없어요'), findsOneWidget);
      expect(await container.read(notificationsProvider.future), isEmpty);
      expect(await container.read(unreadNotificationCountProvider.future), 0);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '모두 읽음'))
            .onPressed,
        isNull,
      );
      container.invalidate(notificationRepositoryProvider);
      await tester.pumpAndSettle();
      expect(await container.read(notificationsProvider.future), isEmpty);
      expect(find.text('아직 알림이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings logout immediately shows progress and completion', (
    tester,
  ) async {
    final container = await mount(tester);
    final auth = container.read(authControllerProvider.notifier) as _GuestAuth;
    auth.finishLogin();
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    final gate = Completer<void>();
    auth.signOutGate = gate;
    await tester.tap(find.text('로그아웃').first);
    await tester.pump();
    expect(auth.signOutCalls, 1);
    expect(find.text('로그아웃 중...'), findsOneWidget);
    expect(
      tester
          .widget<SettingsRow>(find.widgetWithText(SettingsRow, '모든 기기에서 로그아웃'))
          .enabled,
      isFalse,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('로그아웃했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial logout still leaves settings and reports the unconfirmed server session',
    (tester) async {
      final container = await mount(tester);
      final auth =
          container.read(authControllerProvider.notifier) as _GuestAuth;
      auth.finishLogin();
      auth.signOutResult = const SignOutResult(serverSessionEnded: false);
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('로그아웃').first);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('이 기기에서 로그아웃했어요. 서버 세션 종료는 확인하지 못했어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all-device logout confirms server revocation before local cleanup',
    (tester) async {
      final activity = _LogoutActivity();
      final container = await mount(tester, logoutActivity: activity);
      final auth =
          container.read(authControllerProvider.notifier) as _GuestAuth;
      auth.finishLogin();
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('모든 기기에서 로그아웃'));
      await tester.pumpAndSettle();
      expect(activity.calls, 1);
      expect(auth.signOutCalls, 1);
      expect(auth.serverSessionAlreadyEnded, isTrue);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('모든 기기에서 로그아웃했어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed all-device revocation keeps login and does not report success',
    (tester) async {
      final activity = _LogoutActivity(fail: true);
      final container = await mount(tester, logoutActivity: activity);
      final auth =
          container.read(authControllerProvider.notifier) as _GuestAuth;
      auth.finishLogin();
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('모든 기기에서 로그아웃'));
      await tester.pumpAndSettle();
      expect(activity.calls, 1);
      expect(auth.signOutCalls, 0);
      expect(
        container.read(authControllerProvider).value?.isAuthenticated,
        isTrue,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('네트워크에 연결할 수 없어요.'), findsOneWidget);
      expect(find.text('모든 기기에서 로그아웃했어요.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed session deletion displays a specific retry message', (
    tester,
  ) async {
    final container = await mount(tester);
    final auth = container.read(authControllerProvider.notifier) as _GuestAuth;
    auth.finishLogin();
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/settings');
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    auth.signOutGate = gate;
    await tester.tap(find.text('로그아웃').first);
    await tester.pump();
    gate.completeError(
      const AuthFailure('기기에 저장된 로그인 정보를 지우지 못했어요. 다시 시도해 주세요.'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('기기에 저장된 로그인 정보를 지우지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('로그아웃했어요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed settings logout restores the action and explains why', (
    tester,
  ) async {
    final container = await mount(tester);
    final auth = container.read(authControllerProvider.notifier) as _GuestAuth;
    auth.finishLogin();
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/settings');
    await tester.pumpAndSettle();

    final gate = Completer<void>();
    auth.signOutGate = gate;
    await tester.tap(find.text('로그아웃').first);
    await tester.pump();
    gate.completeError(StateError('sign-out failed'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('로그아웃하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<SettingsRow>(find.widgetWithText(SettingsRow, '로그아웃'))
          .enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('protected deep links stay guarded and resume only after login', (
    tester,
  ) async {
    final container = await mount(tester);
    final router = container.read(appRouterProvider);
    router.go('/profile');
    await tester.pumpAndSettle();
    expect(find.byType(LoginRequiredScreen), findsOneWidget);
    await tester.tap(find.text('로그인하러 가기'));
    await tester.pumpAndSettle();
    (container.read(authControllerProvider.notifier) as _GuestAuth)
        .finishLogin();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(find.text('테스트 여행자'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login actions remain reachable in a short landscape viewport', (
    tester,
  ) async {
    final container = await mount(tester, size: const Size(740, 320));
    container.read(appRouterProvider).push('/login');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Google로 계속하기'));
    await tester.pumpAndSettle();
    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an incomplete Google sign-in gives feedback without leaving login',
    (tester) async {
      final container = await mount(tester);
      container.read(appRouterProvider).push('/login');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('로그인이 완료되지 않았어요.'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(authControllerProvider).value?.isGuest, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

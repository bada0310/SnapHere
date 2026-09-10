import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/router/app_shell.dart';
import 'package:snap_here/src/app/router/login_navigation.dart';
import 'package:snap_here/src/core/ui/feature_placeholder.dart';
import 'package:snap_here/src/features/activity/presentation/my_activity_screen.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/presentation/legal_document_screen.dart';
import 'package:snap_here/src/features/auth/presentation/login_screen.dart';
import 'package:snap_here/src/features/auth/presentation/login_required_screen.dart';
import 'package:snap_here/src/features/auth/presentation/onboarding_screen.dart';
import 'package:snap_here/src/features/auth/presentation/profile_setup_screen.dart';
import 'package:snap_here/src/features/badges/presentation/badge_collection_screen.dart';
import 'package:snap_here/src/features/community/presentation/community_screen.dart';
import 'package:snap_here/src/features/community/presentation/community_search_screen.dart';
import 'package:snap_here/src/features/community/presentation/tag_posts_screen.dart';
import 'package:snap_here/src/features/event/presentation/event_detail_screen.dart';
import 'package:snap_here/src/features/event/presentation/event_screen.dart';
import 'package:snap_here/src/features/home/presentation/home_screen.dart';
import 'package:snap_here/src/features/map/presentation/map_screen.dart';
import 'package:snap_here/src/features/notification/presentation/notification_screen.dart';
import 'package:snap_here/src/features/place/presentation/place_detail_screen.dart';
import 'package:snap_here/src/features/post/presentation/comments_screen.dart';
import 'package:snap_here/src/features/post/presentation/post_detail_screen.dart';
import 'package:snap_here/src/features/region/presentation/region_screen.dart';
import 'package:snap_here/src/features/profile/presentation/profile_screen.dart';
import 'package:snap_here/src/features/rankings/presentation/rankings_screen.dart';
import 'package:snap_here/src/features/settings/presentation/settings_screen.dart';
import 'package:snap_here/src/features/social/data/api_social_repository.dart';
import 'package:snap_here/src/features/social/presentation/connections_screen.dart';
import 'package:snap_here/src/features/upload/presentation/upload_screen.dart';

final _authRouterRefreshProvider = Provider<_AuthRouterRefresh>((ref) {
  final refresh = _AuthRouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);
  return refresh;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_authRouterRefreshProvider);
  final router = GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refresh,
    redirect: (_, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null;

      final path = state.uri.path;
      final session = auth.value;
      final isLegal = path.startsWith('/legal/');
      final isEntry = path == '/onboarding' || path == '/login';

      if (session == null) {
        final canVisitWithoutSession =
            isEntry || isLegal || path == '/login-required';
        return canVisitWithoutSession ? null : '/onboarding';
      }

      if (session.isGuest) {
        if (path == '/onboarding' || path == '/profile-setup') return '/home';
        const guestProtected = {
          '/upload',
          '/notifications',
          '/profile',
          '/settings',
          '/me/activity',
        };
        if (guestProtected.contains(path) || path.startsWith('/profile/')) {
          return loginPromptLocation(state.uri.toString());
        }
        return null;
      }

      if (session.user!.needsProfileSetup) {
        if (path == '/profile-setup' || isLegal) return null;
        return Uri(
          path: '/profile-setup',
          queryParameters: {
            'from': loginReturnLocation(state.uri.queryParameters['from']),
          },
        ).toString();
      }

      if (isEntry || path == '/profile-setup' || path == '/login-required') {
        return loginReturnLocation(state.uri.queryParameters['from']);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/profile-setup',
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/login-required',
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          opaque: false,
          barrierColor: const Color(0x990F1720),
          barrierLabel: '로그인 안내',
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          child: LoginRequiredScreen(
            returnTo: state.uri.queryParameters['from'],
          ),
        ),
      ),
      GoRoute(
        path: '/legal/:type',
        builder: (_, state) {
          final type = LegalDocumentType.fromPath(
            state.pathParameters['type'] ?? '',
          );
          return LegalDocumentScreen(type: type);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          // Figma `Wireframe_v3`의 하단 탭 2번째 자리는 커뮤니티다.
          // 기존 랭킹은 아래 최상위 라우트로 남겨 두었다.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (_, _) => const CommunityScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (_, _) => const CommunitySearchScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/events', builder: (_, _) => const EventScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'badges',
                    builder: (_, _) => const BadgeCollectionScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/users/:userId',
                builder: (_, state) =>
                    ProfileScreen(userId: state.pathParameters['userId']!),
                routes: [
                  GoRoute(
                    path: 'followers',
                    builder: (_, state) => ConnectionsScreen(
                      userId: state.pathParameters['userId']!,
                      kind: ConnectionKind.followers,
                    ),
                  ),
                  GoRoute(
                    path: 'following',
                    builder: (_, state) => ConnectionsScreen(
                      userId: state.pathParameters['userId']!,
                      kind: ConnectionKind.following,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/upload',
        builder: (_, state) =>
            UploadScreen(eventId: state.uri.queryParameters['eventId']),
      ),
      GoRoute(
        path: '/events/:eventId',
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(path: '/map', builder: (_, _) => const MapScreen()),
      // 하단 탭 4번째는 Wireframe_v3 기준 이벤트로 확정했고 랭킹 화면은
      // 기존 딥 링크 호환을 위해 최상위 라우트로 유지한다.
      GoRoute(path: '/rankings', builder: (_, _) => const RankingsScreen()),
      // 통합 검색은 화면이 하나다. 커뮤니티 탭 안팎 어디서 들어와도 같은 화면을 쓴다
      // (API-SCH-001, SCH-009).
      GoRoute(
        path: '/search',
        builder: (_, _) => const CommunitySearchScreen(),
      ),
      GoRoute(
        path: '/tags/:tagId',
        builder: (_, state) => TagPostsScreen(
          tagId: state.pathParameters['tagId']!,
          tagName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/me/activity',
        builder: (_, state) => MyActivityScreen(
          initialTab: ActivityTab.fromName(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: '/regions/:regionId',
        builder: (_, state) => RegionScreen(
          areaCode: int.tryParse(state.pathParameters['regionId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/photos/:photoId',
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['photoId']!),
        routes: [
          GoRoute(
            path: 'comments',
            builder: (_, state) =>
                CommentsScreen(postId: state.pathParameters['photoId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/places/:placeId',
        builder: (_, state) =>
            PlaceDetailScreen(placeId: state.pathParameters['placeId']!),
      ),
      GoRoute(
        path: '/k-culture',
        builder: (_, _) => const FeaturePlaceholder(
          title: 'K-컬처',
          description: '드라마, 영화, 예능 촬영지 피드와 테마별 랭킹을 제공합니다.',
          icon: Icons.movie_filter_outlined,
        ),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class _AuthRouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

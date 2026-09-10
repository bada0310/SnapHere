import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/profile/application/profile_providers.dart';
import 'package:snap_here/src/features/social/data/api_social_repository.dart';

final socialRepositoryProvider = Provider<ApiSocialRepository>(
  (ref) => ApiSocialRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  ),
);

typedef FollowStatus = ({bool following, bool busy});
final followStateProvider =
    NotifierProvider<FollowController, Map<String, FollowStatus>>(
      FollowController.new,
    );

class FollowController extends Notifier<Map<String, FollowStatus>> {
  @override
  Map<String, FollowStatus> build() {
    ref.watch(socialRepositoryProvider);
    return {};
  }

  Future<void> toggle(String userId, {required bool initialFollowing}) async {
    final current = state[userId] ?? (following: initialFollowing, busy: false);
    if (current.busy) return;
    final repository = ref.read(socialRepositoryProvider);
    state = {...state, userId: (following: current.following, busy: true)};
    try {
      final following = await repository.setFollowing(
        userId,
        following: !current.following,
      );
      if (!ref.mounted || repository != ref.read(socialRepositoryProvider)) {
        return;
      }
      state = {...state, userId: (following: following, busy: false)};
      ref.invalidate(profileSnapshotProvider);
      ref.invalidate(publicProfileProvider);
    } on Object {
      if (ref.mounted && repository == ref.read(socialRepositoryProvider)) {
        state = {...state, userId: (following: current.following, busy: false)};
      }
      rethrow;
    }
  }
}

/// 팔로잉 피드가 비었을 때 노출할 추천 사용자 (API-SOC-005).
final recommendedUsersProvider = FutureProvider<List<SocialUser>>(
  (ref) => ref.watch(socialRepositoryProvider).fetchRecommendations(),
);

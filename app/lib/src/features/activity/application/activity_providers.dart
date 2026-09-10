import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/activity/data/api_activity_repository.dart';
import 'package:snap_here/src/features/activity/domain/activity_models.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';

final activityRepositoryProvider = Provider<ApiActivityRepository>(
  (ref) => ApiActivityRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  ),
);

final likedPostsProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(activityRepositoryProvider).fetchLikedPosts(),
);

final bookmarkedPostsProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(activityRepositoryProvider).fetchBookmarkedPosts(),
);

final bookmarkedPlacesProvider = FutureProvider<List<PlaceSummary>>(
  (ref) => ref.watch(activityRepositoryProvider).fetchBookmarkedPlaces(),
);

final visitsProvider = FutureProvider<List<Visit>>(
  (ref) => ref.watch(activityRepositoryProvider).fetchVisits(),
);

final visitStatsProvider = FutureProvider<VisitStats>(
  (ref) => ref.watch(activityRepositoryProvider).fetchVisitStats(),
);

final recentPlacesProvider = FutureProvider<List<PlaceSummary>>(
  (ref) => ref.watch(activityRepositoryProvider).fetchRecentPlaces(),
);

final deletionPreviewProvider = FutureProvider<DeletionPreview>(
  (ref) => ref.watch(activityRepositoryProvider).fetchDeletionPreview(),
);

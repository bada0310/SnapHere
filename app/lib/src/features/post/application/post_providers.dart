import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/post/data/api_post_repository.dart';
import 'package:snap_here/src/features/post/data/fake_post_repository.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/domain/post_repository.dart';

const _useFakePosts = bool.fromEnvironment(
  'USE_FAKE_POSTS',
  defaultValue: false,
);

final postRepositoryProvider = Provider<PostRepository>((ref) {
  if (_useFakePosts) return FakePostRepository();
  return ApiPostRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  );
});

final postDetailProvider = FutureProvider.family<PostDetail, String>(
  (ref, postId) => ref.watch(postRepositoryProvider).fetchPost(postId),
);

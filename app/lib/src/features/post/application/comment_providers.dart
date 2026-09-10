import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/post/application/post_providers.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';

/// 커서 페이지는 첫 장만 읽는다. 더보기는 화면이 `PagedSliver`로 붙인다.
final commentThreadsProvider =
    FutureProvider.family<List<CommentThread>, String>((ref, postId) async {
      final page = await ref
          .watch(postRepositoryProvider)
          .fetchComments(postId);
      return page.items;
    });

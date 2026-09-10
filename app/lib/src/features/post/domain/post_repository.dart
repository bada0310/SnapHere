import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';

abstract interface class PostRepository {
  Future<PostDetail> fetchPost(String postId);

  /// 좋아요·저장은 멱등이다. 서버가 최종 상태를 돌려주므로 화면은 그 값을 따른다
  /// (API-PST-009~012).
  Future<({int likeCount, bool isLiked})> setLiked(String postId, bool liked);

  Future<bool> setBookmarked(String postId, bool bookmarked);

  Future<void> report(String postId, {required String reason, String? detail});

  Future<void> deletePost(String postId);

  Future<CursorPage<CommentThread>> fetchComments(
    String postId, {
    String? cursor,
  });

  Future<Comment> addComment(String postId, String content);

  Future<Comment> addReply(String commentId, String content);

  Future<Comment> editComment(String commentId, String content);

  Future<void> deleteComment(String commentId);

  /// 앱 설치 없이 열리는 공개 페이지 주소를 받는다 (API-PST-014).
  Future<ShareMetadata> fetchShareMetadata(String postId);
}

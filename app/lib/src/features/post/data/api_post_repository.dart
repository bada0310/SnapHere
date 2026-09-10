import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/domain/post_repository.dart';

class ApiPostRepository implements PostRepository {
  ApiPostRepository({this.accessToken, ApiClient? client})
    : _client = client ?? ApiClient();

  final String? accessToken;
  final ApiClient _client;

  @override
  Future<PostDetail> fetchPost(String postId) async =>
      PostDetail.fromJson(jsonMap(await _get('/posts/$postId')));

  @override
  Future<({int likeCount, bool isLiked})> setLiked(
    String postId,
    bool liked,
  ) async {
    final data = jsonMap(
      await _send(liked ? 'PUT' : 'DELETE', '/posts/$postId/like'),
    );
    return (
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      isLiked: data['isLiked'] as bool? ?? liked,
    );
  }

  @override
  Future<bool> setBookmarked(String postId, bool bookmarked) async {
    final data = jsonMap(
      await _send(bookmarked ? 'PUT' : 'DELETE', '/posts/$postId/bookmark'),
    );
    return data['isBookmarked'] as bool? ?? bookmarked;
  }

  @override
  Future<void> report(
    String postId, {
    required String reason,
    String? detail,
  }) => _guard(
    () => _client.post(
      '/posts/$postId/reports',
      body: {'reason': reason, 'detail': ?detail},
      accessToken: _requireToken(),
    ),
  );

  @override
  Future<void> deletePost(String postId) => _guard(
    () => _client.delete('/posts/$postId', accessToken: _requireToken()),
  );

  @override
  Future<CursorPage<CommentThread>> fetchComments(
    String postId, {
    String? cursor,
  }) async {
    final data = jsonMap(
      await _get('/posts/$postId/comments', query: {'cursor': ?cursor}),
    );
    return CursorPage(
      items: jsonMapList(data['items'])
          .map(CommentThread.fromJson)
          .toList(growable: false),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  @override
  Future<Comment> addComment(String postId, String content) async =>
      Comment.fromJson(
        jsonMap(
          await _guard(
            () => _client.post(
              '/posts/$postId/comments',
              body: {'content': content},
              accessToken: _requireToken(),
            ),
          ),
        ),
      );

  @override
  Future<Comment> addReply(String commentId, String content) async =>
      Comment.fromJson(
        jsonMap(
          await _guard(
            () => _client.post(
              '/comments/$commentId/replies',
              body: {'content': content},
              accessToken: _requireToken(),
            ),
          ),
        ),
      );

  @override
  Future<Comment> editComment(String commentId, String content) async =>
      Comment.fromJson(
        jsonMap(
          await _guard(
            () => _client.patch(
              '/comments/$commentId',
              body: {'content': content},
              accessToken: _requireToken(),
            ),
          ),
        ),
      );

  @override
  Future<void> deleteComment(String commentId) => _guard(
    () => _client.delete('/comments/$commentId', accessToken: _requireToken()),
  );

  @override
  Future<ShareMetadata> fetchShareMetadata(String postId) async =>
      ShareMetadata.fromJson(
        jsonMap(await _get('/public/posts/$postId/share-metadata')),
      );

  Future<Object?> _get(String path, {Map<String, String> query = const {}}) =>
      _guard(() => _client.get(path, query: query, accessToken: accessToken));

  Future<Object?> _send(String method, String path) =>
      _guard(() => _client.request(method, path, accessToken: _requireToken()));

  String _requireToken() {
    final token = accessToken;
    if (token == null) throw const PostFailure('로그인이 필요한 기능이에요.');
    return token;
  }

  /// 화면은 `ApiException`을 모른다. 도메인 예외로 바꿔 넘긴다.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (error) {
      throw PostFailure(error.message);
    } on PostFailure {
      rethrow;
    } on Object {
      throw const PostFailure('네트워크에 연결할 수 없어요.');
    }
  }
}

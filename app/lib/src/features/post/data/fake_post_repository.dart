import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/domain/post_repository.dart';

/// Figma `07_게시글_상세`와 `12 Comment CRUD Prototype`의 예시 값을 그대로 쓴다.
/// 디자인 검수와 백엔드 없이 도는 위젯 테스트가 같은 데이터를 보게 하려는 것이다.
class FakePostRepository implements PostRepository {
  FakePostRepository();

  static const _me = PostAuthor(userId: 'usr_me', nickname: '여행하는 너구리 (나)');

  PostDetail _post = PostDetail(
    postId: 'pst_1',
    author: const PostAuthor(userId: 'usr_1', nickname: '너구리여행자'),
    place: const PostPlace(
      placeId: 'plc_1',
      title: '전주 한옥마을',
      addr1: '전북 전주시',
      lat: 35.8150,
      lng: 127.1530,
    ),
    images: const [
      PostImage(postImageId: 'img_1', imageUrl: ''),
      PostImage(postImageId: 'img_2', imageUrl: ''),
      PostImage(postImageId: 'img_3', imageUrl: ''),
    ],
    content: '전주 한옥마을의 봄\n날씨 좋은 날 경복궁을 다녀왔어요. 근정전 앞 풍경에서 찍은 사진인데 마음에 드네요.',
    tags: const [
      PostTag(tagId: 'tag_1', name: '2026 전주 한옥마을 봄축제', locked: true),
    ],
    likeCount: 142,
    commentCount: 28,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    tierResult: const TierResult(
      tier: TrustTier.high,
      distanceM: 24,
      verifyRadiusM: 300,
      withinRadius: true,
      daysSinceTaken: 0,
    ),
    isLiked: false,
    isBookmarked: false,
  );

  final _threads = <CommentThread>[
    CommentThread(
      parent: Comment(
        commentId: 'cmt_1',
        postId: 'pst_1',
        author: _me,
        content: '봄날 풍경이 정말 좋았어요!',
        status: CommentStatus.active,
        likeCount: 3,
        createdAt: DateTime.now(),
      ),
      replies: const [],
    ),
    CommentThread(
      parent: Comment(
        commentId: 'cmt_2',
        postId: 'pst_1',
        author: const PostAuthor(userId: 'usr_2', nickname: 'seoul_trip'),
        content: '한옥마을은 해질 무렵도 예뻐요.',
        status: CommentStatus.active,
        likeCount: 12,
        createdAt: DateTime.now(),
      ),
      replies: [
        Comment(
          commentId: 'cmt_3',
          postId: 'pst_1',
          parentId: 'cmt_2',
          author: const PostAuthor(userId: 'usr_2', nickname: 'seoul_trip'),
          content: '해질 무렵도 꼭 가보세요!',
          status: CommentStatus.active,
          likeCount: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),
    CommentThread(
      parent: Comment(
        commentId: 'cmt_4',
        postId: 'pst_1',
        author: const PostAuthor(userId: 'usr_3', nickname: 'jeonju_local'),
        content: '주말에는 오전 방문을 추천해요!',
        status: CommentStatus.active,
        likeCount: 7,
        createdAt: DateTime.now(),
      ),
      replies: const [],
    ),
  ];

  var _nextId = 100;

  @override
  Future<PostDetail> fetchPost(String postId) async => _post;

  @override
  Future<({int likeCount, bool isLiked})> setLiked(
    String postId,
    bool liked,
  ) async {
    final count = _post.likeCount + (liked ? 1 : -1);
    _post = _post.copyWith(likeCount: count, isLiked: liked);
    return (likeCount: count, isLiked: liked);
  }

  @override
  Future<bool> setBookmarked(String postId, bool bookmarked) async {
    _post = _post.copyWith(isBookmarked: bookmarked);
    return bookmarked;
  }

  @override
  Future<void> report(
    String postId, {
    required String reason,
    String? detail,
  }) async {}

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<CursorPage<CommentThread>> fetchComments(
    String postId, {
    String? cursor,
  }) async => CursorPage(items: List.unmodifiable(_threads));

  @override
  Future<Comment> addComment(String postId, String content) async {
    final comment = _build(postId: postId, content: content);
    _threads.add(CommentThread(parent: comment, replies: const []));
    return comment;
  }

  @override
  Future<Comment> addReply(String commentId, String content) async {
    final index = _threads.indexWhere((t) => t.parent.commentId == commentId);
    if (index < 0) throw const PostFailure('원 댓글을 찾을 수 없어요.');
    final reply = _build(
      postId: _threads[index].parent.postId,
      content: content,
      parentId: commentId,
    );
    _threads[index] = _threads[index].copyWith(
      replies: [..._threads[index].replies, reply],
    );
    return reply;
  }

  @override
  Future<Comment> editComment(String commentId, String content) async {
    final updated = _mutate(commentId, (c) => c.copyWith(content: content));
    if (updated == null) throw const PostFailure('댓글을 찾을 수 없어요.');
    return updated;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    // 자식이 있으면 남기고 본문만 비운다 (CMU-017). 없으면 통째로 지운다.
    for (var index = 0; index < _threads.length; index++) {
      final thread = _threads[index];
      if (thread.parent.commentId == commentId) {
        if (thread.replies.isEmpty) {
          _threads.removeAt(index);
        } else {
          _threads[index] = thread.copyWith(parent: _erase(thread.parent));
        }
        return;
      }
      if (thread.replies.any((r) => r.commentId == commentId)) {
        _threads[index] = thread.copyWith(
          replies: thread.replies
              .where((r) => r.commentId != commentId)
              .toList(growable: false),
        );
        return;
      }
    }
  }

  Comment _build({
    required String postId,
    required String content,
    String? parentId,
  }) => Comment(
    commentId: 'cmt_${_nextId++}',
    postId: postId,
    author: _me,
    parentId: parentId,
    content: content,
    status: CommentStatus.active,
    likeCount: 0,
    createdAt: DateTime.now(),
  );

  Comment? _mutate(String commentId, Comment Function(Comment) change) {
    for (var index = 0; index < _threads.length; index++) {
      final thread = _threads[index];
      if (thread.parent.commentId == commentId) {
        final next = change(thread.parent);
        _threads[index] = thread.copyWith(parent: next);
        return next;
      }
      final replyIndex = thread.replies.indexWhere(
        (r) => r.commentId == commentId,
      );
      if (replyIndex >= 0) {
        final replies = [...thread.replies];
        replies[replyIndex] = change(replies[replyIndex]);
        _threads[index] = thread.copyWith(replies: replies);
        return replies[replyIndex];
      }
    }
    return null;
  }

  Comment _erase(Comment comment) => Comment(
    commentId: comment.commentId,
    postId: comment.postId,
    author: comment.author,
    parentId: comment.parentId,
    status: CommentStatus.deleted,
    likeCount: comment.likeCount,
    createdAt: comment.createdAt,
  );

  @override
  Future<ShareMetadata> fetchShareMetadata(String postId) async =>
      ShareMetadata(
        shareUrl: 'https://snaphere.app/p/$postId',
        title: _post.title,
        description: _post.body,
      );
}

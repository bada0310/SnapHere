import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/post/application/comment_composer.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/domain/post_repository.dart';

class _StubPostRepository implements PostRepository {
  _StubPostRepository({this.fail = false});

  final bool fail;
  final calls = <String>[];

  Comment _reply(String content) => Comment(
    commentId: 'c_new',
    postId: 'pst_1',
    author: const PostAuthor(userId: 'me', nickname: '나'),
    content: content,
    status: CommentStatus.active,
    likeCount: 0,
  );

  Comment _guard(String label, String content) {
    calls.add(label);
    if (fail) throw const PostFailure('전송에 실패했어요.');
    return _reply(content);
  }

  @override
  Future<Comment> addComment(String postId, String content) async =>
      _guard('addComment', content);

  @override
  Future<Comment> addReply(String commentId, String content) async =>
      _guard('addReply:$commentId', content);

  @override
  Future<Comment> editComment(String commentId, String content) async =>
      _guard('editComment:$commentId', content);

  @override
  Future<void> deleteComment(String commentId) async =>
      calls.add('deleteComment');

  @override
  Future<CursorPage<CommentThread>> fetchComments(
    String postId, {
    String? cursor,
  }) async => const CursorPage(items: []);

  @override
  Future<PostDetail> fetchPost(String postId) => throw UnimplementedError();

  @override
  Future<void> deletePost(String postId) => throw UnimplementedError();

  @override
  Future<void> report(
    String postId, {
    required String reason,
    String? detail,
  }) => throw UnimplementedError();

  @override
  Future<({int likeCount, bool isLiked})> setLiked(String postId, bool liked) =>
      throw UnimplementedError();

  @override
  Future<bool> setBookmarked(String postId, bool bookmarked) =>
      throw UnimplementedError();

  @override
  Future<ShareMetadata> fetchShareMetadata(String postId) async =>
      const ShareMetadata(shareUrl: 'https://snaphere.test/p/1', title: '테스트');
}

void main() {
  group('CommentComposer 상태 전이', () {
    test('기본은 새 댓글 작성이고 안내 줄이 없다', () {
      final composer = CommentComposer(_StubPostRepository(), 'pst_1');
      expect(composer.value.mode, ComposerMode.create);
      expect(composer.value.banner, isNull);
      expect(composer.value.submitLabel, '게시');
    });

    test('답글을 시작하면 대상과 안내 줄이 생긴다', () {
      final composer = CommentComposer(_StubPostRepository(), 'pst_1')
        ..startReply(parentId: 'c1', nickname: 'seoul_trip');
      expect(composer.value.mode, ComposerMode.reply);
      expect(composer.value.targetId, 'c1');
      expect(composer.value.banner, 'seoul_trip님에게 답글');
    });

    test('수정을 시작하면 버튼이 저장으로 바뀐다', () {
      final composer = CommentComposer(_StubPostRepository(), 'pst_1')
        ..startEdit(commentId: 'c1');
      expect(composer.value.isEditing, isTrue);
      expect(composer.value.submitLabel, '저장');
      expect(composer.value.banner, '댓글 수정 중');
    });

    test('취소하면 새 댓글 작성으로 돌아간다', () {
      final composer = CommentComposer(_StubPostRepository(), 'pst_1')
        ..startEdit(commentId: 'c1')
        ..cancel();
      expect(composer.value.mode, ComposerMode.create);
      expect(composer.value.targetId, isNull);
    });
  });

  group('CommentComposer 전송', () {
    test('모드마다 다른 API를 부른다', () async {
      final repository = _StubPostRepository();
      final composer = CommentComposer(repository, 'pst_1');

      await composer.submit('새 댓글');
      composer.startReply(parentId: 'c1', nickname: 'seoul_trip');
      await composer.submit('답글');
      composer.startEdit(commentId: 'c2');
      await composer.submit('고친 댓글');

      expect(repository.calls, ['addComment', 'addReply:c1', 'editComment:c2']);
    });

    test('성공하면 새 댓글 작성 상태로 되돌아간다', () async {
      final composer = CommentComposer(_StubPostRepository(), 'pst_1')
        ..startEdit(commentId: 'c1');
      final error = await composer.submit('고친 댓글');
      expect(error, isNull);
      expect(composer.value.mode, ComposerMode.create);
      expect(composer.value.isSubmitting, isFalse);
    });

    // Figma `07_댓글_작성중`의 "실패 시 입력 내용 보존" 주석을 지킨다.
    test('실패하면 모드와 대상을 그대로 두고 오류만 남긴다', () async {
      final composer = CommentComposer(_StubPostRepository(fail: true), 'pst_1')
        ..startReply(parentId: 'c1', nickname: 'seoul_trip');
      final error = await composer.submit('답글');

      expect(error, '전송에 실패했어요.');
      expect(composer.value.mode, ComposerMode.reply);
      expect(composer.value.targetId, 'c1');
      expect(composer.value.isSubmitting, isFalse);
      expect(composer.value.errorMessage, '전송에 실패했어요.');
    });

    test('빈 입력은 보내지 않는다', () async {
      final repository = _StubPostRepository();
      final composer = CommentComposer(repository, 'pst_1');
      expect(await composer.submit('   '), isNull);
      expect(repository.calls, isEmpty);
    });

    test('전송 중에는 두 번째 요청을 막는다', () async {
      final repository = _StubPostRepository();
      final composer = CommentComposer(repository, 'pst_1');
      final first = composer.submit('댓글');
      final second = await composer.submit('중복');
      await first;

      expect(second, isNull);
      expect(repository.calls, ['addComment']);
    });
  });
}

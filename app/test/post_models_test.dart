import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';

void main() {
  group('PostDetail 제목·본문 분리', () {
    // 서버에 제목 칼럼이 없고 업로드가 `제목\n본문`으로 합쳐 보낸다.
    PostDetail withContent(String content) => PostDetail(
      postId: 'pst_1',
      author: const PostAuthor(userId: 'u1', nickname: '너구리'),
      place: null,
      images: const [],
      content: content,
      tags: const [],
      likeCount: 0,
      commentCount: 0,
    );

    test('첫 줄을 제목으로, 나머지를 본문으로 나눈다', () {
      final post = withContent('전주 한옥마을의 봄\n날씨 좋은 날 다녀왔어요.');
      expect(post.title, '전주 한옥마을의 봄');
      expect(post.body, '날씨 좋은 날 다녀왔어요.');
    });

    test('본문이 여러 줄이면 줄바꿈을 보존한다', () {
      final post = withContent('제목\n첫 줄\n둘째 줄');
      expect(post.body, '첫 줄\n둘째 줄');
    });

    test('한 줄뿐이면 본문은 빈 문자열이다', () {
      final post = withContent('제목만 있는 글');
      expect(post.title, '제목만 있는 글');
      expect(post.body, isEmpty);
    });

    test('내용이 비어도 예외를 던지지 않는다', () {
      final post = withContent('');
      expect(post.title, isEmpty);
      expect(post.body, isEmpty);
    });
  });

  group('Comment 삭제 표시', () {
    Comment build({String? content, CommentStatus? status}) => Comment(
      commentId: 'c1',
      postId: 'pst_1',
      author: const PostAuthor(userId: 'u1', nickname: '너구리'),
      content: content,
      status: status ?? CommentStatus.active,
      likeCount: 0,
    );

    test('본문이 null이면 삭제된 댓글로 본다', () {
      expect(build().isDeleted, isTrue);
    });

    test('상태가 DELETED면 본문이 남아 있어도 삭제로 본다', () {
      expect(
        build(content: '내용', status: CommentStatus.deleted).isDeleted,
        isTrue,
      );
    });

    test('살아 있는 댓글은 삭제가 아니다', () {
      expect(build(content: '내용').isDeleted, isFalse);
    });
  });

  group('PostDetail.fromJson', () {
    test('place가 없어도 파싱된다', () {
      final post = PostDetail.fromJson(const {
        'summary': {
          'postId': 'pst_1',
          'author': {'userId': 'u1', 'nickname': '너구리'},
          'likeCount': 3,
          'commentCount': 2,
        },
        'content': '제목\n본문',
      });
      expect(post.place, isNull);
      expect(post.likeCount, 3);
      expect(post.images, isEmpty);
    });

    test('isLiked는 비회원이면 null로 남는다 — false와 다르다', () {
      final post = PostDetail.fromJson(const {
        'summary': {
          'postId': 'pst_1',
          'author': {'userId': 'u1', 'nickname': '너구리'},
        },
        'content': '제목',
      });
      expect(post.isLiked, isNull);
    });
  });
}

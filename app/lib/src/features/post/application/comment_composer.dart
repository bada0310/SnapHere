import 'package:flutter/foundation.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';
import 'package:snap_here/src/features/post/domain/post_repository.dart';

/// Figma `12 Comment CRUD Prototype`의 15개 프레임이 도는 상태다.
///
/// - `create` — `07_댓글_작성중`
/// - `reply` — `07_대댓글_작성중`
/// - `edit` — `07_댓글_수정중` · `07_대댓글_수정중`
enum ComposerMode { create, reply, edit }

@immutable
class CommentComposerState {
  const CommentComposerState({
    this.mode = ComposerMode.create,
    this.targetId,
    this.targetNickname,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final ComposerMode mode;

  /// `reply`면 부모 댓글 ID, `edit`면 고칠 댓글 ID다.
  final String? targetId;
  final String? targetNickname;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isEditing => mode == ComposerMode.edit;

  /// 목록 위에 뜨는 안내 줄. `create`일 때는 줄 자체가 없다.
  String? get banner => switch (mode) {
    ComposerMode.create => null,
    ComposerMode.reply => '${targetNickname ?? '댓글'}님에게 답글',
    ComposerMode.edit => '댓글 수정 중',
  };

  String get submitLabel => isEditing ? '저장' : '게시';

  String get hintText => switch (mode) {
    ComposerMode.create => '댓글 추가...',
    ComposerMode.reply => '답글을 입력하세요...',
    ComposerMode.edit => '댓글을 입력하세요...',
  };

  CommentComposerState copyWith({
    ComposerMode? mode,
    String? targetId,
    String? targetNickname,
    bool? isSubmitting,
    String? errorMessage,
    bool clearTarget = false,
    bool clearError = false,
  }) => CommentComposerState(
    mode: mode ?? this.mode,
    targetId: clearTarget ? null : targetId ?? this.targetId,
    targetNickname: clearTarget ? null : targetNickname ?? this.targetNickname,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

/// 입력창의 상태 전이와 전송만 맡는다. 목록 갱신은 화면이 `onChanged`로 받아
/// 프로바이더를 무효화한다 — 여기서 Riverpod을 알 필요가 없다.
class CommentComposer extends ValueNotifier<CommentComposerState> {
  CommentComposer(this._repository, this._postId)
    : super(const CommentComposerState());

  final PostRepository _repository;
  final String _postId;

  void startCreate() => value = const CommentComposerState();

  void startReply({required String parentId, required String nickname}) =>
      value = CommentComposerState(
        mode: ComposerMode.reply,
        targetId: parentId,
        targetNickname: nickname,
      );

  void startEdit({required String commentId}) => value = CommentComposerState(
    mode: ComposerMode.edit,
    targetId: commentId,
  );

  void cancel() => startCreate();

  /// 성공이면 null, 실패면 안내 문구를 돌려준다.
  ///
  /// 실패해도 입력 내용을 지우지 않는다 — Figma `07_댓글_작성중`의
  /// "전송 중에는 게시 버튼에 스피너 · 실패 시 입력 내용 보존" 주석 그대로다.
  Future<String?> submit(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || value.isSubmitting) return null;

    value = value.copyWith(isSubmitting: true, clearError: true);
    try {
      await _send(text);
      value = const CommentComposerState();
      return null;
    } on PostFailure catch (error) {
      value = value.copyWith(isSubmitting: false, errorMessage: error.message);
      return error.message;
    }
  }

  Future<void> _send(String text) => switch (value.mode) {
    ComposerMode.create => _repository.addComment(_postId, text),
    ComposerMode.reply => _repository.addReply(value.targetId!, text),
    ComposerMode.edit => _repository.editComment(value.targetId!, text),
  };
}

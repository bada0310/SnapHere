/// Figma가 `방금 전`, `2시간 전`, `3일 전`처럼 상대 시각을 쓴다.
///
/// 커뮤니티 카드·게시글 상세·댓글·알림이 모두 같은 표기를 써야 해서 여기 둔다.
String formatRelativeTime(DateTime createdAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(createdAt);
  if (elapsed.inMinutes < 1) return '방금 전';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전';
  if (elapsed.inDays < 1) return '${elapsed.inHours}시간 전';
  if (elapsed.inDays < 7) return '${elapsed.inDays}일 전';
  return '${createdAt.year}.${createdAt.month}.${createdAt.day}';
}

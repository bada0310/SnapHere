import 'package:flutter/foundation.dart';

/// 위치 신뢰 등급. Figma `07_게시글_상세`의 장소 카드 옆 배지다 (PST-046).
enum TrustTier {
  high,
  medium,
  low;

  factory TrustTier.fromJson(String? value) => switch (value) {
    'HIGH' => high,
    'MEDIUM' => medium,
    _ => low,
  };

  String get label => switch (this) {
    high => '높음',
    medium => '보통',
    low => '낮음',
  };
}

enum CommentStatus {
  active,
  deleted;

  factory CommentStatus.fromJson(String? value) =>
      value == 'DELETED' ? deleted : active;
}

@immutable
class PostAuthor {
  const PostAuthor({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
  });

  factory PostAuthor.fromJson(Map<String, Object?> json) => PostAuthor(
    userId: json['userId']! as String,
    nickname: json['nickname'] as String? ?? '이용자',
    profileImageUrl: json['profileImageUrl'] as String?,
  );

  final String userId;
  final String nickname;
  final String? profileImageUrl;
}

@immutable
class PostPlace {
  const PostPlace({
    required this.placeId,
    required this.title,
    this.addr1,
    this.lat,
    this.lng,
  });

  factory PostPlace.fromJson(Map<String, Object?> json) => PostPlace(
    placeId: json['placeId']! as String,
    title: json['title'] as String? ?? '장소',
    addr1: json['addr1'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );

  final String placeId;
  final String title;
  final String? addr1;
  final double? lat;
  final double? lng;
}

@immutable
class PostImage {
  const PostImage({
    required this.postImageId,
    required this.imageUrl,
    this.thumbnailUrl,
    this.aspectRatio = 0.8,
  });

  factory PostImage.fromJson(Map<String, Object?> json) => PostImage(
    postImageId: json['postImageId']! as String,
    imageUrl: json['imageUrl'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String?,
    aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 0.8,
  );

  final String postImageId;
  final String imageUrl;
  final String? thumbnailUrl;
  final double aspectRatio;
}

@immutable
class PostTag {
  const PostTag({required this.tagId, required this.name, this.locked = false});

  factory PostTag.fromJson(Map<String, Object?> json) => PostTag(
    tagId: json['tagId']! as String,
    name: json['name'] as String? ?? '',
    locked: json['locked'] as bool? ?? false,
  );

  final String tagId;
  final String name;

  /// 장소·행사에서 자동으로 붙어 사용자가 지울 수 없는 태그다 (PLC-021).
  final bool locked;
}

/// 등급 판정 근거. 배지를 누르면 여는 바텀시트가 쓴다 (PST-047, PST-049).
@immutable
class TierResult {
  const TierResult({
    required this.tier,
    this.distanceM,
    this.verifyRadiusM,
    this.withinRadius = false,
    this.daysSinceTaken,
    this.improvementHints = const [],
  });

  factory TierResult.fromJson(Map<String, Object?> json) => TierResult(
    tier: TrustTier.fromJson(json['tier'] as String?),
    distanceM: (json['distanceM'] as num?)?.toInt(),
    verifyRadiusM: (json['verifyRadiusM'] as num?)?.toInt(),
    withinRadius: json['withinRadius'] as bool? ?? false,
    daysSinceTaken: (json['daysSinceTaken'] as num?)?.toInt(),
    improvementHints: ((json['improvementHints'] as List?) ?? const [])
        .map((value) => '$value')
        .toList(growable: false),
  );

  final TrustTier tier;
  final int? distanceM;
  final int? verifyRadiusM;
  final bool withinRadius;
  final int? daysSinceTaken;
  final List<String> improvementHints;
}

@immutable
class PostDetail {
  const PostDetail({
    required this.postId,
    required this.author,
    required this.place,
    required this.images,
    required this.content,
    required this.tags,
    required this.likeCount,
    required this.commentCount,
    this.createdAt,
    this.tierResult,
    this.isLiked,
    this.isBookmarked,
    this.viewCount = 0,
  });

  factory PostDetail.fromJson(Map<String, Object?> json) {
    final summary = Map<String, Object?>.from(json['summary']! as Map);
    final tierJson = json['tierResult'];
    return PostDetail(
      postId: summary['postId']! as String,
      author: PostAuthor.fromJson(
        Map<String, Object?>.from(summary['author']! as Map),
      ),
      place: summary['place'] == null
          ? null
          : PostPlace.fromJson(
              Map<String, Object?>.from(summary['place']! as Map),
            ),
      images: ((json['images'] as List?) ?? const [])
          .map(
            (item) =>
                PostImage.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false),
      content: json['content'] as String? ?? '',
      tags: ((json['tags'] as List?) ?? const [])
          .map(
            (item) => PostTag.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false),
      likeCount: (summary['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (summary['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(summary['createdAt'] as String? ?? ''),
      tierResult: tierJson == null
          ? null
          : TierResult.fromJson(Map<String, Object?>.from(tierJson as Map)),
      isLiked: summary['isLiked'] as bool?,
      isBookmarked: summary['isBookmarked'] as bool?,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String postId;
  final PostAuthor author;
  final PostPlace? place;
  final List<PostImage> images;

  /// 서버에는 제목 칼럼이 없다. 업로드가 `제목\n본문`으로 합쳐 보내므로
  /// (`device_upload_repository`) 상세도 같은 규칙으로 되돌린다.
  final String content;
  final List<PostTag> tags;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;
  final TierResult? tierResult;
  final bool? isLiked;
  final bool? isBookmarked;
  final int viewCount;

  String get title => content.split('\n').first.trim();

  String get body {
    final lines = content.split('\n');
    return lines.length <= 1 ? '' : lines.sublist(1).join('\n').trim();
  }

  PostDetail copyWith({
    int? likeCount,
    bool? isLiked,
    bool? isBookmarked,
    int? commentCount,
  }) => PostDetail(
    postId: postId,
    author: author,
    place: place,
    images: images,
    content: content,
    tags: tags,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    createdAt: createdAt,
    tierResult: tierResult,
    isLiked: isLiked ?? this.isLiked,
    isBookmarked: isBookmarked ?? this.isBookmarked,
    viewCount: viewCount,
  );
}

@immutable
class Comment {
  const Comment({
    required this.commentId,
    required this.postId,
    required this.author,
    required this.status,
    required this.likeCount,
    this.parentId,
    this.content,
    this.createdAt,
    this.isLiked,
  });

  factory Comment.fromJson(Map<String, Object?> json) => Comment(
    commentId: json['commentId']! as String,
    postId: json['postId'] as String? ?? '',
    author: PostAuthor.fromJson(
      Map<String, Object?>.from(json['author']! as Map),
    ),
    parentId: json['parentId'] as String?,
    content: json['content'] as String?,
    status: CommentStatus.fromJson(json['status'] as String?),
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    isLiked: json['isLiked'] as bool?,
  );

  final String commentId;
  final String postId;
  final PostAuthor author;
  final String? parentId;

  /// 삭제된 댓글이면 null이다. 문구는 앱이 만든다 (CMU-017, SYS-010).
  final String? content;
  final CommentStatus status;
  final int likeCount;
  final DateTime? createdAt;
  final bool? isLiked;

  bool get isDeleted => status == CommentStatus.deleted || content == null;

  Comment copyWith({String? content}) => Comment(
    commentId: commentId,
    postId: postId,
    author: author,
    parentId: parentId,
    content: content ?? this.content,
    status: status,
    likeCount: likeCount,
    createdAt: createdAt,
    isLiked: isLiked,
  );
}

/// 부모 하나와 그 대댓글 전부. 서버가 한 덩어리로 준다 (CMU-013).
@immutable
class CommentThread {
  const CommentThread({required this.parent, required this.replies});

  factory CommentThread.fromJson(Map<String, Object?> json) => CommentThread(
    parent: Comment.fromJson(Map<String, Object?>.from(json['parent']! as Map)),
    replies: ((json['replies'] as List?) ?? const [])
        .map((item) => Comment.fromJson(Map<String, Object?>.from(item as Map)))
        .toList(growable: false),
  );

  final Comment parent;
  final List<Comment> replies;

  CommentThread copyWith({Comment? parent, List<Comment>? replies}) =>
      CommentThread(
        parent: parent ?? this.parent,
        replies: replies ?? this.replies,
      );
}

/// 외부 공유 링크의 미리보기 값 (API-PST-014, CMU-019·020).
@immutable
class ShareMetadata {
  const ShareMetadata({
    required this.shareUrl,
    required this.title,
    this.description,
    this.imageUrl,
  });

  factory ShareMetadata.fromJson(Map<String, Object?> json) => ShareMetadata(
    shareUrl: json['shareUrl'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
  );

  final String shareUrl;
  final String title;
  final String? description;
  final String? imageUrl;
}

class PostFailure implements Exception {
  const PostFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

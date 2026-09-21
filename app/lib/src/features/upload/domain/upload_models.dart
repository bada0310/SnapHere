import 'package:flutter/foundation.dart';

enum UploadPhotoSource { bundledAsset, deviceLibrary, camera }

// 서버의 태그 정규화(CMU-025)와 같은 기준으로 중복을 판정한다.
String normalizeUploadTag(String value) => value
    .trim()
    .replaceFirst(RegExp(r'^#'), '')
    .replaceAll(RegExp(r'\s+'), '')
    .toLowerCase();

@immutable
class UploadPhoto {
  const UploadPhoto({
    required this.id,
    this.assetPath,
    this.filePath,
    this.thumbnailBytes,
    this.source = UploadPhotoSource.bundledAsset,
    this.suggestedTitle,
    this.latitude,
    this.longitude,
    this.takenAt,
    this.aspectRatio,
  });

  final String id;
  final String? assetPath;
  final String? filePath;
  final Uint8List? thumbnailBytes;
  final UploadPhotoSource source;
  final String? suggestedTitle;
  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;
  final double? aspectRatio;

  bool get hasLocationMetadata => latitude != null && longitude != null;

  UploadPhoto copyWith({String? filePath}) => UploadPhoto(
    id: id,
    assetPath: assetPath,
    filePath: filePath ?? this.filePath,
    thumbnailBytes: thumbnailBytes,
    source: source,
    suggestedTitle: suggestedTitle,
    latitude: latitude,
    longitude: longitude,
    takenAt: takenAt,
    aspectRatio: aspectRatio,
  );
}

@immutable
class UploadPlace {
  const UploadPlace({
    required this.id,
    required this.name,
    required this.address,
    this.distanceMeters,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final int? distanceMeters;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinate => latitude != null && longitude != null;

  String get tagName {
    final cleaned = name
        .trim()
        .replaceFirst(RegExp(r'^#'), '')
        .replaceAll(RegExp(r'\s+'), '');
    // TagEntity.MAX_NAME_LENGTH / tags.name의 50자 제한을 지킨다.
    // 유니코드 문자 단위로 잘라 이모지의 서로게이트 쌍을 나누지 않는다.
    return String.fromCharCodes(cleaned.runes.take(50));
  }
}

/// 사진 메타데이터와 선택 장소 좌표로 기기 안에서 계산한 인증 결과다.
/// 이 값만 게시글 등록 요청에 포함하며 사진 좌표·촬영 시각은 전송하지 않는다.
@immutable
class LocalTierResult {
  const LocalTierResult({required this.tier, required this.withinRadius});

  final String tier;
  final bool withinRadius;
}

@immutable
class UploadDraft {
  const UploadDraft({
    required this.photos,
    required this.primaryPhoto,
    required this.title,
    required this.description,
    required this.place,
    this.eventId,
    this.fixedTags = const [],
    this.userTags = const [],
  });

  final List<UploadPhoto> photos;
  final UploadPhoto primaryPhoto;
  final String title;
  final String description;
  final UploadPlace place;
  final String? eventId;
  final List<String> fixedTags;
  final List<String> userTags;

  List<String> get photoIds => photos.map((photo) => photo.id).toList();

  List<String> get requestTagNames {
    final seen = <String>{
      if (eventId != null) ...fixedTags.map(normalizeUploadTag),
    };
    return [
      // 일반 자동 태그는 현재 서버가 직접 추가하지 않으므로 요청에 보장한다.
      // 행사 고정 태그는 서버가 추가하므로 자유 태그만 보낸다.
      for (final tag in [if (eventId == null) place.tagName, ...userTags])
        if (normalizeUploadTag(tag).isNotEmpty &&
            seen.add(normalizeUploadTag(tag)))
          tag,
    ];
  }
}

@immutable
class UploadEventContext {
  const UploadEventContext({
    required this.eventId,
    required this.eventTitle,
    required this.place,
    required this.fixedTags,
    required this.verifyRadiusM,
    this.badgeTitle,
  });

  final String eventId;
  final String eventTitle;
  final UploadPlace place;
  final List<String> fixedTags;
  final int verifyRadiusM;
  final String? badgeTitle;
}

@immutable
class UploadResult {
  const UploadResult({
    required this.postId,
    this.badgeTitle,
    this.badgeDescription,
  });

  final String postId;
  final String? badgeTitle;
  final String? badgeDescription;
}

/// 업로드 전 등급 미리보기 결과 (API-PST-002, PST-047).
@immutable
class TierPreview {
  const TierPreview({
    required this.tier,
    this.distanceM,
    this.verifyRadiusM,
    this.withinRadius = false,
  });

  factory TierPreview.fromJson(Map<String, Object?> json) => TierPreview(
    tier: json['tier'] as String? ?? 'LOW',
    distanceM: (json['distanceM'] as num?)?.toInt(),
    verifyRadiusM: (json['verifyRadiusM'] as num?)?.toInt(),
    withinRadius: json['withinRadius'] as bool? ?? false,
  );

  final String tier;
  final int? distanceM;
  final int? verifyRadiusM;
  final bool withinRadius;

  String get label => switch (tier) {
    'HIGH' => '높음',
    'MEDIUM' => '보통',
    _ => '낮음',
  };
}

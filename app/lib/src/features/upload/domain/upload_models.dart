import 'package:flutter/foundation.dart';

enum UploadPhotoSource { bundledAsset, deviceLibrary, camera }

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
  });

  final String id;
  final String name;
  final String address;
  final int? distanceMeters;
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

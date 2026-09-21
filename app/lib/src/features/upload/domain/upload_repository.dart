import 'package:snap_here/src/features/upload/domain/upload_models.dart';

abstract interface class UploadRepository {
  Future<List<UploadPhoto>> fetchGallery();

  Future<void> openMediaSettings();

  Future<List<UploadPlace>> matchPlaces(UploadPhoto photo);

  Future<List<UploadPlace>> searchPlaces(String keyword);

  /// 장소·행사에 맞는 해시태그 추천 (API-CMU-011).
  Future<List<String>> suggestTags({
    required String placeId,
    String? eventId,
    String? query,
  });

  /// 좌표 없이 기본 신뢰 등급을 미리 본다 (API-PST-002).
  Future<TierPreview?> previewTier({
    required String placeId,
    String? eventId,
    required bool fromCamera,
    DateTime? takenAt,
    double? lat,
    double? lng,
  });

  Future<UploadResult> createPost(UploadDraft draft);
}

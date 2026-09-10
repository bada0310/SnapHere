import 'package:snap_here/src/features/upload/domain/upload_models.dart';
import 'package:snap_here/src/features/upload/domain/upload_repository.dart';

class FakeUploadRepository implements UploadRepository {
  static const _latency = Duration(milliseconds: 250);

  static const _places = <UploadPlace>[
    UploadPlace(
      id: 'place-jeonju-hanok',
      name: '전주 한옥마을',
      address: '전북 전주시 완산구 기린대로 99',
      distanceMeters: 120,
    ),
    UploadPlace(
      id: 'place-gyeonggijeon',
      name: '전주 경기전',
      address: '전북 전주시 완산구 태조로 44',
      distanceMeters: 350,
    ),
    UploadPlace(
      id: 'place-pungnammun',
      name: '전주 풍남문',
      address: '전북 전주시 완산구 풍남문3길 1',
      distanceMeters: 800,
    ),
    UploadPlace(
      id: 'place-gyochon',
      name: '경주 교촌한옥마을',
      address: '경북 경주시 교촌길 39-2',
    ),
    UploadPlace(id: 'place-bukchon', name: '북촌한옥마을', address: '서울 종로구 계동길 37'),
  ];

  @override
  Future<List<UploadPhoto>> fetchGallery() async {
    await Future<void>.delayed(_latency);
    return List.generate(
      12,
      (index) => UploadPhoto(
        id: 'photo-${index + 1}',
        assetPath:
            'assets/images/upload/upload_${(index + 1).toString().padLeft(2, '0')}.png',
        suggestedTitle: index < 3 ? '전주 한옥마을의 봄' : null,
        latitude: index < 3 ? 35.815 : null,
        longitude: index < 3 ? 127.153 : null,
      ),
    );
  }

  @override
  Future<List<UploadPhoto>> fetchDraftGallery() async {
    await Future<void>.delayed(_latency);
    return List.generate(
      3,
      (index) => UploadPhoto(
        id: 'draft-${index + 1}',
        assetPath:
            'assets/images/upload/upload_${(index + 10).toString().padLeft(2, '0')}.png',
        suggestedTitle: '작성 중인 여행 기록',
      ),
    );
  }

  @override
  Future<void> openMediaSettings() async {}

  @override
  Future<List<UploadPlace>> matchPlaces(UploadPhoto photo) async {
    await Future<void>.delayed(_latency);
    return photo.hasLocationMetadata ? _places.take(3).toList() : const [];
  }

  @override
  Future<List<UploadPlace>> searchPlaces(String keyword) async {
    await Future<void>.delayed(_latency);
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _places
        .where(
          (place) =>
              place.name.toLowerCase().contains(query) ||
              place.address.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Future<UploadResult> createPost(UploadDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const UploadResult(
      postId: 'dummy-upload-post',
      badgeTitle: '축제 참가 뱃지 획득!',
      badgeDescription: '2026 전주 한옥마을 봄축제 뱃지를 획득했어요!',
    );
  }

  @override
  Future<List<String>> suggestTags({
    required String placeId,
    String? eventId,
    String? query,
  }) async => const ['전주한옥마을', '봄나들이', '한복'];

  @override
  Future<TierPreview?> previewTier({
    required String placeId,
    String? eventId,
    required bool fromCamera,
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) async => const TierPreview(
    tier: 'HIGH',
    distanceM: 24,
    verifyRadiusM: 300,
    withinRadius: true,
  );
}

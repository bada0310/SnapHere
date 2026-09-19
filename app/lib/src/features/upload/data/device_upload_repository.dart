import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/upload/domain/upload_failure.dart';
import 'package:snap_here/src/features/upload/domain/upload_models.dart';
import 'package:snap_here/src/features/upload/domain/upload_repository.dart';

class UploadPermissionException implements Exception {
  const UploadPermissionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UploadLocationException implements Exception {
  const UploadLocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum _UploadStage { photos, preparation, transfer, submission }

class DeviceUploadRepository implements UploadRepository {
  DeviceUploadRepository({
    required this.accessToken,
    http.Client? httpClient,
    ApiClient? api,
  }) : _httpClient = httpClient ?? http.Client(),
       _api = api ?? ApiClient(client: httpClient);

  final String? accessToken;
  final http.Client _httpClient;
  final ApiClient _api;

  @override
  Future<List<UploadPhoto>> fetchGallery() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      throw const UploadPermissionException(
        '사진 보관함 권한이 필요합니다. 기기 설정에서 사진 접근을 허용해 주세요.',
      );
    }
    final entities = await PhotoManager.getAssetListPaged(
      page: 0,
      pageCount: 60,
      type: RequestType.image,
    );
    return Future.wait(entities.map(_toUploadPhoto));
  }

  Future<UploadPhoto> _toUploadPhoto(AssetEntity entity) async {
    final thumbnail = await entity.thumbnailDataWithSize(
      const ThumbnailSize.square(600),
      quality: 88,
    );
    final location = await entity.latlngAsync();
    return UploadPhoto(
      id: entity.id,
      thumbnailBytes: thumbnail,
      source: UploadPhotoSource.deviceLibrary,
      latitude: location?.latitude,
      longitude: location?.longitude,
      aspectRatio: entity.height == 0 ? null : entity.width / entity.height,
    );
  }

  @override
  Future<List<UploadPhoto>> fetchDraftGallery() async => const [];

  @override
  Future<void> openMediaSettings() => PhotoManager.openSetting();

  @override
  Future<List<UploadPlace>> matchPlaces(UploadPhoto photo) async {
    final position = photo.hasLocationMetadata
        ? (latitude: photo.latitude!, longitude: photo.longitude!)
        : await _currentCoordinates();
    final result = jsonMap(
      await _api.get(
        '/places/nearby',
        query: {
          'lat': '${position.latitude}',
          'lng': '${position.longitude}',
          'radiusM': '1500',
        },
        accessToken: accessToken,
      ),
    );
    final values = <Map<String, Object?>>[
      if (result['exactMatch'] is Map) jsonMap(result['exactMatch']),
      ...jsonMapList(result['candidates']),
    ];
    return values.map(_place).toList(growable: false);
  }

  @override
  Future<List<UploadPlace>> searchPlaces(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    final page = jsonMap(
      await _api.get(
        '/places',
        query: {'keyword': keyword.trim(), 'size': '20'},
        accessToken: accessToken,
      ),
    );
    return jsonMapList(page['items']).map(_place).toList(growable: false);
  }

  UploadPlace _place(Map<String, Object?> json) => UploadPlace(
    id: json['placeId']! as String,
    name: json['title']! as String,
    address: json['addr1'] as String? ?? '',
    distanceMeters: (json['distanceM'] as num?)?.toInt(),
  );

  Future<({double latitude, double longitude})> _currentCoordinates() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const UploadLocationException('기기의 위치 서비스를 켜 주세요.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const UploadLocationException(
        '위치 권한이 없어 자동 매칭할 수 없습니다. 장소를 직접 검색해 주세요.',
      );
    }
    final value = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return (latitude: value.latitude, longitude: value.longitude);
  }

  @override
  Future<List<String>> suggestTags({
    required String placeId,
    String? eventId,
    String? query,
  }) async {
    final token = accessToken;
    if (token == null) return const [];
    try {
      final items = jsonMapList(
        await _api.get(
          '/tags/suggestions',
          query: {
            'placeId': _numericId(placeId, 'plc_').toString(),
            'eventId': ?eventId == null
                ? null
                : _numericId(eventId, 'evt_').toString(),
            'query': ?query,
          },
          accessToken: token,
        ),
      );
      return items
          .map((item) => item['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
    } on ApiException {
      // 추천은 보조 기능이다. 실패해도 직접 입력으로 계속 쓸 수 있어야 한다.
      return const [];
    }
  }

  @override
  Future<TierPreview?> previewTier({
    required String placeId,
    String? eventId,
    required bool fromCamera,
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) async {
    final token = accessToken;
    if (token == null) return null;
    try {
      return TierPreview.fromJson(
        jsonMap(
          await _api.post(
            '/posts/tier-preview',
            body: {
              'placeId': _numericId(placeId, 'plc_'),
              if (eventId != null) 'eventId': _numericId(eventId, 'evt_'),
              'source': fromCamera ? 'CAMERA' : 'GALLERY',
              'takenAt': ?takenAt?.toUtc().toIso8601String(),
              'lat': ?lat,
              'lng': ?lng,
            },
            accessToken: token,
          ),
        ),
      );
    } on ApiException {
      return null;
    }
  }

  @override
  Future<UploadResult> createPost(UploadDraft draft) async {
    var stage = _UploadStage.photos;
    try {
      final token = _requireAccessToken();
      final placeId = _numericId(draft.place.id, 'plc_');
      final eventId = draft.eventId == null
          ? null
          : _numericId(draft.eventId!, 'evt_');
      if (eventId == null && draft.place.tagName.isEmpty) {
        throw const UploadFailure(UploadFailureReason.placeNotFound);
      }
      final photos = await Future.wait(draft.photos.map(_resolveOriginal));
      final primary = photos.firstWhere(
        (photo) => photo.id == draft.primaryPhoto.id,
      );
      if (primary.source == UploadPhotoSource.camera &&
          primary.takenAt == null) {
        throw const UploadFailure(UploadFailureReason.invalidTakenAt);
      }
      final files = await Future.wait(photos.map(_fileInfo));
      stage = _UploadStage.preparation;
      final uploadTargets = await _issueUploadTargets(files, token);
      _validateUploadTargets(uploadTargets, files.length);
      final body = _createPostBody(
        draft,
        photos,
        uploadTargets,
        primary,
        placeId: placeId,
        eventId: eventId,
      );
      stage = _UploadStage.transfer;
      await _uploadFiles(uploadTargets, files);
      // 이 시점 이후 통신 오류는 서버 저장 여부를 확정할 수 없다.
      stage = _UploadStage.submission;
      final response = await _api
          .post('/posts', accessToken: token, body: body)
          .timeout(const Duration(seconds: 15));
      return _toUploadResult(jsonMap(response));
    } on UploadFailure {
      rethrow;
    } catch (error) {
      throw _uploadFailure(error, stage);
    }
  }

  String _requireAccessToken() {
    final token = accessToken;
    if (token == null || token.trim().isEmpty) {
      throw const UploadFailure(UploadFailureReason.loginRequired);
    }
    return token;
  }

  Future<List<Map<String, Object?>>> _issueUploadTargets(
    List<({List<int> bytes, String mimeType})> files,
    String token,
  ) async => jsonMapList(
    await _api
        .post(
          '/media/presigned-urls',
          accessToken: token,
          body: {
            'purpose': 'POST_IMAGE',
            'files': [
              for (final file in files)
                {'mimeType': file.mimeType, 'sizeBytes': file.bytes.length},
            ],
          },
        )
        .timeout(const Duration(seconds: 15)),
  );

  void _validateUploadTargets(
    List<Map<String, Object?>> targets,
    int photoCount,
  ) {
    if (targets.length != photoCount || targets.isEmpty) {
      throw const UploadFailure(UploadFailureReason.preparationFailed);
    }
    for (final target in targets) {
      final url = target['uploadUrl'];
      final key = target['imageKey'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null ||
          !uri.hasAuthority ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          key is! String ||
          key.isEmpty) {
        throw const UploadFailure(UploadFailureReason.preparationFailed);
      }
    }
  }

  Future<void> _uploadFiles(
    List<Map<String, Object?>> targets,
    List<({List<int> bytes, String mimeType})> files,
  ) async {
    for (var index = 0; index < targets.length; index++) {
      final target = targets[index];
      final url = target['uploadUrl']! as String;
      if (Uri.parse(url).queryParameters['stub-presign'] == 'true') continue;
      final headers = Map<String, String>.from(target['headers'] as Map? ?? {});
      final response = await _httpClient
          .put(Uri.parse(url), headers: headers, body: files[index].bytes)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('사진 업로드에 실패했습니다.', statusCode: response.statusCode);
      }
    }
  }

  Map<String, Object?> _createPostBody(
    UploadDraft draft,
    List<UploadPhoto> photos,
    List<Map<String, Object?>> uploadTargets,
    UploadPhoto primary, {
    required int placeId,
    int? eventId,
  }) => {
    'placeId': placeId,
    'eventId': ?eventId,
    'content': [
      draft.title,
      draft.description,
    ].where((value) => value.isNotEmpty).join('\n'),
    'originalLanguageCode': 'ko',
    'images': [
      for (var index = 0; index < uploadTargets.length; index++)
        {
          'imageKey': uploadTargets[index]['imageKey'],
          'sortOrder': index + 1,
          'aspectRatio': photos[index].aspectRatio,
        },
    ],
    'tagNames': draft.requestTagNames,
    'source': primary.source == UploadPhotoSource.camera ? 'CAMERA' : 'ALBUM',
    if (primary.source == UploadPhotoSource.camera)
      'takenAt': primary.takenAt!.toUtc().toIso8601String(),
    if (primary.latitude != null) 'lat': primary.latitude,
    if (primary.longitude != null) 'lng': primary.longitude,
  };

  int _numericId(String id, String prefix) {
    final raw = id.startsWith(prefix) ? id.substring(prefix.length) : null;
    final value = raw != null && RegExp(r'^[0-9a-z]+$').hasMatch(raw)
        ? int.tryParse(raw, radix: 36)
        : null;
    if (value == null || value <= 0) {
      throw UploadFailure(
        prefix == 'evt_'
            ? UploadFailureReason.eventNotFound
            : UploadFailureReason.placeNotFound,
      );
    }
    return value;
  }

  UploadResult _toUploadResult(Map<String, Object?> data) {
    // CreatePostResponse는 최상위 postId를 반환한다. PROCESSING도 등록 성공이다.
    final postId = data['postId'];
    if (postId is! String || postId.trim().isEmpty) {
      throw const UploadFailure(UploadFailureReason.resultUnknown);
    }
    // 선택적인 뱃지 정보의 문제로 이미 완료된 등록을 실패 처리하지 않는다.
    final badges = data['earnedBadges'];
    final first = badges is List && badges.isNotEmpty ? badges.first : null;
    final badge = first is Map ? first : const <String, Object?>{};
    return UploadResult(
      postId: postId,
      badgeTitle: badge['name'] is String ? badge['name'] as String : null,
      badgeDescription: badge['description'] is String
          ? badge['description'] as String
          : null,
    );
  }

  UploadFailure _uploadFailure(Object error, _UploadStage stage) {
    if (stage == _UploadStage.photos) {
      return const UploadFailure(UploadFailureReason.photoRead);
    }
    if (stage == _UploadStage.transfer) {
      return UploadFailure(switch (error) {
        TimeoutException() => UploadFailureReason.photoUploadTimeout,
        ApiException(statusCode: 401 || 403) =>
          UploadFailureReason.photoUploadRejected,
        _ => UploadFailureReason.photoUpload,
      });
    }
    if (error is ApiException) {
      final reason = _apiFailureReason(error);
      if (reason != null) return UploadFailure(reason);
    }
    if (stage == _UploadStage.submission) {
      return const UploadFailure(UploadFailureReason.resultUnknown);
    }
    return UploadFailure(switch (error) {
      TimeoutException() => UploadFailureReason.preparationTimeout,
      SocketException() ||
      http.ClientException() => UploadFailureReason.network,
      ApiException(statusCode: final status?) when status >= 500 =>
        UploadFailureReason.serverUnavailable,
      _ => UploadFailureReason.preparationFailed,
    });
  }

  UploadFailureReason? _apiFailureReason(ApiException error) =>
      switch (error.code) {
        'AUTH_REQUIRED' ||
        'AUTH_INVALID_REFRESH' ||
        'AUTH_REFRESH_EXPIRED' ||
        'AUTH_TOKEN_REUSED' => UploadFailureReason.loginRequired,
        'AUTH_TERMS_REQUIRED' => UploadFailureReason.termsRequired,
        'USER_WITHDRAWN' ||
        'USER_NOT_FOUND' => UploadFailureReason.accountUnavailable,
        'MEDIA_COUNT_INVALID' ||
        'POST_IMAGE_REQUIRED' => UploadFailureReason.photoCount,
        'MEDIA_TOO_LARGE' => UploadFailureReason.photoTooLarge,
        'MEDIA_TYPE_UNSUPPORTED' => UploadFailureReason.photoType,
        'MEDIA_NOT_FOUND' => UploadFailureReason.photoNotFound,
        'POST_PLACE_REQUIRED' => UploadFailureReason.placeRequired,
        'PLACE_NOT_FOUND' => UploadFailureReason.placeNotFound,
        'EVENT_NOT_FOUND' => UploadFailureReason.eventNotFound,
        'PLACE_INVALID_COORDINATE' ||
        'PLACE_OUT_OF_SERVICE_AREA' => UploadFailureReason.invalidCoordinates,
        'POST_INVALID_TAKEN_AT' => UploadFailureReason.invalidTakenAt,
        'POST_TAG_REQUIRED' => UploadFailureReason.tagInvalid,
        'POST_DAILY_LIMIT' => UploadFailureReason.dailyLimit,
        'POST_PLACE_DAILY_LIMIT' => UploadFailureReason.placeDailyLimit,
        'POST_DUPLICATE_IMAGE' => UploadFailureReason.duplicateImage,
        'POST_UPLOAD_SUSPENDED' => UploadFailureReason.uploadSuspended,
        'POST_MEDIA_PROCESSING' => UploadFailureReason.mediaProcessing,
        'POST_MEDIA_FAILED' => UploadFailureReason.mediaFailed,
        'COMMON_429' => UploadFailureReason.tooManyRequests,
        _ => switch (error.statusCode) {
          401 => UploadFailureReason.loginRequired,
          403 => UploadFailureReason.permissionDenied,
          400 || 404 || 422 => UploadFailureReason.invalidInput,
          409 => UploadFailureReason.conflict,
          413 => UploadFailureReason.photoTooLarge,
          415 => UploadFailureReason.photoType,
          429 => UploadFailureReason.tooManyRequests,
          _ => null,
        },
      };

  Future<({List<int> bytes, String mimeType})> _fileInfo(
    UploadPhoto photo,
  ) async {
    final path = photo.filePath;
    if (path == null) throw const UploadPermissionException('사진 원본을 읽지 못했습니다.');
    final bytes = await File(path).readAsBytes();
    final extension = path.toLowerCase().split('.').last;
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    return (bytes: bytes, mimeType: mimeType);
  }

  Future<UploadPhoto> _resolveOriginal(UploadPhoto photo) async {
    if (photo.filePath != null ||
        photo.source != UploadPhotoSource.deviceLibrary) {
      return photo;
    }
    final entity = await AssetEntity.fromId(photo.id);
    final file = await entity?.originFile;
    if (file == null) {
      throw const UploadPermissionException(
        '선택한 사진 원본을 읽지 못했습니다. 사진 접근 권한을 확인해 주세요.',
      );
    }
    return photo.copyWith(filePath: file.path);
  }
}

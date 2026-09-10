import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_here/src/core/network/api_client.dart';
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
            'placeId': _numericId(placeId, 'plc_'),
            'eventId': ?eventId == null ? null : _numericId(eventId, 'evt_'),
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
              'placeId': int.parse(_numericId(placeId, 'plc_')),
              if (eventId != null)
                'eventId': int.parse(_numericId(eventId, 'evt_')),
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

  String _numericId(String value, String prefix) =>
      value.replaceFirst(prefix, '');

  @override
  Future<UploadResult> createPost(UploadDraft draft) async {
    final token = _requireAccessToken();
    final photos = await Future.wait(draft.photos.map(_resolveOriginal));
    final files = await Future.wait(photos.map(_fileInfo));
    final uploadTargets = await _issueUploadTargets(files, token);
    await _uploadFiles(uploadTargets, files);
    final response = await _createPost(draft, photos, uploadTargets, token);
    return _toUploadResult(response);
  }

  String _requireAccessToken() {
    final token = accessToken;
    if (token == null) {
      throw const UploadPermissionException('로그인이 필요한 기능입니다.');
    }
    return token;
  }

  Future<List<Map<String, Object?>>> _issueUploadTargets(
    List<({List<int> bytes, String mimeType})> files,
    String token,
  ) async => jsonMapList(
    await _api.post(
      '/media/presigned-urls',
      accessToken: token,
      body: {
        'purpose': 'POST_IMAGE',
        'files': [
          for (final file in files)
            {'mimeType': file.mimeType, 'sizeBytes': file.bytes.length},
        ],
      },
    ),
  );

  Future<void> _uploadFiles(
    List<Map<String, Object?>> targets,
    List<({List<int> bytes, String mimeType})> files,
  ) async {
    for (var index = 0; index < targets.length; index++) {
      final target = targets[index];
      final url = target['uploadUrl']! as String;
      if (Uri.parse(url).queryParameters['stub-presign'] == 'true') continue;
      final headers = Map<String, String>.from(target['headers'] as Map? ?? {});
      final response = await _httpClient.put(
        Uri.parse(url),
        headers: headers,
        body: files[index].bytes,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('사진 업로드에 실패했습니다. (${response.statusCode})');
      }
    }
  }

  Future<Map<String, Object?>> _createPost(
    UploadDraft draft,
    List<UploadPhoto> photos,
    List<Map<String, Object?>> uploadTargets,
    String token,
  ) async {
    final primary = photos.firstWhere(
      (photo) => photo.id == draft.primaryPhoto.id,
    );
    return jsonMap(
      await _api.post(
        '/posts',
        accessToken: token,
        body: _createPostBody(draft, photos, uploadTargets, primary),
      ),
    );
  }

  Map<String, Object?> _createPostBody(
    UploadDraft draft,
    List<UploadPhoto> photos,
    List<Map<String, Object?>> uploadTargets,
    UploadPhoto primary,
  ) => {
    'placeId': _numericId(draft.place.id, 'plc_'),
    if (draft.eventId != null) 'eventId': _numericId(draft.eventId!, 'evt_'),
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
    'tagNames': [...draft.fixedTags, ...draft.userTags],
    'source': primary.source == UploadPhotoSource.camera ? 'CAMERA' : 'ALBUM',
    if (primary.source == UploadPhotoSource.camera)
      'takenAt': DateTime.now().toUtc().toIso8601String(),
    if (primary.latitude != null) 'lat': primary.latitude,
    if (primary.longitude != null) 'lng': primary.longitude,
  };

  int _numericId(String id, String prefix) =>
      int.parse(id.replaceFirst(prefix, ''));

  UploadResult _toUploadResult(Map<String, Object?> data) {
    final post = jsonMap(data['post']);
    final summary = jsonMap(post['summary']);
    final badges = jsonMapList(data['earnedBadges']);
    return UploadResult(
      postId: summary['postId']! as String,
      badgeTitle: badges.isEmpty ? null : badges.first['name'] as String?,
      badgeDescription: badges.isEmpty
          ? null
          : badges.first['description'] as String?,
    );
  }

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

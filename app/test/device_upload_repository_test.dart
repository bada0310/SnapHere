import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/upload/application/upload_controller.dart';
import 'package:snap_here/src/features/upload/data/device_upload_repository.dart';
import 'package:snap_here/src/features/upload/domain/upload_failure.dart';
import 'package:snap_here/src/features/upload/domain/upload_models.dart';

// 기기 갤러리만 대체하고 등록은 실제 DeviceUploadRepository를 통과한다.
class _DeviceRepository extends DeviceUploadRepository {
  _DeviceRepository({
    required super.accessToken,
    required super.httpClient,
    required super.api,
    required this.photo,
  });

  final UploadPhoto photo;

  @override
  Future<List<UploadPhoto>> fetchGallery() async => [photo];

  @override
  Future<List<UploadPhoto>> fetchDraftGallery() async => [];
}

const _created = {
  'postId': 'pst_42',
  'mediaStatus': 'PROCESSING',
  'tierResult': {'tier': 'LOW'},
  'visitRecorded': false,
  'earnedBadges': [
    {'badgeId': 'bdg_1', 'name': '사천 에어쇼', 'description': '행사 참여 기념'},
  ],
};

http.Response _data(Object? data, {int status = 200}) => http.Response(
  jsonEncode({'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _error(String code, int status) => http.Response(
  jsonEncode({
    'error': {'code': code, 'messageKey': 'error.test'},
  }),
  status,
);

Matcher _failure(UploadFailureReason reason) =>
    throwsA(isA<UploadFailure>().having((e) => e.reason, 'reason', reason));

void main() {
  late Directory directory;
  late UploadDraft draft;
  late List<http.Request> requests;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('snaphere-upload-test-');
    final file = await File('${directory.path}/photo.jpg')
        .writeAsBytes([1, 2, 3]);
    final photo = UploadPhoto(id: 'photo-1', filePath: file.path);
    draft = UploadDraft(
      photos: [photo],
      primaryPhoto: photo,
      title: '사천 에어쇼',
      description: '사진 설명',
      place: const UploadPlace(id: 'plc_1', name: '사천에어쇼', address: '사천시'),
      eventId: 'evt_2',
      fixedTags: const ['사천', '에어쇼'],
      userTags: const ['비행'],
    );
    requests = [];
  });

  tearDown(() async => directory.delete(recursive: true));

  _DeviceRepository repository({
    String? token = 'test-token',
    FutureOr<http.Response?> Function(http.Request)? respond,
  }) {
    final client = MockClient((request) async {
      requests.add(request);
      final response = await respond?.call(request);
      if (response != null) return response;
      if (request.url.path == '/api/v1/media/presigned-urls') {
        return _data([
          {
            'imageKey': 'originals/posts/test/photo.jpg',
            'uploadUrl': 'https://storage.test/photo.jpg',
            'headers': {'Content-Type': 'image/jpeg'},
          },
        ]);
      }
      if (request.method == 'PUT') return http.Response('', 200);
      if (request.url.path == '/api/v1/posts') {
        return _data(_created, status: 201);
      }
      throw StateError('Unexpected request: ${request.url.path}');
    });
    addTearDown(client.close);
    return _DeviceRepository(
      accessToken: token,
      httpClient: client,
      api: ApiClient(client: client, baseUrl: 'https://api.test'),
      photo: draft.primaryPhoto,
    );
  }

  test('서버의 실제 201 응답으로 완료 전환하고 게시글 번호와 뱃지를 유지한다', () async {
    final container = ProviderContainer(
      overrides: [uploadRepositoryProvider.overrideWithValue(repository())],
    );
    addTearDown(container.dispose);
    await container.read(uploadControllerProvider.future);
    final controller = container.read(uploadControllerProvider.notifier);
    controller.applyEventContext(
      UploadEventContext(
        eventId: draft.eventId!,
        eventTitle: draft.title,
        place: draft.place,
        fixedTags: draft.fixedTags,
        verifyRadiusM: 2000,
      ),
    );
    await controller.showForm();
    controller.updateTitle(draft.title);
    controller.updateDescription(draft.description);
    for (final tag in draft.userTags) {
      controller.addUserTag(tag);
    }
    await controller.submit();

    final state = container.read(uploadControllerProvider).requireValue;
    expect(state.step, UploadStep.complete);
    expect(state.isSubmitting, isFalse);
    expect(state.submitMessage, isNull);
    expect(state.result?.postId, 'pst_42');
    expect(state.result?.badgeTitle, '사천 에어쇼');
    expect(state.result?.badgeDescription, '행사 참여 기념');
    expect(requests.map((r) => r.method), ['POST', 'PUT', 'POST']);
    expect(requests[1].bodyBytes, [1, 2, 3]);
    expect(requests[1].headers['authorization'], isNull);
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['placeId'], 1);
    expect(body['eventId'], 2);
    expect(body['content'], '사천 에어쇼\n사진 설명');
    expect(body['tagNames'], ['비행']);

    await controller.submit();
    expect(requests, hasLength(3));
  });

  test('행사 고정 2개는 서버에 맡기고 자유 태그 8개만 요청에 담는다', () async {
    final tags = List.generate(8, (index) => '자유태그$index');
    await repository().createPost(
      UploadDraft(
        photos: draft.photos,
        primaryPhoto: draft.primaryPhoto,
        title: draft.title,
        description: draft.description,
        place: draft.place,
        eventId: draft.eventId,
        fixedTags: draft.fixedTags,
        userTags: tags,
      ),
    );
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['tagNames'], tags);
    expect(body['tagNames'], hasLength(8));
    expect(body['tagNames'], isNot(contains('사천')));
    expect(body['tagNames'], isNot(contains('에어쇼')));
  });

  test('일반 게시글은 수동 태그 없이 실제 요청에 자동 장소 태그를 포함한다', () async {
    final container = ProviderContainer(
      overrides: [uploadRepositoryProvider.overrideWithValue(repository())],
    );
    addTearDown(container.dispose);
    await container.read(uploadControllerProvider.future);
    final controller = container.read(uploadControllerProvider.notifier);
    controller.selectPlace(
      const UploadPlace(id: 'plc_2zq', name: '은구비 공원', address: ''),
    );
    controller.updateTitle('공원 사진');
    await controller.submit();
    final state = container.read(uploadControllerProvider).requireValue;
    expect(state.step, UploadStep.complete);
    expect(state.userTags, isEmpty);
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['placeId'], 3878);
    expect(body['tagNames'], ['은구비공원']);
    expect(body.containsKey('eventId'), isFalse);
  });

  test('작성 상태를 거치지 않는 일반 요청도 장소 태그를 보장하고 정규화 중복을 지운다', () async {
    final tags = ['#사천 에어쇼', ...List.generate(9, (index) => '추가$index'), '추가0'];
    await repository().createPost(
      UploadDraft(
        photos: draft.photos,
        primaryPhoto: draft.primaryPhoto,
        title: draft.title,
        description: draft.description,
        place: draft.place,
        userTags: tags,
      ),
    );
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['tagNames'], [
      '사천에어쇼',
      ...List.generate(9, (index) => '추가$index'),
    ]);
    expect(body['tagNames'], hasLength(10));
  });

  test('긴 장소 이름은 서버의 50자 태그 제한에 맞추고 이모지를 나누지 않는다', () async {
    final name =
        '${List.filled(49, '가').join()}📷${List.filled(15, '나').join()}';
    final place = UploadPlace(id: 'plc_1', name: name, address: '');
    await repository().createPost(
      UploadDraft(
        photos: draft.photos,
        primaryPhoto: draft.primaryPhoto,
        title: draft.title,
        description: draft.description,
        place: place,
      ),
    );
    final body = jsonDecode(requests.last.body) as Map;
    final tag = (body['tagNames'] as List).single as String;
    expect(tag, '${List.filled(49, '가').join()}📷');
    expect(tag.runes, hasLength(50));
    expect(tag, place.tagName);
    expect(normalizeUploadTag(tag).runes, hasLength(50));
  });

  test('행사도 추가 입력 없이 자유 태그 빈 배열로 게시를 완료한다', () async {
    final result = await repository().createPost(
      UploadDraft(
        photos: draft.photos,
        primaryPhoto: draft.primaryPhoto,
        title: draft.title,
        description: draft.description,
        place: draft.place,
        eventId: draft.eventId,
        fixedTags: draft.fixedTags,
      ),
    );
    expect(result.postId, 'pst_42');
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['tagNames'], isEmpty);
    expect(body['eventId'], 2);
  });

  test('카메라 촬영 시각과 좌표를 행사 게시글 요청에 그대로 전달한다', () async {
    final takenAt = DateTime.parse('2026-09-18T10:20:30+09:00');
    final photo = UploadPhoto(
      id: 'camera-1',
      filePath: draft.primaryPhoto.filePath,
      source: UploadPhotoSource.camera,
      latitude: 35.003,
      longitude: 128.064,
      takenAt: takenAt,
    );
    await repository().createPost(
      UploadDraft(
        photos: [photo],
        primaryPhoto: photo,
        title: draft.title,
        description: draft.description,
        place: draft.place,
        eventId: draft.eventId,
      ),
    );
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['source'], 'CAMERA');
    expect(body['takenAt'], takenAt.toUtc().toIso8601String());
    expect(body['lat'], 35.003);
    expect(body['lng'], 128.064);
    expect(body['eventId'], 2);
    expect(photo.copyWith(filePath: photo.filePath).takenAt, takenAt);
  });

  test('촬영 시각이 없는 카메라 사진은 서버 요청 전에 멈춘다', () async {
    final photo = UploadPhoto(
      id: 'camera-1',
      filePath: draft.primaryPhoto.filePath,
      source: UploadPhotoSource.camera,
    );
    await expectLater(
      repository().createPost(
        UploadDraft(
          photos: [photo],
          primaryPhoto: photo,
          title: draft.title,
          description: draft.description,
          place: draft.place,
          eventId: draft.eventId,
        ),
      ),
      _failure(UploadFailureReason.invalidTakenAt),
    );
    expect(requests, isEmpty);
  });

  test('장소 이름이 비어 자동 태그를 만들 수 없으면 사진 준비 전에 장소 재선택을 안내한다', () async {
    await expectLater(
      repository().createPost(
        UploadDraft(
          photos: draft.photos,
          primaryPhoto: draft.primaryPhoto,
          title: draft.title,
          description: draft.description,
          place: const UploadPlace(id: 'plc_1', name: '   ', address: ''),
        ),
      ),
      _failure(UploadFailureReason.placeNotFound),
    );
    expect(requests, isEmpty);
  });

  test('문자 포함·숫자 전용 외부 장소와 행사 ID를 36진수로 게시한다', () async {
    for (final ids in [
      (place: 'plc_2zq', placeNumber: 3878, event: 'evt_a', eventNumber: 10),
      (place: 'plc_10', placeNumber: 36, event: 'evt_10', eventNumber: 36),
    ]) {
      requests.clear();
      final result = await repository().createPost(
        UploadDraft(
          photos: draft.photos,
          primaryPhoto: draft.primaryPhoto,
          title: draft.title,
          description: draft.description,
          place: UploadPlace(id: ids.place, name: '은구비공원', address: ''),
          eventId: ids.event,
        ),
      );
      expect(result.postId, 'pst_42');
      expect(requests.map((r) => r.method), ['POST', 'PUT', 'POST']);
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['placeId'], ids.placeNumber);
      expect(body['eventId'], ids.eventNumber);
    }
  });

  test('태그 추천과 등급 미리보기도 같은 장소·행사 번호를 사용한다', () async {
    final repo = repository(
      respond: (request) => request.url.path == '/api/v1/tags/suggestions'
          ? _data([
              {'name': '공원'},
            ])
          : request.url.path == '/api/v1/posts/tier-preview'
          ? _data({'tier': 'LOW'})
          : null,
    );
    expect(await repo.suggestTags(placeId: 'plc_2zq', eventId: 'evt_10'), [
      '공원',
    ]);
    expect(requests.single.url.queryParameters['placeId'], '3878');
    expect(requests.single.url.queryParameters['eventId'], '36');
    expect(
      (await repo.previewTier(
        placeId: 'plc_2zq',
        eventId: 'evt_10',
        fromCamera: false,
      ))?.tier,
      'LOW',
    );
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['placeId'], 3878);
    expect(body['eventId'], 36);
  });

  test('잘못된 장소·행사 ID는 사진 준비 요청 전에 구체적으로 안내한다', () async {
    for (final place in ['plc_', 'evt_1', 'plc_-1', 'plc_0', 'plc_2 zq']) {
      await expectLater(
        repository().createPost(
          UploadDraft(
            photos: draft.photos,
            primaryPhoto: draft.primaryPhoto,
            title: draft.title,
            description: draft.description,
            place: UploadPlace(id: place, name: '공원', address: ''),
          ),
        ),
        _failure(UploadFailureReason.placeNotFound),
      );
    }
    await expectLater(
      repository().createPost(
        UploadDraft(
          photos: draft.photos,
          primaryPhoto: draft.primaryPhoto,
          title: draft.title,
          description: draft.description,
          place: draft.place,
          eventId: 'plc_1',
        ),
      ),
      _failure(UploadFailureReason.eventNotFound),
    );
    expect(requests, isEmpty);
  });

  test('게시글 번호를 받았다면 뱃지가 없거나 손상돼도 성공을 유지한다', () async {
    for (final badges in [
      null,
      [],
      'invalid',
      [null],
      [
        {'name': 1, 'description': false},
      ],
    ]) {
      final result = await repository(
        respond: (request) => request.url.path == '/api/v1/posts'
            ? _data({'postId': 'pst_42', 'earnedBadges': badges}, status: 201)
            : null,
      ).createPost(draft);
      expect(result.postId, 'pst_42');
      expect(result.badgeTitle, isNull);
      expect(result.badgeDescription, isNull);
    }
  });

  test('성공 응답이 비었거나 손상되면 재등록 대신 결과 확인을 안내한다', () async {
    for (final response in [
      http.Response('', 201),
      http.Response('{invalid', 201),
      _data({'mediaStatus': 'PROCESSING'}, status: 201),
      _data({'postId': ''}, status: 201),
    ]) {
      final repo = repository(
        respond: (request) =>
            request.url.path == '/api/v1/posts' ? response : null,
      );
      await expectLater(
        repo.createPost(draft),
        _failure(UploadFailureReason.resultUnknown),
      );
    }
  });

  test('로그인과 사진 읽기 실패 시 서버에 등록 요청을 보내지 않는다', () async {
    await expectLater(
      repository(token: null).createPost(draft),
      _failure(UploadFailureReason.loginRequired),
    );
    await File(draft.primaryPhoto.filePath!).delete();
    await expectLater(
      repository().createPost(draft),
      _failure(UploadFailureReason.photoRead),
    );
    expect(requests, isEmpty);
  });

  test('업로드 주소가 누락되면 사진이 빠진 게시글을 등록하지 않는다', () async {
    await expectLater(
      repository(respond: (request) => _data([])).createPost(draft),
      _failure(UploadFailureReason.preparationFailed),
    );
    expect(requests, hasLength(1));
  });

  test('사진 저장소의 403은 로그인 만료와 구분하고 게시 요청을 중단한다', () async {
    await expectLater(
      repository(
        respond: (request) =>
            request.method == 'PUT' ? http.Response('AccessDenied', 403) : null,
      ).createPost(draft),
      _failure(UploadFailureReason.photoUploadRejected),
    );
    expect(requests, hasLength(2));
  });

  test('같은 연결 장애도 등록 요청 전후에 따라 다르게 안내한다', () async {
    for (final scenario in [
      (
        path: '/api/v1/media/presigned-urls',
        reason: UploadFailureReason.network,
      ),
      (path: '/photo.jpg', reason: UploadFailureReason.photoUpload),
      (path: '/api/v1/posts', reason: UploadFailureReason.resultUnknown),
    ]) {
      requests.clear();
      await expectLater(
        repository(
          respond: (request) {
            if (request.url.path == scenario.path) {
              throw http.ClientException('Connection closed');
            }
            return null;
          },
        ).createPost(draft),
        _failure(scenario.reason),
      );
      expect(requests.last.url.path, scenario.path);
      expect(requests.where((r) => r.url.path == scenario.path), hasLength(1));
    }
  });

  test('시간 초과를 준비·사진 전송·등록 결과 확인 단계로 구분한다', () async {
    for (final scenario in [
      (
        path: '/api/v1/media/presigned-urls',
        reason: UploadFailureReason.preparationTimeout,
      ),
      (path: '/photo.jpg', reason: UploadFailureReason.photoUploadTimeout),
      (path: '/api/v1/posts', reason: UploadFailureReason.resultUnknown),
    ]) {
      await expectLater(
        repository(
          respond: (request) {
            if (request.url.path == scenario.path) {
              throw TimeoutException('test');
            }
            return null;
          },
        ).createPost(draft),
        _failure(scenario.reason),
      );
    }
  });

  test('서버 장애도 게시 요청 뒤에는 저장 실패로 단정하지 않는다', () async {
    for (final scenario in [
      (
        path: '/api/v1/media/presigned-urls',
        reason: UploadFailureReason.serverUnavailable,
      ),
      (path: '/api/v1/posts', reason: UploadFailureReason.resultUnknown),
    ]) {
      await expectLater(
        repository(
          respond: (request) => request.url.path == scenario.path
              ? http.Response('Bad Gateway', 502)
              : null,
        ).createPost(draft),
        _failure(scenario.reason),
      );
    }
  });

  test('같은 HTTP 상태라도 서버의 원인 코드에 따라 조치가 달라진다', () async {
    for (final scenario in [
      (
        code: 'AUTH_TERMS_REQUIRED',
        status: 403,
        reason: UploadFailureReason.termsRequired,
      ),
      (
        code: 'POST_UPLOAD_SUSPENDED',
        status: 403,
        reason: UploadFailureReason.uploadSuspended,
      ),
      (
        code: 'POST_TAG_REQUIRED',
        status: 422,
        reason: UploadFailureReason.tagInvalid,
      ),
      (
        code: 'POST_INVALID_TAKEN_AT',
        status: 422,
        reason: UploadFailureReason.invalidTakenAt,
      ),
      (
        code: 'POST_PLACE_DAILY_LIMIT',
        status: 429,
        reason: UploadFailureReason.placeDailyLimit,
      ),
      (
        code: 'COMMON_429',
        status: 429,
        reason: UploadFailureReason.tooManyRequests,
      ),
      (
        code: 'PLACE_NOT_FOUND',
        status: 404,
        reason: UploadFailureReason.placeNotFound,
      ),
      (
        code: 'EVENT_NOT_FOUND',
        status: 404,
        reason: UploadFailureReason.eventNotFound,
      ),
      (
        code: 'POST_DUPLICATE_IMAGE',
        status: 409,
        reason: UploadFailureReason.duplicateImage,
      ),
      (
        code: 'UNKNOWN_CODE',
        status: 401,
        reason: UploadFailureReason.loginRequired,
      ),
    ]) {
      await expectLater(
        repository(
          respond: (request) => request.url.path == '/api/v1/posts'
              ? _error(scenario.code, scenario.status)
              : null,
        ).createPost(draft),
        _failure(scenario.reason),
      );
    }
  });

  test('사진 용량 거절은 업로드를 멈추고 사진 교체를 안내한다', () async {
    await expectLater(
      repository(respond: (_) => _error('MEDIA_TOO_LARGE', 413))
          .createPost(draft),
      _failure(UploadFailureReason.photoTooLarge),
    );
    expect(requests, hasLength(1));
  });

  test('HEIC 원본은 서버가 지원하는 실제 형식으로 업로드 주소를 요청한다', () async {
    final file = await File('${directory.path}/photo.heic')
        .writeAsBytes([1, 2]);
    final photo = draft.primaryPhoto.copyWith(filePath: file.path);
    await repository().createPost(
      UploadDraft(
        photos: [photo],
        primaryPhoto: photo,
        title: draft.title,
        description: draft.description,
        place: draft.place,
        fixedTags: draft.fixedTags,
      ),
    );
    final body = jsonDecode(requests.first.body) as Map;
    expect((body['files'] as List).single['mimeType'], 'image/heic');
  });
}

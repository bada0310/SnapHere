import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/upload/application/upload_controller.dart';
import 'package:snap_here/src/features/upload/domain/upload_failure.dart';
import 'package:snap_here/src/features/upload/domain/upload_models.dart';
import 'package:snap_here/src/features/upload/domain/upload_repository.dart';
import 'package:snap_here/src/features/upload/presentation/upload_screen.dart';

class _StubUploadRepository implements UploadRepository {
  _StubUploadRepository({
    this.hasMetadata = true,
    this.emptyGallery = false,
    this.cameraPhoto = false,
    this.submitFailure,
    this.pendingSubmit,
  });

  final bool hasMetadata;
  final bool emptyGallery;
  final bool cameraPhoto;
  Object? submitFailure;
  final Completer<UploadResult>? pendingSubmit;
  int submitCount = 0;
  UploadDraft? submittedDraft;

  static const place = UploadPlace(
    id: 'place-1',
    name: '전주 한옥마을',
    address: '전북 전주시 완산구 기린대로 99',
    distanceMeters: 120,
  );

  @override
  Future<List<UploadPhoto>> fetchGallery() async => emptyGallery
      ? const []
      : [
          UploadPhoto(
            id: 'photo-1',
            source: cameraPhoto
                ? UploadPhotoSource.camera
                : UploadPhotoSource.deviceLibrary,
            suggestedTitle: hasMetadata ? '전주 한옥마을의 봄' : null,
            latitude: hasMetadata && !cameraPhoto ? 35.815 : null,
            longitude: hasMetadata && !cameraPhoto ? 127.153 : null,
            takenAt: cameraPhoto ? DateTime(2026, 9, 18) : null,
          ),
          const UploadPhoto(id: 'photo-2'),
        ];

  @override
  Future<List<UploadPhoto>> fetchDraftGallery() async =>
      emptyGallery ? const [] : const [UploadPhoto(id: 'draft-1')];

  @override
  Future<void> openMediaSettings() async {}

  @override
  Future<List<UploadPlace>> matchPlaces(UploadPhoto photo) async =>
      photo.hasLocationMetadata ? [place] : [];

  @override
  Future<List<UploadPlace>> searchPlaces(String keyword) async => [place];

  @override
  Future<UploadResult> createPost(UploadDraft draft) async {
    submitCount++;
    if (submitFailure case final error?) throw error;
    submittedDraft = draft;
    if (pendingSubmit case final pending?) return pending.future;
    return const UploadResult(
      postId: 'post-1',
      badgeTitle: '축제 참가 뱃지 획득!',
      badgeDescription: '테스트 뱃지를 획득했어요!',
    );
  }

  @override
  Future<List<String>> suggestTags({
    required String placeId,
    String? eventId,
    String? query,
  }) async => const ['전주한옥마을'];

  @override
  Future<TierPreview?> previewTier({
    required String placeId,
    String? eventId,
    required bool fromCamera,
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) async => null;
}

class _DelayedMatchRepository extends _StubUploadRepository {
  final pendingMatch = Completer<List<UploadPlace>>();

  @override
  Future<List<UploadPlace>> matchPlaces(UploadPhoto photo) =>
      pendingMatch.future;
}

Widget _wrap(UploadRepository repository) {
  final router = GoRouter(
    initialLocation: '/upload',
    routes: [
      GoRoute(path: '/upload', builder: (_, _) => const UploadScreen()),
      GoRoute(
        path: '/photos/:id',
        builder: (_, _) => const Scaffold(body: Text('사진 상세')),
      ),
      GoRoute(
        path: '/home',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('홈'),
              TextButton(
                onPressed: () => context.push('/upload'),
                child: const Text('새 게시글'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [uploadRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _goToForm(WidgetTester tester) async {
  await tester.tap(find.textContaining('다음'));
  await tester.pumpAndSettle();
  expect(find.text('사진 확인'), findsOneWidget);
  await tester.tap(find.text('다음'));
  await tester.pumpAndSettle();
  expect(find.text('게시글 작성'), findsOneWidget);
}

void main() {
  test('사진과 자유 태그 선택 규칙을 한도 안에서 일관되게 적용한다', () async {
    final container = ProviderContainer(
      overrides: [
        uploadRepositoryProvider.overrideWithValue(_StubUploadRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(uploadControllerProvider.future);
    final controller = container.read(uploadControllerProvider.notifier);

    for (var index = 2; index <= UploadLimits.photoCount; index++) {
      expect(
        controller.addCapturedPhoto(UploadPhoto(id: 'captured-$index')),
        isTrue,
      );
    }
    expect(
      controller.addCapturedPhoto(const UploadPhoto(id: 'over-limit')),
      isFalse,
    );

    controller.applyEventContext(
      const UploadEventContext(
        eventId: 'event-1',
        eventTitle: '서울 빛초롱 축제',
        place: _StubUploadRepository.place,
        fixedTags: ['고정태그', '행사태그'],
        verifyRadiusM: 2000,
      ),
    );
    controller.addUserTag('#고정태그');
    for (var index = 0; index < UploadLimits.userTagCount; index++) {
      controller.addUserTag('태그$index');
    }
    controller.addUserTag('태그0');
    controller.addUserTag('초과태그');

    final state = container.read(uploadControllerProvider).requireValue;
    expect(state.selectedPhotoIds, hasLength(UploadLimits.photoCount));
    expect(state.userTags, hasLength(UploadLimits.userTagCount));
    expect(state.userTags, isNot(contains('고정태그')));
    expect(state.userTags, isNot(contains('초과태그')));
  });

  test('이벤트 컨텍스트와 고정·자유 태그가 게시 요청에 보존된다', () async {
    final repository = _StubUploadRepository();
    final container = ProviderContainer(
      overrides: [uploadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(uploadControllerProvider.future);
    final controller = container.read(uploadControllerProvider.notifier);

    controller.applyEventContext(
      const UploadEventContext(
        eventId: 'event-1',
        eventTitle: '서울 빛초롱 축제',
        place: _StubUploadRepository.place,
        fixedTags: ['서울', '서울빛초롱축제'],
        verifyRadiusM: 2000,
      ),
    );
    controller.addUserTag('야경');
    controller.showReview();
    await controller.showForm();
    controller.updateTitle('빛초롱의 밤');
    await controller.submit();

    expect(repository.submittedDraft?.eventId, 'event-1');
    expect(repository.submittedDraft?.place.id, 'place-1');
    expect(repository.submittedDraft?.fixedTags, ['서울', '서울빛초롱축제']);
    expect(repository.submittedDraft?.userTags, ['야경']);
  });

  testWidgets('일반 작성에서도 태그를 추가·삭제하고 게시에 포함한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _StubUploadRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    await _goToForm(tester);
    final input = find.byKey(const Key('upload-tag-input'));
    await tester.ensureVisible(input);
    expect(find.text('태그 (추가 입력은 선택)', findRichText: true), findsOneWidget);
    expect(find.text('태그 입력 (0/9)'), findsOneWidget);
    expect(find.widgetWithText(Chip, '#전주한옥마을'), findsOneWidget);
    await tester.enterText(input, '#공원');
    await tester.ensureVisible(find.byKey(const Key('upload-tag-add')));
    await tester.tap(find.byKey(const Key('upload-tag-add')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '#공원'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    await tester.enterText(input, '야경');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '#야경'), findsOneWidget);
    final parkChip = find.widgetWithText(InputChip, '#공원');
    await tester.ensureVisible(parkChip);
    await tester.tap(
      find.descendant(of: parkChip, matching: find.byTooltip('Delete')),
    );
    await tester.pumpAndSettle();
    expect(parkChip, findsNothing);
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(repository.submittedDraft?.userTags, ['야경']);
    expect(repository.submittedDraft?.fixedTags, ['전주한옥마을']);
    expect(find.text('업로드 완료!'), findsOneWidget);
  });

  testWidgets('행사 작성은 고정 태그 잠금과 자유 태그 입력을 함께 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('upload-flow'))),
    );
    container
        .read(uploadControllerProvider.notifier)
        .applyEventContext(
          const UploadEventContext(
            eventId: 'evt_2',
            eventTitle: '사천에어쇼',
            place: _StubUploadRepository.place,
            fixedTags: ['사천', '에어쇼'],
            verifyRadiusM: 2000,
          ),
        );
    await tester.pumpAndSettle();
    await _goToForm(tester);
    final input = find.byKey(const Key('upload-tag-input'));
    await tester.ensureVisible(input);
    expect(find.text('이벤트 태그'), findsOneWidget);
    expect(find.text('태그 입력 (0/8)'), findsOneWidget);
    expect(find.widgetWithText(Chip, '#사천'), findsOneWidget);
    expect(find.widgetWithText(Chip, '#에어쇼'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    await tester.enterText(input, '비행');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '#비행'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
  });

  test('일반 게시글은 장소 태그 몫을 남기고 추가 태그 9개까지 입력한다', () async {
    final container = ProviderContainer(
      overrides: [
        uploadRepositoryProvider.overrideWithValue(_StubUploadRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(uploadControllerProvider.future);
    final controller = container.read(uploadControllerProvider.notifier);
    for (var index = 0; index < 11; index++) {
      controller.addUserTag('태그$index');
    }
    expect(
      container.read(uploadControllerProvider).requireValue.userTags,
      hasLength(9),
    );
    expect(
      container.read(uploadControllerProvider).requireValue.userTags,
      isNot(contains('태그9')),
    );
    controller.removeUserTag('태그0');
    controller.addUserTag('다시추가');
    expect(
      container.read(uploadControllerProvider).requireValue.userTags,
      hasLength(9),
    );
    expect(
      container.read(uploadControllerProvider).requireValue.userTags,
      contains('다시추가'),
    );
  });

  testWidgets('추가 태그 없이 자동 장소 태그만으로 게시를 완료한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _StubUploadRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    await _goToForm(tester);
    await tester.ensureVisible(find.byKey(const Key('upload-tag-input')));
    expect(find.widgetWithText(Chip, '#전주한옥마을'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '#전주한옥마을'), findsNothing);
    expect(find.text('태그 (추가 입력은 선택)', findRichText: true), findsOneWidget);
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(repository.submittedDraft?.userTags, isEmpty);
    expect(repository.submittedDraft?.requestTagNames, ['전주한옥마을']);
    expect(find.text('업로드 완료!'), findsOneWidget);
  });

  test('장소 변경과 행사 전환이 자동 태그·중복·전체 한도를 함께 갱신한다', () async {
    final repository = _StubUploadRepository();
    final container = ProviderContainer(
      overrides: [uploadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(uploadControllerProvider.future);
    final controller = container.read(uploadControllerProvider.notifier);
    await controller.showForm();
    controller.addUserTag('#전주 한옥마을');
    expect(
      container.read(uploadControllerProvider).requireValue.userTags,
      isEmpty,
    );
    controller.addUserTag('은구비 공원');
    controller.selectPlace(
      const UploadPlace(id: 'plc_2zq', name: '은구비공원', address: ''),
    );
    var state = container.read(uploadControllerProvider).requireValue;
    expect(state.automaticTags, ['은구비공원']);
    expect(state.userTags, isEmpty);
    controller.removeUserTag('은구비공원');
    expect(
      container.read(uploadControllerProvider).requireValue.automaticTags,
      ['은구비공원'],
    );
    controller.addUserTag('PHOTO');
    controller.addUserTag('photo');
    for (var index = 0; index < 9; index++) {
      controller.addUserTag('태그$index');
    }
    expect(
      container.read(uploadControllerProvider).requireValue.userTags,
      hasLength(9),
    );
    controller.applyEventContext(
      const UploadEventContext(
        eventId: 'evt_2',
        eventTitle: '사천에어쇼',
        place: _StubUploadRepository.place,
        fixedTags: ['사천', '에어쇼'],
        verifyRadiusM: 2000,
      ),
    );
    state = container.read(uploadControllerProvider).requireValue;
    expect(state.automaticTags, ['사천', '에어쇼']);
    expect(state.userTags, hasLength(8));
    expect(
      state.userTags.where((tag) => normalizeUploadTag(tag) == 'photo'),
      hasLength(1),
    );
    await controller.submit();
    expect(repository.submittedDraft?.requestTagNames, hasLength(8));
    expect(repository.submittedDraft?.fixedTags, ['사천', '에어쇼']);
  });

  testWidgets('갤러리에서 사진 확인과 자동 매칭 폼을 거쳐 업로드한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('upload-gallery-grid')), findsOneWidget);
    expect(find.text('다음 (1)'), findsOneWidget);

    await _goToForm(tester);
    expect(find.text('전주 한옥마을의 봄'), findsOneWidget);
    expect(find.text('자동 매칭 완료'), findsOneWidget);

    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.text('업로드 완료!'), findsOneWidget);
    expect(find.text('축제 참가 뱃지 획득!'), findsOneWidget);

    await tester.tap(find.text('게시글 보기'));
    await tester.pumpAndSettle();
    expect(find.text('사진 상세'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsOneWidget);
  });

  testWidgets('등록 완료 후 다시 진입하면 지난 완료 화면 대신 새 갤러리부터 시작한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _StubUploadRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    await _goToForm(tester);
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.text('업로드 완료!'), findsOneWidget);

    await tester.tap(find.text('홈 지도에서 확인'));
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsOneWidget);
    await tester.tap(find.text('새 게시글'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('upload-gallery-grid')), findsOneWidget);
    expect(find.text('업로드 완료!'), findsNothing);
    expect(find.text('다음 (1)'), findsOneWidget);
  });

  testWidgets('제목과 장소가 없으면 검증 메시지를 표시하고 장소 검색이 동작한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository(hasMetadata: false)));
    await tester.pumpAndSettle();

    await _goToForm(tester);
    expect(find.text('주변 장소를 찾지 못했어요.'), findsOneWidget);

    await tester.tap(find.text('게시'));
    await tester.pump();
    expect(find.text('제목을 입력해 주세요'), findsOneWidget);
    expect(find.text('장소를 선택해 주세요'), findsOneWidget);

    await tester.tap(find.text('장소 직접 검색'));
    await tester.pumpAndSettle();
    expect(find.text('장소 검색'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('upload-place-search')), '한옥');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('전주 한옥마을'), findsOneWidget);
    await tester.tap(find.text('전주 한옥마을'));
    await tester.pumpAndSettle();
    expect(find.text('게시글 작성'), findsOneWidget);
    expect(find.text('전주 한옥마을'), findsOneWidget);
    expect(find.text('선택 완료'), findsOneWidget);
    expect(find.text('자동 매칭 완료'), findsNothing);
    expect(find.textContaining('주변 장소를 찾지 못했어요'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '직접 선택한 장소');
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.text('업로드 완료!'), findsOneWidget);
  });

  test('직접 선택하면 늦은 자동 검색의 빈 결과·다른 장소·오류가 선택을 바꾸지 않는다', () async {
    const manualPlace = UploadPlace(id: 'plc_2zq', name: '은구비공원', address: '');
    for (final outcome in ['empty', 'other', 'error']) {
      final repository = _DelayedMatchRepository();
      final container = ProviderContainer(
        overrides: [uploadRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(uploadControllerProvider.future);
      final controller = container.read(uploadControllerProvider.notifier);
      final form = controller.showForm();
      controller.selectPlace(manualPlace);
      if (outcome == 'error') {
        repository.pendingMatch.completeError(Exception('자동 검색 실패'));
      } else {
        repository.pendingMatch.complete(
          outcome == 'empty' ? [] : [_StubUploadRepository.place],
        );
      }
      await form;
      final state = container.read(uploadControllerProvider).requireValue;
      expect(state.selectedPlace, manualPlace);
      expect(state.automaticTags, ['은구비공원']);
      expect(state.isMatchingLocation, isFalse);
      expect(state.locationMessage, isNull);
    }
  });

  testWidgets('최근과 임시 저장 피드 탭이 전환되고 취소 동작을 확인한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gallery-photo-1')), findsOneWidget);
    await tester.tap(find.text('임시 저장 피드'));
    await tester.pump();
    expect(find.byKey(const ValueKey('gallery-draft-1')), findsOneWidget);

    await tester.tap(find.byTooltip('업로드 취소'));
    await tester.pumpAndSettle();
    expect(find.text('업로드를 취소할까요?'), findsOneWidget);
    expect(find.text('계속 작성'), findsOneWidget);
  });

  testWidgets('빈 갤러리에서도 카메라 진입점이 유지되고 다음 버튼이 비활성화된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository(emptyGallery: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('upload-camera-tile')), findsOneWidget);
    expect(find.text('다음 (0)'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '다음 (0)'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('촬영 좌표가 없으면 게시 전에 낮음 등급 이유를 알린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository(cameraPhoto: true)));
    await tester.pumpAndSettle();
    await _goToForm(tester);

    expect(find.byKey(const Key('camera-location-warning')), findsOneWidget);
    expect(find.textContaining('낮음 등급으로 등록됩니다'), findsOneWidget);
  });

  testWidgets('시스템 뒤로가기는 작성 단계부터 한 단계씩 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository()));
    await tester.pumpAndSettle();
    await _goToForm(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('사진 확인'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('새 게시물'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('업로드를 취소할까요?'), findsOneWidget);
  });

  testWidgets('구체적인 오류를 표시하고 입력을 보존해 재시도할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _StubUploadRepository(
      submitFailure: const UploadFailure(UploadFailureReason.photoTooLarge),
    );
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    await _goToForm(tester);

    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.textContaining('사진 용량이 업로드 한도를 넘었어요'), findsOneWidget);
    expect(find.text('게시글 작성'), findsOneWidget);
    expect(find.text('전주 한옥마을의 봄'), findsOneWidget);
    expect(find.text('게시'), findsOneWidget);
    repository.submitFailure = null;
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.text('업로드 완료!'), findsOneWidget);
    expect(find.textContaining('사진 용량이 업로드 한도를 넘었어요'), findsNothing);
  });

  testWidgets('알 수 없는 등록 결과는 실패·재등록 안내 대신 확인을 요청한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        _StubUploadRepository(submitFailure: Exception('unexpected response')),
      ),
    );
    await tester.pumpAndSettle();
    await _goToForm(tester);
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.textContaining('내 게시글을 먼저 확인해 주세요'), findsOneWidget);
    expect(find.text('게시글 작성'), findsOneWidget);
    expect(find.text('업로드 완료!'), findsNothing);
  });

  test('등록 처리 중 연속 제출과 완료 후 재제출은 추가 요청을 보내지 않는다', () async {
    final pending = Completer<UploadResult>();
    final repository = _StubUploadRepository(pendingSubmit: pending);
    final container = ProviderContainer(
      overrides: [uploadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(uploadControllerProvider.future);
    final controller = container.read(uploadControllerProvider.notifier);
    await controller.showForm();
    final first = controller.submit();
    await controller.submit();
    expect(repository.submitCount, 1);
    pending.complete(const UploadResult(postId: 'pst_42'));
    await first;
    await controller.submit();
    expect(repository.submitCount, 1);
    expect(
      container.read(uploadControllerProvider).requireValue.step,
      UploadStep.complete,
    );
  });

  testWidgets('가로 화면에서도 갤러리 레이아웃이 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(893, 412));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('upload-gallery-grid')), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/upload/application/upload_controller.dart';
import 'package:snap_here/src/features/upload/domain/upload_models.dart';
import 'package:snap_here/src/features/upload/domain/upload_repository.dart';
import 'package:snap_here/src/features/upload/presentation/upload_screen.dart';

class _StubUploadRepository implements UploadRepository {
  _StubUploadRepository({
    this.hasMetadata = true,
    this.emptyGallery = false,
    this.failSubmit = false,
  });

  final bool hasMetadata;
  final bool emptyGallery;
  final bool failSubmit;
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
            assetPath: 'assets/images/upload/upload_01.png',
            suggestedTitle: hasMetadata ? '전주 한옥마을의 봄' : null,
            latitude: hasMetadata ? 35.815 : null,
            longitude: hasMetadata ? 127.153 : null,
          ),
          const UploadPhoto(
            id: 'photo-2',
            assetPath: 'assets/images/upload/upload_02.png',
          ),
        ];

  @override
  Future<List<UploadPhoto>> fetchDraftGallery() async => emptyGallery
      ? const []
      : const [
          UploadPhoto(
            id: 'draft-1',
            assetPath: 'assets/images/upload/upload_03.png',
          ),
        ];

  @override
  Future<void> openMediaSettings() async {}

  @override
  Future<List<UploadPlace>> matchPlaces(UploadPhoto photo) async =>
      photo.hasLocationMetadata ? [place] : [];

  @override
  Future<List<UploadPlace>> searchPlaces(String keyword) async => [place];

  @override
  Future<UploadResult> createPost(UploadDraft draft) async {
    if (failSubmit) throw Exception('network error');
    submittedDraft = draft;
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
        builder: (_, _) => const Scaffold(body: Text('홈')),
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
        fixedTags: ['고정태그'],
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

  testWidgets('게시 실패 시 재시도 가능한 오류 메시지를 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(_StubUploadRepository(failSubmit: true)));
    await tester.pumpAndSettle();
    await _goToForm(tester);

    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.textContaining('게시물을 등록하지 못했어요'), findsOneWidget);
    expect(find.text('게시'), findsOneWidget);
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

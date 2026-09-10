import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/event/application/event_providers.dart';
import 'package:snap_here/src/features/event/domain/event_models.dart';
import 'package:snap_here/src/features/event/domain/event_repository.dart';
import 'package:snap_here/src/features/event/presentation/event_detail_screen.dart';
import 'package:snap_here/src/features/event/presentation/event_screen.dart';

class _StubEventRepository implements EventRepository {
  int? requestedAreaCode;

  final event = EventSummary(
    eventId: 'event-1',
    title: '서울 빛초롱 축제',
    thumbnailUrl: 'assets/images/upload/upload_04.png',
    areaCode: 1,
    areaName: '서울',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 20),
    status: EventStatus.ongoing,
    dday: 0,
    isNew: true,
    participantCount: 248,
  );

  @override
  Future<List<EventSummary>> fetchEvents({int? areaCode}) async {
    requestedAreaCode = areaCode;
    return [event];
  }

  @override
  Future<List<EventRegionSummary>> fetchRegionSummary() async => const [
    EventRegionSummary(
      areaCode: 1,
      areaName: '서울',
      eventCount: 12,
      newCount: 2,
    ),
  ];

  @override
  Future<EventDetail> fetchEvent(String eventId) async => EventDetail(
    event: event,
    overview: '도시의 밤을 사진으로 기록하는 행사입니다.',
    place: const EventPlace(
      placeId: 'place-1',
      name: '청계광장',
      address: '서울 종로구 서린동',
      latitude: 37.57,
      longitude: 126.98,
    ),
    fixedTags: const ['서울', '서울빛초롱축제'],
    badge: const EventBadge(
      badgeId: 'badge-1',
      name: '서울 빛초롱 참여 뱃지',
      description: '현장에서 사진을 올리면 받을 수 있어요.',
    ),
    verifyRadiusM: 2000,
  );

  @override
  Future<List<EventPost>> fetchEventPosts(String eventId) async => const [
    EventPost(
      postId: 'post-1',
      authorName: '여행토끼',
      thumbnailUrl: 'assets/images/upload/upload_03.png',
      likeCount: 82,
    ),
  ];

  @override
  Future<EventUploadContext> fetchUploadContext(String eventId) async {
    final detail = await fetchEvent(eventId);
    return EventUploadContext(
      event: detail.event,
      place: detail.place,
      fixedTags: detail.fixedTags,
      verifyRadiusM: detail.verifyRadiusM,
      badge: detail.badge,
    );
  }

  @override
  Future<List<EventSummary>> fetchNearbyEvents({
    required double lat,
    required double lng,
    int? radiusM,
  }) async => const [];
}

Widget _wrap({
  required Widget child,
  required _StubEventRepository repository,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(
        path: '/events/:eventId',
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/upload',
        builder: (_, state) => Scaffold(
          body: Text('이벤트 업로드 ${state.uri.queryParameters['eventId']}'),
        ),
      ),
      GoRoute(
        path: '/map',
        builder: (_, _) => const Scaffold(body: Text('지도 화면')),
      ),
      GoRoute(
        path: '/photos/:postId',
        builder: (_, _) => const Scaffold(body: Text('게시글 상세')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const Scaffold(body: Text('알림')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [eventRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  testWidgets('이벤트 홈은 지역과 신규 행사 카드를 보여준다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _StubEventRepository();

    await tester.pumpWidget(
      _wrap(child: const EventScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('지금, 여기서만 만나는 순간'), findsOneWidget);
    expect(find.text('서울 빛초롱 축제'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('248명이 기록했어요'), findsOneWidget);

    await tester.tap(find.text('서울').first);
    await tester.pumpAndSettle();
    expect(repository.requestedAreaCode, 1);
  });

  testWidgets('이벤트 상세는 정보·뱃지·참여 업로드 진입을 제공한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _StubEventRepository();

    await tester.pumpWidget(
      _wrap(
        child: const EventDetailScreen(eventId: 'event-1'),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('서울 빛초롱 축제'), findsOneWidget);
    expect(find.text('청계광장'), findsOneWidget);
    expect(find.text('서울 빛초롱 참여 뱃지'), findsOneWidget);
    expect(find.text('참여 스냅'), findsOneWidget);

    await tester.tap(find.text('사진 올리고 참여하기'));
    await tester.pumpAndSettle();
    expect(find.text('이벤트 업로드 event-1'), findsOneWidget);
  });
}

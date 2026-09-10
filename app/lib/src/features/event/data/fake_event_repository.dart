import 'package:snap_here/src/features/event/domain/event_models.dart';
import 'package:snap_here/src/features/event/domain/event_repository.dart';

class FakeEventRepository implements EventRepository {
  static const _latency = Duration(milliseconds: 180);

  static final _events = <EventSummary>[
    EventSummary(
      eventId: 'event-seoul-light',
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
    ),
    EventSummary(
      eventId: 'event-busan-sea',
      title: '부산 바다 미술제',
      thumbnailUrl: 'assets/images/upload/upload_07.png',
      areaCode: 6,
      areaName: '부산',
      startDate: DateTime(2026, 9, 6),
      endDate: DateTime(2026, 10, 11),
      status: EventStatus.upcoming,
      dday: 3,
      isNew: true,
      participantCount: 93,
    ),
    EventSummary(
      eventId: 'event-jeonju-culture',
      title: '전주 한옥 문화주간',
      thumbnailUrl: 'assets/images/upload/upload_01.png',
      areaCode: 37,
      areaName: '전북',
      startDate: DateTime(2026, 9, 3),
      endDate: DateTime(2026, 9, 13),
      status: EventStatus.ongoing,
      dday: 0,
      participantCount: 156,
    ),
    EventSummary(
      eventId: 'event-jeju-sunset',
      title: '제주 노을 사진전',
      thumbnailUrl: 'assets/images/upload/upload_10.png',
      areaCode: 39,
      areaName: '제주',
      startDate: DateTime(2026, 9, 12),
      endDate: DateTime(2026, 9, 30),
      status: EventStatus.upcoming,
      dday: 9,
      participantCount: 41,
    ),
  ];

  @override
  Future<List<EventRegionSummary>> fetchRegionSummary() async {
    await Future<void>.delayed(_latency);
    return const [
      EventRegionSummary(
        areaCode: 1,
        areaName: '서울',
        eventCount: 12,
        newCount: 2,
      ),
      EventRegionSummary(
        areaCode: 6,
        areaName: '부산',
        eventCount: 8,
        newCount: 1,
      ),
      EventRegionSummary(
        areaCode: 37,
        areaName: '전북',
        eventCount: 5,
        newCount: 0,
      ),
      EventRegionSummary(
        areaCode: 39,
        areaName: '제주',
        eventCount: 7,
        newCount: 0,
      ),
    ];
  }

  @override
  Future<List<EventSummary>> fetchEvents({int? areaCode}) async {
    await Future<void>.delayed(_latency);
    return _events
        .where((event) => areaCode == null || event.areaCode == areaCode)
        .toList(growable: false);
  }

  @override
  Future<EventDetail> fetchEvent(String eventId) async {
    await Future<void>.delayed(_latency);
    final event = _events.firstWhere((item) => item.eventId == eventId);
    return EventDetail(
      event: event,
      overview: '도시의 밤과 지역 문화를 사진으로 기록하는 특별한 행사입니다. 행사장을 거닐며 나만의 장면을 남겨 보세요.',
      place: _place(event),
      fixedTags: [event.areaName, event.title.replaceAll(' ', '')],
      badge: EventBadge(
        badgeId: 'badge-${event.eventId}',
        name: '${event.title} 참여 뱃지',
        description: '행사 현장에서 사진을 올리면 받을 수 있어요.',
      ),
      verifyRadiusM: 2000,
    );
  }

  @override
  Future<List<EventPost>> fetchEventPosts(String eventId) async {
    await Future<void>.delayed(_latency);
    return const [
      EventPost(
        postId: 'event-post-1',
        authorName: '여행토끼',
        thumbnailUrl: 'assets/images/upload/upload_03.png',
        likeCount: 82,
      ),
      EventPost(
        postId: 'event-post-2',
        authorName: 'snap_min',
        thumbnailUrl: 'assets/images/upload/upload_06.png',
        likeCount: 57,
      ),
      EventPost(
        postId: 'event-post-3',
        authorName: '오늘의산책',
        thumbnailUrl: 'assets/images/upload/upload_09.png',
        likeCount: 31,
      ),
    ];
  }

  @override
  Future<EventUploadContext> fetchUploadContext(String eventId) async {
    final detail = await fetchEvent(eventId);
    return EventUploadContext(
      event: detail.event,
      place: detail.place,
      fixedTags: detail.fixedTags,
      badge: detail.badge,
      verifyRadiusM: detail.verifyRadiusM,
    );
  }

  EventPlace _place(EventSummary event) => EventPlace(
    placeId: 'place-${event.eventId}',
    name: switch (event.areaCode) {
      1 => '청계광장',
      6 => '다대포해수욕장',
      37 => '전주 한옥마을',
      _ => '새별오름',
    },
    address: switch (event.areaCode) {
      1 => '서울 종로구 서린동 14-1',
      6 => '부산 사하구 몰운대1길 14',
      37 => '전북 전주시 완산구 기린대로 99',
      _ => '제주 제주시 애월읍 봉성리 산59-8',
    },
    latitude: 37.57,
    longitude: 126.98,
  );

  @override
  Future<List<EventSummary>> fetchNearbyEvents({
    required double lat,
    required double lng,
    int? radiusM,
  }) => fetchEvents();
}

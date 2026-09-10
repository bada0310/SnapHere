import 'package:snap_here/src/features/event/domain/event_models.dart';

abstract interface class EventRepository {
  Future<List<EventRegionSummary>> fetchRegionSummary();

  Future<List<EventSummary>> fetchEvents({int? areaCode});

  Future<EventDetail> fetchEvent(String eventId);

  Future<List<EventPost>> fetchEventPosts(String eventId);

  Future<EventUploadContext> fetchUploadContext(String eventId);

  /// 현재 위치 주변에서 열리는 행사 (API-EVT-002).
  Future<List<EventSummary>> fetchNearbyEvents({
    required double lat,
    required double lng,
    int? radiusM,
  });
}

class EventFailure implements Exception {
  const EventFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/event/data/api_event_repository.dart';
import 'package:snap_here/src/features/event/data/fake_event_repository.dart';
import 'package:snap_here/src/features/event/domain/event_models.dart';
import 'package:snap_here/src/features/event/domain/event_repository.dart';

const _useFakeEvents = bool.fromEnvironment(
  'USE_FAKE_EVENTS',
  defaultValue: false,
);

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  if (_useFakeEvents) return FakeEventRepository();
  return ApiEventRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  );
});

final selectedEventRegionProvider =
    NotifierProvider<SelectedEventRegionNotifier, int?>(
      SelectedEventRegionNotifier.new,
    );

class SelectedEventRegionNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? areaCode) => state = areaCode;
}

final viewedEventRegionsProvider =
    NotifierProvider<ViewedEventRegionsNotifier, Set<int>>(
      ViewedEventRegionsNotifier.new,
    );

class ViewedEventRegionsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => <int>{};

  void markViewed(int areaCode) => state = {...state, areaCode};
}

final eventRegionSummaryProvider = FutureProvider<List<EventRegionSummary>>(
  (ref) => ref.watch(eventRepositoryProvider).fetchRegionSummary(),
);

final eventListProvider = FutureProvider<List<EventSummary>>((ref) {
  final areaCode = ref.watch(selectedEventRegionProvider);
  return ref.watch(eventRepositoryProvider).fetchEvents(areaCode: areaCode);
});

final eventDetailProvider = FutureProvider.family<EventDetail, String>(
  (ref, eventId) => ref.watch(eventRepositoryProvider).fetchEvent(eventId),
);

final eventPostsProvider = FutureProvider.family<List<EventPost>, String>(
  (ref, eventId) => ref.watch(eventRepositoryProvider).fetchEventPosts(eventId),
);

final eventUploadContextProvider =
    FutureProvider.family<EventUploadContext, String>(
      (ref, eventId) =>
          ref.watch(eventRepositoryProvider).fetchUploadContext(eventId),
    );

/// 주변 이벤트 (API-EVT-002). 좌표가 있어야 하므로 화면이 위치를 넘겨준다.
final nearbyEventsProvider =
    FutureProvider.family<List<EventSummary>, ({double lat, double lng})>(
      (ref, at) => ref
          .watch(eventRepositoryProvider)
          .fetchNearbyEvents(lat: at.lat, lng: at.lng),
    );

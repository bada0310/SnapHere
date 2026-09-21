import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/core/network/cursor_page.dart';
import 'package:snap_here/src/features/place/application/place_providers.dart';
import 'package:snap_here/src/features/place/domain/place_models.dart';
import 'package:snap_here/src/features/place/domain/place_repository.dart';
import 'package:snap_here/src/features/place/presentation/place_detail_screen.dart';

class _FailingPlaceRepository implements PlaceRepository {
  int detailCalls = 0;

  @override
  Future<PlaceDetail> fetchPlace(String placeId) async {
    detailCalls += 1;
    throw StateError('place unavailable');
  }

  @override
  Future<CursorPage<PlacePost>> fetchPlacePosts(
    String placeId, {
    String? cursor,
  }) async => const CursorPage(items: []);

  @override
  Future<List<PlaceVisitor>> fetchVisitors(String placeId) async => const [];

  @override
  Future<bool> setBookmarked(String placeId, bool bookmarked) async =>
      bookmarked;
}

void main() {
  testWidgets('장소 상세 실패는 자동 재시도하지 않고 다시 시도를 제공한다', (tester) async {
    final repository = _FailingPlaceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [placeRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PlaceDetailScreen(placeId: 'plc_1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('장소 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('네트워크에 연결할 수 없어요'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(repository.detailCalls, 1);
  });
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/explore/application/explore_providers.dart';
import 'package:snap_here/src/features/home/presentation/home_screen.dart';
import 'package:snap_here/src/features/map/application/map_configuration.dart';
import 'package:snap_here/src/features/map/application/map_providers.dart';
import 'package:snap_here/src/features/map/data/api_map_repository.dart';
import 'package:snap_here/src/features/map/domain/map_models.dart';
import 'package:snap_here/src/features/map/presentation/map_screen.dart';
import 'package:snap_here/src/features/map/presentation/photo_marker.dart';
import 'package:snap_here/src/features/map/presentation/photo_marker_layer.dart';
import 'package:snap_here/src/features/map/presentation/snap_map.dart';

const _viewport = MapViewport(
  west: 124,
  south: 33,
  east: 132,
  north: 39,
  zoom: 6,
);
typedef _Camera = ({MapViewport viewport, int zoom, bool active});

class _MapHarness extends ConsumerWidget {
  const _MapHarness({required this.camera});
  final _Camera camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(viewportPhotoMarkersProvider(camera.viewport));
    return TickerMode(
      enabled: camera.active,
      child: PhotoMarkerLayer(
        photos: photos.value ?? const [],
        builder: (markers) => SnapMap(markers: markers),
      ),
    );
  }
}

void main() {
  late ValueNotifier<_Camera> camera;
  late GoRouter router;
  late List<Uri> requests;
  final firstIcon = BitmapDescriptor.defaultMarkerWithHue(60);
  final secondIcon = BitmapDescriptor.defaultMarkerWithHue(120);

  Future<void> mount(WidgetTester tester) async {
    requests = [];
    camera = ValueNotifier((viewport: _viewport, zoom: 6, active: true));
    final repository = ApiMapRepository(
      accessToken: 'test-token',
      api: ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          requests.add(request.url);
          expect(request.headers['authorization'], 'Bearer test-token');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': [_photo],
              }),
            ),
            200,
          );
        }),
      ),
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder(
            valueListenable: camera,
            builder: (_, value, _) => _MapHarness(camera: value),
          ),
        ),
        GoRoute(
          path: '/photos/:postId',
          builder: (_, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['postId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapConfiguredProvider.overrideWith((_) async => false),
          mapRepositoryProvider.overrideWithValue(repository),
          photoMarkerIconProvider.overrideWith((_, args) async {
            if (args.url.endsWith('first.jpg')) return firstIcon;
            return secondIcon;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Marker marker(WidgetTester tester) =>
      tester.widget<SnapMap>(find.byType(SnapMap)).markers.single;

  test('candidate parsing keeps only the top-ranked representative photo', () {
    final photo = PhotoMarker.fromJson({
      ..._photo,
      'candidates': [
        {'postId': 'missing-cover'},
        for (var i = 0; i < 12; i++)
          {'postId': 'pst_$i', 'thumbnailUrl': 'https://test/$i.jpg'},
      ],
    });
    expect(photo.candidates, hasLength(1));
    expect(photo.candidates.first.postId, 'pst_0');
    expect(photo.postCount, 7);
    expect(photo.postCountIsLowerBound, false);
    expect(() => photo.candidates.clear(), throwsUnsupportedError);
  });

  test('legacy grid response uses representative place and a capped candidate count', () {
    final photo = PhotoMarker.fromJson({
      'cellKey': 'legacy-grid-cell',
      'lat': 37.5,
      'lng': 127.5,
      'candidates': [
        for (var i = 0; i < 10; i++)
          {
            'postId': 'pst_$i',
            'thumbnailUrl': 'https://test/$i.jpg',
            'place': {'lat': 37.5588, 'lng': 127.0048},
          },
      ],
    });

    expect(photo.lat, 37.5588);
    expect(photo.lng, 127.0048);
    expect(photo.postCount, 10);
    expect(photo.postCountIsLowerBound, true);
    expect(photo.candidates.single.postId, 'pst_0');
  });

  testWidgets(
    'representative photo stays fixed without querying and opens its post',
    (tester) async {
      await mount(tester);
      expect(requests.single.path, '/api/v1/map/photo-markers');
      expect(requests.single.queryParameters, _viewport.toQuery());
      expect(marker(tester).icon, firstIcon);
      expect(marker(tester).position, const LatLng(35.09, 128.07));
      expect(marker(tester).anchor, const Offset(.5, .5));
      expect(marker(tester).consumeTapEvents, true);
      await tester.pump(const Duration(seconds: 9));
      expect(marker(tester).icon, firstIcon);
      expect(requests, hasLength(1));
      marker(tester).onTap!();
      await tester.pumpAndSettle();
      expect(find.text('detail pst_first'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'viewport changes fetch new bounds while keeping the representative photo',
    (tester) async {
      await mount(tester);
      camera.value = (viewport: _viewport, zoom: 14, active: true);
      await tester.pumpAndSettle();
      expect(marker(tester).icon, firstIcon);
      await tester.pump(const Duration(seconds: 9));
      expect(marker(tester).icon, firstIcon);
      expect(requests, hasLength(1));
      const moved = MapViewport(
        west: 128,
        south: 35,
        east: 128.2,
        north: 35.2,
        zoom: 14,
      );
      camera.value = (viewport: moved, zoom: 14, active: true);
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last.queryParameters, moved.toQuery());
      marker(tester).onTap!();
      await tester.pumpAndSettle();
      expect(find.text('detail pst_first'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'home includes the shared photo layer and camera idle synchronization',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapConfiguredProvider.overrideWith((_) async => false),
            mapRegionsProvider.overrideWith((_) async => const []),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhotoMarkerLayer), findsOneWidget);
      final map = tester.widget<SnapMap>(find.byType(SnapMap));
      expect(map.onCameraMove, isNotNull);
      expect(map.onCameraIdle, isNotNull);
      map.onCameraIdle!(); // 아직 플랫폼 지도가 없을 때도 예외 없이 동작한다.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map exploration uses the photo icon instead of a duplicate cell pin',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapConfiguredProvider.overrideWith((_) async => false),
            heatmapProvider.overrideWith(
              (_) async => const HeatmapResult(
                cells: [
                  HeatmapCell(
                    cellKey: 'weekly-cell',
                    lat: 35.09,
                    lng: 128.07,
                    postCount: 2,
                  ),
                ],
              ),
            ),
            photoMarkersProvider.overrideWith(
              (_) async => [PhotoMarker.fromJson(_photo)],
            ),
            photoMarkerIconProvider.overrideWith((_, _) async => firstIcon),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(marker(tester).markerId.value, 'photo_weekly-cell');
      expect(marker(tester).icon, firstIcon);
      tester.widget<SnapMap>(find.byType(SnapMap)).onCameraIdle!();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'thumbnail raster contains the image and image failure produces a photo placeholder',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 60, 40),
          Paint()..color = Colors.red,
        );
        final picture = recorder.endRecording();
        final source = await picture.toImage(60, 40);
        final png = (await source.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        source.dispose();
        picture.dispose();
        final icon = await photoMarkerIcon(MemoryImage(png), 7);
        final serialized = icon.toJson() as List;
        expect(serialized.first, 'bytes');
        final data = serialized[1] as Map;
        expect(data['width'], 60);
        expect(data['height'], 60);
        final codec = await ui.instantiateImageCodec(
          data['byteData'] as Uint8List,
        );
        final image = (await codec.getNextFrame()).image;
        final pixels = await image.toByteData();
        expect(image.width, 180);
        expect(image.height, 180);
        expect(pixels!.buffer.asUint8List().sublist(0, 4), [0, 0, 0, 0]);
        expect(
          pixels.buffer.asUint8List().sublist(
            (90 * 180 + 90) * 4,
            (90 * 180 + 90) * 4 + 4,
          ),
          [244, 67, 54, 255],
        );
        expect(
          pixels.buffer.asUint8List().sublist(
            (15 * 180 + 144) * 4,
            (15 * 180 + 144) * 4 + 4,
          ),
          [122, 221, 242, 255],
        );
        image.dispose();
        codec.dispose();
        final fallback = await photoMarkerIcon(MemoryImage(Uint8List(0)));
        expect((fallback.toJson() as List).first, 'bytes');
      });
      expect(tester.takeException(), isNull);
    },
  );
}

const _photo = {
  'cellKey': 'weekly-cell',
  'lat': 35.09,
  'lng': 128.07,
  'postCount': 7,
  'candidates': [
    {
      'postId': 'pst_first',
      'thumbnailUrl': 'https://test/first.jpg',
      'tier': 'HIGH',
    },
    {
      'postId': 'pst_second',
      'thumbnailUrl': 'https://test/second.jpg',
      'tier': 'MEDIUM',
    },
  ],
};

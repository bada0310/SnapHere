import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/home/data/home_map_repository.dart';

final homeMapRepositoryProvider = Provider<HomeMapRepository>(
  (ref) => HomeMapRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  ),
);
final homeLocationProvider = Provider<HomeLocationService>(
  (ref) => HomeLocationService(),
);

class HomeLocationService {
  Future<LatLng> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException('기기의 위치 서비스를 켜 주세요.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiException('위치 권한이 필요해요. 지역 목록에서 직접 선택할 수도 있어요.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}

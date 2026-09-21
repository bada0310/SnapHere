import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/features/upload/domain/local_tier_calculator.dart';
import 'package:snap_here/src/features/upload/domain/upload_models.dart';

void main() {
  const place = UploadPlace(
    id: 'plc_1',
    name: '테스트 장소',
    address: '',
    latitude: 37.5665,
    longitude: 126.9780,
  );
  final now = DateTime(2026, 9, 21, 12);

  UploadPhoto photo({
    UploadPhotoSource source = UploadPhotoSource.deviceLibrary,
    double? latitude = 37.5665,
    double? longitude = 126.9780,
    DateTime? takenAt,
  }) => UploadPhoto(
    id: 'photo',
    source: source,
    latitude: latitude,
    longitude: longitude,
    takenAt: takenAt ?? now.subtract(const Duration(days: 1)),
  );

  test('camera photo at the selected place within ten minutes is HIGH', () {
    final result = calculateLocalTier(
      photo(
        source: UploadPhotoSource.camera,
        takenAt: now.subtract(const Duration(minutes: 10)),
      ),
      place,
      now: now,
    );
    expect(result.tier, 'HIGH');
    expect(result.withinRadius, isTrue);
  });

  test('photo outside 200m or without metadata is LOW', () {
    expect(
      calculateLocalTier(
        photo(latitude: 37.5700, longitude: 126.9780),
        place,
        now: now,
      ).tier,
      'LOW',
    );
    expect(
      calculateLocalTier(photo(latitude: null, longitude: null), place, now: now).tier,
      'LOW',
    );
  });

  test('recent album is MEDIUM and an old photo is LOW', () {
    expect(calculateLocalTier(photo(), place, now: now).tier, 'MEDIUM');
    expect(
      calculateLocalTier(
        photo(takenAt: now.subtract(const Duration(days: 31))),
        place,
        now: now,
      ).tier,
      'LOW',
    );
  });
}

import 'dart:math' as math;

import 'package:snap_here/src/features/upload/domain/upload_models.dart';

/// 게시글 인증을 위해 기기에서만 사진 위치와 선택 장소를 비교한다.
/// 원 좌표와 촬영 시각은 반환하거나 서버에 전달하지 않는다.
LocalTierResult calculateLocalTier(
  UploadPhoto photo,
  UploadPlace place, {
  DateTime? now,
}) {
  const radiusM = 200.0;
  if (!photo.hasLocationMetadata || !place.hasCoordinate) {
    return const LocalTierResult(tier: 'LOW', withinRadius: false);
  }

  final distance = _metersBetween(
    photo.latitude!,
    photo.longitude!,
    place.latitude!,
    place.longitude!,
  );
  if (distance > radiusM || photo.takenAt == null) {
    return const LocalTierResult(tier: 'LOW', withinRadius: false);
  }

  final elapsed = (now ?? DateTime.now()).difference(photo.takenAt!);
  final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
  if (photo.source == UploadPhotoSource.camera &&
      safeElapsed <= const Duration(minutes: 10)) {
    return const LocalTierResult(tier: 'HIGH', withinRadius: true);
  }
  if (safeElapsed <= const Duration(days: 30)) {
    return const LocalTierResult(tier: 'MEDIUM', withinRadius: true);
  }
  return const LocalTierResult(tier: 'LOW', withinRadius: true);
}

double _metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusM = 6371000.0;
  final latitudeDelta = _radians(lat2 - lat1);
  final longitudeDelta = _radians(lng2 - lng1);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;

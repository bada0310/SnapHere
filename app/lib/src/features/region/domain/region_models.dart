import 'package:flutter/foundation.dart';

/// 17개 시도 마스터 (API-PLC-001).
@immutable
class Region {
  const Region({
    required this.areaCode,
    required this.name,
    this.imageUrl,
    this.defaultEventVerifyRadiusM,
  });

  factory Region.fromJson(Map<String, Object?> json) => Region(
    areaCode: (json['areaCode'] as num?)?.toInt() ?? 0,
    name: json['nameKo'] as String? ?? json['name'] as String? ?? '지역',
    imageUrl: json['imageUrl'] as String?,
    defaultEventVerifyRadiusM: (json['defaultEventVerifyRadiusM'] as num?)
        ?.toInt(),
  );

  final int areaCode;
  final String name;
  final String? imageUrl;
  final int? defaultEventVerifyRadiusM;
}

/// 시도에 속한 시군구 (API-PLC-002).
@immutable
class Sigungu {
  const Sigungu({
    required this.areaCode,
    required this.sigunguCode,
    required this.name,
  });

  factory Sigungu.fromJson(Map<String, Object?> json) => Sigungu(
    areaCode: (json['areaCode'] as num?)?.toInt() ?? 0,
    sigunguCode: (json['sigunguCode'] as num?)?.toInt() ?? 0,
    name: json['nameKo'] as String? ?? json['name'] as String? ?? '',
  );

  final int areaCode;
  final int sigunguCode;
  final String name;
}

class RegionFailure implements Exception {
  const RegionFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

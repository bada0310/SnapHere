import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:snap_here/src/core/network/api_client.dart';
import 'package:snap_here/src/features/event/domain/event_models.dart';
import 'package:snap_here/src/features/event/domain/event_repository.dart';

class ApiEventRepository implements EventRepository {
  ApiEventRepository({
    this.accessToken,
    http.Client? client,
    String baseUrl = defaultApiBaseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final String? accessToken;
  final http.Client _client;
  final String _baseUrl;

  String get _root =>
      _baseUrl.endsWith('/api') ? '$_baseUrl/v1' : '$_baseUrl/api/v1';

  @override
  Future<List<EventRegionSummary>> fetchRegionSummary() async {
    final data = await _get('/events/region-summary');
    return _list(data).map(EventRegionSummary.fromJson).toList(growable: false);
  }

  @override
  Future<List<EventSummary>> fetchEvents({int? areaCode}) async {
    final data = await _get(
      '/events',
      query: {if (areaCode != null) 'areaCode': '$areaCode', 'size': '50'},
    );
    final page = Map<String, Object?>.from(data as Map);
    return _list(page['items'])
        .map(EventSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<EventDetail> fetchEvent(String eventId) async => EventDetail.fromJson(
    Map<String, Object?>.from(await _get('/events/$eventId') as Map),
  );

  @override
  Future<List<EventPost>> fetchEventPosts(String eventId) async {
    final page = Map<String, Object?>.from(
      await _get('/events/$eventId/posts') as Map,
    );
    return _list(page['items']).map(EventPost.fromJson).toList(growable: false);
  }

  @override
  Future<EventUploadContext> fetchUploadContext(String eventId) async =>
      EventUploadContext.fromJson(
        Map<String, Object?>.from(
          await _get('/events/$eventId/upload-context', authenticated: true)
              as Map,
        ),
      );

  @override
  Future<List<EventSummary>> fetchNearbyEvents({
    required double lat,
    required double lng,
    int? radiusM,
  }) async {
    final data = await _get(
      '/events/nearby',
      query: {
        'lat': '$lat',
        'lng': '$lng',
        if (radiusM != null) 'radiusM': '$radiusM',
      },
    );
    return _list(data).map(EventSummary.fromJson).toList(growable: false);
  }

  Future<Object?> _get(
    String path, {
    Map<String, String> query = const {},
    bool authenticated = false,
  }) async {
    if (_baseUrl.isEmpty) {
      throw const EventFailure('API_BASE_URL이 설정되지 않았습니다.');
    }
    if (authenticated && accessToken == null) {
      throw const EventFailure('로그인이 필요한 기능입니다.');
    }
    final response = await _client
        .get(
          Uri.parse('$_root$path').replace(queryParameters: query),
          headers: {
            'accept': 'application/json',
            'accept-language': 'ko-KR',
            if (accessToken != null) 'authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 15));
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const EventFailure('서버 응답 형식이 올바르지 않습니다.');
    }
    final envelope = Map<String, Object?>.from(decoded! as Map);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = envelope['error'];
      final errorMap = error is Map
          ? Map<String, Object?>.from(error)
          : const <String, Object?>{};
      throw EventFailure(
        errorMap['message'] as String? ??
            errorMap['messageKey'] as String? ??
            '이벤트 정보를 불러오지 못했습니다. (${response.statusCode})',
      );
    }
    return envelope.containsKey('data') ? envelope['data'] : envelope;
  }

  List<Map<String, Object?>> _list(Object? value) => (value! as List)
      .map((item) => Map<String, Object?>.from(item as Map))
      .toList(growable: false);
}

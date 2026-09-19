import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/core/network/api_client.dart';

void main() {
  test('production server is the default API base URL', () {
    expect(defaultApiBaseUrl, 'https://snaphere.duckdns.org');
  });
}

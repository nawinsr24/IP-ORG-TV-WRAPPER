@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tamil_tv/models.dart';

/// Hits the real iptv-org API. Run with: flutter test --tags live
void main() {
  test('real iptv-org data yields many Tamil channels', () async {
    Future<String> get(String f) async => (await http.get(Uri.parse('${Catalog.base}$f'))).body;
    final raw = await Future.wait(
        ['channels.json', 'feeds.json', 'streams.json', 'logos.json', 'blocklist.json'].map(get));
    final list = Catalog.build(raw);
    // ignore: avoid_print
    print('Tamil channels: ${list.length}; Star Vijay = ${list.firstWhere((c) => c.name == 'Star Vijay').number}');
    expect(list.length, greaterThan(100));
  });
}

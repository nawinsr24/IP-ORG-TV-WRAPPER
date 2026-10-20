import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tamil_tv/models.dart';

void main() {
  test('builds, filters and numbers Tamil channels', () {
    final channels = [
      {'id': 'SunTV.in', 'name': 'Sun TV', 'categories': ['entertainment'], 'closed': null, 'is_nsfw': false},
      {'id': 'PolimerNews.in', 'name': 'Polimer News', 'categories': ['news'], 'closed': null, 'is_nsfw': false},
      {'id': 'Old.in', 'name': 'Closed', 'categories': ['news'], 'closed': '2020-01-01', 'is_nsfw': false},
      {'id': 'Adult.in', 'name': 'Adult', 'categories': ['xxx'], 'closed': null, 'is_nsfw': true},
      {'id': 'Blocked.in', 'name': 'Blocked', 'categories': ['news'], 'closed': null, 'is_nsfw': false},
      {'id': 'Hindi.in', 'name': 'Hindi', 'categories': ['news'], 'closed': null, 'is_nsfw': false},
      {'id': 'NoStream.in', 'name': 'NoStream', 'categories': ['news'], 'closed': null, 'is_nsfw': false},
    ];
    final feeds = [
      for (final id in ['SunTV.in', 'PolimerNews.in', 'Old.in', 'Adult.in', 'Blocked.in', 'NoStream.in'])
        {'channel': id, 'languages': ['tam']},
      {'channel': 'Hindi.in', 'languages': ['hin']},
    ];
    final streams = [
      {'channel': 'SunTV.in', 'url': 'http://a/low.m3u8', 'quality': '360p', 'referrer': 'http://r', 'user_agent': null},
      {'channel': 'SunTV.in', 'url': 'http://a/high.m3u8', 'quality': '1080p'},
      {'channel': 'PolimerNews.in', 'url': 'http://b/p.m3u8'},
      {'channel': 'Old.in', 'url': 'http://c'},
      {'channel': 'Adult.in', 'url': 'http://d'},
      {'channel': 'Blocked.in', 'url': 'http://e'},
      {'channel': 'Hindi.in', 'url': 'http://f'},
    ];
    final result = Catalog.build([
      jsonEncode(channels),
      jsonEncode(feeds),
      jsonEncode(streams),
      jsonEncode([{'channel': 'SunTV.in', 'url': 'http://logo.png'}]),
      jsonEncode([{'channel': 'Blocked.in', 'reason': 'dmca'}]),
    ]);

    // Entertainment sorts before news; closed/nsfw/blocked/non-Tamil/no-stream are dropped.
    expect(result.map((c) => c.name), ['Sun TV', 'Polimer News']);
    expect(result.map((c) => c.number), [1, 2]);
    expect(result.first.streams.first.url, 'http://a/high.m3u8'); // best quality first
    expect(result.first.logo, 'http://logo.png');
    expect(result.first.streams.last.headers, {'Referer': 'http://r'});
  });

  test('channel survives JSON cache round trip', () {
    final c = Channel('x', 'X', 'news', null, [const StreamInfo('http://s', userAgent: 'UA')]);
    final back = Channel.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.streams.first.headers, {'User-Agent': 'UA'});
    expect(back.name, 'X');
  });
}

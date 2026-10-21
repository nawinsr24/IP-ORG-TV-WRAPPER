import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StreamInfo {
  final String url;
  final String? referrer;
  final String? userAgent;
  final String? quality;
  const StreamInfo(this.url, {this.referrer, this.userAgent, this.quality});

  Map<String, String> get headers => {
    'Referer': ?referrer,
    'User-Agent': ?userAgent,
  };

  Map<String, dynamic> toJson() => {
    'url': url,
    'referrer': referrer,
    'userAgent': userAgent,
    'quality': quality,
  };
  factory StreamInfo.fromJson(Map<String, dynamic> j) => StreamInfo(
    j['url'] as String,
    referrer: j['referrer'] as String?,
    userAgent: j['userAgent'] as String?,
    quality: j['quality'] as String?,
  );
}

class Channel {
  final String id;
  final String name;
  final String category;
  final String? logo;
  final List<StreamInfo> streams;
  int number;
  Channel(
    this.id,
    this.name,
    this.category,
    this.logo,
    this.streams, [
    this.number = 0,
  ]);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'logo': logo,
    'streams': streams.map((s) => s.toJson()).toList(),
  };
  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
    j['id'] as String,
    j['name'] as String,
    j['category'] as String,
    j['logo'] as String?,
    (j['streams'] as List)
        .map((s) => StreamInfo.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

/// Loads Tamil channels from the public iptv-org API (https://github.com/iptv-org/api).
class Catalog {
  static const base = 'https://iptv-org.github.io/api/';
  static const _cacheKey = 'catalog_v1';
  static const _order = [
    'general',
    'entertainment',
    'news',
    'movies',
    'music',
    'kids',
    'religious',
  ];

  static Future<List<Channel>?> loadCached() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (raw == null) return null;
      return _number(
        (jsonDecode(raw) as List)
            .map((e) => Channel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Channel>> fetch() async {
    Future<String> get(String f) async {
      final r = await http
          .get(Uri.parse('$base$f'))
          .timeout(const Duration(seconds: 40));
      if (r.statusCode != 200) throw Exception('$f: HTTP ${r.statusCode}');
      return utf8.decode(r.bodyBytes);
    }

    final raw = await Future.wait([
      get('channels.json'),
      get('feeds.json'),
      get('streams.json'),
      get('logos.json'),
      get('blocklist.json'),
    ]);
    final channels = await Isolate.run(() => build(raw));
    try {
      (await SharedPreferences.getInstance()).setString(
        _cacheKey,
        jsonEncode(channels.map((c) => c.toJson()).toList()),
      );
    } catch (_) {}
    return channels;
  }

  static int _q(String? s) =>
      int.tryParse((s ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @visibleForTesting
  static List<Channel> build(List<String> raw) {
    final chs = jsonDecode(raw[0]) as List;
    final feeds = jsonDecode(raw[1]) as List;
    final streams = jsonDecode(raw[2]) as List;
    final logos = jsonDecode(raw[3]) as List;
    final block = jsonDecode(raw[4]) as List;

    final tamil = <String>{
      for (final f in feeds)
        if (((f['languages'] as List?) ?? const []).contains('tam'))
          f['channel'] as String,
    };
    final blocked = {for (final b in block) b['channel'] as String};
    final byChannel = <String, List<StreamInfo>>{};
    for (final s in streams) {
      final ch = s['channel'] as String?;
      if (ch == null || !tamil.contains(ch)) continue;
      byChannel
          .putIfAbsent(ch, () => [])
          .add(
            StreamInfo(
              s['url'] as String,
              referrer: s['referrer'] as String?,
              userAgent: s['user_agent'] as String?,
              quality: s['quality'] as String?,
            ),
          );
    }
    final logoFor = <String, String>{};
    for (final l in logos) {
      logoFor.putIfAbsent(l['channel'] as String, () => l['url'] as String);
    }
    final out = <Channel>[];
    for (final c in chs) {
      final id = c['id'] as String;
      final st = byChannel[id];
      if (st == null || st.isEmpty) continue;
      if (c['closed'] != null || c['is_nsfw'] == true || blocked.contains(id))
        continue;
      st.sort((a, b) => _q(b.quality).compareTo(_q(a.quality)));
      final cats = (c['categories'] as List?) ?? const [];
      out.add(
        Channel(
          id,
          c['name'] as String,
          cats.isEmpty ? 'general' : cats.first as String,
          logoFor[id],
          st,
        ),
      );
    }
    return _number(out);
  }

  static List<Channel> _number(List<Channel> list) {
    int rank(Channel c) {
      final i = _order.indexOf(c.category);
      return i < 0 ? _order.length : i;
    }

    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    for (var i = 0; i < list.length; i++) {
      list[i].number = i + 1;
    }
    return list;
  }
}

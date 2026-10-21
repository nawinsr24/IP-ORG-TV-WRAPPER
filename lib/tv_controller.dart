import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class TvController extends ChangeNotifier {
  final Player player = Player();
  late final VideoController video = VideoController(player);

  List<Channel> all = [];
  String category = 'all';
  Channel? current;
  String status = 'Loading channels…';
  bool bannerVisible = false;
  String numberEntry = '';
  bool muted = false;
  bool playing = true;
  double volume = 80; // 0..100
  String? toast;
  Set<String> favorites = {};
  Duration? sleepIn; // chosen sleep timer length
  Timer? _sleepTimer;

  SharedPreferences? _prefs;
  int _streamIndex = 0;
  int _token =
      0; // identifies the stream attempt currently allowed to report results
  int _direction = 1;
  int _skipsInRow = 0;
  Timer? _bannerTimer, _numberTimer, _timeout, _toastTimer;
  final List<StreamSubscription> _subs = [];

  List<String> get categories => [
    'all',
    if (favorites.isNotEmpty) 'favorites',
    ...({...all.map((c) => c.category)}.toList()..sort()),
  ];

  List<Channel> get channels {
    switch (category) {
      case 'all':
        return all;
      case 'favorites':
        return all.where((c) => favorites.contains(c.id)).toList();
      default:
        return all.where((c) => c.category == category).toList();
    }
  }

  bool get isFavorite => current != null && favorites.contains(current!.id);

  bool loadFailed = false;
  bool _listening = false;

  Future<void> start() async {
    loadFailed = false;
    status = 'Loading channels…';
    notifyListeners();

    // Player wiring is fire-and-forget so a slow native player can never block channel loading.
    _attachPlayer();

    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 8),
      );
      favorites = (_prefs!.getStringList('favorites') ?? []).toSet();
      volume = _prefs!.getDouble('volume') ?? 80;
    } catch (_) {
      // Settings are optional; carry on with defaults.
    }

    final cached = await Catalog.loadCached().timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
    if (cached != null && cached.isNotEmpty) _setChannels(cached);
    try {
      status = all.isEmpty ? 'Downloading channel list…' : '';
      notifyListeners();
      _setChannels(await Catalog.fetch());
    } catch (e) {
      if (all.isEmpty) {
        loadFailed = true;
        status = 'Could not load channels.\n$e';
        notifyListeners();
      }
    }
  }

  Future<void> retry() => start();

  void _attachPlayer() {
    if (_listening) return;
    _listening = true;
    player
        .setVolume(volume)
        .timeout(const Duration(seconds: 5))
        .catchError((_) {});
    _subs.add(
      player.stream.playing.listen((p) {
        playing = p;
        notifyListeners();
      }),
    );
    _subs.add(
      player.stream.error.listen((e) {
        if (e.isNotEmpty) _failStream(_token);
      }),
    );
    // A stream counts as working once it reports a video size or starts advancing.
    _subs.add(
      player.stream.width.listen((w) {
        if ((w ?? 0) > 0) _markWorking(_token);
      }),
    );
    _subs.add(
      player.stream.position.listen((p) {
        if (p > const Duration(milliseconds: 400)) _markWorking(_token);
      }),
    );
  }

  void _setChannels(List<Channel> list) {
    final first = all.isEmpty;
    all = list;
    if (!first) {
      notifyListeners();
      return;
    }
    final last = _prefs?.getString('lastChannel');
    tune(list.firstWhere((c) => c.id == last, orElse: () => list.first), 1);
  }

  // ---- switching ----
  void next() => _step(1);
  void previous() => _step(-1);

  void _step(int d) {
    final list = channels;
    if (list.isEmpty) return;
    final i = list.indexWhere((c) => c.id == current?.id);
    final from = i < 0 ? (d > 0 ? -1 : 0) : i;
    tune(list[((from + d) % list.length + list.length) % list.length], d);
  }

  void cycleCategory() {
    final cats = categories;
    category = cats[(cats.indexOf(category) + 1) % cats.length];
    final c = channels;
    if (c.isNotEmpty) tune(c.first, 1);
    showBanner();
  }

  void typeDigit(String d) {
    numberEntry = (numberEntry + d);
    if (numberEntry.length > 3)
      numberEntry = numberEntry.substring(numberEntry.length - 3);
    _numberTimer?.cancel();
    _numberTimer = Timer(const Duration(milliseconds: 1500), commitNumber);
    notifyListeners();
  }

  void commitNumber() {
    _numberTimer?.cancel();
    final n = int.tryParse(numberEntry);
    numberEntry = '';
    if (n != null) {
      final match = all.where((c) => c.number == n);
      if (match.isNotEmpty) {
        if (category != 'all' &&
            match.first.category != category &&
            category != 'favorites') {
          category = 'all';
        }
        tune(match.first, 1);
        return;
      }
      _toast('No channel $n');
    }
    notifyListeners();
  }

  void toggleFavorite() => toggleFavoriteFor(current);

  void toggleFavoriteFor(Channel? c) {
    if (c == null) return;
    if (favorites.contains(c.id)) {
      favorites.remove(c.id);
    } else {
      favorites.add(c.id);
    }
    _prefs?.setStringList('favorites', favorites.toList());
    if (favorites.isEmpty && category == 'favorites') category = 'all';
    _toast(
      favorites.contains(c.id)
          ? '★ Added to favorites'
          : 'Removed from favorites',
    );
    if (c.id == current?.id) showBanner();
    notifyListeners();
  }

  void stepFavorite(int d) {
    final favs = all.where((c) => favorites.contains(c.id)).toList();
    if (favs.isEmpty) {
      _toast('No favorites yet — press S on a channel to add it');
      return;
    }
    final n = current?.number ?? 0;
    Channel target;
    if (d > 0) {
      target = favs.firstWhere((c) => c.number > n, orElse: () => favs.first);
    } else {
      target = favs.lastWhere((c) => c.number < n, orElse: () => favs.last);
    }
    if (category != 'favorites') category = 'all';
    tune(target, d);
  }

  void say(String msg) => _toast(msg);

  void togglePlay() => player.playOrPause();

  void toggleOverlay() {
    if (bannerVisible) {
      _bannerTimer?.cancel();
      bannerVisible = false;
      notifyListeners();
    } else {
      showBanner();
    }
  }

  void setCategory(String c) {
    category = c;
    notifyListeners();
  }

  void setVolumeTo(double v) {
    volume = v.clamp(0, 100);
    muted = false;
    player.setVolume(volume);
    _prefs?.setDouble('volume', volume);
    notifyListeners();
  }

  // ---- volume ----
  void changeVolume(double delta) {
    volume = (volume + delta).clamp(0, 100);
    muted = false;
    player.setVolume(volume);
    _prefs?.setDouble('volume', volume);
    _toast('Volume ${volume.round()}%');
  }

  void toggleMute() {
    muted = !muted;
    player.setVolume(muted ? 0 : volume);
    _toast(muted ? 'Muted' : 'Volume ${volume.round()}%');
  }

  // ---- sleep timer ----
  static const _sleepSteps = [null, 15, 30, 60, 90];
  int _sleepIdx = 0;
  void cycleSleepTimer() {
    _sleepIdx = (_sleepIdx + 1) % _sleepSteps.length;
    _sleepTimer?.cancel();
    final m = _sleepSteps[_sleepIdx];
    if (m == null) {
      sleepIn = null;
      _toast('Sleep timer off');
    } else {
      sleepIn = Duration(minutes: m);
      _sleepTimer = Timer(sleepIn!, () {
        player.pause();
        sleepIn = null;
        _sleepIdx = 0;
        _toast('Sleep timer: paused');
      });
      _toast('Sleep timer: $m min');
    }
  }

  // ---- playback ----
  void tune(Channel? channel, int direction, {bool resetSkips = true}) {
    if (channel == null) return;
    _direction = direction;
    if (resetSkips) _skipsInRow = 0;
    current = channel;
    _prefs?.setString('lastChannel', channel.id);
    _streamIndex = 0;
    status = '';
    showBanner();
    _playStream();
  }

  void _playStream() {
    final ch = current;
    if (ch == null) return;
    if (_streamIndex >= ch.streams.length) return _failChannel();
    final s = ch.streams[_streamIndex];
    final token = ++_token;
    player.open(Media(s.url, httpHeaders: s.headers), play: true);
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 12), () => _failStream(token));
    notifyListeners();
  }

  void _markWorking(int token) {
    if (token != _token) return;
    _timeout?.cancel();
    _skipsInRow = 0;
    if (status.isNotEmpty) {
      status = '';
      notifyListeners();
    }
  }

  void _failStream(int token) {
    if (token != _token) return; // stale event from an earlier channel
    _timeout?.cancel();
    _streamIndex++;
    _playStream();
  }

  void _failChannel() {
    final ch = current;
    if (ch == null) return;
    status = '${ch.name} is not available — skipping';
    _skipsInRow++;
    notifyListeners();
    final list = channels;
    if (_skipsInRow >= list.length) {
      status = 'No working channels found';
      notifyListeners();
      return;
    }
    final d = _direction;
    Timer(const Duration(milliseconds: 600), () {
      if (current?.id != ch.id) return;
      final i = list.indexWhere((c) => c.id == ch.id);
      tune(
        list[(((i < 0 ? 0 : i) + d) % list.length + list.length) % list.length],
        d,
        resetSkips: false,
      );
    });
  }

  void showBanner() {
    bannerVisible = true;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 4500), () {
      bannerVisible = false;
      notifyListeners();
    });
    notifyListeners();
  }

  void _toast(String msg) {
    toast = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      toast = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _bannerTimer?.cancel();
    _numberTimer?.cancel();
    _timeout?.cancel();
    _toastTimer?.cancel();
    _sleepTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}

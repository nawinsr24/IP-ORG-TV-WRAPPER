import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'tv_controller.dart';

bool get isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
        const WindowOptions(size: Size(1100, 640), minimumSize: Size(640, 360), title: 'Tamil TV'),
        () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } else {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const TamilTvApp());
}

class TamilTvApp extends StatelessWidget {
  const TamilTvApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tamil TV',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const TvScreen(),
      );
}

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});
  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  final tv = TvController();
  final _focus = FocusNode();
  bool _agreed = false;
  bool _listOpen = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimer());
  }

  Future<void> _showDisclaimer() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DisclaimerDialog(),
    );
    if (ok == true) {
      setState(() => _agreed = true);
      _focus.requestFocus();
      tv.start();
    } else {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    }
  }

  Future<void> _toggleFullscreen() async {
    if (!isDesktop) return;
    _fullscreen = !_fullscreen;
    await windowManager.setFullScreen(_fullscreen);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!_agreed || e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      if (_listOpen) {
        setState(() => _listOpen = false);
        _focus.requestFocus();
      } else if (_fullscreen) {
        _toggleFullscreen();
      }
      return KeyEventResult.handled;
    }
    if (_listOpen) return KeyEventResult.ignored; // let the search box have the keys
    if (k == LogicalKeyboardKey.arrowRight) {
      tv.next();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      tv.previous();
    } else if (k == LogicalKeyboardKey.arrowUp) {
      tv.changeVolume(5);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      tv.changeVolume(-5);
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.select) {
      tv.numberEntry.isNotEmpty ? tv.commitNumber() : tv.showBanner();
    } else if (k == LogicalKeyboardKey.space) {
      tv.toggleMute();
    } else if (k == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (k == LogicalKeyboardKey.keyC) {
      tv.cycleCategory();
    } else if (k == LogicalKeyboardKey.keyS) {
      tv.toggleFavorite();
    } else if (k == LogicalKeyboardKey.bracketRight) {
      tv.stepFavorite(1);
    } else if (k == LogicalKeyboardKey.bracketLeft) {
      tv.stepFavorite(-1);
    } else if (k == LogicalKeyboardKey.keyI) {
      tv.showBanner();
    } else if (k == LogicalKeyboardKey.keyT) {
      tv.cycleSleepTimer();
    } else if (k == LogicalKeyboardKey.keyL || k == LogicalKeyboardKey.contextMenu) {
      setState(() => _listOpen = true);
    } else if (e.character != null && RegExp(r'^[0-9]$').hasMatch(e.character!)) {
      tv.typeDigit(e.character!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    tv.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: tv,
          builder: (context, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tv.showBanner,
            onDoubleTap: _toggleFullscreen,
            onVerticalDragUpdate: isDesktop
                ? null
                : (d) => tv.changeVolume(-d.delta.dy / 4),
            onHorizontalDragEnd: isDesktop
                ? null
                : (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -300) tv.next();
                    if (v > 300) tv.previous();
                  },
            child: Stack(fit: StackFit.expand, children: [
              Video(controller: tv.video, controls: NoVideoControls, fill: Colors.black),
              if (_agreed && tv.all.isEmpty)
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (!tv.loadFailed) const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    _Pill(tv.status.isEmpty ? 'Loading channels…' : tv.status, big: true),
                    if (tv.loadFailed) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: tv.retry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                    ],
                  ]),
                )
              else if (tv.status.isNotEmpty)
                Center(child: _Pill(tv.status, big: true)),
              if (tv.numberEntry.isNotEmpty)
                Positioned(
                  top: 24,
                  right: 32,
                  child: Text(tv.numberEntry,
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow,
                          fontFamily: 'monospace',
                          shadows: [Shadow(blurRadius: 6)])),
                ),
              if (tv.toast != null) Positioned(top: 24, left: 0, right: 0, child: Center(child: _Pill(tv.toast!))),
              if (tv.sleepIn != null)
                Positioned(top: 24, left: 24, child: _Pill('😴 ${tv.sleepIn!.inMinutes} min')),
              if (tv.bannerVisible && tv.current != null)
                Positioned(left: 0, right: 0, bottom: 0, child: _Banner(tv: tv, onList: () => setState(() => _listOpen = true))),
              if (!isDesktop && !tv.bannerVisible && tv.all.isNotEmpty)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: IconButton.filledTonal(onPressed: tv.showBanner, icon: const Icon(Icons.tv)),
                ),
              if (_listOpen)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 340,
                  child: ChannelList(
                    tv: tv,
                    onClose: () {
                      setState(() => _listOpen = false);
                      _focus.requestFocus();
                    },
                  ),
                ),
              if (!_agreed) const ColoredBox(color: Colors.black),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool big;
  const _Pill(this.text, {this.big = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: big ? 20 : 16, color: Colors.white)),
      );
}

class _Banner extends StatelessWidget {
  final TvController tv;
  final VoidCallback onList;
  const _Banner({required this.tv, required this.onList});
  @override
  Widget build(BuildContext context) {
    final c = tv.current!;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text('${c.number}',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.yellow, fontFamily: 'monospace')),
        const SizedBox(width: 14),
        if (c.logo != null)
          SizedBox(width: 56, height: 40, child: Image.network(c.logo!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox())),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${tv.isFavorite ? '★ ' : ''}${c.name}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('${c.category}  ·  filter: ${tv.category}  ·  vol ${tv.muted ? 'muted' : '${tv.volume.round()}%'}',
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            if (isDesktop)
              const Text('←→ channel  ↑↓ volume  [ ] favorites  S star  L list  0-9 jump  C category  T sleep  F full',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
        IconButton(tooltip: 'Previous', onPressed: tv.previous, icon: const Icon(Icons.skip_previous)),
        IconButton(tooltip: 'Next', onPressed: tv.next, icon: const Icon(Icons.skip_next)),
        IconButton(
            tooltip: 'Favorite',
            onPressed: tv.toggleFavorite,
            icon: Icon(tv.isFavorite ? Icons.star : Icons.star_border, color: Colors.amber)),
        IconButton(tooltip: 'Channel list', onPressed: onList, icon: const Icon(Icons.list)),
        IconButton(tooltip: 'Mute', onPressed: tv.toggleMute, icon: Icon(tv.muted ? Icons.volume_off : Icons.volume_up)),
      ]),
    );
  }
}

class ChannelList extends StatefulWidget {
  final TvController tv;
  final VoidCallback onClose;
  const ChannelList({super.key, required this.tv, required this.onClose});
  @override
  State<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<ChannelList> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final tv = widget.tv;
    final list = tv.all.where((c) {
      if (q.isEmpty) return true;
      final s = q.toLowerCase();
      return c.name.toLowerCase().contains(s) || '${c.number}' == s || c.category.contains(s);
    }).toList();
    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search channels…', prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) => setState(() => q = v),
              ),
            ),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              final fav = tv.favorites.contains(c.id);
              return ListTile(
                dense: true,
                selected: c.id == tv.current?.id,
                leading: Text('${c.number}', style: const TextStyle(fontSize: 18, color: Colors.yellow, fontFamily: 'monospace')),
                title: Text('${fav ? '★ ' : ''}${c.name}'),
                subtitle: Text(c.category),
                onTap: () {
                  tv.tune(c, 1);
                  widget.onClose();
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class DisclaimerDialog extends StatelessWidget {
  const DisclaimerDialog({super.key});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Before you watch'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const SingleChildScrollView(
            child: Text(
              'Tamil TV is a simple wrapper app made for educational purposes only. '
              'It is free, has no ads, and is not monetised in any way.\n\n'
              'This app does not host, own, or upload any video content. It only plays public '
              'streams listed by the open-source iptv-org project (github.com/iptv-org/iptv). '
              'All channels, streams and trademarks belong to their respective owners.\n\n'
              'Any legal issue about a channel or its content relates to the original stream '
              'source and the iptv-org repository, not to this app. If you are the owner of a '
              'channel and want it removed, please contact iptv-org.\n\n'
              'By tapping "I Agree" you confirm that you understand this and will use the app '
              'responsibly and lawfully in your country.',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Quit')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('I Agree')),
        ],
      ),
    );
  }
}

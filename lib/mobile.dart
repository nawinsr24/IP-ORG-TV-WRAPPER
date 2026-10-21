import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'models.dart';
import 'tv_controller.dart';

/// Shown while the channel list loads (or fails to load).
class LoadingView extends StatelessWidget {
  final TvController tv;
  const LoadingView(this.tv, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!tv.loadFailed) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            tv.status.isEmpty ? 'Loading channels…' : tv.status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          if (tv.loadFailed) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: tv.retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Phone / tablet layout: portrait = video + button bar + channel list,
/// landscape = full-screen video with tap-to-show controls and a channel drawer.
class MobileLayout extends StatefulWidget {
  final TvController tv;
  const MobileLayout({super.key, required this.tv});
  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  Orientation? _applied;

  TvController get tv => widget.tv;

  void _applyChrome(Orientation o) {
    if (_applied == o) return;
    _applied = o;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SystemChrome.setEnabledSystemUIMode(
        o == Orientation.landscape
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      ),
    );
  }

  /// Force the other orientation, then hand control back to the sensor.
  Future<void> _rotate(Orientation now) async {
    await SystemChrome.setPreferredOrientations(
      now == Orientation.portrait
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
    await Future.delayed(const Duration(seconds: 2));
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Widget _video() => Video(
    controller: tv.video,
    controls: NoVideoControls,
    fill: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, o) {
        _applyChrome(o);
        if (tv.all.isEmpty)
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(child: LoadingView(tv)),
          );
        return o == Orientation.landscape ? _landscape(o) : _portrait(o);
      },
    );
  }

  Widget _landscape(Orientation o) {
    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: Drawer(
        width: 340,
        child: SafeArea(
          child: ChannelPanel(
            tv: tv,
            onPicked: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tv.toggleOverlay,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -300) tv.next();
            if (v > 300) tv.previous();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _video(),
              if (tv.status.isNotEmpty) Center(child: _Pill(tv.status)),
              if (tv.toast != null)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(child: _Pill(tv.toast!)),
                ),
              if (tv.numberEntry.isNotEmpty)
                Positioned(
                  top: 16,
                  right: 24,
                  child: Text(
                    tv.numberEntry,
                    style: const TextStyle(fontSize: 48, color: Colors.yellow),
                  ),
                ),
              AnimatedOpacity(
                opacity: tv.bannerVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !tv.bannerVisible,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xCC000000),
                          Color(0x00000000),
                          Color(0xCC000000),
                        ],
                        stops: [0, 0.5, 1],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          _TitleRow(tv: tv),
                          const Spacer(),
                          ControlBar(
                            tv: tv,
                            onRotate: () => _rotate(o),
                            onList: () => Scaffold.of(context).openEndDrawer(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portrait(Orientation o) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: tv.toggleOverlay,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _video(),
                    if (tv.status.isNotEmpty) Center(child: _Pill(tv.status)),
                    if (tv.toast != null)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(child: _Pill(tv.toast!)),
                      ),
                    if (tv.bannerVisible)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          child: _TitleRow(tv: tv),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              color: const Color(0xFF181B24),
              child: ControlBar(tv: tv, onRotate: () => _rotate(o)),
            ),
            Expanded(child: ChannelPanel(tv: tv)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
    ),
  );
}

class _TitleRow extends StatelessWidget {
  final TvController tv;
  const _TitleRow({required this.tv});
  @override
  Widget build(BuildContext context) {
    final c = tv.current;
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(
            '${c.number}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.yellow,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(c.category, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

/// Previous / play-pause / next, favourite, volume, rotate and (landscape) channel list.
class ControlBar extends StatelessWidget {
  final TvController tv;
  final VoidCallback onRotate;
  final VoidCallback? onList;
  const ControlBar({
    super.key,
    required this.tv,
    required this.onRotate,
    this.onList,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous channel',
            iconSize: 34,
            onPressed: tv.previous,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton.filled(
            tooltip: tv.playing ? 'Pause' : 'Play',
            iconSize: 34,
            onPressed: tv.togglePlay,
            icon: Icon(
              tv.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Next channel',
            iconSize: 34,
            onPressed: tv.next,
            icon: const Icon(Icons.skip_next_rounded),
          ),
          IconButton(
            tooltip: 'Favorite',
            onPressed: tv.toggleFavorite,
            icon: Icon(
              tv.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber,
            ),
          ),
          IconButton(
            tooltip: 'Mute',
            onPressed: tv.toggleMute,
            icon: Icon(
              tv.muted || tv.volume == 0
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
            ),
          ),
          Expanded(
            child: Slider(
              value: tv.muted ? 0 : tv.volume,
              min: 0,
              max: 100,
              onChanged: tv.setVolumeTo,
            ),
          ),
          if (onList != null)
            IconButton(
              tooltip: 'Channels',
              onPressed: onList,
              icon: const Icon(Icons.format_list_bulleted_rounded),
            ),
          IconButton(
            tooltip: 'Rotate',
            onPressed: onRotate,
            icon: const Icon(Icons.screen_rotation_rounded),
          ),
        ],
      ),
    );
  }
}

/// Category chips + search + channel list.
class ChannelPanel extends StatefulWidget {
  final TvController tv;
  final VoidCallback? onPicked;
  const ChannelPanel({super.key, required this.tv, this.onPicked});
  @override
  State<ChannelPanel> createState() => _ChannelPanelState();
}

class _ChannelPanelState extends State<ChannelPanel> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final tv = widget.tv;
    final list = tv.channels.where((c) {
      if (q.isEmpty) return true;
      final s = q.toLowerCase();
      return c.name.toLowerCase().contains(s) || '${c.number}' == s;
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final c in tv.categories)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: ChoiceChip(
                    label: Text(
                      c == 'favorites'
                          ? '★ Favorites'
                          : '${c[0].toUpperCase()}${c.substring(1)}',
                    ),
                    selected: tv.category == c,
                    onSelected: (_) => tv.setCategory(c),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search name or number…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    'No channels here yet',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => _row(tv, list[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(TvController tv, Channel c) {
    final fav = tv.favorites.contains(c.id);
    return ListTile(
      dense: true,
      selected: c.id == tv.current?.id,
      leading: SizedBox(
        width: 36,
        child: Text(
          '${c.number}',
          style: const TextStyle(fontSize: 18, color: Colors.yellow),
        ),
      ),
      title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(c.category),
      trailing: IconButton(
        icon: Icon(
          fav ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.amber,
        ),
        onPressed: () => tv.toggleFavoriteFor(c),
      ),
      onTap: () {
        tv.tune(c, 1);
        widget.onPicked?.call();
      },
    );
  }
}

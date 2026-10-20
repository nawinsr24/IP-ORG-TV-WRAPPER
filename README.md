# Tamil TV

A simple TV-style player for Mac, Windows and Android that plays the public Tamil
channels listed by [iptv-org](https://github.com/iptv-org/iptv).

> **Educational project.** Free, no ads, not monetised. This app **does not host or own
> any content** — it only plays public streams published by the iptv-org project. Any legal
> concern about a channel or its content relates to the original stream source and the
> iptv-org repository. The app asks users to accept this notice every time it opens.

## Controls (Mac / Windows / keyboard / Android TV remote)

| Key | Action |
|---|---|
| ← / → | Previous / next channel |
| ↑ / ↓ | Volume up / down |
| 0–9 (+ Enter) | Jump to a channel number |
| S | Star / unstar a favourite |
| `[` / `]` | Previous / next favourite |
| C | Cycle category (all, favorites, news, movies, music, kids, religious…) |
| L | Channel list with search |
| Space | Mute |
| T | Sleep timer (15 / 30 / 60 / 90 min / off) |
| F | Full screen (desktop) |
| I | Show channel info |

**Android phone/tablet:** tap to show controls, swipe left/right to change channel,
swipe up/down for volume.

## Downloads

Every push builds all three apps with GitHub Actions. Open the **Actions** tab → latest run →
*Artifacts*, or tag a release (`git tag v1.0.0 && git push --tags`) to publish them on the
**Releases** page.

- **Android:** `TamilTV-android.apk` (allow "install unknown apps").
- **Windows:** unzip `TamilTV-windows.zip`, run `tamil_tv.exe`. If SmartScreen warns, choose *More info → Run anyway*.
- **Mac:** unzip `TamilTV-macos.zip`. The app is unsigned, so right-click → *Open* the first time.

## Build it yourself

```bash
flutter pub get
flutter run -d macos      # or windows / an Android device
```

Many community streams are offline, geo-blocked or flaky — the app skips unavailable ones.

import AVFoundation
import Foundation

/// Headless check: which channels actually start playing. Run with `--selftest`.
enum SelfTest {
    static func run() {
        Task {
            do {
                let chans = try await Catalog.fetch()
                print("Loaded \(chans.count) Tamil channels with streams")
                var ok = 0
                var results: [(Channel, Bool)] = []
                var i = 0
                while i < chans.count {
                    let batch = Array(chans[i..<min(i + 12, chans.count)]); i += 12
                    let r = await withTaskGroup(of: (Channel, Bool).self) { g in
                        for c in batch { g.addTask { (c, await works(c)) } }
                        var out: [(Channel, Bool)] = []
                        for await x in g { out.append(x) }
                        return out
                    }
                    results += r
                }
                for (c, good) in results.sorted(by: { $0.0.number < $1.0.number }) {
                    if good { ok += 1 }
                    print(String(format: "%3d %@ %@", c.number, good ? "OK  " : "FAIL", c.name))
                }
                print("WORKING: \(ok) / \(chans.count)")
            } catch { print("ERROR: \(error)") }
            exit(0)
        }
        RunLoop.main.run()
    }

    static func works(_ c: Channel) async -> Bool {
        for s in c.streams.prefix(3) {
            var h: [String: String] = [:]
            if let r = s.referrer { h["Referer"] = r }
            if let u = s.userAgent { h["User-Agent"] = u }
            let asset = AVURLAsset(url: s.url, options: h.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": h])
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.play()
            for _ in 0..<40 {   // up to ~10 s
                try? await Task.sleep(for: .milliseconds(250))
                if item.status == .failed { break }
                if item.status == .readyToPlay, player.currentTime().seconds > 0.3 { player.pause(); return true }
            }
            player.pause()
        }
        return false
    }
}

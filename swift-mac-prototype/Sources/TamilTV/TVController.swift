import AVFoundation
import Combine
import Foundation

@MainActor
final class TVController: ObservableObject {
    @Published var all: [Channel] = []
    @Published var category: String = "all"
    @Published var current: Channel?
    @Published var status: String = "Loading channels…"
    @Published var bannerVisible = false
    @Published var numberEntry = ""
    @Published var muted = false { didSet { player.isMuted = muted } }

    let player = AVPlayer()
    private var streamIndex = 0
    private var item: AVPlayerItem?
    private var statusObs: NSKeyValueObservation?
    private var timeout: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?
    private var numberTask: Task<Void, Never>?
    private var dead = Set<String>()
    private var direction = 1
    private var skipsInRow = 0

    @Published var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])

    var categories: [String] {
        ["all"] + (favorites.isEmpty ? [] : ["favorites"]) + Array(Set(all.map(\.category))).sorted()
    }
    var channels: [Channel] {
        switch category {
        case "all": return all
        case "favorites": return all.filter { favorites.contains($0.id) }
        default: return all.filter { $0.category == category }
        }
    }
    var isFavorite: Bool { current.map { favorites.contains($0.id) } ?? false }

    func toggleFavorite() {
        guard let c = current else { return }
        if favorites.contains(c.id) { favorites.remove(c.id) } else { favorites.insert(c.id) }
        UserDefaults.standard.set(Array(favorites), forKey: "favorites")
        if favorites.isEmpty, category == "favorites" { category = "all" }
        showBanner()
    }

    /// Jump to the next/previous favorite, whatever category is selected.
    func stepFavorite(_ d: Int) {
        let favs = all.filter { favorites.contains($0.id) }
        guard !favs.isEmpty else { status = "No favorites yet — press S on a channel to add it"
            Task { try? await Task.sleep(for: .seconds(2)); status = "" }; return }
        let n = current?.number ?? 0
        let target: Channel? = d > 0 ? (favs.first { $0.number > n } ?? favs.first)
                                     : (favs.last { $0.number < n } ?? favs.last)
        if category == "favorites" || category == "all" { } else { category = "all" }
        tune(target, direction: d)
    }

    func start() async {
        if let cached = Catalog.loadCached(), !cached.isEmpty { setChannels(cached) }
        do { setChannels(try await Catalog.fetch()) }
        catch { if all.isEmpty { status = "Could not load channels: \(error.localizedDescription)" } }
    }

    private func setChannels(_ list: [Channel]) {
        let first = all.isEmpty
        all = list
        guard first else { return }
        let last = UserDefaults.standard.string(forKey: "lastChannel")
        tune(list.first { $0.id == last } ?? list.first, direction: 1)
    }

    // MARK: Switching
    func next() { step(1) }
    func previous() { step(-1) }

    private func step(_ d: Int) {
        let list = channels
        guard !list.isEmpty else { return }
        let i = list.firstIndex { $0.id == current?.id } ?? (d > 0 ? -1 : 0)
        tune(list[((i + d) % list.count + list.count) % list.count], direction: d)
    }

    func cycleCategory() {
        let cats = categories
        category = cats[((cats.firstIndex(of: category) ?? 0) + 1) % cats.count]
        if let c = channels.first { tune(c, direction: 1) }
        showBanner()
    }

    func typeDigit(_ d: String) {
        numberEntry = String((numberEntry + d).suffix(3))
        numberTask?.cancel()
        numberTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            commitNumber()
        }
    }

    func commitNumber() {
        numberTask?.cancel()
        defer { numberEntry = "" }
        guard let n = Int(numberEntry), let c = all.first(where: { $0.number == n }) else { return }
        if category != "all", c.category != category { category = "all" }
        tune(c, direction: 1)
    }

    // MARK: Playback
    func tune(_ channel: Channel?, direction: Int, resetSkips: Bool = true) {
        guard let channel else { return }
        self.direction = direction
        if resetSkips { skipsInRow = 0 }
        current = channel
        UserDefaults.standard.set(channel.id, forKey: "lastChannel")
        streamIndex = 0
        status = ""
        showBanner()
        playStream()
    }

    private func playStream() {
        guard let ch = current, streamIndex < ch.streams.count else { return failChannel() }
        let s = ch.streams[streamIndex]
        var headers: [String: String] = [:]
        if let r = s.referrer { headers["Referer"] = r }
        if let u = s.userAgent { headers["User-Agent"] = u }
        let asset = AVURLAsset(url: s.url, options: headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let it = AVPlayerItem(asset: asset)
        item = it
        statusObs = it.observe(\.status, options: [.new]) { [weak self] it, _ in
            Task { @MainActor in
                guard let self, self.item === it else { return }
                switch it.status {
                case .readyToPlay: self.timeout?.cancel(); self.skipsInRow = 0; self.player.play()
                case .failed: self.failStream()
                default: break
                }
            }
        }
        player.replaceCurrentItem(with: it)
        player.isMuted = muted
        player.play()
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            self?.failStream(only: it)
        }
    }

    private func failStream(only: AVPlayerItem? = nil) {
        if let only, item !== only { return }
        timeout?.cancel()
        streamIndex += 1
        playStream()
    }

    private func failChannel() {
        guard let ch = current else { return }
        dead.insert(ch.id)
        status = "\(ch.name) is not available — skipping"
        skipsInRow += 1
        let list = channels
        guard skipsInRow < list.count else { status = "No working channels found"; return }
        let d = direction
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            guard current?.id == ch.id else { return }
            let i = list.firstIndex { $0.id == ch.id } ?? 0
            tune(list[((i + d) % list.count + list.count) % list.count], direction: d, resetSkips: false)
        }
    }

    func showBanner() {
        bannerVisible = true
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            bannerVisible = false
        }
    }
}

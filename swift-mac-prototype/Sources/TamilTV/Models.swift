import Foundation

struct StreamInfo: Hashable {
    let url: URL
    let referrer: String?
    let userAgent: String?
    let quality: String?
}

struct Channel: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    var number: Int
    let logo: URL?
    var streams: [StreamInfo]
}

private struct ChannelDTO: Decodable {
    let id: String; let name: String; let country: String?
    let categories: [String]?; let is_nsfw: Bool?; let closed: String?
}
private struct FeedDTO: Decodable { let channel: String; let languages: [String]? }
private struct StreamDTO: Decodable {
    let channel: String?; let url: String
    let referrer: String?; let user_agent: String?; let quality: String?
}
private struct LogoDTO: Decodable { let channel: String; let url: String }
private struct BlockDTO: Decodable { let channel: String }

enum Catalog {
    static let base = "https://iptv-org.github.io/api/"
    static let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TamilTV", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("channels-cache.json")
    }()

    private struct Cached: Codable {
        struct C: Codable { let id, name, category: String; let logo: String?; let streams: [S] }
        struct S: Codable { let url: String; let referrer, userAgent, quality: String? }
        let channels: [C]
    }

    static func loadCached() -> [Channel]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let c = try? JSONDecoder().decode(Cached.self, from: data) else { return nil }
        return number(c.channels.map { x in
            Channel(id: x.id, name: x.name, category: x.category, number: 0,
                    logo: x.logo.flatMap(URL.init(string:)),
                    streams: x.streams.compactMap { s in
                        URL(string: s.url).map { StreamInfo(url: $0, referrer: s.referrer, userAgent: s.userAgent, quality: s.quality) } })
        })
    }

    static func fetch() async throws -> [Channel] {
        func get<T: Decodable>(_ f: String, _ t: T.Type) async throws -> T {
            let (d, _) = try await URLSession.shared.data(from: URL(string: base + f)!)
            return try JSONDecoder().decode(T.self, from: d)
        }
        async let chs = get("channels.json", [ChannelDTO].self)
        async let feeds = get("feeds.json", [FeedDTO].self)
        async let streams = get("streams.json", [StreamDTO].self)
        async let logos = get("logos.json", [LogoDTO].self)
        async let block = get("blocklist.json", [BlockDTO].self)
        let (c, f, s, l, b) = try await (chs, feeds, streams, logos, block)

        let tamil = Set(f.filter { ($0.languages ?? []).contains("tam") }.map(\.channel))
        let blocked = Set(b.map(\.channel))
        var byChannel: [String: [StreamInfo]] = [:]
        for x in s {
            guard let ch = x.channel, tamil.contains(ch), let u = URL(string: x.url) else { continue }
            byChannel[ch, default: []].append(StreamInfo(url: u, referrer: x.referrer, userAgent: x.user_agent, quality: x.quality))
        }
        var logoFor: [String: String] = [:]
        for x in l where logoFor[x.channel] == nil { logoFor[x.channel] = x.url }

        let result = c.compactMap { ch -> Channel? in
            guard let st = byChannel[ch.id], !st.isEmpty, ch.closed == nil,
                  ch.is_nsfw != true, !blocked.contains(ch.id) else { return nil }
            // Best quality first (highest resolution number), unknown last.
            let sorted = st.sorted { q($0.quality) > q($1.quality) }
            return Channel(id: ch.id, name: ch.name, category: ch.categories?.first ?? "general",
                           number: 0, logo: logoFor[ch.id].flatMap(URL.init(string:)), streams: sorted)
        }
        let numbered = number(result)

        let cache = Cached(channels: numbered.map { c in
            .init(id: c.id, name: c.name, category: c.category, logo: c.logo?.absoluteString,
                  streams: c.streams.map { .init(url: $0.url.absoluteString, referrer: $0.referrer, userAgent: $0.userAgent, quality: $0.quality) }) })
        if let data = try? JSONEncoder().encode(cache) { try? data.write(to: cacheURL) }
        return numbered
    }

    private static func q(_ s: String?) -> Int { Int((s ?? "").dropLast()) ?? 0 }

    private static let order = ["general", "entertainment", "news", "movies", "music", "kids", "religious"]
    static func number(_ list: [Channel]) -> [Channel] {
        func rank(_ c: Channel) -> Int { order.firstIndex(of: c.category) ?? order.count }
        var sorted = list.sorted { (rank($0), $0.name.lowercased()) < (rank($1), $1.name.lowercased()) }
        for i in sorted.indices { sorted[i].number = i + 1 }
        return sorted
    }
}

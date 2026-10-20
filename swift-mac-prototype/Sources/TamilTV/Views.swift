import AVKit
import SwiftUI

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var tv = TVController()
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black
            PlayerView(player: tv.player).allowsHitTesting(false)

            if !tv.status.isEmpty {
                Text(tv.status).font(.title3).foregroundStyle(.white)
                    .padding(14).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            }
            if !tv.numberEntry.isEmpty {
                VStack { HStack { Spacer()
                    Text(tv.numberEntry).font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow).shadow(radius: 4).padding(30)
                }; Spacer() }
            }
            VStack {
                Spacer()
                if tv.bannerVisible, let c = tv.current { Banner(channel: c, category: tv.category, muted: tv.muted, favorite: tv.isFavorite) }
            }
            .animation(.easeInOut(duration: 0.25), value: tv.bannerVisible)
        }
        .ignoresSafeArea()
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .task { await tv.start() }
        .onKeyPress(keys: [.upArrow, .rightArrow]) { _ in tv.next(); return .handled }
        .onKeyPress(keys: [.downArrow, .leftArrow]) { _ in tv.previous(); return .handled }
        .onKeyPress(.return) { tv.commitNumber(); return .handled }
        .onKeyPress(.space) { tv.muted.toggle(); tv.showBanner(); return .handled }
        .onKeyPress(characters: .decimalDigits, phases: .down) { tv.typeDigit($0.characters); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "fF")) { _ in
            NSApp.keyWindow?.toggleFullScreen(nil); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "cC")) { _ in tv.cycleCategory(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "sS")) { _ in tv.toggleFavorite(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "]")) { _ in tv.stepFavorite(1); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "[")) { _ in tv.stepFavorite(-1); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "iI")) { _ in tv.showBanner(); return .handled }
    }
}

struct Banner: View {
    let channel: Channel
    let category: String
    let muted: Bool
    let favorite: Bool
    var body: some View {
        HStack(spacing: 16) {
            Text("\(channel.number)").font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
            if let logo = channel.logo {
                AsyncImage(url: logo) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                    .frame(width: 60, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text((favorite ? "★ " : "") + channel.name).font(.title2.bold())
                Text("\(channel.category.capitalized)  ·  Filter: \(category.capitalized)").font(.callout).opacity(0.8)
            }
            Spacer()
            if muted { Image(systemName: "speaker.slash.fill").font(.title2) }
            Text("↑↓ channel   [ ] favorites   S star   0-9 jump   C category   Space mute   F full")
                .font(.caption).opacity(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
        .padding(24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

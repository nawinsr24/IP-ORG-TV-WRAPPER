import AVFoundation
import SwiftUI

struct TamilTVApp: App {
    var body: some Scene {
        WindowGroup("Tamil TV") { ContentView().frame(minWidth: 640, minHeight: 360) }
            .windowStyle(.hiddenTitleBar)
    }
}

if CommandLine.arguments.contains("--selftest") {
    SelfTest.run()
} else {
    TamilTVApp.main()
}

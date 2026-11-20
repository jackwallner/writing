import SwiftUI

@main
struct InklingApp: App {
    init() {
        Theme.applyNavigationAppearance()
        SubscriptionService.shared.start()
        ReviewPrompt().recordLaunch()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SeedDemo") {
            Journal.shared.seedDemo(library: .bundled)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
                .tint(Theme.accent)
        }
    }
}

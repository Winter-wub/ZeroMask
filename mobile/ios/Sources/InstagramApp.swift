import SwiftUI

@main
struct InstagramApp: App {
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(settings.themeMode.colorScheme)
        }
    }
}

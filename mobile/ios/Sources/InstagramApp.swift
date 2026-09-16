import SwiftUI

@main
struct InstagramApp: App {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _ = NotificationManager.shared
        BackgroundTaskManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(settings.themeMode.colorScheme)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                BackgroundTaskManager.shared.scheduleAppRefresh()
            }
        }
    }
}

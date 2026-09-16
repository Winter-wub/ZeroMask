## Question

Prototype the iOS `BGTaskScheduler` and `UNUserNotificationCenter` setup to verify that we can reliably trigger a local notification from the background, and confirm how often iOS allows this task to run for our app.

## Type

wayfinder:prototype

## Status

Closed

## Resolution

- Created `BackgroundTaskManager.swift` which registers `com.local.gallery.fetchUpdates` with `BGTaskScheduler`.
- When the SwiftUI `scenePhase` goes to `.background` in `InstagramApp.swift`, we call `scheduleAppRefresh()` to schedule a background task.
- When the task fires, it calls `NotificationManager.shared.postDisguisedNotification()` which creates a local notification looking exactly like Instagram (e.g. "somchai liked your photo.").
- To test this in Xcode, we can use the LLDB command:
  `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.local.gallery.fetchUpdates"]`
- Note: Requires adding `com.local.gallery.fetchUpdates` to the `Permitted background task scheduler identifiers` in `Info.plist` and enabling the `Background fetch` capability.

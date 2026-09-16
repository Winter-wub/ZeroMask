## Question

1. Add `UIBackgroundModes` (`fetch`, `processing`) and `BGTaskSchedulerPermittedIdentifiers` to `mobile/ios/project.yml` so iOS background tasks can execute in production.
2. Replace fragile fetch/XHR monkey-patching by extracting the Tinder auth token directly from `localStorage` / cookies and storing it in a dedicated `KeychainTokenStore` (not `PinStore`).
3. Refactor `NotificationManager` and `BackgroundTaskManager` to persist `lastKnownCount` in `UserDefaults`, support randomized disguise templates, respect Decoy Mode, and only notify on true count increments.

## Type

wayfinder:task

## Status

Closed

## Resolution

- **Project Config**: Added `UIBackgroundModes: [fetch, processing]` and `BGTaskSchedulerPermittedIdentifiers: [com.prachayawut.gallery.fetchUpdates]` to `project.yml`. Regenerated project with `xcodegen generate` (`Info.plist` updated).
- **Keychain Storage**: Created `KeychainTokenStore.swift` to read/write plaintext tokens safely using iOS Keychain.
- **Token Extraction**: Injected localStorage token reader in `MaskScripts.swift` and handled `"auth-token"` in `TinderWebView.swift`, saving to `KeychainTokenStore`.
- **Notification Disguise**: Refactored `NotificationManager` with randomized Instagram handles and actions, persisting `lastCount` in `UserDefaults`.
- **Decoy Mode Guard**: Connected `RootView` Decoy state to `AppSettings.shared.isDecoyActive`, completely suppressing notifications in Decoy mode.
- **Background Fetch Polling**: Implemented `BackgroundTaskManager` polling `https://api.gotinder.com/v2/meta` with Mobile Safari User-Agent, safe headers, and graceful 401 handling.

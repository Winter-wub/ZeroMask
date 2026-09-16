## Destination

Implement Tinder background notifications in the `mask-of-sex` iOS app via Background Fetch and Local Notifications. The notifications must be disguised as typical Instagram notifications (e.g., "john_doe sent you a message") to maintain absolute camouflage.

## Notes

- Domain: iOS (SwiftUI, WKWebView).
- Constraints: 
  - Must not use a central proxy server to preserve user privacy. 
  - Must rely on iOS Background Tasks (`BGTaskScheduler`) or Background Fetch to periodically poll Tinder's API or Web DOM.
  - Notifications must mimic Instagram's local phrasing exactly.
  - Must respect the "Decoy Boundary"; notifications should probably not appear if the device is locked in Decoy mode, or they should be totally benign.

## Decisions so far

- **[Technical Approach]**: Use Background Fetch + Local Notifications instead of a Proxy Server to prioritize privacy over real-time delivery.
- **[Disguise]**: Notification content will mimic Instagram interactions (e.g., "user sent you a message", "user liked your photo").
- **[Primary Platform]**: Focus exclusively on the iOS mobile app for now.
- [01-research-tinder-api-polling](file:///Users/prachayawut/personal-projects/mask-of-sex/wayfinder-tickets/01-research-tinder-api-polling.md): Discovered auth token retrieval via localStorage/cookies and URLSession background requests.
- [02-prototype-bg-tasks](file:///Users/prachayawut/personal-projects/mask-of-sex/wayfinder-tickets/02-prototype-bg-tasks.md): Prototyped `BGTaskScheduler` triggering a disguised Local Notification.
- **[Token Storage]**: Use a dedicated `KeychainTokenStore` for reading/writing plaintext tokens (since `PinStore` only stores SHA-256 one-way hashes).
- **[Extraction Method]**: Read auth token cleanly from `localStorage` (`TinderWeb/APIToken`) and cookies rather than hooking `window.fetch`/`XHR`.
- **[Decoy Safety]**: Decoy Mode (PickleWatch) must suppress all Tinder notifications to prevent blowing cover.
- [03-task-implement-interceptor](file:///Users/prachayawut/personal-projects/mask-of-sex/wayfinder-tickets/03-task-implement-interceptor.md): Configured iOS Background Modes, extracted token via localStorage, created KeychainTokenStore, synced Decoy guard, and enabled disguised notifications.

## Not yet specified

- Best-effort iOS background scheduling limits (force-quit disables BGTaskScheduler; low-power mode pauses fetch).
- Anti-ban headers: Matching Mobile Safari UA and cookies when polling Tinder updates.

## Out of scope

(None yet)

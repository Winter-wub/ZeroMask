# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Discreet adult dating app users on iPhone who need absolute privacy when browsing Tinder in shared or public environments (home, office, transit, social gatherings) where visibility of dating apps causes embarrassment or conflict.

## Product Purpose
Wrap Tinder web inside an unremarkable-looking app named "Prism" so that any bystander, partner, or casual observer glancing at the Home Screen, App Switcher, notifications, or the open app sees nothing that suggests a dating app.

## Positioning
A neutral "Prism" identity (3D crystal icon) with switchable in-app disguise modes (Liquid Glass, raw Tinder, ChatGPT 4o-styled Instagram Direct) wrapping Tinder web, plus a quick switch to real Instagram. Unlike generic "calculator vault" or hidden folder apps, it runs in plain sight while preserving 1:1 human action mapping (no auto-swiping / bots, fully adhering to account safety).

## Operating Context
- iPhone handheld usage in public, transit, workplace, or home settings where shoulder-surfing occurs.
- Home Screen and App Switcher show the "Prism" identity; the App Switcher snapshot is covered by a banking-style Privacy Shield.
- Notifications are disguised as AI-agent work updates or Instagram activity; the icon badge shows the combined unread count.
- Dual-PIN lock screen: Primary PIN unlocks the app; Secondary decoy PIN opens a real PickleWatch live stream in a non-persistent web session with zero trace of Tinder. Face ID never auto-prompts while a decoy PIN is set.
- Repeated wrong PINs trigger an escalating lockout (30 s → 1 min → 5 min → 15 min) persisted in Keychain.
- Rapid emergency escape: 5-tap top-left gesture or app backgrounding exits decoy mode back to the lock screen.

## Capabilities and Constraints
- Native SwiftUI app shell hosting WKWebView running Tinder web (and a separate real-Instagram web view) with injected custom scripts (`MaskScripts.swift`); script messages are accepted only from the main frame of the real domain.
- Stripping of Tinder navigation, brand banners, and gamepad buttons; full-screen "Seamless Chat" and "Seamless Explore" views.
- Optional gestures (toggle in Settings): double-tap photo to Like with heart animation; swipe to Pass (Nope).
- Background refresh polls Tinder / Instagram unread counts using session tokens captured from the web views (Keychain, this-device-only).
- Real native GPS location permission passed through to Tinder web.
- PIN hashes stored in Keychain with PBKDF2-SHA256 (`PinStore.swift`).
- Strict 1:1 human interaction dispatch; no automated swiping or background scraping.
- Dependent on Tinder web DOM structure (`nav`, `main.mobile`, `.gamepad-button-wrapper`, `button.gamepad-button`).
- Free developer provisioning limit (7-day re-signing via `./install.sh` unless using paid Apple Developer account).

## Brand Commitments
- Public disguise identity: "Prism" (3D crystal icon, app name, Privacy Shield). The Xcode target/bundle is still named `Instagram` internally.
- Internal codebase name: `mask-of-sex`.
- Every disguise mode must look like a complete, plausible app on its own — no half-hidden Tinder chrome.

## Evidence on Hand
- Swift iOS implementation in `mobile/ios/Sources/` (`ContentView.swift`, `LockView.swift`, `MaskScripts.swift`, `PickleLiveView.swift`, `PinStore.swift`, `SettingsView.swift`, `TinderWebView.swift`).
- Xcode project specification in `mobile/ios/project.yml` and `mobile/ios/Instagram.xcodeproj`.
- iOS documentation in `mobile/ios/README.md`.

## Product Principles
1. **Camouflage is Absolute**: If a bystander or casual viewer suspects the app is anything other than what its disguise claims, the design has failed.
2. **Authentic Muscle Memory**: Gestures and spatial rhythm should feel native to the chosen disguise so the user blends in without awkward hesitations.
3. **Impenetrable Decoy Boundary**: The secondary PIN path (PickleWatch) must be an entirely genuine, functional, non-persistent surface with zero leaks of dating state or data — including no notifications while it is showing.
4. **Account Safety via Strict 1:1 Execution**: Every action maps directly to one human input event; zero automation, botting, or artificial fast-forwarding.

## Accessibility & Inclusion
- Adhere to Apple Human Interface Guidelines (HIG) minimum 44×44 pt touch targets for all interactive controls.
- Maintain high contrast and proper system font scaling.

# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Discreet adult dating app users on iPhone who need absolute privacy when browsing Tinder in shared or public environments (home, office, transit, social gatherings) where visibility of dating apps causes embarrassment or conflict.

## Product Purpose
Deliver an indistinguishable, authentic Instagram iOS experience that seamlessly routes actions to Tinder web underneath. Success means any bystander, partner, or casual observer glancing at the screen sees standard Instagram feed browsing with zero suspicious anomalies.

## Positioning
Pixel-accurate Instagram camouflage with authentic native feed ergonomics (double-tap like with heart burst animation, post headers with name/age, post action rows, story bars) wrapping Tinder web. Unlike generic "calculator vault" or hidden folder apps, it runs in plain sight as a high-fidelity social media app while preserving 1:1 human action mapping (no auto-swiping / bots, fully adhering to account safety).

## Operating Context
- iPhone handheld usage in public, transit, workplace, or home settings where shoulder-surfing occurs.
- iOS App Switcher and notification badges disguised under the "Instagram" display identity and icon.
- Dual-PIN lock screen: Primary PIN unlocks the Instagram/Tinder feed; Secondary decoy PIN opens a real PickleWatch live stream / PickleDashboard with completely isolated sessions and zero trace of Tinder.
- Rapid emergency escape: 5-tap top-left gesture or app backgrounding exits decoy mode back to the lock screen.

## Capabilities and Constraints
- Native SwiftUI app shell hosting WKWebView running Tinder web with injected custom scripts (`MaskScripts.swift`).
- Complete stripping of Tinder navigation, brand banners, and gamepad buttons, reframing profile cards as Instagram feed posts.
- Natural Instagram gestures: double-tap photo to Like with heart animation; hard upward scroll / swipe to Pass (Nope); Bookmark icon to Pass; Heart icon to Like; Airplane icon to Super Like; Chat icon to access conversations.
- Real native GPS location permission passed through to Tinder web.
- Dual PIN storage via Keychain (`PinStore.swift`).
- Strict 1:1 human interaction dispatch; no automated swiping or background scraping.
- Dependent on Tinder web DOM structure (`nav`, `main.mobile`, `.gamepad-button-wrapper`, `button.gamepad-button`).
- Free developer provisioning limit (7-day re-signing via `./install.sh` unless using paid Apple Developer account).

## Brand Commitments
- Public disguise identity: "Instagram" (icon, app name, visual chrome, navigation bar, and tab bar styling).
- Internal codebase name: `mask-of-sex`.
- Strict mimicry: Every visible pixel and gesture must reflect Instagram's actual mobile interface.

## Evidence on Hand
- Swift iOS implementation in `mobile/ios/Sources/` (`ContentView.swift`, `LockView.swift`, `MaskScripts.swift`, `PickleLiveView.swift`, `PickleDashboard.swift`, `PinStore.swift`, `SettingsView.swift`, `TinderWebView.swift`).
- Xcode project specification in `mobile/ios/project.yml` and `mobile/ios/Instagram.xcodeproj`.
- Reference desktop wrapper in `src/` (`main.js`, `shell.html`, `shell.js`, `preload.js`).
- iOS documentation in `mobile/ios/README.md`.

## Product Principles
1. **Camouflage is Absolute**: If a bystander or casual viewer suspects the app is anything other than Instagram, the design has failed.
2. **Authentic Muscle Memory**: Touch gestures and spatial rhythm must match Instagram's real feed behaviors so the user naturally blends in without awkward hesitations.
3. **Impenetrable Decoy Boundary**: The secondary PIN path (PickleWatch/PickleDashboard) must be an entirely genuine, functional, non-persistent surface with zero leaks of dating state or data.
4. **Account Safety via Strict 1:1 Execution**: Every action maps directly to one human input event; zero automation, botting, or artificial fast-forwarding.

## Accessibility & Inclusion
- Adhere to Apple Human Interface Guidelines (HIG) minimum 44×44 pt touch targets for all interactive controls.
- Maintain high contrast and proper system font scaling that aligns with Instagram's mobile typography.

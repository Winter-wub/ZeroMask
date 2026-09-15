import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "ตามระบบ"
        case .light:  return "สว่าง"
        case .dark:   return "มืด"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum DisguiseMode: String, CaseIterable, Identifiable {
    case liquidGlass = "liquid"
    case instagram = "instagram"
    case rawTinder = "tinder"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liquidGlass: return "💎 Liquid Glass"
        case .instagram:   return "📸 Instagram"
        case .rawTinder:   return "🔥 Tinder"
        }
    }
}

// สถานะการตั้งค่าที่จำไว้ (UserDefaults) — ใช้ร่วมกันทั้งแอป
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("disguiseMode") var disguiseMode: DisguiseMode = .liquidGlass {
        willSet { objectWillChange.send() }
    }
    @AppStorage("themeMode") var themeMode: ThemeMode = .system {
        willSet { objectWillChange.send() }
    }
    @AppStorage("gestureDoubleTapLike") var doubleTapLike = true {
        willSet { objectWillChange.send() }
    }
    @AppStorage("gestureSwipeToPass") var swipeToPass = true {
        willSet { objectWillChange.send() }
    }
    @AppStorage("showActionRow") var showActionRow = true {
        willSet { objectWillChange.send() }
    }
    // เปิดใช้ Face ID / Touch ID ตอนปลดล็อก (นอกเหนือจาก PIN)
    @AppStorage("useBiometrics") var useBiometrics = true {
        willSet { objectWillChange.send() }
    }

    // ── การแจ้งเตือน ──
    @AppStorage("notificationsEnabled") var notificationsEnabled = false {
        willSet { objectWillChange.send() }
    }
    @AppStorage("notificationSound") var notificationSound = true {
        willSet { objectWillChange.send() }
    }
    @AppStorage("showIconBadge") var showIconBadge = true {
        willSet { objectWillChange.send() }
    }
    // เด้งแจ้งเตือนแม้กำลังใช้แอปอยู่
    @AppStorage("notifyWhileUsing") var notifyWhileUsing = false {
        willSet { objectWillChange.send() }
    }

    // ── PIN สำรอง (decoy): ใส่แล้วเปิดเว็บ PickleWatch ตัวจริงเต็มจอ ──
    @AppStorage("pickleLiveURL") var pickleLiveURL =
        "" {
        willSet { objectWillChange.send() }
    }

    // PIN เปิดอยู่ไหม (ดูจาก Keychain ไม่ใช่ UserDefaults)
    var pinEnabled: Bool { PinStore.isSet }
    var decoyPinEnabled: Bool { PinStore.isSet(.decoy) }

    private init() {}
}

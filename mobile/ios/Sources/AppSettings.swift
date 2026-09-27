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
    case rawTinder = "tinder"
    case chatGPT = "chatgpt"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liquidGlass: return "💎 Liquid Glass"
        case .rawTinder:   return "🔥 Tinder"
        case .chatGPT:     return "🤖 ChatGPT 4o"
        }
    }
}

enum NotificationDisguiseStyle: String, CaseIterable, Identifiable {
    case aiAgent = "ai_agent"
    case instagram = "instagram"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aiAgent:   return "🤖 AI Agent (Dev / Work)"
        case .instagram: return "📸 Instagram"
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
    @AppStorage("notificationsEnabled") var notificationsEnabled = true {
        willSet { objectWillChange.send() }
    }
    @AppStorage("notificationDisguiseStyle") var notificationDisguiseStyle: NotificationDisguiseStyle = .aiAgent {
        willSet { objectWillChange.send() }
    }
    @AppStorage("notificationSound") var notificationSound = true {
        willSet { objectWillChange.send() }
    }
    @AppStorage("showIconBadge") var showIconBadge = true {
        willSet { objectWillChange.send() }
    }
    // เด้งแจ้งเตือนแม้กำลังใช้แอปอยู่
    @AppStorage("notifyWhileUsing") var notifyWhileUsing = true {
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

    /// สถานะว่ากำลังอยู่ในโหมดอำพราง (PickleWatch) หรือไม่
    @Published var isDecoyActive = false

    private init() {}
}

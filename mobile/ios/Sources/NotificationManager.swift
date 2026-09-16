import Foundation
import UserNotifications
import UIKit

// จัดการ local notification + badge บนไอคอนแอป
//
// ข้อจำกัดสำคัญ: แอปนี้เป็น wrapper ของเว็บ ไม่มี push server
// → ตรวจเจอกิจกรรมใหม่ได้เฉพาะตอนแอปเปิดอยู่ (webview ยังรันอยู่)
//   ตอนแอปโดน suspend เต็มที่ webview จะหยุด ตรวจไม่ได้
// ส่วน badge บนไอคอนจะค้างอยู่บนหน้าโฮมเหมือนแอปจริง
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        refreshAuthorizationStatus()
    }

    // อนุญาตให้แสดง Banner และเล่นเสียงขณะที่แอปเปิดอยู่หน้าจอ (Foreground)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    private var lastCount: Int {
        get { UserDefaults.standard.integer(forKey: "NotificationManager.lastCount") }
        set { UserDefaults.standard.set(newValue, forKey: "NotificationManager.lastCount") }
    }
    private(set) var authorized = false
    var isAuthorized: Bool { authorized }

    private let instagramHandles = [
        "alex_m", "sarah.k", "mike.photo", "emma_designs",
        "david.bkk", "charlotte_v", "lucas.art", "nathan_j"
    ]
    private let instagramActions = [
        "liked your photo.",
        "liked your story.",
        "sent you a message.",
        "commented: '🔥'",
        "started following you."
    ]

    /// ขอสิทธิ์แจ้งเตือน (เรียกตอนผู้ใช้เปิด toggle ใน Settings)
    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    self.authorized = granted
                    completion?(granted)
                }
            }
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async {
                self.authorized = (s.authorizationStatus == .authorized
                                   || s.authorizationStatus == .provisional)
            }
        }
    }

    /// เรียกทุกครั้งที่เลขแจ้งเตือนจาก Tinder หรือ Instagram เปลี่ยน
    func handleBadgeChange(to count: Int, appIsActive: Bool, source: String? = nil) {
        let settings = AppSettings.shared
        defer { lastCount = count }

        // badge บนไอคอนแอป (หน้าโฮม)
        if settings.notificationsEnabled && settings.showIconBadge {
            setIconBadge(count)
        } else {
            setIconBadge(0)
        }

        guard settings.notificationsEnabled, authorized else { return }
        // ถ้าอยู่ใน Decoy Mode (PickleWatch) ห้ามเด้งแจ้งเตือนเด็ดขาดเพื่อความปลอดภัย
        guard !settings.isDecoyActive else { return }
        // แจ้งเฉพาะตอน "เพิ่มขึ้น" เท่านั้น (อ่านแล้วเลขลด ไม่ต้องเด้ง)
        guard count > lastCount, count > 0 else { return }
        // ถ้ากำลังดูแอปอยู่ ไม่ต้องเด้งซ้ำ (เห็น badge ในแอปอยู่แล้ว)
        if appIsActive && !settings.notifyWhileUsing { return }

        if source == "Instagram" {
            postDisguisedNotification(action: "sent you a direct message.")
        } else {
            postDisguisedNotification()
        }
    }

    func resetLastCount() {
        lastCount = 0
    }

    /// ยิง Notification พรางเป็น Instagram
    func postDisguisedNotification(
        user: String? = nil,
        action: String? = nil,
        force: Bool = false,
        completion: ((Bool, String) -> Void)? = nil
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let isAuth = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            DispatchQueue.main.async { self.authorized = isAuth }

            guard isAuth else {
                let msg = "ระบบยังไม่ได้รับสิทธิ์แจ้งเตือน (Status: \(settings.authorizationStatus.rawValue))"
                print("[Notification] \(msg)")
                DispatchQueue.main.async { completion?(false, msg) }
                return
            }

            if !force {
                guard AppSettings.shared.notificationsEnabled else {
                    DispatchQueue.main.async { completion?(false, "การแจ้งเตือนถูกปิดไว้ในแอป") }
                    return
                }
                guard !AppSettings.shared.isDecoyActive else {
                    DispatchQueue.main.async { completion?(false, "อยู่ในโหมดอำพราง (Decoy)") }
                    return
                }
            }

            let handle = user ?? (self.instagramHandles.randomElement() ?? "alex_m")
            let act = action ?? (self.instagramActions.randomElement() ?? "liked your photo.")

            let content = UNMutableNotificationContent()
            content.title = "Instagram"
            content.body = "\(handle) \(act)"
            content.sound = AppSettings.shared.notificationSound ? .default : nil

            let req = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
            UNUserNotificationCenter.current().add(req) { error in
                if let error = error {
                    let errStr = "เกิดข้อผิดพลาด: \(error.localizedDescription)"
                    print("[Notification] \(errStr)")
                    DispatchQueue.main.async { completion?(false, errStr) }
                } else {
                    let successMsg = "\(handle) \(act)"
                    print("[Notification] Successfully posted disguised notification: \(successMsg)")
                    DispatchQueue.main.async { completion?(true, successMsg) }
                }
            }
        }
    }

    private func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if AppSettings.shared.notificationSound { content.sound = .default }

        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: nil) // เด้งทันที
        UNUserNotificationCenter.current().add(req)
    }

    func setIconBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    func clearAll() {
        setIconBadge(0)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

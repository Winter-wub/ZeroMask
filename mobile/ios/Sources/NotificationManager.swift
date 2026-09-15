import Foundation
import UserNotifications
import UIKit

// จัดการ local notification + badge บนไอคอนแอป
//
// ข้อจำกัดสำคัญ: แอปนี้เป็น wrapper ของเว็บ ไม่มี push server
// → ตรวจเจอกิจกรรมใหม่ได้เฉพาะตอนแอปเปิดอยู่ (webview ยังรันอยู่)
//   ตอนแอปโดน suspend เต็มที่ webview จะหยุด ตรวจไม่ได้
// ส่วน badge บนไอคอนจะค้างอยู่บนหน้าโฮมเหมือนแอปจริง
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private var lastCount = 0
    private var authorized = false

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

    /// เรียกทุกครั้งที่เลขแจ้งเตือนจาก Tinder เปลี่ยน
    func handleBadgeChange(to count: Int, appIsActive: Bool) {
        let settings = AppSettings.shared
        defer { lastCount = count }

        // badge บนไอคอนแอป (หน้าโฮม)
        if settings.notificationsEnabled && settings.showIconBadge {
            setIconBadge(count)
        } else {
            setIconBadge(0)
        }

        guard settings.notificationsEnabled, authorized else { return }
        // แจ้งเฉพาะตอน "เพิ่มขึ้น" เท่านั้น (อ่านแล้วเลขลด ไม่ต้องเด้ง)
        guard count > lastCount, count > 0 else { return }
        // ถ้ากำลังดูแอปอยู่ ไม่ต้องเด้งซ้ำ (เห็น badge ในแอปอยู่แล้ว)
        if appIsActive && !settings.notifyWhileUsing { return }

        let new = count - lastCount
        post(title: "PickleWatch",
             body: new == 1 ? "คุณมีข้อความใหม่ 1 รายการ"
                            : "คุณมีข้อความใหม่ \(new) รายการ")
    }

    func postDisguisedNotification(user: String = "somchai") {
        let content = UNMutableNotificationContent()
        content.title = "Instagram"
        content.body = "\(user) liked your photo."
        if AppSettings.shared.notificationSound { content.sound = .default }

        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: nil)
        UNUserNotificationCenter.current().add(req)
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

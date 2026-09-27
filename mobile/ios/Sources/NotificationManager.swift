import Foundation
import UserNotifications
import UIKit

// จัดการ local notification + badge บนไอคอนแอป
//
// ข้อจำกัดสำคัญ: แอปนี้เป็น wrapper ของเว็บ ไม่มี push server
// → ตรวจเจอกิจกรรมใหม่ได้เฉพาะตอนแอปเปิดอยู่ (webview ยังรันอยู่)
//   ตอนแอปโดน suspend เต็มที่ webview จะหยุด ตรวจไม่ได้
// ส่วน badge บนไอคอนจะค้างอยู่บนหน้าโฮมเหมือนแอปจริง
extension Notification.Name {
    /// ยิงทุกครั้งที่ยอดแชทยังไม่อ่านของ Tinder/IG เปลี่ยน (ทั้งจาก webview และ background fetch)
    static let unreadCountsChanged = Notification.Name("NotificationManager.unreadCountsChanged")
}

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

    private var lastTinderCount: Int {
        get { UserDefaults.standard.integer(forKey: "NotificationManager.lastTinderCount") }
        set { UserDefaults.standard.set(newValue, forKey: "NotificationManager.lastTinderCount") }
    }
    private var lastIGCount: Int {
        get { UserDefaults.standard.integer(forKey: "NotificationManager.lastIGCount") }
        set { UserDefaults.standard.set(newValue, forKey: "NotificationManager.lastIGCount") }
    }
    var currentTotalCount: Int {
        lastTinderCount + lastIGCount
    }
    var tinderUnreadCount: Int { lastTinderCount }
    var igUnreadCount: Int { lastIGCount }
    private(set) var authorized = false
    var isAuthorized: Bool { authorized }

    // MARK: - AI Agent Disguise (อ้างอิงโปรเจกต์งานจริงจาก Obsidian)

    private let aiAgentSenders = [
        "Claude Code",
        "Antigravity",
        "Agent Runner",
        "Hermes Agent",
        "Task Agent",
        "DevOps Bot"
    ]

    /// ข้อความแจ้งเตือนสถานะงาน / task สำเร็จ (สำหรับ Likes / แมตช์ / polling เบื้องหลัง)
    private let aiAgentTaskUpdates = [
        "Task complete: SFTP Watcher 15-min scheduler synced in map-datapipeline.",
        "Quality gate passed: SonarQube verified 0 issues for sale-tools.",
        "Prisma migration: Generated idempotent SQL script for PRD handoff.",
        "Mappedin Sync: Successfully reconciled 14 venue polygons.",
        "Figma Tokens: Extracted variables and mapped to palette.salesBand.",
        "Kiosk Agent: Heartbeat received (v1.0.4). All services healthy.",
        "AuthGuard: Verified EmailAuthGuard & AdminGuard order on /admin/scheduler.",
        "Jenkins build #482 succeeded: map-service deployed to staging.",
        "Floorplan audit: Unit reconciliation completed for directory kiosk.",
        "Dev-Design sync: Verified component variants for node-id 4173.",
        "Data pipeline: Pre-seed migration completed without schema errors.",
        "Camera UX: Return-to-center & pan clamp merged into sale-tools."
    ]

    /// ข้อความโต้ตอบ / แชท (สำหรับข้อความ Direct หรือ incoming message)
    private let aiAgentDirectResponses = [
        "I've updated the PRD deploy handoff doc and verified the endpoints.",
        "Inspection finished. Found 0 breaking changes in the schema diff.",
        "Cron job scheduled: SFTP watcher running every 15 minutes.",
        "Here is the summary of the latest Mappedin sync flow review.",
        "Refactored auth guard order and added unit tests.",
        "Ready for review: PR #142 consolidated migration script.",
        "CI pipeline #512 passed all integration checks.",
        "Extracted Figma variable tokens and verified with design team."
    ]

    // MARK: - Instagram Disguise (Legacy fallback)
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
                switch s.authorizationStatus {
                case .notDetermined:
                    // ค่าเริ่มต้นในแอปคือเปิดแจ้งเตือน แต่ iOS ยังไม่เคยถาม → ขอสิทธิ์จริงครั้งแรก
                    self.authorized = false
                    if AppSettings.shared.notificationsEnabled {
                        self.requestAuthorization { granted in
                            if !granted { AppSettings.shared.notificationsEnabled = false }
                        }
                    }
                case .denied:
                    // ผู้ใช้ปิดสิทธิ์ใน iOS Settings → ให้สวิตช์ในแอปตรงกับสถานะจริง
                    self.authorized = false
                    AppSettings.shared.notificationsEnabled = false
                default:
                    self.authorized = (s.authorizationStatus == .authorized
                                       || s.authorizationStatus == .provisional
                                       || s.authorizationStatus == .ephemeral)
                }
            }
        }
    }

    /// อัปเดตจำนวนแชทที่ยังไม่ได้ตอบจาก Tinder / Instagram แล้วคำนวณ Badge รวมทันที
    func updateCounts(tinder: Int? = nil, instagram: Int? = nil, appIsActive: Bool = false) {
        let prevTotal = currentTotalCount
        let prevIG = lastIGCount
        if let t = tinder { lastTinderCount = max(0, t) }
        if let ig = instagram { lastIGCount = max(0, ig) }
        let newTotal = currentTotalCount
        NotificationCenter.default.post(name: .unreadCountsChanged, object: nil)

        let settings = AppSettings.shared
        if settings.notificationsEnabled && settings.showIconBadge {
            setIconBadge(newTotal)
        } else {
            setIconBadge(0)
        }

        guard settings.notificationsEnabled, authorized else { return }
        guard !settings.isDecoyActive else { return }
        // ยิงแจ้งเตือนเฉพาะเมื่อยอดรวมแชทที่ค้างอยู่เพิ่มขึ้น
        guard newTotal > prevTotal, newTotal > 0 else { return }
        if appIsActive && !settings.notifyWhileUsing { return }

        // ดูว่าฝั่ง IG เพิ่มขึ้นจริงไหม (ไม่ใช่แค่ส่งค่า IG มาด้วย)
        let isFromIG = lastIGCount > prevIG
        postDisguisedNotification(isDirectMessage: isFromIG)
    }

    func resetLastCount() {
        lastTinderCount = 0
        lastIGCount = 0
        setIconBadge(0)
        NotificationCenter.default.post(name: .unreadCountsChanged, object: nil)
    }

    /// ยิง Notification พรางตัว (AI Agent หรือ Instagram ตามการตั้งค่า)
    func postDisguisedNotification(
        user: String? = nil,
        action: String? = nil,
        isDirectMessage: Bool = false,
        force: Bool = false,
        completion: ((Bool, String) -> Void)? = nil
    ) {
        dlog("[Notification] Attempting to post disguised notification (force=\(force), isDM=\(isDirectMessage))")
        
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let isAuth = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            DispatchQueue.main.async { self.authorized = isAuth }

            guard isAuth else {
                let msg = "ระบบยังไม่ได้รับสิทธิ์แจ้งเตือน (Status: \(settings.authorizationStatus.rawValue))"
                dlog("[Notification] ❌ \(msg)")
                DispatchQueue.main.async { completion?(false, msg) }
                return
            }

            if !force {
                guard AppSettings.shared.notificationsEnabled else {
                    let msg = "การแจ้งเตือนถูกปิดไว้ในแอป (notificationsEnabled=false)"
                    dlog("[Notification] ⚠️ \(msg)")
                    DispatchQueue.main.async { completion?(false, msg) }
                    return
                }
                guard !AppSettings.shared.isDecoyActive else {
                    let msg = "อยู่ในโหมดอำพราง (Decoy) - ไม่ยิง notification"
                    dlog("[Notification] ⚠️ \(msg)")
                    DispatchQueue.main.async { completion?(false, msg) }
                    return
                }
            }

            let style = AppSettings.shared.notificationDisguiseStyle
            let notifTitle: String
            let notifBody: String

            switch style {
            case .aiAgent:
                let sender = user ?? (self.aiAgentSenders.randomElement() ?? "Claude Code")
                if let custom = action, custom != "sent you a direct message." {
                    notifBody = custom
                } else if isDirectMessage || action == "sent you a direct message." {
                    let quote = self.aiAgentDirectResponses.randomElement() ?? "I've verified the endpoints and everything is passing."
                    notifBody = "\"\(quote)\""
                } else {
                    notifBody = self.aiAgentTaskUpdates.randomElement() ?? "Task complete: Scheduler synced successfully."
                }
                notifTitle = sender

            case .instagram:
                let handle = user ?? (self.instagramHandles.randomElement() ?? "alex_m")
                let act = action ?? (self.instagramActions.randomElement() ?? "liked your photo.")
                notifTitle = "Instagram"
                notifBody = "\(handle) \(act)"
            }

            let content = UNMutableNotificationContent()
            content.title = notifTitle
            content.body = notifBody
            content.sound = AppSettings.shared.notificationSound ? .default : nil

            let req = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
            UNUserNotificationCenter.current().add(req) { error in
                if let error = error {
                    let errStr = "เกิดข้อผิดพลาด: \(error.localizedDescription)"
                    dlog("[Notification] \(errStr)")
                    DispatchQueue.main.async { completion?(false, errStr) }
                } else {
                    let successMsg = "\(notifTitle): \(notifBody)"
                    dlog("[Notification] Successfully posted disguised notification: \(successMsg)")
                    DispatchQueue.main.async { completion?(true, successMsg) }
                }
            }
        }
    }

    func setIconBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    func clearAll() {
        resetLastCount()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

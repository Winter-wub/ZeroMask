import BackgroundTasks
import Foundation
import UIKit
import WebKit

final class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()

    let fetchTaskID = "com.prachayawut.gallery.fetchUpdates"

    private let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    enum ServiceType {
        case tinder
        case instagram
        case all
    }

    struct FetchResult {
        let success: Bool
        let httpStatus: Int?
        let likesCount: Int
        let messagesCount: Int
        let detail: String
    }

    @Published var lastTinderCheck: Date?
    @Published var lastTinderStatus: String = "ยังไม่เคยตรวจสอบ"
    @Published var lastIGCheck: Date?
    @Published var lastIGStatus: String = "ยังไม่เคยตรวจสอบ"

    private init() {}

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: fetchTaskID, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: fetchTaskID)
        // iOS minimum is ~15 min but request earliest possible
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BGTask] Successfully scheduled background task: \(fetchTaskID)")
        } catch {
            print("[BGTask] Could not schedule app refresh: \(error)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // 1. นัดหมายรอบถัดไปทันที
        scheduleAppRefresh()

        // 2. ถ้าผู้ใช้อยู่ใน Decoy Mode หรือปิดการแจ้งเตือน ให้จบงานทันที
        guard AppSettings.shared.notificationsEnabled,
              !AppSettings.shared.isDecoyActive else {
            task.setTaskCompleted(success: true)
            return
        }

        // จบงานได้ครั้งเดียว — ถ้า iOS ตัดเวลาก่อน (expiration) ต้องเรียก setTaskCompleted
        // ไม่งั้นแอปโดน kill และ iOS จะให้โควต้า background refresh น้อยลง
        var finished = false
        let finish: (Bool) -> Void = { success in
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                task.setTaskCompleted(success: success)
            }
        }
        task.expirationHandler = { finish(false) }

        let group = DispatchGroup()

        // ตรวจสอบ Tinder ถ้ามี Token
        if let token = KeychainTokenStore.load(for: .tinderAuthToken), !token.isEmpty {
            group.enter()
            fetchTinder { _ in
                group.leave()
            }
        }

        // ตรวจสอบ Instagram ถ้ามี Session
        if let igSession = KeychainTokenStore.load(for: .instagramSessionId), !igSession.isEmpty {
            group.enter()
            fetchInstagram { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) {
            finish(true)
        }
    }

    // MARK: - On-Demand Manual Fetch (สำหรับทดสอบทันทีจาก Settings)

    func fetchUpdatesNow(for service: ServiceType, completion: @escaping (FetchResult) -> Void) {
        switch service {
        case .tinder:
            fetchTinder(completion: completion)
        case .instagram:
            fetchInstagram(completion: completion)
        case .all:
            let group = DispatchGroup()
            var tResult: FetchResult?
            var igResult: FetchResult?

            group.enter()
            fetchTinder { res in
                tResult = res
                group.leave()
            }

            group.enter()
            fetchInstagram { res in
                igResult = res
                group.leave()
            }

            group.notify(queue: .main) {
                let success = (tResult?.success ?? false) || (igResult?.success ?? false)
                let combinedLikes = (tResult?.likesCount ?? 0)
                let combinedMsg = (tResult?.messagesCount ?? 0) + (igResult?.messagesCount ?? 0)
                let detail = "Tinder: \(tResult?.detail ?? "-")\nInstagram: \(igResult?.detail ?? "-")"
                completion(FetchResult(
                    success: success,
                    httpStatus: tResult?.httpStatus ?? igResult?.httpStatus,
                    likesCount: combinedLikes,
                    messagesCount: combinedMsg,
                    detail: detail
                ))
            }
        }
    }

    // MARK: - Tinder Live Fetch

    func fetchTinder(completion: @escaping (FetchResult) -> Void) {
        guard let token = KeychainTokenStore.load(for: .tinderAuthToken), !token.isEmpty else {
            let res = FetchResult(success: false, httpStatus: nil, likesCount: 0, messagesCount: 0,
                                  detail: "ไม่พบ Tinder Auth Token (กรุณาเปิดแอปและเลื่อนหน้า Tinder เพื่อดึง Token อัตโนมัติ)")
            DispatchQueue.main.async {
                self.lastTinderStatus = res.detail
                self.lastTinderCheck = Date()
            }
            completion(res)
            return
        }

        // เช็ค Endpoint 1: Fast Match Count (ยอดคนกด Like เรา)
        guard let fastMatchURL = URL(string: "https://api.gotinder.com/v2/fast-match/count") else {
            completion(FetchResult(success: false, httpStatus: nil, likesCount: 0, messagesCount: 0, detail: "URL ไม่ถูกต้อง"))
            return
        }

        var req1 = URLRequest(url: fastMatchURL)
        req1.httpMethod = "GET"
        req1.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        req1.setValue("application/json", forHTTPHeaderField: "Accept")
        req1.setValue(safariUA, forHTTPHeaderField: "User-Agent")
        req1.setValue("web", forHTTPHeaderField: "platform")
        req1.timeoutInterval = 10

        URLSession.shared.dataTask(with: req1) { data1, resp1, _ in
            let httpCode = (resp1 as? HTTPURLResponse)?.statusCode
            var likesCount = 0

            if httpCode == 200, let data = data1 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any],
                   let c = dataObj["count"] as? Int {
                    likesCount = c
                }
            } else if httpCode == 401 {
                let res = FetchResult(success: false, httpStatus: 401, likesCount: 0, messagesCount: 0,
                                      detail: "Token หมดอายุ (401 Unauthorized) กรุณาเปิดหน้า Tinder ในแอปเพื่อต่อเซสชันใหม่")
                DispatchQueue.main.async {
                    self.lastTinderStatus = res.detail
                    self.lastTinderCheck = Date()
                }
                completion(res)
                return
            }

            // เช็ค Endpoint 2: Updates (ข้อความและแมตช์ใหม่)
            guard let updatesURL = URL(string: "https://api.gotinder.com/v2/updates?is_background=1") else {
                let res = FetchResult(success: httpCode == 200, httpStatus: httpCode, likesCount: likesCount, messagesCount: 0,
                                      detail: "สำเร็จ (Likes: \(likesCount))")
                DispatchQueue.main.async {
                    self.lastTinderStatus = res.detail
                    self.lastTinderCheck = Date()
                }
                completion(res)
                return
            }

            var req2 = URLRequest(url: updatesURL)
            req2.httpMethod = "POST"
            req2.setValue(token, forHTTPHeaderField: "X-Auth-Token")
            req2.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req2.setValue("application/json", forHTTPHeaderField: "Accept")
            req2.setValue(self.safariUA, forHTTPHeaderField: "User-Agent")
            req2.setValue("web", forHTTPHeaderField: "platform")
            req2.httpBody = try? JSONSerialization.data(withJSONObject: ["nudge": true])
            req2.timeoutInterval = 10

            URLSession.shared.dataTask(with: req2) { data2, resp2, _ in
                let updatesCode = (resp2 as? HTTPURLResponse)?.statusCode ?? httpCode
                var unreadChats = 0

                if updatesCode == 200, let data = data2 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let matches = json["matches"] as? [[String: Any]] {
                            for m in matches {
                                let hasUnseen = (m["has_unseen_message"] as? Bool) ?? false
                                let isNew = (m["is_new_message"] as? Bool) ?? false
                                if hasUnseen || isNew {
                                    unreadChats += 1
                                } else if let messages = m["messages"] as? [[String: Any]], !messages.isEmpty {
                                    if let lastMsg = messages.last {
                                        let lastMsgId = lastMsg["_id"] as? String
                                        if let seen = m["seen"] as? [String: Any] {
                                            let lastSeenId = seen["last_seen_msg_id"] as? String
                                            if lastMsgId != nil && lastMsgId != lastSeenId {
                                                unreadChats += 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    NotificationManager.shared.updateCounts(tinder: unreadChats)
                    let detailMsg = "สำเร็จ (\(updatesCode ?? 200) OK) - แชทที่ยังไม่ได้อ่าน: \(unreadChats) รายการ (คนกด Like: \(likesCount))"
                    self.lastTinderStatus = detailMsg
                    self.lastTinderCheck = Date()
                    completion(FetchResult(success: true, httpStatus: updatesCode, likesCount: likesCount, messagesCount: unreadChats, detail: detailMsg))
                }
            }.resume()
        }.resume()
    }

    // MARK: - Instagram Live Fetch

    func fetchInstagram(completion: @escaping (FetchResult) -> Void) {
        // อ่าน cookie สดจาก WKHTTPCookieStore ทุกครั้ง (sessionid เป็น HttpOnly และอาจถูกหมุนใหม่)
        DispatchQueue.main.async {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let igCookies = cookies.filter { $0.domain.contains("instagram.com") && !$0.value.isEmpty }
                for c in igCookies {
                    if c.name == "sessionid" {
                        KeychainTokenStore.save(c.value, for: .instagramSessionId)
                    } else if c.name == "ds_user_id" {
                        KeychainTokenStore.save(c.value, for: .instagramUserId)
                    } else if c.name == "csrftoken" {
                        KeychainTokenStore.save(c.value, for: .instagramCsrfToken)
                    }
                }
                self.performFetchInstagram(cookies: igCookies, completion: completion)
            }
        }
    }

    private func performFetchInstagram(cookies: [HTTPCookie], completion: @escaping (FetchResult) -> Void) {
        guard let sessionId = KeychainTokenStore.load(for: .instagramSessionId), !sessionId.isEmpty else {
            let res = FetchResult(success: false, httpStatus: nil, likesCount: 0, messagesCount: 0,
                                  detail: "ไม่พบเซสชัน Instagram (กรุณากดปุ่ม 📸 เข้าสู่ระบบ Instagram ก่อน)")
            DispatchQueue.main.async {
                self.lastIGStatus = res.detail
                self.lastIGCheck = Date()
            }
            completion(res)
            return
        }

        let userId = KeychainTokenStore.load(for: .instagramUserId) ?? ""
        let csrf = KeychainTokenStore.load(for: .instagramCsrfToken) ?? ""

        guard let url = URL(string: "https://www.instagram.com/api/v1/direct_v2/inbox/?persistentBadging=true") else {
            completion(FetchResult(success: false, httpStatus: nil, likesCount: 0, messagesCount: 0, detail: "URL ไม่ถูกต้อง"))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        // ส่ง cookie ทั้งชุดเหมือน browser จริง (IG มักเด้งไป login/checkpoint ถ้ามีแค่ sessionid)
        var cookieHeader: String
        if !cookies.isEmpty {
            cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        } else {
            cookieHeader = "sessionid=\(sessionId)"
            if !userId.isEmpty { cookieHeader += "; ds_user_id=\(userId)" }
            if !csrf.isEmpty { cookieHeader += "; csrftoken=\(csrf)" }
        }
        req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        if !csrf.isEmpty { req.setValue(csrf, forHTTPHeaderField: "X-CSRFToken") }
        req.setValue("https://www.instagram.com/direct/inbox/", forHTTPHeaderField: "Referer")
        req.setValue("936619743392459", forHTTPHeaderField: "X-IG-App-ID")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(safariUA, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { data, response, _ in
            guard let httpResponse = response as? HTTPURLResponse else {
                let res = FetchResult(success: false, httpStatus: nil, likesCount: 0, messagesCount: 0, detail: "การเชื่อมต่อล้มเหลว")
                DispatchQueue.main.async {
                    self.lastIGStatus = res.detail
                    self.lastIGCheck = Date()
                }
                completion(res)
                return
            }

            if httpResponse.statusCode == 200, let data = data {
                // URLSession ตาม redirect เอง → ถ้าเซสชันหลุดจะได้ 200 เป็นหน้า HTML login แทน 302
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let inbox = json["inbox"] as? [String: Any],
                      let unreadDMs = inbox["unseen_count"] as? Int else {
                    let detailMsg = "ได้ 200 แต่ไม่ใช่ข้อมูล inbox (น่าจะโดนเด้งไปหน้า login/checkpoint) กรุณากดปุ่ม 📸 เข้าสู่ระบบใหม่"
                    print("[IG] ❌ \(detailMsg)")
                    DispatchQueue.main.async {
                        self.lastIGStatus = detailMsg
                        self.lastIGCheck = Date()
                    }
                    completion(FetchResult(success: false, httpStatus: 200, likesCount: 0, messagesCount: 0, detail: detailMsg))
                    return
                }

                DispatchQueue.main.async {
                    NotificationManager.shared.updateCounts(instagram: unreadDMs)
                    let detailMsg = "สำเร็จ (200 OK) - ข้อความ Direct ที่ยังไม่ได้อ่าน: \(unreadDMs) ข้อความ"
                    print("[IG] ✅ \(detailMsg)")
                    self.lastIGStatus = detailMsg
                    self.lastIGCheck = Date()
                    completion(FetchResult(success: true, httpStatus: 200, likesCount: 0, messagesCount: unreadDMs, detail: detailMsg))
                }
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 302 {
                let detailMsg = "เซสชันหมดอายุ (\(httpResponse.statusCode)) กรุณากดปุ่ม 📸 เข้าสู่ระบบใหม่อีกครั้ง"
                print("[IG] ❌ \(detailMsg)")
                DispatchQueue.main.async {
                    self.lastIGStatus = detailMsg
                    self.lastIGCheck = Date()
                }
                completion(FetchResult(success: false, httpStatus: httpResponse.statusCode, likesCount: 0, messagesCount: 0, detail: detailMsg))
            } else {
                let detailMsg = "HTTP Status: \(httpResponse.statusCode)"
                DispatchQueue.main.async {
                    self.lastIGStatus = detailMsg
                    self.lastIGCheck = Date()
                }
                completion(FetchResult(success: false, httpStatus: httpResponse.statusCode, likesCount: 0, messagesCount: 0, detail: detailMsg))
            }
        }.resume()
    }
}

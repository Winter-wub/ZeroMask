import SwiftUI
import WebKit
import UIKit

// สถานะกลางของแอป: webview, ชื่อบนหัวโพสต์, แอนิเมชัน
final class MaskModel: NSObject, ObservableObject {
    @Published var username = "…"
    @Published var heartBurst = false
    @Published var slideAway = false
    @Published var popupWebView: WKWebView?
    @Published var isInChat = false          // โหมดแชทเต็มจอ (Seamless Chat)
    @Published var isExplore = false         // โหมดสำรวจเต็มจอ (Seamless Explore)
    @Published var dropletBurst = false      // เอฟเฟกต์หยดน้ำกระจายของ Liquid Glass
    @Published var badgeCount = 0            // เลขแจ้งเตือนจริงจาก Tinder
    @Published var tinderUnread = 0          // แชท Tinder ยังไม่อ่าน (โชว์บนปุ่มกลับ Tinder)
    @Published var igUnread = 0              // DM IG ยังไม่อ่าน (โชว์บนปุ่มสลับไป IG)
    @Published var showRealInstagram = false // โหมด decoy: โชว์ instagram.com จริง

    let recsURL = URL(string: "https://tinder.com/app/recs")!
    private(set) var webView: WKWebView!
    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private var igTitleObservation: NSKeyValueObservation?

    // เลขแจ้งเตือนแยกฝั่ง แล้วรวมเป็น badgeCount เดียว
    // Tinder มี 2 แหล่งแยกช่องกัน: DOM badge (หลัก) กับ /updates ที่ดักจาก network
    // /updates บนเว็บเป็น delta มักได้ 0 → ห้ามเขียนทับ DOM ให้ใช้ค่าที่มากกว่าแทน
    private var tinderDOMCount = 0
    private var tinderAPICount = 0
    private var tinderCount: Int { max(tinderDOMCount, tinderAPICount) }
    private var igCount = 0

    @Published var isTinderLoading = false  // สถานะกำลังโหลด Tinder
    @Published var isIGLoading = false      // สถานะกำลังโหลด Instagram

    // webview แยกสำหรับ Instagram จริง (สร้างเมื่อใช้ครั้งแรก, session แยกจำไว้)
    private(set) lazy var igWebView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()

        // ฉีดสคริปต์ตรวจจับ Instagram (Cookies, Unread DMs, DOM Badges)
        let igScript = WKUserScript(source: MaskScripts.instagramScript,
                                    injectionTime: .atDocumentEnd,
                                    forMainFrameOnly: false)
        config.userContentController.addUserScript(igScript)
        config.userContentController.add(self, name: "maskIG")

        // ฉีดสคริปต์อำพรางหน้าต่างแชทเป็น ChatGPT 4o
        let chatGPTScript = WKUserScript(source: MaskScripts.chatGPTDirectScript,
                                         injectionTime: .atDocumentEnd,
                                         forMainFrameOnly: false)
        config.userContentController.addUserScript(chatGPTScript)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = safariUA
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        if #available(iOS 16.4, *) {
            wv.isInspectable = true
        }
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleIGRefresh(_:)), for: .valueChanged)
        wv.scrollView.refreshControl = refreshControl
        return wv
    }()

    func syncInstagramCookies(completion: ((Bool) -> Void)? = nil) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            var foundSession = false
            for c in cookies where c.domain.contains("instagram.com") {
                if c.name == "sessionid" && !c.value.isEmpty {
                    KeychainTokenStore.save(c.value, for: .instagramSessionId)
                    foundSession = true
                    print("[IG Cookie] Found HttpOnly sessionid: \(c.value.prefix(8))...")
                }
                if c.name == "ds_user_id" && !c.value.isEmpty {
                    KeychainTokenStore.save(c.value, for: .instagramUserId)
                    print("[IG Cookie] Found ds_user_id: \(c.value)")
                }
                if c.name == "csrftoken" && !c.value.isEmpty {
                    KeychainTokenStore.save(c.value, for: .instagramCsrfToken)
                }
            }
            DispatchQueue.main.async {
                completion?(foundSession)
            }
        }
    }

    @objc private func handleIGRefresh(_ sender: UIRefreshControl) {
        reloadInstagram()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sender.endRefreshing()
        }
    }

    // ดึงเลขในวงเล็บหน้า title เช่น "(4) Tinder" → 4
    private static func countInTitle(_ title: String?) -> Int {
        guard let title, let m = title.range(of: #"^\((\d+)\)"#, options: .regularExpression)
        else { return 0 }
        return Int(title[m].dropFirst().dropLast()) ?? 0
    }

    // รวมเลข 2 ฝั่ง → อัปเดต badge + ยิงแจ้งเตือน
    private func recomputeBadge(source: String? = nil) {
        let active = UIApplication.shared.applicationState == .active
        if source == "Tinder" {
            NotificationManager.shared.updateCounts(tinder: tinderCount, appIsActive: active)
        } else if source == "Instagram" {
            NotificationManager.shared.updateCounts(instagram: igCount, appIsActive: active)
        } else {
            NotificationManager.shared.updateCounts(tinder: tinderCount, instagram: igCount, appIsActive: active)
        }
        syncUnreadCounts()
    }

    // ดึงยอดล่าสุดจาก NotificationManager (รวมผลจาก background fetch ด้วย)
    @objc private func syncUnreadCounts() {
        let mgr = NotificationManager.shared
        badgeCount = mgr.currentTotalCount
        tinderUnread = mgr.tinderUnreadCount
        igUnread = mgr.igUnreadCount
    }

    // UA ของ Safari บน iPhone จริง — ให้ Tinder เสิร์ฟเว็บปกติ + login Google ไม่โดนบล็อก
    private let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default() // จำ session/login ไว้

        // 1. ดักจับ Network ที่ document start เพื่อดึง Auth Token ทันที
        let interceptorScript = WKUserScript(source: MaskScripts.networkInterceptorScript,
                                             injectionTime: .atDocumentStart,
                                             forMainFrameOnly: false)
        config.userContentController.addUserScript(interceptorScript)

        // 2. ปรับแต่ง DOM / Gesture ที่ document end
        let script = WKUserScript(source: MaskScripts.userScript,
                                  injectionTime: .atDocumentEnd,
                                  forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: "mask")

        syncUnreadCounts()
        NotificationCenter.default.addObserver(self, selector: #selector(syncUnreadCounts),
                                               name: .unreadCountsChanged, object: nil)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = safariUA
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.load(URLRequest(url: recsURL))

        // ตรวจสอบ URL เพื่อปรับเข้าสู่โหมดแชทเต็มจอ (Seamless Chat) หรือโหมดสำรวจ (Seamless Explore)
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            guard let self, let path = wv.url?.path else { return }
            DispatchQueue.main.async {
                if path.contains("/matches") || path.contains("/messages") {
                    if !self.isInChat { self.isInChat = true }
                    if self.isExplore { self.isExplore = false }
                } else if path.contains("/explore") {
                    if self.isInChat { self.isInChat = false }
                    if !self.isExplore { self.isExplore = true }
                } else if path.contains("/recs") {
                    if self.isInChat { self.isInChat = false }
                    if self.isExplore { self.isExplore = false }
                }
            }
        }

        // ซิงค์คุกกี้ Instagram ทันทีและเป็นระยะเพื่อดักจับ HttpOnly sessionid
        syncInstagramCookies()
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.syncInstagramCookies()
        }
    }

    // ── โหมด decoy: สลับไป Instagram จริง ──
    func toggleRealInstagram() {
        if !showRealInstagram && igWebView.url == nil {
            igWebView.load(URLRequest(url: URL(string: "https://www.instagram.com/direct/inbox/")!))
        }
        syncInstagramCookies()
        showRealInstagram.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateIGTheme()
        }
    }

    func openInstagramDirect() {
        let directURL = URL(string: "https://www.instagram.com/direct/inbox/")!
        if igWebView.url == nil {
            igWebView.load(URLRequest(url: directURL))
        } else if let current = igWebView.url?.absoluteString, !current.contains("/direct") && !current.contains("/accounts") {
            igWebView.load(URLRequest(url: directURL))
        }
        updateIGTheme()
    }

    func updateIGTheme() {
        let shouldDisguise = (AppSettings.shared.disguiseMode == .chatGPT && !showRealInstagram)
        let js = "if (window.__mask_toggle_chatgpt) { window.__mask_toggle_chatgpt(\(shouldDisguise ? "true" : "false")); }"
        igWebView.evaluateJavaScript(js, completionHandler: nil)
    }

    // ── รีเฟรชหน้าเว็บ ──
    func reloadTinder() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if webView.url != nil {
            webView.reload()
        } else {
            webView.load(URLRequest(url: recsURL))
        }
    }

    func reloadInstagram() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if igWebView.url != nil {
            igWebView.reload()
        } else {
            igWebView.load(URLRequest(url: URL(string: "https://www.instagram.com/direct/inbox/")!))
        }
    }

    // ── แอ็กชันหลัก (1 กดของผู้ใช้ = 1 คลิกปุ่มจริงของ Tinder) ──
    func like(withBurst: Bool = true) {
        if withBurst { burst() }
        webView.evaluateJavaScript(MaskScripts.clickGamepad("Like"))
    }

    func collect() {
        dropletBurst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { self.dropletBurst = false }
        webView.evaluateJavaScript(MaskScripts.clickGamepad("Like"))
    }

    func pass() {
        withAnimation(.easeIn(duration: 0.3)) { slideAway = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.slideAway = false
        }
        webView.evaluateJavaScript(MaskScripts.clickGamepad("Nope"))
    }

    func superLike() {
        burst()
        webView.evaluateJavaScript(MaskScripts.clickGamepad("Super Like"))
    }

    func openExplore() {
        isInChat = false
        isExplore = true
        go("explore")
    }

    func openChat() {
        isExplore = false
        isInChat = true
        go("matches")
    }

    func backToFeed() {
        isInChat = false
        isExplore = false
        if let path = webView.url?.path, !path.contains("/recs") {
            webView.evaluateJavaScript("window.history.back()") { [weak self] _, error in
                if error != nil {
                    self?.go("recs")
                }
            }
        }
    }

    func go(_ page: String) {
        if let url = URL(string: "https://tinder.com/app/\(page)") {
            webView.load(URLRequest(url: url))
        }
    }

    // ล้าง cookie/session ทั้งหมด แล้วโหลด Tinder ใหม่ (= ออกจากระบบ)
    func logout() {
        KeychainTokenStore.clearAll()
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) { [weak self] in
                guard let self else { return }
                self.username = "…"
                self.webView.load(URLRequest(url: self.recsURL))
            }
        }
    }

    private func burst() {
        heartBurst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.heartBurst = false }
    }
}

// ── รับ event จาก JS ที่ฉีดเข้า Tinder และ Instagram ──
extension MaskModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "mask",
           let body = message.body as? [String: Any],
           let type = body["type"] as? String {
            switch type {
            case "double-tap":
                if AppSettings.shared.doubleTapLike { like() }
            case "scroll-next":
                if AppSettings.shared.swipeToPass { pass() }
            case "profile":
                if let name = body["payload"] as? String, !name.isEmpty { username = name }
            case "auth-token":
                if let token = body["payload"] as? String, !token.isEmpty {
                    print("[Auth] Captured live Tinder Auth Token: \(token.prefix(10))...")
                    KeychainTokenStore.save(token, for: .tinderAuthToken)
                }
            case "api-endpoint":
                if let endpoint = body["payload"] as? String, !endpoint.isEmpty {
                    print("[Auth] Captured live Tinder API endpoint: \(endpoint)")
                    KeychainTokenStore.save(endpoint, for: .tinderUpdatesEndpoint)
                }
            case "dom-badge":
                if let count = body["payload"] as? Int {
                    DispatchQueue.main.async {
                        guard self.tinderDOMCount != count else { return }
                        let before = self.tinderCount
                        self.tinderDOMCount = count
                        if self.tinderCount != before { self.recomputeBadge(source: "Tinder") }
                    }
                }
            case "api-data":
                if let payload = body["payload"] as? [String: Any],
                   let url = payload["url"] as? String,
                   let data = payload["data"] as? [String: Any] {
                    self.handleTinderAPIData(url: url, data: data)
                }
            default: break
            }
        } else if message.name == "maskIG",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String {
            switch type {
            case "ig-session":
                if let payload = body["payload"] as? [String: Any] {
                    if let sid = payload["sessionId"] as? String, !sid.isEmpty {
                        KeychainTokenStore.save(sid, for: .instagramSessionId)
                    }
                    if let uid = payload["userId"] as? String, !uid.isEmpty {
                        KeychainTokenStore.save(uid, for: .instagramUserId)
                    }
                    if let csrf = payload["csrfToken"] as? String, !csrf.isEmpty {
                        KeychainTokenStore.save(csrf, for: .instagramCsrfToken)
                    }
                    print("[IG] Captured live Instagram session cookies")
                }
            case "ig-badge":
                if let count = body["payload"] as? Int {
                    DispatchQueue.main.async {
                        guard self.igCount != count else { return }
                        self.igCount = count
                        self.recomputeBadge(source: "Instagram")
                    }
                }
            case "ig-api-data":
                if let payload = body["payload"] as? [String: Any],
                   let url = payload["url"] as? String,
                   let data = payload["data"] as? [String: Any] {
                    self.handleInstagramAPIData(url: url, data: data)
                }
            default: break
            }
        }
    }

    private func handleTinderAPIData(url: String, data: [String: Any]) {
        var unreadChats = 0
        if url.contains("/updates") || url.contains("/matches") {
            if let matches = data["matches"] as? [[String: Any]] {
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
            DispatchQueue.main.async {
                guard self.tinderAPICount != unreadChats else { return }
                let before = self.tinderCount
                self.tinderAPICount = unreadChats
                if self.tinderCount != before { self.recomputeBadge(source: "Tinder") }
            }
        }
    }

    private func handleInstagramAPIData(url: String, data: [String: Any]) {
        // นับเฉพาะข้อความ Direct ที่ยังไม่ได้อ่าน (ไม่นับ Activity / ไลค์รูป / การแจ้งเตือนทั่วไป)
        if url.contains("/direct_v2/inbox/") {
            var unseen = 0
            if let inbox = data["inbox"] as? [String: Any],
               let u = inbox["unseen_count"] as? Int {
                unseen = u
            }

            DispatchQueue.main.async {
                guard self.igCount != unseen else { return }
                self.igCount = unseen
                self.recomputeBadge(source: "Instagram")
            }
        }
    }
}

// ── ติดตามการโหลดหน้าเว็บของ Tinder และ Instagram เพื่ออัปเดตสถานะและดึงคุกกี้ ──
extension MaskModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            if webView === self.igWebView {
                self.isIGLoading = true
            } else {
                self.isTinderLoading = true
            }
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if webView === self.igWebView {
            self.updateIGTheme()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            if webView === self.igWebView {
                self.isIGLoading = false
                self.syncInstagramCookies()
                self.updateIGTheme()
            } else {
                self.isTinderLoading = false
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            if webView === self.igWebView {
                self.isIGLoading = false
            } else {
                self.isTinderLoading = false
            }
        }
        print("[WebView Error] didFail: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            if webView === self.igWebView {
                self.isIGLoading = false
            } else {
                self.isTinderLoading = false
            }
        }
        print("[WebView Error] didFailProvisional: \(error.localizedDescription)")
    }
}

// ── popup (login Google/Facebook เปิดหน้าต่างใหม่) + จัดการสิทธิ์ Geolocation ──
extension MaskModel: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.customUserAgent = safariUA
        popup.uiDelegate = self
        popupWebView = popup
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView === popupWebView { popupWebView = nil }
    }

    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // อนุญาตสิทธิ์ตำแหน่งสำหรับ Tinder เพื่อให้โหลดการ์ดโปรไฟล์รอบตัวได้ทันที
        decisionHandler(.grant)
    }
}

// ── ห่อ WKWebView ให้ SwiftUI ใช้ พร้อม AutoLayout Container ป้องกันจอดำระหว่างสลับหน้า (Reparenting fix) ──
struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        attach(webView: webView, to: container)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        attach(webView: webView, to: uiView)
    }

    private func attach(webView: WKWebView, to container: UIView) {
        if webView.superview !== container {
            webView.removeFromSuperview()
            webView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: container.topAnchor),
                webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
            container.setNeedsLayout()
            container.layoutIfNeeded()
        }
    }
}

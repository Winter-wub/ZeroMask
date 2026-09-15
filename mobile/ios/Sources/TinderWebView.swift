import SwiftUI
import WebKit
import UIKit

// สถานะกลางของแอป: webview, ชื่อบนหัวโพสต์, แอนิเมชัน
final class MaskModel: NSObject, ObservableObject {
    @Published var username = "…"
    @Published var heartBurst = false
    @Published var slideAway = false
    @Published var popupWebView: WKWebView?
    @Published var badgeCount = 0            // เลขแจ้งเตือนจริงจาก Tinder
    @Published var showRealInstagram = false // โหมด decoy: โชว์ instagram.com จริง

    let recsURL = URL(string: "https://tinder.com/app/recs")!
    private(set) var webView: WKWebView!
    private var titleObservation: NSKeyValueObservation?
    private var igTitleObservation: NSKeyValueObservation?

    // เลขแจ้งเตือนแยกฝั่ง แล้วรวมเป็น badgeCount เดียว
    private var tinderCount = 0
    private var igCount = 0

    // webview แยกสำหรับ Instagram จริง (สร้างเมื่อใช้ครั้งแรก, session แยกจำไว้)
    private(set) lazy var igWebView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = safariUA
        wv.allowsBackForwardNavigationGestures = true
        // Instagram web ก็ใส่เลขไว้ใน title เช่น "(3) Instagram" → นับรวมด้วย
        igTitleObservation = wv.observe(\.title, options: [.new]) { [weak self] w, _ in
            let c = Self.countInTitle(w.title)
            DispatchQueue.main.async {
                guard let self, self.igCount != c else { return }
                self.igCount = c
                self.recomputeBadge()
            }
        }
        return wv
    }()

    // ดึงเลขในวงเล็บหน้า title เช่น "(4) Tinder" → 4
    private static func countInTitle(_ title: String?) -> Int {
        guard let title, let m = title.range(of: #"^\((\d+)\)"#, options: .regularExpression)
        else { return 0 }
        return Int(title[m].dropFirst().dropLast()) ?? 0
    }

    // รวมเลข 2 ฝั่ง → อัปเดต badge + ยิงแจ้งเตือน
    private func recomputeBadge() {
        let total = tinderCount + igCount
        guard badgeCount != total else { return }
        badgeCount = total
        let active = UIApplication.shared.applicationState == .active
        NotificationManager.shared.handleBadgeChange(to: total, appIsActive: active)
    }

    // UA ของ Safari บน iPhone จริง — ให้ Tinder เสิร์ฟเว็บปกติ + login Google ไม่โดนบล็อก
    private let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default() // จำ session/login ไว้

        let script = WKUserScript(source: MaskScripts.userScript,
                                  injectionTime: .atDocumentEnd,
                                  forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: "mask")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = safariUA
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: recsURL))

        // Tinder ใส่เลขแจ้งเตือนไว้ใน title เช่น "(4) Tinder" → นับรวมกับ IG
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            let c = Self.countInTitle(wv.title)
            DispatchQueue.main.async {
                guard let self, self.tinderCount != c else { return }
                self.tinderCount = c
                self.recomputeBadge()
            }
        }
    }

    // ── โหมด decoy: สลับไป Instagram จริง ──
    func toggleRealInstagram() {
        if !showRealInstagram, igWebView.url == nil {
            igWebView.load(URLRequest(url: URL(string: "https://www.instagram.com/")!))
        }
        showRealInstagram.toggle()
    }

    // ── แอ็กชันหลัก (1 กดของผู้ใช้ = 1 คลิกปุ่มจริงของ Tinder) ──
    func like(withBurst: Bool = true) {
        if withBurst { burst() }
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

    func go(_ page: String) {
        if let url = URL(string: "https://tinder.com/app/\(page)") {
            webView.load(URLRequest(url: url))
        }
    }

    // ล้าง cookie/session ทั้งหมด แล้วโหลด Tinder ใหม่ (= ออกจากระบบ)
    func logout() {
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

// ── รับ event จาก JS ที่ฉีดเข้า Tinder ──
extension MaskModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "mask",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        switch type {
        case "double-tap":
            if AppSettings.shared.doubleTapLike { like() }
        case "scroll-next":
            if AppSettings.shared.swipeToPass { pass() }
        case "profile":
            if let name = body["payload"] as? String, !name.isEmpty { username = name }
        default: break
        }
    }
}

// ── popup (login Google/Facebook เปิดหน้าต่างใหม่) → โชว์เป็น sheet ──
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
}

// ── ห่อ WKWebView ให้ SwiftUI ใช้ ──
struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

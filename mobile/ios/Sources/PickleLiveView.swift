import SwiftUI
import WebKit

// โหมด "PIN สำรอง": เปิดเว็บ PickleWatch ตัวจริงเต็มจอ — ไม่มีร่องรอยของแอปข้างใน
// ใครบังคับให้เปิดแอป ใส่ PIN ชุดนี้แล้วจะเห็นแค่เว็บถ่ายทอดสดพิกเกิลบอลจริง ๆ
struct PickleLiveView: View {
    var onExit: () -> Void   // ทางออกลับ → กลับไปหน้าล็อก (ใส่ PIN หลักใหม่)

    @StateObject private var model = PickleLiveModel()
    @State private var secretTaps = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground).ignoresSafeArea()

            WebViewRepresentable(webView: model.webView)
                .ignoresSafeArea(edges: .bottom)

            // ทางออกลับ: แตะมุมซ้ายบน 5 ครั้งรวดเร็ว (พื้นที่ใส มองไม่เห็น)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: 64, height: 64)
                .onTapGesture { secretTap() }
        }
        .onAppear { model.loadIfNeeded() }
    }

    private func secretTap() {
        secretTaps += 1
        guard secretTaps >= 5 else {
            // รีเซ็ตถ้าแตะไม่ต่อเนื่อง กันหลุดโหมดโดยบังเอิญ
            let mark = secretTaps
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if secretTaps == mark { secretTaps = 0 }
            }
            return
        }
        secretTaps = 0
        onExit()
    }
}

// webview แยกของโหมด PickleWatch — session แยก ไม่ปนกับ Tinder/Instagram
final class PickleLiveModel: ObservableObject {
    private let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = safariUA
        webView.allowsBackForwardNavigationGestures = true
    }

    func loadIfNeeded() {
        guard webView.url == nil,
              let url = AppSettings.shared.pickleLiveResolvedURL else { return }
        webView.load(URLRequest(url: url))
    }
}

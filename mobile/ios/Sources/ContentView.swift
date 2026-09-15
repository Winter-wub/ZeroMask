import SwiftUI
import WebKit

// เปลือก Instagram ครอบ Tinder — พอร์ตจาก src/shell.html ของเวอร์ชัน desktop
struct ContentView: View {
    @StateObject private var model = MaskModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var showSettings = false

    // สีปรับตามธีมสว่าง/มืดอัตโนมัติ
    private let igBorder = Color(.separator)
    private let igText = Color(.label)
    private let igBg = Color(.systemBackground)
    private let igGradient = LinearGradient(
        colors: [Color(red: 0.94, green: 0.58, blue: 0.20),
                 Color(red: 0.86, green: 0.15, blue: 0.26),
                 Color(red: 0.74, green: 0.09, blue: 0.53)],
        startPoint: .bottomLeading, endPoint: .topTrailing)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider().overlay(igBorder)
                postHead
                Divider().overlay(igBorder)
                media
                Divider().overlay(igBorder)
                if settings.showActionRow {
                    actionRow
                    Divider().overlay(igBorder)
                }
                bottomNav
            }

            // โหมด decoy: Instagram จริงเต็มจอ ทับเปลือก Tinder ไว้ (Tinder ยังค้างอยู่ข้างหลัง)
            if model.showRealInstagram {
                realInstagram
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.showRealInstagram)
        .background(igBg)
        // สำคัญ: อย่าให้ SwiftUI หลบ keyboard เอง — ไม่งั้น WKWebView โดน re-layout
        // ตอน keyboard เด้งขึ้น แล้วช่องพิมพ์หลุด focus → keyboard ปิดทันที
        // (WKWebView ปรับ content inset ตอน keyboard ขึ้นเองอยู่แล้ว)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showSettings) {
            SettingsView(onLogout: { model.logout() })
        }
        .sheet(isPresented: Binding(
            get: { model.popupWebView != nil },
            set: { if !$0 { model.popupWebView = nil } }
        )) {
            if let popup = model.popupWebView {
                WebViewRepresentable(webView: popup)
            }
        }
    }

    // ── แถบบน ──
    private var header: some View {
        HStack {
            BrandMark(size: 22)
            Spacer()
            HStack(spacing: 20) {
                Button { model.go("recs") } label: {
                    Image(systemName: "heart").font(.system(size: 22))
                }
                Button { model.go("matches") } label: {
                    Image(systemName: "bubble.right").font(.system(size: 21))
                        .igBadge(model.badgeCount)   // เลขแจ้งเตือนจริงจาก Tinder
                }
            }
            .foregroundColor(igText)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    // ── Instagram จริง (decoy) + ปุ่มลอยลากได้สำหรับกลับ ──
    private var realInstagram: some View {
        GeometryReader { geo in
            ZStack {
                WebViewRepresentable(webView: model.igWebView)
                    .background(igBg)
                DraggableFloatingButton(bounds: geo.size) {
                    model.toggleRealInstagram()
                }
            }
        }
    }

    // ── หัวโพสต์: avatar + ชื่อจากการ์ด Tinder ──
    private var postHead: some View {
        HStack(spacing: 10) {
            Circle().fill(igGradient).frame(width: 30, height: 30)
            Text(model.username)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(igText)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "ellipsis").foregroundColor(igText)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }

    // ── ตัวรูป (webview Tinder) + หัวใจเด้ง ──
    private var media: some View {
        ZStack {
            WebViewRepresentable(webView: model.webView)
                .offset(y: model.slideAway ? -40 : 0)
                .opacity(model.slideAway ? 0 : 1)
            if model.heartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 96))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 2)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipped()
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: model.heartBurst)
    }

    // ── แถวปุ่มใต้โพสต์: ❤️ Like / 💬 แชท / ✈️ Super Like / 🔖 ข้าม ──
    private var actionRow: some View {
        HStack(spacing: 18) {
            Button { model.like() } label: {
                Image(systemName: "heart").font(.system(size: 24))
            }
            Button { model.go("matches") } label: {
                Image(systemName: "bubble.right").font(.system(size: 23))
            }
            Button { model.superLike() } label: {
                Image(systemName: "paperplane").font(.system(size: 23))
            }
            Spacer()
            Button { model.pass() } label: {
                Image(systemName: "bookmark").font(.system(size: 23))
            }
        }
        .foregroundColor(igText)
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    // ── แถบล่าง 5 ปุ่มแบบ IG → ครบทุกหน้า Tinder ──
    private var bottomNav: some View {
        HStack {
            Spacer()
            Button { model.go("recs") } label: {
                Image(systemName: "house").font(.system(size: 24))
            }
            Spacer()
            Button { model.go("explore") } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 24))
            }
            Spacer()
            // ปุ่มสลับไป Instagram จริง (decoy)
            Button { model.toggleRealInstagram() } label: {
                Image(systemName: "play.rectangle").font(.system(size: 24))
            }
            Spacer()
            Button { model.go("gold-home") } label: {
                Image(systemName: "heart").font(.system(size: 24))
            }
            Spacer()
            Button { model.go("profile") } label: {
                Circle().fill(igGradient).frame(width: 26, height: 26)
                    .overlay(Circle().stroke(igText, lineWidth: 1.5))
            }
            Spacer()
        }
        .foregroundColor(igText)
        .frame(height: 48)
    }
}

// ปุ่มลอยแบบ AssistiveTouch: ลากย้ายได้อิสระ ปล่อยแล้วดูดเข้าขอบซ้าย/ขวา
// จำตำแหน่งไว้ข้ามการเปิดแอป (AppStorage)
struct DraggableFloatingButton: View {
    let bounds: CGSize
    var action: () -> Void

    @AppStorage("floatBtnOnRight") private var onRight = true
    @AppStorage("floatBtnYRatio") private var yRatio = 0.12   // ตำแหน่งแนวตั้ง (สัดส่วนของจอ)

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private let diameter: CGFloat = 56
    private let edgeMargin: CGFloat = 12

    var body: some View {
        let homeX = onRight ? bounds.width - edgeMargin - diameter / 2
                            : edgeMargin + diameter / 2
        let homeY = clampY(yRatio) * bounds.height

        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(.regularMaterial))
            .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(isDragging ? 0.3 : 0.15), radius: isDragging ? 10 : 6, y: 2)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .opacity(isDragging ? 1.0 : 0.8)
            .position(x: homeX + dragOffset.width, y: homeY + dragOffset.height)
            .onTapGesture { action() }
            .gesture(
                // minimumDistance 10 → แตะเฉย ๆ ยังเป็นการกดปุ่ม ไม่โดนลากกิน
                DragGesture(minimumDistance: 10)
                    .onChanged { v in
                        isDragging = true
                        dragOffset = v.translation
                    }
                    .onEnded { v in
                        let finalX = homeX + v.translation.width
                        let finalY = homeY + v.translation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            onRight = finalX > bounds.width / 2   // ดูดเข้าขอบใกล้สุด
                            yRatio = clampY(Double(finalY / bounds.height))
                            dragOffset = .zero
                        }
                        isDragging = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            )
    }

    // กันปุ่มหลุดขอบบน/ล่าง (เผื่อ notch กับ home indicator)
    private func clampY(_ ratio: Double) -> Double {
        min(max(ratio, 0.07), 0.88)
    }
}

// จุดแดงเลขแจ้งเตือนสไตล์ IG มุมขวาบนของไอคอน
extension View {
    func igBadge(_ count: Int) -> some View {
        overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(red: 1.0, green: 0.19, blue: 0.31)))
                    .offset(x: 10, y: -6)
            }
        }
    }
}

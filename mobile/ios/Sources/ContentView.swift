import SwiftUI
import WebKit

// หน้าจอหลัก: รองรับ 3 โหมดพรางตัว (Liquid Glass, Instagram, Tinder)
// พร้อมระบบแชท IG Direct แบบเต็มจอ ไร้แถบกวนใจ (Seamless Chat)
struct ContentView: View {
    @StateObject private var model = MaskModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var showSettings = false

    // สีสไตล์ Instagram
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
            // เลือกระหว่างหน้าแชทเต็มจอ หรือหน้าฟีดหลัก
            if model.isInChat {
                seamlessChatView
                    .transition(.opacity)
            } else {
                switch settings.disguiseMode {
                case .liquidGlass:
                    liquidGlassView
                        .transition(.opacity)
                case .instagram:
                    instagramView
                        .transition(.opacity)
                case .rawTinder:
                    rawTinderView
                        .transition(.opacity)
                }
            }

            // โหมด decoy: Instagram จริงเต็มจอ ทับเปลือก Tinder ไว้
            if model.showRealInstagram {
                realInstagram
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isInChat)
        .animation(.easeInOut(duration: 0.2), value: settings.disguiseMode)
        .animation(.easeInOut(duration: 0.15), value: model.showRealInstagram)
        .background(currentBackground)
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

    private var currentBackground: Color {
        if settings.disguiseMode == .liquidGlass || settings.disguiseMode == .rawTinder {
            return Color(red: 0.04, green: 0.06, blue: 0.09)
        }
        return igBg
    }

    // =========================================================================
    // 1. SEAMLESS CHAT VIEW (แชทเต็มจอ มีปุ่ม Back ชัดเจน ไม่โดนบีบเลย์เอาต์)
    // =========================================================================
    private var seamlessChatView: some View {
        VStack(spacing: 0) {
            // Direct Chat Header
            HStack(spacing: 12) {
                Button {
                    model.backToFeed()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                        Text("ย้อนกลับ")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(settings.disguiseMode == .liquidGlass ? .cyan : igText)
                }

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(settings.disguiseMode == .liquidGlass ? Color.cyan.opacity(0.25) : Color.blue.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 14))
                                .foregroundColor(settings.disguiseMode == .liquidGlass ? .cyan : .blue)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.username.components(separatedBy: " · ").first ?? "ข้อความ Direct")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(settings.disguiseMode == .liquidGlass ? .white : igText)
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("Active Now")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(settings.disguiseMode == .liquidGlass ? .white : igText)
                        .padding(6)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(settings.disguiseMode == .liquidGlass ? Color(red: 0.08, green: 0.10, blue: 0.14) : igBg)
            
            Divider().overlay(settings.disguiseMode == .liquidGlass ? Color.white.opacity(0.15) : igBorder)

            // Full Height Chat Webview
            WebViewRepresentable(webView: model.webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(settings.disguiseMode == .liquidGlass ? Color.black : igBg)
        }
    }

    // =========================================================================
    // 2. LIQUID GLASS VIEW (ดีไซน์ VisionOS / Frosted Glass ดูไม่เหมือนใคร)
    // =========================================================================
    private var liquidGlassView: some View {
        ZStack {
            // Media Webview Container
            media
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .padding(.top, 58)
                .padding(.bottom, 78)

            // Liquid Droplet Burst Animation
            if model.dropletBurst {
                LiquidDropletBurstView()
                    .zIndex(5)
            }

            // Top Floating Frosted Glass Capsule
            VStack {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                            Text("LF")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Text("Lumina Flow")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Switch Mode Menu
                    Menu {
                        ForEach(DisguiseMode.allCases) { mode in
                            Button {
                                withAnimation { settings.disguiseMode = mode }
                            } label: {
                                if settings.disguiseMode == mode {
                                    Label(mode.label, systemImage: "checkmark")
                                } else {
                                    Text(mode.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("4K HDR")
                                .font(.system(size: 10, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .liquidGlassSurface(cornerRadius: 22)
                .padding(.horizontal, 14)
                .padding(.top, 2)

                Spacer()

                // Candidate Info Glass Panel
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.username)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Visual Creator • Studio Portrait")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.85))
                    }
                    Spacer()
                    Button {
                        model.openChat()
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.cyan)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .liquidGlassSurface(cornerRadius: 20)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

                // Bottom Floating Glass Pill Action Bar
                HStack(spacing: 8) {
                    Button {
                        model.pass()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Pass")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.45))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }

                    Button {
                        model.openChat()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Connect")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }

                    Button {
                        model.collect()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            Text("Collect")
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.cyan.opacity(0.22))
                        .clipShape(Capsule())
                    }
                }
                .padding(5)
                .liquidGlassSurface(cornerRadius: 26)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        }
    }

    // =========================================================================
    // 3. INSTAGRAM VIEW (โหมดพรางฟีดไอจีเดิม)
    // =========================================================================
    private var instagramView: some View {
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
    }

    // ── แถบบน IG ──
    private var header: some View {
        HStack {
            BrandMark(size: 22)
            Spacer()
            HStack(spacing: 20) {
                Button { model.go("recs") } label: {
                    Image(systemName: "heart").font(.system(size: 22))
                }
                Button { model.openChat() } label: {
                    Image(systemName: "bubble.right").font(.system(size: 21))
                        .igBadge(model.badgeCount)
                }
            }
            .foregroundColor(igText)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    // ── หัวโพสต์ IG ──
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

    // ── แถวปุ่มใต้โพสต์ IG ──
    private var actionRow: some View {
        HStack(spacing: 18) {
            Button { model.like() } label: {
                Image(systemName: "heart").font(.system(size: 24))
            }
            Button { model.openChat() } label: {
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

    // ── แถบล่าง IG ──
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
            Button { model.toggleRealInstagram() } label: {
                Image(systemName: "play.rectangle").font(.system(size: 24))
            }
            Spacer()
            Button { model.openChat() } label: {
                Image(systemName: "bubble.left").font(.system(size: 24))
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

    // =========================================================================
    // 4. RAW TINDER VIEW (โหมดตรวจสอบ Tinder ดั้งเดิม)
    // =========================================================================
    private var rawTinderView: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.pink)
                    Text("tinder")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.pink)
                }
                Spacer()
                Text("RAW VIEW")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.pink.opacity(0.2))
                    .foregroundColor(.pink)
                    .clipShape(Capsule())

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(red: 0.08, green: 0.09, blue: 0.12))

            // Media
            media

            // Classic 5 Tinder buttons
            HStack(spacing: 16) {
                Button { model.pass() } label: {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "arrow.counterclockwise").foregroundColor(.yellow))
                }
                Button { model.pass() } label: {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "xmark").font(.system(size: 22, weight: .bold)).foregroundColor(.red))
                }
                Button { model.superLike() } label: {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "star.fill").foregroundColor(.blue))
                }
                Button { model.like() } label: {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "heart.fill").font(.system(size: 22, weight: .bold)).foregroundColor(.green))
                }
                Button { model.openChat() } label: {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "bubble.left.fill").foregroundColor(.purple))
                }
            }
            .padding(.vertical, 12)
            .background(Color(red: 0.08, green: 0.09, blue: 0.12))
        }
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
}

// Modifier สำหรับสไตล์ Liquid Glass พื้นผิวกระจกสะท้อนแสง
struct LiquidGlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.12),
                                Color.black.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func liquidGlassSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(LiquidGlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}

// แอนิเมชันคลื่นหยดน้ำกระจายสไตล์ Liquid Glass
struct LiquidDropletBurstView: View {
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.7), lineWidth: 2.5)
                .frame(width: 140, height: 140)
            
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 120, height: 120)
                .liquidGlassSurface(cornerRadius: 60)
            
            VStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.cyan)
                Text("COLLECTED")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color.cyan.opacity(0.95))
                    .tracking(2)
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                scale = 1.05
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.38)) {
                scale = 1.25
                opacity = 0.0
            }
        }
    }
}

// ปุ่มลอยแบบ AssistiveTouch: ลากย้ายได้อิสระ ปล่อยแล้วดูดเข้าขอบซ้าย/ขวา
struct DraggableFloatingButton: View {
    let bounds: CGSize
    var action: () -> Void

    @AppStorage("floatBtnOnRight") private var onRight = true
    @AppStorage("floatBtnYRatio") private var yRatio = 0.12

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
                DragGesture(minimumDistance: 10)
                    .onChanged { v in
                        isDragging = true
                        dragOffset = v.translation
                    }
                    .onEnded { v in
                        let finalX = homeX + v.translation.width
                        let finalY = homeY + v.translation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            onRight = finalX > bounds.width / 2
                            yRatio = clampY(Double(finalY / bounds.height))
                            dragOffset = .zero
                        }
                        isDragging = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            )
    }

    private func clampY(_ ratio: Double) -> Double {
        min(max(ratio, 0.07), 0.88)
    }
}

// จุดแดงเลขแจ้งเตือน
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

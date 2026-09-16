import SwiftUI

// ครอบ ContentView ด้วยระบบล็อก PIN + เบลอตอนสลับแอป
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = PinStore.isSet   // ล็อกตั้งแต่เปิดแอปถ้าตั้ง PIN ไว้
    @State private var showPickleLive = false      // ใส่ PIN สำรอง → เว็บ PickleWatch ตัวจริง
    @State private var isAppResigning = false      // สัญญาณ iOS กำลังจะสลับแอป/ถ่าย snapshot

    var body: some View {
        ZStack {
            ContentView()

            // โหมด PIN สำรอง: เว็บตัวจริงเต็มจอ ทับทุกอย่าง
            if showPickleLive {
                PickleLiveView(onExit: {
                    showPickleLive = false
                    AppSettings.shared.isDecoyActive = false
                    isLocked = true      // กลับไปหน้าล็อก ต้องใส่ PIN หลักใหม่
                })
                .transition(.opacity)
                .zIndex(3)
            }

            // ล็อกด้วย PIN
            if isLocked {
                LockView(
                    mode: .verify,
                    onUnlocked: {
                        showPickleLive = false
                        AppSettings.shared.isDecoyActive = false
                        isLocked = false
                    },
                    onDecoyUnlocked: {
                        showPickleLive = true
                        AppSettings.shared.isDecoyActive = true
                        isLocked = false
                    }
                )
                .transition(.opacity)
                .zIndex(2)
            }

            // ตอนสลับแอป / อยู่ใน App Switcher → พรางหน้าต่างแบบแอปธนาคาร (Banking Privacy Shield)
            if shouldShowPrivacyShield {
                BankingPrivacyShield()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLocked)
        .animation(.easeInOut(duration: 0.2), value: showPickleLive)
        .animation(.easeInOut(duration: 0.12), value: shouldShowPrivacyShield)
        .onAppear { NotificationManager.shared.refreshAuthorizationStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isAppResigning = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isAppResigning = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, PinStore.isSet {
                isLocked = true       // กลับมาเปิดใหม่ต้องใส่ PIN อีกครั้ง
                showPickleLive = false // ออกจากโหมด PIN สำรองด้วย
            }
            if phase == .active {
                isAppResigning = false
                NotificationManager.shared.refreshAuthorizationStatus()
            }
        }
    }

    // พรางหน้าจอทันทีเมื่อไม่ได้ Active หรือกำลังจะถูกดึงเข้า App Switcher (แบบแอปธนาคาร)
    private var shouldShowPrivacyShield: Bool {
        (scenePhase != .active || isAppResigning) && !showPickleLive
    }
}

// หน้าต่างพรางความปลอดภัยสไตล์แอปธนาคาร (Banking Privacy Shield)
struct BankingPrivacyShield: View {
    @State private var pulseGlow = false

    var body: some View {
        ZStack {
            // ชั้นทึบสนิท 100% ป้องกันข้อมูลทุกอย่างไม่ให้รั่วไหล
            Color.black
                .ignoresSafeArea()

            // กระจกเบลอหนาพิเศษ (Ultra-thick Frosted Material)
            VisualEffectBlur(style: .systemUltraThinMaterialDark)
                .ignoresSafeArea()

            // แสงสะท้อนสี Caustic นุ่มนวลรอบจุดศูนย์กลาง
            RadialGradient(
                colors: [Color.cyan.opacity(0.18), Color.purple.opacity(0.1), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 260
            )
            .ignoresSafeArea()

            // การ์ดกระจกศูนย์กลาง (Center Glass Shield Card)
            VStack(spacing: 20) {
                // ไอคอน Prism Crystal เรืองแสง
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.cyan.opacity(0.28), .indigo.opacity(0.35), .purple.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 86, height: 86)
                        .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.5))
                        .shadow(color: .cyan.opacity(pulseGlow ? 0.55 : 0.25), radius: pulseGlow ? 20 : 10)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(pulseGlow ? 1.04 : 1.0)

                VStack(spacing: 6) {
                    Text("Prism")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.5)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                            .shadow(color: .green.opacity(0.8), radius: 4)

                        Text("Privacy Shield Active")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.08), .cyan.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)

            // แถบรับรองความปลอดภัยด้านล่าง
            VStack {
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan.opacity(0.8))
                    Text("Encrypted & Protected by Secure Enclave")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
}

// โลโก้แบรนด์หน้ากากพรางตัว ปรับเปลี่ยนตามโหมด
struct BrandMark: View {
    var size: CGFloat = 34
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 8) {
            switch settings.disguiseMode {
            case .liquidGlass:
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.75, weight: .bold))
                    .foregroundColor(.cyan)
                Text("Prism")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            case .rawTinder:
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.75))
                    .foregroundColor(.pink)
                Text("tinder")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(.pink)
            }
        }
    }
}

// ห่อ UIVisualEffectView ให้ SwiftUI
struct VisualEffectBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

import SwiftUI

// ครอบ ContentView ด้วยระบบล็อก PIN + เบลอตอนสลับแอป
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = PinStore.isSet   // ล็อกตั้งแต่เปิดแอปถ้าตั้ง PIN ไว้
    @State private var showPickleLive = false      // ใส่ PIN สำรอง → เว็บ PickleWatch ตัวจริง

    var body: some View {
        ZStack {
            ContentView()

            // โหมด PIN สำรอง: เว็บ PickleWatch ของจริงเต็มจอ ทับทุกอย่าง
            if showPickleLive {
                PickleLiveView(onExit: {
                    showPickleLive = false
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
                        isLocked = false
                    },
                    onDecoyUnlocked: {
                        showPickleLive = true
                        isLocked = false
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }

            // ตอนสลับแอป/อยู่ใน app switcher → โชว์แดชบอร์ดพิกเกิลบอลปลอมทับ
            // (กันแอบดู snapshot ของ Tinder + ดูเป็นแอปกีฬาธรรมดา)
            if shouldShowDecoy {
                PickleDashboard()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLocked)
        .animation(.easeInOut(duration: 0.2), value: showPickleLive)
        .animation(.easeInOut(duration: 0.15), value: shouldShowDecoy)
        .onAppear { NotificationManager.shared.refreshAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, PinStore.isSet {
                isLocked = true       // กลับมาเปิดใหม่ต้องใส่ PIN อีกครั้ง
                showPickleLive = false // ออกจากโหมด PIN สำรองด้วย
            }
            if phase == .active {
                // เผื่อผู้ใช้ไปเปลี่ยนสิทธิ์แจ้งเตือนใน Settings ของ iOS
                NotificationManager.shared.refreshAuthorizationStatus()
            }
        }
    }

    // โชว์ decoy เมื่อไม่ได้ active และยังไม่ได้ล็อก (ถ้าล็อกอยู่ lock screen บังให้แล้ว)
    // โหมด PickleWatch ตัวจริงไม่ต้องบัง — หน้าจอนั้นดูปลอดภัยอยู่แล้ว
    private var shouldShowDecoy: Bool {
        scenePhase != .active && !isLocked && !showPickleLive
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
                Text("Lumina Flow")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            case .instagram:
                Image(systemName: "camera.fill")
                    .font(.system(size: size * 0.65))
                    .foregroundColor(.primary)
                Text("Instagram")
                    .font(.system(size: size, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
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

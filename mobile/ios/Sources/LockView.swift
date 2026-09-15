import SwiftUI
import LocalAuthentication

// หน้าจอล็อก: ใช้ทั้งตอน "ตั้ง PIN ใหม่" และ "ปลดล็อก"
struct LockView: View {
    enum Mode { case setup, setupDecoy, verify }

    let mode: Mode
    var onUnlocked: () -> Void
    var onPinSet: (() -> Void)?
    var onCancel: (() -> Void)?
    // ใส่ PIN สำรองถูก → เปิดเว็บ PickleWatch ตัวจริงแทนการเข้าแอป
    var onDecoyUnlocked: (() -> Void)?

    private let pinLength = 6

    @State private var entry = ""
    @State private var firstPin: String? = nil   // สำหรับ setup: PIN รอบแรกไว้ยืนยัน
    @State private var title = ""
    @State private var errorShake = false
    @State private var wrongMsg: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // โลโก้อำพราง
            BrandMark(size: 34)
                .padding(.bottom, 40)

            Text(currentTitle)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .padding(.bottom, 22)

            // จุดแสดงจำนวนหลักที่กด
            HStack(spacing: 20) {
                ForEach(0..<pinLength, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color.secondary, lineWidth: 1.5)
                        .background(Circle().fill(i < entry.count ? Color.primary : Color.clear))
                        .frame(width: 16, height: 16)
                }
            }
            .offset(x: errorShake ? -10 : 0)
            .padding(.bottom, 14)

            Text(wrongMsg ?? " ")
                .font(.system(size: 13))
                .foregroundColor(.red)
                .padding(.bottom, 20)

            Spacer()

            keypad
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            if mode == .verify { tryBiometric() }
        }
    }

    private var currentTitle: String {
        switch mode {
        case .verify: return "ใส่ PIN เพื่อปลดล็อก"
        case .setup:  return firstPin == nil ? "ตั้ง PIN ใหม่ (6 หลัก)" : "ใส่ PIN อีกครั้งเพื่อยืนยัน"
        case .setupDecoy:
            return firstPin == nil ? "ตั้ง PIN สำรอง (6 หลัก)" : "ใส่ PIN สำรองอีกครั้งเพื่อยืนยัน"
        }
    }

    // ── ปุ่มตัวเลข ──
    private var keypad: some View {
        let rows: [[String]] = [["1","2","3"], ["4","5","6"], ["7","8","9"], ["bio","0","del"]]
        return VStack(spacing: 18) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 26) {
                    ForEach(row, id: \.self) { key in keyButton(key) }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        switch key {
        case "del":
            Button { if !entry.isEmpty { entry.removeLast() } } label: {
                Image(systemName: "delete.left").font(.system(size: 24))
                    .frame(width: 72, height: 72)
            }
            .foregroundColor(.primary)
        case "bio":
            if mode == .verify && biometricAvailable {
                Button { tryBiometric() } label: {
                    Image(systemName: biometricIcon).font(.system(size: 26))
                        .frame(width: 72, height: 72)
                }
                .foregroundColor(.primary)
            } else if mode != .verify, onCancel != nil {
                Button { onCancel?() } label: {
                    Text("ยกเลิก").font(.system(size: 15))
                        .frame(width: 72, height: 72)
                }
                .foregroundColor(.primary)
            } else {
                Color.clear.frame(width: 72, height: 72)
            }
        default:
            Button { press(key) } label: {
                Text(key)
                    .font(.system(size: 30, weight: .regular))
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }
            .foregroundColor(.primary)
        }
    }

    // ── ตรรกะ ──
    private func press(_ digit: String) {
        guard entry.count < pinLength else { return }
        wrongMsg = nil
        entry += digit
        if entry.count == pinLength { submit() }
    }

    private func submit() {
        switch mode {
        case .verify:
            if PinStore.verify(entry) {
                onUnlocked()
            } else if let onDecoy = onDecoyUnlocked, PinStore.verify(entry, slot: .decoy) {
                onDecoy()
            } else {
                fail("PIN ไม่ถูกต้อง")
            }
        case .setup, .setupDecoy:
            let slot: PinStore.Slot = (mode == .setup) ? .main : .decoy
            // กันตั้งซ้ำกับ PIN อีกชุด — ไม่งั้นชุดหนึ่งจะไม่มีวันถูกใช้
            let otherSlot: PinStore.Slot = (slot == .main) ? .decoy : .main
            if PinStore.isSet(otherSlot), PinStore.verify(entry, slot: otherSlot) {
                firstPin = nil
                fail("ห้ามซ้ำกับ PIN อีกชุด")
                return
            }
            if let first = firstPin {
                if first == entry {
                    PinStore.setPin(entry, slot: slot)
                    onPinSet?()
                } else {
                    firstPin = nil
                    fail("PIN ไม่ตรงกัน ลองใหม่")
                }
            } else {
                firstPin = entry
                entry = ""
            }
        }
    }

    private func fail(_ msg: String) {
        wrongMsg = msg
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) { errorShake = true }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            errorShake = false
            entry = ""
        }
    }

    // ── Face ID / Touch ID ──
    private var biometricAvailable: Bool {
        AppSettings.shared.useBiometrics &&
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private var biometricIcon: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .faceID ? "faceid" : "touchid"
    }

    private func tryBiometric() {
        guard biometricAvailable else { return }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "ใช้ PIN"
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "ปลดล็อกเพื่อเข้าใช้งาน") { ok, _ in
            if ok { DispatchQueue.main.async { onUnlocked() } }
        }
    }
}

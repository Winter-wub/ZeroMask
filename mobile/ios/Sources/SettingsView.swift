import SwiftUI
import WebKit
import UIKit

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    var onLogout: () -> Void

    @State private var showLogoutConfirm = false
    @State private var showPinSetup = false
    @State private var showPinRemoveConfirm = false
    @State private var pinEnabled = PinStore.isSet
    @State private var showNotifDeniedAlert = false
    @State private var testAlertMessage: String? = nil
    @State private var showDecoyPinSetup = false
    @State private var showDecoyRemoveConfirm = false
    @State private var decoyPinEnabled = PinStore.isSet(.decoy)
    @ObservedObject private var bgTaskManager = BackgroundTaskManager.shared
    @State private var isTestingTinder = false
    @State private var isTestingIG = false

    // เช็คสิทธิ์ Background Refresh ของ iOS
    private var bgRefreshStatusText: (text: String, isOk: Bool) {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            return ("เปิดใช้งานแล้ว", true)
        case .denied:
            return ("ถูกปิดใน iOS Settings", false)
        case .restricted:
            return ("ถูกจำกัด (โหมดประหยัดพลังงาน)", false)
        @unknown default:
            return ("ไม่ทราบสถานะ", false)
        }
    }

    @State private var isIGSessionReady = false
    @State private var igUserId: String? = nil
    @State private var isTinderTokenReady = false
    @State private var tinderTokenSnippet: String? = nil

    private var isBackgroundNotificationReady: Bool {
        settings.notificationsEnabled &&
        NotificationManager.shared.isAuthorized &&
        UIApplication.shared.backgroundRefreshStatus == .available &&
        (isTinderTokenReady || isIGSessionReady)
    }

    private func refreshSessions() {
        if let token = KeychainTokenStore.load(for: .tinderAuthToken), !token.isEmpty {
            self.tinderTokenSnippet = String(token.prefix(6)) + "..." + String(token.suffix(4))
            self.isTinderTokenReady = true
        }
        if let sid = KeychainTokenStore.load(for: .instagramSessionId), !sid.isEmpty {
            self.isIGSessionReady = true
            self.igUserId = KeychainTokenStore.load(for: .instagramUserId)
        }

        // ดึง HttpOnly cookies ของ Instagram และ Tinder จาก WKHTTPCookieStore สดๆ
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            var foundIGSession = false
            var foundUserId: String?
            var foundTinderToken: String?

            for c in cookies {
                if c.domain.contains("instagram.com") {
                    if c.name == "sessionid" && !c.value.isEmpty {
                        KeychainTokenStore.save(c.value, for: .instagramSessionId)
                        foundIGSession = true
                    } else if c.name == "ds_user_id" && !c.value.isEmpty {
                        KeychainTokenStore.save(c.value, for: .instagramUserId)
                        foundUserId = c.value
                    } else if c.name == "csrftoken" && !c.value.isEmpty {
                        KeychainTokenStore.save(c.value, for: .instagramCsrfToken)
                    }
                } else if c.domain.contains("tinder.com") {
                    if (c.name.contains("token") || c.name.contains("Token") || c.name == "api_token") && !c.value.isEmpty {
                        foundTinderToken = c.value
                    }
                }
            }

            if let tt = foundTinderToken, KeychainTokenStore.load(for: .tinderAuthToken) == nil {
                KeychainTokenStore.save(tt, for: .tinderAuthToken)
            }

            DispatchQueue.main.async {
                if let token = KeychainTokenStore.load(for: .tinderAuthToken), !token.isEmpty {
                    self.tinderTokenSnippet = String(token.prefix(6)) + "..." + String(token.suffix(4))
                    self.isTinderTokenReady = true
                }
                let hasIG = foundIGSession || (KeychainTokenStore.load(for: .instagramSessionId) != nil)
                self.isIGSessionReady = hasIG
                if let uid = foundUserId ?? KeychainTokenStore.load(for: .instagramUserId) {
                    self.igUserId = uid
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── โหมดหน้ากากพรางตัว ──
                Section {
                    Picker("รูปแบบ", selection: $settings.disguiseMode) {
                        ForEach(DisguiseMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("หน้ากากพรางตัว (Disguise Mode)")
                } footer: {
                    Text("โหมดหลักคือ Liquid Glass (Lumina Flow) ที่ดูไม่เหมือนใคร หรือเลือกดู Raw Tinder\nแตะปุ่ม 📸 IG ในหน้าหลักเพื่อสลับไป Instagram จริง (Decoy) ได้ตลอดเวลา")
                }

                // ── ธีม ──
                Section("การแสดงผล") {
                    Picker("ธีม", selection: $settings.themeMode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ── ท่าทาง / การเล่น ──
                Section("การเล่นแบบฟีด") {
                    Toggle("ดับเบิลแท็ปรูปเพื่อ Like", isOn: $settings.doubleTapLike)
                    Toggle("ปัดลงเพื่อข้ามคนนี้", isOn: $settings.swipeToPass)
                }

                // ── การแจ้งเตือน ──
                Section {
                    Toggle("เปิดการแจ้งเตือน", isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { want in
                            if want {
                                NotificationManager.shared.requestAuthorization { granted in
                                    settings.notificationsEnabled = granted
                                    if !granted { showNotifDeniedAlert = true }
                                }
                            } else {
                                settings.notificationsEnabled = false
                                NotificationManager.shared.clearAll()
                            }
                        }
                    ))
                    if settings.notificationsEnabled {
                        Picker("รูปแบบการพรางตัว", selection: $settings.notificationDisguiseStyle) {
                            ForEach(NotificationDisguiseStyle.allCases) { style in
                                Text(style.label).tag(style)
                            }
                        }

                        Toggle("เสียงแจ้งเตือน", isOn: $settings.notificationSound)
                        Toggle("แสดงเลขบนไอคอนแอป", isOn: $settings.showIconBadge)
                        Toggle("แจ้งเตือนขณะใช้แอปอยู่", isOn: $settings.notifyWhileUsing)
                        notificationStatusPanel
                    }
                } header: {
                    Text("การแจ้งเตือน")
                } footer: {
                    Text(settings.notificationDisguiseStyle == .aiAgent
                        ? "ระบบจะสุ่มแจ้งเตือนเป็นข้อความ AI Agent (สถานะงาน / task สำเร็จ / โค้ด) เมื่อมีแมตช์หรือข้อความใหม่ โดยจะแอบดึงข้อมูลเป็นระยะเบื้องหลัง (Background App Refresh)"
                        : "ระบบจะสุ่มแจ้งเตือนเป็นข้อความ Instagram เมื่อมีแมตช์หรือข้อความใหม่ โดยจะแอบดึงข้อมูลเป็นระยะเบื้องหลัง (Background App Refresh)")
                }

                // ── ความปลอดภัย ──
                Section {
                    Toggle("ล็อกด้วย PIN", isOn: Binding(
                        get: { pinEnabled },
                        set: { want in
                            if want { showPinSetup = true }
                            else { showPinRemoveConfirm = true }
                        }
                    ))
                    if pinEnabled {
                        Button("เปลี่ยน PIN") { showPinSetup = true }
                        Toggle("ปลดล็อกด้วย Face ID / Touch ID", isOn: $settings.useBiometrics)
                    }
                } header: {
                    Text("ความปลอดภัย")
                } footer: {
                    Text("ต้องใส่ PIN ทุกครั้งที่เปิดแอป และหน้าจอจะเบลอตอนสลับแอป")
                }

                // ── PIN สำรอง (decoy) ──
                Section {
                    Toggle("เปิดใช้ PIN สำรอง", isOn: Binding(
                        get: { decoyPinEnabled },
                        set: { want in
                            if want { showDecoyPinSetup = true }
                            else { showDecoyRemoveConfirm = true }
                        }
                    ))
                    .disabled(!pinEnabled)
                    if decoyPinEnabled {
                        Button("เปลี่ยน PIN สำรอง") { showDecoyPinSetup = true }
                        TextField("ลิงก์ถ่ายทอดสด", text: $settings.pickleLiveURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.system(size: 13))
                        if settings.pickleLiveResolvedURL == nil {
                            Label("ยังไม่มีลิงก์ที่ใช้ได้ — ใส่ PIN สำรองแล้วจะเห็นจอขาว", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("PIN สำรอง")
                } footer: {
                    Text(pinEnabled
                         ? "ใส่ PIN ชุดนี้ที่หน้าล็อกแทน PIN หลัก จะเปิดเว็บ PickleWatch ตัวจริงเต็มจอ "
                           + "ไม่เห็นแอปข้างในเลย (แตะมุมซ้ายบน 5 ครั้งเพื่อกลับหน้าล็อก)"
                         : "ต้องเปิดการล็อกด้วย PIN ก่อนถึงจะตั้ง PIN สำรองได้")
                }

                // ── บัญชี ──
                Section("บัญชี") {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Text("ออกจากระบบ / ล้างข้อมูล")
                    }
                }

                // ── เกี่ยวกับ ──
                Section {
                    LabeledContent("เวอร์ชัน", value: appVersion)
                } footer: {
                    Text("แอปนี้เป็นเปลือกห่อ Tinder web สำหรับใช้บนเครื่องตัวเองเท่านั้น ไม่มีบอท/ไม่ออโต้สไวป์")
                }
            }
            .navigationTitle("การตั้งค่า")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
            .confirmationDialog("ออกจากระบบ?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("ล้างข้อมูลและออกจากระบบ", role: .destructive) {
                    onLogout()
                    dismiss()
                }
                Button("ยกเลิก", role: .cancel) {}
            } message: {
                Text("จะล้าง cookie/session ทั้งหมด ต้องล็อกอิน Tinder ใหม่")
            }
            .confirmationDialog("ปิดการล็อก?", isPresented: $showPinRemoveConfirm, titleVisibility: .visible) {
                Button("ปิดการล็อกด้วย PIN", role: .destructive) {
                    PinStore.clearAll()   // ปิดล็อกหลัก → PIN สำรองก็ใช้ไม่ได้แล้ว
                    pinEnabled = false
                    decoyPinEnabled = false
                }
                Button("ยกเลิก", role: .cancel) {}
            }
            .confirmationDialog("ปิด PIN สำรอง?", isPresented: $showDecoyRemoveConfirm, titleVisibility: .visible) {
                Button("ปิด PIN สำรอง", role: .destructive) {
                    PinStore.clear(.decoy)
                    decoyPinEnabled = false
                }
                Button("ยกเลิก", role: .cancel) {}
            }
            .alert("เปิดการแจ้งเตือนไม่ได้", isPresented: $showNotifDeniedAlert) {
                Button("เปิดการตั้งค่า") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("ตกลง", role: .cancel) {}
            } message: {
                Text("คุณปิดสิทธิ์แจ้งเตือนไว้ ไปเปิดที่การตั้งค่าเครื่อง (Settings → Notifications)")
            }
            .alert("ทดสอบการแจ้งเตือน", isPresented: Binding(
                get: { testAlertMessage != nil },
                set: { if !$0 { testAlertMessage = nil } }
            )) {
                Button("ตกลง", role: .cancel) {}
            } message: {
                Text(testAlertMessage ?? "")
            }
            .fullScreenCover(isPresented: $showPinSetup) {
                LockView(
                    mode: .setup,
                    onUnlocked: {},
                    onPinSet: {
                        pinEnabled = true
                        showPinSetup = false
                    },
                    onCancel: { showPinSetup = false }
                )
            }
            .fullScreenCover(isPresented: $showDecoyPinSetup) {
                LockView(
                    mode: .setupDecoy,
                    onUnlocked: {},
                    onPinSet: {
                        decoyPinEnabled = true
                        showDecoyPinSetup = false
                    },
                    onCancel: { showDecoyPinSetup = false }
                )
            }
            .onAppear {
                NotificationManager.shared.refreshAuthorizationStatus()
                refreshSessions()
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    @ViewBuilder
    private var notificationStatusPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("สถานะระบบแจ้งเตือน")
                    .font(.subheadline.bold())
                Spacer()
                if isBackgroundNotificationReady {
                    Label("พร้อมทำงาน", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.green)
                } else {
                    Label("ยังไม่สมบูรณ์", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.orange)
                }
            }

            Divider()

            // 1. สิทธิ์แจ้งเตือนระบบ
            HStack {
                Text("• สิทธิ์แจ้งเตือนระบบ")
                Spacer()
                let notifOk = NotificationManager.shared.isAuthorized
                Text(notifOk ? "อนุญาตแล้ว ✅" : "ยังไม่อนุญาต ❌")
                    .font(.caption)
                    .foregroundStyle(notifOk ? Color.secondary : Color.red)
            }

            // 2. Background Refresh
            HStack {
                Text("• Background Refresh")
                Spacer()
                let bgOk = bgRefreshStatusText.isOk
                let text = bgRefreshStatusText.text + (bgOk ? " ✅" : " ⚠️")
                Text(text)
                    .font(.caption)
                    .foregroundStyle(bgOk ? Color.secondary : Color.orange)
            }

            // 3. เซสชัน Tinder
            HStack {
                Text("• เซสชัน Tinder")
                Spacer()
                if let snippet = tinderTokenSnippet {
                    Text("เชื่อมต่อแล้ว ✅ (\(snippet))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                } else {
                    Text("รอเข้าสู่ระบบ ⏳")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }

            // 4. เซสชัน Instagram
            HStack {
                Text("• เซสชัน Instagram")
                Spacer()
                if isIGSessionReady {
                    let text = igUserId != nil && !igUserId!.isEmpty ? "เข้าสู่ระบบแล้ว ✅ (@\(igUserId!))" : "เข้าสู่ระบบแล้ว ✅"
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                } else {
                    Text("ยังไม่เข้าสู่ระบบ ⏳")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }

            Divider().padding(.vertical, 2)

            // ปุ่มทดสอบดึงข้อมูลจริงจาก Tinder API
            Button {
                isTestingTinder = true
                bgTaskManager.fetchUpdatesNow(for: .tinder) { res in
                    isTestingTinder = false
                    if res.success {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        testAlertMessage = "🔥 ตรวจสอบ Tinder API สำเร็จ!\n\n\(res.detail)\n\n(หากยอดใหม่มากกว่าเดิม ระบบจะส่งการแจ้งเตือนพรางตัวให้ทันที)"
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        testAlertMessage = "⚠️ ผลการตรวจ Tinder API:\n\n\(res.detail)"
                    }
                }
            } label: {
                HStack {
                    if isTestingTinder {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "flame.fill").foregroundColor(.orange)
                    }
                    Text("🔄 ทดสอบดึงข้อมูลจริงจาก Tinder API")
                }
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
            .disabled(isTestingTinder)

            // ปุ่มทดสอบดึงข้อมูลจริงจาก Instagram API
            Button {
                isTestingIG = true
                bgTaskManager.fetchUpdatesNow(for: .instagram) { res in
                    isTestingIG = false
                    if res.success {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        testAlertMessage = "📸 ตรวจสอบ Instagram API สำเร็จ!\n\n\(res.detail)\n\n(หากมียอดข้อความใหม่ ระบบจะส่งการแจ้งเตือนพรางตัวให้ทันที)"
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        testAlertMessage = "⚠️ ผลการตรวจ Instagram API:\n\n\(res.detail)"
                    }
                }
            } label: {
                HStack {
                    if isTestingIG {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "camera.fill").foregroundColor(.pink)
                    }
                    Text("📸 ทดสอบดึงข้อมูลจริงจาก Instagram API")
                }
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
            .disabled(isTestingIG)

            // ปุ่มทดสอบยิง Notification พรางตัว
            Button {
                let notifMgr = NotificationManager.shared
                notifMgr.requestAuthorization { granted in
                    if granted {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        notifMgr.postDisguisedNotification(force: true) { success, msg in
                            if success {
                                testAlertMessage = "ส่งการแจ้งเตือนพรางตัวสำเร็จ!\n\n\(msg)\n\n🔔 หากแถบ Banner ไม่เด้งลงมา โปรดเลื่อน Notification Center (ปัดขอบจอด้านบนลงมา) หรือตรวจเช็คว่าเปิดโหมด Focus/ห้ามรบกวน ไว้หรือไม่"
                            } else {
                                testAlertMessage = msg
                            }
                        }
                    } else {
                        showNotifDeniedAlert = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: settings.notificationDisguiseStyle == .aiAgent ? "cpu.fill" : "bell.badge.fill")
                        .foregroundColor(.blue)
                    Text(settings.notificationDisguiseStyle == .aiAgent ? "🤖 ทดสอบส่งแจ้งเตือน AI Agent" : "📸 ทดสอบส่งแจ้งเตือน Instagram")
                }
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)

            // ปุ่มรีเซ็ตตัวนับ
            Button {
                NotificationManager.shared.resetLastCount()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                testAlertMessage = "รีเซ็ตตัวนับการแจ้งเตือนเรียบร้อยแล้ว!\n\nการดึงข้อมูลครั้งถัดไปจะถือว่าข้อความหรือ Like ที่มีอยู่เป็นรายการใหม่ และจะส่งการแจ้งเตือนให้ทันที"
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("รีเซ็ตตัวนับการแจ้งเตือน (Reset Count)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)

            Text("💡 ระบบจะทำงานอัตโนมัติเป็นระยะเบื้องหลัง (Background App Refresh) เมื่อเสียบสายชาร์จหรือพักหน้าจอ หรือสามารถกดปุ่มทดสอบด้านบนเพื่อดึงข้อมูลสดได้ทันที")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

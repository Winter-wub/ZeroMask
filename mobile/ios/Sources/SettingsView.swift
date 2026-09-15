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
    @State private var showDecoyPinSetup = false
    @State private var showDecoyRemoveConfirm = false
    @State private var decoyPinEnabled = PinStore.isSet(.decoy)

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
                        Toggle("เสียงแจ้งเตือน", isOn: $settings.notificationSound)
                        Toggle("แสดงเลขบนไอคอนแอป", isOn: $settings.showIconBadge)
                        Toggle("แจ้งเตือนขณะใช้แอปอยู่", isOn: $settings.notifyWhileUsing)
                    }
                } header: {
                    Text("การแจ้งเตือน")
                } footer: {
                    Text("แจ้งเตือนเมื่อมีข้อความ/แมตช์ใหม่ ตรวจพบได้เฉพาะตอนแอปเปิดอยู่ "
                         + "(แอปนี้ไม่มี push server จึงไม่ได้รับแจ้งเตือนตอนปิดแอปสนิท) "
                         + "ส่วนเลขบนไอคอนจะค้างอยู่บนหน้าโฮมตามปกติ")
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
                Text("คุณปิดสิทธิ์แจ้งเตือนไว้ ไปเปิดที่ Settings → Instagram → Notifications")
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
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

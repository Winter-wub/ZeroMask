import Foundation
import CommonCrypto
import CryptoKit
import Security

// เก็บ PIN แบบ hash ใน Keychain — ไม่เก็บ PIN ตรง ๆ
// ใช้ PBKDF2-SHA256 (วนหลายรอบ) แทน SHA-256 รอบเดียว: PIN มีแค่ 10^6 แบบ
// ถ้าค่า hash หลุดออกไป SHA-256 เดาครบได้ในไม่กี่วินาที PBKDF2 ทำให้ช้าลงหลายแสนเท่า
//
// รูปแบบที่เก็บ: [0x02] + PBKDF2 32 byte (33 byte)
// แบบเก่า (SHA-256 ล้วน 32 byte) ยังตรวจได้ และจะถูกอัปเกรดอัตโนมัติตอนใส่ PIN ถูกครั้งแรก
//
// มี PIN 2 ชุด:
//   .main  — เข้าแอปจริง (เปลือก IG ครอบ Tinder)
//   .decoy — เปิดหน้าเว็บ PickleWatch ของจริงเต็มจอ (โหมดอำพราง)
enum PinStore {
    enum Slot: String {
        case main = "app-pin"
        case decoy = "app-pin-decoy"
    }

    private static let service = "com.prachayawut.gallery.pin"

    static var isSet: Bool { isSet(.main) }
    static func isSet(_ slot: Slot) -> Bool { load(slot) != nil }

    static func setPin(_ pin: String, slot: Slot = .main) {
        save(Data([formatV2]) + pbkdf2(pin), slot: slot)
    }

    static func verify(_ pin: String, slot: Slot = .main) -> Bool {
        guard let stored = load(slot) else { return false }
        // เทียบแบบ constant-time กันการเดา timing
        if stored.count == 33, stored.first == formatV2 {
            return constantTimeEquals(Data(stored.dropFirst()), pbkdf2(pin))
        }
        // PIN ที่ตั้งไว้ก่อนเปลี่ยนมาใช้ PBKDF2 → ตรวจแบบเก่า ถ้าถูกก็เขียนทับเป็นแบบใหม่
        guard constantTimeEquals(stored, legacyHash(pin)) else { return false }
        setPin(pin, slot: slot)
        return true
    }

    static func clear(_ slot: Slot = .main) {
        SecItemDelete(baseQuery(slot.rawValue) as CFDictionary)
    }

    // ลบ PIN ทั้งหมด (ใช้ตอนปิดการล็อกทั้งระบบ)
    static func clearAll() {
        clear(.main)
        clear(.decoy)
        resetFailures()
    }

    // ── กันเดา PIN: ผิดติดกันตั้งแต่ครั้งที่ 5 ต้องรอนานขึ้นเรื่อย ๆ ──
    // เก็บใน Keychain (ไม่ใช่หน่วยความจำ) → ปิดแล้วเปิดแอปใหม่ก็รีเซ็ตตัวนับไม่ได้
    private static let attemptsAccount = "app-pin.attempts"
    private static let maxLockout: TimeInterval = 15 * 60

    /// เหลือเวลาอีกกี่วินาทีถึงจะใส่ PIN ได้ (0 = ใส่ได้เลย)
    static var lockoutRemaining: TimeInterval {
        let remaining = loadAttempts().lockedUntil - Date().timeIntervalSince1970
        // ครอบด้วย maxLockout กันกรณีตั้งนาฬิกาเครื่องย้อนหลังแล้วโดนล็อกยาวเกินจริง
        return min(max(0, remaining), maxLockout)
    }

    static func recordFailure() {
        var (failures, _) = loadAttempts()
        failures += 1
        let lockedUntil = Date().timeIntervalSince1970 + lockoutDuration(afterFailures: failures)
        writeData(Data("\(failures)|\(lockedUntil)".utf8), account: attemptsAccount)
    }

    static func resetFailures() {
        SecItemDelete(baseQuery(attemptsAccount) as CFDictionary)
    }

    private static func lockoutDuration(afterFailures n: Int) -> TimeInterval {
        switch n {
        case ..<5: return 0
        case 5:    return 30
        case 6:    return 60
        case 7:    return 5 * 60
        default:   return maxLockout
        }
    }

    private static func loadAttempts() -> (failures: Int, lockedUntil: TimeInterval) {
        guard let data = readData(account: attemptsAccount),
              let parts = String(data: data, encoding: .utf8)?.split(separator: "|"),
              parts.count == 2,
              let failures = Int(parts[0]),
              let lockedUntil = TimeInterval(parts[1]) else { return (0, 0) }
        return (failures, lockedUntil)
    }

    // ── ภายใน ──

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static let formatV2: UInt8 = 0x02
    // ตามคำแนะนำ OWASP สำหรับ PBKDF2-SHA256 — ~0.1 วิ/ครั้ง ใส่ PIN ยังลื่น แต่เดาแบบ offline ช้าลงมาก
    private static let pbkdf2Rounds: UInt32 = 600_000

    private static func pbkdf2(_ pin: String) -> Data {
        // salt คงที่ต่อการติดตั้ง (เก็บคู่กับ hash) — สร้างครั้งแรกถ้ายังไม่มี
        let salt = loadOrCreateSalt()
        var derived = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        let status = derived.withUnsafeMutableBytes { out in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pin, pin.utf8.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    pbkdf2Rounds,
                    out.bindMemory(to: UInt8.self).baseAddress, Int(CC_SHA256_DIGEST_LENGTH)
                )
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 failed: \(status)")
        return derived
    }

    // รูปแบบเดิม: SHA-256(salt + PIN) — ใช้ตรวจ PIN เก่าเพื่ออัปเกรดเท่านั้น
    private static func legacyHash(_ pin: String) -> Data {
        var data = loadOrCreateSalt()
        data.append(Data(pin.utf8))
        return Data(SHA256.hash(data: data))
    }

    private static func save(_ digest: Data, slot: Slot) {
        writeData(digest, account: slot.rawValue)
    }

    private static func writeData(_ data: Data, account: String) {
        let query = baseQuery(account)
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private static func load(_ slot: Slot) -> Data? {
        readData(account: slot.rawValue)
    }

    private static func readData(account: String) -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return data
    }

    private static func loadOrCreateSalt() -> Data {
        let saltAccount = Slot.main.rawValue + ".salt"
        if let data = readData(account: saltAccount) { return data }

        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        var attrs = baseQuery(saltAccount)
        attrs[kSecValueData as String] = salt
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
        return salt
    }

    private static func constantTimeEquals(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }
}

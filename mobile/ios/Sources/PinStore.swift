import Foundation
import CryptoKit
import Security

// เก็บ PIN แบบ hash (SHA-256 + salt) ใน Keychain — ปลอดภัยกว่า UserDefaults
// ไม่เก็บ PIN ตรง ๆ ต่อให้เครื่องโดนแงะก็ได้แค่ค่า hash
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
        save(hash(pin), slot: slot)
    }

    static func verify(_ pin: String, slot: Slot = .main) -> Bool {
        guard let stored = load(slot) else { return false }
        // เทียบแบบ constant-time กันการเดา timing
        let candidate = hash(pin)
        return constantTimeEquals(stored, candidate)
    }

    static func clear(_ slot: Slot = .main) {
        SecItemDelete(baseQuery(slot.rawValue) as CFDictionary)
    }

    // ลบ PIN ทั้งหมด (ใช้ตอนปิดการล็อกทั้งระบบ)
    static func clearAll() {
        clear(.main)
        clear(.decoy)
    }

    // ── ภายใน ──

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func hash(_ pin: String) -> Data {
        // salt คงที่ต่อการติดตั้ง (เก็บคู่กับ hash) — สร้างครั้งแรกถ้ายังไม่มี
        var data = loadOrCreateSalt()
        data.append(Data(pin.utf8))
        return Data(SHA256.hash(data: data))
    }

    private static func save(_ digest: Data, slot: Slot) {
        let query = baseQuery(slot.rawValue)
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = digest
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

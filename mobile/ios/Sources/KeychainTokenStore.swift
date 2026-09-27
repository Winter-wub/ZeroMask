import Foundation
import Security

/// Helper class สำหรับบันทึกและอ่าน Token / Endpoint จาก iOS Keychain อย่างปลอดภัย
/// (แยกจาก PinStore ที่ใช้เก็บแบบ one-way SHA-256 hash)
enum KeychainTokenStore {
    private static let service = "com.prachayawut.gallery.tokens"

    enum Key: String {
        case tinderAuthToken = "tinder_auth_token"
        case tinderUpdatesEndpoint = "tinder_updates_endpoint"
        case instagramSessionId = "instagram_session_id"
        case instagramUserId = "instagram_user_id"
        case instagramCsrfToken = "instagram_csrf_token"
    }

    static func save(_ value: String, for key: Key) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        // ลบค่าเดิมก่อนถ้ามีอยู่
        SecItemDelete(query as CFDictionary)

        var newAttributes = query
        newAttributes[kSecValueData as String] = data
        // AfterFirstUnlock: background fetch ต้องอ่านได้ตอนจอล็อก
        // ThisDeviceOnly: ไม่ติดไปกับ backup/ย้ายเครื่อง (token เซสชันไม่ควรออกจากเครื่องนี้)
        newAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemAdd(newAttributes as CFDictionary, nil)
    }

    static func load(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        delete(for: .tinderAuthToken)
        delete(for: .tinderUpdatesEndpoint)
        delete(for: .instagramSessionId)
        delete(for: .instagramUserId)
        delete(for: .instagramCsrfToken)
    }
}

import Foundation
import Security

// TODO: M6 — wire to the Settings sheet's auth section.
enum KeychainService {
    enum Account: String {
        case huggingFace = "huggingface.token"
        case github      = "github.token"
    }

    @discardableResult
    static func set(_ value: String, account: Account) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account.rawValue,
            kSecAttrService as String: "app.osm.downloads"
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ account: Account) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account.rawValue,
            kSecAttrService as String: "app.osm.downloads",
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    @discardableResult
    static func delete(_ account: Account) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account.rawValue,
            kSecAttrService as String: "app.osm.downloads"
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

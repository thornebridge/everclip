import Foundation
import CryptoKit
import Security

/// AES-256-GCM encryption with Keychain-stored key.
/// Key never touches disk or SQLite — lives in macOS Keychain only.
enum VaultCrypto {
    private static let service = "com.thornebridge.everclip.vault"
    private static let encPrefix = "enc:"

    // MARK: - Public API

    static func encrypt(_ plaintext: String) -> String {
        guard !plaintext.isEmpty,
              let data = plaintext.data(using: .utf8),
              let key = getOrCreateKey() else { return plaintext }
        guard let sealed = try? AES.GCM.seal(data, using: key).combined else { return plaintext }
        return encPrefix + sealed.base64EncodedString()
    }

    static func decrypt(_ stored: String) -> String {
        // If not encrypted, return as-is (handles pre-encryption data)
        guard stored.hasPrefix(encPrefix) else { return stored }
        let b64 = String(stored.dropFirst(encPrefix.count))
        guard let data = Data(base64Encoded: b64),
              let key = getOrCreateKey(),
              let box = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(box, using: key) else { return "" }
        return String(data: decrypted, encoding: .utf8) ?? ""
    }

    static func isEncrypted(_ stored: String) -> Bool {
        stored.hasPrefix(encPrefix)
    }

    // MARK: - Keychain Key Management

    private static func getOrCreateKey() -> SymmetricKey? {
        if let existing = readKeyFromKeychain() { return existing }
        let key = SymmetricKey(size: .bits256)
        saveKeyToKeychain(key)
        return key
    }

    private static func readKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "vault-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private static func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "vault-key",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
}

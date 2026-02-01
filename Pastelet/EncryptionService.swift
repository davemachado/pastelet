import Foundation
import CryptoKit
import Security

class EncryptionService {
    private let keychainTag = "drm.Pastelet.encryptionKey"
    private var cachedKey: SymmetricKey?
    
    private let keychainService = "drm.Pastelet"
    private let keychainLabel = "Pastelet Encryption Key"
    
    init() {
        // Do not auto-generate key here, let usage determine valid state
    }
    
    func encrypt(_ data: Data) -> Data? {
        guard let key = getOrGenerateKey() else { return nil }
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("Encryption Error: \(error)")
            return nil
        }
    }
    
    func decrypt(_ data: Data) -> Data? {
        guard let key = getOrGenerateKey() else { return nil }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            // This is expected if data is legacy plaintext or key is wrong
            return nil
        }
    }
    
    func regenerateKey() -> Bool {
        // 1. Generate new Standard Key
        let newKey = SymmetricKey(size: .bits256)
        
        // 2. Save to Keychain (overwrite)
        if saveKeyToKeychain(newKey) {
            self.cachedKey = newKey
            return true
        }
        return false
    }
    
    func hasKeyInKeychain() -> Bool {
        return loadKeyFromKeychain() != nil
    }
    
    // MARK: - Keychain Helpers
    
    private func getOrGenerateKey() -> SymmetricKey? {
        if let key = cachedKey { return key }
        
        // 1. Try to load from Keychain (New Style)
        if let keyData = loadKeyFromKeychain() {
            let key = SymmetricKey(data: keyData)
            self.cachedKey = key
            return key
        }
        
        // 1b. Try to handle "Legacy" key (from the previous iteration without Service/Label)
        // If found, migrate it to the new format so user data isn't lost.
        if let legacyKeyData = loadLegacyKeyFromKeychain() {
            let key = SymmetricKey(data: legacyKeyData)
            // Save in new format
            if saveKeyToKeychain(key) {
                // Delete legacy
                deleteLegacyKey()
                self.cachedKey = key
                return key
            }
        }
        
        // 2. Generate and Save
        let newKey = SymmetricKey(size: .bits256)
        if saveKeyToKeychain(newKey) {
            self.cachedKey = newKey
            return newKey
        }
        
        return nil
    }
    
    private func saveKeyToKeychain(_ key: SymmetricKey) -> Bool {
        // Store as Base64 String Data to be "text-friendly" in Keychain Access
        let keyData = key.withUnsafeBytes { Data($0) }
        let base64Data = keyData.base64EncodedData()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainTag,
            kSecAttrLabel as String: keychainLabel,
            kSecValueData as String: base64Data
        ]
        
        // First delete any existing item matching this service/account
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("EncryptionService: Saved key to Keychain (Service: \(keychainService))")
            return true
        } else {
            print("EncryptionService: Keychain Save Error: \(status)")
            return false
        }
    }
    
    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let retrievedData = dataTypeRef as? Data {
            // Decode Base64
            return Data(base64Encoded: retrievedData)
        }
        return nil
    }
    
    // MARK: - Legacy Migration (Temporary)
    // Handles the brief period where we stored key without Service/Label attributes
    
    private func loadLegacyKeyFromKeychain() -> Data? {
        // Query strictly WITHOUT Service attribute if possible, but matching Account
        // Note: Adding attributes usually narrows search, removing them widens.
        // We want to find the item that HAS account but MAYBE NO service.
        // However, standard query might find multiple.
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    private func deleteLegacyKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTag
        ]
        SecItemDelete(query as CFDictionary)
    }
}

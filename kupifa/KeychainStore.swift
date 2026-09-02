//
//  KeychainStore.swift
//  kupifa
//
//  APIキーをmacOSのKeychainに安全に保存する。
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "com.kupifa.apikeys"
    private static let lock = NSLock()
    /// キー存在でキャッシュ済み。値が nil の場合は「未設定」もキャッシュする
    private static var cache: [AIProvider: String?] = [:]

    static func apiKey(for provider: AIProvider) -> String? {
        lock.lock()
        if let cached = cache[provider] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let value = fetchAPIKey(for: provider)

        lock.lock()
        cache[provider] = value
        lock.unlock()
        return value
    }

    @discardableResult
    static func setAPIKey(_ key: String, for provider: AIProvider) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return deleteAPIKey(for: provider)
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        let data = Data(trimmed.utf8)

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        let ok: Bool
        if updateStatus == errSecSuccess {
            ok = true
        } else if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            ok = SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        } else {
            ok = false
        }

        if ok {
            lock.lock()
            cache[provider] = trimmed
            lock.unlock()
        }
        return ok
    }

    @discardableResult
    static func deleteAPIKey(for provider: AIProvider) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        let ok = status == errSecSuccess || status == errSecItemNotFound
        if ok {
            lock.lock()
            cache.updateValue(nil, forKey: provider)
            lock.unlock()
        }
        return ok
    }

    private static func fetchAPIKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    /// このサービスに保存した API キーをすべて削除する
    static func deleteAllAPIKeys() {
        for provider in AIProvider.allCases {
            _ = deleteAPIKey(for: provider)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}

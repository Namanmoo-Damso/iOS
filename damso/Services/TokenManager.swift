//
//  TokenManager.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation
import Security

/// JWT 토큰 관리자
/// Keychain을 사용하여 토큰을 안전하게 저장/관리합니다
@MainActor
final class TokenManager {
    static let shared = TokenManager()

    private let service = "com.damso.app"
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"

    private init() {
        clearTokensOnFreshInstall()
    }

    /// 앱 재설치 시 Keychain 토큰 클리어
    /// Keychain은 앱 삭제 후에도 남아있으므로, 첫 실행 시 클리어
    private func clearTokensOnFreshInstall() {
        let hasLaunchedKey = "hasLaunchedBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedKey)

        if !hasLaunched {
            debugLog("Fresh install detected - clearing keychain tokens")
            clearTokens()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }
    }

    // MARK: - Access Token

    var accessToken: String? {
        get { getKeychainValue(forKey: accessTokenKey) }
        set {
            if let value = newValue {
                setKeychainValue(value, forKey: accessTokenKey)
            } else {
                deleteKeychainValue(forKey: accessTokenKey)
            }
        }
    }

    // MARK: - Refresh Token

    var refreshToken: String? {
        get { getKeychainValue(forKey: refreshTokenKey) }
        set {
            if let value = newValue {
                setKeychainValue(value, forKey: refreshTokenKey)
            } else {
                deleteKeychainValue(forKey: refreshTokenKey)
            }
        }
    }

    // MARK: - Convenience

    /// 토큰이 존재하는지 확인
    var hasTokens: Bool {
        return accessToken != nil && refreshToken != nil
    }

    /// 모든 토큰 삭제
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        debugLog("All tokens cleared")
    }

    /// 토큰 저장
    func saveTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        debugLog("Tokens saved")
    }

    // MARK: - Keychain Operations

    private func setKeychainValue(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // 기존 값 삭제
        SecItemDelete(query as CFDictionary)

        // 새 값 추가
        var newQuery = query
        newQuery[kSecValueData as String] = data

        let status = SecItemAdd(newQuery as CFDictionary, nil)
        if status != errSecSuccess {
            debugLog("Failed to save \(key): \(status)")
        }
    }

    private func getKeychainValue(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteKeychainValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[TokenManager] \(message)")
        #endif
    }
}

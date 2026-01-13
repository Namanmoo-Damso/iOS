//
//  UserDefaults+Keys.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import Foundation

extension UserDefaults {

    // MARK: - Keys

    enum Keys {
        static let selectedServerDomain = "selectedServerDomain"
        static let pendingLoginUserType = "pendingLoginUserType"
        static let kakaoUserId = "kakao_user_id"
        static let cachedApnsToken = "cached_apns_token"
        static let cachedVoipToken = "cached_voip_token"
        static let legacyAuthToken = "authToken"
        static let permissionOnboardingCompleted = "permission_onboarding_completed"
    }

    // MARK: - Typed Accessors

    var selectedServerDomain: String? {
        get { string(forKey: Keys.selectedServerDomain) }
        set { set(newValue, forKey: Keys.selectedServerDomain) }
    }

    var cachedApnsToken: String? {
        get { string(forKey: Keys.cachedApnsToken) }
        set { set(newValue, forKey: Keys.cachedApnsToken) }
    }

    var cachedVoipToken: String? {
        get { string(forKey: Keys.cachedVoipToken) }
        set { set(newValue, forKey: Keys.cachedVoipToken) }
    }

    var legacyAuthToken: String? {
        get { string(forKey: Keys.legacyAuthToken) }
        set { set(newValue, forKey: Keys.legacyAuthToken) }
    }

    var permissionOnboardingCompleted: Bool {
        get { bool(forKey: Keys.permissionOnboardingCompleted) }
        set { set(newValue, forKey: Keys.permissionOnboardingCompleted) }
    }

    // MARK: - Helper Methods

    func clearLegacyAuthToken() {
        removeObject(forKey: Keys.legacyAuthToken)
    }

    func clearPendingLoginUserType() {
        removeObject(forKey: Keys.pendingLoginUserType)
    }
}

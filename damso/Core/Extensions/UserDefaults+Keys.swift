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
        static let userIdentity = "user_identity"
        static let cachedApnsToken = "cached_apns_token"
        static let cachedVoipToken = "cached_voip_token"
        static let legacyAuthToken = "authToken"
    }

    // MARK: - Typed Accessors

    var selectedServerDomain: String? {
        get { string(forKey: Keys.selectedServerDomain) }
        set { set(newValue, forKey: Keys.selectedServerDomain) }
    }

    var userIdentity: String? {
        get { string(forKey: Keys.userIdentity) }
        set { set(newValue, forKey: Keys.userIdentity) }
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

    // MARK: - Helper Methods

    func clearLegacyAuthToken() {
        removeObject(forKey: Keys.legacyAuthToken)
    }

    func clearPendingLoginUserType() {
        removeObject(forKey: Keys.pendingLoginUserType)
    }
}

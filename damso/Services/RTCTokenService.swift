//
//  RTCTokenService.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import Foundation

/// RTC 토큰 관리 서비스
@MainActor
final class RTCTokenService: RTCTokenProtocol {

    // MARK: - Singleton

    static let shared = RTCTokenService()

    // MARK: - Properties

    private var apnsEnv: String {
        #if DEBUG
        return "sandbox"
        #else
        return "prod"
        #endif
    }

    private init() {}

    // MARK: - Public Methods

    /// LiveKit 접속용 토큰 발급
    func fetchLiveKitToken(roomName: String) async throws -> String {
        // JWT 토큰이 있으면 JWT 사용, 없으면 익명 토큰 사용
        let authToken: String
        if let jwtToken = TokenManager.shared.accessToken {
            authToken = jwtToken
        } else {
            var legacyToken = UserDefaults.standard.legacyAuthToken
            if legacyToken == nil || legacyToken?.isEmpty == true {
                legacyToken = try await fetchApiToken()
            }
            guard let token = legacyToken else {
                throw TokenError.missingAuthToken
            }
            authToken = token
        }

        guard let tokenEndpoint = URL(string: "\(AppConfig.apiBaseURL)/v1/rtc/token") else {
            throw TokenError.networkError("Invalid token URL")
        }

        var request = URLRequest(url: tokenEndpoint, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.tokenRefresh)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let identity = stableIdentity()
        let cachedApns = UserDefaults.standard.cachedApnsToken
        let cachedVoip = UserDefaults.standard.cachedVoipToken

        let supportsCallKit = resolveCallCapability() == .callKit

        var body: [String: Any] = [
            "roomName": roomName,
            "identity": identity,
            "name": "iOS User",
            "role": "viewer",
            "platform": "ios",
            "env": apnsEnv,
            "supportsCallKit": supportsCallKit
        ]

        if let cachedApns, !cachedApns.isEmpty {
            body["apnsToken"] = cachedApns
        }
        if supportsCallKit, let cachedVoip, !cachedVoip.isEmpty {
            body["voipToken"] = cachedVoip
        }

        let data: Data
        let response: URLResponse

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TokenError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // JWT 토큰이 만료되었을 수 있음 - 갱신 시도
            if TokenManager.shared.hasTokens {
                do {
                    _ = try await AuthService.shared.refreshToken()
                    // 재시도
                    return try await fetchLiveKitToken(roomName: roomName)
                } catch {
                    Log.auth.e("Token refresh failed: \(error)")
                }
            }
            UserDefaults.standard.clearLegacyAuthToken()
            throw TokenError.httpStatus(code: 401, body: "Unauthorized - Token might be expired")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TokenError.httpStatus(code: httpResponse.statusCode, body: body)
        }

        let rawResponse = String(data: data, encoding: .utf8) ?? "(no data)"
        print("🎫 [Token] Raw response: \(rawResponse.prefix(200))...")

        let token = try parseToken(from: data)
        print("🎫 [Token] Parsed token length: \(token.count)")
        return token
    }

    /// 익명 API 토큰 발급 (Legacy)
    func fetchApiToken() async throws -> String {
        let identity = stableIdentity()
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/anonymous") else {
            throw TokenError.networkError("Invalid auth URL")
        }

        var req = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.tokenRefresh)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "identity": identity,
                "displayName": "iOS User"
            ])
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw TokenError.networkError(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse {
            if !(200..<300).contains(httpResponse.statusCode) {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw TokenError.httpStatus(code: httpResponse.statusCode, body: bodyText)
            }
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["accessToken"] as? String else {
                throw TokenError.missingToken
            }
            UserDefaults.standard.legacyAuthToken = token
            Log.auth.i("API token stored")
            return token
        } catch {
            if let tokenErr = error as? TokenError { throw tokenErr }
            throw TokenError.networkError("JSON Parsing Error")
        }
    }

    // MARK: - Private Helpers

    private func parseToken(from data: Data) throws -> String {
        if let raw = String(data: data, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.first != "{", trimmed.first != "[" {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        struct TokenEnvelope: Decodable {
            let token: String?
            let accessToken: String?
            let data: Nested?
            let result: Nested?

            struct Nested: Decodable {
                let token: String?
                let accessToken: String?
            }
        }

        let response: TokenEnvelope
        do {
            response = try JSONDecoder().decode(TokenEnvelope.self, from: data)
        } catch {
            throw TokenError.networkError("JSON Decode Failed")
        }

        if let t = response.token { return t }
        if let t = response.accessToken { return t }
        if let t = response.data?.token { return t }
        if let t = response.data?.accessToken { return t }
        if let t = response.result?.token { return t }
        if let t = response.result?.accessToken { return t }

        throw TokenError.missingToken
    }

    private func stableIdentity() -> String {
        if let stored = UserDefaults.standard.userIdentity {
            return stored
        }
        let newIdentity = "ios-\(UUID().uuidString)"
        UserDefaults.standard.userIdentity = newIdentity
        return newIdentity
    }
}

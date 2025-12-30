//
//  AuthService.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation
import Combine
import os

enum AuthError: LocalizedError {
    case missingAuthToken
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case missingToken
    case networkError(String)
    case decodingError(String)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "인증 토큰이 없습니다."
        case .invalidResponse:
            return "잘못된 응답입니다."
        case let .httpStatus(code, body):
            if body.isEmpty {
                return "API 요청 실패 (상태 코드: \(code))"
            }
            return "API 요청 실패 (\(code)): \(body)"
        case .missingToken:
            return "응답에 토큰이 없습니다."
        case let .networkError(msg):
            return "네트워크 오류: \(msg)"
        case let .decodingError(msg):
            return "디코딩 오류: \(msg)"
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .unknown:
            return "알 수 없는 오류가 발생했습니다."
        }
    }
}

// MARK: - Legacy TokenError (호환성 유지)

enum TokenError: LocalizedError {
    case missingAuthToken
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case missingToken
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "Missing API auth token. Store it in UserDefaults with key 'authToken'."
        case .invalidResponse:
            return "Invalid token response."
        case let .httpStatus(code, body):
            if body.isEmpty {
                return "Token API failed with status \(code)."
            }
            return "Token API failed (\(code)): \(body)"
        case .missingToken:
            return "Token is missing in API response."
        case let .networkError(msg):
            return "Network Error: \(msg)"
        }
    }
}

// MARK: - AuthService

@MainActor
final class AuthService: AuthServiceProtocol {

    // MARK: - Singleton

    static let shared = AuthService()

    // MARK: - Properties

    private let legacyAuthTokenKey = "authToken"
    private let identityKey = "user_identity"
    private let apnsKey = "cached_apns_token"
    private let voipKey = "cached_voip_token"

    private var apnsEnv: String {
        #if DEBUG
        return "sandbox"
        #else
        return "prod"
        #endif
    }

    /// 현재 로그인 상태
    var isLoggedIn: Bool {
        TokenManager.shared.hasTokens
    }

    // MARK: - Kakao Login + JWT

    /// 카카오 로그인 + 서버 JWT 발급
    /// - Parameters:
    ///   - kakaoAccessToken: 카카오 액세스 토큰
    ///   - kakaoUserInfo: 카카오 사용자 정보 (nickname, email 등)
    ///   - userType: 사용자 타입 (nil이면 서버에서 null로 저장, 추후 업데이트)
    func loginWithKakao(kakaoAccessToken: String, kakaoUserInfo: KakaoUserInfo? = nil, userType: UserType? = nil) async throws -> AuthResponse {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/kakao") else {
            throw AuthError.networkError("Invalid auth URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "kakaoAccessToken": kakaoAccessToken
        ]

        // 카카오 사용자 정보 추가 (서버에서 DB 저장용)
        if let userInfo = kakaoUserInfo {
            if let nickname = userInfo.nickname {
                body["nickname"] = nickname
            }
            if let email = userInfo.email {
                body["email"] = email
            }
            if let profileImageUrl = userInfo.profileImageUrl {
                body["profileImageUrl"] = profileImageUrl.absoluteString
            }
        }

        // userType이 있으면 추가 (기존 호환성)
        if let userType = userType {
            body["userType"] = userType.rawValue
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AuthError.networkError("Request body encoding failed")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        // 서버 응답 디버그 로그
        if let rawJSON = String(data: data, encoding: .utf8) {
            Log.auth.d("서버 응답 (raw): \(rawJSON)")
        }

        do {
            Log.auth.d("AuthResponse 디코딩 시작...")
            let authResponse = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: data)
            Log.auth.d("AuthResponse 디코딩 성공!")
            Log.auth.d("- isNewUser: \(authResponse.isNewUser ?? false)")
            Log.auth.d("- hasAccessToken: \(authResponse.accessToken != nil)")
            Log.auth.d("- hasRefreshToken: \(authResponse.refreshToken != nil)")
            Log.auth.d("- hasUser: \(authResponse.user != nil)")
            if let user = authResponse.user {
                Log.auth.d("- user.id: \(user.id)")
                Log.auth.d("- user.nickname: \(user.nickname ?? "nil")")
                Log.auth.d("- user.userType: \(user.userType?.rawValue ?? "nil")")
            }

            // 신규 사용자가 아닌 경우에만 토큰 저장
            if !authResponse.isNewUserFlag {
                if let accessToken = authResponse.accessToken,
                   let refreshToken = authResponse.refreshToken {
                    TokenManager.shared.saveTokens(
                        access: accessToken,
                        refresh: refreshToken
                    )
                    Log.auth.i("Login successful, tokens saved")
                } else {
                    Log.auth.w("Login successful but missing tokens in response")
                }
            } else {
                Log.auth.i("New user detected, tempToken provided (registration required)")
            }

            return authResponse
        } catch {
            Log.auth.e("AuthResponse 디코딩 실패!")
            Log.auth.e("Decoding error: \(error)")
            // 더 상세한 에러 정보
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    Log.auth.e("Missing key: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue })")
                case .typeMismatch(let type, let context):
                    Log.auth.e("Type mismatch: \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    Log.auth.e("Value not found: \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .dataCorrupted(let context):
                    Log.auth.e("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    break
                }
            }
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    /// 토큰 갱신
    func refreshToken() async throws -> TokenRefreshResponse {
        guard let refreshToken = TokenManager.shared.refreshToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/refresh") else {
            throw AuthError.networkError("Invalid refresh URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AuthError.networkError("Request body encoding failed")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Refresh token도 만료됨 - 로그아웃 처리
            await logout()
            throw AuthError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        do {
            let tokenResponse = try JSONDecoder.apiDecoder.decode(TokenRefreshResponse.self, from: data)

            // 새 토큰 저장
            TokenManager.shared.saveTokens(
                access: tokenResponse.accessToken,
                refresh: tokenResponse.refreshToken
            )

            Log.auth.i("Token refreshed successfully")
            return tokenResponse
        } catch {
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    /// 로그아웃
    func logout() async {
        TokenManager.shared.clearTokens()
        UserDefaults.standard.removeObject(forKey: legacyAuthTokenKey)
        Log.auth.i("Logged out, all tokens cleared")
    }

    /// 회원탈퇴
    func deleteUser() async throws {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/me") else {
            throw AuthError.networkError("Invalid user URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        // 로컬 토큰 정리
        TokenManager.shared.clearTokens()
        UserDefaults.standard.removeObject(forKey: legacyAuthTokenKey)

        Log.auth.i("User deleted successfully")
    }

    /// 현재 사용자 정보 조회
    func getMe() async throws -> UserMeResponse {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/me") else {
            throw AuthError.networkError("Invalid user URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        do {
            let userResponse = try JSONDecoder.apiDecoder.decode(UserMeResponse.self, from: data)
            Log.auth.i("User info fetched: \(userResponse.nickname ?? "nil")")
            return userResponse
        } catch {
            Log.auth.e("Decoding error: \(error)")
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    /// 보호자 등록
    /// - Parameters:
    ///   - wardEmail: 어르신 이메일
    ///   - wardPhoneNumber: 어르신 전화번호
    ///   - tempToken: 신규 사용자 등록용 임시 토큰 (카카오 로그인 응답에서 받음)
    func registerGuardian(wardEmail: String, wardPhoneNumber: String, tempToken: String? = nil) async throws -> GuardianRegistrationResponse {
        // tempToken이 있으면 사용, 없으면 기존 accessToken 사용
        let authToken: String
        if let tempToken = tempToken {
            authToken = tempToken
        } else if let accessToken = TokenManager.shared.accessToken {
            authToken = accessToken
        } else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/register/guardian") else {
            throw AuthError.networkError("Invalid registration URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "wardEmail": wardEmail,
            "wardPhoneNumber": wardPhoneNumber
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AuthError.networkError("Request body encoding failed")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        // 디버그: 서버 응답 확인
        if let rawJSON = String(data: data, encoding: .utf8) {
            Log.auth.d("Guardian registration 서버 응답 (raw): \(rawJSON)")
        }

        do {
            let registrationResponse = try JSONDecoder.apiDecoder.decode(GuardianRegistrationResponse.self, from: data)
            Log.auth.i("Guardian registered: \(registrationResponse.resolvedGuardianId)")

            // 응답에 토큰이 있으면 저장
            if let accessToken = registrationResponse.accessToken,
               let refreshToken = registrationResponse.refreshToken {
                TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
                Log.auth.i("Registration tokens saved")
            }

            return registrationResponse
        } catch {
            Log.auth.e("Decoding error: \(error)")
            // 더 상세한 에러 정보
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    Log.auth.e("Missing key: \(key.stringValue), path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    Log.auth.e("Type mismatch: \(type), path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    Log.auth.e("Value not found: \(type), path: \(context.codingPath)")
                default:
                    break
                }
            }
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Legacy Methods (익명 인증 - 기존 호환성)

    func fetchApiToken() async throws(TokenError) -> String {
        let identity = stableIdentity()
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/anonymous") else {
            throw .networkError("Invalid auth URL")
        }

        var req = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
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
            throw .networkError(error.localizedDescription)
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
            UserDefaults.standard.set(token, forKey: legacyAuthTokenKey)
            Log.auth.i("API token stored")
            return token
        } catch {
            if let tokenErr = error as? TokenError { throw tokenErr }
            throw .networkError("JSON Parsing Error")
        }
    }

    func fetchLiveKitToken(roomName: String) async throws(TokenError) -> String {
        // JWT 토큰이 있으면 JWT 사용, 없으면 익명 토큰 사용
        let authToken: String
        if let jwtToken = TokenManager.shared.accessToken {
            authToken = jwtToken
        } else {
            var legacyToken = UserDefaults.standard.string(forKey: legacyAuthTokenKey)
            if legacyToken == nil || legacyToken?.isEmpty == true {
                legacyToken = try await fetchApiToken()
            }
            guard let token = legacyToken else {
                throw .missingAuthToken
            }
            authToken = token
        }

        guard let tokenEndpoint = URL(string: "\(AppConfig.apiBaseURL)/v1/rtc/token") else {
            throw .networkError("Invalid token URL")
        }

        var request = URLRequest(url: tokenEndpoint, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let identity = stableIdentity()
        let cachedApns = UserDefaults.standard.string(forKey: apnsKey)
        let cachedVoip = UserDefaults.standard.string(forKey: voipKey)

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
            throw .networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // JWT 토큰이 만료되었을 수 있음 - 갱신 시도
            if TokenManager.shared.hasTokens {
                do {
                    _ = try await refreshToken()
                    // 재시도
                    return try await fetchLiveKitToken(roomName: roomName)
                } catch {
                    Log.auth.e("Token refresh failed: \(error)")
                }
            }
            UserDefaults.standard.removeObject(forKey: legacyAuthTokenKey)
            throw TokenError.httpStatus(code: 401, body: "Unauthorized - Token might be expired")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TokenError.httpStatus(code: httpResponse.statusCode, body: body)
        }

        return try parseToken(from: data)
    }

    // MARK: - Private Helpers

    private func parseToken(from data: Data) throws(TokenError) -> String {
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
            throw .networkError("JSON Decode Failed")
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
        if let stored = UserDefaults.standard.string(forKey: identityKey) {
            return stored
        }
        let newIdentity = "ios-\(UUID().uuidString)"
        UserDefaults.standard.set(newIdentity, forKey: identityKey)
        return newIdentity
    }

}

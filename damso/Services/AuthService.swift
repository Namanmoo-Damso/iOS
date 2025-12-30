//
//  AuthService.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation
import Combine

// MARK: - AuthService

@MainActor
final class AuthService: AuthServiceProtocol {

    // MARK: - Singleton

    static let shared = AuthService()

    // MARK: - Properties

    /// 현재 로그인 상태
    var isLoggedIn: Bool {
        TokenManager.shared.hasTokens
    }

    init() {}

    // MARK: - Kakao Login + JWT

    /// 카카오 로그인 + 서버 JWT 발급
    func loginWithKakao(kakaoAccessToken: String, kakaoUserInfo: KakaoUserInfo? = nil, userType: UserType? = nil) async throws -> AuthResponse {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/kakao") else {
            throw AuthError.networkError("Invalid auth URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "kakaoAccessToken": kakaoAccessToken
        ]

        // 카카오 사용자 정보 추가
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

        // userType 추가
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

        // 디버그 로그
        if let rawJSON = String(data: data, encoding: .utf8) {
            Log.auth.d("서버 응답 (raw): \(rawJSON)")
        }

        do {
            let authResponse = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: data)
            logAuthResponse(authResponse)

            // 토큰 저장
            if let accessToken = authResponse.accessToken,
               let refreshToken = authResponse.refreshToken {
                TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
                Log.auth.i("Login successful, tokens saved (isNewUser: \(authResponse.isNewUserFlag))")
            } else {
                Log.auth.w("Login successful but missing tokens in response")
            }

            return authResponse
        } catch {
            logDecodingError(error)
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

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.tokenRefresh)
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
            await logout()
            throw AuthError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        do {
            let tokenResponse = try JSONDecoder.apiDecoder.decode(TokenRefreshResponse.self, from: data)
            TokenManager.shared.saveTokens(access: tokenResponse.accessToken, refresh: tokenResponse.refreshToken)
            Log.auth.i("Token refreshed successfully")
            return tokenResponse
        } catch {
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    /// 로그아웃
    func logout() async {
        TokenManager.shared.clearTokens()
        UserDefaults.standard.clearLegacyAuthToken()
        Log.auth.i("Logged out, all tokens cleared")
    }

    // MARK: - AuthServiceProtocol Conformance (Delegation)

    func fetchApiToken() async throws -> String {
        try await RTCTokenService.shared.fetchApiToken()
    }

    func fetchLiveKitToken(roomName: String) async throws -> String {
        try await RTCTokenService.shared.fetchLiveKitToken(roomName: roomName)
    }

    func getMe() async throws -> UserMeResponse {
        try await UserService.shared.getMe()
    }

    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse {
        try await RegistrationService.shared.registerGuardian(wardEmail: wardEmail, wardPhoneNumber: wardPhoneNumber)
    }

    func deleteUser() async throws {
        try await UserService.shared.deleteUser()
    }

    // MARK: - Private Helpers

    private func logAuthResponse(_ response: AuthResponse) {
        Log.auth.d("AuthResponse 디코딩 성공!")
        Log.auth.d("- isNewUser: \(response.isNewUser ?? false)")
        Log.auth.d("- hasAccessToken: \(response.accessToken != nil)")
        Log.auth.d("- hasRefreshToken: \(response.refreshToken != nil)")
        Log.auth.d("- hasUser: \(response.user != nil)")
        if let user = response.user {
            Log.auth.d("- user.id: \(user.id)")
            Log.auth.d("- user.nickname: \(user.nickname ?? "nil")")
            Log.auth.d("- user.userType: \(user.userType?.rawValue ?? "nil")")
        }
    }

    private func logDecodingError(_ error: Error) {
        Log.auth.e("AuthResponse 디코딩 실패!")
        Log.auth.e("Decoding error: \(error)")

        guard let decodingError = error as? DecodingError else { return }

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
}

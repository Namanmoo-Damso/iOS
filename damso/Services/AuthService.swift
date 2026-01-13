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
        Log.auth.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.auth.i("🔐 loginWithKakao 시작")
        Log.auth.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.auth.i("userType: \(userType?.rawValue ?? "nil")")
        Log.auth.i("kakaoAccessToken: \(String(kakaoAccessToken.prefix(20)))...")
        Log.auth.i("nickname: \(kakaoUserInfo?.nickname ?? "nil")")
        Log.auth.i("email: \(kakaoUserInfo?.email ?? "nil")")

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/kakao") else {
            Log.auth.e("❌ Invalid auth URL")
            throw AuthError.networkError("Invalid auth URL")
        }
        Log.auth.i("📡 요청 URL: \(url.absoluteString)")

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

        Log.auth.i("📤 요청 body: \(body.filter { $0.key != "kakaoAccessToken" })")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            Log.auth.e("❌ Request body encoding failed: \(error)")
            throw AuthError.networkError("Request body encoding failed")
        }

        let data: Data
        let response: URLResponse

        Log.auth.i("📡 서버 요청 시작...")
        do {
            (data, response) = try await URLSession.shared.data(for: request)
            Log.auth.i("📡 서버 응답 수신 완료")
        } catch {
            Log.auth.e("❌ 네트워크 요청 실패: \(error)")
            Log.auth.e("❌ 에러 타입: \(type(of: error))")
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Log.auth.e("❌ 응답이 HTTPURLResponse가 아님")
            throw AuthError.invalidResponse
        }

        Log.auth.i("📡 HTTP 상태 코드: \(httpResponse.statusCode)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Log.auth.e("❌ HTTP 에러 응답")
            Log.auth.e("❌ 상태 코드: \(httpResponse.statusCode)")
            Log.auth.e("❌ 응답 본문: \(bodyText)")
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        // 디버그 로그
        if let rawJSON = String(data: data, encoding: .utf8) {
            Log.auth.d("✅ 서버 응답 (raw): \(rawJSON)")
        }

        do {
            let authResponse = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: data)
            logAuthResponse(authResponse)

            // 토큰 저장
            if let accessToken = authResponse.accessToken,
               let refreshToken = authResponse.refreshToken {
                TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
                Log.auth.i("Login successful, tokens saved (isNewUser: \(authResponse.isNewUserFlag))")

                // 캐시된 푸시 토큰으로 디바이스 재등록
                Task {
                    try? await PushNotificationService.shared.registerDeviceTokens(
                        apnsToken: UserDefaults.standard.cachedApnsToken,
                        voipToken: UserDefaults.standard.cachedVoipToken
                    )
                }
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
            "refreshToken": refreshToken
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
        // 서버에 로그아웃 요청 (room_members, devices, refresh_tokens 정리)
        if let accessToken = TokenManager.shared.accessToken {
            await callServerLogout(accessToken: accessToken)
        }

        TokenManager.shared.clearTokens()
        UserDefaults.standard.clearLegacyAuthToken()
        Log.auth.i("Logged out, all tokens cleared")
    }

    /// 서버 로그아웃 API 호출
    private func callServerLogout(accessToken: String) async {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/logout") else {
            Log.auth.w("Invalid logout URL")
            return
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200..<300).contains(httpResponse.statusCode) {
                    Log.auth.i("Server logout successful")
                } else {
                    Log.auth.w("Server logout failed: \(httpResponse.statusCode)")
                }
            }
        } catch {
            // 서버 로그아웃 실패해도 로컬 토큰은 삭제 진행
            Log.auth.w("Server logout request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - AuthServiceProtocol Conformance (Delegation)

    func fetchLiveKitToken(roomName: String) async throws -> String {
        try await RTCTokenService.shared.fetchLiveKitToken(roomName: roomName)
    }

    func getMe() async throws -> UserMeResponse {
        try await UserService.shared.getMe()
    }

    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse {
        try await RegistrationService.shared.registerGuardian(wardEmail: wardEmail, wardPhoneNumber: wardPhoneNumber)
    }

    func registerGuardian(
        wardEmail: String,
        wardPhoneNumber: String,
        wardBasicInfo: WardBasicInfo?,
        aiCareInfo: AICarInfo?,
        callSchedule: AICallSchedule?
    ) async throws -> GuardianRegistrationResponse {
        try await RegistrationService.shared.registerGuardian(
            wardEmail: wardEmail,
            wardPhoneNumber: wardPhoneNumber,
            wardBasicInfo: wardBasicInfo,
            aiCareInfo: aiCareInfo,
            callSchedule: callSchedule
        )
    }

    func deleteUser() async throws {
        try await UserService.shared.deleteUser()
    }

    // MARK: - 개발용 로그인 (카카오 로그인 없이)

    /// 개발용 로그인 API - 이미 등록된 보호자면 토큰만 발급
    /// - Returns: AuthResponse (isNewUser로 등록 필요 여부 확인)
    /// - Note: 개발 환경에서만 동작 (production에서는 403)
    func devLogin(developerName: String) async throws -> AuthResponse {
        let wardEmail = AppConfig.selectedDevWardEmail
        Log.auth.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.auth.i("🔧 devLogin 시작 (개발용)")
        Log.auth.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.auth.i("developerName: \(developerName), wardEmail: \(wardEmail)")

        guard !wardEmail.isEmpty else {
            Log.auth.e("❌ 선택된 개발자의 wardEmail이 없음")
            throw AuthError.networkError("개발자를 먼저 선택해주세요")
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/dev/guardian") else {
            throw AuthError.networkError("Invalid dev login URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "wardEmail": wardEmail
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            Log.auth.e("❌ Request body encoding failed: \(error)")
            throw AuthError.networkError("Request body encoding failed")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Log.auth.e("❌ 네트워크 요청 실패: \(error)")
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        Log.auth.i("📡 응답 상태 코드: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 403 {
            Log.auth.e("❌ 개발용 API는 production에서 사용 불가")
            throw AuthError.httpStatus(code: 403, body: "개발용 API는 production 환경에서 사용할 수 없습니다.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Log.auth.e("❌ HTTP 에러: \(httpResponse.statusCode), body: \(bodyText)")
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        // 응답 파싱
        let authResponse: AuthResponse
        do {
            authResponse = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: data)
            logAuthResponse(authResponse)
        } catch {
            logDecodingError(error)
            throw AuthError.decodingError(error.localizedDescription)
        }

        // 토큰 저장 (이미 등록된 사용자인 경우)
        if !authResponse.isNewUserFlag,
           let accessToken = authResponse.accessToken,
           let refreshToken = authResponse.refreshToken {
            TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
            Log.auth.i("✅ 개발용 로그인 토큰 저장 완료")

            // 캐시된 푸시 토큰으로 디바이스 재등록
            Task {
                try? await PushNotificationService.shared.registerDeviceTokens(
                    apnsToken: UserDefaults.standard.cachedApnsToken,
                    voipToken: UserDefaults.standard.cachedVoipToken
                )
            }
        }

        return authResponse
    }

    // MARK: - 개발용 보호자 등록 (카카오 로그인 없이)

    /// 개발용 보호자 등록 API - 카카오 로그인 없이 토큰 발급
    /// - Note: 개발 환경에서만 동작 (production에서는 403)
    func registerDevGuardian(
        wardEmail: String,
        wardPhoneNumber: String,
        wardBasicInfo: WardBasicInfo?,
        aiCareInfo: AICarInfo?,
        callSchedule: AICallSchedule?,
        guardianNickname: String? = nil,
        guardianEmail: String? = nil
    ) async throws -> AuthResponse {
        Log.auth.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.auth.i("🔧 registerDevGuardian 시작 (개발용)")
        Log.auth.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/dev/guardian") else {
            throw AuthError.networkError("Invalid dev guardian URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "wardEmail": wardEmail,
            "wardPhoneNumber": wardPhoneNumber
        ]

        // wardBasicInfo
        if let basicInfo = wardBasicInfo {
            body["wardBasicInfo"] = [
                "name": basicInfo.name,
                "relation": basicInfo.relation.rawValue,
                "birthDate": basicInfo.birthDate,
                "gender": basicInfo.gender.rawValue,
                "address": basicInfo.address
            ]
        }

        // aiCareInfo
        if let careInfo = aiCareInfo {
            body["aiCareInfo"] = [
                "medicalConditions": careInfo.medicalConditions,
                "medications": careInfo.medications
            ]
        }

        // callSchedule
        if let schedule = callSchedule {
            let items = schedule.items.map { item -> [String: Any] in
                [
                    "time": item.timeString,
                    "weekdays": item.weekdays.map { $0.rawValue },
                    "isEnabled": item.isEnabled
                ]
            }
            body["callSchedule"] = [
                "isEnabled": schedule.isEnabled,
                "items": items
            ]
        }

        // 보호자 정보 (선택)
        if let nickname = guardianNickname {
            body["nickname"] = nickname
        }
        if let email = guardianEmail {
            body["email"] = email
        }

        Log.auth.i("📤 요청 body: \(body)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            Log.auth.e("❌ Request body encoding failed: \(error)")
            throw AuthError.networkError("Request body encoding failed")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Log.auth.e("❌ 네트워크 요청 실패: \(error)")
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        Log.auth.i("📡 응답 상태 코드: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 403 {
            Log.auth.e("❌ 개발용 API는 production에서 사용 불가")
            throw AuthError.httpStatus(code: 403, body: "개발용 API는 production 환경에서 사용할 수 없습니다.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Log.auth.e("❌ HTTP 에러: \(httpResponse.statusCode), body: \(bodyText)")
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        // 응답 파싱
        let authResponse: AuthResponse
        do {
            authResponse = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: data)
            logAuthResponse(authResponse)
        } catch {
            logDecodingError(error)
            throw AuthError.decodingError(error.localizedDescription)
        }

        // 토큰 저장
        if let accessToken = authResponse.accessToken,
           let refreshToken = authResponse.refreshToken {
            TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
            Log.auth.i("✅ 개발용 토큰 저장 완료")
        }

        return authResponse
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

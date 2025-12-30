//
//  RegistrationService.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import Foundation

/// 등록 서비스 프로토콜
protocol RegistrationServiceProtocol {
    /// 보호자 등록
    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse
}

/// 사용자 등록 관리 서비스
@MainActor
final class RegistrationService: RegistrationServiceProtocol {

    // MARK: - Singleton

    static let shared = RegistrationService()

    private init() {}

    // MARK: - Public Methods

    /// 보호자 등록
    /// - Parameters:
    ///   - wardEmail: 어르신 이메일
    ///   - wardPhoneNumber: 어르신 전화번호
    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse {
        guard let authToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/register/guardian") else {
            throw AuthError.networkError("Invalid registration URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
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
            logDecodingError(error)
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func logDecodingError(_ error: Error) {
        guard let decodingError = error as? DecodingError else { return }

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
}

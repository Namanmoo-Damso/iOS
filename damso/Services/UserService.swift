//
//  UserService.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import Foundation

/// 사용자 정보 관리 서비스
@MainActor
final class UserService: UserInfoProtocol {

    // MARK: - Singleton

    static let shared = UserService()

    private init() {}

    // MARK: - Public Methods

    /// 현재 사용자 정보 조회
    func getMe() async throws -> UserMeResponse {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/me") else {
            throw AuthError.networkError("Invalid user URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.tokenRefresh)
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

    /// 회원탈퇴
    func deleteUser() async throws {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/me") else {
            throw AuthError.networkError("Invalid user URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
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
        UserDefaults.standard.clearLegacyAuthToken()

        Log.auth.i("User deleted successfully")
    }
}

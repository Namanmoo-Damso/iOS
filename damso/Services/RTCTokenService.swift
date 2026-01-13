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
        // JWT 토큰 필수 (카카오 로그인 후에만 통화 가능)
        guard let authToken = TokenManager.shared.accessToken else {
            Log.auth.e("No JWT token - user must be logged in via Kakao")
            throw TokenError.missingAuthToken
        }

        guard let tokenEndpoint = URL(string: "\(AppConfig.apiBaseURL)/v1/rtc/token") else {
            throw TokenError.networkError("Invalid token URL")
        }

        var request = URLRequest(url: tokenEndpoint, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.tokenRefresh)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        // identity는 서버가 JWT에서 추출하므로 body에 포함하지 않음
        let cachedApns = UserDefaults.standard.cachedApnsToken
        let cachedVoip = UserDefaults.standard.cachedVoipToken

        let supportsCallKit = resolveCallCapability() == .callKit

        var body: [String: Any] = [
            "roomName": roomName,
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
            throw TokenError.httpStatus(code: 401, body: "Unauthorized - Token might be expired")
        }
        
        // 503 (서버 용량 초과) 또는 409 (이미 통화 중) 에러 처리
        if httpResponse.statusCode == 503 || httpResponse.statusCode == 409 {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data),
               let errorCode = errorResponse.error?.code {
                switch errorCode {
                case APIErrorCode.serverAtCapacity.rawValue:
                    Log.livekit.e("Server at capacity - too many concurrent calls")
                    throw TokenError.serverAtCapacity
                case APIErrorCode.callAlreadyActive.rawValue:
                    Log.livekit.e("Call already active for this user")
                    throw TokenError.callAlreadyActive
                default:
                    break
                }
            }
            // 에러 코드 파싱 실패 시 기본 처리
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TokenError.httpStatus(code: httpResponse.statusCode, body: body)
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
    
    /// LiveKit 토큰 발급 (재시도 로직 포함)
    /// - Parameters:
    ///   - roomName: 방 이름
    ///   - maxRetries: 최대 재시도 횟수 (기본값: 3)
    ///   - retryDelay: 재시도 간격 (초, 기본값: 2.0)
    /// - Returns: LiveKit 토큰
    func fetchLiveKitTokenWithRetry(
        roomName: String,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0
    ) async throws -> String {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await fetchLiveKitToken(roomName: roomName)
            } catch let error as TokenError {
                lastError = error
                
                // 재시도 가능한 에러인 경우에만 재시도
                if error.isRetryable && attempt < maxRetries {
                    Log.livekit.i("Token fetch failed (attempt \(attempt)/\(maxRetries)), retrying in \(retryDelay)s...")
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }
                
                throw error
            } catch {
                lastError = error
                throw error
            }
        }
        
        throw lastError ?? TokenError.networkError("Max retries exceeded")
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
            let livekitUrl: String?
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

        // livekitUrl이 있으면 저장 (LiveKitService에서 사용)
        if let livekitUrl = response.livekitUrl, !livekitUrl.isEmpty {
            UserDefaults.standard.set(livekitUrl, forKey: "cachedLiveKitUrl")
            print("🎫 [Token] Cached livekitUrl: \(livekitUrl)")
        }

        if let t = response.token { return t }
        if let t = response.accessToken { return t }
        if let t = response.data?.token { return t }
        if let t = response.data?.accessToken { return t }
        if let t = response.result?.token { return t }
        if let t = response.result?.accessToken { return t }

        throw TokenError.missingToken
    }
}

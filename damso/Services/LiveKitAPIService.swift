//
//  LiveKitAPIService.swift
//  damso
//
//  Created by Claude Code on 2025-01-16.
//

import Foundation

/// LiveKit 관리 API 서비스
/// Bot 생성, Agent 음소거, 위험 상태 설정 등 LiveKit 제어 API 호출 담당
@MainActor
final class LiveKitAPIService: LiveKitAPIServiceProtocol {

    // MARK: - Singleton

    static let shared = LiveKitAPIService()

    // MARK: - Properties

    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Constants

    private enum Endpoints {
        static let createBot = "/v1/livekit/create-bot"
        static func muteAgent(roomName: String) -> String {
            return "/v1/livekit/rooms/\(roomName)/mute-agent"
        }
        static func danger(roomName: String) -> String {
            return "/v1/livekit/rooms/\(roomName)/danger"
        }
    }

    private enum Timeout {
        static let standard: TimeInterval = 30.0
    }

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Timeout.standard
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder.apiDecoder
    }

    // MARK: - Public Methods

    /// Bot 생성 및 Agent 시작
    func createBot() async throws -> CreateBotResponse {
        let url = try buildURL(path: Endpoints.createBot)
        var request = try buildRequest(url: url, method: "POST")

        // Body는 빈 객체 (서버가 JWT에서 사용자 정보 추출)
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])

        return try await executeRequest(request)
    }

    /// Agent 음소거 설정
    func muteAgent(roomName: String, muted: Bool) async throws -> MuteAgentResponse {
        let url = try buildURL(path: Endpoints.muteAgent(roomName: roomName))
        var request = try buildRequest(url: url, method: "POST")

        let body: [String: Any] = ["muted": muted]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request)
    }

    /// 위험 상태 설정
    func setDangerState(roomName: String, dangerType: String, message: String?) async throws -> DangerStateResponse {
        let url = try buildURL(path: Endpoints.danger(roomName: roomName))
        var request = try buildRequest(url: url, method: "POST")

        var body: [String: Any] = ["dangerType": dangerType]
        if let message = message {
            body["message"] = message
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request)
    }

    // MARK: - Private Helpers

    /// API URL 빌드
    private func buildURL(path: String) throws -> URL {
        let baseURL = AppConfig.apiBaseURL
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw LiveKitAPIError.invalidURL
        }
        return url
    }

    /// URLRequest 빌드 (인증 헤더 포함)
    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        guard let authToken = TokenManager.shared.accessToken else {
            Log.auth.e("[LiveKitAPI] 인증 토큰 없음 - 로그인 필요")
            throw LiveKitAPIError.missingAuthToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        return request
    }

    /// API 요청 실행 및 응답 처리
    private func executeRequest<T: Codable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Log.livekit.e("[LiveKitAPI] 네트워크 오류: \(error.localizedDescription)")
            throw LiveKitAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LiveKitAPIError.invalidResponse
        }

        // 디버그 로깅
        #if DEBUG
        let rawResponse = String(data: data, encoding: .utf8) ?? "(no data)"
        print("[LiveKitAPI] \(request.httpMethod ?? "?") \(request.url?.path ?? "") -> \(httpResponse.statusCode)")
        print("[LiveKitAPI] Response: \(rawResponse.prefix(500))")
        #endif

        // 상태 코드 처리
        try handleStatusCode(httpResponse.statusCode, data: data)

        // 응답 디코딩
        do {
            // APIResponse 래퍼 시도
            if let apiResponse = try? decoder.decode(APIResponse<T>.self, from: data),
               let responseData = apiResponse.data {
                return responseData
            }

            // 직접 디코딩 시도
            return try decoder.decode(T.self, from: data)
        } catch {
            Log.livekit.e("[LiveKitAPI] 디코딩 오류: \(error)")
            throw LiveKitAPIError.decodingError(error.localizedDescription)
        }
    }

    /// HTTP 상태 코드 처리
    private func handleStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200..<300:
            // 성공
            return

        case 401:
            // 인증 실패 - 토큰 갱신 시도
            Log.auth.e("[LiveKitAPI] 401 Unauthorized")
            throw LiveKitAPIError.unauthorized

        case 404:
            // Room 또는 Agent 없음
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.lowercased().contains("room") {
                throw LiveKitAPIError.roomNotFound
            } else if body.lowercased().contains("agent") {
                throw LiveKitAPIError.agentNotFound
            }
            throw LiveKitAPIError.httpStatus(code: 404, body: body)

        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LiveKitAPIError.httpStatus(code: statusCode, body: body)
        }
    }
}

// MARK: - Convenience Extensions

extension LiveKitAPIService {

    /// Agent 음소거 (간편 메서드)
    func muteAgent(roomName: String) async throws -> MuteAgentResponse {
        return try await muteAgent(roomName: roomName, muted: true)
    }

    /// Agent 음소거 해제 (간편 메서드)
    func unmuteAgent(roomName: String) async throws -> MuteAgentResponse {
        return try await muteAgent(roomName: roomName, muted: false)
    }

    /// 위험 상태 설정 (메시지 없이)
    func setDangerState(roomName: String, dangerType: String) async throws -> DangerStateResponse {
        return try await setDangerState(roomName: roomName, dangerType: dangerType, message: nil)
    }

    /// Bot 생성 및 Agent 시작 (재시도 로직 포함)
    /// - Parameters:
    ///   - maxRetries: 최대 재시도 횟수
    ///   - retryDelay: 재시도 간격 (초)
    func createBotWithRetry(
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0
    ) async throws -> CreateBotResponse {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await createBot()
            } catch let error as LiveKitAPIError {
                lastError = error

                // 재시도 가능한 에러인 경우에만 재시도
                if error.isRetryable && attempt < maxRetries {
                    Log.livekit.i("[LiveKitAPI] createBot 실패 (시도 \(attempt)/\(maxRetries)), \(retryDelay)초 후 재시도...")
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }

                throw error
            } catch {
                lastError = error
                throw error
            }
        }

        throw lastError ?? LiveKitAPIError.networkError("최대 재시도 횟수 초과")
    }
}

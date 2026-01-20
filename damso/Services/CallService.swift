//
//  CallService.swift
//  damso
//
//  통화 API 서비스 구현
//  - POST /v1/calls/invite: 통화 초대
//  - POST /v1/calls/:callId/analyze: 통화 분석
//  - GET /v1/calls/room/:roomName/context: 방 컨텍스트 조회
//  - GET /v1/calls/room/:roomName/transcripts: 방 전사 내역 조회
//

import Foundation

/// 통화 API 서비스 에러
enum CallServiceError: LocalizedError {
    case invalidURL
    case unauthorized
    case networkError(Error)
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .unauthorized:
            return "인증이 필요합니다. 다시 로그인해주세요."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "서버 오류 (\(statusCode)): \(message ?? "알 수 없는 오류")"
        case .decodingError(let error):
            return "응답 파싱 오류: \(error.localizedDescription)"
        case .noData:
            return "응답 데이터가 없습니다."
        }
    }
}

/// 통화 API 서비스 구현체
final class CallService: CallServiceProtocol {
    static let shared = CallService()

    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Private Helpers

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CallService] \(message)")
        #endif
    }

    @MainActor
    private func getAuthorizationHeader() async -> String? {
        guard let token = TokenManager.shared.accessToken else {
            debugLog("No access token available")
            return nil
        }
        return "Bearer \(token)"
    }

    @MainActor
    private func getBaseURL() async -> String {
        return AppConfig.apiBaseURL
    }

    private func createRequest(
        url: URL,
        method: String,
        body: Data? = nil,
        authHeader: String?
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let authHeader = authHeader {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        debugLog("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CallServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CallServiceError.noData
        }

        debugLog("Response status: \(httpResponse.statusCode)")

        // 상태 코드 처리
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw CallServiceError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8)
            throw CallServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // 응답 디코딩
        do {
            let decoded = try JSONDecoder.apiDecoder.decode(T.self, from: data)
            return decoded
        } catch {
            debugLog("Decoding error: \(error)")
            throw CallServiceError.decodingError(error)
        }
    }

    // MARK: - CallServiceProtocol

    /// 통화 초대
    /// - Parameter wardId: 어르신 ID
    /// - Returns: 초대 응답 (callId, roomName 등)
    func inviteCall(wardId: String) async throws -> InviteCallResponse {
        let baseURL = await getBaseURL()
        guard let url = URL(string: "\(baseURL)/v1/calls/invite") else {
            throw CallServiceError.invalidURL
        }

        guard let authHeader = await getAuthorizationHeader() else {
            throw CallServiceError.unauthorized
        }

        let body: [String: Any] = ["wardId": wardId]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let request = createRequest(
            url: url,
            method: "POST",
            body: bodyData,
            authHeader: authHeader
        )

        return try await performRequest(request, responseType: InviteCallResponse.self)
    }

    /// 통화 분석 요청
    /// - Parameter callId: 통화 ID
    /// - Returns: 분석 결과
    func analyzeCall(callId: String) async throws -> CallAnalyzeResponse {
        let baseURL = await getBaseURL()
        let encodedCallId = callId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? callId
        guard let url = URL(string: "\(baseURL)/v1/calls/\(encodedCallId)/analyze") else {
            throw CallServiceError.invalidURL
        }

        guard let authHeader = await getAuthorizationHeader() else {
            throw CallServiceError.unauthorized
        }

        let request = createRequest(
            url: url,
            method: "POST",
            body: nil,
            authHeader: authHeader
        )

        return try await performRequest(request, responseType: CallAnalyzeResponse.self)
    }

    /// 방 컨텍스트 조회
    /// - Parameter roomName: 방 이름
    /// - Returns: 방 컨텍스트 정보
    func getRoomContext(roomName: String) async throws -> RoomContextResponse {
        let baseURL = await getBaseURL()
        let encodedRoomName = roomName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? roomName
        guard let url = URL(string: "\(baseURL)/v1/calls/room/\(encodedRoomName)/context") else {
            throw CallServiceError.invalidURL
        }

        guard let authHeader = await getAuthorizationHeader() else {
            throw CallServiceError.unauthorized
        }

        let request = createRequest(
            url: url,
            method: "GET",
            body: nil,
            authHeader: authHeader
        )

        return try await performRequest(request, responseType: RoomContextResponse.self)
    }

    /// 방 전사 내역 조회
    /// - Parameter roomName: 방 이름
    /// - Returns: 전사 내역 목록
    func getRoomTranscripts(roomName: String) async throws -> RoomTranscriptsResponse {
        let baseURL = await getBaseURL()
        let encodedRoomName = roomName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? roomName
        guard let url = URL(string: "\(baseURL)/v1/calls/room/\(encodedRoomName)/transcripts") else {
            throw CallServiceError.invalidURL
        }

        guard let authHeader = await getAuthorizationHeader() else {
            throw CallServiceError.unauthorized
        }

        let request = createRequest(
            url: url,
            method: "GET",
            body: nil,
            authHeader: authHeader
        )

        return try await performRequest(request, responseType: RoomTranscriptsResponse.self)
    }
}

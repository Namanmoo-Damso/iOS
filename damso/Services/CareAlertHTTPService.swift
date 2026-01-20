//
//  CareAlertHTTPService.swift
//  damso
//
//  Care Alert HTTP API 서비스 구현
//  DataChannel 기반 CareAlertService와 분리된 HTTP API 통신 담당
//

import Foundation
import os

/// Care Alert HTTP API 서비스
/// `/v1/care-alerts` 엔드포인트와 통신
@MainActor
final class CareAlertHTTPService: CareAlertHTTPServiceProtocol {

    // MARK: - Singleton

    static let shared = CareAlertHTTPService()

    // MARK: - Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.damso", category: "CareAlertHTTP")

    private init() {}

    // MARK: - CareAlertHTTPServiceProtocol

    /// 새로운 케어 알림 생성
    func createAlert(_ request: CreateCareAlertRequest) async throws -> CareAlertResponse {
        logger.info("Creating care alert: type=\(request.alertType), severity=\(request.severity)")

        let url = try buildURL(path: "/v1/care-alerts")
        var urlRequest = try buildRequest(url: url, method: "POST")

        // 요청 바디 인코딩
        urlRequest.httpBody = try JSONEncoder.apiEncoder.encode(request)

        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        do {
            let alertResponse = try JSONDecoder.apiDecoder.decode(CareAlertResponse.self, from: data)
            logger.info("Care alert created: id=\(alertResponse.id)")
            return alertResponse
        } catch {
            logger.error("Failed to decode CareAlertResponse: \(error.localizedDescription)")
            throw CareAlertHTTPError.decodingError(error.localizedDescription)
        }
    }

    /// 특정 Ward의 알림 목록 조회
    func getAlerts(wardId: String, page: Int = 1, limit: Int = 20) async throws -> CareAlertListResponse {
        logger.info("Fetching care alerts for ward: \(wardId), page=\(page), limit=\(limit)")

        var urlComponents = URLComponents(string: "\(AppConfig.apiBaseURL)/v1/guardians/wards/\(wardId)/alerts")
        urlComponents?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = urlComponents?.url else {
            throw CareAlertHTTPError.invalidURL
        }

        let urlRequest = try buildRequest(url: url, method: "GET")
        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        do {
            let listResponse = try JSONDecoder.apiDecoder.decode(CareAlertListResponse.self, from: data)
            logger.info("Fetched \(listResponse.alerts.count) alerts (total: \(listResponse.pagination.total))")
            return listResponse
        } catch {
            logger.error("Failed to decode CareAlertListResponse: \(error.localizedDescription)")
            throw CareAlertHTTPError.decodingError(error.localizedDescription)
        }
    }

    /// 특정 Ward의 감정 분석 리포트 조회
    func getEmotionReport(wardId: String, startDate: Date? = nil, endDate: Date? = nil) async throws -> EmotionReportResponse {
        logger.info("Fetching emotion report for ward: \(wardId)")

        var urlComponents = URLComponents(string: "\(AppConfig.apiBaseURL)/v1/guardians/wards/\(wardId)/emotion-report")

        var queryItems: [URLQueryItem] = []
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: ISO8601DateFormatter().string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: ISO8601DateFormatter().string(from: endDate)))
        }
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            throw CareAlertHTTPError.invalidURL
        }

        let urlRequest = try buildRequest(url: url, method: "GET")
        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        do {
            let reportResponse = try JSONDecoder.apiDecoder.decode(EmotionReportResponse.self, from: data)
            logger.info("Emotion report fetched: totalDetections=\(reportResponse.totalDetections)")
            return reportResponse
        } catch {
            logger.error("Failed to decode EmotionReportResponse: \(error.localizedDescription)")
            throw CareAlertHTTPError.decodingError(error.localizedDescription)
        }
    }

    /// 알림 확인 처리 (acknowledge)
    func acknowledgeAlert(alertId: String) async throws -> CareAlertResponse {
        logger.info("Acknowledging alert: \(alertId)")

        let url = try buildURL(path: "/v1/guardians/alerts/\(alertId)/acknowledge")
        let urlRequest = try buildRequest(url: url, method: "PATCH")

        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        do {
            let alertResponse = try JSONDecoder.apiDecoder.decode(CareAlertResponse.self, from: data)
            logger.info("Alert acknowledged: id=\(alertResponse.id), acknowledgedAt=\(String(describing: alertResponse.acknowledgedAt))")
            return alertResponse
        } catch {
            logger.error("Failed to decode CareAlertResponse: \(error.localizedDescription)")
            throw CareAlertHTTPError.decodingError(error.localizedDescription)
        }
    }

    /// 케어 알림 버퍼 상태 조회
    func getBufferStatus() async throws -> BufferStatusResponse {
        logger.info("Fetching buffer status")

        let url = try buildURL(path: "/v1/care-alerts/buffer-status")
        let urlRequest = try buildRequest(url: url, method: "GET")

        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        do {
            let statusResponse = try JSONDecoder.apiDecoder.decode(BufferStatusResponse.self, from: data)
            logger.info("Buffer status: \(statusResponse.currentSize)/\(statusResponse.maxSize) (\(Int(statusResponse.usageRate * 100))%)")
            return statusResponse
        } catch {
            logger.error("Failed to decode BufferStatusResponse: \(error.localizedDescription)")
            throw CareAlertHTTPError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// URL 생성
    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)\(path)") else {
            throw CareAlertHTTPError.invalidURL
        }
        return url
    }

    /// URLRequest 생성
    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw CareAlertHTTPError.missingAuthToken
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: Numbers.Timeout.networkRequest
        )
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return request
    }

    /// 네트워크 요청 수행
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw CareAlertHTTPError.networkError(error.localizedDescription)
        }
    }

    /// 응답 검증
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CareAlertHTTPError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        // 성공 응답
        if (200..<300).contains(statusCode) {
            return
        }

        // 에러 응답 처리
        let bodyText = String(data: data, encoding: .utf8) ?? ""

        switch statusCode {
        case 401:
            logger.warning("Unauthorized - token may be expired")
            throw CareAlertHTTPError.unauthorized
        case 404:
            logger.warning("Resource not found")
            throw CareAlertHTTPError.notFound
        default:
            logger.error("HTTP error \(statusCode): \(bodyText)")
            throw CareAlertHTTPError.httpError(statusCode: statusCode, body: bodyText)
        }
    }
}

// MARK: - Convenience Extensions

extension CareAlertHTTPService {

    /// CareAlertPayload를 HTTP API로 전송 (DataChannel 대신 HTTP 사용 시)
    func sendAlert(payload: CareAlertPayload, wardId: String) async throws -> CareAlertResponse {
        // CareAlertPayload를 CreateCareAlertRequest로 변환
        let request = CreateCareAlertRequest(
            alertType: payload.alertType,
            severity: payload.severity,
            wardId: wardId,
            data: nil,  // 복잡한 data는 별도 변환 필요
            message: nil
        )
        return try await createAlert(request)
    }

    /// 간편 알림 생성 (기본 파라미터)
    func createSimpleAlert(
        type: CareAlertType,
        severity: CareAlertSeverity,
        wardId: String,
        message: String? = nil
    ) async throws -> CareAlertResponse {
        let request = CreateCareAlertRequest(
            alertType: type,
            severity: severity,
            wardId: wardId,
            message: message
        )
        return try await createAlert(request)
    }
}

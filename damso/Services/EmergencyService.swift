//
//  EmergencyService.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation
import CoreLocation

/// 비상 연락 서비스
final class EmergencyService {

    static let shared = EmergencyService()

    private init() {}

    // MARK: - Public Methods

    /// 비상 연락 전송
    func triggerEmergency(
        type: EmergencyType = .manual,
        message: String? = nil
    ) async throws {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw EmergencyError.unauthorized
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/ward/emergency") else {
            throw EmergencyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "type": type.rawValue,
            "message": message ?? type.defaultMessage
        ]

        // 현재 위치 정보 포함
        if let location = LocationService.shared.lastLocation {
            body["latitude"] = location.coordinate.latitude
            body["longitude"] = location.coordinate.longitude
            body["accuracy"] = location.horizontalAccuracy
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmergencyError.serverError
        }

        if httpResponse.statusCode == 401 {
            throw EmergencyError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            debugLog("Emergency API error: \(httpResponse.statusCode) \(bodyText)")
            throw EmergencyError.serverError
        }

        debugLog("Emergency alert sent successfully")
    }

    // MARK: - Private Methods

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[EmergencyService] \(message)")
        #endif
    }
}

// MARK: - Emergency Type

/// 비상 유형 (백엔드: string - 확장 가능)
enum EmergencyType: String, Codable {
    case health = "health"    // 건강 관련 비상
    case safety = "safety"    // 안전 관련 비상
    case fall = "fall"        // 낙상
    case manual = "manual"    // 수동 호출
    case unknown              // 알 수 없는 타입

    var defaultMessage: String {
        switch self {
        case .health:
            return "건강 이상이 감지되었습니다"
        case .safety:
            return "안전 관련 비상 상황이 발생했습니다"
        case .fall:
            return "낙상이 감지되었습니다"
        case .manual:
            return "비상 버튼이 눌렸습니다"
        case .unknown:
            return "긴급 상황이 발생했습니다"
        }
    }

    var displayName: String {
        switch self {
        case .health:
            return "건강 비상"
        case .safety:
            return "안전 비상"
        case .fall:
            return "낙상 감지"
        case .manual:
            return "수동 호출"
        case .unknown:
            return "비상"
        }
    }

    // 알 수 없는 타입 처리
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = EmergencyType(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Emergency Error

enum EmergencyError: LocalizedError {
    case invalidURL
    case serverError
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .serverError:
            return "서버 오류가 발생했습니다."
        case .unauthorized:
            return "인증이 필요합니다."
        }
    }
}

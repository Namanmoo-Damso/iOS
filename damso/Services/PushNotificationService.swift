//
//  PushNotificationService.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

/// 푸시 알림 설정 서비스
final class PushNotificationService {

    static let shared = PushNotificationService()

    private init() {}

    // MARK: - Public Methods

    /// 디바이스 토큰 서버에 등록
    func registerDeviceToken(_ token: String) async throws {
        guard let accessToken = TokenManager.shared.accessToken else {
            debugLog("No access token, skipping device token registration")
            return
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/me/device-token") else {
            throw PushError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "token": token,
            "platform": "ios"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PushError.serverError
        }

        debugLog("Device token registered successfully")
    }

    /// 알림 설정 서버에 동기화
    func updateNotificationSettings(
        callReminder: Bool,
        callComplete: Bool,
        healthAlert: Bool,
        dailySummary: Bool
    ) async throws {
        guard let accessToken = TokenManager.shared.accessToken else {
            debugLog("No access token, skipping notification settings update")
            return
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/users/me/notification-settings") else {
            throw PushError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "callReminder": callReminder,
            "callComplete": callComplete,
            "healthAlert": healthAlert,
            "dailySummary": dailySummary
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PushError.serverError
        }

        debugLog("Notification settings updated successfully")
    }

    // MARK: - Private Methods

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[PushNotificationService] \(message)")
        #endif
    }
}

// MARK: - Push Error

enum PushError: LocalizedError {
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

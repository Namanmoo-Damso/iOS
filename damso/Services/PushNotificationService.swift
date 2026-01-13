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

    // MARK: - Properties

    private var apnsEnv: String {
        #if DEBUG
        return "sandbox"
        #else
        return "prod"
        #endif
    }

    // MARK: - Public Methods

    /// 디바이스 토큰 서버에 등록 (APNs 또는 VoIP)
    /// - Parameters:
    ///   - apnsToken: 일반 푸시 토큰 (optional)
    ///   - voipToken: VoIP 푸시 토큰 (optional)
    func registerDeviceTokens(apnsToken: String? = nil, voipToken: String? = nil) async throws {
        guard let accessToken = TokenManager.shared.accessToken else {
            debugLog("No access token, skipping device token registration")
            return
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/devices/register") else {
            throw PushError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let supportsCallKit = resolveCallCapability() == .callKit

        // identity는 서버가 JWT에서 추출하므로 body에 포함하지 않음
        var body: [String: Any] = [
            "platform": "ios",
            "env": apnsEnv,
            "supportsCallKit": supportsCallKit
        ]

        if let apnsToken = apnsToken, !apnsToken.isEmpty {
            body["apnsToken"] = apnsToken
        }

        if let voipToken = voipToken, !voipToken.isEmpty {
            body["voipToken"] = voipToken
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PushError.serverError
        }

        debugLog("Device tokens registered successfully (apns: \(apnsToken != nil), voip: \(voipToken != nil))")
    }

    /// 단일 APNs 토큰 등록 (하위 호환)
    func registerDeviceToken(_ token: String) async throws {
        try await registerDeviceTokens(apnsToken: token)
    }

    /// 알림 설정 서버에 동기화
    func updateNotificationSettings(
        callReminder: Bool,
        callComplete: Bool,
        healthAlert: Bool
    ) async throws {
        guard let accessToken = TokenManager.shared.accessToken else {
            debugLog("No access token, skipping notification settings update")
            return
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/guardian/notification-settings") else {
            throw PushError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "callReminder": callReminder,
            "callComplete": callComplete,
            "healthAlert": healthAlert
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

//
//  WardSettingsService.swift
//  damso
//
//  어르신 설정 API 서비스
//

import Foundation

/// 어르신 설정 관리 서비스
@MainActor
final class WardSettingsService: WardSettingsServiceProtocol {

    // MARK: - Singleton

    static let shared = WardSettingsService()

    private init() {}

    // MARK: - Public Methods

    /// 어르신 설정 조회
    /// GET /v1/ward/settings
    func fetchSettings() async throws -> WardSettings {
        guard let authToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/ward/settings") else {
            throw AuthError.networkError("Invalid settings URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

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

        // 응답이 비어있는 경우 기본값 반환
        if data.isEmpty {
            Log.network.d("Ward settings response is empty, returning default")
            return WardSettings.default
        }

        do {
            let settingsResponse = try JSONDecoder.apiDecoder.decode(WardSettingsResponse.self, from: data)

            if let settings = settingsResponse.data {
                Log.network.i("Ward settings fetched successfully")
                return settings
            } else if let apiError = settingsResponse.error {
                Log.network.e("Ward settings API error: \(apiError.message)")
                throw AuthError.networkError(apiError.message)
            } else {
                // data가 nil이고 error도 nil인 경우 기본값 반환
                return WardSettings.default
            }
        } catch let decodingError as DecodingError {
            Log.network.e("Ward settings decoding error: \(decodingError)")
            logDecodingError(decodingError)
            throw AuthError.decodingError(decodingError.localizedDescription)
        }
    }

    /// 어르신 설정 수정
    /// PUT /v1/ward/settings
    func updateSettings(_ settings: WardSettingsUpdateRequest) async throws -> WardSettings {
        guard let authToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/ward/settings") else {
            throw AuthError.networkError("Invalid settings URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        do {
            let jsonData = try JSONEncoder.apiEncoder.encode(settings)
            request.httpBody = jsonData

            #if DEBUG
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                Log.network.d("Ward settings update request body: \(jsonString)")
            }
            #endif
        } catch {
            throw AuthError.networkError("Request body encoding failed: \(error)")
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

        do {
            let settingsResponse = try JSONDecoder.apiDecoder.decode(WardSettingsResponse.self, from: data)

            if let settings = settingsResponse.data {
                Log.network.i("Ward settings updated successfully")
                return settings
            } else if let apiError = settingsResponse.error {
                Log.network.e("Ward settings update API error: \(apiError.message)")
                throw AuthError.networkError(apiError.message)
            } else {
                // 응답에 data가 없는 경우, 요청한 설정값 기반으로 기본값 반환
                Log.network.w("Ward settings update response has no data")
                return WardSettings.default
            }
        } catch let decodingError as DecodingError {
            Log.network.e("Ward settings update decoding error: \(decodingError)")
            logDecodingError(decodingError)
            throw AuthError.decodingError(decodingError.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            Log.network.e("Missing key: \(key.stringValue), path: \(context.codingPath)")
        case .typeMismatch(let type, let context):
            Log.network.e("Type mismatch: \(type), path: \(context.codingPath)")
        case .valueNotFound(let type, let context):
            Log.network.e("Value not found: \(type), path: \(context.codingPath)")
        case .dataCorrupted(let context):
            Log.network.e("Data corrupted: \(context.debugDescription)")
        @unknown default:
            Log.network.e("Unknown decoding error")
        }
    }
}

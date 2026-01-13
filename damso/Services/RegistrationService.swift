//
//  RegistrationService.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import Foundation

/// 사용자 등록 관리 서비스
@MainActor
final class RegistrationService: RegistrationProtocol {

    // MARK: - Singleton

    static let shared = RegistrationService()

    private init() {}

    // MARK: - Public Methods

    /// 보호자 등록 (기존 API - 호환성 유지)
    /// - Parameters:
    ///   - wardEmail: 어르신 이메일
    ///   - wardPhoneNumber: 어르신 전화번호
    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse {
        try await registerGuardian(
            wardEmail: wardEmail,
            wardPhoneNumber: wardPhoneNumber,
            wardBasicInfo: nil,
            aiCareInfo: nil,
            callSchedule: nil
        )
    }

    /// 보호자 등록 (확장 API - 어르신 상세 정보 포함)
    /// - Parameters:
    ///   - wardEmail: 어르신 이메일
    ///   - wardPhoneNumber: 어르신 전화번호
    ///   - wardBasicInfo: 어르신 기본 정보
    ///   - aiCareInfo: AI 케어 정보
    ///   - callSchedule: AI 전화 스케줄
    func registerGuardian(
        wardEmail: String,
        wardPhoneNumber: String,
        wardBasicInfo: WardBasicInfo?,
        aiCareInfo: AICarInfo?,
        callSchedule: AICallSchedule?
    ) async throws -> GuardianRegistrationResponse {
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

        var body: [String: Any] = [
            "wardEmail": wardEmail,
            "wardPhoneNumber": wardPhoneNumber
        ]

        // 어르신 기본 정보 추가
        if let basicInfo = wardBasicInfo {
            body["wardBasicInfo"] = [
                "name": basicInfo.name,
                "relation": basicInfo.relation.rawValue,
                "phoneNumber": basicInfo.phoneNumber,
                "birthDate": basicInfo.birthDate,
                "gender": basicInfo.gender.rawValue,
                "address": basicInfo.address
            ]
        }

        // AI 케어 정보 추가
        if let careInfo = aiCareInfo {
            body["aiCareInfo"] = [
                "medicalConditions": careInfo.medicalConditions,
                "medications": careInfo.medications
            ]
        }

        // AI 전화 스케줄 추가
        if let schedule = callSchedule {
            let scheduleItems = schedule.items.map { item -> [String: Any] in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return [
                    "id": item.id,
                    "time": formatter.string(from: item.time),
                    "weekdays": item.weekdays.map { $0.rawValue },
                    "isEnabled": item.isEnabled
                ]
            }
            body["callSchedule"] = [
                "items": scheduleItems,
                "isEnabled": schedule.isEnabled
            ]
        }

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

    // MARK: - Schedule API

    /// 스케줄 목록 조회
    /// - Parameter wardId: 어르신 ID (없으면 전체 스케줄 조회)
    func fetchSchedules(wardId: String? = nil) async throws -> AICallSchedule {
        guard let authToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        // URL 구성 (ward_id 쿼리 파라미터 지원)
        var urlComponents = URLComponents(string: "\(AppConfig.apiBaseURL)/v1/guardian/schedules")
        if let wardId {
            urlComponents?.queryItems = [URLQueryItem(name: "ward_id", value: wardId)]
        }
        
        guard let url = urlComponents?.url else {
            throw AuthError.networkError("Invalid schedule URL")
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
        
        // 404: 어르신 없음
        if httpResponse.statusCode == 404 {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data),
               errorResponse.error?.code == APIErrorCode.wardNotFound.rawValue {
                throw ScheduleError.wardNotFound
            }
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        // 응답이 비어있거나 스케줄이 없는 경우 기본값 반환
        if data.isEmpty {
            return AICallSchedule.default
        }

        do {
            let scheduleResponse = try JSONDecoder.apiDecoder.decode(ScheduleResponse.self, from: data)
            return scheduleResponse.toSchedule()
        } catch {
            Log.auth.e("Schedule decoding error: \(error)")
            logDecodingError(error)
            // 디코딩 실패 시 기본값 반환
            return AICallSchedule.default
        }
    }

    /// 스케줄 저장/수정
    /// - Parameters:
    ///   - schedule: 스케줄 데이터
    ///   - wardId: 어르신 ID (다중 어르신 지원)
    func saveSchedules(_ schedule: AICallSchedule, wardId: String? = nil) async throws {
        guard let authToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/guardian/schedules") else {
            throw AuthError.networkError("Invalid schedule URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let requestBody = ScheduleRequest(schedule: schedule, wardId: wardId)

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            #if DEBUG
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                Log.auth.d("Schedule request body: \(jsonString)")
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
        
        // 409: 슬롯 용량 초과
        if httpResponse.statusCode == 409 {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data),
               let apiError = errorResponse.error,
               apiError.code == APIErrorCode.slotCapacityExceeded.rawValue {
                let message = apiError.details?.userMessage ?? apiError.message
                throw ScheduleError.slotCapacityExceeded(message: message)
            }
        }
        
        // 404: 어르신 없음
        if httpResponse.statusCode == 404 {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data),
               errorResponse.error?.code == APIErrorCode.wardNotFound.rawValue {
                throw ScheduleError.wardNotFound
            }
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        Log.auth.i("Schedules saved successfully (wardId: \(wardId ?? "none"))")
    }

    /// 스케줄 삭제
    func deleteSchedule(id: String) async throws {
        guard let authToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/guardian/schedules/\(id)") else {
            throw AuthError.networkError("Invalid schedule URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "DELETE"
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

        Log.auth.i("Schedule \(id) deleted successfully")
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

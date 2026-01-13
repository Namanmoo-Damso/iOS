//
//  AuthErrors.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import Foundation

/// 인증 관련 에러
enum AuthError: LocalizedError {
    case missingAuthToken
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case missingToken
    case networkError(String)
    case decodingError(String)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return ErrorMessages.missingAuthToken
        case .invalidResponse:
            return ErrorMessages.invalidResponse
        case let .httpStatus(code, body):
            if body.isEmpty {
                return "API 요청 실패 (상태 코드: \(code))"
            }
            return "API 요청 실패 (\(code)): \(body)"
        case .missingToken:
            return ErrorMessages.missingToken
        case let .networkError(msg):
            return "네트워크 오류: \(msg)"
        case let .decodingError(msg):
            return "디코딩 오류: \(msg)"
        case .unauthorized:
            return ErrorMessages.unauthorized
        case .unknown:
            return ErrorMessages.unknownError
        }
    }
}

/// 스케줄 관련 에러
enum ScheduleError: LocalizedError {
    case wardNotFound
    case slotCapacityExceeded(message: String)
    case invalidTime
    case invalidWeekdays
    
    var errorDescription: String? {
        switch self {
        case .wardNotFound:
            return "어르신 정보를 찾을 수 없습니다."
        case .slotCapacityExceeded(let message):
            return message
        case .invalidTime:
            return "유효하지 않은 시간입니다."
        case .invalidWeekdays:
            return "유효하지 않은 요일입니다."
        }
    }
}

/// Legacy 토큰 에러 (호환성 유지)
enum TokenError: LocalizedError {
    case missingAuthToken
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case missingToken
    case networkError(String)
    case serverAtCapacity       // 503: 서버 용량 초과
    case callAlreadyActive      // 409: 이미 통화 중

    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "Missing API auth token. Store it in UserDefaults with key 'authToken'."
        case .invalidResponse:
            return "Invalid token response."
        case let .httpStatus(code, body):
            if body.isEmpty {
                return "Token API failed with status \(code)."
            }
            return "Token API failed (\(code)): \(body)"
        case .missingToken:
            return "Token is missing in API response."
        case let .networkError(msg):
            return "Network Error: \(msg)"
        case .serverAtCapacity:
            return "현재 서버가 혼잡합니다. 잠시 후 다시 시도해주세요."
        case .callAlreadyActive:
            return "이미 진행 중인 통화가 있습니다."
        }
    }
    
    /// 재시도 가능한 에러인지 확인
    var isRetryable: Bool {
        switch self {
        case .serverAtCapacity:
            return true
        case .networkError:
            return true
        default:
            return false
        }
    }
}

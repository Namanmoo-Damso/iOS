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
            return "인증 토큰이 없습니다."
        case .invalidResponse:
            return "잘못된 응답입니다."
        case let .httpStatus(code, body):
            if body.isEmpty {
                return "API 요청 실패 (상태 코드: \(code))"
            }
            return "API 요청 실패 (\(code)): \(body)"
        case .missingToken:
            return "응답에 토큰이 없습니다."
        case let .networkError(msg):
            return "네트워크 오류: \(msg)"
        case let .decodingError(msg):
            return "디코딩 오류: \(msg)"
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .unknown:
            return "알 수 없는 오류가 발생했습니다."
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
        }
    }
}

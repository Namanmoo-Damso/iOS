//
//  APIResponses.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

// MARK: - 공통 API 응답 래퍼

/// API 응답 기본 구조
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
    let error: APIError?
}

/// API 에러 정보
struct APIError: Codable {
    let code: String
    let message: String
}

// MARK: - 사용자 관련 응답

/// GET /users/me 응답
struct UserMeResponse: Codable {
    let id: String
    let kakaoId: String
    let email: String
    let nickname: String
    let profileImageUrl: String?
    let userType: UserType
    let createdAt: Date

    /// 보호자인 경우에만 존재
    let guardianInfo: GuardianInfoResponse?

    /// 어르신인 경우에만 존재
    let wardInfo: WardInfoResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case kakaoId = "kakao_id"
        case email
        case nickname
        case profileImageUrl = "profile_image_url"
        case userType = "user_type"
        case createdAt = "created_at"
        case guardianInfo = "guardian_info"
        case wardInfo = "ward_info"
    }
}

/// 보호자 상세 정보 응답
struct GuardianInfoResponse: Codable {
    let wardEmail: String
    let wardPhoneNumber: String
    let linkedWard: WardSummary?

    enum CodingKeys: String, CodingKey {
        case wardEmail = "ward_email"
        case wardPhoneNumber = "ward_phone_number"
        case linkedWard = "linked_ward"
    }
}

/// 어르신 상세 정보 응답
struct WardInfoResponse: Codable {
    let phoneNumber: String
    let linkedGuardian: GuardianSummary?
    let linkedOrganization: OrganizationSummary?

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case linkedGuardian = "linked_guardian"
        case linkedOrganization = "linked_organization"
    }
}

// MARK: - 인증 관련 응답

/// POST /auth/kakao 응답
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: UserMeResponse

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

/// POST /auth/refresh 응답
struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - 등록/매칭 관련 응답

/// POST /guardians 응답
struct GuardianRegistrationResponse: Codable {
    let guardianId: String
    let userId: String
    let wardEmail: String
    let wardPhoneNumber: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case guardianId = "guardian_id"
        case userId = "user_id"
        case wardEmail = "ward_email"
        case wardPhoneNumber = "ward_phone_number"
        case message
    }
}

/// POST /wards/match 응답
struct WardMatchResponse: Codable {
    let wardId: String
    let userId: String
    let phoneNumber: String
    let matched: Bool
    let matchType: String?  // "guardian" or "organization" or null
    let linkedGuardian: GuardianSummary?
    let linkedOrganization: OrganizationSummary?
    let message: String

    enum CodingKeys: String, CodingKey {
        case wardId = "ward_id"
        case userId = "user_id"
        case phoneNumber = "phone_number"
        case matched
        case matchType = "match_type"
        case linkedGuardian = "linked_guardian"
        case linkedOrganization = "linked_organization"
        case message
    }
}

// MARK: - JSON Decoder Helper

extension JSONDecoder {
    /// 서버 API 응답용 공통 디코더
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    /// 서버 API 요청용 공통 인코더
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

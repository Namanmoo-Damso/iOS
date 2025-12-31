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
    let kakaoId: String?
    let email: String?
    let nickname: String?
    let profileImageUrl: String?
    let userType: UserType?  // null 허용 (신규 사용자는 userType이 null)
    let createdAt: Date?

    /// 보호자인 경우에만 존재
    let guardianInfo: GuardianInfoResponse?

    /// 어르신인 경우에만 존재
    let wardInfo: WardInfoResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case kakaoId
        case email
        case nickname
        case profileImageUrl
        case userType
        case createdAt
        case guardianInfo
        case wardInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id
        id = try container.decode(String.self, forKey: .id)

        // kakaoId: snake_case와 camelCase 둘 다 지원
        if let kakao = try? container.decode(String.self, forKey: .kakaoId) {
            kakaoId = kakao
        } else {
            // snake_case 시도
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            kakaoId = try? snakeContainer.decode(String.self, forKey: .kakaoId)
        }

        // email
        email = try? container.decode(String.self, forKey: .email)

        // nickname
        nickname = try? container.decode(String.self, forKey: .nickname)

        // profileImageUrl: snake_case와 camelCase 둘 다 지원
        if let url = try? container.decode(String.self, forKey: .profileImageUrl) {
            profileImageUrl = url
        } else {
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            profileImageUrl = try? snakeContainer.decode(String.self, forKey: .profileImageUrl)
        }

        // userType: snake_case와 camelCase 둘 다 지원 (null 허용)
        if let type = try? container.decode(UserType.self, forKey: .userType) {
            userType = type
        } else {
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            userType = try? snakeContainer.decode(UserType.self, forKey: .userType)
        }

        // createdAt: snake_case와 camelCase 둘 다 지원
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            createdAt = try? snakeContainer.decode(Date.self, forKey: .createdAt)
        }

        // guardianInfo
        if let info = try? container.decode(GuardianInfoResponse.self, forKey: .guardianInfo) {
            guardianInfo = info
        } else {
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            guardianInfo = try? snakeContainer.decode(GuardianInfoResponse.self, forKey: .guardianInfo)
        }

        // wardInfo
        if let info = try? container.decode(WardInfoResponse.self, forKey: .wardInfo) {
            wardInfo = info
        } else {
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            wardInfo = try? snakeContainer.decode(WardInfoResponse.self, forKey: .wardInfo)
        }
    }

    // snake_case 키 지원
    private enum SnakeCaseCodingKeys: String, CodingKey {
        case kakaoId = "kakao_id"
        case profileImageUrl = "profile_image_url"
        case userType = "user_type"
        case createdAt = "created_at"
        case guardianInfo = "guardian_info"
        case wardInfo = "ward_info"
    }

    // Memberwise initializer (코드에서 직접 생성용)
    init(
        id: String,
        kakaoId: String?,
        email: String?,
        nickname: String?,
        profileImageUrl: String?,
        userType: UserType,
        createdAt: Date?,
        guardianInfo: GuardianInfoResponse? = nil,
        wardInfo: WardInfoResponse? = nil
    ) {
        self.id = id
        self.kakaoId = kakaoId
        self.email = email
        self.nickname = nickname
        self.profileImageUrl = profileImageUrl
        self.userType = userType
        self.createdAt = createdAt
        self.guardianInfo = guardianInfo
        self.wardInfo = wardInfo
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

/// 매칭 상태
enum MatchStatus: String, Codable {
    case matched = "matched"
    case notMatched = "not_matched"
    case pending = "pending"
}

/// 카카오 프로필 정보 (신규 사용자용)
struct KakaoProfile: Codable {
    let kakaoId: String
    let email: String?
    let nickname: String?
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case kakaoId
        case email
        case nickname
        case profileImageUrl
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case kakaoId = "kakao_id"
        case profileImageUrl = "profile_image_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // kakaoId
        if let id = try? container.decode(String.self, forKey: .kakaoId) {
            kakaoId = id
        } else {
            kakaoId = try snakeContainer.decode(String.self, forKey: .kakaoId)
        }

        email = try? container.decode(String.self, forKey: .email)
        nickname = try? container.decode(String.self, forKey: .nickname)

        // profileImageUrl
        if let url = try? container.decode(String.self, forKey: .profileImageUrl) {
            profileImageUrl = url
        } else {
            profileImageUrl = try? snakeContainer.decode(String.self, forKey: .profileImageUrl)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kakaoId, forKey: .kakaoId)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
    }
}

/// POST /auth/kakao 응답
/// 신규 사용자: isNewUser=true, requiresRegistration=true, tempToken
/// 기존 사용자: isNewUser=false, accessToken, refreshToken, user
struct AuthResponse: Codable {
    // 공통 필드
    let isNewUser: Bool?

    // 신규 사용자용 필드
    let requiresRegistration: Bool?
    let kakaoProfile: KakaoProfile?
    let tempToken: String?

    // 기존 사용자용 필드
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: UserMeResponse?

    /// 어르신 자동 매칭 상태 (어르신 로그인 시에만 사용)
    let matchStatus: MatchStatus?

    /// 매칭 관련 메시지
    let matchMessage: String?

    /// 신규 사용자인지 확인
    var isNewUserFlag: Bool {
        return isNewUser == true || requiresRegistration == true
    }

    enum CodingKeys: String, CodingKey {
        case isNewUser
        case requiresRegistration
        case kakaoProfile
        case tempToken
        case accessToken
        case refreshToken
        case expiresIn
        case user
        case matchStatus
        case matchMessage
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case isNewUser = "is_new_user"
        case requiresRegistration = "requires_registration"
        case kakaoProfile = "kakao_profile"
        case tempToken = "temp_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case matchStatus = "match_status"
        case matchMessage = "match_message"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // isNewUser
        if let val = try? container.decode(Bool.self, forKey: .isNewUser) {
            isNewUser = val
        } else {
            isNewUser = try? snakeContainer.decode(Bool.self, forKey: .isNewUser)
        }

        // requiresRegistration
        if let val = try? container.decode(Bool.self, forKey: .requiresRegistration) {
            requiresRegistration = val
        } else {
            requiresRegistration = try? snakeContainer.decode(Bool.self, forKey: .requiresRegistration)
        }

        // kakaoProfile
        if let val = try? container.decode(KakaoProfile.self, forKey: .kakaoProfile) {
            kakaoProfile = val
        } else {
            kakaoProfile = try? snakeContainer.decode(KakaoProfile.self, forKey: .kakaoProfile)
        }

        // tempToken
        if let val = try? container.decode(String.self, forKey: .tempToken) {
            tempToken = val
        } else {
            tempToken = try? snakeContainer.decode(String.self, forKey: .tempToken)
        }

        // accessToken
        if let val = try? container.decode(String.self, forKey: .accessToken) {
            accessToken = val
        } else {
            accessToken = try? snakeContainer.decode(String.self, forKey: .accessToken)
        }

        // refreshToken
        if let val = try? container.decode(String.self, forKey: .refreshToken) {
            refreshToken = val
        } else {
            refreshToken = try? snakeContainer.decode(String.self, forKey: .refreshToken)
        }

        // expiresIn
        if let val = try? container.decode(Int.self, forKey: .expiresIn) {
            expiresIn = val
        } else {
            expiresIn = try? snakeContainer.decode(Int.self, forKey: .expiresIn)
        }

        // user - camelCase만 (user는 키 이름이 같음)
        user = try? container.decode(UserMeResponse.self, forKey: .user)

        // matchStatus
        if let val = try? container.decode(MatchStatus.self, forKey: .matchStatus) {
            matchStatus = val
        } else {
            matchStatus = try? snakeContainer.decode(MatchStatus.self, forKey: .matchStatus)
        }

        // matchMessage
        if let val = try? container.decode(String.self, forKey: .matchMessage) {
            matchMessage = val
        } else {
            matchMessage = try? snakeContainer.decode(String.self, forKey: .matchMessage)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(isNewUser, forKey: .isNewUser)
        try container.encodeIfPresent(requiresRegistration, forKey: .requiresRegistration)
        try container.encodeIfPresent(kakaoProfile, forKey: .kakaoProfile)
        try container.encodeIfPresent(tempToken, forKey: .tempToken)
        try container.encodeIfPresent(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(expiresIn, forKey: .expiresIn)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(matchStatus, forKey: .matchStatus)
        try container.encodeIfPresent(matchMessage, forKey: .matchMessage)
    }
}

/// POST /auth/refresh 응답
struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?  // 서버에서 반환하지 않을 수 있음

    // 서버가 camelCase로 응답하므로 CodingKeys 불필요
}

// MARK: - 등록/매칭 관련 응답

/// POST /v1/users/register/guardian 응답
struct GuardianRegistrationResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let user: UserMeResponse?
    let guardianInfo: GuardianInfoDetail?

    // 서버가 camelCase로 응답하므로 CodingKeys 불필요
}

/// 보호자 등록 시 반환되는 상세 정보
struct GuardianInfoDetail: Codable {
    let id: String
    let wardEmail: String
    let wardPhoneNumber: String
    let linkedWard: WardSummary?
}

extension GuardianRegistrationResponse {
    /// 응답에서 guardian ID 추출
    var resolvedGuardianId: String {
        guardianInfo?.id ?? user?.id ?? "unknown"
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

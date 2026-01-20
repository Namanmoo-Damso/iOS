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

/// 빈 응답 (에러 응답 파싱 등에 사용)
struct EmptyResponse: Codable {}

/// API 에러 정보
struct APIError: Codable {
    let code: String
    let message: String
    let details: SlotErrorDetails?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        details = try? container.decode(SlotErrorDetails.self, forKey: .details)
    }
    
    enum CodingKeys: String, CodingKey {
        case code, message, details
    }
}

/// 서버 에러 코드
enum APIErrorCode: String {
    case serverAtCapacity = "SERVER_AT_CAPACITY"
    case callAlreadyActive = "CALL_ALREADY_ACTIVE"
    case slotCapacityExceeded = "SLOT_CAPACITY_EXCEEDED"
    case wardNotFound = "WARD_NOT_FOUND"
    case invalidHour = "INVALID_HOUR"
    case invalidMinute = "INVALID_MINUTE"
    case invalidWeekdays = "INVALID_WEEKDAYS"
    
    /// 사용자에게 표시할 메시지
    var userMessage: String {
        switch self {
        case .serverAtCapacity:
            return "현재 서버가 혼잡합니다. 잠시 후 다시 시도해주세요."
        case .callAlreadyActive:
            return "이미 진행 중인 통화가 있습니다."
        case .slotCapacityExceeded:
            return "해당 시간대의 예약이 가득 찼습니다."
        case .wardNotFound:
            return "어르신 정보를 찾을 수 없습니다."
        case .invalidHour, .invalidMinute:
            return "유효하지 않은 시간입니다."
        case .invalidWeekdays:
            return "유효하지 않은 요일입니다."
        }
    }
}

/// 슬롯 에러 상세 정보
struct SlotErrorDetails: Codable {
    let weekday: Int
    let slotStartHour: Int
    let slotStartMinute: Int
    let currentCount: Int
    let maxCapacity: Int
    
    /// 사용자에게 표시할 상세 메시지
    var userMessage: String {
        let weekdayName = Weekday(rawValue: weekday)?.fullName ?? "알 수 없는 요일"
        return "\(weekdayName) \(String(format: "%02d:%02d", slotStartHour, slotStartMinute)) 슬롯이 가득 찼습니다 (\(currentCount)/\(maxCapacity))"
    }
}

// MARK: - 사용자 관련 응답

/// GET /users/me 응답
struct UserMeResponse: Codable {
    let id: String
    let identity: String?  // 서버에서 제공하는 고유 identity (예: "kakao_12345")
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
        case identity
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

        // identity (서버에서 제공하는 고유 식별자)
        identity = try? container.decode(String.self, forKey: .identity)

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
        identity: String? = nil,
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
        self.identity = identity
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

/// 등록된 어르신 정보 (다중 어르신 지원)
struct WardRegistrationInfo: Codable, Identifiable {
    let registrationId: String
    let wardEmail: String
    let wardPhoneNumber: String
    let linkedWardId: String?
    let wardNickname: String?

    var id: String { registrationId }

    /// 어르신 연결 여부
    var isLinked: Bool { linkedWardId != nil }

    /// 표시할 이름 (닉네임 또는 이메일)
    var displayName: String { wardNickname ?? wardEmail }

    enum CodingKeys: String, CodingKey {
        case registrationId
        case wardEmail
        case wardPhoneNumber
        case linkedWardId
        case linkedWard  // camelCase 객체용
        case wardNickname
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case registrationId = "registration_id"
        case wardEmail = "ward_email"
        case wardPhoneNumber = "ward_phone_number"
        case linkedWardId = "linked_ward_id"
        case linkedWard = "linked_ward"
        case wardNickname = "ward_nickname"
    }

    /// linkedWard 객체 파싱용 (서버가 객체로 보낼 때)
    private struct LinkedWardObject: Codable {
        let id: String
        let nickname: String?
    }

    init(from decoder: Decoder) throws {
        // camelCase 시도
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let regId = try? container.decode(String.self, forKey: .registrationId) {
            registrationId = regId
            wardEmail = (try? container.decode(String.self, forKey: .wardEmail)) ?? ""
            wardPhoneNumber = (try? container.decode(String.self, forKey: .wardPhoneNumber)) ?? ""
            
            // linkedWard 객체 시도 (camelCase 키 linkedWard)
            if let linkedWardObj = try? container.decode(LinkedWardObject.self, forKey: .linkedWard) {
                linkedWardId = linkedWardObj.id
                wardNickname = linkedWardObj.nickname ?? (try? container.decode(String.self, forKey: .wardNickname))
            } else if let linkedWardObj = try? container.decode(LinkedWardObject.self, forKey: .linkedWardId) {
                // linkedWardId 키에 객체가 있는 경우
                linkedWardId = linkedWardObj.id
                wardNickname = linkedWardObj.nickname ?? (try? container.decode(String.self, forKey: .wardNickname))
            } else {
                // 문자열 fallback
                linkedWardId = try? container.decode(String.self, forKey: .linkedWardId)
                wardNickname = try? container.decode(String.self, forKey: .wardNickname)
            }
        } else {
            // snake_case 시도
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            registrationId = try snakeContainer.decode(String.self, forKey: .registrationId)
            wardEmail = (try? snakeContainer.decode(String.self, forKey: .wardEmail)) ?? ""
            wardPhoneNumber = (try? snakeContainer.decode(String.self, forKey: .wardPhoneNumber)) ?? ""
            
            // linkedWard 객체 시도 → 문자열 fallback
            if let linkedWardObj = try? snakeContainer.decode(LinkedWardObject.self, forKey: .linkedWard) {
                linkedWardId = linkedWardObj.id
                wardNickname = linkedWardObj.nickname ?? (try? snakeContainer.decode(String.self, forKey: .wardNickname))
            } else if let linkedWardObj = try? snakeContainer.decode(LinkedWardObject.self, forKey: .linkedWardId) {
                linkedWardId = linkedWardObj.id
                wardNickname = linkedWardObj.nickname ?? (try? snakeContainer.decode(String.self, forKey: .wardNickname))
            } else {
                linkedWardId = try? snakeContainer.decode(String.self, forKey: .linkedWardId)
                wardNickname = try? snakeContainer.decode(String.self, forKey: .wardNickname)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(registrationId, forKey: .registrationId)
        try container.encode(wardEmail, forKey: .wardEmail)
        try container.encode(wardPhoneNumber, forKey: .wardPhoneNumber)
        try container.encodeIfPresent(linkedWardId, forKey: .linkedWardId)
        try container.encodeIfPresent(wardNickname, forKey: .wardNickname)
    }

    // 코드에서 직접 생성용
    init(registrationId: String, wardEmail: String, wardPhoneNumber: String, linkedWardId: String? = nil, wardNickname: String? = nil) {
        self.registrationId = registrationId
        self.wardEmail = wardEmail
        self.wardPhoneNumber = wardPhoneNumber
        self.linkedWardId = linkedWardId
        self.wardNickname = wardNickname
    }
}

/// 보호자 상세 정보 응답
struct GuardianInfoResponse: Codable {
    let id: String  // 보호자 고유 ID (필수)
    let wards: [WardRegistrationInfo]  // 다중 어르신 지원

    // MARK: - 하위 호환성 (deprecated - 다중 어르신 지원으로 대체)

    /// 첫 번째 등록된 어르신의 이메일 (하위 호환성)
    var wardEmail: String { wards.first?.wardEmail ?? "" }

    /// 첫 번째 등록된 어르신의 전화번호 (하위 호환성)
    var wardPhoneNumber: String { wards.first?.wardPhoneNumber ?? "" }

    /// 첫 번째 연결된 어르신 (하위 호환성)
    var linkedWard: WardSummary? {
        guard let firstLinked = wards.first(where: { $0.isLinked }),
              let wardId = firstLinked.linkedWardId else {
            return nil
        }
        return WardSummary(
            id: wardId,
            userId: nil,
            nickname: firstLinked.wardNickname ?? firstLinked.wardEmail,
            profileImageUrl: nil,
            phoneNumber: firstLinked.wardPhoneNumber
        )
    }

    /// 연결된 어르신이 있는지 확인
    var hasLinkedWard: Bool { wards.contains { $0.isLinked } }

    /// 연결된 어르신 수
    var linkedWardCount: Int { wards.filter { $0.isLinked }.count }

    enum CodingKeys: String, CodingKey {
        case id
        case wards
        case registrationId
        // 기존 형식 지원
        case wardEmail
        case wardPhoneNumber
        case linkedWardId
        case linkedWard  // 서버가 객체로 보낼 때 사용
        case wardNickname
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case registrationId = "registration_id"
        case wardEmail = "ward_email"
        case wardPhoneNumber = "ward_phone_number"
        case linkedWardId = "linked_ward_id"
        case linkedWard = "linked_ward"
        case wardNickname = "ward_nickname"
    }
    
    /// linkedWard 객체 파싱용
    private struct LinkedWardObject: Codable {
        let id: String
        let nickname: String?
        let profileImageUrl: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        // 먼저 wards 배열 시도 (새 형식)
        if let wardsArray = try? container.decode([WardRegistrationInfo].self, forKey: .wards), !wardsArray.isEmpty {
            wards = wardsArray
        } else {
            // 기존 형식 fallback (wardEmail, wardPhoneNumber가 직접 있는 경우)
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

            // camelCase 또는 snake_case로 wardEmail 찾기
            let email = (try? container.decode(String.self, forKey: .wardEmail))
                ?? (try? snakeContainer.decode(String.self, forKey: .wardEmail))

            if let wardEmail = email {
                let wardPhone = (try? container.decode(String.self, forKey: .wardPhoneNumber))
                    ?? (try? snakeContainer.decode(String.self, forKey: .wardPhoneNumber))
                    ?? ""
                
                // registrationId 추출 (있으면 사용, 없으면 guardianId 사용)
                let regId = (try? container.decode(String.self, forKey: .registrationId))
                    ?? (try? snakeContainer.decode(String.self, forKey: .registrationId))
                    ?? id
                
                // linkedWard 객체에서 id와 nickname 추출 (서버가 객체로 보낼 때)
                var linkedId: String? = nil
                var nickname: String? = nil
                
                if let linkedWardObj = try? container.decode(LinkedWardObject.self, forKey: .linkedWard) {
                    linkedId = linkedWardObj.id
                    nickname = linkedWardObj.nickname
                } else if let linkedWardObj = try? snakeContainer.decode(LinkedWardObject.self, forKey: .linkedWard) {
                    linkedId = linkedWardObj.id
                    nickname = linkedWardObj.nickname
                } else {
                    // linkedWardId 문자열로 직접 시도 (fallback)
                    linkedId = (try? container.decode(String.self, forKey: .linkedWardId))
                        ?? (try? snakeContainer.decode(String.self, forKey: .linkedWardId))
                    nickname = (try? container.decode(String.self, forKey: .wardNickname))
                        ?? (try? snakeContainer.decode(String.self, forKey: .wardNickname))
                }

                let singleWard = WardRegistrationInfo(
                    registrationId: regId,
                    wardEmail: wardEmail,
                    wardPhoneNumber: wardPhone,
                    linkedWardId: linkedId,
                    wardNickname: nickname
                )
                wards = [singleWard]
            } else {
                wards = []
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(wards, forKey: .wards)
    }

    // 코드에서 직접 생성용
    init(id: String, wards: [WardRegistrationInfo]) {
        self.id = id
        self.wards = wards
    }
}

/// 어르신 상세 정보 응답
struct WardInfoResponse: Codable {
    let id: String  // 어르신 고유 ID (필수)
    let phoneNumber: String  // 빈 문자열 가능
    let linkedGuardian: GuardianSummary?
    let linkedOrganization: OrganizationSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber
        case linkedGuardian
        case linkedOrganization
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case linkedGuardian = "linked_guardian"
        case linkedOrganization = "linked_organization"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // id
        id = try container.decode(String.self, forKey: .id)

        // phoneNumber: camelCase와 snake_case 둘 다 지원 (null이면 빈 문자열)
        if let val = try? container.decode(String.self, forKey: .phoneNumber) {
            phoneNumber = val
        } else if let val = try? snakeContainer.decode(String.self, forKey: .phoneNumber) {
            phoneNumber = val
        } else {
            phoneNumber = ""  // null이면 빈 문자열
        }

        // linkedGuardian: camelCase와 snake_case 둘 다 지원
        if let val = try? container.decode(GuardianSummary.self, forKey: .linkedGuardian) {
            linkedGuardian = val
        } else {
            linkedGuardian = try? snakeContainer.decode(GuardianSummary.self, forKey: .linkedGuardian)
        }

        // linkedOrganization: camelCase와 snake_case 둘 다 지원 (백엔드에서 안 보낼 수도 있음)
        if let val = try? container.decode(OrganizationSummary.self, forKey: .linkedOrganization) {
            linkedOrganization = val
        } else {
            linkedOrganization = try? snakeContainer.decode(OrganizationSummary.self, forKey: .linkedOrganization)
        }
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

    /// 보호자 정보 (보호자 로그인 시 포함)
    let guardianInfo: GuardianInfoResponse?

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
        case guardianInfo
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
        case guardianInfo = "guardian_info"
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

        // guardianInfo
        if let val = try? container.decode(GuardianInfoResponse.self, forKey: .guardianInfo) {
            guardianInfo = val
        } else {
            guardianInfo = try? snakeContainer.decode(GuardianInfoResponse.self, forKey: .guardianInfo)
        }

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
        try container.encodeIfPresent(guardianInfo, forKey: .guardianInfo)
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

// MARK: - 통화 관련 응답

/// POST /v1/calls/invite 응답 (camelCase)
struct InviteCallResponse: Codable {
    let callId: String
    let roomName: String
    let state: String
    let deduped: Bool
    let push: PushResultDetail
}

/// 푸시 결과 상세
struct PushResultDetail: Codable {
    let sent: Int
    let failed: Int
    let invalidTokens: [String]  // 빈 배열 가능, non-optional
    let voip: PushStat           // non-optional (필수)
    let alert: PushStat          // non-optional (필수)
}

/// 푸시 통계 (VoIP/Alert 별)
struct PushStat: Codable {
    let sent: Int
    let failed: Int
}

/// 통화 상태 응답 (snake_case - DB 컬럼 그대로 반환)
struct CallStateResponse: Codable {
    let id: String
    let roomName: String
    let callerIdentity: String
    let calleeIdentity: String
    let state: String
    let createdAt: String
    let answeredAt: String?
    let endedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, state
        case roomName = "room_name"
        case callerIdentity = "caller_identity"
        case calleeIdentity = "callee_identity"
        case createdAt = "created_at"
        case answeredAt = "answered_at"
        case endedAt = "ended_at"
    }
}

// MARK: - 디바이스 등록 요청

/// POST /v1/devices/register 요청
struct RegisterDeviceRequest: Codable {
    let identity: String?
    let displayName: String?
    let platform: String
    let env: String
    let apnsToken: String?
    let voipToken: String?
    let supportsCallKit: Bool

    init(
        identity: String? = nil,
        displayName: String? = nil,
        platform: String = "ios",
        env: String,
        apnsToken: String? = nil,
        voipToken: String? = nil,
        supportsCallKit: Bool = true
    ) {
        self.identity = identity
        self.displayName = displayName
        self.platform = platform
        self.env = env
        self.apnsToken = apnsToken
        self.voipToken = voipToken
        self.supportsCallKit = supportsCallKit
    }
}

// MARK: - 위치/비상 요청

/// POST /v1/ward/location 요청
struct UpdateLocationRequest: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let timestamp: String?
}

/// POST /v1/ward/emergency 요청
struct TriggerEmergencyRequest: Codable {
    let type: String
    let message: String?
    let latitude: Double?
    let longitude: Double?
    let accuracy: Double?
}

// MARK: - 통화 분석 응답

/// POST /v1/calls/:callId/analyze 응답
struct CallAnalyzeResponse: Codable {
    let callId: String
    let status: String
    let analysis: CallAnalysis?

    enum CodingKeys: String, CodingKey {
        case callId
        case status
        case analysis
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case callId = "call_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // callId
        if let id = try? container.decode(String.self, forKey: .callId) {
            callId = id
        } else {
            callId = try snakeContainer.decode(String.self, forKey: .callId)
        }

        status = try container.decode(String.self, forKey: .status)
        analysis = try? container.decode(CallAnalysis.self, forKey: .analysis)
    }
}

/// 통화 분석 결과
struct CallAnalysis: Codable {
    let sentiment: String?
    let summary: String?
    let keywords: [String]?
    let emotionScores: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case sentiment
        case summary
        case keywords
        case emotionScores
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case emotionScores = "emotion_scores"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        sentiment = try? container.decode(String.self, forKey: .sentiment)
        summary = try? container.decode(String.self, forKey: .summary)
        keywords = try? container.decode([String].self, forKey: .keywords)

        // emotionScores
        if let scores = try? container.decode([String: Double].self, forKey: .emotionScores) {
            emotionScores = scores
        } else {
            emotionScores = try? snakeContainer.decode([String: Double].self, forKey: .emotionScores)
        }
    }
}

// MARK: - 방 컨텍스트 응답

/// GET /v1/calls/room/:roomName/context 응답
struct RoomContextResponse: Codable {
    let roomName: String
    let callId: String?
    let participants: [RoomParticipant]?
    let state: String?
    let createdAt: String?
    let metadata: RoomMetadata?

    enum CodingKeys: String, CodingKey {
        case roomName
        case callId
        case participants
        case state
        case createdAt
        case metadata
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case roomName = "room_name"
        case callId = "call_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // roomName
        if let name = try? container.decode(String.self, forKey: .roomName) {
            roomName = name
        } else {
            roomName = try snakeContainer.decode(String.self, forKey: .roomName)
        }

        // callId
        if let id = try? container.decode(String.self, forKey: .callId) {
            callId = id
        } else {
            callId = try? snakeContainer.decode(String.self, forKey: .callId)
        }

        participants = try? container.decode([RoomParticipant].self, forKey: .participants)
        state = try? container.decode(String.self, forKey: .state)

        // createdAt
        if let date = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = try? snakeContainer.decode(String.self, forKey: .createdAt)
        }

        metadata = try? container.decode(RoomMetadata.self, forKey: .metadata)
    }
}

/// 방 참가자 정보
struct RoomParticipant: Codable {
    let identity: String
    let name: String?
    let joinedAt: String?

    enum CodingKeys: String, CodingKey {
        case identity
        case name
        case joinedAt
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case joinedAt = "joined_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        identity = try container.decode(String.self, forKey: .identity)
        name = try? container.decode(String.self, forKey: .name)

        // joinedAt
        if let date = try? container.decode(String.self, forKey: .joinedAt) {
            joinedAt = date
        } else {
            joinedAt = try? snakeContainer.decode(String.self, forKey: .joinedAt)
        }
    }
}

/// 방 메타데이터
struct RoomMetadata: Codable {
    let callerIdentity: String?
    let calleeIdentity: String?
    let callType: String?

    enum CodingKeys: String, CodingKey {
        case callerIdentity
        case calleeIdentity
        case callType
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case callerIdentity = "caller_identity"
        case calleeIdentity = "callee_identity"
        case callType = "call_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // callerIdentity
        if let caller = try? container.decode(String.self, forKey: .callerIdentity) {
            callerIdentity = caller
        } else {
            callerIdentity = try? snakeContainer.decode(String.self, forKey: .callerIdentity)
        }

        // calleeIdentity
        if let callee = try? container.decode(String.self, forKey: .calleeIdentity) {
            calleeIdentity = callee
        } else {
            calleeIdentity = try? snakeContainer.decode(String.self, forKey: .calleeIdentity)
        }

        // callType
        if let type = try? container.decode(String.self, forKey: .callType) {
            callType = type
        } else {
            callType = try? snakeContainer.decode(String.self, forKey: .callType)
        }
    }
}

// MARK: - 방 전사 내역 응답

/// GET /v1/calls/room/:roomName/transcripts 응답
struct RoomTranscriptsResponse: Codable {
    let roomName: String
    let transcripts: [TranscriptEntry]

    enum CodingKeys: String, CodingKey {
        case roomName
        case transcripts
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case roomName = "room_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // roomName
        if let name = try? container.decode(String.self, forKey: .roomName) {
            roomName = name
        } else {
            roomName = try snakeContainer.decode(String.self, forKey: .roomName)
        }

        transcripts = (try? container.decode([TranscriptEntry].self, forKey: .transcripts)) ?? []
    }
}

/// 전사 내역 엔트리
struct TranscriptEntry: Codable, Identifiable {
    let id: String
    let speaker: String
    let text: String
    let timestamp: String
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case speaker
        case text
        case timestamp
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id가 없을 경우 UUID 생성
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        speaker = try container.decode(String.self, forKey: .speaker)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        confidence = try? container.decode(Double.self, forKey: .confidence)
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

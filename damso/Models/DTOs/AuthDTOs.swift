//
//  AuthDTOs.swift
//  damso
//
//  인증 관련 DTO (Data Transfer Objects)
//

import Foundation

// MARK: - Auth Request DTOs

/// 카카오 로그인 요청
struct KakaoLoginRequest: Codable {
    let accessToken: String
    let userType: UserType?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userType = "user_type"
    }
}

/// 토큰 갱신 요청
struct TokenRefreshRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

/// 보호자 등록 요청
struct GuardianRegistrationRequest: Codable {
    let tempToken: String
    let wardEmail: String
    let wardPhoneNumber: String
    
    enum CodingKeys: String, CodingKey {
        case tempToken = "temp_token"
        case wardEmail = "ward_email"
        case wardPhoneNumber = "ward_phone_number"
    }
}

/// 어르신 등록 요청
struct WardRegistrationRequest: Codable {
    let tempToken: String
    let phoneNumber: String
    
    enum CodingKeys: String, CodingKey {
        case tempToken = "temp_token"
        case phoneNumber = "phone_number"
    }
}

// MARK: - Auth Response DTOs (Simplified - actual response parsing in APIResponses.swift)

/// 카카오 프로필 정보 (신규 사용자용)
/// Note: Full implementation remains in APIResponses.swift for backward compatibility
extension KakaoProfile {
    /// 편의 초기화 - 코드에서 직접 생성용
    init(kakaoId: String, email: String?, nickname: String?, profileImageUrl: String?) {
        // Codable conformance를 사용하여 초기화
        let data = """
        {
            "kakaoId": "\(kakaoId)",
            "email": \(email.map { "\"\($0)\"" } ?? "null"),
            "nickname": \(nickname.map { "\"\($0)\"" } ?? "null"),
            "profileImageUrl": \(profileImageUrl.map { "\"\($0)\"" } ?? "null")
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        self = try! decoder.decode(KakaoProfile.self, from: data)
    }
}

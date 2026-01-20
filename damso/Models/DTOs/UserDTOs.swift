//
//  UserDTOs.swift
//  damso
//
//  사용자 관련 DTO (Data Transfer Objects)
//

import Foundation

// MARK: - User Request DTOs

/// 프로필 업데이트 요청
struct UpdateProfileRequest: Codable {
    let nickname: String?
    let phoneNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case nickname
        case phoneNumber = "phone_number"
    }
}

/// 푸시 토큰 등록 요청
struct RegisterPushTokenRequest: Codable {
    let deviceToken: String
    let voipToken: String?
    let platform: String = "ios"
    
    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case voipToken = "voip_token"
        case platform
    }
}

// MARK: - User Response Mappers

extension UserMeResponse {
    /// Domain User 모델로 변환
    /// Note: User 모델에는 guardianInfo/wardInfo가 없으므로 기본 정보만 변환
    func toDomainUser() -> User {
        User(
            id: id,
            kakaoId: kakaoId ?? "",
            email: email ?? "",
            nickname: nickname ?? "사용자",
            profileImageUrl: profileImageUrl,
            userType: userType ?? .ward,
            createdAt: createdAt ?? Date()
        )
    }
}

//
//  User.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

/// 공통 사용자 모델
/// 보호자(Guardian)와 어르신(Ward) 모두의 기본 정보를 담습니다
struct User: Codable, Identifiable, Equatable {
    let id: String
    let kakaoId: String
    let email: String
    let nickname: String
    let profileImageUrl: String?
    let userType: UserType
    let createdAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case kakaoId = "kakao_id"
        case email
        case nickname
        case profileImageUrl = "profile_image_url"
        case userType = "user_type"
        case createdAt = "created_at"
    }

    // MARK: - Equatable

    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Mock Data (테스트용)

#if DEBUG
extension User {
    static let mockGuardian = User(
        id: "guardian-uuid-001",
        kakaoId: "1234567890",
        email: "guardian@example.com",
        nickname: "홍길동",
        profileImageUrl: "https://example.com/profile.jpg",
        userType: .guardian,
        createdAt: Date()
    )

    static let mockWard = User(
        id: "ward-uuid-001",
        kakaoId: "0987654321",
        email: "ward@example.com",
        nickname: "어르신",
        profileImageUrl: nil,
        userType: .ward,
        createdAt: Date()
    )
}
#endif

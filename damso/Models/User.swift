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

//
//  SummaryModels.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

// MARK: - Summary Models
// 순환 참조 방지를 위한 경량 요약 모델들

/// 보호자 요약 정보
/// Ward에서 linkedGuardian으로 사용
struct GuardianSummary: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let nickname: String
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case nickname
        case profileImageUrl = "profile_image_url"
    }

    static func == (lhs: GuardianSummary, rhs: GuardianSummary) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 어르신 요약 정보
/// Guardian에서 linkedWard로 사용
struct WardSummary: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let nickname: String
    let profileImageUrl: String?
    let phoneNumber: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case nickname
        case profileImageUrl = "profile_image_url"
        case phoneNumber = "phone_number"
    }

    static func == (lhs: WardSummary, rhs: WardSummary) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 기관 요약 정보
/// Ward에서 linkedOrganization으로 사용
struct OrganizationSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String

    static func == (lhs: OrganizationSummary, rhs: OrganizationSummary) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Mock Data (테스트용)

#if DEBUG
extension GuardianSummary {
    static let mock = GuardianSummary(
        id: "guardian-001",
        userId: "user-001",
        nickname: "보호자",
        profileImageUrl: nil
    )
}

extension WardSummary {
    static let mock = WardSummary(
        id: "ward-001",
        userId: "user-002",
        nickname: "어르신",
        profileImageUrl: nil,
        phoneNumber: "010-1234-5678"
    )
}

extension OrganizationSummary {
    static let mock = OrganizationSummary(
        id: "org-001",
        name: "행복요양원"
    )
}
#endif

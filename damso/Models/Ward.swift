//
//  Ward.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

/// 어르신(피보호자) 모델
/// 보호자(Guardian) 또는 기관(Organization)의 케어를 받는 어르신 정보를 담습니다
struct Ward: Codable, Identifiable, Equatable {
    /// 어르신 고유 ID (User.id와 다름)
    let id: String

    /// 기본 사용자 정보
    let user: User

    /// 어르신 본인의 전화번호
    let phoneNumber: String

    /// 연결된 보호자 요약 정보 (개인 케어 시)
    /// 순환 참조 방지를 위해 GuardianSummary 사용
    var linkedGuardian: GuardianSummary?

    /// 연결된 기관 요약 정보 (기관 케어 시)
    var linkedOrganization: OrganizationSummary?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case phoneNumber = "phone_number"
        case linkedGuardian = "linked_guardian"
        case linkedOrganization = "linked_organization"
    }

    // MARK: - Equatable

    static func == (lhs: Ward, rhs: Ward) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Computed Properties

extension Ward {
    /// 보호자 또는 기관과 연결되었는지 여부
    var isLinked: Bool {
        return linkedGuardian != nil || linkedOrganization != nil
    }

    /// 연결 타입
    var linkType: WardLinkType {
        if linkedGuardian != nil {
            return .guardian
        } else if linkedOrganization != nil {
            return .organization
        } else {
            return .none
        }
    }

    /// 어르신 표시 이름 (User의 nickname)
    var displayName: String {
        return user.nickname
    }
}

/// 어르신 연결 타입
enum WardLinkType {
    case guardian      // 보호자와 연결됨
    case organization  // 기관과 연결됨
    case none          // 미연결

    var displayName: String {
        switch self {
        case .guardian:
            return "보호자 연결"
        case .organization:
            return "기관 연결"
        case .none:
            return "미연결"
        }
    }
}

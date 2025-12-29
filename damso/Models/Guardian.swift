//
//  Guardian.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

/// 보호자 모델
/// 어르신(Ward)을 돌보는 가족 또는 담당자 정보를 담습니다
struct Guardian: Codable, Identifiable, Equatable {
    /// 보호자 고유 ID (User.id와 다름)
    let id: String

    /// 기본 사용자 정보
    let user: User

    /// 연결할 어르신의 이메일 (매칭에 사용)
    let wardEmail: String

    /// 연결할 어르신의 전화번호
    let wardPhoneNumber: String

    /// 연결된 어르신 요약 정보 (매칭 후 설정됨)
    /// 순환 참조 방지를 위해 WardSummary 사용
    var linkedWard: WardSummary?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case wardEmail = "ward_email"
        case wardPhoneNumber = "ward_phone_number"
        case linkedWard = "linked_ward"
    }

    // MARK: - Equatable

    static func == (lhs: Guardian, rhs: Guardian) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Computed Properties

extension Guardian {
    /// 어르신과 연결되었는지 여부
    var isLinkedToWard: Bool {
        return linkedWard != nil
    }

    /// 보호자 표시 이름 (User의 nickname)
    var displayName: String {
        return user.nickname
    }
}

// MARK: - Mock Data (테스트용)

#if DEBUG
extension Guardian {
    static let mock = Guardian(
        id: "guardian-detail-uuid-001",
        user: User.mockGuardian,
        wardEmail: "ward@example.com",
        wardPhoneNumber: "010-1234-5678",
        linkedWard: nil
    )
}
#endif

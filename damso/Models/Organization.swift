//
//  Organization.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

/// 기관 모델
/// 어르신을 케어하는 기관(병원, 요양시설 등) 정보를 담습니다
struct Organization: Codable, Identifiable, Equatable {
    /// 기관 고유 ID
    let id: String

    /// 기관명
    let name: String

    /// 기관 연락처 (선택)
    let phoneNumber: String?

    /// 기관 주소 (선택)
    let address: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phoneNumber = "phone_number"
        case address
    }

    // MARK: - Equatable

    static func == (lhs: Organization, rhs: Organization) -> Bool {
        return lhs.id == rhs.id
    }
}

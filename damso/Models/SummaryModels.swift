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
    let userId: String?  // 백엔드에서 안 보내는 경우 있음
    let nickname: String
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case nickname
        case profileImageUrl
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case userId = "user_id"
        case profileImageUrl = "profile_image_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)

        // userId: camelCase와 snake_case 둘 다 지원 (optional)
        if let val = try? container.decode(String.self, forKey: .userId) {
            userId = val
        } else {
            userId = try? snakeContainer.decode(String.self, forKey: .userId)
        }

        // profileImageUrl: camelCase와 snake_case 둘 다 지원
        if let val = try? container.decode(String.self, forKey: .profileImageUrl) {
            profileImageUrl = val
        } else {
            profileImageUrl = try? snakeContainer.decode(String.self, forKey: .profileImageUrl)
        }
    }

    init(id: String, userId: String?, nickname: String, profileImageUrl: String?) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.profileImageUrl = profileImageUrl
    }

    static func == (lhs: GuardianSummary, rhs: GuardianSummary) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 어르신 요약 정보
/// Guardian에서 linkedWard로 사용
struct WardSummary: Codable, Identifiable, Equatable {
    let id: String
    let userId: String?  // 백엔드에서 안 보내는 경우 있음
    let nickname: String
    let profileImageUrl: String?
    let phoneNumber: String?  // 백엔드에서 안 보내는 경우 있음

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case nickname
        case profileImageUrl
        case phoneNumber
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case userId = "user_id"
        case profileImageUrl = "profile_image_url"
        case phoneNumber = "phone_number"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)

        // userId: camelCase와 snake_case 둘 다 지원 (optional)
        if let val = try? container.decode(String.self, forKey: .userId) {
            userId = val
        } else {
            userId = try? snakeContainer.decode(String.self, forKey: .userId)
        }

        // profileImageUrl: camelCase와 snake_case 둘 다 지원
        if let val = try? container.decode(String.self, forKey: .profileImageUrl) {
            profileImageUrl = val
        } else {
            profileImageUrl = try? snakeContainer.decode(String.self, forKey: .profileImageUrl)
        }

        // phoneNumber: camelCase와 snake_case 둘 다 지원 (optional)
        if let val = try? container.decode(String.self, forKey: .phoneNumber) {
            phoneNumber = val
        } else {
            phoneNumber = try? snakeContainer.decode(String.self, forKey: .phoneNumber)
        }
    }

    init(id: String, userId: String?, nickname: String, profileImageUrl: String?, phoneNumber: String?) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.profileImageUrl = profileImageUrl
        self.phoneNumber = phoneNumber
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

//
//  AIPersona.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

/// AI 페르소나 (AI 친구 캐릭터)
enum AIPersona: String, CaseIterable, Identifiable, Codable {
    case dami = "dami"
    case tori = "tori"
    case bear = "bear"

    var id: String { rawValue }

    /// 표시 이름
    var displayName: String {
        switch self {
        case .dami: return "다미"
        case .tori: return "토리"
        case .bear: return "곰돌이"
        }
    }

    /// 캐릭터 설명
    var description: String {
        switch self {
        case .dami: return "기본 AI 친구"
        case .tori: return "활발한 성격"
        case .bear: return "차분한 성격"
        }
    }

    /// 이모지 아이콘
    var emoji: String {
        switch self {
        case .dami: return "🤖"
        case .tori: return "🐰"
        case .bear: return "🐻"
        }
    }
}

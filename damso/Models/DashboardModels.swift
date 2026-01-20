//
//  DashboardModels.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

// MARK: - 대시보드 API 응답

/// 보호자 대시보드 응답
struct GuardianDashboardResponse: Codable {
    let wardId: String?         // 조회된 어르신 ID
    let wardName: String?       // 어르신 이름
    let statistics: DashboardStatistics
    let aiSummary: String?      // 서버에서 생성한 AI 요약 메시지
    let alerts: [DashboardAlert]
    let recentCalls: [RecentCall]
}

/// 대시보드 통계
struct DashboardStatistics: Codable {
    let totalCalls: Int
    let weeklyChange: Int
    let averageDuration: Int
    let overallMood: MoodStatistics

    // 서버가 camelCase로 응답하므로 CodingKeys 불필요
}

/// 기분 통계
struct MoodStatistics: Codable {
    let positive: Int
    let negative: Int
}

/// 대시보드 알림
struct DashboardAlert: Codable, Identifiable {
    let id: String
    let type: AlertType
    let message: String
    let date: String

    enum AlertType: String, Codable {
        case warning
        case info
    }
}

/// 최근 통화
struct RecentCall: Codable, Identifiable {
    let id: String
    let date: Date
    let duration: Int
    let summary: String
    let tags: [String]
    let mood: CallMood

    enum CallMood: String, Codable {
        case positive
        case neutral
        case negative
    }
}

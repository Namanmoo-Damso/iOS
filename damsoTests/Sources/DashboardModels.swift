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
    let statistics: DashboardStatistics
    let alerts: [DashboardAlert]
    let recentCalls: [RecentCall]

    enum CodingKeys: String, CodingKey {
        case statistics
        case alerts
        case recentCalls = "recent_calls"
    }
}

/// 대시보드 통계
struct DashboardStatistics: Codable {
    let totalCalls: Int
    let weeklyChange: Int
    let averageDuration: Int
    let overallMood: MoodStatistics

    enum CodingKeys: String, CodingKey {
        case totalCalls = "total_calls"
        case weeklyChange = "weekly_change"
        case averageDuration = "average_duration"
        case overallMood = "overall_mood"
    }
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

// MARK: - Mock Data

#if DEBUG
extension GuardianDashboardResponse {
    static let mock = GuardianDashboardResponse(
        statistics: DashboardStatistics(
            totalCalls: 24,
            weeklyChange: 3,
            averageDuration: 11,
            overallMood: MoodStatistics(positive: 85, negative: 15)
        ),
        alerts: [
            DashboardAlert(
                id: "1",
                type: .warning,
                message: "3일 연속 통증 관련 단어가 감지되었습니다",
                date: "2024-12-24"
            ),
            DashboardAlert(
                id: "2",
                type: .info,
                message: "대화 빈도가 지난주 대비 증가했습니다",
                date: "2024-12-23"
            )
        ],
        recentCalls: [
            RecentCall(
                id: "1",
                date: Date(),
                duration: 12,
                summary: "어머니께서 오늘 날씨가 좋다고 말씀하시며 산책을 다녀오셨다고 하셨습니다.",
                tags: ["날씨", "산책", "긍정적"],
                mood: .positive
            ),
            RecentCall(
                id: "2",
                date: Date().addingTimeInterval(-86400),
                duration: 8,
                summary: "평소와 같은 일상 대화를 나누셨습니다.",
                tags: ["일상"],
                mood: .neutral
            )
        ]
    )
}
#endif

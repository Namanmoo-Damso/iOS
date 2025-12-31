//
//  ReportModels.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

// MARK: - 보고서 API 응답

/// 보호자 분석 보고서 응답
struct GuardianReportResponse: Codable {
    let period: String?
    let emotionTrend: [EmotionDataPoint]
    let healthKeywords: HealthKeywords
    let topTopics: [TopTopic]?
    let weeklySummary: String
    let recommendations: [String]?

    // 서버가 camelCase로 응답하므로 CodingKeys 불필요
}

/// 인기 주제
struct TopTopic: Codable {
    let topic: String
    let count: Int
}

/// 감정 데이터 포인트
struct EmotionDataPoint: Codable, Identifiable {
    let date: String
    let score: Double
    let mood: EmotionMood

    var id: String { date }

    /// Date 객체로 변환
    var dateValue: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }

    enum EmotionMood: String, Codable {
        case positive
        case neutral
        case negative
    }
}

/// 건강 키워드
struct HealthKeywords: Codable {
    let pain: KeywordAnalysis
    let sleep: StatusAnalysis
    let meal: StatusAnalysis

    struct KeywordAnalysis: Codable {
        let count: Int
        let trend: String
    }

    struct StatusAnalysis: Codable {
        let status: String
    }
}

// MARK: - Mock Data

#if DEBUG
extension GuardianReportResponse {
    static let mock = GuardianReportResponse(
        period: "week",
        emotionTrend: [
            EmotionDataPoint(date: "2024-12-23", score: 0.8, mood: .positive),
            EmotionDataPoint(date: "2024-12-24", score: 0.85, mood: .positive),
            EmotionDataPoint(date: "2024-12-25", score: 0.75, mood: .positive),
            EmotionDataPoint(date: "2024-12-26", score: 0.6, mood: .neutral),
            EmotionDataPoint(date: "2024-12-27", score: 0.55, mood: .neutral),
            EmotionDataPoint(date: "2024-12-28", score: 0.7, mood: .positive),
            EmotionDataPoint(date: "2024-12-29", score: 0.8, mood: .positive)
        ],
        healthKeywords: HealthKeywords(
            pain: HealthKeywords.KeywordAnalysis(count: 3, trend: "increasing"),
            sleep: HealthKeywords.StatusAnalysis(status: "good"),
            meal: HealthKeywords.StatusAnalysis(status: "regular")
        ),
        topTopics: [
            TopTopic(topic: "날씨", count: 5),
            TopTopic(topic: "손주", count: 4),
            TopTopic(topic: "건강", count: 3)
        ],
        weeklySummary: "이번 주 어머니께서는 전반적으로 긍정적인 감정 상태를 보이셨습니다. 손주 이야기를 자주 하시며 즐거워하셨습니다. 다만 허리 통증을 3회 언급하셨으니 확인이 필요합니다.",
        recommendations: ["통증 관련 언급이 있었습니다. 건강 상태를 확인해보세요."]
    )
}
#endif

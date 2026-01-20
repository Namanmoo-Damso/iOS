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

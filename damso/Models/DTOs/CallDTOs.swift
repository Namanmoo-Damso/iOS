//
//  CallDTOs.swift
//  damso
//
//  통화 관련 DTO (Data Transfer Objects)
//

import Foundation

// MARK: - Call Request DTOs

/// 통화 시작 요청
struct StartCallRequest: Codable {
    let wardId: String
    let callType: String  // "ai", "guardian"
    
    enum CodingKeys: String, CodingKey {
        case wardId = "ward_id"
        case callType = "call_type"
    }
}

/// 통화 종료 요청
struct EndCallRequest: Codable {
    let callId: String
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case reason
    }
}

/// 통화 기록 조회 요청
struct CallHistoryRequest: Codable {
    let wardId: String?
    let page: Int
    let limit: Int
    let startDate: Date?
    let endDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case wardId = "ward_id"
        case page
        case limit
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

// MARK: - Call Response DTOs

/// 통화 기록 목록 응답
struct CallHistoryResponse: Codable {
    let calls: [CallRecordDTO]
    let totalCount: Int
    let page: Int
    let limit: Int
    
    enum CodingKeys: String, CodingKey {
        case calls
        case totalCount = "total_count"
        case page
        case limit
    }
}

/// 단일 통화 기록 DTO
struct CallRecordDTO: Codable, Identifiable {
    let id: String
    let wardId: String
    let callType: String
    let startTime: Date
    let endTime: Date?
    let duration: Int  // 초 단위
    let summary: String?
    let mood: String?  // "positive", "negative", "neutral"
    let transcription: String?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case wardId = "ward_id"
        case callType = "call_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case summary
        case mood
        case transcription
        case tags
    }
    
    /// Domain RecentCall 모델로 변환
    func toRecentCall() -> RecentCall {
        RecentCall(
            id: id,
            date: startTime,
            duration: duration / 60,  // 분 단위로 변환
            summary: summary ?? "대화 요약 없음",
            tags: tags ?? [],
            mood: RecentCall.CallMood(rawValue: mood ?? "neutral") ?? .neutral
        )
    }
}

// MARK: - Call Detail Response

/// 통화 상세 정보 응답
struct CallDetailResponse: Codable {
    let call: CallRecordDTO
    let transcription: String?
    let emotionAnalysis: EmotionAnalysisDTO?
    let keywords: [KeywordDTO]?
    let highlights: [HighlightDTO]?
    let aiInsight: String?
    
    enum CodingKeys: String, CodingKey {
        case call
        case transcription
        case emotionAnalysis = "emotion_analysis"
        case keywords
        case highlights
        case aiInsight = "ai_insight"
    }
}

/// 감정 분석 DTO
struct EmotionAnalysisDTO: Codable {
    let positive: Double
    let negative: Double
    let neutral: Double
}

/// 키워드 DTO
struct KeywordDTO: Codable {
    let keyword: String
    let frequency: Int
}

/// 하이라이트 DTO
struct HighlightDTO: Codable {
    let speaker: String
    let text: String
    let timestamp: Double  // 초 단위
}

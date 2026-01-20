//
//  CallServiceModels.swift
//  damso
//
//  통화 API 서비스 요청/응답 모델 정의
//  - POST /v1/calls/invite: 통화 초대
//  - POST /v1/calls/:callId/analyze: 통화 분석
//  - GET /v1/calls/room/:roomName/context: 방 컨텍스트 조회
//  - GET /v1/calls/room/:roomName/transcripts: 방 전사 내역 조회
//

import Foundation

// MARK: - 통화 초대 요청

/// POST /v1/calls/invite 요청
struct InviteCallRequest: Codable {
    /// 어르신 ID
    let wardId: String

    /// 통화 유형 (기본: video)
    let callType: CallType?

    /// 우선순위 (긴급 통화 등)
    let priority: CallPriority?

    /// 추가 메타데이터
    let metadata: [String: String]?

    init(
        wardId: String,
        callType: CallType? = nil,
        priority: CallPriority? = nil,
        metadata: [String: String]? = nil
    ) {
        self.wardId = wardId
        self.callType = callType
        self.priority = priority
        self.metadata = metadata
    }
}

// MARK: - 통화 유형

/// 통화 유형 enum
enum CallType: String, Codable, CaseIterable {
    /// 영상통화
    case video

    /// 음성통화
    case audio

    /// AI 봇 통화
    case aiBot = "ai_bot"
}

// MARK: - 통화 우선순위

/// 통화 우선순위 enum
enum CallPriority: String, Codable, CaseIterable {
    /// 일반 통화
    case normal

    /// 긴급 통화
    case urgent

    /// 예약 통화
    case scheduled
}

// MARK: - 통화 상태

/// 통화 상태 enum
enum CallState: String, Codable, CaseIterable {
    /// 초대 중 (링 울리는 중)
    case ringing

    /// 연결됨 (통화 중)
    case connected

    /// 종료됨
    case ended

    /// 부재중
    case missed

    /// 거절됨
    case rejected

    /// 실패
    case failed

    /// 대기 중
    case pending

    /// 표시용 문자열
    var displayName: String {
        switch self {
        case .ringing:
            return "연결 중"
        case .connected:
            return "통화 중"
        case .ended:
            return "종료됨"
        case .missed:
            return "부재중"
        case .rejected:
            return "거절됨"
        case .failed:
            return "실패"
        case .pending:
            return "대기 중"
        }
    }
}

// MARK: - 통화 분석 요청

/// POST /v1/calls/:callId/analyze 요청
struct AnalyzeCallRequest: Codable {
    /// 분석 유형 (기본: full)
    let analysisType: AnalysisType?

    /// 분석할 언어 (기본: ko)
    let language: String?

    /// 감정 분석 포함 여부
    let includeEmotions: Bool?

    /// 요약 포함 여부
    let includeSummary: Bool?

    /// 키워드 추출 포함 여부
    let includeKeywords: Bool?

    init(
        analysisType: AnalysisType? = nil,
        language: String? = "ko",
        includeEmotions: Bool? = true,
        includeSummary: Bool? = true,
        includeKeywords: Bool? = true
    ) {
        self.analysisType = analysisType
        self.language = language
        self.includeEmotions = includeEmotions
        self.includeSummary = includeSummary
        self.includeKeywords = includeKeywords
    }
}

// MARK: - 분석 유형

/// 통화 분석 유형 enum
enum AnalysisType: String, Codable, CaseIterable {
    /// 전체 분석
    case full

    /// 감정 분석만
    case emotionOnly = "emotion_only"

    /// 요약만
    case summaryOnly = "summary_only"

    /// 키워드만
    case keywordsOnly = "keywords_only"
}

// MARK: - 감정 분석 결과

/// 감정 분석 세부 결과
struct EmotionAnalysisResult: Codable, Equatable {
    /// 전반적인 감정 (positive, negative, neutral)
    let overallSentiment: String

    /// 감정 점수 (0.0 ~ 1.0)
    let sentimentScore: Double

    /// 개별 감정 점수
    let emotions: [String: Double]

    /// 주요 감정
    let dominantEmotion: String?

    enum CodingKeys: String, CodingKey {
        case overallSentiment
        case sentimentScore
        case emotions
        case dominantEmotion
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case overallSentiment = "overall_sentiment"
        case sentimentScore = "sentiment_score"
        case dominantEmotion = "dominant_emotion"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // overallSentiment
        if let val = try? container.decode(String.self, forKey: .overallSentiment) {
            overallSentiment = val
        } else {
            overallSentiment = (try? snakeContainer.decode(String.self, forKey: .overallSentiment)) ?? "neutral"
        }

        // sentimentScore
        if let val = try? container.decode(Double.self, forKey: .sentimentScore) {
            sentimentScore = val
        } else {
            sentimentScore = (try? snakeContainer.decode(Double.self, forKey: .sentimentScore)) ?? 0.5
        }

        emotions = (try? container.decode([String: Double].self, forKey: .emotions)) ?? [:]

        // dominantEmotion
        if let val = try? container.decode(String.self, forKey: .dominantEmotion) {
            dominantEmotion = val
        } else {
            dominantEmotion = try? snakeContainer.decode(String.self, forKey: .dominantEmotion)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(overallSentiment, forKey: .overallSentiment)
        try container.encode(sentimentScore, forKey: .sentimentScore)
        try container.encode(emotions, forKey: .emotions)
        try container.encodeIfPresent(dominantEmotion, forKey: .dominantEmotion)
    }

    // 코드에서 직접 생성용
    init(
        overallSentiment: String,
        sentimentScore: Double,
        emotions: [String: Double],
        dominantEmotion: String? = nil
    ) {
        self.overallSentiment = overallSentiment
        self.sentimentScore = sentimentScore
        self.emotions = emotions
        self.dominantEmotion = dominantEmotion
    }
}

// MARK: - 통화 요약 정보

/// 통화 요약 (대시보드용)
struct CallSummary: Codable, Identifiable, Equatable {
    let id: String
    let roomName: String
    let callerIdentity: String
    let calleeIdentity: String
    let state: CallState
    let duration: Int?  // 초 단위
    let createdAt: Date
    let endedAt: Date?
    let hasTranscript: Bool
    let hasAnalysis: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case roomName
        case callerIdentity
        case calleeIdentity
        case state
        case duration
        case createdAt
        case endedAt
        case hasTranscript
        case hasAnalysis
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case roomName = "room_name"
        case callerIdentity = "caller_identity"
        case calleeIdentity = "callee_identity"
        case createdAt = "created_at"
        case endedAt = "ended_at"
        case hasTranscript = "has_transcript"
        case hasAnalysis = "has_analysis"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        // roomName
        if let val = try? container.decode(String.self, forKey: .roomName) {
            roomName = val
        } else {
            roomName = try snakeContainer.decode(String.self, forKey: .roomName)
        }

        // callerIdentity
        if let val = try? container.decode(String.self, forKey: .callerIdentity) {
            callerIdentity = val
        } else {
            callerIdentity = try snakeContainer.decode(String.self, forKey: .callerIdentity)
        }

        // calleeIdentity
        if let val = try? container.decode(String.self, forKey: .calleeIdentity) {
            calleeIdentity = val
        } else {
            calleeIdentity = try snakeContainer.decode(String.self, forKey: .calleeIdentity)
        }

        state = try container.decode(CallState.self, forKey: .state)
        duration = try? container.decode(Int.self, forKey: .duration)

        // createdAt
        if let val = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = val
        } else {
            createdAt = try snakeContainer.decode(Date.self, forKey: .createdAt)
        }

        // endedAt
        if let val = try? container.decode(Date.self, forKey: .endedAt) {
            endedAt = val
        } else {
            endedAt = try? snakeContainer.decode(Date.self, forKey: .endedAt)
        }

        // hasTranscript
        if let val = try? container.decode(Bool.self, forKey: .hasTranscript) {
            hasTranscript = val
        } else {
            hasTranscript = (try? snakeContainer.decode(Bool.self, forKey: .hasTranscript)) ?? false
        }

        // hasAnalysis
        if let val = try? container.decode(Bool.self, forKey: .hasAnalysis) {
            hasAnalysis = val
        } else {
            hasAnalysis = (try? snakeContainer.decode(Bool.self, forKey: .hasAnalysis)) ?? false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roomName, forKey: .roomName)
        try container.encode(callerIdentity, forKey: .callerIdentity)
        try container.encode(calleeIdentity, forKey: .calleeIdentity)
        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(hasTranscript, forKey: .hasTranscript)
        try container.encode(hasAnalysis, forKey: .hasAnalysis)
    }

    // 코드에서 직접 생성용
    init(
        id: String,
        roomName: String,
        callerIdentity: String,
        calleeIdentity: String,
        state: CallState,
        duration: Int? = nil,
        createdAt: Date,
        endedAt: Date? = nil,
        hasTranscript: Bool = false,
        hasAnalysis: Bool = false
    ) {
        self.id = id
        self.roomName = roomName
        self.callerIdentity = callerIdentity
        self.calleeIdentity = calleeIdentity
        self.state = state
        self.duration = duration
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.hasTranscript = hasTranscript
        self.hasAnalysis = hasAnalysis
    }

    /// 통화 시간 문자열 (mm:ss 형식)
    var durationString: String {
        guard let duration = duration else { return "--:--" }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 전사 세그먼트

/// 전사 세그먼트 (시간 기반)
struct TranscriptSegment: Codable, Identifiable, Equatable {
    let id: String
    let speaker: String
    let text: String
    let startTime: Double  // 초 단위
    let endTime: Double    // 초 단위
    let confidence: Double?
    let language: String?

    enum CodingKeys: String, CodingKey {
        case id
        case speaker
        case text
        case startTime
        case endTime
        case confidence
        case language
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // id가 없을 경우 UUID 생성
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        speaker = try container.decode(String.self, forKey: .speaker)
        text = try container.decode(String.self, forKey: .text)

        // startTime
        if let val = try? container.decode(Double.self, forKey: .startTime) {
            startTime = val
        } else {
            startTime = try snakeContainer.decode(Double.self, forKey: .startTime)
        }

        // endTime
        if let val = try? container.decode(Double.self, forKey: .endTime) {
            endTime = val
        } else {
            endTime = try snakeContainer.decode(Double.self, forKey: .endTime)
        }

        confidence = try? container.decode(Double.self, forKey: .confidence)
        language = try? container.decode(String.self, forKey: .language)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(speaker, forKey: .speaker)
        try container.encode(text, forKey: .text)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(language, forKey: .language)
    }

    // 코드에서 직접 생성용
    init(
        id: String = UUID().uuidString,
        speaker: String,
        text: String,
        startTime: Double,
        endTime: Double,
        confidence: Double? = nil,
        language: String? = nil
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.language = language
    }

    /// 세그먼트 길이 (초)
    var duration: Double {
        endTime - startTime
    }

    /// 시작 시간 문자열 (mm:ss 형식)
    var startTimeString: String {
        let minutes = Int(startTime) / 60
        let seconds = Int(startTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

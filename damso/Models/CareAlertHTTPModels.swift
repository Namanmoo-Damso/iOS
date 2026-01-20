//
//  CareAlertHTTPModels.swift
//  damso
//
//  Care Alert HTTP API 요청/응답 모델
//

import Foundation

// MARK: - 요청 모델

/// 케어 알림 생성 요청
struct CreateCareAlertRequest: Codable, Sendable {
    /// 알림 타입 (device_fall, person_fall, loud_voice, emotion)
    let alertType: String

    /// 심각도 (low, medium, high, critical)
    let severity: String

    /// Ward ID
    let wardId: String

    /// 알림 상세 데이터 (JSON)
    let data: [String: AnyCodableValue]?

    /// 메시지 (선택)
    let message: String?

    init(
        alertType: CareAlertType,
        severity: CareAlertSeverity,
        wardId: String,
        data: [String: AnyCodableValue]? = nil,
        message: String? = nil
    ) {
        self.alertType = alertType.rawValue
        self.severity = severity.rawValue
        self.wardId = wardId
        self.data = data
        self.message = message
    }
}

// MARK: - 응답 모델

/// 단일 케어 알림 응답
struct CareAlertResponse: Codable, Sendable {
    /// 알림 ID
    let id: String

    /// 알림 타입
    let alertType: String

    /// 심각도
    let severity: String

    /// Ward ID
    let wardId: String

    /// 알림 상세 데이터
    let data: [String: AnyCodableValue]?

    /// 메시지
    let message: String?

    /// 확인 여부
    let isAcknowledged: Bool

    /// 확인 시각
    let acknowledgedAt: Date?

    /// 생성 시각
    let createdAt: Date

    /// 수정 시각
    let updatedAt: Date?
}

/// 케어 알림 목록 응답 (페이지네이션)
struct CareAlertListResponse: Codable, Sendable {
    /// 알림 목록
    let alerts: [CareAlertResponse]

    /// 페이지네이션 정보
    let pagination: PaginationInfo
}

/// 페이지네이션 정보
struct PaginationInfo: Codable, Sendable {
    /// 현재 페이지
    let page: Int

    /// 페이지당 항목 수
    let limit: Int

    /// 전체 항목 수
    let total: Int

    /// 전체 페이지 수
    let totalPages: Int

    /// 다음 페이지 존재 여부
    var hasNextPage: Bool {
        page < totalPages
    }

    /// 이전 페이지 존재 여부
    var hasPreviousPage: Bool {
        page > 1
    }
}

// MARK: - 감정 리포트 응답

/// 감정 분석 리포트 응답
struct EmotionReportResponse: Codable, Sendable {
    /// Ward ID
    let wardId: String

    /// 조회 시작일
    let startDate: Date?

    /// 조회 종료일
    let endDate: Date?

    /// 감정 분포 통계
    let emotionDistribution: [EmotionStatItem]

    /// 일별 감정 트렌드
    let dailyTrends: [DailyEmotionTrend]?

    /// 주요 감정 (가장 빈번한 감정)
    let dominantEmotion: String?

    /// 분석 기간 동안 총 감정 감지 횟수
    let totalDetections: Int

    /// 평균 신뢰도
    let averageConfidence: Float?
}

/// 감정 통계 항목
struct EmotionStatItem: Codable, Sendable {
    /// 감정 유형
    let emotion: String

    /// 감지 횟수
    let count: Int

    /// 비율 (0.0 ~ 1.0)
    let percentage: Float

    /// 평균 강도
    let averageIntensity: Float?
}

/// 일별 감정 트렌드
struct DailyEmotionTrend: Codable, Sendable {
    /// 날짜
    let date: Date

    /// 주요 감정
    let dominantEmotion: String

    /// 감정 분포
    let emotions: [EmotionStatItem]

    /// 감지 횟수
    let detectionCount: Int
}

// MARK: - 버퍼 상태 응답

/// 버퍼 상태 응답
struct BufferStatusResponse: Codable, Sendable {
    /// 현재 버퍼 크기
    let currentSize: Int

    /// 최대 버퍼 크기
    let maxSize: Int

    /// 버퍼 사용률 (0.0 ~ 1.0)
    let usageRate: Float

    /// 대기 중인 알림 수
    let pendingAlerts: Int

    /// 마지막 플러시 시각
    let lastFlushAt: Date?

    /// 서버 상태
    let status: String
}

// MARK: - AnyCodableValue (JSON 동적 값 지원)

/// JSON 동적 값을 위한 타입
enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayValue)
        } else if let dictValue = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodableValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Error

/// Care Alert HTTP API 에러
enum CareAlertHTTPError: LocalizedError {
    case missingAuthToken
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case httpError(statusCode: Int, body: String)
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "인증 토큰이 없습니다"
        case .invalidURL:
            return "잘못된 URL입니다"
        case .invalidResponse:
            return "잘못된 서버 응답입니다"
        case .unauthorized:
            return "인증이 만료되었습니다"
        case .notFound:
            return "알림을 찾을 수 없습니다"
        case .httpError(let statusCode, let body):
            return "HTTP 에러 (\(statusCode)): \(body)"
        case .decodingError(let message):
            return "디코딩 에러: \(message)"
        case .networkError(let message):
            return "네트워크 에러: \(message)"
        }
    }
}

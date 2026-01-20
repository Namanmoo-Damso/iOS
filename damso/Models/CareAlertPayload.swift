//
//  CareAlertPayload.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//

import Foundation

// MARK: - Care Alert Payload

/// 케어 알림 통합 페이로드
/// Agent로 전송되는 4가지 알림 타입을 통합 관리
struct CareAlertPayload: Codable, Sendable {
    /// 타임스탬프 (Unix milliseconds)
    let timestamp: Int64

    /// 알림 타입
    let alertType: CareAlertType

    /// 알림 심각도
    let severity: CareAlertSeverity

    /// 알림 상세 데이터
    let data: CareAlertData

    init(alertType: CareAlertType, severity: CareAlertSeverity, data: CareAlertData) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.alertType = alertType
        self.severity = severity
        self.data = data
    }
}

// MARK: - Alert Type

/// 케어 알림 타입
enum CareAlertType: String, Codable, Sendable {
    /// 기기 낙상 감지 (자이로센서/가속도계 기반)
    case deviceFall = "device_fall"

    /// 사람 낙상 감지 (카메라 기반 얼굴 추적)
    case personFall = "person_fall"

    /// 음성 레벨 경고 (큰 소리/비명)
    case loudVoice = "loud_voice"

    /// 감정 분석 결과
    case emotion = "emotion"

    /// 위험 상황 해제 (사용자 확인)
    case dangerDismissed = "danger_dismissed"

    // MARK: - Agent → iOS 요청 타입

    /// Agent가 낙상 확인 Alert 표시 요청 (음성 질문 후 응답 없을 때)
    case requestFallConfirmation = "request_fall_confirmation"

    /// Agent가 긴급 상황 확정 (보호자 알림 필요)
    case emergencyConfirmed = "emergency_confirmed"
}

// MARK: - Alert Severity

/// 알림 심각도
enum CareAlertSeverity: String, Codable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - Alert Data (Union Type)

/// 알림 상세 데이터 (타입별 다른 구조)
enum CareAlertData: Codable, Sendable {
    case deviceFall(DeviceFallAlertData)
    case personFall(PersonFallAlertData)
    case loudVoice(LoudVoiceAlertData)
    case emotion(EmotionAlertData)
    case dangerDismissed(DangerDismissedData)
    case requestFallConfirmation(RequestFallConfirmationData)
    case emergencyConfirmed(EmergencyConfirmedData)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "device_fall":
            let payload = try container.decode(DeviceFallAlertData.self, forKey: .payload)
            self = .deviceFall(payload)
        case "person_fall":
            let payload = try container.decode(PersonFallAlertData.self, forKey: .payload)
            self = .personFall(payload)
        case "loud_voice":
            let payload = try container.decode(LoudVoiceAlertData.self, forKey: .payload)
            self = .loudVoice(payload)
        case "emotion":
            let payload = try container.decode(EmotionAlertData.self, forKey: .payload)
            self = .emotion(payload)
        case "danger_dismissed":
            let payload = try container.decode(DangerDismissedData.self, forKey: .payload)
            self = .dangerDismissed(payload)
        case "request_fall_confirmation":
            let payload = try container.decode(RequestFallConfirmationData.self, forKey: .payload)
            self = .requestFallConfirmation(payload)
        case "emergency_confirmed":
            let payload = try container.decode(EmergencyConfirmedData.self, forKey: .payload)
            self = .emergencyConfirmed(payload)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown alert type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .deviceFall(let data):
            try container.encode("device_fall", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .personFall(let data):
            try container.encode("person_fall", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .loudVoice(let data):
            try container.encode("loud_voice", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .emotion(let data):
            try container.encode("emotion", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .dangerDismissed(let data):
            try container.encode("danger_dismissed", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .requestFallConfirmation(let data):
            try container.encode("request_fall_confirmation", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .emergencyConfirmed(let data):
            try container.encode("emergency_confirmed", forKey: .type)
            try container.encode(data, forKey: .payload)
        }
    }
}

// MARK: - Device Fall Alert Data

/// 기기 낙상 알림 데이터
struct DeviceFallAlertData: Codable, Sendable {
    /// 충격 크기 (g 단위)
    let impactMagnitude: Float

    /// 낙상 유형
    let fallType: DeviceFallType

    /// 낙하 전 자유낙하 시간 (초)
    let freefallDuration: Float?

    /// 최대 회전 속도 (rad/s)
    let maxRotationRate: Float?

    /// 위험 수준 (normal/caution/critical)
    let riskLevel: DeviceFallRiskLevel?

    /// 위험도 점수 (0.0 ~ 1.0)
    let riskScore: Float?

    enum DeviceFallType: String, Codable, Sendable {
        /// 자유 낙하 후 충격
        case freefallImpact = "freefall_impact"
        /// 단순 충격
        case impact = "impact"
        /// 급격한 회전 + 충격
        case rotationImpact = "rotation_impact"
        /// 복합 감지
        case combination = "combination"
    }

    /// 위험 수준 (페이로드용)
    enum DeviceFallRiskLevel: String, Codable, Sendable {
        case normal = "normal"
        case caution = "caution"
        case critical = "critical"
    }
}

// MARK: - Person Fall Alert Data

/// 사람 낙상 알림 데이터 (카메라 기반)
struct PersonFallAlertData: Codable, Sendable {
    /// 감지 유형
    let detectionType: PersonFallDetectionType

    /// 얼굴 Y좌표 변화량 (정규화, 0-1)
    let faceYDelta: Float?

    /// 변화 소요 시간 (초)
    let deltaTime: Float?

    /// 얼굴 마지막 위치 (정규화 좌표)
    let lastFacePosition: NormalizedPosition?

    enum PersonFallDetectionType: String, Codable, Sendable {
        /// 얼굴 Y좌표 급강하
        case rapidDescent = "rapid_descent"
        /// 얼굴 갑자기 사라짐
        case faceDisappeared = "face_disappeared"
        /// 얼굴 크기 급변
        case sizeChange = "size_change"
    }

    struct NormalizedPosition: Codable, Sendable {
        let x: Float
        let y: Float
    }
}

// MARK: - Loud Voice Alert Data

/// 음성 레벨 경고 데이터
struct LoudVoiceAlertData: Codable, Sendable {
    /// 감지된 음량 레벨 (0.0 ~ 1.0 정규화)
    let level: Float

    /// 데시벨 (dB)
    let decibel: Float

    /// 임계값 초과 지속 시간 (초)
    let duration: Float

    /// 가능한 원인 추정
    let possibleCause: PossibleCause?

    enum PossibleCause: String, Codable, Sendable {
        /// 비명/고함
        case scream = "scream"
        /// 큰 소리로 말함
        case loudSpeech = "loud_speech"
        /// 알 수 없음
        case unknown = "unknown"
    }
}

// MARK: - Emotion Alert Data

/// 감정 분석 결과 데이터
struct EmotionAlertData: Codable, Sendable {
    /// 감지된 감정
    let emotion: DetectedEmotion

    /// 신뢰도 (0.0 ~ 1.0)
    let confidence: Float

    /// 감정 강도 (0.0 ~ 1.0)
    let intensity: Float?

    /// 이전 감정 (변화 추적용)
    let previousEmotion: DetectedEmotion?

    /// 분석 주기 (초)
    let analysisInterval: Float

    enum DetectedEmotion: String, Codable, Sendable {
        case neutral = "neutral"
        case happy = "happy"
        case sad = "sad"
        case angry = "angry"
        case fearful = "fearful"
        case disgusted = "disgusted"
        case surprised = "surprised"
    }
}

// MARK: - Danger Dismissed Data

/// 위험 상황 해제 데이터
struct DangerDismissedData: Codable, Sendable {
    /// 원래 알림 타입 (device_fall, person_fall, loud_voice 등)
    let originalAlertType: String

    /// 해제 주체 (user, timeout 등)
    let dismissedBy: String

    /// 알림부터 해제까지 걸린 시간 (ms)
    let responseTimeMs: Int64?
}

// MARK: - Request Fall Confirmation Data (Agent → iOS)

/// Agent가 낙상 확인 Alert 표시 요청 데이터
struct RequestFallConfirmationData: Codable, Sendable {
    /// 원래 낙상 알림 타입 (device_fall, person_fall)
    let originalAlertType: String

    /// Agent가 질문한 횟수
    let askCount: Int

    /// 질문부터 타임아웃까지 걸린 시간 (초)
    let timeoutSeconds: Float?

    /// 추가 메시지 (선택사항)
    let message: String?
}

// MARK: - Emergency Confirmed Data (Agent → iOS)

/// Agent가 긴급 상황 확정 데이터 (보호자 알림 필요)
struct EmergencyConfirmedData: Codable, Sendable {
    /// 긴급 상황 유형
    let emergencyType: EmergencyType

    /// 원래 감지 타입 (device_fall, person_fall, loud_voice)
    let originalAlertType: String

    /// 긴급 상황 확정 사유
    let reason: ConfirmationReason

    /// 보호자에게 전달할 메시지
    let messageForGuardian: String?

    enum EmergencyType: String, Codable, Sendable {
        /// 낙상 응급
        case fall = "fall"
        /// 호출 응급 (도움 요청)
        case callForHelp = "call_for_help"
        /// 기타 응급
        case other = "other"
    }

    enum ConfirmationReason: String, Codable, Sendable {
        /// 사용자가 "도움이 필요해요" 선택
        case userRequested = "user_requested"
        /// 응답 없음 타임아웃
        case noResponse = "no_response"
        /// Agent 판단
        case agentDecision = "agent_decision"
    }
}

// MARK: - Alert Response (Agent → iOS)

/// Agent가 iOS에 보내는 알림 응답 (alert_response 토픽)
struct AlertResponse: Codable, Sendable {
    // MARK: - 필수 필드

    /// 알림 ID (acknowledge_alert 응답 시 필수)
    let alertId: String

    /// 알림 타입 (device_fall, person_fall, loud_voice, emotion)
    let alertType: String

    // MARK: - 선택 필드

    /// Ward ID
    let wardId: String?

    /// 심각도 (low, medium, high, critical)
    let severity: String?

    /// 위험 수준 (caution: 노란색, critical: 빨간색)
    let riskLevel: AlertRiskLevel?

    /// 위험도 점수 (0.0 ~ 1.0)
    let riskScore: Float?

    /// Agent의 음성 응답 메시지
    let agentResponse: String?

    /// 타임스탬프 (Unix milliseconds)
    let timestamp: Int64?

    /// 감지 상세 정보
    let detectionInfo: AlertDetectionInfo?

    /// DataChannel topic
    static let topic = "alert_response"

    /// 위험 수준 (UI 색상 결정용)
    enum AlertRiskLevel: String, Codable, Sendable {
        case caution = "caution"    // 노란색 (주의)
        case critical = "critical"  // 빨간색 (경고)
    }
}

/// Alert 감지 상세 정보
struct AlertDetectionInfo: Codable, Sendable {
    /// 감지 타입
    let type: String

    /// 심각도
    let severity: String

    /// 판단 기준 목록
    let criteria: [AlertCriterion]?
}

/// Alert 판단 기준
struct AlertCriterion: Codable, Sendable {
    /// 기준 이름
    let name: String

    /// 기준 값
    let value: String

    /// 수준 (low, medium, high, critical)
    let level: String
}

// MARK: - DataChannel Constants

extension CareAlertPayload {
    /// DataChannel topic
    static let topic = "care_alert"

    /// 최대 페이로드 크기 (15KB)
    static let maxPayloadSize = 15 * 1024

    /// JSON 인코딩
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    /// JSON 디코딩
    static func from(jsonData: Data) throws -> CareAlertPayload {
        let decoder = JSONDecoder()
        return try decoder.decode(CareAlertPayload.self, from: jsonData)
    }
}

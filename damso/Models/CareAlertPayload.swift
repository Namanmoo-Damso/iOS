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

//
//  SensorStreamPayload.swift
//  damso
//
//  Created by Claude Code on 2026-01-20.
//
//  센서 스트림 페이로드 - Agent로 매초 전송되는 원시 데이터
//  iOS는 판단 없이 raw data만 전송, 임계값 판단은 Agent에서 수행
//

import Foundation

// MARK: - Sensor Stream Payload

/// 센서 스트림 통합 페이로드
/// 매초 Agent로 전송되는 4가지 센서 원시 데이터
struct SensorStreamPayload: Codable, Sendable {
    /// 타임스탬프 (Unix milliseconds)
    let timestamp: Int64

    /// 감정 분석 데이터
    let emotion: EmotionStreamData?

    /// 음성 레벨 데이터
    let audio: AudioStreamData?

    /// 기기 모션 데이터 (기기 낙상 감지용)
    let motion: MotionStreamData?

    /// 얼굴 추적 데이터 (사람 낙상 감지용)
    let face: FaceStreamData?

    init(
        emotion: EmotionStreamData? = nil,
        audio: AudioStreamData? = nil,
        motion: MotionStreamData? = nil,
        face: FaceStreamData? = nil
    ) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.emotion = emotion
        self.audio = audio
        self.motion = motion
        self.face = face
    }
}

// MARK: - Emotion Stream Data

/// 감정 분석 스트림 데이터 (raw data only)
struct EmotionStreamData: Codable, Sendable {
    /// 감지된 감정 (neutral, happy, sad, angry, fearful, disgusted, surprised)
    let emotion: String

    /// 신뢰도 (0.0 ~ 1.0)
    let confidence: Float

    /// 감정 강도 (0.0 ~ 1.0)
    let intensity: Float?

    init(emotion: String, confidence: Float, intensity: Float? = nil) {
        self.emotion = emotion
        self.confidence = confidence
        self.intensity = intensity
    }
}

// MARK: - Audio Stream Data

/// 음성 레벨 스트림 데이터 (raw data only)
struct AudioStreamData: Codable, Sendable {
    /// 정규화된 음량 레벨 (0.0 ~ 1.0)
    let level: Float

    /// 데시벨 (dB)
    let decibel: Float

    init(level: Float, decibel: Float) {
        self.level = level
        self.decibel = decibel
    }
}

// MARK: - Motion Stream Data

/// 기기 모션 스트림 데이터 (raw data only)
/// 가속도계/자이로 기반, 임계값 판단은 Agent에서 수행
struct MotionStreamData: Codable, Sendable {
    /// 낙상 위험도 점수 (0.0 ~ 1.0)
    let fallRisk: Float

    /// 사용자 가속도 크기 (g 단위)
    let accelerationMagnitude: Float

    /// 회전 속도 크기 (rad/s)
    let rotationMagnitude: Float

    /// 자유낙하 감지 여부
    let isFreefalling: Bool

    init(
        fallRisk: Float,
        accelerationMagnitude: Float,
        rotationMagnitude: Float,
        isFreefalling: Bool
    ) {
        self.fallRisk = fallRisk
        self.accelerationMagnitude = accelerationMagnitude
        self.rotationMagnitude = rotationMagnitude
        self.isFreefalling = isFreefalling
    }
}

// MARK: - Face Stream Data

/// 얼굴 추적 스트림 데이터 (raw data only)
/// 카메라 기반 사람 낙상 감지용, 임계값 판단은 Agent에서 수행
struct FaceStreamData: Codable, Sendable {
    /// 얼굴 감지 여부
    let isDetected: Bool

    /// 얼굴 Y 좌표 (정규화, 0.0=상단 ~ 1.0=하단)
    let faceY: Float?

    /// Y 좌표 변화량 (최근 0.5초간, 정규화)
    /// 양수 = 하강, 음수 = 상승
    let yDelta: Float?

    /// 변화 소요 시간 (초)
    let deltaTime: Float?

    /// 얼굴 실종 시간 (초, 감지 안 될 때만)
    let disappearedDuration: Float?

    init(
        isDetected: Bool,
        faceY: Float? = nil,
        yDelta: Float? = nil,
        deltaTime: Float? = nil,
        disappearedDuration: Float? = nil
    ) {
        self.isDetected = isDetected
        self.faceY = faceY
        self.yDelta = yDelta
        self.deltaTime = deltaTime
        self.disappearedDuration = disappearedDuration
    }
}

// MARK: - DataChannel Constants

extension SensorStreamPayload {
    /// DataChannel topic
    static let topic = "sensor_stream"

    /// 전송 주기 (초)
    static let sendInterval: TimeInterval = 1.0

    /// 최대 페이로드 크기 (2KB)
    static let maxPayloadSize = 2 * 1024

    /// JSON 인코딩
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    /// JSON 디코딩
    static func from(jsonData: Data) throws -> SensorStreamPayload {
        let decoder = JSONDecoder()
        return try decoder.decode(SensorStreamPayload.self, from: jsonData)
    }
}

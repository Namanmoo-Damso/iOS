//
//  MotionSensorData.swift
//  damso
//
//  Created by Claude Code on 2025-01-09.
//

import Foundation
import CoreMotion

/// Core Motion 센서 데이터 모델
/// LiveKit Data Channel을 통해 전송됨
struct MotionSensorData: Codable, Sendable {
    /// 데이터 타임스탬프 (Unix time milliseconds)
    let timestamp: Int64

    /// 가속도계 데이터 (g 단위)
    let acceleration: Vector3D?

    /// 자이로스코프 데이터 (rad/s)
    let rotationRate: Vector3D?

    /// 중력 벡터 (g 단위)
    let gravity: Vector3D?

    /// 사용자 가속도 (중력 제외, g 단위)
    let userAcceleration: Vector3D?

    /// 기기 자세 (쿼터니언)
    let attitude: AttitudeData?

    /// 기압계 데이터 (hPa)
    let pressure: Float?

    /// 상대 고도 변화 (m)
    let relativeAltitude: Float?

    /// 낙상 감지 플래그
    let fallDetected: Bool

    /// 낙상 위험도 (0.0~1.0)
    let fallRisk: Float

    init(
        acceleration: Vector3D? = nil,
        rotationRate: Vector3D? = nil,
        gravity: Vector3D? = nil,
        userAcceleration: Vector3D? = nil,
        attitude: AttitudeData? = nil,
        pressure: Float? = nil,
        relativeAltitude: Float? = nil,
        fallDetected: Bool = false,
        fallRisk: Float = 0.0
    ) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.acceleration = acceleration
        self.rotationRate = rotationRate
        self.gravity = gravity
        self.userAcceleration = userAcceleration
        self.attitude = attitude
        self.pressure = pressure
        self.relativeAltitude = relativeAltitude
        self.fallDetected = fallDetected
        self.fallRisk = fallRisk
    }
}

// MARK: - Vector3D

/// 3D 벡터 데이터
struct Vector3D: Codable, Sendable {
    let x: Float
    let y: Float
    let z: Float

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(cmAcceleration: CMAcceleration) {
        self.x = Float(cmAcceleration.x)
        self.y = Float(cmAcceleration.y)
        self.z = Float(cmAcceleration.z)
    }

    init(cmRotationRate: CMRotationRate) {
        self.x = Float(cmRotationRate.x)
        self.y = Float(cmRotationRate.y)
        self.z = Float(cmRotationRate.z)
    }

    /// 벡터 크기 (magnitude)
    var magnitude: Float {
        sqrt(x * x + y * y + z * z)
    }
}

// MARK: - AttitudeData

/// 기기 자세 데이터 (쿼터니언)
struct AttitudeData: Codable, Sendable {
    let roll: Float   // X축 회전
    let pitch: Float  // Y축 회전
    let yaw: Float    // Z축 회전

    // 쿼터니언 (선택적)
    let quaternionX: Float?
    let quaternionY: Float?
    let quaternionZ: Float?
    let quaternionW: Float?

    init(attitude: CMAttitude) {
        self.roll = Float(attitude.roll)
        self.pitch = Float(attitude.pitch)
        self.yaw = Float(attitude.yaw)

        let q = attitude.quaternion
        self.quaternionX = Float(q.x)
        self.quaternionY = Float(q.y)
        self.quaternionZ = Float(q.z)
        self.quaternionW = Float(q.w)
    }
}

// MARK: - Data Channel Constants

extension MotionSensorData {
    /// Data channel topic 이름
    static let topic = "motion_sensor"

    /// 최대 페이로드 크기 (LiveKit 제한: 15KB)
    static let maxPayloadSize = 15 * 1024

    /// JSON 인코딩
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    /// JSON 디코딩
    static func from(jsonData: Data) throws -> MotionSensorData {
        let decoder = JSONDecoder()
        return try decoder.decode(MotionSensorData.self, from: jsonData)
    }
}

// MARK: - Fall Detection Constants

extension MotionSensorData {
    /// 자유 낙하 감지 임계값 (g 단위, 0에 가까움)
    static let freefallThreshold: Float = 0.3

    /// 충격 감지 임계값 (g 단위) - 낮춤 (기존 4.5 → 2.5)
    static let impactThreshold: Float = 2.5

    /// 회전 속도 임계값 (rad/s) - 낮춤 (기존 5.0 → 3.0)
    static let rotationThreshold: Float = 3.0
}

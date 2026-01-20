//
//  MotionSensorProtocol.swift
//  damso
//
//  Created by Claude Code on 2025-01-09.
//

import Foundation
import Combine

/// Core Motion 센서 데이터 수집 프로토콜
@MainActor
protocol MotionSensorProtocol: AnyObject {
    /// 현재 센서 수집 상태
    var isCollecting: Bool { get }

    /// 마지막 센서 데이터
    var lastSensorData: MotionSensorData? { get }

    /// 센서 데이터 스트림
    var sensorDataStream: AnyPublisher<MotionSensorData, Never> { get }

    /// 낙상 감지 이벤트 스트림
    var fallDetectedStream: AnyPublisher<FallEvent, Never> { get }

    /// 센서 사용 가능 여부
    var isAccelerometerAvailable: Bool { get }
    var isGyroAvailable: Bool { get }
    var isDeviceMotionAvailable: Bool { get }
    var isAltimeterAvailable: Bool { get }

    /// 센서 데이터 수집 시작
    /// - Parameters:
    ///   - sendToDataChannel: LiveKit Data Channel로 전송 여부
    func startCollection(sendToDataChannel: Bool)

    /// 센서 데이터 수집 중지
    func stopCollection()

    /// 수집 빈도 설정 (Hz)
    func setUpdateRate(_ hz: Double)

    /// 낙상 감지 활성화/비활성화
    func setFallDetectionEnabled(_ enabled: Bool)
}

/// 낙상 위험 수준
enum FallRiskLevel: String, Codable, Sendable {
    /// 정상 (위험도 0.5 미만)
    case normal = "normal"
    /// 주의 (위험도 0.5 이상 0.7 미만)
    case caution = "caution"
    /// 위급 (위험도 0.7 이상)
    case critical = "critical"

    /// 위험도 값에서 레벨 계산
    static func from(risk: Float) -> FallRiskLevel {
        if risk >= 0.7 {
            return .critical
        } else if risk >= 0.5 {
            return .caution
        } else {
            return .normal
        }
    }
}

/// 낙상 감지 이벤트
struct FallEvent: Codable, Sendable {
    /// 이벤트 타임스탬프
    let timestamp: Int64

    /// 낙상 유형
    let type: FallType

    /// 충격 강도 (g 단위)
    let impactMagnitude: Float

    /// 이벤트 발생 전 센서 데이터 스냅샷
    let sensorSnapshot: MotionSensorData?

    /// 위험 수준 (normal/caution/critical)
    let riskLevel: FallRiskLevel

    /// 위험도 점수 (0.0 ~ 1.0)
    let riskScore: Float

    enum FallType: String, Codable, Sendable {
        case freefall      // 자유 낙하 감지
        case impact        // 충격 감지
        case combination   // 낙하 + 충격 조합
        case rapidPostureChange  // 급격한 자세 변화
    }

    init(type: FallType, impactMagnitude: Float, sensorSnapshot: MotionSensorData? = nil, riskScore: Float = 1.0) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.type = type
        self.impactMagnitude = impactMagnitude
        self.sensorSnapshot = sensorSnapshot
        self.riskScore = riskScore
        self.riskLevel = FallRiskLevel.from(risk: riskScore)
    }
}

/// Motion 센서 에러
enum MotionSensorError: LocalizedError {
    case accelerometerNotAvailable
    case gyroNotAvailable
    case deviceMotionNotAvailable
    case altimeterNotAvailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .accelerometerNotAvailable:
            return "가속도계를 사용할 수 없습니다"
        case .gyroNotAvailable:
            return "자이로스코프를 사용할 수 없습니다"
        case .deviceMotionNotAvailable:
            return "Device Motion을 사용할 수 없습니다"
        case .altimeterNotAvailable:
            return "기압계를 사용할 수 없습니다"
        case .permissionDenied:
            return "Motion 센서 접근 권한이 거부되었습니다"
        }
    }
}

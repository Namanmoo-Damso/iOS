//
//  MotionSensorService.swift
//  damso
//
//  Created by Claude Code on 2025-01-09.
//

import Foundation
import CoreMotion
import Combine
#if canImport(LiveKit)
import LiveKit
#endif

/// Core Motion 센서 데이터 수집 서비스
/// 가속도계, 자이로스코프, 기압계 데이터 수집 및 낙상 감지
@MainActor
final class MotionSensorService: ObservableObject, MotionSensorProtocol {

    // MARK: - Singleton

    static let shared = MotionSensorService()

    // MARK: - Published Properties

    @Published private(set) var isCollecting: Bool = false
    @Published private(set) var lastSensorData: MotionSensorData?
    @Published private(set) var currentUpdateRate: Double = 0

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    // Main queue 사용 - @MainActor와 동일한 스레드에서 콜백 실행
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue.main
        return queue
    }()

    private let sensorDataSubject = PassthroughSubject<MotionSensorData, Never>()
    private let fallDetectedSubject = PassthroughSubject<FallEvent, Never>()

    // 설정
    private var updateRate: Double = 50.0  // Hz
    private var fallDetectionEnabled: Bool = true
    private var sendToDataChannel: Bool = false

    // 낙상 감지 상태
    private var recentAccelerations: [Vector3D] = []
    private var freefallStartTime: Date?

    // 기압계 데이터
    private var currentPressure: Float?
    private var currentRelativeAltitude: Float?

    // Data Channel
    private var dataChannelCancellable: AnyCancellable?

    // MARK: - Public Properties

    var sensorDataStream: AnyPublisher<MotionSensorData, Never> {
        sensorDataSubject.eraseToAnyPublisher()
    }

    var fallDetectedStream: AnyPublisher<FallEvent, Never> {
        fallDetectedSubject.eraseToAnyPublisher()
    }

    var isAccelerometerAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    var isGyroAvailable: Bool {
        motionManager.isGyroAvailable
    }

    var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    var isAltimeterAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    // MARK: - Init

    private init() {
        // operationQueue는 OperationQueue.main으로 설정됨
    }

    // MARK: - Public Methods

    func startCollection(sendToDataChannel: Bool) {
        guard !isCollecting else { return }

        self.sendToDataChannel = sendToDataChannel

        // Device Motion 시작 (가속도 + 자이로 + 자세 통합)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / updateRate

            motionManager.startDeviceMotionUpdates(
                using: .xArbitraryZVertical,
                to: operationQueue  // OperationQueue.main 사용
            ) { [weak self] motion, error in
                // Main queue에서 실행됨 - @MainActor와 동일 스레드
                guard let self, let motion else {
                    if let error {
                        print("[MotionSensor] Device motion error: \(error)")
                    }
                    return
                }

                // CMDeviceMotion에서 값 추출
                let userAccel = Vector3D(cmAcceleration: motion.userAcceleration)
                let gravity = Vector3D(cmAcceleration: motion.gravity)
                let rotationRate = Vector3D(cmRotationRate: motion.rotationRate)
                let attitude = AttitudeData(attitude: motion.attitude)

                // Main queue에서 실행 중이므로 직접 호출 가능
                self.processDeviceMotionData(
                    userAccel: userAccel,
                    gravity: gravity,
                    rotationRate: rotationRate,
                    attitude: attitude
                )
            }

            debugLog("Device Motion started at \(updateRate) Hz")
        }

        // 기압계 시작
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: operationQueue) { [weak self] data, error in
                // Main queue에서 실행됨 - @MainActor와 동일 스레드
                guard let self, let data else {
                    if let error {
                        print("[MotionSensor] Altimeter error: \(error)")
                    }
                    return
                }

                // CMAltitudeData에서 값 추출
                let pressure = Float(truncating: data.pressure)
                let relativeAltitude = Float(truncating: data.relativeAltitude)

                // Main queue에서 실행 중이므로 직접 호출 가능
                self.processAltimeterValues(pressure: pressure, relativeAltitude: relativeAltitude)
            }

            debugLog("Altimeter started")
        }

        isCollecting = true
        debugLog("Motion sensor collection started")
    }

    func stopCollection() {
        guard isCollecting else { return }

        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()

        isCollecting = false
        recentAccelerations.removeAll()
        freefallStartTime = nil

        debugLog("Motion sensor collection stopped")
    }

    func setUpdateRate(_ hz: Double) {
        updateRate = max(1.0, min(100.0, hz))

        // 실행 중이면 재시작
        if isCollecting {
            stopCollection()
            startCollection(sendToDataChannel: sendToDataChannel)
        }

        debugLog("Update rate set to \(updateRate) Hz")
    }

    func setFallDetectionEnabled(_ enabled: Bool) {
        fallDetectionEnabled = enabled
        debugLog("Fall detection \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Private Processing

    /// 이미 추출된 센서 데이터 처리 (MainActor에서 실행)
    private func processDeviceMotionData(
        userAccel: Vector3D,
        gravity: Vector3D,
        rotationRate: Vector3D,
        attitude: AttitudeData
    ) {
        // 낙상 감지
        var fallDetected = false
        var fallRisk: Float = 0.0

        if fallDetectionEnabled {
            let (detected, risk) = checkFallDetection(
                userAcceleration: userAccel,
                gravity: gravity,
                rotationRate: rotationRate
            )
            fallDetected = detected
            fallRisk = risk
        }

        let sensorData = MotionSensorData(
            acceleration: nil,  // userAcceleration 사용
            rotationRate: rotationRate,
            gravity: gravity,
            userAcceleration: userAccel,
            attitude: attitude,
            pressure: currentPressure,
            relativeAltitude: currentRelativeAltitude,
            fallDetected: fallDetected,
            fallRisk: fallRisk
        )

        lastSensorData = sensorData
        sensorDataSubject.send(sensorData)

        // 낙상 이벤트 발생
        if fallDetected {
            let event = FallEvent(
                type: .combination,
                impactMagnitude: userAccel.magnitude,
                sensorSnapshot: sensorData
            )
            fallDetectedSubject.send(event)
            debugLog("⚠️ Fall detected! Impact: \(userAccel.magnitude)g")
        }

        // Data Channel로 전송 (rate limiting 적용)
        if sendToDataChannel {
            sendToDataChannelIfNeeded(sensorData)
        }
    }

    /// 이미 추출된 기압계 데이터 처리 (MainActor에서 실행)
    private func processAltimeterValues(pressure: Float, relativeAltitude: Float) {
        currentPressure = pressure
        currentRelativeAltitude = relativeAltitude
    }

    // MARK: - Fall Detection Algorithm

    /// 낙상 감지 알고리즘
    /// 1. 자유 낙하 감지: userAcceleration 크기가 임계값 이하
    /// 2. 충격 감지: userAcceleration 크기가 임계값 이상
    /// 3. 조합 감지: 자유 낙하 후 충격
    private func checkFallDetection(
        userAcceleration: Vector3D,
        gravity: Vector3D,
        rotationRate: Vector3D
    ) -> (detected: Bool, risk: Float) {
        let accelMagnitude = userAcceleration.magnitude
        let rotationMagnitude = rotationRate.magnitude

        // 최근 가속도 기록 (10개 유지)
        recentAccelerations.append(userAcceleration)
        if recentAccelerations.count > 10 {
            recentAccelerations.removeFirst()
        }

        var fallRisk: Float = 0.0

        // 1. 자유 낙하 감지 (가속도가 거의 0)
        if accelMagnitude < MotionSensorData.freefallThreshold {
            if freefallStartTime == nil {
                freefallStartTime = Date()
            }
            fallRisk += 0.3
        } else {
            // 자유 낙하 후 충격 확인
            if let startTime = freefallStartTime {
                let freefallDuration = Date().timeIntervalSince(startTime)

                // 자유 낙하가 0.1초 이상 지속되었고 충격이 발생
                if freefallDuration > 0.1 && accelMagnitude > MotionSensorData.impactThreshold {
                    freefallStartTime = nil
                    return (true, 1.0)  // 확실한 낙상
                }

                // 1초 이상 자유 낙하 없으면 리셋
                if freefallDuration > 1.0 {
                    freefallStartTime = nil
                }
            }
        }

        // 2. 단독 충격 감지
        if accelMagnitude > MotionSensorData.impactThreshold {
            fallRisk += 0.4
        }

        // 3. 급격한 회전 감지
        if rotationMagnitude > MotionSensorData.rotationThreshold {
            fallRisk += 0.2
        }

        // 4. 최근 가속도 패턴 분석
        if recentAccelerations.count >= 5 {
            let avgMagnitude = recentAccelerations.map { $0.magnitude }.reduce(0, +) / Float(recentAccelerations.count)
            let variance = recentAccelerations.map { pow($0.magnitude - avgMagnitude, 2) }.reduce(0, +) / Float(recentAccelerations.count)

            // 높은 분산 = 불안정한 움직임
            if variance > 1.0 {
                fallRisk += 0.1
            }
        }

        fallRisk = min(1.0, fallRisk)

        // 위험도가 0.8 이상이면 낙상으로 판단
        return (fallRisk >= 0.8, fallRisk)
    }

    // MARK: - Data Channel

    private var lastDataChannelSendTime: Date = .distantPast
    private let dataChannelSendInterval: TimeInterval = 0.1  // 10Hz로 제한

    private func sendToDataChannelIfNeeded(_ data: MotionSensorData) {
        let now = Date()
        guard now.timeIntervalSince(lastDataChannelSendTime) >= dataChannelSendInterval else { return }
        lastDataChannelSendTime = now

        Task {
            do {
                let jsonData = try data.toJSONData()
                try await MotionSensorDataChannel.shared.send(jsonData)
            } catch {
                debugLog("Failed to send motion data: \(error)")
            }
        }
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[MotionSensor] \(message)")
        #endif
    }
}

// MARK: - Motion Sensor Data Channel

/// Motion 센서 데이터 전송용 Data Channel
@MainActor
final class MotionSensorDataChannel: ObservableObject {

    static let shared = MotionSensorDataChannel()

    #if canImport(LiveKit)
    private weak var room: Room?
    #endif

    private init() {}

    #if canImport(LiveKit)
    func setRoom(_ room: Room?) {
        self.room = room
    }
    #else
    func setRoom(_ room: Any?) {
        // LiveKit 미사용 시 무시
    }
    #endif

    func send(_ data: Data) async throws {
        // LiveKit이 연결되어 있을 때만 전송
        // FaceDetectionDataChannel과 유사한 방식으로 구현
        #if canImport(LiveKit)
        guard let room = room,
              room.connectionState == .connected else {
            return
        }

        let options = DataPublishOptions(
            topic: MotionSensorData.topic,
            reliable: false  // 실시간 데이터는 lossy 사용
        )

        try await room.localParticipant.publish(data: data, options: options)
        #endif
    }
}

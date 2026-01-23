//
//  SensorDataAggregator.swift
//  damso
//
//  Created by Claude Code on 2025-01-09.
//

import Foundation
import Combine
import AVFoundation
import CoreGraphics

/// 모든 센서 데이터를 통합하여 LiveKit Data Channel로 전송하는 서비스
/// Face Detection(FaceLandmarkDetector) + Motion Sensor 데이터를 하나의 페이로드로 묶어 전송
@MainActor
final class SensorDataAggregator: ObservableObject {

    // MARK: - Singleton

    static let shared = SensorDataAggregator()

    // MARK: - Published Properties

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastAggregatedData: AggregatedSensorData?
    @Published private(set) var currentStatus: AggregatorStatus = .idle

    // MARK: - Private Properties

    private let faceLandmarkDetector = FaceLandmarkDetector.shared
    private let motionSensorService = MotionSensorService.shared

    private var cancellables = Set<AnyCancellable>()
    private var aggregationTimer: Timer?

    // 설정
    private var aggregationRate: Double = 10.0  // Hz (초당 전송 횟수)
    private var sendToDataChannel: Bool = false  // 현재 비활성화 - 수집만 함

    // 버퍼
    private var latestFaceData: FaceDetectionData?
    private var latestMotionData: MotionSensorData?

    // MARK: - Init

    private init() {
        setupSubscriptions()
    }

    // MARK: - Public Methods

    /// 모든 센서 데이터 수집 시작
    /// - Parameters:
    ///   - enableMotionSensor: 모션 센서 활성화
    /// - Note: 얼굴 감지는 LiveKit VideoTrack에서 자동 처리됨 (FaceLandmarkDetector)
    func start(enableMotionSensor: Bool = true) {
        guard !isRunning else { return }

        currentStatus = .starting

        // Motion Sensor 시작
        if enableMotionSensor {
            motionSensorService.startCollection(sendToDataChannel: false)
        }

        // 통합 전송 타이머 시작
        startAggregationTimer()

        isRunning = true
        currentStatus = .running
        debugLog("Sensor aggregator started (motion sensor only)")
    }

    /// 모든 센서 데이터 수집 중지
    func stop() {
        guard isRunning else { return }

        currentStatus = .stopping

        motionSensorService.stopCollection()
        stopAggregationTimer()

        latestFaceData = nil
        latestMotionData = nil
        lastAggregatedData = nil  // 이전 통화 데이터 초기화

        isRunning = false
        currentStatus = .idle
        debugLog("Sensor aggregator stopped")
    }

    /// 통합 전송 빈도 설정 (Hz)
    func setAggregationRate(_ hz: Double) {
        aggregationRate = max(1.0, min(30.0, hz))

        if isRunning {
            stopAggregationTimer()
            startAggregationTimer()
        }

        debugLog("Aggregation rate set to \(aggregationRate) Hz")
    }

    /// 모션 센서 설정
    func configureMotionSensor(updateRate: Double, fallDetectionEnabled: Bool) {
        motionSensorService.setUpdateRate(updateRate)
        motionSensorService.setFallDetectionEnabled(fallDetectionEnabled)
    }

    /// FaceLandmarkDetector 검출율 설정
    func setFaceDetectionRate(_ fps: Int) {
        faceLandmarkDetector.setDetectionRate(fps)
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // FaceLandmarkDetector 결과 구독 - CGPoint 배열을 FaceDetectionData로 변환
        faceLandmarkDetector.landmarksStream
            .sink { [weak self] landmarks in
                self?.latestFaceData = self?.convertLandmarksToFaceData(landmarks)
            }
            .store(in: &cancellables)

        // Motion Sensor 데이터 구독
        motionSensorService.sensorDataStream
            .sink { [weak self] data in
                self?.latestMotionData = data
            }
            .store(in: &cancellables)

        // 낙상 감지 이벤트 구독 (즉시 전송)
        motionSensorService.fallDetectedStream
            .sink { [weak self] event in
                self?.handleFallEvent(event)
            }
            .store(in: &cancellables)
    }

    /// CGPoint 랜드마크 배열을 FaceDetectionData로 변환
    private func convertLandmarksToFaceData(_ landmarks: [CGPoint]) -> FaceDetectionData? {
        guard !landmarks.isEmpty else { return nil }

        // 랜드마크에서 바운딩 박스 계산
        let xs = landmarks.map { Float($0.x) }
        let ys = landmarks.map { Float($0.y) }

        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return nil
        }

        let boundingBox = NormalizedRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        // 주요 랜드마크 추출 (대략적인 인덱스 기반)
        var faceLandmarks: [FaceLandmark] = []

        // Vision Framework 68-point 순서 기준 (대략적)
        // 얼굴 외곽선, 눈썹, 코, 눈, 입 순서
        if landmarks.count >= 68 {
            // 왼쪽 눈 중심 (약 36-41번 인덱스)
            if landmarks.count > 40 {
                let leftEyeCenter = landmarks[39]
                faceLandmarks.append(FaceLandmark(type: .leftEye, x: Float(leftEyeCenter.x), y: Float(leftEyeCenter.y)))
            }
            // 오른쪽 눈 중심 (약 42-47번 인덱스)
            if landmarks.count > 46 {
                let rightEyeCenter = landmarks[45]
                faceLandmarks.append(FaceLandmark(type: .rightEye, x: Float(rightEyeCenter.x), y: Float(rightEyeCenter.y)))
            }
            // 코 끝 (약 30번 인덱스)
            if landmarks.count > 30 {
                let noseTip = landmarks[30]
                faceLandmarks.append(FaceLandmark(type: .nose, x: Float(noseTip.x), y: Float(noseTip.y)))
            }
            // 입 중심 (약 62번 인덱스)
            if landmarks.count > 62 {
                let mouthCenter = landmarks[62]
                faceLandmarks.append(FaceLandmark(type: .mouth, x: Float(mouthCenter.x), y: Float(mouthCenter.y)))
            }
        }

        let face = DetectedFace(
            faceId: "face_0",
            boundingBox: boundingBox,
            confidence: 1.0,
            landmarks: faceLandmarks.isEmpty ? nil : faceLandmarks,
            emotion: nil
        )

        return FaceDetectionData(
            faces: [face],
            frameSize: FrameSize(width: 640, height: 480)  // VideoRenderer adaptiveStreamSize 기준
        )
    }

    private func startAggregationTimer() {
        let interval = 1.0 / aggregationRate

        aggregationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.aggregateAndSend()
            }
        }
    }

    private func stopAggregationTimer() {
        aggregationTimer?.invalidate()
        aggregationTimer = nil
    }

    private func aggregateAndSend() {
        // 데이터가 하나도 없으면 스킵
        guard latestFaceData != nil || latestMotionData != nil else { return }

        let aggregatedData = AggregatedSensorData(
            faceDetection: latestFaceData,
            motionSensor: latestMotionData
        )

        lastAggregatedData = aggregatedData

        // Data Channel로 전송
        if sendToDataChannel {
            Task {
                do {
                    try await sendAggregatedData(aggregatedData)
                } catch {
                    debugLog("Failed to send aggregated data: \(error)")
                }
            }
        }
    }

    private func handleFallEvent(_ event: FallEvent) {
        debugLog("⚠️ Fall event detected: \(event.type)")

        // 낙상 이벤트는 즉시 전송
        Task {
            do {
                let alertData = AlertEventData(
                    type: .fall,
                    severity: .high,
                    fallEvent: event
                )
                try await sendAlertEvent(alertData)
            } catch {
                debugLog("Failed to send fall alert: \(error)")
            }
        }
    }

    // MARK: - Data Channel Transmission

    private func sendAggregatedData(_ data: AggregatedSensorData) async throws {
        #if canImport(LiveKit)
        let jsonData = try data.toJSONData()

        guard jsonData.count <= AggregatedSensorData.maxPayloadSize else {
            debugLog("Payload too large: \(jsonData.count) bytes")
            return
        }

        try await FaceDetectionDataChannel.shared.sendRaw(
            data: jsonData,
            topic: AggregatedSensorData.topic
        )
        #endif
    }

    private func sendAlertEvent(_ alert: AlertEventData) async throws {
        #if canImport(LiveKit)
        let jsonData = try alert.toJSONData()

        try await FaceDetectionDataChannel.shared.sendRaw(
            data: jsonData,
            topic: AlertEventData.topic
        )
        #endif
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SensorAggregator] \(message)")
        #endif
    }
}

// MARK: - Aggregator Status

enum AggregatorStatus: String {
    case idle
    case starting
    case running
    case stopping
    case error
}

// MARK: - Aggregated Sensor Data

/// 통합 센서 데이터 모델
struct AggregatedSensorData: Codable, Sendable {
    let timestamp: Int64
    let faceDetection: FaceDetectionData?
    let motionSensor: MotionSensorData?

    init(faceDetection: FaceDetectionData?, motionSensor: MotionSensorData?) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.faceDetection = faceDetection
        self.motionSensor = motionSensor
    }
}

extension AggregatedSensorData {
    static let topic = "sensor_data"
    static let maxPayloadSize = 15 * 1024

    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }
}

// MARK: - Alert Event Data

/// 긴급 알림 이벤트 데이터
struct AlertEventData: Codable, Sendable {
    let timestamp: Int64
    let type: AlertType
    let severity: AlertSeverity
    let fallEvent: FallEvent?
    let message: String?

    enum AlertType: String, Codable, Sendable {
        case fall           // 낙상 감지
        case faceDisappeared  // 얼굴 사라짐
        case abnormalMovement // 비정상 움직임
        case sosButton      // SOS 버튼 누름
    }

    enum AlertSeverity: String, Codable, Sendable {
        case low
        case medium
        case high
        case critical
    }

    init(type: AlertType, severity: AlertSeverity, fallEvent: FallEvent? = nil, message: String? = nil) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.type = type
        self.severity = severity
        self.fallEvent = fallEvent
        self.message = message
    }
}

extension AlertEventData {
    static let topic = "alert_event"

    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}

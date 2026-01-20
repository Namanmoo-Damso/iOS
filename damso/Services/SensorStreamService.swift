//
//  SensorStreamService.swift
//  damso
//
//  Created by Claude Code on 2026-01-20.
//
//  센서 스트림 서비스 - 매초 원시 데이터를 Agent로 전송
//  임계값 판단은 Agent에서 수행
//

import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit
#endif

/// 센서 스트림 서비스
/// 매초 모든 센서 데이터를 수집하여 Agent로 전송
@MainActor
final class SensorStreamService: ObservableObject {

    // MARK: - Singleton

    static let shared = SensorStreamService()

    // MARK: - Published Properties

    /// 서비스 활성화 상태
    @Published private(set) var isActive: Bool = false

    /// 마지막 전송된 페이로드
    @Published private(set) var lastSentPayload: SensorStreamPayload?

    /// 전송 횟수
    @Published private(set) var sendCount: Int = 0

    // MARK: - Private Properties

    #if canImport(LiveKit)
    private weak var room: Room?
    #endif

    private var streamTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // 센서 서비스 참조
    private let emotionAnalyzer = EmotionAnalyzer.shared
    private let audioMonitor = UserAudioLevelMonitor.shared
    private let motionSensorService = MotionSensorService.shared
    private let personFallDetector = PersonFallDetector.shared
    private let faceLandmarkDetector = FaceLandmarkDetector.shared

    // 모션 센서 최신 데이터 캐시
    private var latestFallRisk: Float = 0
    private var latestAccelMagnitude: Float = 0
    private var latestRotationMagnitude: Float = 0
    private var isFreefalling: Bool = false
    private var hasReceivedMotionData: Bool = false  // 실제 센서 데이터 수신 여부

    // 얼굴 추적 데이터 캐시
    private var faceYHistory: [(timestamp: Date, y: Float)] = []
    private var lastFaceDetectedTime: Date?
    private let maxFaceHistoryCount = 15

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 서비스 시작
    #if canImport(LiveKit)
    func start(room: Room) {
        guard !isActive else {
            debugLog("Already active, skipping start")
            return
        }

        self.room = room
        setupSubscriptions()
        startStreamTimer()
        isActive = true

        debugLog("✅ SensorStreamService started (interval: \(SensorStreamPayload.sendInterval)s)")
    }
    #endif

    /// 서비스 중지
    func stop() {
        guard isActive else { return }

        stopStreamTimer()
        cancellables.removeAll()
        #if canImport(LiveKit)
        room = nil
        #endif
        isActive = false
        sendCount = 0
        faceYHistory.removeAll()

        // 모션 데이터 캐시 초기화
        latestFallRisk = 0
        latestAccelMagnitude = 0
        latestRotationMagnitude = 0
        isFreefalling = false
        hasReceivedMotionData = false

        // 얼굴 추적 초기화
        lastFaceDetectedTime = nil

        debugLog("SensorStreamService stopped")
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // 모션 센서 데이터 구독
        motionSensorService.sensorDataStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                self?.updateMotionData(sensorData)
            }
            .store(in: &cancellables)

        // 낙상 이벤트 구독 (fallRisk 업데이트)
        motionSensorService.fallDetectedStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fallEvent in
                self?.latestFallRisk = fallEvent.riskScore
            }
            .store(in: &cancellables)

        // 얼굴 위치 구독
        faceLandmarkDetector.landmarksStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] landmarks in
                self?.updateFacePosition(landmarks)
            }
            .store(in: &cancellables)

        // 얼굴 감지 상태 구독
        faceLandmarkDetector.$isFaceDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDetected in
                if isDetected {
                    self?.lastFaceDetectedTime = Date()
                }
            }
            .store(in: &cancellables)
    }

    private func updateMotionData(_ sensorData: MotionSensorData) {
        latestAccelMagnitude = sensorData.userAcceleration?.magnitude ?? 0
        latestRotationMagnitude = sensorData.rotationRate?.magnitude ?? 0
        isFreefalling = latestAccelMagnitude < MotionSensorData.freefallThreshold
        hasReceivedMotionData = true  // 실제 센서 데이터 수신됨

        // fallRisk는 항상 갱신 (낙상 미감지 시 0으로 리셋)
        latestFallRisk = sensorData.fallRisk
    }

    private func updateFacePosition(_ landmarks: [CGPoint]) {
        guard !landmarks.isEmpty else { return }

        let now = Date()
        lastFaceDetectedTime = now

        // 얼굴 중심 Y좌표 계산
        let averageY = landmarks.reduce(0.0) { $0 + $1.y } / CGFloat(landmarks.count)
        let currentY = Float(averageY)

        // 히스토리에 추가
        faceYHistory.append((timestamp: now, y: currentY))

        // 오래된 기록 제거 (최근 1초만 유지)
        let cutoff = now.addingTimeInterval(-1.0)
        faceYHistory.removeAll { $0.timestamp < cutoff }
    }

    private func startStreamTimer() {
        stopStreamTimer()

        streamTimer = Timer.scheduledTimer(
            withTimeInterval: SensorStreamPayload.sendInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.collectAndSendData()
            }
        }
    }

    private func stopStreamTimer() {
        streamTimer?.invalidate()
        streamTimer = nil
    }

    /// 모든 센서 데이터 수집 및 전송
    private func collectAndSendData() async {
        #if canImport(LiveKit)
        guard let room, room.connectionState == .connected else {
            return
        }

        // 1. 감정 데이터 수집
        let emotionData = collectEmotionData()

        // 2. 음성 데이터 수집
        let audioData = collectAudioData()

        // 3. 모션 데이터 수집
        let motionData = collectMotionData()

        // 4. 얼굴 데이터 수집
        let faceData = collectFaceData()

        // 페이로드 생성
        let payload = SensorStreamPayload(
            emotion: emotionData,
            audio: audioData,
            motion: motionData,
            face: faceData
        )

        // 전송 데이터 로그
        #if DEBUG
        print("[SensorStreamService] 📤 Sending payload #\(sendCount + 1):")
        if let emotion = emotionData {
            print("  emotion: \(emotion.emotion), conf=\(String(format: "%.2f", emotion.confidence))")
        }
        if let audio = audioData {
            print("  audio: level=\(String(format: "%.2f", audio.level)), dB=\(String(format: "%.1f", audio.decibel))")
        }
        if let motion = motionData {
            print("  motion: fallRisk=\(String(format: "%.2f", motion.fallRisk)), accel=\(String(format: "%.2f", motion.accelerationMagnitude)), rot=\(String(format: "%.2f", motion.rotationMagnitude)), freefall=\(motion.isFreefalling)")
        }
        if let face = faceData {
            print("  face: detected=\(face.isDetected), y=\(face.faceY.map { String(format: "%.3f", $0) } ?? "nil"), yDelta=\(face.yDelta.map { String(format: "%.3f", $0) } ?? "nil"), deltaTime=\(face.deltaTime.map { String(format: "%.2f", $0) } ?? "nil"), disappeared=\(face.disappearedDuration.map { String(format: "%.1f", $0) } ?? "nil")")
        }
        #endif

        // 전송
        do {
            try await sendToDataChannel(payload)
            lastSentPayload = payload
            sendCount += 1
        } catch {
            debugLog("Failed to send sensor stream: \(error)")
        }
        #endif
    }

    // MARK: - Data Collection

    private func collectEmotionData() -> EmotionStreamData? {
        // 감정 분석이 활성화되어 있고 얼굴이 감지된 경우에만
        guard emotionAnalyzer.isActive,
              faceLandmarkDetector.isFaceDetected else {
            return nil
        }

        return EmotionStreamData(
            emotion: emotionAnalyzer.currentEmotion.rawValue,
            confidence: emotionAnalyzer.confidence,
            intensity: emotionAnalyzer.intensity
        )
    }

    private func collectAudioData() -> AudioStreamData? {
        let level = audioMonitor.currentLevel
        let decibel = audioMonitor.currentDecibel

        // 음성 데이터가 유효한 경우에만
        guard level > 0 || decibel > -160 else {
            return nil
        }

        return AudioStreamData(
            level: level,
            decibel: decibel
        )
    }

    private func collectMotionData() -> MotionStreamData? {
        // 모션 센서가 수집 중이고, 실제 데이터를 수신한 경우에만
        guard motionSensorService.isCollecting, hasReceivedMotionData else {
            return nil
        }

        return MotionStreamData(
            fallRisk: latestFallRisk,
            accelerationMagnitude: latestAccelMagnitude,
            rotationMagnitude: latestRotationMagnitude,
            isFreefalling: isFreefalling
        )
    }

    private func collectFaceData() -> FaceStreamData? {
        let isDetected = faceLandmarkDetector.isFaceDetected

        if isDetected {
            // 얼굴이 감지된 경우
            let currentY = personFallDetector.lastFaceY
            let (yDelta, deltaTime) = calculateYDelta()

            return FaceStreamData(
                isDetected: true,
                faceY: currentY,
                yDelta: yDelta,
                deltaTime: deltaTime,
                disappearedDuration: nil
            )
        } else {
            // 얼굴이 감지되지 않은 경우
            var disappearedDuration: Float? = nil
            if let lastDetected = lastFaceDetectedTime {
                disappearedDuration = Float(Date().timeIntervalSince(lastDetected))
            }

            return FaceStreamData(
                isDetected: false,
                faceY: nil,
                yDelta: nil,
                deltaTime: nil,
                disappearedDuration: disappearedDuration
            )
        }
    }

    /// Y 좌표 변화량 계산 (최근 0.5초)
    private func calculateYDelta() -> (yDelta: Float?, deltaTime: Float?) {
        guard faceYHistory.count >= 2 else {
            return (nil, nil)
        }

        let now = Date()
        let windowStart = now.addingTimeInterval(-0.5)

        // 0.5초 전 데이터 찾기
        guard let startEntry = faceYHistory.first(where: { $0.timestamp >= windowStart }),
              let endEntry = faceYHistory.last else {
            return (nil, nil)
        }

        let yDelta = endEntry.y - startEntry.y
        let deltaTime = Float(endEntry.timestamp.timeIntervalSince(startEntry.timestamp))

        return (yDelta, deltaTime)
    }

    // MARK: - DataChannel

    #if canImport(LiveKit)
    private func sendToDataChannel(_ payload: SensorStreamPayload) async throws {
        guard let room, room.connectionState == .connected else {
            return
        }

        // Agent 찾기
        guard let agentIdentity = room.remoteParticipants.values
            .first(where: {
                let id = $0.identity?.stringValue ?? ""
                return id.hasPrefix("agent-") || id.hasPrefix("voice-agent")
            })?.identity else {
            // Agent 없으면 조용히 스킵
            return
        }

        let jsonData = try payload.toJSONData()

        guard jsonData.count <= SensorStreamPayload.maxPayloadSize else {
            debugLog("Payload too large: \(jsonData.count) bytes")
            return
        }

        // lossy 전송 (실시간 스트림이므로 일부 손실 허용)
        let options = DataPublishOptions(
            destinationIdentities: [agentIdentity],
            topic: SensorStreamPayload.topic,
            reliable: false
        )

        try await room.localParticipant.publish(data: jsonData, options: options)
    }
    #endif

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SensorStreamService] \(message)")
        #endif
    }
}

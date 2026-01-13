//
//  CareAlertService.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//

import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit
#endif

/// 케어 알림 통합 서비스
/// 4가지 알림 타입을 통합 관리하고 DataChannel로 Agent에게 전송
@MainActor
final class CareAlertService: ObservableObject {

    // MARK: - Singleton

    static let shared = CareAlertService()

    // MARK: - Published Properties

    /// 서비스 활성화 상태
    @Published private(set) var isActive: Bool = false

    /// 마지막 전송된 알림
    @Published private(set) var lastSentAlert: CareAlertPayload?

    /// 전송 통계
    @Published private(set) var alertsSentCount: Int = 0

    // MARK: - Private Properties

    #if canImport(LiveKit)
    private weak var room: Room?
    #endif

    private var cancellables = Set<AnyCancellable>()

    // 기기 낙상 감지
    private let motionSensorService = MotionSensorService.shared

    // TODO: 추후 추가
    // private let userAudioMonitor = UserAudioLevelMonitor.shared
    // private let personFallDetector = PersonFallDetector.shared
    // private let emotionAnalyzer = EmotionAnalyzer.shared

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 서비스 시작
    /// - Parameter room: LiveKit Room (DataChannel 전송용)
    #if canImport(LiveKit)
    func start(room: Room) {
        guard !isActive else {
            debugLog("Service already active")
            return
        }

        self.room = room
        setupSubscriptions()
        isActive = true
        debugLog("✅ CareAlertService started")
    }
    #endif

    /// 서비스 중지
    func stop() {
        guard isActive else { return }

        cancellables.removeAll()
        #if canImport(LiveKit)
        room = nil
        #endif
        isActive = false
        debugLog("CareAlertService stopped")
    }

    // MARK: - Manual Alert Sending

    /// 수동으로 알림 전송 (테스트용 또는 외부에서 호출)
    func sendAlert(_ payload: CareAlertPayload) async throws {
        try await sendToDataChannel(payload)
    }

    /// 기기 낙상 알림 전송
    func sendDeviceFallAlert(
        impactMagnitude: Float,
        fallType: DeviceFallAlertData.DeviceFallType,
        freefallDuration: Float? = nil,
        maxRotationRate: Float? = nil
    ) async throws {
        let data = DeviceFallAlertData(
            impactMagnitude: impactMagnitude,
            fallType: fallType,
            freefallDuration: freefallDuration,
            maxRotationRate: maxRotationRate
        )

        let severity: CareAlertSeverity = impactMagnitude > 3.0 ? .critical : .high

        let payload = CareAlertPayload(
            alertType: .deviceFall,
            severity: severity,
            data: .deviceFall(data)
        )

        try await sendToDataChannel(payload)
    }

    /// 사람 낙상 알림 전송
    func sendPersonFallAlert(
        detectionType: PersonFallAlertData.PersonFallDetectionType,
        faceYDelta: Float? = nil,
        deltaTime: Float? = nil,
        lastFacePosition: PersonFallAlertData.NormalizedPosition? = nil
    ) async throws {
        let data = PersonFallAlertData(
            detectionType: detectionType,
            faceYDelta: faceYDelta,
            deltaTime: deltaTime,
            lastFacePosition: lastFacePosition
        )

        let payload = CareAlertPayload(
            alertType: .personFall,
            severity: .critical,
            data: .personFall(data)
        )

        try await sendToDataChannel(payload)
    }

    /// 음성 레벨 경고 전송
    func sendLoudVoiceAlert(
        level: Float,
        decibel: Float,
        duration: Float,
        possibleCause: LoudVoiceAlertData.PossibleCause? = nil
    ) async throws {
        let data = LoudVoiceAlertData(
            level: level,
            decibel: decibel,
            duration: duration,
            possibleCause: possibleCause
        )

        let severity: CareAlertSeverity = level > 0.9 ? .high : .medium

        let payload = CareAlertPayload(
            alertType: .loudVoice,
            severity: severity,
            data: .loudVoice(data)
        )

        try await sendToDataChannel(payload)
    }

    /// 감정 분석 결과 전송
    func sendEmotionAlert(
        emotion: EmotionAlertData.DetectedEmotion,
        confidence: Float,
        intensity: Float? = nil,
        previousEmotion: EmotionAlertData.DetectedEmotion? = nil,
        analysisInterval: Float
    ) async throws {
        let data = EmotionAlertData(
            emotion: emotion,
            confidence: confidence,
            intensity: intensity,
            previousEmotion: previousEmotion,
            analysisInterval: analysisInterval
        )

        // 부정적 감정일수록 높은 심각도
        let severity: CareAlertSeverity
        switch emotion {
        case .fearful, .sad:
            severity = .medium
        case .angry, .disgusted:
            severity = .low
        default:
            severity = .low
        }

        let payload = CareAlertPayload(
            alertType: .emotion,
            severity: severity,
            data: .emotion(data)
        )

        try await sendToDataChannel(payload)
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // 1. 기기 낙상 감지 구독
        motionSensorService.fallDetectedStream
            .sink { [weak self] fallEvent in
                Task { @MainActor in
                    await self?.handleDeviceFallEvent(fallEvent)
                }
            }
            .store(in: &cancellables)

        debugLog("Subscriptions setup complete")
    }

    /// 기기 낙상 이벤트 처리
    private func handleDeviceFallEvent(_ event: FallEvent) async {
        debugLog("⚠️ Device fall detected: \(event.type)")

        let fallType: DeviceFallAlertData.DeviceFallType
        switch event.type {
        case .freefall:
            fallType = .freefallImpact
        case .impact:
            fallType = .impact
        case .rapidPostureChange:
            fallType = .rotationImpact
        case .combination:
            fallType = .combination
        }

        do {
            try await sendDeviceFallAlert(
                impactMagnitude: event.impactMagnitude,
                fallType: fallType,
                freefallDuration: nil,
                maxRotationRate: nil
            )
        } catch {
            debugLog("Failed to send device fall alert: \(error)")
        }
    }

    /// DataChannel로 전송 (Agent에게만)
    private func sendToDataChannel(_ payload: CareAlertPayload) async throws {
        #if canImport(LiveKit)
        guard let room, room.connectionState == .connected else {
            debugLog("Room not connected, skipping send")
            return
        }

        // Room에 참여한 participant 중 Agent 찾기 ("agent-" 또는 "voice-agent" 로 시작)
        guard let agentIdentity = room.remoteParticipants.values
            .first(where: {
                let id = $0.identity?.stringValue ?? ""
                return id.hasPrefix("agent-") || id.hasPrefix("voice-agent")
            })?.identity else {
            debugLog("⚠️ No agent found in room (looking for 'agent-' or 'voice-agent'), skipping send")
            return
        }

        let jsonData = try payload.toJSONData()

        guard jsonData.count <= CareAlertPayload.maxPayloadSize else {
            debugLog("Payload too large: \(jsonData.count) bytes")
            throw CareAlertError.payloadTooLarge(jsonData.count)
        }

        // Agent에게만 reliable 전송
        let options = DataPublishOptions(
            destinationIdentities: [agentIdentity],
            topic: CareAlertPayload.topic,
            reliable: true
        )

        try await room.localParticipant.publish(data: jsonData, options: options)

        lastSentAlert = payload
        alertsSentCount += 1

        let targetDescription = String(describing: agentIdentity)
        debugLog("✅ Sent \(payload.alertType.rawValue) alert to \(targetDescription) (\(jsonData.count) bytes)")
        #endif
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CareAlertService] \(message)")
        #endif
    }
}

// MARK: - Errors

enum CareAlertError: LocalizedError {
    case roomNotConnected
    case payloadTooLarge(Int)
    case sendFailed(Error)

    var errorDescription: String? {
        switch self {
        case .roomNotConnected:
            return "Room이 연결되지 않았습니다"
        case .payloadTooLarge(let size):
            return "페이로드가 너무 큽니다: \(size) bytes (최대: 15KB)"
        case .sendFailed(let error):
            return "전송 실패: \(error.localizedDescription)"
        }
    }
}

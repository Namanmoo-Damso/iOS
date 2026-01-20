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

    /// 낙상 확인 Alert 표시 여부
    @Published var showFallConfirmationAlert: Bool = false

    /// 현재 알림 타입 (Alert 메시지 표시용)
    @Published private(set) var currentAlertType: CurrentAlertType = .deviceFall

    /// 현재 낙상 이벤트 (확인 대기 중)
    @Published private(set) var currentFallEvent: FallEvent?

    /// 현재 Alert ID (Agent에서 받은 값, acknowledge_alert 응답 시 사용)
    @Published private(set) var currentAlertId: String?

    /// Alert 메시지 (알림 타입별)
    var alertMessage: String {
        switch currentAlertType {
        case .deviceFall:
            return "충격이 감지되었습니다.\n상태를 알려주세요."
        case .personFallRapidDescent:
            return "낙상이 감지되었습니다.\n상태를 알려주세요."
        case .personFallFaceDisappeared:
            return "얼굴이 보이지 않습니다.\n상태를 알려주세요."
        case .loudVoice:
            return "큰 소리가 감지되었습니다.\n상태를 알려주세요."
        case .emotion:
            return "감정 변화가 감지되었습니다.\n상태를 알려주세요."
        case .speechKeyword:
            return "감정 변화가 감지되었습니다.\n상태를 알려주세요."
        }
    }

    /// 알림 타입 enum
    enum CurrentAlertType {
        case deviceFall
        case personFallRapidDescent
        case personFallFaceDisappeared
        case loudVoice
        case emotion
        case speechKeyword
    }

    /// 낙상 감지 시간 (responseTime 계산용)
    private var fallDetectedTime: Date?

    /// 마지막 person fall 세부 타입 (rapidDescent/faceDisappeared 구분용)
    private var lastPersonFallType: CurrentAlertType = .personFallRapidDescent

    /// 마지막 낙상 알림 전송 시간 (쿨다운 계산용)
    private var lastFallAlertTime: Date = .distantPast

    /// 낙상 알림 쿨다운 (초) - 이 시간 내 중복 알림 방지
    private let fallAlertCooldown: TimeInterval = 30.0

    /// Ward ID (서버 전송용)
    private var wardId: String = "unknown"

    // MARK: - Configuration

    /// 임계값 기반 알림 사용 여부
    /// false로 설정 시 iOS에서 자동 알림을 보내지 않고, SensorStreamService가 원시 데이터를 전송하여 Agent가 판단
    /// true로 설정 시 기존 방식대로 iOS에서 임계값 초과 시 자동 알림 전송
    var useThresholdBasedAlerts: Bool = false

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
    /// - Parameters:
    ///   - room: LiveKit Room (DataChannel 전송용)
    ///   - wardId: Ward UUID (서버 전송용)
    #if canImport(LiveKit)
    func start(room: Room, wardId: String? = nil) {
        guard !isActive else {
            debugLog("Service already active")
            return
        }

        self.room = room
        self.wardId = wardId ?? "unknown"
        setupSubscriptions()
        isActive = true
        debugLog("✅ CareAlertService started (wardId: \(self.wardId))")
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
            maxRotationRate: maxRotationRate,
            riskLevel: nil,
            riskScore: nil
        )

        let severity: CareAlertSeverity = impactMagnitude > 3.0 ? .critical : .high

        let payload = CareAlertPayload(
            alertType: .deviceFall,
            severity: severity,
            data: .deviceFall(data)
        )

        try await sendToDataChannel(payload)
    }

    /// 기기 낙상 알림 전송 (위험도 레벨 포함)
    /// - Parameters:
    ///   - impactMagnitude: 충격 크기 (g 단위)
    ///   - fallType: 낙상 유형
    ///   - riskLevel: 위험도 레벨 (normal/caution/critical)
    ///   - riskScore: 위험도 점수 (0.0 ~ 1.0)
    ///   - freefallDuration: 낙하 전 자유낙하 시간 (초)
    ///   - maxRotationRate: 최대 회전 속도 (rad/s)
    func sendDeviceFallAlertWithRiskLevel(
        impactMagnitude: Float,
        fallType: DeviceFallAlertData.DeviceFallType,
        riskLevel: FallRiskLevel,
        riskScore: Float,
        freefallDuration: Float? = nil,
        maxRotationRate: Float? = nil
    ) async throws {
        // FallRiskLevel → DeviceFallAlertData.DeviceFallRiskLevel 변환
        let dataRiskLevel: DeviceFallAlertData.DeviceFallRiskLevel
        switch riskLevel {
        case .normal:
            dataRiskLevel = .normal
        case .caution:
            dataRiskLevel = .caution
        case .critical:
            dataRiskLevel = .critical
        }

        let data = DeviceFallAlertData(
            impactMagnitude: impactMagnitude,
            fallType: fallType,
            freefallDuration: freefallDuration,
            maxRotationRate: maxRotationRate,
            riskLevel: dataRiskLevel,
            riskScore: riskScore
        )

        // 위험도 레벨에 따른 심각도 설정
        // critical → .critical (긴급)
        // caution → .medium (주의)
        // normal → .low (정상) - 실제로는 normal은 전송하지 않음
        let severity: CareAlertSeverity
        switch riskLevel {
        case .critical:
            severity = .critical
        case .caution:
            severity = .medium
        case .normal:
            severity = .low
        }

        let payload = CareAlertPayload(
            alertType: .deviceFall,
            severity: severity,
            data: .deviceFall(data)
        )

        try await sendToDataChannel(payload)
        debugLog("📤 Device fall alert sent: riskLevel=\(riskLevel), riskScore=\(String(format: "%.2f", riskScore)), severity=\(severity)")
    }

    /// 사람 낙상 알림 전송
    func sendPersonFallAlert(
        detectionType: PersonFallAlertData.PersonFallDetectionType,
        faceYDelta: Float? = nil,
        deltaTime: Float? = nil,
        lastFacePosition: PersonFallAlertData.NormalizedPosition? = nil
    ) async throws {
        // person fall 세부 타입 저장 (Agent 응답 시 메시지 표시용)
        switch detectionType {
        case .rapidDescent:
            lastPersonFallType = .personFallRapidDescent
        case .faceDisappeared:
            lastPersonFallType = .personFallFaceDisappeared
        case .sizeChange:
            lastPersonFallType = .personFallRapidDescent
        }

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
        // 임계값 기반 알림이 비활성화된 경우 자동 알림 구독 건너뛰기
        // SensorStreamService가 원시 데이터를 전송하고 Agent가 판단
        guard useThresholdBasedAlerts else {
            debugLog("⚙️ Threshold-based alerts disabled - skipping subscriptions (SensorStreamService will send raw data)")
            return
        }

        // 1. 기기 낙상 감지 구독 (임계값 기반)
        motionSensorService.fallDetectedStream
            .sink { [weak self] fallEvent in
                Task { @MainActor in
                    await self?.handleDeviceFallEvent(fallEvent)
                }
            }
            .store(in: &cancellables)

        debugLog("✅ Threshold-based subscriptions setup complete")
    }

    /// 기기 낙상 이벤트 처리
    /// Agent에게만 알림 전송 (iOS Alert은 Agent의 request_fall_confirmation 요청 시 표시)
    private func handleDeviceFallEvent(_ event: FallEvent) async {
        debugLog("⚠️ Device fall detected: \(event.type), riskLevel: \(event.riskLevel), riskScore: \(event.riskScore)")

        // 쿨다운 체크 - 이미 Alert이 표시 중이거나 최근에 알림을 보냈으면 무시
        let timeSinceLastAlert = Date().timeIntervalSince(lastFallAlertTime)
        if showFallConfirmationAlert || timeSinceLastAlert < fallAlertCooldown {
            debugLog("⏳ Fall alert skipped (cooldown: \(Int(fallAlertCooldown - timeSinceLastAlert))s remaining)")
            return
        }

        // 위급(critical) 단계만 Alert 표시 대기
        // 주의(caution) 단계는 Agent에게 알림만 전송하고 Alert은 표시하지 않음
        if event.riskLevel == .critical {
            Task { @MainActor in
                self.objectWillChange.send()
                self.currentFallEvent = event
                self.fallDetectedTime = Date()
                self.lastFallAlertTime = Date()
                debugLog("🚨 CRITICAL fall event stored, waiting for Agent's confirmation request")
            }
        } else {
            debugLog("⚠️ CAUTION level - sending to Agent without Alert")
        }

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
            try await sendDeviceFallAlertWithRiskLevel(
                impactMagnitude: event.impactMagnitude,
                fallType: fallType,
                riskLevel: event.riskLevel,
                riskScore: event.riskScore,
                freefallDuration: nil,
                maxRotationRate: nil
            )
            debugLog("✅ Fall alert sent to Agent (riskLevel: \(event.riskLevel)), waiting for alert_response...")
        } catch {
            debugLog("Failed to send device fall alert: \(error)")
        }
    }

    // MARK: - Alert Display

    /// Alert 표시 (중복 방지)
    private func showFallAlertIfNeeded() {
        guard !showFallConfirmationAlert else {
            debugLog("⚠️ Alert already showing, skipping")
            return
        }

        Task { @MainActor in
            self.objectWillChange.send()
            self.showFallConfirmationAlert = true
            debugLog("⚠️ Fall confirmation alert displayed")
        }
    }

    // MARK: - Danger Dismissal

    /// 사용자가 "괜찮아요" 버튼을 눌렀을 때 호출
    func dismissDangerAlert() {
        // Alert 숨기기
        showFallConfirmationAlert = false

        // Agent에게 acknowledge_alert 전송 (response: "ok")
        Task {
            do {
                try await sendAcknowledgeAlert(response: .ok)
                debugLog("✅ Danger dismissed by user (response: ok)")
            } catch {
                debugLog("Failed to send acknowledge alert: \(error)")
            }
        }

        // 상태 초기화
        currentFallEvent = nil
        fallDetectedTime = nil
        lastFallAlertTime = .distantPast  // 쿨다운 리셋 - 바로 다음 낙상 감지 가능
    }

    /// 사용자 응답 타입 (acknowledge_alert용)
    enum AcknowledgeResponse: String {
        case ok = "ok"              // "괜찮아요" 버튼
        case needHelp = "need_help" // "도움이 필요해요" 버튼
    }

    /// 사용자 응답 전송 (acknowledge_alert topic)
    /// - Parameter response: "ok" (괜찮아요) 또는 "need_help" (도움이 필요해요)
    func sendAcknowledgeAlert(response: AcknowledgeResponse) async throws {
        #if canImport(LiveKit)
        guard let room, room.connectionState == .connected else {
            debugLog("Room not connected, skipping acknowledge send")
            return
        }

        guard let alertId = currentAlertId else {
            debugLog("⚠️ No alertId available, skipping acknowledge send")
            return
        }

        // Payload 생성 (명세에 맞게)
        let payload: [String: Any] = [
            "alertId": alertId,
            "wardId": wardId,
            "response": response.rawValue,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        // Room에 참여한 participant 중 Agent 찾기
        guard let agentIdentity = room.remoteParticipants.values
            .first(where: {
                let id = $0.identity?.stringValue ?? ""
                return id.hasPrefix("agent-") || id.hasPrefix("voice-agent")
            })?.identity else {
            debugLog("⚠️ No agent found in room, skipping acknowledge send")
            return
        }

        // Agent에게 reliable 전송
        let options = DataPublishOptions(
            destinationIdentities: [agentIdentity],
            topic: "acknowledge_alert",
            reliable: true
        )

        try await room.localParticipant.publish(data: jsonData, options: options)
        debugLog("✅ Sent acknowledge_alert to \(agentIdentity) (alertId: \(alertId), response: \(response.rawValue))")

        // 상태 초기화
        currentAlertId = nil
        #endif
    }

    // MARK: - Agent Response Handler (alert_response 토픽)

    /// Agent 알림 응답 처리 (alert_response 토픽)
    /// Agent가 TTS 출력 후 iOS에 Alert 표시 요청
    func handleAlertResponse(_ response: AlertResponse) {
        debugLog("📢 Received alert_response: alertId=\(response.alertId), type=\(response.alertType), riskLevel=\(response.riskLevel?.rawValue ?? "unknown")")

        // alertId 저장 (acknowledge_alert 응답 시 사용)
        currentAlertId = response.alertId

        // 알림 타입 설정 (메시지 표시용)
        switch response.alertType {
        case "device_fall":
            currentAlertType = .deviceFall
        case "person_fall":
            // 저장된 person fall 세부 타입 사용 (rapidDescent/faceDisappeared)
            currentAlertType = lastPersonFallType
        case "loud_voice":
            currentAlertType = .loudVoice
        case "emotion":
            currentAlertType = .emotion
        case "speech_keyword":
            currentAlertType = .speechKeyword
        default:
            currentAlertType = .deviceFall
        }

        // iOS Alert 표시
        showFallAlertIfNeeded()

        debugLog("⚠️ Alert displayed (alertId: \(response.alertId), riskLevel: \(response.riskLevel?.rawValue ?? "unknown"), type: \(currentAlertType))")
    }

    // MARK: - Agent Request Handlers

    /// Agent로부터 낙상 확인 Alert 표시 요청 처리
    /// Agent가 음성으로 질문 후 응답이 없을 때 호출됨
    func handleFallConfirmationRequest(_ data: RequestFallConfirmationData) {
        debugLog("📱 Agent requested fall confirmation alert (askCount: \(data.askCount))")

        // iOS Alert 표시
        showFallAlertIfNeeded()
    }

    /// Agent로부터 긴급 상황 확정 알림 처리
    /// 보호자에게 알림 전송
    func handleEmergencyConfirmed(_ data: EmergencyConfirmedData) {
        debugLog("🚨 Emergency confirmed by Agent: \(data.emergencyType), reason: \(data.reason)")

        Task {
            await sendEmergencyAlertToGuardian(data)
        }
    }

    /// 사용자가 "도움이 필요해요" 버튼을 눌렀을 때 호출
    func requestHelp() {
        debugLog("🆘 User requested help")

        // Alert 숨기기
        showFallConfirmationAlert = false

        // Agent에게 acknowledge_alert 전송 (response: "need_help")
        // Agent가 서버의 /v1/guardians/alerts/:alertId/escalate 호출하여 격상 처리
        Task {
            do {
                try await sendAcknowledgeAlert(response: .needHelp)
                debugLog("✅ Help request sent to Agent (response: need_help)")
            } catch {
                debugLog("Failed to send help request: \(error)")
            }
        }

        // 상태 초기화
        currentFallEvent = nil
        fallDetectedTime = nil
    }

    /// Agent에게 도움 요청 전송
    private func sendHelpRequestToAgent() async throws {
        #if canImport(LiveKit)
        guard let room, room.connectionState == .connected else {
            debugLog("Room not connected, skipping help request send")
            return
        }

        guard let agentIdentity = room.remoteParticipants.values
            .first(where: {
                let id = $0.identity?.stringValue ?? ""
                return id.hasPrefix("agent-") || id.hasPrefix("voice-agent")
            })?.identity else {
            debugLog("⚠️ No agent found in room, skipping help request send")
            return
        }

        let payload: [String: Any] = [
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "wardId": wardId,
            "requestType": "help_needed"
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        let options = DataPublishOptions(
            destinationIdentities: [agentIdentity],
            topic: "help_request",
            reliable: true
        )

        try await room.localParticipant.publish(data: jsonData, options: options)
        debugLog("✅ Sent help_request to \(agentIdentity)")
        #endif
    }

    /// 보호자에게 긴급 알림 전송 (서버 API 호출)
    private func sendEmergencyAlertToGuardian(_ data: EmergencyConfirmedData) async {
        debugLog("🚨 Sending emergency alert to guardian...")

        // TODO: 실제 서버 API 호출 구현
        // POST /api/alerts/emergency
        // {
        //   "wardId": wardId,
        //   "emergencyType": data.emergencyType.rawValue,
        //   "reason": data.reason.rawValue,
        //   "message": data.messageForGuardian
        // }

        // 임시: NotificationCenter로 앱 내 알림 발송
        NotificationCenter.default.post(
            name: .emergencyAlertTriggered,
            object: nil,
            userInfo: [
                "wardId": wardId,
                "emergencyType": data.emergencyType.rawValue,
                "reason": data.reason.rawValue,
                "message": data.messageForGuardian ?? "긴급 상황이 감지되었습니다"
            ]
        )

        debugLog("✅ Emergency alert posted to NotificationCenter (wardId: \(wardId))")
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

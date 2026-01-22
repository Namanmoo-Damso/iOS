import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit

@MainActor
final class LiveKitService: NSObject, ObservableObject, LiveKitServiceProtocol {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var reconnectMode: ReconnectMode?
    @Published var errorMessage: String?

    // 재연결 타이머 (30초)
    @Published var reconnectTimeRemaining: Int = 0
    @Published var isReconnecting: Bool = false

    // 상대방 연결 상태
    @Published var remoteParticipantDisconnected: Bool = false
    @Published var remoteDisconnectTimeRemaining: Int = 0

    // 실시간 자막
    let transcription = TranscriptionManager.shared

    // Face detection data channel
    let faceDetectionChannel = FaceDetectionDataChannel.shared

    // Sensor data aggregator (얼굴 감지 + 모션 센서 통합)
    let sensorAggregator = SensorDataAggregator.shared

    // Care alert service (낙상/음성/감정 알림)
    let careAlertService = CareAlertService.shared

    // Call Session Manager (센서 서비스 생명주기 관리)
    private let callSessionManager = CallSessionManager.shared
    private let defaultRemoteAudioVolume: Double = 1.0
    private let remoteAudioMutedVolume: Double = 0.0
    private var isRemoteAudioEnabled: Bool = true
    private var remoteAudioVolumeCache: [ObjectIdentifier: Double] = [:]

    let room: Room
    private var _localMedia: LocalMedia?

    /// LocalMedia는 실제로 필요할 때만 생성 (권한 요청 지연)
    var localMedia: LocalMedia {
        if _localMedia == nil {
            _localMedia = LocalMedia(room: room)
        }
        return _localMedia!
    }

    private var reconnectTimer: Timer?
    private var remoteDisconnectTimer: Timer?
    private let reconnectTimeout: Int = 30
    private let remoteDisconnectTimeout: Int = 60

    // Skip delegate notifications during intentional disconnect
    private var isDisconnecting: Bool = false

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[LiveKitService] \(message)")
        #endif
    }

    override init() {
        let r = Room()
        self.room = r
        // LocalMedia는 lazy property로 실제 사용 시 생성 (권한 요청 지연)
        super.init()
        self.room.add(delegate: self)
    }

    // MARK: - Reconnection Timer
    private func startReconnectTimer() {
        stopReconnectTimer()
        isReconnecting = true
        reconnectTimeRemaining = reconnectTimeout

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reconnectTimeRemaining -= 1
                if self.reconnectTimeRemaining <= 0 {
                    self.stopReconnectTimer()
                    self.handleReconnectTimeout()
                }
            }
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        isReconnecting = false
        reconnectTimeRemaining = 0
    }

    private func handleReconnectTimeout() {
        debugLog("Reconnect timeout - disconnecting")
        Task {
            await disconnect()
            errorMessage = "연결 복구에 실패했습니다"
        }
    }

    // MARK: - Remote Participant Disconnect Timer
    private func startRemoteDisconnectTimer() {
        stopRemoteDisconnectTimer()
        remoteParticipantDisconnected = true
        remoteDisconnectTimeRemaining = remoteDisconnectTimeout

        remoteDisconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.remoteDisconnectTimeRemaining -= 1
                if self.remoteDisconnectTimeRemaining <= 0 {
                    self.stopRemoteDisconnectTimer()
                    self.handleRemoteDisconnectTimeout()
                }
            }
        }
    }

    private func stopRemoteDisconnectTimer() {
        remoteDisconnectTimer?.invalidate()
        remoteDisconnectTimer = nil
        remoteParticipantDisconnected = false
        remoteDisconnectTimeRemaining = 0
    }

    private func handleRemoteDisconnectTimeout() {
        debugLog("Remote participant disconnect timeout - ending call")
        Task {
            await disconnect()
            errorMessage = "상대방이 연결을 종료했습니다"
        }
    }
    
    func connect(token: String) async throws {
        // 서버에서 반환한 livekitUrl 사용, 없으면 AppConfig 기본값 사용
        let serverUrl = UserDefaults.standard.string(forKey: "cachedLiveKitUrl") ?? AppConfig.liveKitServerURL
        debugLog("🔌 [CONNECT] START - url=\(serverUrl)")
        debugLog("🔌 [CONNECT] (cached from server, fallback=\(AppConfig.liveKitServerURL))")
        debugLog("🔌 [CONNECT] token length=\(token.count), prefix=\(token.prefix(20))...")
        debugLog("🔌 [CONNECT] current state=\(room.connectionState)")

        // 이미 연결 중이거나 연결된 상태면 무시
        if room.connectionState == .connecting || room.connectionState == .connected {
            debugLog("🔌 [CONNECT] SKIPPED - already connecting or connected")
            return
        }

        if room.connectionState != .disconnected {
            debugLog("🔌 [CONNECT] Disconnecting first...")
            await room.disconnect()
            debugLog("🔌 [CONNECT] Disconnected, now reconnecting")
        }

        let audioOptions = AudioCaptureOptions(
            echoCancellation: true,
            autoGainControl: true,
            noiseSuppression: true,
            highpassFilter: true,
            typingNoiseDetection: true  // 저주파 노이즈 제거
        )
        
        // 음성 통화 품질 개선 (Hi-Fi보다는 음성 최적화)
        let audioPublishOptions = AudioPublishOptions(
            encoding: .presetSpeech,  // 24kbps - 음성 통화 최적화
            dtx: true,   // 무음 시 대역폭 절약
            red: true    // 패킷 손실 시 오디오 복구 (끊김 방지)
        )

        // ✅ 비디오 인코딩 설정
        let networkMonitor = NetworkMonitor.shared
        let isWiFi = networkMonitor.connectionType == .wifi || networkMonitor.connectionType == .wired
        
        // 네트워크 타입별 비트레이트 설정
        // WiFi/Cellular 모두 15Mbps (최고화질, 방송 수준)
        let maxBitrate = 15_000_000
        let maxFps = 60  // WiFi, Cellular 모두 60fps
        let _: VideoParameters = isWiFi ? .presetH1080_169 : .presetH360_169  // WiFi: 1080p, Cellular: 360p
        
        debugLog("📶 [CONNECT] Network: \(networkMonitor.connectionType), bitrate: \(maxBitrate / 1_000_000)Mbps, fps: \(maxFps)")
        
        // VP9 + SVC (Scalable Video Coding) 설정
        // - VP9 선택 시 L3T3_KEY 모드 자동 활성화 (3 spatial + 3 temporal layers)
        // - 즉시 레이어 전환 가능 (키프레임 대기 불필요)
        // - H.264 Simulcast 대비 20-30% 대역폭 절약
        // - A14 Bionic (iPhone 12+) 하드웨어 가속 지원
        let videoPublishOptions = VideoPublishOptions(
            encoding: VideoEncoding(
                maxBitrate: maxBitrate,
                maxFps: maxFps
            ),
            simulcast: false,  // VP9 SVC와 simulcast는 상호 배타적
            preferredCodec: .vp9,  // ⭐ VP9 선택 → SVC L3T3_KEY 자동 활성화
            preferredBackupCodec: .vp8,  // 호환성 백업 코덱
            degradationPreference: .balanced  // 네트워크 나쁘면 해상도/프레임 모두 조정
        )
        
        // 카메라 캡처 해상도 설정 (WiFi: 1080p, Cellular: 720p)
        let initialResolution: Dimensions = isWiFi ? .h1080_169 : .h720_169
        let cameraCaptureOptions = CameraCaptureOptions(dimensions: initialResolution)

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: cameraCaptureOptions,  // ⭐ 카메라 해상도 설정
            defaultAudioCaptureOptions: audioOptions,
            defaultVideoPublishOptions: videoPublishOptions,
            defaultAudioPublishOptions: audioPublishOptions,
            adaptiveStream: true,  // ✅ 구독자 측 적응형 스트림
            dynacast: true         // ✅ 구독자 없는 레이어 송출 중지
        )
        // Increased reconnect attempts due to network instability
        let connectOptions = ConnectOptions(autoSubscribe: true, reconnectAttempts: 15)

        debugLog("🔌 [CONNECT] Calling room.connect()...")
        try await room.connect(
            url: serverUrl,
            token: token,
            connectOptions: connectOptions,
            roomOptions: roomOptions
        )
        debugLog("🔌 [CONNECT] room.connect() completed - state=\(room.connectionState)")

        debugLog("🔌 [CONNECT] Enabling microphone...")
        try await room.localParticipant.setMicrophone(enabled: true)
        debugLog("🔌 [CONNECT] Microphone enabled")

        debugLog("🔌 [CONNECT] Enabling camera...")
        // captureOptions를 명시적으로 전달 (WiFi: 1080p, Cellular: 720p)
        try await room.localParticipant.setCamera(enabled: true, captureOptions: cameraCaptureOptions)
        debugLog("🔌 [CONNECT] Camera enabled (\(isWiFi ? "1080p" : "720p") start)")

        // ✅ CallSessionManager를 통해 모든 센서/보조 서비스 시작
        let wardId = room.localParticipant.identity?.stringValue
        callSessionManager.startSession(room: room, wardId: wardId)

        debugLog("🔌 [CONNECT] END - SUCCESS")
        self.objectWillChange.send()
    }
    
    func disconnect() async {
        debugLog("🔌 [DISCONNECT] START")
        // Mark as intentionally disconnecting to skip delegate notifications
        isDisconnecting = true

        // Set state immediately for responsive UI
        self.connectionState = .disconnecting
        self.objectWillChange.send()

        // Stop any active timers
        stopReconnectTimer()
        stopRemoteDisconnectTimer()

        // ✅ CallSessionManager를 통해 모든 센서/보조 서비스 중지
        callSessionManager.stopSession(room: room)

        // Disconnect room (can take time)
        debugLog("🔌 [DISCONNECT] Calling room.disconnect()...")
        await room.disconnect()
        debugLog("🔌 [DISCONNECT] room.disconnect() completed")

        self.connectionState = .disconnected
        isDisconnecting = false
        debugLog("🔌 [DISCONNECT] END")
    }
    
    func setRemoteAudioEnabled(_ enabled: Bool) async {
        isRemoteAudioEnabled = enabled
        applyRemoteAudioState()
    }

    // MARK: - Remote Audio Control

    private func applyRemoteAudioState() {
        for participant in room.remoteParticipants.values {
            for publication in participant.audioTracks {
                if let track = publication.track as? RemoteAudioTrack {
                    applyRemoteAudioState(to: track)
                }
            }
        }
    }

    private func applyRemoteAudioState(to track: RemoteAudioTrack) {
        let key = ObjectIdentifier(track)
        if isRemoteAudioEnabled {
            let volume = remoteAudioVolumeCache[key] ?? defaultRemoteAudioVolume
            track.volume = volume
        } else {
            if remoteAudioVolumeCache[key] == nil {
                remoteAudioVolumeCache[key] = track.volume
            }
            track.volume = remoteAudioMutedVolume
        }
    }
}

// MARK: - RoomDelegate
extension LiveKitService: RoomDelegate {
    nonisolated func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        Task { @MainActor in
            self.debugLog("🔄 [STATE] \(oldConnectionState) → \(connectionState)")

            // Skip updates during intentional disconnect
            guard !self.isDisconnecting else {
                self.debugLog("🔄 [STATE] Skipped (isDisconnecting=true)")
                return
            }

            self.connectionState = connectionState
            if connectionState == .connected {
                self.debugLog("🔄 [STATE] ✅ Connected successfully!")
                self.errorMessage = nil
                self.reconnectMode = nil
                self.stopReconnectTimer()
            } else if connectionState == .disconnected && oldConnectionState == .reconnecting {
                self.debugLog("🔄 [STATE] ❌ Reconnect failed - disconnected")
                self.stopReconnectTimer()
            }
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, didStartReconnectWithMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
            self.debugLog("🔄 [RECONNECT] Started - mode=\(reconnectMode)")
            guard !self.isDisconnecting else { return }
            self.reconnectMode = reconnectMode
            self.connectionState = .reconnecting
            self.startReconnectTimer()
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, didCompleteReconnectWithMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
            self.debugLog("🔄 [RECONNECT] Completed - mode=\(reconnectMode)")
            guard !self.isDisconnecting else { return }
            self.reconnectMode = nil
            self.connectionState = room.connectionState
            self.stopReconnectTimer()
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, didUpdateReconnectMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            self.reconnectMode = reconnectMode
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, didUpdateIsSpeaking isSpeaking: Bool) {
        Task { @MainActor in
            if participant is LocalParticipant {
                if isSpeaking { debugLog("🎤 VAD: Local Speaking") } else { debugLog("🤫 VAD: Local Silent") }
            } else {
                // 원격 참가자 (AI Agent)가 말할 때 상태 업데이트
                debugLog("🎙️ VAD: Remote \(isSpeaking ? "Speaking" : "Silent")")
                // TranscriptionManager로 AI 발화 상태 전달 (듣는중/말하는중 UI용)
                self.transcription.setAISpeaking(isSpeaking)
            }
        }
    }

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            // 상대방 재연결됨
            self.stopRemoteDisconnectTimer()
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            // 상대방 연결 끊김 - 타이머 시작
            if room.remoteParticipants.isEmpty {
                self.startRemoteDisconnectTimer()
            }
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            debugLog("Track published: \(publication.kind)")
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            debugLog("Track unpublished: \(publication.kind)")
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            // 트랙 구독 완료 시에만 알림 (가장 핵심적인 갱신 포인트)
            debugLog("Track subscribed: \(publication.kind) from \(participant.identity?.stringValue ?? "unknown")")

            // 비디오 트랙인 경우 고화질로 고정
            if publication.kind == .video {
                debugLog("📹 Video track detected - setting high quality")
                try? await publication.set(videoQuality: .high)
                try? await publication.set(preferredDimensions: Dimensions(width: 1920, height: 1080))
            }

            // 오디오 트랙인 경우 원격 오디오 상태 적용
            if let audioTrack = publication.track as? RemoteAudioTrack {
                debugLog("🎵 Audio track subscribed from \(participant.identity?.stringValue ?? "unknown")")
                self.applyRemoteAudioState(to: audioTrack)
            }

            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, trackPublication: RemoteTrackPublication, didUpdateStreamState streamState: StreamState) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }
            self.objectWillChange.send()
        }
    }

    // MARK: - Transcription

    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didReceiveTranscriptionSegments segments: [TranscriptionSegment]) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }

            let identity = participant.identity?.stringValue
            debugLog("📝 Transcription received: \(segments.count) segments from \(identity ?? "unknown")")

            // 첫 번째 세그먼트 내용 로깅
            if let first = segments.first {
                debugLog("📝 First segment: \"\(first.text)\" isFinal=\(first.isFinal)")
            }

            // TranscriptionManager로 전달
            self.transcription.processTranscriptionSegments(segments, participantIdentity: identity)
        }
    }

    // MARK: - Data Channel

    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }

            let identity = participant?.identity?.stringValue
            debugLog("📦 Data received: \(data.count) bytes, topic=\(topic), from=\(identity ?? "unknown")")

            // 토픽별 데이터 처리
            switch topic {
            case FaceDetectionData.topic:
                self.faceDetectionChannel.handleReceivedData(data, from: identity)

            case MotionSensorData.topic:
                // Motion sensor 데이터 수신 (서버에서 보낸 경우)
                debugLog("📦 Motion sensor data received from \(identity ?? "unknown")")

            case AggregatedSensorData.topic:
                // 통합 센서 데이터 수신 (서버에서 보낸 경우)
                debugLog("📦 Aggregated sensor data received from \(identity ?? "unknown")")

            case AlertEventData.topic:
                // 긴급 알림 이벤트 수신
                debugLog("🚨 Alert event received from \(identity ?? "unknown")")
                handleAlertEvent(data, from: identity)

            case CareAlertPayload.topic:
                // 케어 알림 수신 (Agent에서 응답한 경우)
                debugLog("🏥 Care alert received from \(identity ?? "unknown")")
                handleCareAlert(data, from: identity)

            case AlertResponse.topic:
                // Agent 알림 응답 수신 → iOS Alert 표시
                debugLog("📢 Alert response received from \(identity ?? "unknown")")
                handleAlertResponse(data, from: identity)

            default:
                debugLog("📦 Unknown topic data: \(topic)")
            }
        }
    }

    /// 긴급 알림 이벤트 처리
    private func handleAlertEvent(_ data: Data, from identity: String?) {
        do {
            let alert = try JSONDecoder().decode(AlertEventData.self, from: data)
            debugLog("🚨 Alert: type=\(alert.type), severity=\(alert.severity)")

            // 낙상 감지 알림인 경우 특별 처리
            if alert.type == .fall {
                NotificationCenter.default.post(
                    name: .fallAlertReceived,
                    object: nil,
                    userInfo: ["alert": alert, "from": identity ?? "unknown"]
                )
            }
        } catch {
            debugLog("🚨 Failed to decode alert event: \(error)")
        }
    }

    /// Agent 알림 응답 처리 (alert_response 토픽)
    /// Agent가 TTS 출력과 함께 iOS에 Alert 표시 요청
    private func handleAlertResponse(_ data: Data, from identity: String?) {
        do {
            let response = try JSONDecoder().decode(AlertResponse.self, from: data)
            debugLog("📢 AlertResponse: type=\(response.alertType), severity=\(response.severity ?? "unknown")")
            debugLog("📢 Agent says: \(response.agentResponse ?? "")")

            // CareAlertService에 전달하여 iOS Alert 표시
            careAlertService.handleAlertResponse(response)

        } catch {
            debugLog("📢 Failed to decode alert response: \(error)")
        }
    }

    /// 케어 알림 처리 (Agent에서 응답한 경우)
    private func handleCareAlert(_ data: Data, from identity: String?) {
        do {
            let alert = try CareAlertPayload.from(jsonData: data)
            debugLog("🏥 CareAlert: type=\(alert.alertType), severity=\(alert.severity)")

            // 알림 타입별 처리
            switch alert.alertType {
            case .deviceFall, .personFall:
                NotificationCenter.default.post(
                    name: .careAlertFallReceived,
                    object: nil,
                    userInfo: ["alert": alert, "from": identity ?? "unknown"]
                )
            case .loudVoice:
                NotificationCenter.default.post(
                    name: .careAlertLoudVoiceReceived,
                    object: nil,
                    userInfo: ["alert": alert, "from": identity ?? "unknown"]
                )
            case .emotion:
                NotificationCenter.default.post(
                    name: .careAlertEmotionReceived,
                    object: nil,
                    userInfo: ["alert": alert, "from": identity ?? "unknown"]
                )
            case .dangerDismissed:
                // 서버에서 위험 해제 확인 응답 (현재 iOS에서는 별도 처리 불필요)
                debugLog("🏥 Danger dismissed acknowledged by server")

            // MARK: - Agent → iOS 요청 처리

            case .requestFallConfirmation:
                // Agent가 음성 질문 후 응답 없을 때 iOS Alert 표시 요청
                debugLog("📱 Agent requested fall confirmation alert")
                if case .requestFallConfirmation(let requestData) = alert.data {
                    careAlertService.handleFallConfirmationRequest(requestData)
                }

            case .emergencyConfirmed:
                // Agent가 긴급 상황 확정 → 보호자 알림
                debugLog("🚨 Agent confirmed emergency, notifying guardian")
                if case .emergencyConfirmed(let emergencyData) = alert.data {
                    careAlertService.handleEmergencyConfirmed(emergencyData)
                }
            }
        } catch {
            debugLog("🏥 Failed to decode care alert: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 낙상 알림 수신 (기존 AlertEventData 용)
    static let fallAlertReceived = Notification.Name("fallAlertReceived")

    /// 케어 알림 - 낙상 (기기/사람)
    static let careAlertFallReceived = Notification.Name("careAlertFallReceived")

    /// 케어 알림 - 큰 음성
    static let careAlertLoudVoiceReceived = Notification.Name("careAlertLoudVoiceReceived")

    /// 케어 알림 - 감정 분석
    static let careAlertEmotionReceived = Notification.Name("careAlertEmotionReceived")

    /// 긴급 알림 발생 (보호자 알림용)
    static let emergencyAlertTriggered = Notification.Name("emergencyAlertTriggered")
}
#endif

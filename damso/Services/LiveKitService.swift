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

    // 오디오 시각화
    let audioVisualizer = AudioVisualizerManager.shared

    // 실시간 자막
    let transcription = TranscriptionManager.shared

    // Face detection data channel
    let faceDetectionChannel = FaceDetectionDataChannel.shared

    // Sensor data aggregator (얼굴 감지 + 모션 센서 통합)
    let sensorAggregator = SensorDataAggregator.shared

    // Care alert service (낙상/음성/감정 알림)
    let careAlertService = CareAlertService.shared

    // User audio level monitor (큰 소리 감지)
    let userAudioMonitor = UserAudioLevelMonitor.shared

    // Person fall detector (카메라 기반 사람 낙상 감지)
    let personFallDetector = PersonFallDetector.shared

    // Emotion analyzer (감정 분석)
    let emotionAnalyzer = EmotionAnalyzer.shared
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

        // ✅ Simulcast 설정: 1080p(메인) + 720p, 360p 하위 레이어
        let videoPublishOptions = VideoPublishOptions(
            encoding: VideoEncoding(
                maxBitrate: 5_000_000,  // 5Mbps (고품질)
                maxFps: 30
            ),
            simulcast: true,
            simulcastLayers: [
                VideoParameters.presetH360_169,  // 360p (~400kbps)
                VideoParameters.presetH720_169   // 720p (~1.7Mbps)
            ],
            degradationPreference: .maintainResolution
        )

        let roomOptions = RoomOptions(
            defaultAudioCaptureOptions: audioOptions,
            defaultVideoPublishOptions: videoPublishOptions, // ✅ 추가
            adaptiveStream: true,  // ✅ 구독자 측 적응형 스트림
            dynacast: true         // ✅ 구독자 없는 레이어 송출 중지
        )
        let connectOptions = ConnectOptions(autoSubscribe: true, reconnectAttempts: 10)

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
        let captureOptions = CameraCaptureOptions(dimensions: .h1080_169)
        try await room.localParticipant.setCamera(enabled: true, captureOptions: captureOptions)
        debugLog("🔌 [CONNECT] Camera enabled")

        // 자막 기능 시작
        transcription.start()
        debugLog("🔌 [CONNECT] Transcription started")

        // 오디오 시각화 시작
        audioVisualizer.start()
        debugLog("🔌 [CONNECT] AudioVisualizer started")

        // Face detection data channel 연결
        faceDetectionChannel.setRoom(room)
        debugLog("🔌 [CONNECT] FaceDetectionChannel connected")

        // 센서 데이터 수집 자동 시작
        // Note: 얼굴 감지는 FaceLandmarkDetector(VideoRenderer)를 통해 자동 처리됨
        sensorAggregator.start(enableMotionSensor: true)
        debugLog("🔌 [CONNECT] SensorAggregator started")

        // 케어 알림 서비스 시작 (낙상/음성/감정 알림)
        let wardId = room.localParticipant.identity?.stringValue
        careAlertService.start(room: room, wardId: wardId)
        debugLog("🔌 [CONNECT] CareAlertService started (wardId: \(wardId ?? "unknown"))")

        // 사용자 음성 레벨 모니터링 시작
        if let localAudioTrack = room.localParticipant.localAudioTracks.first?.track as? LocalAudioTrack {
            userAudioMonitor.startMonitoring(track: localAudioTrack)
            debugLog("🔌 [CONNECT] UserAudioMonitor started")
        } else {
            debugLog("🔌 [CONNECT] ⚠️ LocalAudioTrack not found for monitoring")
        }

        // 사람 낙상 감지 시작 (카메라 기반)
        personFallDetector.start()
        debugLog("🔌 [CONNECT] PersonFallDetector started")

        // 기기 낙상 감지 시작 (가속도계/자이로 기반)
        MotionSensorService.shared.startCollection(sendToDataChannel: false)
        debugLog("🔌 [CONNECT] MotionSensorService started")

        // 얼굴 랜드마크 검출 시작 (감정 분석용 - PIP 터치 없이 자동 시작)
        if let localVideoTrack = room.localParticipant.localVideoTracks.first?.track as? LocalVideoTrack {
            FaceLandmarkDetector.shared.startDetection(for: localVideoTrack)
            debugLog("🔌 [CONNECT] FaceLandmarkDetector started (auto)")
        } else {
            debugLog("🔌 [CONNECT] ⚠️ LocalVideoTrack not found for face detection")
        }

        // 감정 분석 시작
        emotionAnalyzer.start()
        debugLog("🔌 [CONNECT] EmotionAnalyzer started")

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

        // 오디오 시각화 중지
        detachAudioVisualizerFromRemoteTracks()

        // 자막 기능 중지
        transcription.stop()
        remoteAudioVolumeCache.removeAll()
        isRemoteAudioEnabled = true

        // Face detection data channel 해제
        faceDetectionChannel.setRoom(nil)

        // 센서 데이터 수집 자동 중지
        sensorAggregator.stop()
        debugLog("🔌 [DISCONNECT] SensorAggregator stopped")

        // 케어 알림 서비스 중지
        careAlertService.stop()
        debugLog("🔌 [DISCONNECT] CareAlertService stopped")

        // 사용자 음성 레벨 모니터링 중지
        if let localAudioTrack = room.localParticipant.localAudioTracks.first?.track as? LocalAudioTrack {
            userAudioMonitor.stopMonitoring(track: localAudioTrack)
            debugLog("🔌 [DISCONNECT] UserAudioMonitor stopped")
        }

        // 사람 낙상 감지 중지
        personFallDetector.stop()
        debugLog("🔌 [DISCONNECT] PersonFallDetector stopped")

        // 기기 낙상 감지 중지
        MotionSensorService.shared.stopCollection()
        debugLog("🔌 [DISCONNECT] MotionSensorService stopped")

        // 얼굴 랜드마크 검출 중지
        if let localVideoTrack = room.localParticipant.localVideoTracks.first?.track as? LocalVideoTrack {
            FaceLandmarkDetector.shared.stopDetection(for: localVideoTrack)
            debugLog("🔌 [DISCONNECT] FaceLandmarkDetector stopped")
        }

        // 감정 분석 중지
        emotionAnalyzer.stop()
        debugLog("🔌 [DISCONNECT] EmotionAnalyzer stopped")

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

    // MARK: - Audio Visualizer

    /// 모든 원격 오디오 트랙에 시각화 렌더러 연결
    private func attachAudioVisualizerToRemoteTracks() {
        audioVisualizer.start()
        for participant in room.remoteParticipants.values {
            for publication in participant.audioTracks {
                if let track = publication.track as? RemoteAudioTrack {
                    track.add(audioRenderer: audioVisualizer)
                    debugLog("🎵 AudioVisualizer attached to track: \(track.sid?.stringValue ?? "unknown")")
                }
            }
        }
    }

    /// 모든 원격 오디오 트랙에서 시각화 렌더러 분리
    private func detachAudioVisualizerFromRemoteTracks() {
        for participant in room.remoteParticipants.values {
            for publication in participant.audioTracks {
                if let track = publication.track as? RemoteAudioTrack {
                    track.remove(audioRenderer: audioVisualizer)
                }
            }
        }
        audioVisualizer.stop()
    }

    /// 특정 트랙에 시각화 렌더러 연결
    private func attachAudioVisualizer(to track: RemoteAudioTrack) {
        if !audioVisualizer.isActive {
            audioVisualizer.start()
        }
        track.add(audioRenderer: audioVisualizer)
        debugLog("🎵 AudioVisualizer attached to new track: \(track.sid?.stringValue ?? "unknown")")
    }

    /// 특정 트랙에서 시각화 렌더러 분리
    private func detachAudioVisualizer(from track: RemoteAudioTrack) {
        track.remove(audioRenderer: audioVisualizer)
        debugLog("🎵 AudioVisualizer detached from track: \(track.sid?.stringValue ?? "unknown")")
    }

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
                // 원격 참가자 (AI Agent)가 말할 때 시각화 트리거
                debugLog("🎙️ VAD: Remote \(isSpeaking ? "Speaking" : "Silent")")
                if isSpeaking {
                    // AI가 말하고 있을 때 audioLevel 시뮬레이션
                    self.audioVisualizer.simulateSpeaking()
                } else {
                    self.audioVisualizer.simulateSilent()
                }
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

            // 오디오 트랙인 경우 시각화 렌더러 연결
            if let audioTrack = publication.track as? RemoteAudioTrack {
                debugLog("🎵 Audio track detected - attaching visualizer")
                self.applyRemoteAudioState(to: audioTrack)
                self.attachAudioVisualizer(to: audioTrack)
            } else {
                debugLog("⚠️ Track is not RemoteAudioTrack: \(type(of: publication.track))")
            }

            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard !self.isDisconnecting else { return }

            // 오디오 트랙인 경우 시각화 렌더러 분리
            if let audioTrack = publication.track as? RemoteAudioTrack {
                self.detachAudioVisualizer(from: audioTrack)
            }

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
            debugLog("📢 AlertResponse: type=\(response.alertType), severity=\(response.severity)")
            debugLog("📢 Agent says: \(response.agentResponse)")

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

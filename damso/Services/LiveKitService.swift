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

    let room: Room
    let localMedia: LocalMedia

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
        self.localMedia = LocalMedia(room: r)
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
        debugLog("🔌 [CONNECT] START - url=\(AppConfig.liveKitServerURL)")
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
            typingNoiseDetection: true
        )

        let roomOptions = RoomOptions(defaultAudioCaptureOptions: audioOptions)
        let connectOptions = ConnectOptions(autoSubscribe: true, reconnectAttempts: 10)

        debugLog("🔌 [CONNECT] Calling room.connect()...")
        try await room.connect(
            url: AppConfig.liveKitServerURL,
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

        // Disconnect room (can take time)
        debugLog("🔌 [DISCONNECT] Calling room.disconnect()...")
        await room.disconnect()
        debugLog("🔌 [DISCONNECT] room.disconnect() completed")

        self.connectionState = .disconnected
        isDisconnecting = false
        debugLog("🔌 [DISCONNECT] END")
    }
    
    func setRemoteAudioEnabled(_ enabled: Bool) async {
        for participant in room.remoteParticipants.values {
            for publication in participant.audioTracks {
                if let track = publication.track as? RemoteAudioTrack {
                    if enabled { try? await track.start() } else { try? await track.stop() }
                }
            }
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
        if participant is LocalParticipant {
            Task { @MainActor in
                if isSpeaking { debugLog("🎤 VAD: Speaking") } else { debugLog("🤫 VAD: Silent") }
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
            debugLog("Track subscribed: \(publication.kind)")
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
}
#endif

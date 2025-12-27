import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit

@MainActor
class LiveKitService: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var reconnectMode: ReconnectMode?
    @Published var errorMessage: String?
    
    let room: Room
    let localMedia: LocalMedia
    
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
    
    func connect(token: String) async throws {
        debugLog("Connecting to \(AppConfig.liveKitServerURL)")
        
        if room.connectionState != .disconnected {
            await room.disconnect()
        }
        
        let audioOptions = AudioCaptureOptions(
            echoCancellation: true,
            autoGainControl: true,
            noiseSuppression: true,
            typingNoiseDetection: true
        )
        
        let roomOptions = RoomOptions(defaultAudioCaptureOptions: audioOptions)
        let connectOptions = ConnectOptions(autoSubscribe: true, reconnectAttempts: 10)
        
        try await room.connect(
            url: AppConfig.liveKitServerURL,
            token: token,
            connectOptions: connectOptions,
            roomOptions: roomOptions
        )
        
        try await room.localParticipant.setMicrophone(enabled: true)
        let captureOptions = CameraCaptureOptions(dimensions: .h1080_169)
        try await room.localParticipant.setCamera(enabled: true, captureOptions: captureOptions)
        
        self.objectWillChange.send()
    }
    
    func disconnect() async {
        await room.disconnect()
        self.connectionState = .disconnected
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
            self.connectionState = connectionState
            if connectionState == .connected {
                self.errorMessage = nil
                self.reconnectMode = nil
            }
            // 연결 상태 변화는 중요한 이벤트이므로 즉시 알림
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, didStartReconnectWithMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
            self.reconnectMode = reconnectMode
            self.connectionState = .reconnecting
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, didCompleteReconnectWithMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
            self.reconnectMode = nil
            self.connectionState = room.connectionState
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, didUpdateReconnectMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
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
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.objectWillChange.send()
        }
    }
    
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            debugLog("Track published: \(publication.kind)")
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            debugLog("Track unpublished: \(publication.kind)")
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            // 트랙 구독 완료 시에만 알림 (가장 핵심적인 갱신 포인트)
            debugLog("Track subscribed: \(publication.kind)")
            self.objectWillChange.send() 
        }
    }
    
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            self.objectWillChange.send()
        }
    }
    
    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        Task { @MainActor in
            self.objectWillChange.send()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, trackPublication: RemoteTrackPublication, didUpdateStreamState streamState: StreamState) {
        Task { @MainActor in
            self.objectWillChange.send()
        }
    }
}
#endif

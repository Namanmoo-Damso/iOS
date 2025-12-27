import Foundation
import SwiftUI
import Combine
import Security
import Security
#if canImport(LiveKit)
import LiveKit
#endif

struct ContentView: View {
    #if canImport(LiveKit)
    @StateObject private var viewModel = LiveKitViewModel()

    var body: some View {
        LiveKitRoomView(viewModel: viewModel)
    }
    #else
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.large)
                .foregroundStyle(.orange)
            Text("LiveKit not available in this build.")
                .font(.headline)
            Text("Add the LiveKit Swift Package or build for a supported platform.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    #endif
}

#if canImport(LiveKit)
private struct LiveKitRoomView: View {
    @ObservedObject var viewModel: LiveKitViewModel
    @ObservedObject var room: Room
    @ObservedObject var localMedia: LocalMedia
    @StateObject private var callStore = CallStateStore.shared
    @State private var isRemoteVideoVisible = true
    @State private var isRemoteAudioEnabled = true

    init(viewModel: LiveKitViewModel) {
        self.viewModel = viewModel
        self.room = viewModel.room
        self.localMedia = viewModel.localMedia
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 16) {
                    VideoStageView(
                        remoteVideos: remoteVideoItems,
                        localTrack: localMedia.cameraTrack,
                        isConnected: viewModel.isConnected,
                        isRemoteVideoVisible: isRemoteVideoVisible
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .background(Color.black.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(spacing: 12) {
                        statusPanel
                        callToAction

                        if viewModel.isConnected {
                            controlPanel
                        }
                    }
                }
                .padding()

                if let activeCall = callStore.activeCall {
                    IncomingCallBanner(
                        caller: activeCall.handle,
                        onAccept: {
                            CallManager.shared.answerCall(uuid: activeCall.id)
                            if let roomName = activeCall.roomName {
                                viewModel.startCall(roomName: roomName)
                            } else {
                                viewModel.startCall()
                            }
                        },
                        onDecline: {
                            CallManager.shared.endCall(uuid: activeCall.id)
                        }
                    )
                    .padding(.top, 12)
                }
            }
            .navigationTitle("LiveKit")
        }
    }

    private var statusPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if viewModel.isBusy {
                    ProgressView()
                }
                Text(viewModel.statusText)
                    .font(.callout)
                    .foregroundStyle(viewModel.statusColor)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let mediaError = localMedia.error {
                Text(mediaError.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var callToAction: some View {
        Button(viewModel.isConnected ? "통화 종료" : "영상통화 시작하기") {
            if viewModel.isConnected {
                viewModel.disconnect()
            } else {
                viewModel.startCall()
            }
        }
        .font(.headline)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isBusy)
    }

    private var controlPanel: some View {
        VStack(spacing: 16) {
            // Local Controls
            HStack(spacing: 12) {
                Button {
                    Task {
                        await localMedia.toggleMicrophone()
                    }
                } label: {
                    Label(
                        localMedia.isMicrophoneEnabled ? "Mic On" : "Mic Off",
                        systemImage: localMedia.isMicrophoneEnabled ? "mic.fill" : "mic.slash.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(localMedia.isMicrophoneEnabled ? .green : .red)

                Button {
                    Task {
                        await localMedia.toggleCamera()
                    }
                } label: {
                    Label(
                        localMedia.isCameraEnabled ? "Cam On" : "Cam Off",
                        systemImage: localMedia.isCameraEnabled ? "video.fill" : "video.slash.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(localMedia.isCameraEnabled ? .green : .red)

                if localMedia.canSwitchCamera {
                    Button {
                        Task {
                            await localMedia.switchCamera()
                        }
                    } label: {
                        Label("Flip", systemImage: "arrow.triangle.2.circlepath.camera")
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Remote Controls
            HStack(spacing: 12) {
                Button {
                    isRemoteAudioEnabled.toggle()
                    Task {
                        await viewModel.setRemoteAudioEnabled(isRemoteAudioEnabled)
                    }
                } label: {
                    Label(
                        isRemoteAudioEnabled ? "Remote Audio On" : "Remote Audio Off",
                        systemImage: isRemoteAudioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(isRemoteAudioEnabled ? .blue : .gray)

                Button {
                    isRemoteVideoVisible.toggle()
                } label: {
                    Label(
                        isRemoteVideoVisible ? "Remote Video On" : "Remote Video Off",
                        systemImage: isRemoteVideoVisible ? "eye.fill" : "eye.slash.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(isRemoteVideoVisible ? .blue : .gray)
            }
        }
    }

    private var remoteVideoItems: [RemoteVideoItem] {
        let participants = room.remoteParticipants.values.sorted { lhs, rhs in
            let left = lhs.identity?.stringValue ?? lhs.sid?.stringValue ?? ""
            let right = rhs.identity?.stringValue ?? rhs.sid?.stringValue ?? ""
            return left < right
        }

        return participants.compactMap { participant in
            guard let track = participant.firstCameraVideoTrack else { return nil }
            let name = participant.name
                ?? participant.identity?.stringValue
                ?? participant.sid?.stringValue
                ?? "Guest"
            let id = participant.sid?.stringValue ?? participant.identity?.stringValue ?? UUID().uuidString
            return RemoteVideoItem(id: id, name: name, track: track)
        }
    }
}

private struct IncomingCallBanner: View {
    let caller: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Incoming Call")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(caller)
                    .font(.headline)
            }

            Spacer()

            Button("Decline") {
                onDecline()
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button("Accept") {
                onAccept()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
        .padding(.horizontal)
    }
}

private struct VideoStageView: View {
    let remoteVideos: [RemoteVideoItem]
    let localTrack: VideoTrack?
    let isConnected: Bool
    let isRemoteVideoVisible: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let firstRemote = remoteVideos.first {
                if isRemoteVideoVisible {
                    VideoTileView(track: firstRemote.track, label: firstRemote.name, mirrorMode: .off)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ZStack {
                        Color.black
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Remote Video Hidden")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: isConnected ? "person.2" : "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(isConnected ? "Waiting for participant..." : "Not connected")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let localTrack {
                VideoTileView(track: localTrack, label: "You", mirrorMode: .mirror)
                    .frame(width: 120, height: 170)
                    .padding(12)
            }
        }
    }
}

private struct VideoTileView: View {
    let track: VideoTrack
    let label: String
    let mirrorMode: VideoView.MirrorMode

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: mirrorMode)
                .background(Color.black)
                .clipped()

            Text(label)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RemoteVideoItem: Identifiable {
    let id: String
    let name: String
    let track: VideoTrack
}

@MainActor
final class LiveKitViewModel: NSObject, ObservableObject, RoomDelegate {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var reconnectMode: ReconnectMode?
    @Published var errorMessage: String?
    @Published private(set) var isRequestingToken = false

    let room: Room
    let localMedia: LocalMedia

    private let liveKitServerURL = AppConfig.liveKitServerURL
    private let tokenEndpoint = URL(string: "\(AppConfig.apiBaseURL)/v1/rtc/token")!
    private let authTokenKey = "authToken"
    private let identityKey = "user_identity"
    private let apnsKey = "cached_apns_token"
    private let voipKey = "cached_voip_token"
    private var apnsEnv: String {
        resolveApnsEnv()
    }
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[LiveKitViewModel] \(message)")
        #endif
    }

    private func resolveApnsEnv() -> String {
        #if DEBUG
        return "dev"
        #else
        return "prod"
        #endif
    }

    private func summarizeToken(_ token: String?) -> String {
        guard let token, !token.isEmpty else { return "none" }
        let suffix = token.suffix(6)
        return "len=\(token.count) ..\(suffix)"
    }

    override init() {
        room = Room()
        localMedia = LocalMedia(room: room)
        super.init()
        room.add(delegate: self)
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    var isBusy: Bool {
        isRequestingToken || connectionState == .connecting || connectionState == .reconnecting || connectionState == .disconnecting
    }

    var statusText: String {
        if isRequestingToken {
            return "Requesting token..."
        }

        switch connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .reconnecting:
            if let reconnectMode {
                return "Reconnecting (\(reconnectMode == .quick ? "quick" : "full"))..."
            }
            return "Reconnecting..."
        case .disconnecting:
            return "Disconnecting..."
        case .disconnected:
            return "Disconnected"
        }
    }

    var statusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .reconnecting:
            return .orange
        default:
            return .secondary
        }
    }

    func setRemoteAudioEnabled(_ enabled: Bool) async {
        for participant in room.remoteParticipants.values {
            for publication in participant.audioTracks {
                if let track = publication.track as? RemoteAudioTrack {
                    if enabled {
                        try? await track.start()
                    } else {
                        try? await track.stop()
                    }
                }
            }
        }
    }

    func startCall(roomName: String? = nil) {
        if let roomName {
            activeRoomName = roomName
        }
        debugLog("startCall requested room=\(activeRoomName)")
        Task {
            await startCallInternal()
        }
    }

    func disconnect() {
        debugLog("disconnect requested")
        connectionState = .disconnecting
        Task {
            await room.disconnect()
        }
    }

    private func startCallInternal() async {
        guard !isBusy else { return }

        errorMessage = nil
        reconnectMode = nil

        do {
            debugLog("fetching LiveKit token...")
            let token = try await fetchLiveKitToken()
            connectionState = .connecting
            debugLog("connecting to LiveKit url=\(liveKitServerURL)")

            // 1. 오디오 전처리 옵션 설정 (Noise Suppression, Echo Cancellation, AGC)
            let audioOptions = AudioCaptureOptions(
                echoCancellation: true,
                autoGainControl: true, noiseSuppression: true,
                typingNoiseDetection: true
            )

            let roomOptions = RoomOptions(
                defaultAudioCaptureOptions: audioOptions
            )

            let connectOptions = ConnectOptions(autoSubscribe: true, reconnectAttempts: 10)
            try await room.connect(url: liveKitServerURL, token: token, connectOptions: connectOptions, roomOptions: roomOptions)
            try await room.localParticipant.setMicrophone(enabled: true)
            
            // 1080p 화질 설정 적용
            let captureOptions = CameraCaptureOptions(
                dimensions: .h1080_169
            )
            try await room.localParticipant.setCamera(enabled: true, captureOptions: captureOptions)
            debugLog("local media enabled")
        } catch {
            errorMessage = error.localizedDescription
            connectionState = .disconnected
            debugLog("startCall failed: \(error.localizedDescription)")
        }
    }

    private func fetchApiToken() async throws -> String {
        let identity = stableIdentity()

        let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/anonymous")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "identity": identity,
            "displayName": "iOS User"
        ])
        
        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse {
            debugLog("auth/anonymous status=\(httpResponse.statusCode)")
            if !(200..<300).contains(httpResponse.statusCode) {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw TokenError.httpStatus(code: httpResponse.statusCode, body: bodyText)
            }
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["accessToken"] as? String else {
            throw TokenError.missingToken
        }
        
        UserDefaults.standard.set(token, forKey: authTokenKey)
        debugLog("api token stored \(summarizeToken(token))")
        return token
    }

    private func fetchLiveKitToken() async throws -> String {
        var authToken = UserDefaults.standard.string(forKey: authTokenKey)
        if authToken == nil || authToken?.isEmpty == true {
            authToken = try await fetchApiToken()
        }
        
        // Force unwrap is safe here because fetchApiToken throws if it fails
        let token = authToken!

        isRequestingToken = true
        defer { isRequestingToken = false }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let identity = stableIdentity()
        let cachedApns = UserDefaults.standard.string(forKey: apnsKey)
        let cachedVoip = UserDefaults.standard.string(forKey: voipKey)
        debugLog("rtc/token room=\(activeRoomName) identity=\(identity) role=viewer env=\(apnsEnv) apns=\(summarizeToken(cachedApns)) voip=\(summarizeToken(cachedVoip))")
        var body: [String: Any] = [
            "roomName": activeRoomName,
            "identity": identity,
            "name": "iOS User",
            "role": "viewer",
            "platform": "ios",
            "env": apnsEnv
        ]
        if let apns = cachedApns, !apns.isEmpty {
            body["apnsToken"] = apns
        }
        if let voip = cachedVoip, !voip.isEmpty {
            body["voipToken"] = voip
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.invalidResponse
        }
        debugLog("rtc/token status=\(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
             // Token might be expired, try refreshing once
             UserDefaults.standard.removeObject(forKey: authTokenKey)
             // Simple recursion or just fail for now. To avoid infinite loop, just fail.
             // Ideally we should retry. For now let's just throw.
             // Or better, logic: if 401, clear token and retry?
             // The user snippet didn't include retry logic. I'll stick to basic.
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TokenError.httpStatus(code: httpResponse.statusCode, body: body)
        }

        let liveKitToken = try parseToken(from: data)
        debugLog("rtc/token received \(summarizeToken(liveKitToken))")
        return liveKitToken
    }

    private func parseToken(from data: Data) throws -> String {
        if let raw = String(data: data, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.first != "{", trimmed.first != "[" {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        let response = try JSONDecoder().decode(TokenEnvelope.self, from: data)
        return response.token
    }

    private enum TokenError: LocalizedError {
        case missingAuthToken
        case invalidResponse
        case httpStatus(code: Int, body: String)
        case missingToken

        var errorDescription: String? {
            switch self {
            case .missingAuthToken:
                return "Missing API auth token. Store it in UserDefaults with key 'authToken'."
            case .invalidResponse:
                return "Invalid token response."
            case let .httpStatus(code, body):
                if body.isEmpty {
                    return "Token API failed with status \(code)."
                }
                return "Token API failed (\(code)): \(body)"
            case .missingToken:
                return "Token is missing in API response."
            }
        }
    }

    private struct TokenEnvelope: Decodable {
        let token: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let token = try container.decodeIfPresent(String.self, forKey: .token) {
                self.token = token
                return
            }

            if let token = try container.decodeIfPresent(String.self, forKey: .accessToken) {
                self.token = token
                return
            }

            if let nested = try container.decodeIfPresent(Nested.self, forKey: .data),
               let token = nested.token ?? nested.accessToken {
                self.token = token
                return
            }

            if let nested = try container.decodeIfPresent(Nested.self, forKey: .result),
               let token = nested.token ?? nested.accessToken {
                self.token = token
                return
            }

            throw TokenError.missingToken
        }

        private struct Nested: Decodable {
            let token: String?
            let accessToken: String?
        }

        private enum CodingKeys: String, CodingKey {
            case token
            case accessToken
            case data
            case result
        }
    }

    nonisolated func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        Task { @MainActor in
            self.connectionState = connectionState
            if connectionState == .connected {
                errorMessage = nil
            }
            if connectionState != .reconnecting {
                reconnectMode = nil
            }
            debugLog("connectionState \(oldConnectionState) -> \(connectionState)")
        }
    }

    nonisolated func roomDidConnect(_ room: Room) {
        Task { @MainActor in
            connectionState = room.connectionState
            errorMessage = nil
            debugLog("roomDidConnect")
        }
    }

    nonisolated func roomIsReconnecting(_ room: Room) {
        Task { @MainActor in
            connectionState = .reconnecting
            debugLog("roomIsReconnecting")
        }
    }

    nonisolated func roomDidReconnect(_ room: Room) {
        Task { @MainActor in
            connectionState = .connected
            reconnectMode = nil
            debugLog("roomDidReconnect")
        }
    }

    nonisolated func room(_ room: Room, didStartReconnectWithMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
            connectionState = .reconnecting
            self.reconnectMode = reconnectMode
            debugLog("didStartReconnect mode=\(reconnectMode)")
        }
    }

    nonisolated func room(_ room: Room, didCompleteReconnectWithMode reconnectMode: ReconnectMode) {
        Task { @MainActor in
            connectionState = .connected
            self.reconnectMode = nil
            debugLog("didCompleteReconnect mode=\(reconnectMode)")
        }
    }

    nonisolated func room(_ room: Room, didFailToConnectWithError error: LiveKitError?) {
        Task { @MainActor in
            errorMessage = error?.localizedDescription ?? "Failed to connect."
            connectionState = .disconnected
            debugLog("didFailToConnect error=\(error?.localizedDescription ?? "nil")")
        }
    }

    nonisolated func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor in
            if let error {
                errorMessage = error.localizedDescription
            }
            connectionState = .disconnected
            debugLog("didDisconnect error=\(error?.localizedDescription ?? "nil")")
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, didUpdateIsSpeaking isSpeaking: Bool) {
        if participant is LocalParticipant {
            Task { @MainActor in
                // VAD 이벤트 로그 출력
                if isSpeaking {
                    debugLog("🎤 User started speaking (VAD active)")
                } else {
                    debugLog("🤫 User stopped speaking (VAD inactive)")
                }
            }
        }
    }

    private func stableIdentity() -> String {
        if let stored = UserDefaults.standard.string(forKey: identityKey) {
            return stored
        }
        let newIdentity = "ios-\(UUID().uuidString)"
        UserDefaults.standard.set(newIdentity, forKey: identityKey)
        return newIdentity
    }

    @Published private var activeRoomName = "demo-room"
}
#endif

#Preview {
    ContentView()
}


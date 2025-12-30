import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct FullScreenCallView: View {
    @ObservedObject var viewModel: AppLiveKitViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    // Shortcut accessors
    var room: Room { viewModel.room }
    var localMedia: LocalMedia { viewModel.localMedia }

    // Local state
    @State private var isRemoteVideoVisible = true
    @State private var isRemoteAudioEnabled = true
    @State private var showNetworkAlert = false
    @State private var showCellularWarning = false
    @State private var pendingCallRoomName: String? = nil
    @State private var pendingIncomingCall: Bool = false
    @State private var callDuration: TimeInterval = 0
    @State private var callTimer: Timer? = nil
    @State private var selectedVideoQuality: VideoQualityPreset = .auto
    @State private var isQualitySelectorExpanded = false

    let onDismiss: () -> Void

    init(viewModel: AppLiveKitViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Full screen remote video background
            remoteVideoBackground
                .ignoresSafeArea()

            // UI Overlay
            VStack(spacing: 0) {
                // Top bar
                CallTopBar(
                    callerName: remoteParticipantName,
                    callDuration: callDuration,
                    isConnected: viewModel.isConnected,
                    remoteConnectionQuality: remoteConnectionQuality
                )

                Spacer()

                // Video quality selector (above control bar)
                VideoQualitySelector(
                    selectedQuality: $selectedVideoQuality,
                    isExpanded: $isQualitySelectorExpanded,
                    currentResolution: currentResolutionString
                )
                .padding(.bottom, 12)
                .onChange(of: selectedVideoQuality) { _, newQuality in
                    Task {
                        await changeVideoQuality(to: newQuality)
                    }
                }

                // Bottom control bar
                CallControlBar(
                    isMicEnabled: localMedia.isMicrophoneEnabled,
                    isCameraEnabled: localMedia.isCameraEnabled,
                    isSpeakerEnabled: isRemoteAudioEnabled,
                    isRemoteVideoVisible: isRemoteVideoVisible,
                    canSwitchCamera: localMedia.canSwitchCamera,
                    onToggleMic: {
                        Task { await localMedia.toggleMicrophone() }
                    },
                    onToggleCamera: {
                        Task { await localMedia.toggleCamera() }
                    },
                    onEndCall: {
                        // Dismiss UI immediately for responsive feedback
                        onDismiss()
                        // Then disconnect in background
                        viewModel.disconnect()
                    },
                    onFlipCamera: {
                        Task { await localMedia.switchCamera() }
                    },
                    onToggleSpeaker: {
                        isRemoteAudioEnabled.toggle()
                        Task {
                            await viewModel.setRemoteAudioEnabled(isRemoteAudioEnabled)
                        }
                    },
                    onToggleRemoteVideo: {
                        isRemoteVideoVisible.toggle()
                    }
                )
            }

            // Local video PIP (top right) with network indicator
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        LocalVideoPIP(
                            track: localMedia.cameraTrack,
                            isCameraEnabled: localMedia.isCameraEnabled,
                            isMicEnabled: localMedia.isMicrophoneEnabled
                        )

                        // My network status indicator
                        MyNetworkStatusView(
                            connectionQuality: room.localParticipant.connectionQuality,
                            connectionType: networkMonitor.connectionType
                        )
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }

            // Incoming call banner
            if let activeCall = viewModel.incomingCall, activeCall.status == .ringing {
                VStack {
                    IncomingCallBanner(
                        caller: activeCall.handle,
                        onAccept: { acceptIncomingCallWithCellularCheck() },
                        onDecline: { viewModel.declineIncomingCall() }
                    )
                    .padding(.top, 60)
                    Spacer()
                }
            }

            // Reconnecting overlay
            if viewModel.isReconnecting {
                ReconnectingOverlay(timeRemaining: viewModel.reconnectTimeRemaining) {
                    onDismiss()
                    viewModel.disconnect()
                }
            }

            // Remote participant disconnected overlay
            if viewModel.remoteParticipantDisconnected {
                RemoteDisconnectedOverlay(timeRemaining: viewModel.remoteDisconnectTimeRemaining) {
                    onDismiss()
                    viewModel.disconnect()
                }
            }
        }
        .statusBar(hidden: true)
        .onTapGesture {
            // Close quality selector when tapping elsewhere
            if isQualitySelectorExpanded {
                withAnimation {
                    isQualitySelectorExpanded = false
                }
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if !isConnected {
                showNetworkAlert = true
                if viewModel.isConnected {
                    viewModel.disconnect()
                }
            }
        }
        .onChange(of: viewModel.isConnected) { _, isConnected in
            if isConnected {
                startCallTimer()
            } else {
                stopCallTimer()
            }
        }
        .alert("네트워크 연결 없음", isPresented: $showNetworkAlert) {
            Button("설정으로 이동") { openNetworkSettings() }
            Button("확인", role: .cancel) {}
        } message: {
            Text("인터넷 연결을 확인해주세요.")
        }
        .alert("셀룰러 데이터 사용", isPresented: $showCellularWarning) {
            Button("계속 진행") { proceedWithCall() }
            Button(pendingIncomingCall ? "거절" : "취소", role: .cancel) {
                if pendingIncomingCall {
                    viewModel.declineIncomingCall()
                }
                pendingCallRoomName = nil
                pendingIncomingCall = false
            }
        } message: {
            Text("현재 셀룰러 데이터를 사용 중입니다.\n영상통화는 많은 데이터를 소모할 수 있습니다.")
        }
        .onAppear {
            if viewModel.isConnected {
                startCallTimer()
            }
        }
        .onDisappear {
            stopCallTimer()
        }
    }

    // MARK: - Remote Connection Quality

    private var remoteConnectionQuality: ConnectionQuality {
        guard let firstParticipant = room.remoteParticipants.values.first else {
            return .unknown
        }
        return firstParticipant.connectionQuality
    }

    // MARK: - Current Resolution String

    private var currentResolutionString: String? {
        if selectedVideoQuality == .auto {
            // Return the actual resolution being used (default 720p for auto)
            return "720p"
        }
        return nil
    }

    // MARK: - Video Quality

    private func changeVideoQuality(to quality: VideoQualityPreset) async {
        guard let dimensions = quality.dimensions else {
            // Auto mode - use default 720p
            let captureOptions = CameraCaptureOptions(dimensions: .h720_169)
            _ = try? await room.localParticipant.setCamera(enabled: localMedia.isCameraEnabled, captureOptions: captureOptions)
            return
        }

        let captureOptions = CameraCaptureOptions(dimensions: dimensions)
        _ = try? await room.localParticipant.setCamera(enabled: localMedia.isCameraEnabled, captureOptions: captureOptions)
    }

    // MARK: - Remote Video Background

    @ViewBuilder
    private var remoteVideoBackground: some View {
        if !viewModel.isConnected {
            WaitingCallBackground(isConnected: viewModel.isConnected, isBusy: viewModel.isBusy)
        } else if let firstRemote = remoteVideoItems.first {
            if isRemoteVideoVisible {
                SwiftUIVideoView(firstRemote.track, layoutMode: .fill, mirrorMode: .off)
                    .background(Color.black)
            } else {
                RemoteVideoHiddenBackground()
            }
        } else if room.remoteParticipants.count > 0 {
            AudioOnlyCallBackground()
        } else {
            WaitingCallBackground(isConnected: viewModel.isConnected, isBusy: viewModel.isBusy)
        }
    }

    // MARK: - Helpers

    private var remoteVideoItems: [RemoteVideoItem] {
        let participants = room.remoteParticipants.values.sorted { lhs, rhs in
            let left = lhs.identity?.stringValue ?? lhs.sid?.stringValue ?? ""
            let right = rhs.identity?.stringValue ?? rhs.sid?.stringValue ?? ""
            return left < right
        }

        return participants.compactMap { participant in
            let videoTrack = participant.firstCameraVideoTrack ??
                            participant.videoTracks.compactMap { $0.track as? VideoTrack }.first

            guard let track = videoTrack else { return nil }

            let name = participant.name
                ?? participant.identity?.stringValue
                ?? participant.sid?.stringValue
                ?? "Guest"
            let id = participant.sid?.stringValue ?? participant.identity?.stringValue ?? UUID().uuidString
            return RemoteVideoItem(id: id, name: name, track: track)
        }
    }

    private var remoteParticipantName: String {
        if let firstParticipant = room.remoteParticipants.values.first {
            return firstParticipant.name
                ?? firstParticipant.identity?.stringValue
                ?? "Unknown"
        }
        return "통화 연결 중"
    }

    private func startCallTimer() {
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            Task { @MainActor in
                self.callDuration += 1
            }
        }
    }

    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }

    private func openNetworkSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func acceptIncomingCallWithCellularCheck() {
        if networkMonitor.connectionType == .cellular {
            pendingIncomingCall = true
            showCellularWarning = true
        } else {
            viewModel.acceptIncomingCall()
        }
    }

    private func proceedWithCall() {
        if pendingIncomingCall {
            viewModel.acceptIncomingCall()
        } else if let roomName = pendingCallRoomName {
            viewModel.startCall(roomName: roomName)
        } else {
            viewModel.startCall()
        }
        pendingCallRoomName = nil
        pendingIncomingCall = false
    }
}
#endif

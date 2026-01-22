import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct FullScreenCallView: View {
    @ObservedObject var viewModel: AppLiveKitViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var transcription = TranscriptionManager.shared
    @ObservedObject private var videoStatsLogger = VideoStatsLogger.shared
    // Singleton이지만 View의 생명주기 동안 관찰을 보장하기 위해 StateObject 사용 고려, 그러나 shared 인스턴스이므로 ObservedObject 유지하되 MainActor 보장
    @ObservedObject private var careAlertService = CareAlertService.shared

    // Shortcut accessors
    var room: Room { viewModel.room }
    var localMedia: LocalMedia { viewModel.localMedia }

    @State private var isRemoteAudioEnabled = true
    @State private var showNetworkAlert = false
    @State private var showCellularWarning = false
    @State private var pendingCallRoomName: String? = nil
    @State private var pendingIncomingCall: Bool = false
    @State private var callDuration: TimeInterval = 0
    @State private var callTimer: Timer? = nil
    @State private var selectedVideoQuality: VideoQualityPreset = .auto
    @State private var isQualitySelectorExpanded = false

    // PIP 확대 모드 상태
    @State private var isPIPExpanded: Bool = false
    @State private var showPIPMesh: Bool = false

    // AI 발화 상태 (TranscriptionManager에서 동기화)
    @State private var isAISpeaking: Bool = false

    let onDismiss: () -> Void

    init(viewModel: AppLiveKitViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    /// AI 음성통화 모드인지 확인
    private var isAudioOnlyMode: Bool {
        room.remoteParticipants.count > 0 && !isRemoteVideoActive
    }

    /// AI 대사 표시 텍스트
    private var aiDisplayText: String {
        if !transcription.currentAgentText.isEmpty {
            return transcription.currentAgentText
        }
        if let lastAgentMessage = transcription.messages.last(where: { $0.isAgent }) {
            return lastAgentMessage.text
        }
        return ""
    }

    var body: some View {
        ZStack {
            // Full screen remote video background
            remoteVideoBackground
                .ignoresSafeArea()

            // UI Overlay
            VStack(spacing: 0) {
                // 상단 영역
                ZStack(alignment: .top) {
                    // 중앙 - 이름 및 통화시간
                    CallTopBar(
                        callerName: isAudioOnlyMode ? "소담이" : remoteParticipantName,
                        callDuration: callDuration,
                        isConnected: viewModel.isConnected,
                        remoteConnectionQuality: remoteConnectionQuality
                    )

                    // 좌상단 - 듣는중/말하는중 상태 (AI 모드일 때만)
                    if isAudioOnlyMode {
                        HStack {
                            SpeakingStatusIndicator(status: isAISpeaking ? .talking : .listening)
                                .padding(.leading, 16)
                                .padding(.top, 8)
                            Spacer()
                        }
                    }

                    // 우상단 - 네트워크 상태 (확대 모드가 아닐 때만)
                    if !isPIPExpanded {
                        HStack {
                            Spacer()
                            // 내 네트워크 상태 표시
                            MyNetworkStatusView(
                                connectionQuality: effectiveLocalConnectionQuality,
                                connectionType: networkMonitor.connectionType
                            )
                            .padding(.trailing, 16)
                            .padding(.top, 8)
                        }
                    }
                }

                Spacer()

                // 영상통화일 때만 화질 선택기 표시
                if !isAudioOnlyMode && localMedia.isCameraEnabled {
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
                }

                // AI 대사 (음성통화 모드일 때)
                if isAudioOnlyMode && !aiDisplayText.isEmpty {
                    GeometryReader { geo in
                        AIChatBubbleView(
                            text: aiDisplayText,
                            isFinal: transcription.currentAgentText.isEmpty
                        )
                        .padding(.horizontal, geo.size.width * 0.04)
                        .padding(.bottom, geo.size.height * 0.02)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }

                bottomOverlay
            }
            .onTapGesture {
                // 다른 곳 탭하면 화질 선택기 닫기
                if isQualitySelectorExpanded {
                    withAnimation {
                        isQualitySelectorExpanded = false
                    }
                }
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

            // 확대된 PIP 배경 딤 효과
            if isPIPExpanded {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showPIPMesh = false
                            isPIPExpanded = false
                        }
                    }
            }

            // 단일 LocalVideoPIP 인스턴스 - 위치만 상태에 따라 변경
            GeometryReader { geometry in
                LocalVideoPIP(
                    track: localMedia.cameraTrack,
                    isCameraEnabled: localMedia.isCameraEnabled,
                    isMicEnabled: localMedia.isMicrophoneEnabled,
                    isCompact: !isPIPExpanded,
                    isExpanded: $isPIPExpanded,
                    showMesh: $showPIPMesh
                )
                .position(
                    x: isPIPExpanded
                        ? geometry.size.width / 2
                        : geometry.size.width - pipSize(screenWidth: geometry.size.width).width / 2 - 16,
                    y: isPIPExpanded
                        ? geometry.size.height / 2
                        : pipSize(screenWidth: geometry.size.width).height / 2 + 60
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPIPExpanded)
                
                // 해상도 인디케이터 - PIP 바로 아래 중앙
                if !isPIPExpanded && videoStatsLogger.resolution != "N/A" {
                    VideoResolutionIndicator(resolution: videoStatsLogger.resolution)
                        .position(
                            x: geometry.size.width - pipSize(screenWidth: geometry.size.width).width / 2 - 16,
                            y: pipSize(screenWidth: geometry.size.width).height + 60 + 20  // PIP 아래 20pt 간격
                        )
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
        .alert("현재 셀룰러 데이터 사용", isPresented: $showCellularWarning) {
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
        .alert("괜찮으세요?", isPresented: $careAlertService.showFallConfirmationAlert) {
            Button("괜찮아요", role: .cancel) {
                careAlertService.dismissDangerAlert()
            }
            Button("도움이 필요해요", role: .destructive) {
                careAlertService.requestHelp()
            }
        } message: {
            Text(careAlertService.alertMessage)
        }
        .onAppear {
            if viewModel.isConnected {
                startCallTimer()
            }
            // 초기값 동기화
            isAISpeaking = transcription.isAISpeaking
        }
        .onDisappear {
            stopCallTimer()
        }
        .onReceive(transcription.$isAISpeaking) { newValue in
            #if DEBUG
            print("🎬 [UI] onReceive isAISpeaking: \(newValue)")
            #endif
            isAISpeaking = newValue
        }
    }

    // MARK: - Remote Connection Quality

    private var remoteConnectionQuality: ConnectionQuality {
        guard let firstParticipant = room.remoteParticipants.values.first else {
            return .unknown
        }
        return firstParticipant.connectionQuality
    }
    
    /// 로컬 연결 품질 (LiveKit SDK 값이 unknown이면 추정값 사용)
    private var effectiveLocalConnectionQuality: ConnectionQuality {
        let liveKitQuality = room.localParticipant.connectionQuality
        
        // LiveKit SDK가 unknown이 아니면 그대로 사용
        if liveKitQuality != .unknown {
            return liveKitQuality
        }
        
        // unknown이면 실제 통계 기반 추정값 사용
        return videoStatsLogger.estimatedQuality
    }

    // MARK: - Video Quality

    private var currentResolutionString: String? {
        if selectedVideoQuality == .auto {
            return "720p"
        }
        return nil
    }

    private func changeVideoQuality(to quality: VideoQualityPreset) async {
        guard let dimensions = quality.dimensions else {
            // Auto mode - 기본 720p 사용
            let captureOptions = CameraCaptureOptions(dimensions: .h720_169)
            _ = try? await room.localParticipant.setCamera(enabled: localMedia.isCameraEnabled, captureOptions: captureOptions)
            return
        }

        let captureOptions = CameraCaptureOptions(dimensions: dimensions)
        _ = try? await room.localParticipant.setCamera(enabled: localMedia.isCameraEnabled, captureOptions: captureOptions)
    }

    // MARK: - Call Stage State

    /// 현재 통화 상태 계산
    private var currentCallState: CallStageState {
        if !viewModel.isConnected {
            return .connecting
        } else if let firstRemote = remoteVideoItems.first, isRemoteVideoActive {
            return .videoCall(track: firstRemote.track)
        } else if room.remoteParticipants.count > 0 {
            return .audioCall
        } else {
            return .waitingForParticipant
        }
    }

    /// 원격 참가자가 실제로 비디오를 송출하고 있는지 확인
    private var isRemoteVideoActive: Bool {
        guard !remoteVideoItems.isEmpty else { return false }
        if let publication = room.remoteParticipants.values.first?.videoTracks.first {
            return !publication.isMuted && publication.isSubscribed
        }
        return true
    }

    // MARK: - Background

    @ViewBuilder
    private var remoteVideoBackground: some View {
        switch currentCallState {
        case .connecting:
            Color.black
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                Text("연결 중...")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }

        case .waitingForParticipant:
            Color.black
            VStack(spacing: 20) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.5))
                    .symbolEffect(.pulse)
                Text("참가자 대기 중...")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                if viewModel.isBusy {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }

        case .videoCall(let track):
            SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: .off)

        case .audioCall:
            // 베이지색 배경 + 캐릭터 비디오
            GeometryReader { geometry in
                let videoWidth = geometry.size.width * 0.95
                let videoHeight = videoWidth / (896.0 / 1024.0)
                // iPad mini 6th gen 기준 비율 (234/1133 ≈ 0.206)
                // dock + 말풍선 여유 + safe area를 상대값으로 계산
                let bottomPadding = geometry.size.height * 0.206

                ZStack {
                    Color(hex: "E8E4DF")
                    VStack(spacing: 0) {
                        Spacer()
                        DualStateVideoPlayer(isAISpeaking: isAISpeaking)
                            .frame(width: videoWidth, height: videoHeight)
                            .clipped()
                    }
                    .padding(.bottom, bottomPadding)
                }
            }
        }
    }

    // MARK: - PIP Size

    /// PIP 크기 계산 (LocalVideoPIP과 동일 로직)
    private func pipSize(screenWidth: CGFloat) -> CGSize {
        let width = screenWidth / 3 * 0.8
        let height = width * 4 / 3
        return CGSize(width: width, height: height)
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

private extension FullScreenCallView {
    var bottomOverlay: some View {
        CallControlBar(
            isMicEnabled: localMedia.isMicrophoneEnabled,
            isSpeakerEnabled: isRemoteAudioEnabled,
            isCameraEnabled: localMedia.isCameraEnabled,
            onToggleMic: {
                Task { await localMedia.toggleMicrophone() }
            },
            onEndCall: {
                onDismiss()
                viewModel.disconnect()
            },
            onToggleSpeaker: {
                isRemoteAudioEnabled.toggle()
                Task {
                    await viewModel.setRemoteAudioEnabled(isRemoteAudioEnabled)
                }
            },
            onToggleCamera: {
                Task { await localMedia.toggleCamera() }
            }
        )
        .background(Color.black)
    }
}

// MARK: - Remote Video Item

struct RemoteVideoItem: Identifiable {
    let id: String
    let name: String
    let track: VideoTrack
}

// MARK: - Call Stage State

enum CallStageState: Equatable {
    case connecting
    case waitingForParticipant
    case videoCall(track: VideoTrack)
    case audioCall

    static func == (lhs: CallStageState, rhs: CallStageState) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting): return true
        case (.waitingForParticipant, .waitingForParticipant): return true
        case (.videoCall, .videoCall): return true
        case (.audioCall, .audioCall): return true
        default: return false
        }
    }
}
#endif

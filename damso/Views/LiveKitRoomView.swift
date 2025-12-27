import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct LiveKitRoomView: View {
    @ObservedObject var viewModel: LiveKitViewModel
    
    // ViewModel의 Room과 LocalMedia를 단축 접근자로 사용
    var room: Room { viewModel.room }
    var localMedia: LocalMedia { viewModel.localMedia }
    
    // CallStateStore 직접 참조 제거 (ViewModel이 관리함)
    // @StateObject private var callStore = CallStateStore.shared
    @State private var isRemoteVideoVisible = true
    @State private var isRemoteAudioEnabled = true

    init(viewModel: LiveKitViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 16) {
                    VideoStageView(
                        remoteVideos: remoteVideoItems,
                        localTrack: localMedia.cameraTrack,
                        isConnected: viewModel.isConnected,
                        isRemoteVideoVisible: isRemoteVideoVisible,
                        isCameraEnabled: localMedia.isCameraEnabled,
                        remoteParticipantsCount: room.remoteParticipants.count
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .background(Color.black.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(spacing: 12) {
                        statusPanel
                        callToAction

                        if viewModel.isConnected {
                            // LocalMedia를 관찰하는 별도 뷰 사용
                            ControlPanelView(
                                localMedia: localMedia,
                                viewModel: viewModel,
                                isRemoteVideoVisible: $isRemoteVideoVisible,
                                isRemoteAudioEnabled: $isRemoteAudioEnabled
                            )
                        }
                    }
                }
                .padding()

                // CallStateStore 대신 ViewModel의 incomingCall 사용
                if let activeCall = viewModel.incomingCall {
                    IncomingCallBanner(
                        caller: activeCall.handle,
                        onAccept: {
                            viewModel.acceptIncomingCall()
                        },
                        onDecline: {
                            viewModel.declineIncomingCall()
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
            }
            else {
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
}


// MARK: - Control Panel Component
// LocalMedia의 상태 변화를 감지하기 위해 별도 뷰로 분리하고 @ObservedObject 적용
struct ControlPanelView: View {
    @ObservedObject var localMedia: LocalMedia
    @ObservedObject var viewModel: LiveKitViewModel
    @Binding var isRemoteVideoVisible: Bool
    @Binding var isRemoteAudioEnabled: Bool
    
    var body: some View {
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
}
#endif

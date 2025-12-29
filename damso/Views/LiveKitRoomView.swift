import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct LiveKitRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppLiveKitViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @State private var showNetworkAlert = false
    @State private var showCellularWarning = false
    @State private var pendingCallRoomName: String? = nil
    @State private var pendingIncomingCall: Bool = false
    @State private var showFullScreenCall = false

    /// 통화 종료 후 자동으로 화면을 닫을지 여부 (fullScreenCover로 표시된 경우)
    var dismissOnCallEnd: Bool = false

    init(viewModel: AppLiveKitViewModel, dismissOnCallEnd: Bool = false) {
        self.viewModel = viewModel
        self.dismissOnCallEnd = dismissOnCallEnd
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Main content - call start screen
                VStack(spacing: 24) {
                    Spacer()

                    // App icon / Logo area
                    VStack(spacing: 16) {
                        Image(systemName: "video.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)

                        Text("영상통화")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    // Status
                    statusPanel

                    // Call button
                    callToAction

                    Spacer()
                        .frame(height: 40)
                }
                .padding()

                // Incoming call banner (when not in call)
                if let activeCall = viewModel.incomingCall, activeCall.status == .ringing {
                    IncomingCallBanner(
                        caller: activeCall.handle,
                        onAccept: { acceptIncomingCallWithCellularCheck() },
                        onDecline: { viewModel.declineIncomingCall() }
                    )
                    .padding(.top, 12)
                }
            }
            .navigationTitle("LiveKit")
        }
        .fullScreenCover(isPresented: $showFullScreenCall) {
            FullScreenCallView(viewModel: viewModel) {
                showFullScreenCall = false
            }
        }
        .onChange(of: viewModel.isConnected) { _, isConnected in
            if isConnected {
                showFullScreenCall = true
            } else {
                showFullScreenCall = false
                // 통화 종료 후 화면 닫기 (fullScreenCover로 표시된 경우)
                if dismissOnCallEnd {
                    dismiss()
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
            if !networkMonitor.isConnected {
                showNetworkAlert = true
            }
        }
    }

    // MARK: - Private Methods

    private func openNetworkSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func startCallWithCellularCheck(roomName: String? = nil) {
        if networkMonitor.connectionType == .cellular {
            pendingCallRoomName = roomName
            pendingIncomingCall = false
            showCellularWarning = true
        } else {
            if let roomName {
                viewModel.startCall(roomName: roomName)
            } else {
                viewModel.startCall()
            }
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

    // MARK: - Views

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

            if let mediaError = viewModel.localMedia.error {
                Text(mediaError.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var callToAction: some View {
        Button {
            startCallWithCellularCheck()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "video.fill")
                    .font(.title2)
                Text("영상통화 시작하기")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isBusy)
        .padding(.horizontal)
    }
}
#endif

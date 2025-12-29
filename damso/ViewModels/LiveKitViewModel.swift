import Foundation
import Combine
import SwiftUI
#if canImport(LiveKit)
import LiveKit

@MainActor
final class LiveKitViewModel<
    LKS: LiveKitServiceProtocol,
    AS: AuthServiceProtocol,
    CSS: CallStateStoreProtocol,
    CM: CallManagerProtocol
>: ObservableObject {
    // Services (DIP: Protocol 타입으로 주입)
    private let liveKitService: LKS
    private let authService: AS
    private let callStateStore: CSS
    private let callManager: CM

    // CallKit State
    @Published var incomingCall: CallInfo?

    // UI State
    @Published var isRequestingToken = false
    @Published var activeRoomName = "demo-room"

    // Proxy Properties
    var room: Room { liveKitService.room }
    var localMedia: LocalMedia { liveKitService.localMedia }

    // Service 상태 구독
    private var cancellables = Set<AnyCancellable>()

    init(
        liveKitService: LKS,
        authService: AS,
        callStateStore: CSS,
        callManager: CM
    ) {
        self.liveKitService = liveKitService
        self.authService = authService
        self.callStateStore = callStateStore
        self.callManager = callManager

        // Service의 상태 변화를 그대로 View에 알림
        liveKitService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        callStateStore.activeCallPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] call in
                self?.incomingCall = call
                // .answered 상태면 자동으로 통화 시작
                if let call, call.status == .answered {
                    self?.handleAutoAccept(call: call)
                }
            }
            .store(in: &cancellables)
    }

    /// 알림에서 수락 시 자동으로 통화 시작 (WiFi-only iPad)
    private func handleAutoAccept(call: CallInfo) {
        callStateStore.clearCall()
        if let roomName = call.roomName {
            startCall(roomName: roomName)
        } else {
            startCall()
        }
    }
    
    // Computed Properties for UI
    var isConnected: Bool {
        liveKitService.connectionState == .connected
    }
    
    var isBusy: Bool {
        isRequestingToken || 
        liveKitService.connectionState == .connecting || 
        liveKitService.connectionState == .reconnecting || 
        liveKitService.connectionState == .disconnecting
    }
    
    var statusText: String {
        if isRequestingToken { return "Requesting token..." }
        
        switch liveKitService.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .reconnecting:
            if let mode = liveKitService.reconnectMode {
                return "Reconnecting (\(mode == .quick ? "quick" : "full"))..."
            }
            return "Reconnecting..."
        case .disconnecting: return "Disconnecting..."
        case .disconnected: return "Disconnected"
        }
    }
    
    var statusColor: Color {
        switch liveKitService.connectionState {
        case .connected: return .green
        case .reconnecting: return .orange
        default: return .secondary
        }
    }

    // 재연결 상태
    var isReconnecting: Bool {
        liveKitService.isReconnecting
    }

    var reconnectTimeRemaining: Int {
        liveKitService.reconnectTimeRemaining
    }

    // 상대방 연결 끊김 상태
    var remoteParticipantDisconnected: Bool {
        liveKitService.remoteParticipantDisconnected
    }

    var remoteDisconnectTimeRemaining: Int {
        liveKitService.remoteDisconnectTimeRemaining
    }

    @Published var errorMessage: String? = nil

    // Actions
    func startCall(roomName: String? = nil) {
        if let roomName {
            activeRoomName = roomName
        }
        
        Task {
            guard !isBusy else { return }
            
            isRequestingToken = true
            defer { isRequestingToken = false }
            
            do {
                let token = try await authService.fetchLiveKitToken(roomName: activeRoomName)
                try await liveKitService.connect(token: token)
                self.errorMessage = nil
            } catch let error as TokenError {
                 print("[ViewModel] Token Error: \(error.localizedDescription)")
                 self.errorMessage = "인증 실패: \(error.localizedDescription)"
            } catch {
                print("[ViewModel] Start call failed: \(error.localizedDescription)")
                self.errorMessage = "연결 실패: \(error.localizedDescription)"
            }
        }
    }
    
    func disconnect() {
        Task {
            await liveKitService.disconnect()
        }
    }
    
    func setRemoteAudioEnabled(_ enabled: Bool) async {
        await liveKitService.setRemoteAudioEnabled(enabled)
    }
    
    // MARK: - CallKit Actions
    func acceptIncomingCall() {
        guard let call = incomingCall else { return }

        if resolveCallCapability() == .callKit {
            // CallKit: answerCall → setAnswered → handleAutoAccept에서 startCall 호출됨
            callManager.answerCall(uuid: call.id)
        } else {
            // WiFi-only iPad: CallKit 없이 직접 처리
            callStateStore.clearCall()
            if let roomName = call.roomName {
                startCall(roomName: roomName)
            } else {
                startCall()
            }
        }
    }

    func declineIncomingCall() {
        guard let call = incomingCall else { return }

        if resolveCallCapability() == .callKit {
            callManager.endCall(uuid: call.id)
        } else {
            // WiFi-only iPad: CallKit 없이 직접 처리
            callStateStore.clearCall()
            // 서버에 거절 알림
            notifyDeclineToServer(callId: call.callId)
        }
    }

    private func notifyDeclineToServer(callId: String?) {
        guard let callId else { return }
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/calls/end") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["callId": callId])

        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }
}
#endif


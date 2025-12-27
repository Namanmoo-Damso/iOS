import Foundation
import Combine
import SwiftUI
#if canImport(LiveKit)
import LiveKit

@MainActor
final class LiveKitViewModel: ObservableObject {
    // Services
    let liveKitService = LiveKitService()
    let authService = AuthService()
    
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
    
    init() {
        // Service의 상태 변화를 그대로 View에 알림
        liveKitService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        CallStateStore.shared.$activeCall
            .receive(on: RunLoop.main)
            .assign(to: \.incomingCall, on: self)
            .store(in: &cancellables)
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
        CallManager.shared.answerCall(uuid: call.id)
        
        // 통화 수락 후 LiveKit 방 입장
        if let roomName = call.roomName {
            startCall(roomName: roomName)
        } else {
            startCall()
        }
    }
    
    func declineIncomingCall() {
        guard let call = incomingCall else { return }
        CallManager.shared.endCall(uuid: call.id)
    }
}
#endif


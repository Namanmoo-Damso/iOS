//
//  CallViewModel.swift
//  damso
//
//  통화 화면 ViewModel (FullScreenCallView용)
//

import Foundation
import Combine

@MainActor
final class CallViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = true
    @Published var isCameraOn: Bool = true
    @Published var duration: TimeInterval = 0
    @Published var connectionState: CallConnectionState = .connecting
    
    // MARK: - Dependencies
    
    private let liveKitService: LiveKitService
    private nonisolated(unsafe) var timer: Timer?
    
    // MARK: - Initialization
    
    init(liveKitService: LiveKitService = DependencyContainer.shared.liveKitService) {
        self.liveKitService = liveKitService
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func toggleMute() {
        isMuted.toggle()
        // TODO: LiveKitService의 마이크 제어 메서드 연동
        // liveKitService.setMicrophoneEnabled(!isMuted)
    }
    
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        // TODO: 스피커 토글 로직 (CallManager 등 연동 필요)
    }
    
    func toggleCamera() {
        isCameraOn.toggle()
        // TODO: LiveKitService의 카메라 제어 메서드 연동
        // liveKitService.setCameraEnabled(isCameraOn)
    }
    
    func endCall() {
        Task {
            await liveKitService.disconnect()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // LiveKit 상태 바인딩
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.duration += 1
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

enum CallConnectionState {
    case connecting
    case connected
    case failed
    case disconnected
}

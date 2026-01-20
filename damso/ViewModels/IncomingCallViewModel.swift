//
//  IncomingCallViewModel.swift
//  damso
//
//  수신 전화 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class IncomingCallViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var callerName: String = "소담이"
    @Published var callerImage: String?
    
    // MARK: - Dependencies
    
    private let callManager: CallManager
    
    // MARK: - Initialization
    
    init(callManager: CallManager = .shared) {
        self.callManager = callManager
        // Caller Info 로드 로직
    }
    
    // MARK: - Public Methods
    
    func acceptCall() {
        // 통화 수락
    }
    
    func declineCall() {
        // TODO: CallManager.endCall(uuid:) 사용 필요
        // callManager.endCall(uuid: callUUID)
    }
}

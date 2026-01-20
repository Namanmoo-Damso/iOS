//
//  InviteCompletionViewModel.swift
//  damso
//
//  초대 완료 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class InviteCompletionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var wardName: String = ""
    
    // MARK: - Initialization
    
    init() {
        loadWardInfo()
    }
    
    // MARK: - Public Methods
    
    func loadWardInfo() {
        if let ward = AppState.shared.currentUser?.wardInfo {
            // 어르신 이름이 별도로 없으면 닉네임 사용
            // 현재 구조상 GuardInfo에 nickname이 없음, UserInfo에서 가져와야 함
            // API 구조 개선 필요, 우선 임시 처리
            wardName = "어르신"
        }
    }
    
    func complete() {
        // 확인 버튼 처리
    }
}

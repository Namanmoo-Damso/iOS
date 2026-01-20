//
//  WardProfileViewModel.swift
//  damso
//
//  어르신 프로필 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class WardProfileViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var nickname: String = ""
    @Published var phoneNumber: String = ""
    @Published var profileImageUrl: String?
    @Published var guardianName: String?
    @Published var guardianPhone: String?
    
    // MARK: - Dependencies
    
    private let userService: UserService
    
    // MARK: - Initialization
    
    init(userService: UserService = .shared) {
        self.userService = userService
        loadProfile()
    }
    
    // MARK: - Public Methods
    
    func loadProfile() {
        if let user = AppState.shared.currentUser {
            nickname = user.nickname ?? "어르신"
            profileImageUrl = user.profileImageUrl
            
            if let wardInfo = user.wardInfo {
                phoneNumber = wardInfo.phoneNumber
                if let guardian = wardInfo.linkedGuardian {
                    guardianName = guardian.nickname
                    // Note: GuardianSummary에 phoneNumber 필드 없음
                }
            }
        }
    }
}

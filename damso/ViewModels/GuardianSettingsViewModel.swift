//
//  GuardianSettingsViewModel.swift
//  damso
//
//  보호자 설정 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class GuardianSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var showLogoutAlert: Bool = false
    @Published var showWithdrawAlert: Bool = false
    @Published var showUnlinkAlert: Bool = false
    @Published var isLoggingOut: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var profileImageUrl: String?
    @Published var linkedWards: [WardRegistrationInfo] = []
    @Published var selectedWardForUnlink: WardRegistrationInfo?
    
    // MARK: - Dependencies
    
    private let userService: UserService
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userService: UserService, authService: AuthService) {
        self.userService = userService
        self.authService = authService
        loadUserInfo()
    }
    
    // MARK: - Public Methods
    
    func loadUserInfo() {
        if let user = AppState.shared.currentUser {
            userName = user.nickname ?? "보호자"
            userEmail = user.email ?? ""
            profileImageUrl = user.profileImageUrl
            linkedWards = user.guardianInfo?.wards ?? []
        }
    }
    
    func unlinkWard(_ ward: WardRegistrationInfo) {
        selectedWardForUnlink = ward
        showUnlinkAlert = true
    }
    
    func confirmUnlinkWard() async {
        guard let ward = selectedWardForUnlink,
              let wardId = ward.linkedWardId else { return }
        
        do {
            // TODO: API 연동
            // try await userService.unlinkWard(wardId: wardId)
            linkedWards.removeAll { $0.id == ward.id }
            selectedWardForUnlink = nil
        } catch {
            // 오류 처리
        }
    }
    
    func logout() {
        isLoggingOut = true
        Task {
            await authService.logout()
            isLoggingOut = false
        }
    }
    
    func confirmWithdraw() {
        Task {
            do {
                try await AppState.shared.withdraw()
            } catch {
                // 탈퇴 실패 시 에러 처리
            }
        }
    }
}

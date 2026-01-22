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
    private let authRepository: AuthRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userService: UserService, authRepository: AuthRepositoryProtocol = AuthRepository.shared) {
        self.userService = userService
        self.authRepository = authRepository
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
              ward.linkedWardId != nil else { return }

        // TODO: API 연동
        // try await userService.unlinkWard(wardId: ward.linkedWardId!)
        linkedWards.removeAll { $0.id == ward.id }
        selectedWardForUnlink = nil
    }
    
    func logout() {
        isLoggingOut = true
        Task {
            do {
                try await authRepository.logout()
            } catch {
                // 로그아웃 실패 시 무시 (로컬 토큰은 이미 삭제됨)
            }
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

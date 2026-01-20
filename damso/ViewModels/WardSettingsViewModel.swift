//
//  WardSettingsViewModel.swift
//  damso
//
//  어르신 설정 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class WardSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var showLogoutAlert: Bool = false
    @Published var showWithdrawAlert: Bool = false
    @Published var isLoggingOut: Bool = false
    @Published var locationTrackingEnabled: Bool = true
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var profileImageUrl: String?
    @Published var linkedGuardianName: String?
    
    // MARK: - Dependencies
    
    private let authRepository: AuthRepositoryProtocol
    private let userService: UserService
    private let wardSettingsService: WardSettingsService
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        authRepository: AuthRepositoryProtocol = AuthRepository.shared,
        userService: UserService,
        wardSettingsService: WardSettingsService,
        locationService: LocationService
    ) {
        self.authRepository = authRepository
        self.userService = userService
        self.wardSettingsService = wardSettingsService
        self.locationService = locationService
        loadUserInfo()
    }
    
    // MARK: - Public Methods
    
    func loadUserInfo() {
        Task {
            if let user = AppState.shared.currentUser {
                userName = user.nickname ?? "어르신"
                userEmail = user.email ?? ""
                profileImageUrl = user.profileImageUrl
                linkedGuardianName = user.wardInfo?.linkedGuardian?.nickname
            }
        }
    }
    
    func toggleLocationTracking(_ enabled: Bool) {
        locationTrackingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "locationTrackingEnabled")
        
        if enabled {
            locationService.startTracking()
        } else {
            locationService.stopTracking()
        }
    }
    
    func logout() {
        isLoggingOut = true
        Task {
            do {
                try await authRepository.logout()
            } catch {
                // 로그아웃 실패해도 로컬 토큰은 정리
            }
            TokenManager.shared.clearTokens()
            isLoggingOut = false
        }
    }
    
    func confirmWithdraw() {
        Task {
            do {
                try await authRepository.withdraw()
            } catch {
                // 탈퇴 실패 시 에러 처리 가능
            }
            TokenManager.shared.clearTokens()
        }
    }
}

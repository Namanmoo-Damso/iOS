//
//  AppCoordinator.swift
//  damso
//
//  앱 네비게이션 상태를 중앙 관리하는 Coordinator
//  ContentViewModel에서 분리되어 화면 전환 책임만 담당
//

import Foundation
import Combine
import SwiftUI

/// 앱 네비게이션 상태 (ContentView에서 이동)
enum AppNavigationState: Equatable {
    case splash                       // 로딩 중
    case serverSelection              // 서버 선택
    case userTypeSelection            // 사용자 타입 선택
    case login(UserType)              // 카카오 로그인 (선택된 타입 포함)
    case guardianRegistration         // 보호자 등록 폼
    case inviteCompletion(InviteInfo) // 초대 완료 화면
    case permissionOnboarding(UserType) // 권한 요청 온보딩
    case main                         // 메인 화면
}

/// Coordinator 델리게이트 프로토콜
/// ViewModel이 Coordinator에 화면 전환을 요청할 때 사용
protocol AppCoordinatorDelegate: AnyObject {
    func navigateToMain()
    func navigateToUserTypeSelection()
    func navigateToLogin(userType: UserType, autoTrigger: Bool)
    func navigateToGuardianRegistration()
    func navigateToInviteCompletion(info: InviteInfo)
    func navigateToPermissionOnboarding(userType: UserType)
    func navigateToMainOrPermission(userType: UserType)
}

/// 앱 전역 네비게이션을 관리하는 Coordinator
/// SwiftUI에서 StateObject로 소유되어 화면 전환 상태를 중앙 관리
@MainActor
final class AppCoordinator: ObservableObject, AppCoordinatorDelegate {
    
    static let shared = AppCoordinator()
    
    // MARK: - Published State
    
    @Published var navigationState: AppNavigationState = .splash
    @Published var shouldAutoTriggerLogin: Bool = false
    
    // MARK: - Dependencies
    
    private let deeplinkManager: DeeplinkManager
    
    private init(deeplinkManager: DeeplinkManager = .shared) {
        self.deeplinkManager = deeplinkManager
    }
    
    // MARK: - AppCoordinatorDelegate
    
    func navigateToMain() {
        navigationState = .main
    }
    
    func navigateToUserTypeSelection() {
        navigationState = .userTypeSelection
    }
    
    func navigateToLogin(userType: UserType, autoTrigger: Bool) {
        shouldAutoTriggerLogin = autoTrigger
        navigationState = .login(userType)
    }
    
    func navigateToGuardianRegistration() {
        navigationState = .guardianRegistration
    }
    
    func navigateToInviteCompletion(info: InviteInfo) {
        navigationState = .inviteCompletion(info)
    }
    
    func navigateToPermissionOnboarding(userType: UserType) {
        navigationState = .permissionOnboarding(userType)
    }
    
    func navigateToMainOrPermission(userType: UserType) {
        if UserDefaults.standard.permissionOnboardingCompleted {
            navigationState = .main
        } else {
            navigationState = .permissionOnboarding(userType)
        }
    }
    
    // MARK: - Public Navigation Methods
    
    /// 초기 상태 확인 후 적절한 화면으로 이동
    func handleInitialState() {
        UserDefaults.standard.clearPendingLoginUserType()
        
        if deeplinkManager.hasUnhandledDeeplink {
            Log.ui.i("Universal Link 감지됨 - 서버 선택 후 처리 예정")
        }
        
        navigationState = .serverSelection
    }
    
    /// 서버 선택 완료 후 인증 상태에 따른 화면 분기
    func handleServerSelected() {
        Task {
            Log.ui.i("서버 선택 완료 (서버: \(AppConfig.serverDomain)) - 인증 상태 확인 중...")
            await AppState.shared.checkAuthStatus()
            
            if AppState.shared.isAuthenticated {
                Log.ui.i("자동 로그인 성공 - 메인으로 이동")
                navigationState = .main
            } else {
                Log.ui.i("인증되지 않음 - 사용자 타입 선택으로 이동")
                if TokenManager.shared.hasTokens {
                    Log.ui.w("기존 토큰 발견 - 삭제")
                    TokenManager.shared.clearTokens()
                }
                
                // 딥링크가 있으면 해당 타입으로 바로 로그인
                if deeplinkManager.hasUnhandledDeeplink, let userType = deeplinkManager.requestedUserType {
                    shouldAutoTriggerLogin = deeplinkManager.shouldAutoTriggerLogin
                    deeplinkManager.clearDeeplink()
                    navigationState = .login(userType)
                } else {
                    navigationState = .userTypeSelection
                }
            }
        }
    }
    
    /// 인증 상태 변경에 따른 화면 전환
    func handleAuthStatusChange(isAuthenticated: Bool) {
        if isAuthenticated {
            switch navigationState {
            case .userTypeSelection, .login, .guardianRegistration:
                if let userType = AppState.shared.currentUser?.userType {
                    navigateToMainOrPermission(userType: userType)
                } else {
                    navigationState = .main
                }
            default: break
            }
        } else {
            if case .main = navigationState {
                navigationState = .userTypeSelection
            } else if case .permissionOnboarding = navigationState {
                navigationState = .userTypeSelection
            }
        }
    }
    
    /// 딥링크 처리
    func handleDeeplink() {
        guard let userType = deeplinkManager.requestedUserType else { return }
        if case .serverSelection = navigationState { return }
        
        let isInMainFlow: Bool = {
            if case .main = navigationState { return true }
            if case .permissionOnboarding = navigationState { return true }
            return false
        }()
        
        if !isInMainFlow {
            shouldAutoTriggerLogin = deeplinkManager.shouldAutoTriggerLogin
            navigationState = .login(userType)
        }
        deeplinkManager.clearDeeplink()
    }
}

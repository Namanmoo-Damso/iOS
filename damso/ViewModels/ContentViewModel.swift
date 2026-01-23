//
//  ContentViewModel.swift
//  damso
//
//  앱 메인 진입 및 전역 상태 관리 ViewModel
//

import Foundation
import Combine
import SwiftUI
import KakaoSDKAuth

@MainActor
final class ContentViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI State)
    
    @Published var navigationState: AppNavigationState = .splash
    @Published var selectedUserType: UserType?
    @Published var kakaoUserInfo: KakaoUserInfo?
    @Published var registeredWardEmail: String?
    
    // Alerts
    @Published var showMatchFailureAlert = false
    @Published var matchFailureMessage: String?
    @Published var showUserTypeMismatchAlert = false
    @Published var userTypeMismatchMessage: String?
    @Published var showLoginErrorAlert = false
    @Published var loginErrorMessage: String?
    @Published var showSessionExpiredAlert = false
    
    // Call UI
    @Published var showGlobalCallView = false
    @Published var showCharacterPreview = false
    @Published var shouldAutoTriggerLogin = false
    
    // MARK: - Dependencies
    
    // Repositories (Interfaces)
    private let authRepository: AuthRepositoryProtocol
    private let userRepository: UserRepositoryProtocol // user fetch에 사용
    
    // Managers & Stores
    // CallStateStore, DeeplinkManager는 View에서 Environment/Observed로 관리되기도 하지만,
    // 로직 처리를 위해 주입받거나 싱글톤 참조 (여기서는 기존 싱글톤 패턴 유지하되 추후 리팩터링)
    let deeplinkManager: DeeplinkManager
    let callStateStore: CallStateStore
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        authRepository: AuthRepositoryProtocol = AuthRepository.shared,
        userRepository: UserRepositoryProtocol = UserRepository.shared,
        deeplinkManager: DeeplinkManager = .shared,
        callStateStore: CallStateStore = .shared
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.deeplinkManager = deeplinkManager
        self.callStateStore = callStateStore
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // AppState 인증 상태 감지 (기존 AppState는 점진적으로 제거 또는 동기화)
        AppState.shared.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.handleAuthStatusChange(isAuthenticated: isAuthenticated)
            }
            .store(in: &cancellables)
            
        AppState.shared.$showSessionExpiredAlert
            .assign(to: \.showSessionExpiredAlert, on: self)
            .store(in: &cancellables)
            
        // Deeplink 감지
        deeplinkManager.$hasUnhandledDeeplink
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasLink in
                if hasLink { self?.handleDeeplink() }
            }
            .store(in: &cancellables)
            
        // CallStateStore 감지 (통화 수락 시 화면 이동)
        callStateStore.$activeCall
            .receive(on: DispatchQueue.main)
            .map { $0?.status }
            .removeDuplicates()
            .sink { [weak self] status in
                if status == .answered {
                    self?.showGlobalCallView = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    
    func checkInitialState() async {
        Log.ui.i("checkInitialState() 시작")
        UserDefaults.standard.clearPendingLoginUserType()
        
        if deeplinkManager.hasUnhandledDeeplink {
            Log.ui.i("Universal Link 감지됨 - 서버 선택 후 처리 예정")
        }

        // 서버 자동 설정 (StartView 건너뛰기)
        AppConfig.serverDomain = "2.sodam.store"
        AppConfig.selectedDeveloperName = "임익화"
        AppConfig.usesApiPrefix = false
        Log.ui.i("서버 자동 설정 완료 (서버: \(AppConfig.serverDomain)) - 인증 상태 확인 중...")

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

            if deeplinkManager.hasUnhandledDeeplink, let userType = deeplinkManager.requestedUserType {
                selectedUserType = userType
                shouldAutoTriggerLogin = deeplinkManager.shouldAutoTriggerLogin
                deeplinkManager.clearDeeplink()
                navigationState = .login(userType)
            } else {
                navigationState = .userTypeSelection
            }
        }
    }
    
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
                
                if deeplinkManager.hasUnhandledDeeplink, let userType = deeplinkManager.requestedUserType {
                    selectedUserType = userType
                    shouldAutoTriggerLogin = deeplinkManager.shouldAutoTriggerLogin
                    deeplinkManager.clearDeeplink()
                    navigationState = .login(userType)
                } else {
                    navigationState = .userTypeSelection
                }
            }
        }
    }
    
    func handleLoginSuccess(userType: UserType, loginResult: KakaoLoginResult) {
        Log.auth.i("handleLoginSuccess 호출됨 - userType: \(userType)")
        UserDefaults.standard.clearPendingLoginUserType()
        
        Task {
            do {
                kakaoUserInfo = loginResult.userInfo
                
                // AuthRepository를 통한 로그인 (Moya 기반)
                let authResponse = try await authRepository.loginWithKakao(
                    accessToken: loginResult.accessToken,
                    kakaoUserInfo: loginResult.userInfo,
                    userType: userType
                )

                
                if authResponse.isNewUserFlag {
                    if userType == .ward {
                        handleWardLoginResponse(authResponse)
                    } else {
                        handleNewUserResponse(authResponse: authResponse, userType: userType)
                    }
                    return
                }
                
                guard let user = authResponse.user else {
                    matchFailureMessage = "사용자 정보를 가져올 수 없습니다."
                    showMatchFailureAlert = true
                    return
                }
                
                if let serverUserType = user.userType, serverUserType != userType {
                    let selectedTypeName = userType == .guardian ? Strings.UserType.guardian : Strings.UserType.ward
                    let serverTypeName = serverUserType == .guardian ? Strings.UserType.guardian : Strings.UserType.ward
                    userTypeMismatchMessage = "\(selectedTypeName)(으)로 로그인하려 했지만,\n이미 \(serverTypeName)(으)로 등록된 계정입니다."
                    showUserTypeMismatchAlert = true
                    return
                }
                
                if userType == .ward {
                    handleWardLoginResponse(authResponse)
                } else {
                    // Guardian Logic
                    let userWithGuardianInfo = UserMeResponse(
                        id: user.id,
                        identity: user.identity,
                        kakaoId: user.kakaoId,
                        email: user.email,
                        nickname: user.nickname,
                        profileImageUrl: user.profileImageUrl,
                        userType: user.userType ?? .guardian,
                        createdAt: user.createdAt,
                        guardianInfo: authResponse.guardianInfo ?? user.guardianInfo,
                        wardInfo: user.wardInfo
                    )
                    AppState.shared.didLogin(user: userWithGuardianInfo)
                    navigateToMainOrPermission(userType: .guardian)
                }
            } catch {
                handleLoginError(error)
            }
        }
    }
    
    func navigateToMainOrPermission(userType: UserType) {
        if UserDefaults.standard.permissionOnboardingCompleted {
            navigationState = .main
        } else {
            navigationState = .permissionOnboarding(userType)
        }
    }
    
    func acceptIncomingCall() {
        guard let call = callStateStore.activeCall else { return }
        RingtonePlayer.shared.stopRinging()
        
        let isForeground = UIApplication.shared.applicationState == .active
        if isForeground || resolveCallCapability() != .callKit {
            callStateStore.clearCall()
            showGlobalCallView = true
            
            // ViewModel 내에서 CallViewModel 제어는 복잡하므로 View에서 onAppear로 처리 (기존 로직 유지)
        } else {
            CallManager.shared.answerCall(uuid: call.id)
        }
    }
    
    func declineIncomingCall() {
        guard let call = callStateStore.activeCall else { return }
        RingtonePlayer.shared.stopRinging()
        
        let isForeground = UIApplication.shared.applicationState == .active
        if isForeground || resolveCallCapability() != .callKit {
            callStateStore.clearCall()
        } else {
            CallManager.shared.endCall(uuid: call.id)
        }
    }
    
    func onRegistrationComplete(wardEmail: String, user: UserMeResponse) {
        let guardianName = kakaoUserInfo?.nickname ?? user.nickname ?? Strings.UserType.guardian
        let inviteInfo = InviteInfo(guardianId: user.id, guardianName: guardianName, wardEmail: wardEmail)
        navigationState = .inviteCompletion(inviteInfo)
    }
    
    // MARK: - Private Helper Methods
    
    private func handleAuthStatusChange(isAuthenticated: Bool) {
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
    
    private func handleDeeplink() {
        guard let userType = deeplinkManager.requestedUserType else { return }
        if case .serverSelection = navigationState { return }
        
        let isInMainFlow: Bool = {
            if case .main = navigationState { return true }
            if case .permissionOnboarding = navigationState { return true }
            return false
        }()
        
        if !isInMainFlow {
            selectedUserType = userType
            shouldAutoTriggerLogin = deeplinkManager.shouldAutoTriggerLogin
            navigationState = .login(userType)
        }
        deeplinkManager.clearDeeplink()
    }
    
    private func handleWardLoginResponse(_ authResponse: AuthResponse) {
        guard let user = authResponse.user else {
            matchFailureMessage = "사용자 정보를 가져올 수 없습니다."
            showMatchFailureAlert = true
            return
        }
        
        if let matchStatus = authResponse.matchStatus {
             switch matchStatus {
             case .notMatched:
                 matchFailureMessage = authResponse.matchMessage
                 showMatchFailureAlert = true
                 return
             default: break
             }
        }
        
        AppState.shared.didLogin(user: user)
        navigateToMainOrPermission(userType: .ward)
    }
    
    private func handleNewUserResponse(authResponse: AuthResponse, userType: UserType) {
        if let kakaoProfile = authResponse.kakaoProfile {
             let kakaoId = Int64(kakaoProfile.kakaoId) ?? 0
             let profileUrl = kakaoProfile.profileImageUrl.flatMap { URL(string: $0) }
             kakaoUserInfo = KakaoUserInfo(
                 id: kakaoId,
                 nickname: kakaoProfile.nickname,
                 email: kakaoProfile.email,
                 profileImageUrl: profileUrl
             )
        }
        
        if userType == .guardian {
            navigationState = .guardianRegistration
        } else {
            matchFailureMessage = authResponse.matchMessage ?? "등록된 보호자 정보가 없습니다."
            showMatchFailureAlert = true
        }
    }
    
    private func handleLoginError(_ error: Error) {
        // 에러 메시지 추출 로직 (기존 View 로직과 동일)
        loginErrorMessage = error.localizedDescription
        showLoginErrorAlert = true
    }
}

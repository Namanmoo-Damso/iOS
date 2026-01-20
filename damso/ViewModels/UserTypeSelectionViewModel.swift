//
//  UserTypeSelectionViewModel.swift
//  damso
//
//  유저 타입 선택 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class UserTypeSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedType: UserType?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 개발용 상태
    @Published var isDevLoggingIn: Bool = false
    @Published var showDevGuardianRegistration: Bool = false
    @Published var devAuthResponse: AuthResponse? // 개발용 가입 시 필요
    
    // Events
    let loginSuccessSubject = PassthroughSubject<(UserType, KakaoLoginResult), Never>()
    
    // MARK: - Dependencies
    
    // AuthRepository, UserReposioty가 추후 통합될 예정이나 일단 KakaoAuthService는 별도로 둠
    private let kakaoAuthService: KakaoAuthService
    private let authRepository: AuthRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        kakaoAuthService: KakaoAuthService = .shared,
        authRepository: AuthRepositoryProtocol = AuthRepository.shared
    ) {
        self.kakaoAuthService = kakaoAuthService
        self.authRepository = authRepository
        
        // 카카오 서비스 상태 바인딩
        kakaoAuthService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func selectType(_ type: UserType) {
        selectedType = type
    }
    
    func performKakaoLogin() {
        guard let type = selectedType else { return }
        
        Task {
            do {
                let result = try await kakaoAuthService.login()
                loginSuccessSubject.send((type, result))
            } catch {
                errorMessage = Strings.Auth.loginFailed
            }
        }
    }
    
    func performDevLogin(appState: AppState) {
        isDevLoggingIn = true
        errorMessage = nil
        
        Task {
            do {
                let wardEmail = AppConfig.selectedDevWardEmail
                let authResponse = try await authRepository.devLogin(wardEmail: wardEmail)
                
                // TODO: 토큰 저장 로직 추가 필요 (AuthRepository에서 처리하거나 여기서 처리)
                if let accessToken = authResponse.accessToken,
                   let refreshToken = authResponse.refreshToken {
                    TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
                }
                
                if authResponse.isNewUserFlag {
                    devAuthResponse = authResponse
                    showDevGuardianRegistration = true
                } else {
                    if let user = authResponse.user {
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
                        appState.didLogin(user: userWithGuardianInfo)
                    }
                }
            } catch {
                errorMessage = "개발용 로그인 실패: \(error.localizedDescription)"
            }
            isDevLoggingIn = false
        }
    }
}

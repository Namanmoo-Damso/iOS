//
//  LoginViewModel.swift
//  damso
//
//  카카오 로그인 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isLoggedIn: Bool = false
    
    // MARK: - Dependencies
    
    private let authRepository: AuthRepositoryProtocol
    // TODO: 추후 KakaoAuthService도 Repository 패턴으로 추상화 필요
    private let kakaoAuthService: KakaoAuthService
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        authRepository: AuthRepositoryProtocol = AuthRepository.shared,
        kakaoAuthService: KakaoAuthService = .shared
    ) {
        self.authRepository = authRepository
        self.kakaoAuthService = kakaoAuthService
        
        // KakaoAuthService 상태 바인딩
        kakaoAuthService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
            
        kakaoAuthService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loginWithKakao(completion: @escaping (KakaoLoginResult) -> Void) {
        Task {
            do {
                let result = try await kakaoAuthService.login()
                // 서버 로그인 연동은 UserTypeSelectionView에서 진행되거나, 
                // 여기서 AccessToken을 이용해 자동 로그인 시도 가능
                // 현재 구조상 View에서 userType 선택 화면으로 넘어가는 로직이 있으므로 completion 호출
                completion(result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func serverLogin(accessToken: String) {
        isLoading = true
        Task {
            do {
                let response = try await authRepository.login(accessToken: accessToken, userType: nil)
                if let token = response.accessToken {
                    TokenManager.shared.saveTokens(access: token, refresh: response.refreshToken ?? "")
                    isLoggedIn = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

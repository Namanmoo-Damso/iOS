//
//  GuardianRegistrationViewModel.swift
//  damso
//
//  보호자 회원가입 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class GuardianRegistrationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var wardEmail: String = ""
    @Published var wardPhoneNumber: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isCompleted: Bool = false
    
    // MARK: - Dependencies
    
    private let authRepository: AuthRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(authRepository: AuthRepositoryProtocol = AuthRepository.shared) {
        self.authRepository = authRepository
    }
    
    // MARK: - Public Methods
    
    func submitRegistration() async {
        guard validateInput() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // AuthRepository의 registerGuardian 사용
            // Note: tempToken이 필요하지만 현재 로직에서는 사용하지 않음
            // 실제 구현 시 tempToken 처리 필요
            let response = try await authRepository.registerGuardian(
                tempToken: "", // TODO: tempToken 처리
                wardEmail: wardEmail,
                wardPhoneNumber: wardPhoneNumber
            )
            
            // 토큰 저장 및 상태 업데이트
            if let accessToken = response.accessToken,
               let refreshToken = response.refreshToken {
                TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
            }
            
            isCompleted = true
        } catch {
            errorMessage = "회원가입 중 오류가 발생했습니다."
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func validateInput() -> Bool {
        if wardEmail.isEmpty || !wardEmail.contains("@") {
            errorMessage = "올바른 어르신 이메일을 입력해주세요."
            return false
        }
        if wardPhoneNumber.isEmpty {
            errorMessage = "어르신 전화번호를 입력해주세요."
            return false
        }
        return true
    }
}

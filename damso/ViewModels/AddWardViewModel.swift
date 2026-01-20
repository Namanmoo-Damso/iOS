//
//  AddWardViewModel.swift
//  damso
//
//  어르신 추가 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class AddWardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var wardEmail: String = ""
    @Published var wardPhoneNumber: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false
    
    // MARK: - Dependencies
    
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(authService: AuthService = .shared) {
        self.authService = authService
    }
    
    // MARK: - Public Methods
    
    func registerWard() async {
        guard !wardEmail.isEmpty else {
            errorMessage = "이메일을 입력해주세요."
            return
        }
        
        guard !wardPhoneNumber.isEmpty else {
            errorMessage = "전화번호를 입력해주세요."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // TODO: API 연동
            // try await authService.registerWard(email: wardEmail, phoneNumber: wardPhoneNumber)
            
            // 모의 지연
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            showSuccess = true
        } catch {
            errorMessage = "어르신 등록에 실패했습니다. 다시 시도해주세요."
        }
        
        isLoading = false
    }
}

//
//  GuardianProfileViewModel.swift
//  damso
//
//  보호자 프로필 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class GuardianProfileViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var nickname: String = ""
    @Published var phoneNumber: String = ""
    @Published var profileImageUrl: String?
    @Published var isEditing: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let userService: UserService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userService: UserService = .shared) {
        self.userService = userService
        loadProfile()
    }
    
    // MARK: - Public Methods
    
    func loadProfile() {
        if let user = AppState.shared.currentUser {
            nickname = user.nickname ?? ""
            profileImageUrl = user.profileImageUrl
            // 전화번호는 현재 User 모델에 없거나 다를 수 있음
        }
    }
    
    func updateProfile() async {
        isLoading = true
        errorMessage = nil
        
        // TODO: UserService에 프로필 업데이트 API 추가 후 연동
        // do {
        //     let updatedUser = try await userService.updateProfile(nickname: nickname, phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber)
        //     // AppState에 업데이트된 사용자 정보 반영 필요
        //     isEditing = false
        // } catch {
        //     errorMessage = "프로필 수정에 실패했습니다."
        // }
        
        // 임시로 편집 모드 종료
        isEditing = false
        isLoading = false
    }
    
    func toggleEditMode() {
        isEditing.toggle()
        if !isEditing {
            loadProfile() // 취소 시 원복
        }
    }
}

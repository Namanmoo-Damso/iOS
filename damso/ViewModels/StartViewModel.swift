//
//  StartViewModel.swift
//  damso
//
//  시작 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class StartViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var showLogin: Bool = false
    @Published var showRegistration: Bool = false
    
    // MARK: - Public Methods
    
    func navigateToLogin() {
        showLogin = true
    }
    
    func navigateToRegistration() {
        showRegistration = true
    }
}

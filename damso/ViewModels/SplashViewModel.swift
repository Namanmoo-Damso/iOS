//
//  SplashViewModel.swift
//  damso
//
//  스플래시 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class SplashViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isReady: Bool = false
    @Published var versionText: String = ""
    
    // MARK: - Initialization
    
    init() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            versionText = "v\(version)"
        }
    }
    
    // MARK: - Public Methods
    
    func initializeApp() async {
        // 앱 초기화 로직 (설정 로드, 버전 체크 등)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isReady = true
    }
}

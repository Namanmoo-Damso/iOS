//
//  ContentView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation
import SwiftUI
import Combine
import LiveKit

/// 앱 네비게이션 상태
enum AppNavigationState: Equatable {
    case splash            // 로딩 중
    case serverSelection   // 서버 선택
    case userTypeSelection // 사용자 타입 선택
    case login(UserType)   // 카카오 로그인 (선택된 타입 포함)
    case main              // 메인 화면
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var viewModel = DependencyContainer.shared.makeLiveKitViewModel()
    @StateObject private var kakaoAuth = KakaoAuthService.shared

    @State private var navigationState: AppNavigationState = .splash
    @State private var selectedUserType: UserType?

    var body: some View {
        Group {
            switch navigationState {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .serverSelection:
                StartView(isServerSelected: Binding(
                    get: { false },
                    set: { if $0 { navigationState = .userTypeSelection } }
                ))
                .transition(.move(edge: .leading))

            case .userTypeSelection:
                UserTypeSelectionView { type in
                    selectedUserType = type
                    navigationState = .login(type)
                }
                .transition(.move(edge: .trailing))

            case .login(let userType):
                KakaoLoginView(isLoggedIn: Binding(
                    get: { false },
                    set: { _ in handleLoginSuccess(userType: userType) }
                ))
                .transition(.move(edge: .trailing))

            case .main:
                LiveKitRoomView(viewModel: viewModel)
                    .transition(.move(edge: .trailing))
                    .environmentObject(appState)
            }
        }
        .animation(.default, value: navigationState)
        .task {
            await checkInitialState()
        }
        .alert("세션 만료", isPresented: $appState.showSessionExpiredAlert) {
            Button("확인") {
                navigationState = .userTypeSelection
            }
        } message: {
            Text("로그인 세션이 만료되었습니다.\n다시 로그인해 주세요.")
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated && navigationState == .main {
                // 로그아웃됨
                navigationState = .userTypeSelection
            }
        }
    }

    // MARK: - Private Methods

    private func checkInitialState() async {
        // 앱 시작 시 인증 상태 확인
        await appState.checkAuthStatus()

        if appState.isAuthenticated {
            navigationState = .main
        } else {
            // 서버가 선택되었는지 확인 (UserDefaults 등에서)
            // 현재는 간단히 서버 선택 화면으로 이동
            navigationState = .serverSelection
        }
    }

    private func handleLoginSuccess(userType: UserType) {
        // 카카오 로그인 성공 후 서버 인증 수행
        Task {
            do {
                guard let kakaoResult = try? await kakaoAuth.login() else {
                    return
                }

                // 서버에 카카오 토큰으로 JWT 발급 요청
                let authService = AuthService()
                let authResponse = try await authService.loginWithKakao(
                    kakaoAccessToken: kakaoResult.accessToken,
                    userType: userType
                )

                // AppState 업데이트
                appState.didLogin(user: authResponse.user)
                navigationState = .main
            } catch {
                print("[ContentView] Login failed: \(error)")
                // 에러 처리 - 다시 타입 선택으로
            }
        }
    }
}

#Preview {
    ContentView()
}

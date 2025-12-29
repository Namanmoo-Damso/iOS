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

/// 초대 정보
struct InviteInfo: Equatable {
    let guardianId: String
    let guardianName: String
    let wardEmail: String
}

/// 앱 네비게이션 상태
enum AppNavigationState: Equatable {
    case splash                       // 로딩 중
    case serverSelection              // 서버 선택
    case userTypeSelection            // 사용자 타입 선택
    case login(UserType)              // 카카오 로그인 (선택된 타입 포함)
    case guardianRegistration         // 보호자 등록 폼
    case inviteCompletion(InviteInfo) // 초대 완료 화면
    case main                         // 메인 화면
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var viewModel = DependencyContainer.shared.makeLiveKitViewModel()
    @StateObject private var kakaoAuth = KakaoAuthService.shared

    @State private var navigationState: AppNavigationState = .splash
    @State private var selectedUserType: UserType?
    @State private var kakaoUserInfo: KakaoUserInfo?
    @State private var registeredWardEmail: String?
    @State private var showMatchFailureAlert = false
    @State private var matchFailureMessage: String?

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

            case .guardianRegistration:
                if let userInfo = kakaoUserInfo {
                    GuardianRegistrationView(
                        kakaoUserInfo: userInfo,
                        onRegistrationComplete: { wardEmail in
                            handleGuardianRegistrationComplete(wardEmail: wardEmail)
                        },
                        onBack: {
                            navigationState = .userTypeSelection
                        }
                    )
                    .transition(.move(edge: .trailing))
                }

            case .inviteCompletion(let inviteInfo):
                InviteCompletionView(
                    guardianId: inviteInfo.guardianId,
                    guardianName: inviteInfo.guardianName,
                    wardEmail: inviteInfo.wardEmail,
                    onComplete: {
                        navigationState = .main
                    }
                )
                .transition(.move(edge: .trailing))

            case .main:
                mainView
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
        .alert("보호자 정보 없음", isPresented: $showMatchFailureAlert) {
            Button("확인") {
                navigationState = .userTypeSelection
            }
        } message: {
            Text(matchFailureMessage ?? "등록된 보호자 정보가 없습니다.\n보호자에게 먼저 앱에서 회원가입을 요청해주세요.")
        }
    }

    // MARK: - Computed Views

    @ViewBuilder
    private var mainView: some View {
        if appState.currentUser?.userType == .ward {
            WardHomeView()
        } else {
            // 보호자는 기존 LiveKitRoomView 사용 (추후 GuardianHomeView로 변경)
            LiveKitRoomView(viewModel: viewModel)
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

                // 카카오 사용자 정보 저장
                kakaoUserInfo = kakaoResult.userInfo

                // 서버에 카카오 토큰으로 JWT 발급 요청
                let authService = AuthService()
                let authResponse = try await authService.loginWithKakao(
                    kakaoAccessToken: kakaoResult.accessToken,
                    userType: userType
                )

                // 어르신인 경우 매칭 상태 확인
                if userType == .ward {
                    handleWardLoginResponse(authResponse)
                } else {
                    // 보호자 로그인 처리
                    appState.didLogin(user: authResponse.user)
                    navigationState = .guardianRegistration
                }
            } catch {
                print("[ContentView] Login failed: \(error)")
                // 에러 처리 - 다시 타입 선택으로
            }
        }
    }

    private func handleWardLoginResponse(_ authResponse: AuthResponse) {
        // 매칭 상태 확인
        guard let matchStatus = authResponse.matchStatus else {
            // matchStatus가 없으면 매칭 성공으로 간주
            appState.didLogin(user: authResponse.user)
            navigationState = .main
            return
        }

        switch matchStatus {
        case .matched:
            // 매칭 성공 - 메인으로 이동
            appState.didLogin(user: authResponse.user)
            navigationState = .main

        case .notMatched:
            // 매칭 실패 - 토큰 저장하지 않고 알림 표시
            matchFailureMessage = authResponse.matchMessage
            showMatchFailureAlert = true

        case .pending:
            // 대기 중 - 일단 메인으로 이동 (추후 처리)
            appState.didLogin(user: authResponse.user)
            navigationState = .main
        }
    }

    private func handleGuardianRegistrationComplete(wardEmail: String) {
        // 보호자 등록 완료 후 초대 화면으로
        guard let user = appState.currentUser,
              let userInfo = kakaoUserInfo else {
            navigationState = .main
            return
        }

        let inviteInfo = InviteInfo(
            guardianId: user.id,
            guardianName: userInfo.nickname ?? user.nickname,
            wardEmail: wardEmail
        )
        navigationState = .inviteCompletion(inviteInfo)
    }
}

#Preview {
    ContentView()
}

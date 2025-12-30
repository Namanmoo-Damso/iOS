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
import KakaoSDKAuth
import os

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
    @EnvironmentObject var deeplinkManager: DeeplinkManager

    @State private var navigationState: AppNavigationState = .splash
    @State private var selectedUserType: UserType?
    @State private var kakaoUserInfo: KakaoUserInfo?
    @State private var registeredWardEmail: String?
    @State private var showMatchFailureAlert = false
    @State private var matchFailureMessage: String?
    @State private var showUserTypeMismatchAlert = false
    @State private var userTypeMismatchMessage: String?

    var body: some View {
        Group {
            switch navigationState {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .serverSelection:
                StartView(isServerSelected: Binding(
                    get: { false },
                    set: { if $0 { handleServerSelected() } }
                ))
                .transition(.move(edge: .leading))

            case .userTypeSelection:
                UserTypeSelectionView { type, loginResult in
                    // 카카오 로그인 성공 - 바로 서버 인증 진행
                    selectedUserType = type
                    Log.ui.i("카카오 로그인 성공 - userType: \(type)")
                    handleLoginSuccess(userType: type, loginResult: loginResult)
                }
                .transition(.move(edge: .trailing))

            case .login(let userType):
                KakaoLoginView { loginResult in
                    handleLoginSuccess(userType: userType, loginResult: loginResult)
                }
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
                    .environmentObject(appState)
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
        .alert(Strings.Auth.sessionExpiredTitle, isPresented: $appState.showSessionExpiredAlert) {
            Button(Strings.Common.confirm) {
                navigationState = .userTypeSelection
            }
        } message: {
            Text(Strings.Auth.sessionExpiredMessage)
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated && navigationState == .main {
                // 로그아웃됨
                navigationState = .userTypeSelection
            }
        }
        .onChange(of: deeplinkManager.hasUnhandledDeeplink) { _, hasDeeplink in
            if hasDeeplink, let userType = deeplinkManager.requestedUserType {
                Log.ui.i("Deeplink 수신 - userType: \(userType)")
                // 이미 로그인된 상태가 아닐 때만 처리
                if navigationState != .main {
                    selectedUserType = userType
                    navigationState = .login(userType)
                }
                deeplinkManager.clearDeeplink()
            }
        }
        .alert(Strings.Matching.noGuardianTitle, isPresented: $showMatchFailureAlert) {
            Button(Strings.Common.confirm) {
                navigationState = .userTypeSelection
            }
        } message: {
            Text(matchFailureMessage ?? Strings.Matching.noGuardianMessage)
        }
        .alert(Strings.Matching.userTypeMismatchTitle, isPresented: $showUserTypeMismatchAlert) {
            Button(Strings.Common.confirm) {
                navigationState = .userTypeSelection
            }
        } message: {
            Text(userTypeMismatchMessage ?? Strings.Matching.userTypeMismatchMessage)
        }
    }

    // MARK: - Computed Views

    @ViewBuilder
    private var mainView: some View {
        if appState.currentUser?.userType == .ward {
            WardTabView()
        } else {
            // 보호자 탭 뷰
            GuardianTabView()
        }
    }

    // MARK: - Private Methods

    private func checkInitialState() async {
        Log.ui.i("checkInitialState() 시작")

        // 대기 중인 로그인 상태 클리어
        UserDefaults.standard.clearPendingLoginUserType()

        // 항상 서버 선택 화면(StartView)부터 시작
        Log.ui.i("서버 선택 화면으로 이동 (항상 StartView부터 시작)")
        navigationState = .serverSelection
    }

    private func handleLoginSuccess(userType: UserType, loginResult: KakaoLoginResult) {
        Log.auth.i("handleLoginSuccess 호출됨 - userType: \(userType)")

        // 대기 중인 로그인 상태 클리어
        UserDefaults.standard.clearPendingLoginUserType()

        // 카카오 로그인 성공 후 서버 인증 수행
        Task {
            do {
                Log.auth.i("카카오 사용자 정보 저장: \(loginResult.userInfo.nickname ?? "unknown")")
                // 카카오 사용자 정보 저장
                kakaoUserInfo = loginResult.userInfo

                Log.auth.i("서버 JWT 발급 요청 시작")
                // 서버에 카카오 토큰으로 JWT 발급 요청 (카카오 사용자 정보 포함)
                let authService = AuthService()
                let authResponse = try await authService.loginWithKakao(
                    kakaoAccessToken: loginResult.accessToken,
                    kakaoUserInfo: loginResult.userInfo,
                    userType: userType
                )
                Log.auth.i("서버 응답 수신 - isNewUser: \(authResponse.isNewUserFlag)")

                // 신규 사용자 처리
                if authResponse.isNewUserFlag {
                    handleNewUserResponse(authResponse: authResponse, userType: userType)
                    return
                }

                // 기존 사용자 처리
                guard let user = authResponse.user else {
                    Log.auth.e("응답에 user 정보 없음 - 로그인 실패")
                    matchFailureMessage = "사용자 정보를 가져올 수 없습니다.\n다시 로그인해주세요."
                    showMatchFailureAlert = true
                    return
                }

                // 선택한 userType과 서버의 userType 일치 확인
                if let serverUserType = user.userType, serverUserType != userType {
                    Log.auth.w("userType 불일치 - 선택: \(userType), 서버: \(serverUserType)")
                    let selectedTypeName = userType == .guardian ? Strings.UserType.guardian : Strings.UserType.ward
                    let serverTypeName = serverUserType == .guardian ? Strings.UserType.guardian : Strings.UserType.ward
                    userTypeMismatchMessage = "\(selectedTypeName)(으)로 로그인하려 했지만,\n이미 \(serverTypeName)(으)로 등록된 계정입니다.\n\n\(serverTypeName) 버튼을 눌러 다시 로그인해주세요."
                    showUserTypeMismatchAlert = true
                    return
                }

                if userType == .ward {
                    Log.auth.i("어르신 로그인 - 매칭 상태 확인")
                    handleWardLoginResponse(authResponse)
                } else {
                    // 보호자 로그인 처리 - 기존 사용자는 바로 메인으로
                    Log.auth.i("보호자 로그인 (기존 사용자) - 메인으로 이동")
                    appState.didLogin(user: user)
                    navigationState = .main
                }
            } catch {
                Log.auth.e("Login failed: \(error)")
                // 에러 처리 - 다시 타입 선택으로
            }
        }
    }

    private func handleNewUserResponse(authResponse: AuthResponse, userType: UserType) {
        Log.auth.i("신규 사용자 처리 - userType: \(userType)")

        // 카카오 프로필 정보로 kakaoUserInfo 업데이트
        if let kakaoProfile = authResponse.kakaoProfile {
            let kakaoId = Int64(kakaoProfile.kakaoId) ?? 0
            let profileUrl = kakaoProfile.profileImageUrl.flatMap { URL(string: $0) }
            kakaoUserInfo = KakaoUserInfo(
                id: kakaoId,
                nickname: kakaoProfile.nickname,
                email: kakaoProfile.email,
                profileImageUrl: profileUrl
            )
            Log.auth.i("카카오 프로필 정보 업데이트: \(kakaoProfile.nickname ?? "unknown")")
        }

        if userType == .guardian {
            // 보호자 신규 가입 - 등록 화면으로
            Log.auth.i("보호자 신규 가입 - 등록 화면으로 이동")
            navigationState = .guardianRegistration
        } else {
            // 어르신 신규 가입 - 보호자 정보 없음 알림
            Log.auth.w("어르신 신규 가입 - 보호자 정보 없음")
            matchFailureMessage = authResponse.matchMessage ?? "등록된 보호자 정보가 없습니다.\n보호자에게 먼저 앱에서 회원가입을 요청해주세요."
            showMatchFailureAlert = true
        }
    }

    private func handleWardLoginResponse(_ authResponse: AuthResponse) {
        Log.auth.i("handleWardLoginResponse 호출됨")

        // user 정보 확인 - 없으면 에러
        guard let user = authResponse.user else {
            Log.auth.e("어르신 응답에 user 정보 없음")
            matchFailureMessage = "사용자 정보를 가져올 수 없습니다.\n다시 로그인해주세요."
            showMatchFailureAlert = true
            return
        }

        // 매칭 상태 확인
        guard let matchStatus = authResponse.matchStatus else {
            // matchStatus가 없으면 매칭 성공으로 간주
            Log.auth.i("matchStatus 없음 - 매칭 성공으로 간주, 메인으로 이동")
            appState.didLogin(user: user)
            navigationState = .main
            return
        }

        Log.auth.i("matchStatus: \(matchStatus)")
        switch matchStatus {
        case .matched:
            // 매칭 성공 - 메인으로 이동
            Log.auth.i("매칭 성공 - 메인으로 이동")
            appState.didLogin(user: user)
            navigationState = .main

        case .notMatched:
            // 매칭 실패 - 토큰 저장하지 않고 알림 표시
            Log.auth.w("매칭 실패 - 알림 표시")
            matchFailureMessage = authResponse.matchMessage
            showMatchFailureAlert = true

        case .pending:
            // 대기 중 - 일단 메인으로 이동 (추후 처리)
            Log.auth.i("매칭 대기 중 - 메인으로 이동")
            appState.didLogin(user: user)
            navigationState = .main
        }
    }

    private func handleServerSelected() {
        Task {
            Log.ui.i("서버 선택 완료 - 인증 상태 확인 중...")
            await appState.checkAuthStatus()

            if appState.isAuthenticated {
                Log.ui.i("자동 로그인 성공 - 메인으로 이동")
                navigationState = .main
            } else {
                Log.ui.i("인증되지 않음 - 사용자 타입 선택으로 이동")
                navigationState = .userTypeSelection
            }
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
            guardianName: userInfo.nickname ?? user.nickname ?? Strings.UserType.guardian,
            wardEmail: wardEmail
        )
        navigationState = .inviteCompletion(inviteInfo)
    }

}

#Preview {
    ContentView()
        .environmentObject(DeeplinkManager.shared)
}

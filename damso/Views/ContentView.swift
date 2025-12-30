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
    @State private var tempToken: String?

    // 앱 재시작 시 카카오 로그인 복원을 위한 키
    private let pendingLoginUserTypeKey = "pendingLoginUserType"

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
                        tempToken: tempToken,
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
            WardTabView()
        } else {
            // 보호자 탭 뷰
            GuardianTabView()
        }
    }

    // MARK: - Private Methods

    private func checkInitialState() async {
        Log.ui.i("checkInitialState() 시작")

        // 저장된 tempToken 복원 (앱 재시작 시)
        if let savedTempToken = UserDefaults.standard.string(forKey: "tempToken") {
            self.tempToken = savedTempToken
            Log.ui.i("저장된 tempToken 복원됨")
        }

        // 대기 중인 로그인 상태 클리어
        UserDefaults.standard.removeObject(forKey: pendingLoginUserTypeKey)

        // 항상 서버 선택 화면(StartView)부터 시작
        Log.ui.i("서버 선택 화면으로 이동 (항상 StartView부터 시작)")
        navigationState = .serverSelection
    }

    private func handleLoginSuccess(userType: UserType, loginResult: KakaoLoginResult) {
        Log.auth.i("handleLoginSuccess 호출됨 - userType: \(userType)")

        // 대기 중인 로그인 상태 클리어
        UserDefaults.standard.removeObject(forKey: pendingLoginUserTypeKey)

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
                if userType == .ward {
                    Log.auth.i("어르신 로그인 - 매칭 상태 확인")
                    handleWardLoginResponse(authResponse)
                } else {
                    // 보호자 로그인 처리 - 기존 사용자는 바로 메인으로
                    Log.auth.i("보호자 로그인 (기존 사용자) - 메인으로 이동")
                    if let user = authResponse.user {
                        appState.didLogin(user: user)
                        navigationState = .main
                    } else {
                        // user 정보가 없으면 에러 - 진행 불가
                        Log.auth.e("응답에 user 정보 없음 - 로그인 실패")
                        matchFailureMessage = "사용자 정보를 가져올 수 없습니다.\n다시 로그인해주세요."
                        showMatchFailureAlert = true
                    }
                }
            } catch {
                Log.auth.e("Login failed: \(error)")
                // 에러 처리 - 다시 타입 선택으로
            }
        }
    }

    private func handleNewUserResponse(authResponse: AuthResponse, userType: UserType) {
        Log.auth.i("신규 사용자 처리 - userType: \(userType)")

        // tempToken 저장 (신규 사용자 등록 시 필요)
        if let token = authResponse.tempToken {
            self.tempToken = token
            UserDefaults.standard.set(token, forKey: "tempToken")
            Log.auth.i("tempToken 저장됨")
        }

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

    private func handleGuardianRegistrationComplete(wardEmail: String) {
        // tempToken 정리
        self.tempToken = nil
        UserDefaults.standard.removeObject(forKey: "tempToken")

        // 보호자 등록 완료 후 초대 화면으로
        guard let user = appState.currentUser,
              let userInfo = kakaoUserInfo else {
            navigationState = .main
            return
        }

        let inviteInfo = InviteInfo(
            guardianId: user.id,
            guardianName: userInfo.nickname ?? user.nickname ?? "보호자",
            wardEmail: wardEmail
        )
        navigationState = .inviteCompletion(inviteInfo)
    }

}

#Preview {
    ContentView()
        .environmentObject(DeeplinkManager.shared)
}

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
    case permissionOnboarding(UserType) // 권한 요청 온보딩
    case main                         // 메인 화면
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var callViewModel = DependencyContainer.shared.makeLiveKitViewModel()
    @StateObject private var kakaoAuth = KakaoAuthService.shared
    @ObservedObject private var callStateStore = CallStateStore.shared
    @EnvironmentObject var deeplinkManager: DeeplinkManager

    @State private var navigationState: AppNavigationState = .splash
    @State private var selectedUserType: UserType?
    @State private var kakaoUserInfo: KakaoUserInfo?
    @State private var registeredWardEmail: String?
    @State private var showMatchFailureAlert = false
    @State private var matchFailureMessage: String?
    @State private var showUserTypeMismatchAlert = false
    @State private var userTypeMismatchMessage: String?
    @State private var showLoginErrorAlert = false
    @State private var loginErrorMessage: String?
    @State private var showGlobalCallView = false
    @State private var showCharacterPreview = false
    @State private var shouldAutoTriggerLogin = false  // Universal Link 자동 로그인

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
                .environmentObject(appState)
                .transition(.move(edge: .trailing))

            case .login(let userType):
                KakaoLoginView(
                    onLoginSuccess: { loginResult in
                        handleLoginSuccess(userType: userType, loginResult: loginResult)
                    },
                    autoTriggerLogin: shouldAutoTriggerLogin
                )
                .transition(.move(edge: .trailing))
                .onDisappear {
                    // 로그인 화면에서 벗어나면 자동 트리거 플래그 리셋
                    shouldAutoTriggerLogin = false
                }

            case .guardianRegistration:
                if let userInfo = kakaoUserInfo {
                    GuardianRegistrationView(
                        kakaoUserInfo: userInfo,
                        onRegistrationComplete: { wardEmail, user in
                            handleGuardianRegistrationComplete(wardEmail: wardEmail, user: user)
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
                        navigateToMainOrPermission(userType: .guardian)
                    }
                )
                .transition(.move(edge: .trailing))

            case .permissionOnboarding(let userType):
                PermissionOnboardingView(userType: userType) {
                    navigationState = .main
                }
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
            if isAuthenticated {
                // 로그인됨 - 인증 관련 화면에서 메인으로 이동
                switch navigationState {
                case .userTypeSelection, .login, .guardianRegistration:
                    Log.ui.i("인증 완료 감지 - 메인으로 이동")
                    if let userType = appState.currentUser?.userType {
                        navigateToMainOrPermission(userType: userType)
                    } else {
                        navigationState = .main
                    }
                default:
                    break
                }
            } else {
                // 로그아웃됨 - 메인 또는 권한 온보딩 상태에서만 처리
                if case .main = navigationState {
                    navigationState = .userTypeSelection
                } else if case .permissionOnboarding = navigationState {
                    navigationState = .userTypeSelection
                }
            }
        }
        .onChange(of: deeplinkManager.hasUnhandledDeeplink) { _, hasDeeplink in
            if hasDeeplink, let userType = deeplinkManager.requestedUserType {
                Log.ui.i("Deeplink 수신 - userType: \(userType), shouldAutoTrigger: \(deeplinkManager.shouldAutoTriggerLogin)")

                // 서버 선택 화면에서는 대기 (handleServerSelected에서 처리)
                if case .serverSelection = navigationState {
                    Log.ui.i("서버 선택 중 - Deeplink 대기")
                    return
                }

                // 이미 로그인된 상태가 아닐 때만 처리
                let isInMainFlow: Bool
                if case .main = navigationState { isInMainFlow = true }
                else if case .permissionOnboarding = navigationState { isInMainFlow = true }
                else { isInMainFlow = false }

                if !isInMainFlow {
                    selectedUserType = userType
                    // Universal Link에서 진입 시 자동 로그인 플래그 저장
                    shouldAutoTriggerLogin = deeplinkManager.shouldAutoTriggerLogin
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
        .alert(Strings.Auth.loginFailedTitle, isPresented: $showLoginErrorAlert) {
            Button(Strings.Common.confirm) {
                navigationState = .userTypeSelection
            }
        } message: {
            Text(loginErrorMessage ?? Strings.Auth.loginFailed)
        }
        // 전역 수신 통화 화면 (앱 실행 중 Foreground에서 전체화면 표시)
        .fullScreenCover(isPresented: Binding(
            get: { callStateStore.activeCall?.status == .ringing && !showGlobalCallView },
            set: { _ in }
        )) {
            if let call = callStateStore.activeCall {
                FullScreenIncomingCallView(
                    callerName: call.handle,
                    callerImageName: nil,
                    hasVideo: call.hasVideo,
                    onAccept: { acceptIncomingCall() },
                    onDecline: { declineIncomingCall() }
                )
            }
        }
        // 전역 통화 화면 (CallKit 수락 시 자동 표시)
        .fullScreenCover(isPresented: $showGlobalCallView) {
            FullScreenCallView(viewModel: callViewModel) {
                showGlobalCallView = false
            }
            .onAppear {
                // roomName을 먼저 저장 (clearCall 호출 전에)
                let roomName = callStateStore.activeCall?.roomName

                // CallKit 상태 정리 - 화면 표시 후 호출
                // (LiveKitViewModel에서 너무 일찍 호출하면 .onChange가 상태를 놓침)
                callStateStore.clearCall()

                // 통화 화면 표시 시 자동으로 통화 시작
                if !callViewModel.isConnected && !callViewModel.isBusy {
                    if let roomName = roomName {
                        callViewModel.startCall(roomName: roomName)
                    } else {
                        callViewModel.startCall()
                    }
                }
            }
        }
        // CallKit에서 수락 시 자동으로 통화 화면 표시
        .onChange(of: callStateStore.activeCall?.status) { _, newStatus in
            if newStatus == .answered {
                showGlobalCallView = true
            }
        }
        // 시뮬레이터용 임시 버튼 (DEBUG 빌드만)
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            if navigationState == .serverSelection && !showGlobalCallView && !showCharacterPreview {
                VStack(spacing: 12) {
                    // UI 테스트 버튼
                    Button(action: {
                        showCharacterPreview = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.on.rectangle")
                            Text("UI Test")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .clipShape(Capsule())
                        .shadow(radius: 4)
                    }
                }
                .padding(20)
            }
        }
        .fullScreenCover(isPresented: $showCharacterPreview) {
            ZStack {
                CharacterPreviewView()

                // 닫기 버튼
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showCharacterPreview = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 4)
                        }
                        .padding(20)
                    }
                    Spacer()
                }
            }
        }
        #endif
    }

    // MARK: - Computed Views

    @ViewBuilder
    private var mainView: some View {
        if let user = appState.currentUser {
            if user.userType == .ward {
                WardTabView()
            } else {
                GuardianTabView()
            }
        } else {
            // currentUser가 nil이면 로그인 화면으로 (방어 코드)
            UserTypeSelectionView { type, loginResult in
                selectedUserType = type
                handleLoginSuccess(userType: type, loginResult: loginResult)
            }
            .environmentObject(appState)
            .onAppear {
                Log.ui.e("mainView에 currentUser가 nil - userTypeSelection으로 복귀")
                navigationState = .userTypeSelection
            }
        }
    }

    // MARK: - Private Methods

    private func checkInitialState() async {
        Log.ui.i("checkInitialState() 시작")

        // 대기 중인 로그인 상태 클리어
        UserDefaults.standard.clearPendingLoginUserType()

        // Universal Link로 앱이 시작된 경우에도 서버 선택 먼저
        // (서버 선택 완료 후 deeplink 처리는 onChange에서 수행)
        if deeplinkManager.hasUnhandledDeeplink {
            Log.ui.i("Universal Link 감지됨 - 서버 선택 후 처리 예정")
        }

        // 서버 선택 화면으로 이동
        Log.ui.i("서버 선택 화면으로 이동")
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
                    if userType == .ward {
                        // ward는 신규여도 matchStatus 확인 필요 (자동 매칭 가능)
                        Log.auth.i("어르신 신규 가입 - 매칭 상태 확인")
                        handleWardLoginResponse(authResponse)
                    } else {
                        handleNewUserResponse(authResponse: authResponse, userType: userType)
                    }
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
                    // 보호자 로그인 처리 - 기존 사용자
                    Log.auth.i("보호자 로그인 (기존 사용자)")
                    // guardianInfo가 응답에 있으면 user에 병합
                    let userWithGuardianInfo = UserMeResponse(
                        id: user.id,
                        identity: user.identity,
                        kakaoId: user.kakaoId,
                        email: user.email,
                        nickname: user.nickname,
                        profileImageUrl: user.profileImageUrl,
                        userType: user.userType ?? .guardian,
                        createdAt: user.createdAt,
                        guardianInfo: authResponse.guardianInfo ?? user.guardianInfo,
                        wardInfo: user.wardInfo
                    )
                    appState.didLogin(user: userWithGuardianInfo)
                    navigateToMainOrPermission(userType: .guardian)
                }
            } catch {
                // 상세 에러 로깅
                Log.auth.e("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                Log.auth.e("🚨 로그인 실패 - 상세 정보")
                Log.auth.e("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                Log.auth.e("userType: \(userType)")
                Log.auth.e("error type: \(type(of: error))")
                Log.auth.e("error: \(error)")
                Log.auth.e("localizedDescription: \(error.localizedDescription)")

                if let authError = error as? AuthError {
                    switch authError {
                    case .httpStatus(let code, let body):
                        Log.auth.e("📡 HTTP 에러 - code: \(code)")
                        Log.auth.e("📡 HTTP 에러 - body: \(body)")
                    case .networkError(let message):
                        Log.auth.e("🌐 네트워크 에러: \(message)")
                    case .decodingError(let message):
                        Log.auth.e("📦 디코딩 에러: \(message)")
                    case .invalidResponse:
                        Log.auth.e("❌ 잘못된 응답 형식")
                    case .missingAuthToken:
                        Log.auth.e("🔑 인증 토큰 없음")
                    case .missingToken:
                        Log.auth.e("🔑 토큰 없음")
                    case .unauthorized:
                        Log.auth.e("🚫 인증 실패 (401)")
                    case .unknown:
                        Log.auth.e("❓ 알 수 없는 에러")
                    }
                }
                Log.auth.e("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                // 에러 처리 - alert 표시 후 타입 선택으로
                await MainActor.run {
                    if let authError = error as? AuthError {
                        switch authError {
                        case .httpStatus(let code, let body):
                            // 서버에서 반환한 에러 메시지 파싱 시도
                            if let data = body.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let message = json["message"] as? String {
                                loginErrorMessage = message
                            } else {
                                loginErrorMessage = "로그인에 실패했습니다. (오류 코드: \(code))"
                            }
                        default:
                            loginErrorMessage = Strings.Auth.loginFailed
                        }
                    } else {
                        loginErrorMessage = Strings.Auth.loginFailed
                    }
                    showLoginErrorAlert = true
                }
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
            Log.auth.i("matchStatus 없음 - 매칭 성공으로 간주")
            appState.didLogin(user: user)
            navigateToMainOrPermission(userType: .ward)
            return
        }

        Log.auth.i("matchStatus: \(matchStatus)")
        switch matchStatus {
        case .matched:
            // 매칭 성공
            Log.auth.i("매칭 성공")
            appState.didLogin(user: user)
            navigateToMainOrPermission(userType: .ward)

        case .notMatched:
            // 매칭 실패 - 토큰 저장하지 않고 알림 표시
            Log.auth.w("매칭 실패 - 알림 표시")
            matchFailureMessage = authResponse.matchMessage
            showMatchFailureAlert = true

        case .pending:
            // 대기 중
            Log.auth.i("매칭 대기 중")
            appState.didLogin(user: user)
            navigateToMainOrPermission(userType: .ward)
        }
    }

    private func handleServerSelected() {
        Task {
            Log.ui.i("서버 선택 완료 (서버: \(AppConfig.serverDomain)) - 인증 상태 확인 중...")
            await appState.checkAuthStatus()

            if appState.isAuthenticated {
                Log.ui.i("자동 로그인 성공 - 메인으로 이동")
                navigationState = .main  // 자동 로그인은 권한 온보딩 스킵
            } else {
                Log.ui.i("인증되지 않음 - 사용자 타입 선택으로 이동")
                // 기존 토큰이 남아있으면 삭제 (서버 에러로 인증 실패 시 토큰이 남아있을 수 있음)
                // 새 로그인 시도 시 이전 계정으로 자동 로그인되는 문제 방지
                if TokenManager.shared.hasTokens {
                    Log.ui.w("기존 토큰 발견 - 삭제 (인증 실패 상태에서 토큰이 남아있음)")
                    TokenManager.shared.clearTokens()
                }

                // Deeplink가 있으면 해당 userType으로 바로 로그인 화면으로 이동
                if deeplinkManager.hasUnhandledDeeplink, let userType = deeplinkManager.requestedUserType {
                    Log.ui.i("Deeplink 처리 - userType: \(userType), shouldAutoTrigger: \(deeplinkManager.shouldAutoTriggerLogin)")
                    selectedUserType = userType
                    shouldAutoTriggerLogin = deeplinkManager.shouldAutoTriggerLogin
                    deeplinkManager.clearDeeplink()
                    navigationState = .login(userType)
                } else {
                    navigationState = .userTypeSelection
                }
            }
        }
    }

    /// 권한 온보딩이 필요한지 확인하고 적절한 화면으로 이동
    private func navigateToMainOrPermission(userType: UserType) {
        if UserDefaults.standard.permissionOnboardingCompleted {
            Log.ui.i("권한 온보딩 완료됨 - 메인으로 이동")
            navigationState = .main
        } else {
            Log.ui.i("권한 온보딩 필요 - 온보딩 화면으로 이동")
            navigationState = .permissionOnboarding(userType)
        }
    }

    // MARK: - 수신 통화 처리

    private func acceptIncomingCall() {
        guard let call = callStateStore.activeCall else { return }
        Log.ui.i("수신 통화 수락 - handle: \(call.handle)")

        // ⚠️ 중요: 먼저 벨소리를 중지해야 오디오 세션 충돌 방지
        RingtonePlayer.shared.stopRinging()

        let isForeground = UIApplication.shared.applicationState == .active

        // Foreground에서는 이미 CallKit을 종료했으므로 직접 통화 시작
        // Background에서 CallKit으로 수락된 경우는 onChange에서 처리됨
        if isForeground || resolveCallCapability() != .callKit {
            // Foreground 또는 WiFi-only iPad: 직접 통화 시작
            Log.ui.i("직접 통화 시작 (foreground=\(isForeground))")
            callStateStore.clearCall()
            showGlobalCallView = true

            // 오디오 세션이 안정화될 시간을 위해 약간의 딜레이 후 통화 시작
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
                if let roomName = call.roomName {
                    callViewModel.startCall(roomName: roomName)
                } else {
                    callViewModel.startCall()
                }
            }
        } else {
            // Background + CallKit: answerCall → setAnswered → onChange에서 showGlobalCallView = true
            Log.ui.i("CallKit 통해 수락")
            CallManager.shared.answerCall(uuid: call.id)
        }
    }

    private func declineIncomingCall() {
        guard let call = callStateStore.activeCall else { return }
        Log.ui.i("수신 통화 거절 - handle: \(call.handle)")

        // 벨소리 중지
        RingtonePlayer.shared.stopRinging()

        let isForeground = UIApplication.shared.applicationState == .active

        // Foreground에서는 이미 CallKit을 종료했으므로 clearCall만 호출
        if isForeground || resolveCallCapability() != .callKit {
            callStateStore.clearCall()
        } else {
            CallManager.shared.endCall(uuid: call.id)
        }
    }

    private func handleGuardianRegistrationComplete(wardEmail: String, user: UserMeResponse) {
        // 보호자 등록 완료 후 초대 화면으로
        let guardianName = kakaoUserInfo?.nickname ?? user.nickname ?? Strings.UserType.guardian

        let inviteInfo = InviteInfo(
            guardianId: user.id,
            guardianName: guardianName,
            wardEmail: wardEmail
        )
        navigationState = .inviteCompletion(inviteInfo)
    }

}
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

// AppNavigationState is now defined in Core/AppCoordinator.swift

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var callViewModel = DependencyContainer.shared.makeLiveKitViewModel()
    
    // EnvironmentObjects
    @EnvironmentObject var deeplinkManager: DeeplinkManager
    // AppState는 ViewModel 내부에서 참조하지만, View 계층 구조 유지를 위해 여기서도 주입
    @StateObject private var appState = AppState.shared
    @ObservedObject private var callStateStore = CallStateStore.shared

    var body: some View {
        Group {
            switch viewModel.navigationState {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .serverSelection:
                StartView(isServerSelected: Binding(
                    get: { false },
                    set: { if $0 { viewModel.handleServerSelected() } }
                ))
                .transition(.move(edge: .leading))

            case .userTypeSelection:
                UserTypeSelectionView { type, loginResult in
                    // 카카오 로그인 성공 - 바로 서버 인증 진행
                    viewModel.selectedUserType = type
                    Log.ui.i("카카오 로그인 성공 - userType: \(type)")
                    viewModel.handleLoginSuccess(userType: type, loginResult: loginResult)
                }
                .environmentObject(appState)
                .transition(.move(edge: .trailing))

            case .login(let userType):
                KakaoLoginView(
                    onLoginSuccess: { loginResult in
                        viewModel.handleLoginSuccess(userType: userType, loginResult: loginResult)
                    },
                    autoTriggerLogin: viewModel.shouldAutoTriggerLogin
                )
                .transition(.move(edge: .trailing))
                .onDisappear {
                    viewModel.shouldAutoTriggerLogin = false
                }

            case .guardianRegistration:
                if let userInfo = viewModel.kakaoUserInfo {
                    GuardianRegistrationView(
                        kakaoUserInfo: userInfo,
                        onRegistrationComplete: { wardEmail, user in
                            viewModel.onRegistrationComplete(wardEmail: wardEmail, user: user)
                        },
                        onBack: {
                            viewModel.navigationState = .userTypeSelection
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
                        viewModel.navigateToMainOrPermission(userType: .guardian)
                    }
                )
                .transition(.move(edge: .trailing))

            case .permissionOnboarding(let userType):
                PermissionOnboardingView(userType: userType) {
                    viewModel.navigationState = .main
                }
                .transition(.move(edge: .trailing))

            case .main:
                mainView
                    .transition(.move(edge: .trailing))
                    .environmentObject(appState)
            }
        }
        .animation(.default, value: viewModel.navigationState)
        .task {
            await viewModel.checkInitialState()
        }
        .alert(Strings.Auth.sessionExpiredTitle, isPresented: $viewModel.showSessionExpiredAlert) {
            Button(Strings.Common.confirm) {
                viewModel.navigationState = .userTypeSelection
            }
        } message: {
            Text(Strings.Auth.sessionExpiredMessage)
        }
        .alert(Strings.Matching.noGuardianTitle, isPresented: $viewModel.showMatchFailureAlert) {
            Button(Strings.Common.confirm) {
                viewModel.navigationState = .userTypeSelection
            }
        } message: {
            Text(viewModel.matchFailureMessage ?? Strings.Matching.noGuardianMessage)
        }
        .alert(Strings.Matching.userTypeMismatchTitle, isPresented: $viewModel.showUserTypeMismatchAlert) {
            Button(Strings.Common.confirm) {
                viewModel.navigationState = .userTypeSelection
            }
        } message: {
            Text(viewModel.userTypeMismatchMessage ?? Strings.Matching.userTypeMismatchMessage)
        }
        .alert(Strings.Auth.loginFailedTitle, isPresented: $viewModel.showLoginErrorAlert) {
            Button(Strings.Common.confirm) {
                viewModel.navigationState = .userTypeSelection
            }
        } message: {
            Text(viewModel.loginErrorMessage ?? Strings.Auth.loginFailed)
        }
        // 전역 수신 통화 화면
        .fullScreenCover(isPresented: Binding(
            get: { callStateStore.activeCall?.status == .ringing && !viewModel.showGlobalCallView },
            set: { _ in }
        )) {
            if let call = callStateStore.activeCall {
                FullScreenIncomingCallView(
                    callerName: call.handle,
                    callerImageName: nil,
                    hasVideo: call.hasVideo,
                    onAccept: { viewModel.acceptIncomingCall() },
                    onDecline: { viewModel.declineIncomingCall() }
                )
            }
        }
        // 전역 통화 화면
        .fullScreenCover(isPresented: $viewModel.showGlobalCallView) {
            FullScreenCallView(viewModel: callViewModel) {
                viewModel.showGlobalCallView = false
            }
            .onAppear {
                let roomName = callStateStore.activeCall?.roomName
                callStateStore.clearCall()
                
                if !callViewModel.isConnected && !callViewModel.isBusy {
                    if let roomName = roomName {
                        callViewModel.startCall(roomName: roomName)
                    } else {
                        callViewModel.startCall()
                    }
                }
            }
        }
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            if viewModel.navigationState == .serverSelection && !viewModel.showGlobalCallView && !viewModel.showCharacterPreview {
                Button(action: {
                    viewModel.showCharacterPreview = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.on.rectangle")
                        Text("UI Test")
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .padding()
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
            UserTypeSelectionView { type, loginResult in
                viewModel.selectedUserType = type
                viewModel.handleLoginSuccess(userType: type, loginResult: loginResult)
            }
            .environmentObject(appState)
            .onAppear {
                viewModel.navigationState = .userTypeSelection
            }
        }
    }
}
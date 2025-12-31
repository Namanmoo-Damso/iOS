//
//  WardTabView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 어르신 메인 탭 뷰
struct WardTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var callViewModel = DependencyContainer.shared.makeLiveKitViewModel()
    @State private var selectedTab = 0
    @State private var showCallView = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // 탭 1: 홈
            WardHomeTabContent(showCallView: $showCallView)
                .environmentObject(appState)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(0)

            // 탭 2: 설정
            WardSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .fullScreenCover(isPresented: $showCallView) {
            FullScreenCallView(viewModel: callViewModel) {
                showCallView = false
            }
            .onAppear {
                // 통화 화면 표시 시 자동으로 통화 시작
                if !callViewModel.isConnected && !callViewModel.isBusy {
                    callViewModel.startCall()
                }
            }
        }
    }
}

/// 어르신 홈 탭 컨텐츠 (WardHomeView에서 fullScreenCover 제거한 버전)
struct WardHomeTabContent: View {
    @EnvironmentObject var appState: AppState
    @Binding var showCallView: Bool
    @AppStorage("locationTrackingEnabled") private var locationTrackingEnabled = true
    @State private var showMyProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 헤더
                    WardHeaderView(user: appState.currentUser)

                    // AI 대화 카드
                    AIConversationCard {
                        showCallView = true
                    }

                    // 바로가기
                    HStack(spacing: 16) {
                        QuickLinkButton(
                            icon: "person.fill",
                            title: "내 정보",
                            color: .blue
                        ) {
                            showMyProfile = true
                        }

                        QuickLinkButton(
                            icon: "heart.fill",
                            title: "건강 기록",
                            color: .pink
                        ) {
                            // TODO: 건강 기록 화면으로 이동
                        }
                    }
                    .padding(.horizontal)

                    // 알림 배너
                    NotificationBanner(
                        message: "오늘 오후에 안부 전화를 드릴 예정이에요."
                    )
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EmergencyButton()
                }
            }
            .onAppear {
                // 위치 추적 자동 시작
                if locationTrackingEnabled {
                    LocationService.shared.startTracking()
                }
            }
            .sheet(isPresented: $showMyProfile) {
                NavigationStack {
                    MyProfileView()
                        .environmentObject(appState)
                }
            }
        }
    }
}

#Preview {
    WardTabView()
        .environmentObject(AppState())
}

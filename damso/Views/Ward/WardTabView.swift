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

            // 탭 2: 대화하기 (탭 선택 시 통화 화면 표시)
            CallTabPlaceholder(showCallView: $showCallView)
                .tabItem {
                    Label("대화하기", systemImage: "phone.fill")
                }
                .tag(1)

            // 탭 3: 설정
            WardSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 1 {
                // 통화 탭 선택 시 통화 화면 표시
                showCallView = true
                // 홈 탭으로 되돌리기 (통화 종료 후 홈으로 복귀)
                selectedTab = 0
            }
        }
        .fullScreenCover(isPresented: $showCallView) {
            LiveKitRoomView(
                viewModel: DependencyContainer.shared.makeLiveKitViewModel(),
                dismissOnCallEnd: true
            )
            .environmentObject(appState)
        }
    }
}

/// 어르신 홈 탭 컨텐츠 (WardHomeView에서 fullScreenCover 제거한 버전)
struct WardHomeTabContent: View {
    @EnvironmentObject var appState: AppState
    @Binding var showCallView: Bool
    @AppStorage("locationTrackingEnabled") private var locationTrackingEnabled = true

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
                            // TODO: 내 정보 화면으로 이동
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
        }
    }
}

/// 통화 탭 플레이스홀더 (탭 선택 시 fullScreenCover로 전환)
struct CallTabPlaceholder: View {
    @Binding var showCallView: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "phone.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("대화하기")
                .font(.title2)
                .fontWeight(.semibold)

            Button {
                showCallView = true
            } label: {
                Text("전화 시작하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(25)
            }
        }
    }
}

#Preview {
    WardTabView()
        .environmentObject(AppState())
}

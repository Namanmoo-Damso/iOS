//
//  WardHomeView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 어르신 홈 화면
struct WardHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCallView = false

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
            .fullScreenCover(isPresented: $showCallView) {
                // 영상통화 화면
                LiveKitRoomView(viewModel: DependencyContainer.shared.makeLiveKitViewModel())
                    .environmentObject(appState)
            }
        }
    }
}

#Preview {
    WardHomeView()
        .environmentObject(AppState())
}

//
//  GuardianHomeView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 보호자 홈 화면 (대시보드)
struct GuardianHomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GuardianDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 헤더
                    headerView

                    // 통계 카드
                    statisticsSection

                    // 건강 알림
                    if !viewModel.alerts.isEmpty {
                        alertsSection
                    }

                    // 최근 대화
                    recentCallsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("대시보드")
            .refreshable {
                await viewModel.fetchDashboard()
            }
        }
        .task {
            await viewModel.fetchDashboard()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("안녕하세요, \(appState.currentUser?.nickname ?? "보호자")님")
                    .font(.title2)
                    .fontWeight(.bold)

                if let wardInfo = appState.currentUser?.guardianInfo?.linkedWard {
                    Text("\(wardInfo.nickname)님의 대화 현황입니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("피보호자 연결을 기다리고 있습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "총 대화 수",
                value: "\(viewModel.totalCalls)",
                change: viewModel.weeklyChange > 0 ? "+\(viewModel.weeklyChange)" : nil,
                icon: "phone.fill",
                color: .blue
            )

            StatCard(
                title: "평균 시간",
                value: "\(viewModel.averageDuration)분",
                subtitle: "대화당",
                icon: "clock.fill",
                color: .orange
            )

            StatCard(
                title: "전반적 기분",
                value: viewModel.positiveMoodPercent >= 50 ? "긍정적" : "부정적",
                subtitle: "\(viewModel.positiveMoodPercent)%",
                icon: "face.smiling.fill",
                color: viewModel.positiveMoodPercent >= 50 ? .green : .red
            )
        }
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("건강 알림")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(viewModel.alerts) { alert in
                AlertCard(alert: alert)
            }
        }
    }

    // MARK: - Recent Calls Section

    private var recentCallsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 대화")
                    .font(.headline)

                Spacer()

                NavigationLink("전체보기") {
                    CallHistoryListView()
                        .environmentObject(appState)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 4)

            if viewModel.recentCalls.isEmpty {
                Text("아직 대화 기록이 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(viewModel.recentCalls) { call in
                    RecentCallCard(call: call)
                }
            }
        }
    }
}

// MARK: - Placeholder for Call History

struct CallHistoryListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Text("통화 기록 전체 목록")
            .navigationTitle("통화 기록")
    }
}

#Preview {
    GuardianHomeView()
        .environmentObject(AppState())
}

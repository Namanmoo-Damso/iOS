//
//  GuardianTabView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 보호자 메인 탭 뷰
struct GuardianTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 탭 1: 홈 (대시보드)
            GuardianHomeView()
                .environmentObject(appState)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(0)

            // 탭 2: 보고서
            GuardianReportView()
                .tabItem {
                    Label("보고서", systemImage: "chart.bar.fill")
                }
                .tag(1)

            // 탭 3: 설정
            GuardianSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tabViewStyle(.tabBarOnly)  // iPad에서도 하단 탭바 강제
        .tint(.damsoGreen)
    }
}
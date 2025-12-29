//
//  NotificationSettingsView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 알림 설정 화면
struct NotificationSettingsView: View {
    @AppStorage("healthAlertEnabled") private var healthAlertEnabled = true
    @AppStorage("callCompletedAlertEnabled") private var callCompletedAlertEnabled = true
    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $healthAlertEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("건강 알림")
                            .font(.body)

                        Text("통증, 수면 등 건강 관련 키워드 감지 시")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $callCompletedAlertEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("통화 완료 알림")
                            .font(.body)

                        Text("어르신의 통화가 완료되면 알림")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $dailySummaryEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("일일 요약")
                            .font(.body)

                        Text("매일 저녁 어르신의 하루 요약 전송")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("푸시 알림")
            } footer: {
                Text("알림을 받으려면 기기 설정에서 알림을 허용해주세요.")
            }
        }
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

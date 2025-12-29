//
//  NotificationSettingsView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 알림 설정 화면
struct NotificationSettingsView: View {
    @AppStorage("callReminderEnabled") private var callReminderEnabled = true
    @AppStorage("healthAlertEnabled") private var healthAlertEnabled = true
    @AppStorage("callCompletedAlertEnabled") private var callCompletedAlertEnabled = true
    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled = false

    @State private var isSyncing = false
    @State private var showPermissionAlert = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $callReminderEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("통화 리마인더")
                            .font(.body)

                        Text("예정된 통화 30분 전 알림")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: callReminderEnabled) { _, _ in
                    syncSettings()
                }

                Toggle(isOn: $healthAlertEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("건강 알림")
                            .font(.body)

                        Text("통증, 수면 등 건강 관련 키워드 감지 시")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: healthAlertEnabled) { _, _ in
                    syncSettings()
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
                .onChange(of: callCompletedAlertEnabled) { _, _ in
                    syncSettings()
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
                .onChange(of: dailySummaryEnabled) { _, _ in
                    syncSettings()
                }
            } header: {
                Text("푸시 알림")
            } footer: {
                Text("알림을 받으려면 기기 설정에서 알림을 허용해주세요.")
            }

            Section {
                Button {
                    openSystemSettings()
                } label: {
                    HStack {
                        Text("시스템 알림 설정")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSyncing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }

    // MARK: - Private Methods

    private func syncSettings() {
        Task {
            isSyncing = true
            do {
                try await PushNotificationService.shared.updateNotificationSettings(
                    callReminder: callReminderEnabled,
                    callComplete: callCompletedAlertEnabled,
                    healthAlert: healthAlertEnabled,
                    dailySummary: dailySummaryEnabled
                )
            } catch {
                debugLog("Failed to sync settings: \(error)")
            }
            isSyncing = false
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[NotificationSettingsView] \(message)")
        #endif
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

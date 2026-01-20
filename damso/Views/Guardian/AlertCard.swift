//
//  AlertCard.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 건강 알림 카드
struct AlertCard: View {
    let alert: DashboardAlert

    private var alertColor: Color {
        switch alert.type {
        case .warning:
            return .red
        case .info:
            return .blue
        }
    }

    private var alertIcon: String {
        switch alert.type {
        case .warning:
            return "exclamationmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var alertTypeText: String {
        switch alert.type {
        case .warning:
            return "경고"
        case .info:
            return "정보"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 아이콘
            Image(systemName: alertIcon)
                .font(.title3)
                .foregroundColor(alertColor)

            // 내용
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(alert.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 타입 배지
            Text(alertTypeText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(alertColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(alertColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}
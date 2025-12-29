//
//  NotificationBanner.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 알림 배너
struct NotificationBanner: View {
    let message: String
    var icon: String = "lightbulb.fill"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.yellow)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        NotificationBanner(
            message: "오늘 오후에 안부 전화를 드릴 예정이에요."
        )

        NotificationBanner(
            message: "새로운 메시지가 도착했습니다.",
            icon: "envelope.fill"
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

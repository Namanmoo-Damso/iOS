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
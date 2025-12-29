//
//  QuickLinkButton.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 바로가기 버튼
struct QuickLinkButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        QuickLinkButton(
            icon: "person.fill",
            title: "내 정보",
            color: .blue
        ) {}

        QuickLinkButton(
            icon: "heart.fill",
            title: "건강 기록",
            color: .pink
        ) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

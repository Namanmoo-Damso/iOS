//
//  StatCard.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 통계 카드 컴포넌트
struct StatCard: View {
    let title: String
    let value: String
    var change: String? = nil
    var subtitle: String? = nil
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 아이콘
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            // 제목
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            // 값
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            // 변화량 또는 부제
            if let change = change {
                Text(change)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            } else if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}
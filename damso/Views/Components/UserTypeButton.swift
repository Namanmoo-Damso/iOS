//
//  UserTypeButton.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 사용자 타입 선택 버튼
struct UserTypeButton: View {
    let type: UserType
    let title: String
    let icon: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    init(
        type: UserType,
        title: String,
        icon: String,
        subtitle: String = "",
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // 아이콘
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(isSelected ? typeColor : Color(.systemGray5))
                    )

                // 타이틀
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // 서브타이틀
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? typeColor.opacity(0.1) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? typeColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var typeColor: Color {
        switch type {
        case .guardian:
            return .blue
        case .ward:
            return .orange
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            UserTypeButton(
                type: .guardian,
                title: "보호자",
                icon: "person.badge.shield.checkmark",
                subtitle: "어르신을 돌보는 분",
                isSelected: true
            ) {
                print("Guardian selected")
            }

            UserTypeButton(
                type: .ward,
                title: "어르신",
                icon: "person.fill",
                subtitle: "케어를 받는 분",
                isSelected: false
            ) {
                print("Ward selected")
            }
        }
        .padding()
    }
}

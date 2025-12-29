//
//  UserTypeSelectionView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 사용자 타입(보호자/어르신) 선택 화면
struct UserTypeSelectionView: View {
    @State private var selectedType: UserType?
    @State private var isAnimating = false

    /// 사용자 타입 선택 완료 콜백
    let onTypeSelected: (UserType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 헤더
            VStack(spacing: 12) {
                Image("damso")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Text("담소에 오신 것을 환영합니다!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("서비스를 이용하실 분을 선택해 주세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)

            // 타입 선택 버튼
            HStack(spacing: 16) {
                UserTypeButton(
                    type: .guardian,
                    title: "보호자",
                    icon: "person.badge.shield.checkmark",
                    subtitle: "어르신을 돌보는 분",
                    isSelected: selectedType == .guardian
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedType = .guardian
                    }
                }
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)

                UserTypeButton(
                    type: .ward,
                    title: "어르신",
                    icon: "person.fill",
                    subtitle: "케어를 받는 분",
                    isSelected: selectedType == .ward
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedType = .ward
                    }
                }
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
            }
            .padding(.horizontal, 24)

            Spacer()

            // 계속하기 버튼
            Button(action: continueAction) {
                HStack {
                    Text("계속하기")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedType != nil ? Color.blue : Color.gray)
                )
            }
            .disabled(selectedType == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeIn.delay(0.3), value: isAnimating)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            isAnimating = true
        }
    }

    private func continueAction() {
        guard let type = selectedType else { return }
        onTypeSelected(type)
    }
}

#Preview {
    UserTypeSelectionView { type in
        print("Selected: \(type.displayName)")
    }
}

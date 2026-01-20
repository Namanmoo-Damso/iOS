//
//  AIConversationCard.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// AI 대화 시작 카드
struct AIConversationCard: View {
    let onStartCall: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // AI 캐릭터 이미지
            Image(systemName: "person.wave.2.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 20)

            // 제목
            Text("다미와 대화하기")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            // 부제
            Text("오늘 있었던 일을 들려주세요")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 전화 시작 버튼
            Button(action: onStartCall) {
                HStack {
                    Image(systemName: "phone.fill")
                    Text("전화 시작하기")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }
}
//
//  SplashView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 앱 시작 시 로딩 화면
struct SplashView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 배경
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 앱 로고
                Image("damso")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // 앱 이름
                Text("damso")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // 로딩 인디케이터
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                    .padding(.top, 20)

                // 로딩 텍스트
                Text("로딩 중...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    SplashView()
}

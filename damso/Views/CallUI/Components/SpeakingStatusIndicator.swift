//
//  SpeakingStatusIndicator.swift
//  damso
//
//  음성 통화 상태 표시 (듣는 중 / 말하는 중)
//

import SwiftUI

/// 음성 통화 상태
enum SpeakingStatus {
    case listening  // 사용자의 말을 듣는 중
    case talking    // AI가 말하는 중
    case idle       // 대기 상태

    var displayText: String {
        switch self {
        case .listening: return "듣는 중"
        case .talking: return "말하는 중"
        case .idle: return "대기 중"
        }
    }

    var iconName: String {
        switch self {
        case .listening: return "ear.fill"
        case .talking: return "waveform"
        case .idle: return "circle"
        }
    }

    var color: Color {
        switch self {
        case .listening: return Color(hex: "00D4FF")  // 시안 (듣기)
        case .talking: return Color(hex: "7B61FF")    // 보라 (말하기)
        case .idle: return Color.gray
        }
    }

    var videoName: String {
        switch self {
        case .listening: return "listening_final"
        case .talking: return "talking_final"
        case .idle: return "listening_final"
        }
    }
}

/// 상태 표시 인디케이터 (깜빡임 효과, 화면 크기에 비례)
struct SpeakingStatusIndicator: View {
    let status: SpeakingStatus

    @State private var isBlinking = false

    // 기준 화면 너비 (iPad mini 6)
    private let baseWidth: CGFloat = 768

    /// 상대값 계산
    private func relative(_ value: CGFloat) -> CGFloat {
        value * (UIScreen.main.bounds.width / baseWidth)
    }

    var body: some View {
        HStack(spacing: relative(10)) {
            // 깜빡이는 점 (크기 증가)
            Circle()
                .fill(status.color)
                .frame(width: relative(14), height: relative(14))
                .opacity(isBlinking ? 1.0 : 0.3)
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: isBlinking
                )

            // 아이콘 (크기 증가)
            Image(systemName: status.iconName)
                .font(.system(size: relative(22), weight: .medium))
                .foregroundColor(status.color)

            // 텍스트 (크기 증가)
            Text(status.displayText)
                .font(.system(size: relative(22), weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, relative(20))
        .padding(.vertical, relative(14))
        .background(
            RoundedRectangle(cornerRadius: relative(24), style: .continuous)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: relative(24), style: .continuous)
                        .stroke(status.color.opacity(0.5), lineWidth: relative(1.5))
                )
        )
        .onAppear {
            isBlinking = true
        }
        .onChange(of: status) { _, _ in
            // 상태 변경 시 애니메이션 리셋
            isBlinking = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isBlinking = true
            }
        }
    }
}

#Preview("Speaking Status") {
    ZStack {
        Color(hex: "1C1C1E")
            .ignoresSafeArea()

        VStack(spacing: 20) {
            SpeakingStatusIndicator(status: .listening)
            SpeakingStatusIndicator(status: .talking)
            SpeakingStatusIndicator(status: .idle)
        }
    }
}

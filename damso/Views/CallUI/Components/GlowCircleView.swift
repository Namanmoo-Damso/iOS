//
//  GlowCircleView.swift
//  damso
//
//  오디오 레벨에 반응하는 글로우 원형 시각화
//  말이 없을 때는 정적, 말할 때만 반응
//

import SwiftUI

/// 오디오 레벨에 반응하는 글로우 원형 뷰
struct GlowCircleView: View {
    let audioLevel: Float  // 0.0 ~ 1.0

    // 오디오 활성 상태 (임계값 이상이면 활성)
    private var isActive: Bool {
        audioLevel > 0.02  // 더 민감하게 반응
    }

    // 기본 크기 (크게 조정)
    private let baseSize: CGFloat = 200

    // 색상 (말할 때와 조용할 때)
    private var primaryColor: Color {
        isActive ? Color(hex: "7B61FF") : Color(hex: "4A4A5A")
    }

    private var secondaryColor: Color {
        isActive ? Color(hex: "00D4FF") : Color(hex: "3A3A4A")
    }

    var body: some View {
        ZStack {
            // 외곽 글로우 (말할 때만 확장)
            if isActive {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "7B61FF").opacity(0.4 * Double(audioLevel)),
                                Color(hex: "00D4FF").opacity(0.2 * Double(audioLevel)),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: baseSize * 0.3,
                            endRadius: baseSize * 1.5
                        )
                    )
                    .frame(width: baseSize * 3, height: baseSize * 3)
                    .scaleEffect(1.0 + CGFloat(audioLevel) * 0.4)
                    .animation(.easeOut(duration: 0.1), value: audioLevel)
            }

            // 외곽 테두리 링 (말할 때 파동 효과)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(isActive ? 0.8 : 0.3),
                            secondaryColor.opacity(isActive ? 0.6 : 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isActive ? 4 : 2
                )
                .frame(
                    width: baseSize * 1.4 + (isActive ? CGFloat(audioLevel) * 30 : 0),
                    height: baseSize * 1.4 + (isActive ? CGFloat(audioLevel) * 30 : 0)
                )
                .scaleEffect(isActive ? 1.0 + CGFloat(audioLevel) * 0.1 : 1.0)
                .animation(.easeOut(duration: 0.15), value: audioLevel)
                .animation(.easeInOut(duration: 0.3), value: isActive)

            // 두 번째 테두리 링 (말할 때만 표시)
            if isActive {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "7B61FF").opacity(0.4),
                                Color(hex: "00D4FF").opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(
                        width: baseSize * 1.6 + CGFloat(audioLevel) * 40,
                        height: baseSize * 1.6 + CGFloat(audioLevel) * 40
                    )
                    .opacity(Double(audioLevel) * 0.8)
                    .animation(.easeOut(duration: 0.1), value: audioLevel)
            }

            // 메인 원형
            Circle()
                .fill(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(isActive ? 1.0 + CGFloat(audioLevel) * 0.15 : 1.0)
                .animation(.easeOut(duration: 0.1), value: audioLevel)
                .animation(.easeInOut(duration: 0.3), value: isActive)
                .shadow(
                    color: primaryColor.opacity(isActive ? 0.6 : 0.2),
                    radius: isActive ? 20 + CGFloat(audioLevel) * 15 : 10
                )

            // 웨이브폼 아이콘
            Image(systemName: isActive ? "waveform" : "waveform.circle")
                .font(.system(size: isActive ? 50 : 44, weight: .medium))
                .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.7))
                .scaleEffect(isActive ? 1.0 + CGFloat(audioLevel) * 0.2 : 1.0)
                .animation(.easeOut(duration: 0.1), value: audioLevel)
                .animation(.easeInOut(duration: 0.3), value: isActive)
        }
    }
}
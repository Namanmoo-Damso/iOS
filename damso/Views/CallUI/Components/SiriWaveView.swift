import SwiftUI

/// Siri 스타일 원형 오디오 시각화
struct SiriWaveView: View {
    let audioLevel: Float  // 0.0 ~ 1.0
    let isListening: Bool  // AI가 듣고 있는 중인지

    // 애니메이션 상태
    @State private var phase: Double = 0
    @State private var innerScale: CGFloat = 1.0
    @State private var outerScale: CGFloat = 1.0

    // 색상 설정
    private let gradientColors: [Color] = [
        Color(hex: "00D4FF"),  // 시안
        Color(hex: "7B61FF"),  // 보라
        Color(hex: "FF61DC"),  // 핑크
        Color(hex: "00D4FF")   // 시안 (순환)
    ]

    var body: some View {
        ZStack {
            // 외곽 글로우 효과
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "7B61FF").opacity(0.3 * Double(audioLevel + 0.2)),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(outerScale)

            // 외곽 원 (펄스)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: 3
                )
                .frame(width: 180 + CGFloat(audioLevel) * 40, height: 180 + CGFloat(audioLevel) * 40)
                .opacity(0.6)
                .scaleEffect(outerScale)

            // 중간 원
            Circle()
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(-phase * 1.5),
                        endAngle: .degrees(-phase * 1.5 + 360)
                    ),
                    lineWidth: 4
                )
                .frame(width: 140 + CGFloat(audioLevel) * 30, height: 140 + CGFloat(audioLevel) * 30)
                .opacity(0.8)

            // 내부 원 (메인)
            Circle()
                .fill(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(phase * 2),
                        endAngle: .degrees(phase * 2 + 360)
                    )
                )
                .frame(width: 100 + CGFloat(audioLevel) * 20, height: 100 + CGFloat(audioLevel) * 20)
                .scaleEffect(innerScale)
                .shadow(color: Color(hex: "7B61FF").opacity(0.5), radius: 20)

            // 중앙 아이콘
            Image(systemName: isListening ? "waveform" : "waveform.circle.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: audioLevel > 0.1)
        }
        .onAppear {
            // 회전 애니메이션
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = 360
            }
            // 펄스 애니메이션
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                innerScale = 1.05
                outerScale = 1.02
            }
        }
        .onChange(of: audioLevel) { _, newLevel in
            // 오디오 레벨에 따른 스케일 조정
            withAnimation(.easeOut(duration: 0.1)) {
                innerScale = 1.0 + CGFloat(newLevel) * 0.15
            }
        }
    }
}

/// 간소화된 Siri 웨이브 (성능 최적화)
struct SimpleSiriWaveView: View {
    let audioLevel: Float

    @State private var isAnimating = false

    private let baseSize: CGFloat = 120

    var body: some View {
        ZStack {
            // 글로우
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "7B61FF").opacity(0.4),
                            Color(hex: "00D4FF").opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(1.0 + CGFloat(audioLevel) * 0.3)
                .animation(.easeOut(duration: 0.15), value: audioLevel)

            // 외곽 링
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "00D4FF").opacity(0.6 - Double(i) * 0.15),
                                Color(hex: "7B61FF").opacity(0.6 - Double(i) * 0.15),
                                Color(hex: "FF61DC").opacity(0.6 - Double(i) * 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3 - CGFloat(i)
                    )
                    .frame(
                        width: baseSize + CGFloat(i * 30) + CGFloat(audioLevel) * 20,
                        height: baseSize + CGFloat(i * 30) + CGFloat(audioLevel) * 20
                    )
                    .scaleEffect(isAnimating ? 1.02 : 0.98)
                    .animation(
                        .easeInOut(duration: 1.2 + Double(i) * 0.2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: isAnimating
                    )
            }

            // 중앙 원
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "7B61FF"),
                            Color(hex: "00D4FF")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(1.0 + CGFloat(audioLevel) * 0.2)
                .animation(.easeOut(duration: 0.1), value: audioLevel)
                .shadow(color: Color(hex: "7B61FF").opacity(0.6), radius: 15)

            // 웨이브 아이콘
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(1.0 + CGFloat(audioLevel) * 0.3)
                .animation(.easeOut(duration: 0.1), value: audioLevel)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview("Siri Wave") {
    ZStack {
        Color(hex: "1C1C1E")

        VStack(spacing: 40) {
            SimpleSiriWaveView(audioLevel: 0.5)

            Text("AI가 말하는 중...")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

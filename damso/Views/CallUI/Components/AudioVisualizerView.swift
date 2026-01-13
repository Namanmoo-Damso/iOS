import SwiftUI

/// 오디오 이퀄라이저 시각화 뷰 (32-band)
struct AudioVisualizerView: View {
    let bands: [Float]

    // 시각화 설정
    var barCount: Int = 32
    var barSpacing: CGFloat = 2
    var minBarHeight: CGFloat = 4
    var maxBarHeight: CGFloat = 120
    var barCornerRadius: CGFloat = 2

    // 그라데이션 색상
    var gradientColors: [Color] = [
        Color(hex: "00D4FF"),  // 시안
        Color(hex: "7B61FF"),  // 보라
        Color(hex: "FF61DC")   // 핑크
    ]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedValue = getNormalizedValue(for: index)
                    let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * CGFloat(normalizedValue)

                    RoundedRectangle(cornerRadius: barCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: (geometry.size.width - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount),
                            height: barHeight
                        )
                        .animation(.easeOut(duration: 0.08), value: normalizedValue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    /// 밴드 인덱스에 해당하는 정규화된 값 (0.0 ~ 1.0)
    private func getNormalizedValue(for index: Int) -> Float {
        guard !bands.isEmpty else { return 0 }

        // bands 배열을 barCount 개로 리샘플링
        let bandIndex = Int(Float(index) / Float(barCount) * Float(bands.count))
        let clampedIndex = min(bandIndex, bands.count - 1)

        return min(1.0, max(0.0, bands[clampedIndex]))
    }
}

/// 컴팩트 버전 이퀄라이저 (작은 사이즈용)
struct CompactAudioVisualizerView: View {
    let bands: [Float]

    var barCount: Int = 16
    var barSpacing: CGFloat = 1.5
    var minBarHeight: CGFloat = 2
    var maxBarHeight: CGFloat = 24

    var body: some View {
        AudioVisualizerView(
            bands: bands,
            barCount: barCount,
            barSpacing: barSpacing,
            minBarHeight: minBarHeight,
            maxBarHeight: maxBarHeight,
            barCornerRadius: 1
        )
    }
}

/// 원형 이퀄라이저 (대안 스타일)
struct CircularAudioVisualizerView: View {
    let bands: [Float]

    var barCount: Int = 32
    var innerRadius: CGFloat = 40
    var maxBarLength: CGFloat = 30

    var gradientColors: [Color] = [
        Color(hex: "00D4FF"),
        Color(hex: "7B61FF"),
        Color(hex: "FF61DC")
    ]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedValue = getNormalizedValue(for: index)
                    let angle = Angle(degrees: Double(index) / Double(barCount) * 360 - 90)
                    let barLength = maxBarLength * CGFloat(normalizedValue) + 4

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barLength, height: 3)
                        .offset(x: innerRadius + barLength / 2)
                        .rotationEffect(angle, anchor: .center)
                        .position(center)
                        .animation(.easeOut(duration: 0.08), value: normalizedValue)
                }

                // 중앙 원
                Circle()
                    .fill(Color(hex: "1C1C1E"))
                    .frame(width: innerRadius * 2 - 10, height: innerRadius * 2 - 10)
                    .position(center)

                // 프로필 아이콘
                Image(systemName: "person.circle.fill")
                    .font(.system(size: innerRadius * 0.8))
                    .foregroundStyle(.gray)
                    .position(center)
            }
        }
    }

    private func getNormalizedValue(for index: Int) -> Float {
        guard !bands.isEmpty else { return 0 }
        let bandIndex = Int(Float(index) / Float(barCount) * Float(bands.count))
        let clampedIndex = min(bandIndex, bands.count - 1)
        return min(1.0, max(0.0, bands[clampedIndex]))
    }
}

#Preview("Audio Visualizer") {
    ZStack {
        Color.black
        VStack(spacing: 40) {
            // 막대 이퀄라이저
            AudioVisualizerView(
                bands: (0..<32).map { _ in Float.random(in: 0.1...0.9) }
            )
            .frame(height: 120)
            .padding(.horizontal, 20)

            // 원형 이퀄라이저
            CircularAudioVisualizerView(
                bands: (0..<32).map { _ in Float.random(in: 0.1...0.9) }
            )
            .frame(width: 200, height: 200)
        }
    }
}

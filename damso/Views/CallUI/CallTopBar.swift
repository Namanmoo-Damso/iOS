import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct CallTopBar: View {
    let callerName: String
    let callDuration: TimeInterval
    let isConnected: Bool
    let remoteConnectionQuality: ConnectionQuality
    var onVideoQualityTap: (() -> Void)? = nil

    // 기준 화면 너비 (iPad mini 6)
    private let baseWidth: CGFloat = 768

    /// 상대값 계산
    private func relative(_ value: CGFloat, screenWidth: CGFloat) -> CGFloat {
        value * (screenWidth / baseWidth)
    }

    /// 폰트 크기 상대값 (제한 없이 화면에 비례)
    private func relativeFontSize(_ baseSize: CGFloat, screenWidth: CGFloat) -> CGFloat {
        baseSize * (screenWidth / baseWidth)
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            VStack(spacing: relative(6, screenWidth: screenWidth)) {
                // 이름 (크기 증가: 20 → 28)
                Text(callerName)
                    .font(.system(size: relativeFontSize(28, screenWidth: screenWidth), weight: .bold))
                    .foregroundColor(.black)

                HStack(spacing: relative(10, screenWidth: screenWidth)) {
                    // 연결 상태 표시 (빨간 점 = 녹화/통화 중, 크기 증가)
                    Circle()
                        .fill(Color.red)
                        .frame(width: relative(12, screenWidth: screenWidth), height: relative(12, screenWidth: screenWidth))

                    // 통화 시간 (크기 증가: 14 → 20)
                    Text(formatDuration(callDuration))
                        .font(.system(size: relativeFontSize(20, screenWidth: screenWidth), weight: .medium))
                        .foregroundColor(.black.opacity(0.8))

                    // 네트워크 품질 표시
                    if isConnected {
                        RemoteNetworkIndicator(quality: remoteConnectionQuality, screenWidth: screenWidth)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, relative(16, screenWidth: screenWidth))
            .padding(.top, relative(16, screenWidth: screenWidth))
            .padding(.bottom, relative(12, screenWidth: screenWidth))
        }
        .frame(height: UIScreen.main.bounds.width * 0.12)  // 화면 너비의 12%
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Remote Network Indicator
struct RemoteNetworkIndicator: View {
    let quality: ConnectionQuality
    var screenWidth: CGFloat = 768  // 기본값: iPad mini 6

    // 기준 화면 너비
    private let baseWidth: CGFloat = 768

    /// 상대값 계산
    private func relative(_ value: CGFloat) -> CGFloat {
        value * (screenWidth / baseWidth)
    }

    var body: some View {
        HStack(spacing: relative(3)) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: relative(2))
                    .fill(barColor(for: index))
                    .frame(width: relative(5), height: barHeight(for: index))
            }
        }
        .frame(height: relative(20))
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [6, 10, 14, 20]
        return relative(heights[index])
    }

    private func barColor(for index: Int) -> Color {
        let activeCount = activeBars
        if index < activeCount {
            return qualityColor
        }
        return Color.white.opacity(0.3)
    }

    private var activeBars: Int {
        switch quality {
        case .excellent: return 4
        case .good: return 3
        case .poor: return 2
        case .lost: return 0
        case .unknown: return 1
        @unknown default: return 1
        }
    }

    private var qualityColor: Color {
        switch quality {
        case .excellent, .good: return .green
        case .poor: return .orange
        case .lost: return .red
        case .unknown: return .gray
        @unknown default: return .gray
        }
    }
}#endif

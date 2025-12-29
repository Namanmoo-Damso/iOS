import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct CallTopBar: View {
    let callerName: String
    let callDuration: TimeInterval
    let isConnected: Bool
    let remoteConnectionQuality: ConnectionQuality

    var body: some View {
        HStack {
            Spacer()

            // Center - Name and status
            VStack(spacing: 4) {
                Text(callerName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    // Connection status indicator
                    Circle()
                        .fill(isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    // Duration timer
                    Text(formatDuration(callDuration))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    // Remote network quality indicator
                    RemoteNetworkIndicator(quality: remoteConnectionQuality)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
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

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 14)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [4, 7, 10, 14]
        return heights[index]
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
}

#Preview {
    ZStack {
        Color.gray
        VStack {
            CallTopBar(
                callerName: "Sarah Miller",
                callDuration: 263,
                isConnected: true,
                remoteConnectionQuality: .good
            )
            Spacer()
        }
    }
}
#endif

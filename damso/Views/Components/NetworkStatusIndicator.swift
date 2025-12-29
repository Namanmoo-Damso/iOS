import SwiftUI
#if canImport(LiveKit)
import LiveKit

// MARK: - 내 네트워크 타입 + 품질 인디케이터
struct MyNetworkIndicator: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    let connectionQuality: ConnectionQuality

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)

            ConnectionQualityIndicator(quality: connectionQuality)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.75))
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch networkMonitor.connectionType {
        case .wifi:
            return "wifi"
        case .cellular:
            return "cellularbars"
        case .wired:
            return "cable.connector"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        networkMonitor.isConnected ? .white : .red
    }
}

// MARK: - 상대방 연결 품질 인디케이터
struct ConnectionQualityIndicator: View {
    let quality: ConnectionQuality

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
            }
        }
        .frame(height: 14)
    }

    private func barHeight(for index: Int) -> CGFloat {
        switch index {
        case 0: return 6
        case 1: return 10
        case 2: return 14
        default: return 6
        }
    }

    private func barColor(for index: Int) -> Color {
        let activeCount = activeBars
        if index < activeCount {
            return qualityColor
        }
        return Color.white.opacity(0.35)
    }

    private var activeBars: Int {
        switch quality {
        case .excellent: return 3
        case .good: return 2
        case .poor: return 1
        case .lost: return 0
        default: return 2
        }
    }

    private var qualityColor: Color {
        switch quality {
        case .excellent: return .green
        case .good: return .yellow
        case .poor: return .orange
        case .lost: return .red
        default: return .cyan
        }
    }
}

// MARK: - 참가자 네트워크 상태 뷰
struct ParticipantNetworkStatus: View {
    let name: String
    let quality: ConnectionQuality

    var body: some View {
        HStack(spacing: 6) {
            ConnectionQualityIndicator(quality: quality)

            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.75))
        .clipShape(Capsule())
    }
}

// MARK: - 통화 중 네트워크 상태 오버레이
struct CallNetworkStatusOverlay: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    let localQuality: ConnectionQuality
    let remoteParticipants: [RemoteParticipant]

    var body: some View {
        VStack {
            HStack {
                // 내 네트워크 타입 + 품질
                MyNetworkIndicator(connectionQuality: localQuality)

                Spacer()

                // 상대방 연결 품질
                ForEach(remoteParticipants.prefix(3), id: \.sid) { participant in
                    let name = participant.name ?? participant.identity?.stringValue ?? "Guest"
                    ParticipantNetworkStatus(
                        name: String(name.prefix(8)),
                        quality: participant.connectionQuality
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()
        }
    }
}
#endif

import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct VideoStageView: View {
    let remoteVideos: [RemoteVideoItem]
    let localTrack: VideoTrack?
    let isConnected: Bool
    let isRemoteVideoVisible: Bool
    let isCameraEnabled: Bool
    let remoteParticipantsCount: Int

    var body: some View {
        ZStack(alignment: .center) {
            // 1. 메인 화면 로직 개선
            if !isConnected {
                // 연결되지 않은 경우 무조건 대기/연결 중 화면
                WaitingView(isConnected: isConnected)
            } else if let firstRemote = remoteVideos.first {
                // 연결되었고 비디오 트랙이 있는 경우
                if isRemoteVideoVisible {
                    VideoTileView(track: firstRemote.track, label: firstRemote.name, mirrorMode: .off)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RemoteHiddenView()
                }
            } else if remoteParticipantsCount > 0 {
                // 연결되었고 참가자는 있지만 비디오가 없는 경우
                AudioOnlyView()
            } else {
                // 연결되었지만 혼자 있는 경우
                WaitingView(isConnected: isConnected)
            }

            // 2. 로컬 비디오 (우측 상단 오버레이)
            if let localTrack, isCameraEnabled {
                VStack {
                    HStack {
                        Spacer()
                        VideoTileView(track: localTrack, label: "You", mirrorMode: .mirror)
                            .frame(width: 120, height: 170)
                            .padding(12)
                            .shadow(radius: 5)
                    }
                    Spacer()
                }
            }
        }
    }
}

// 하위 뷰 분리
struct RemoteHiddenView: View {
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Remote Video Hidden")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AudioOnlyView: View {
    var body: some View {
        ZStack {
            Color(hex: "1C1C1E") // 다크 그레이 배경
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.gray)
                    .symbolEffect(.pulse) // 말할 때 효과 주면 좋음 (추후 개선)
                
                Text("상대방과 연결됨")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Text("카메라가 꺼져 있습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct WaitingView: View {
    let isConnected: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
            VStack(spacing: 12) {
                Image(systemName: isConnected ? "person.2.slash" : "network.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.8))
                    .symbolEffect(.pulse, isActive: isConnected)
                
                Text(isConnected ? "참가자 대기 중..." : "연결되지 않음")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct VideoTileView: View {
    let track: VideoTrack
    let label: String
    let mirrorMode: VideoView.MirrorMode

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: mirrorMode)
                .background(Color.black)
                .clipped()

            Text(label)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct RemoteVideoItem: Identifiable {
    let id: String
    let name: String
    let track: VideoTrack
}
#endif

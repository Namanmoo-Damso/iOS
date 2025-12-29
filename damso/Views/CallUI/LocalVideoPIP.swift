import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct LocalVideoPIP: View {
    let track: VideoTrack?
    let isCameraEnabled: Bool
    let isMicEnabled: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let track, isCameraEnabled {
                SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: .mirror)
                    .background(Color.black)
            } else {
                // Camera off placeholder
                ZStack {
                    Color(hex: "2C2C2E")

                    VStack(spacing: 8) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))

                        Text("카메라 꺼짐")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            // Mute indicator
            if !isMicEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(8)
            }
        }
        .frame(width: 200, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        Color.gray
        LocalVideoPIP(
            track: nil,
            isCameraEnabled: false,
            isMicEnabled: false
        )
    }
}
#endif

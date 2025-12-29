import SwiftUI

struct CallControlBar: View {
    let isMicEnabled: Bool
    let isCameraEnabled: Bool
    let isSpeakerEnabled: Bool
    let isRemoteVideoVisible: Bool
    let canSwitchCamera: Bool

    let onToggleMic: () -> Void
    let onToggleCamera: () -> Void
    let onEndCall: () -> Void
    let onFlipCamera: () -> Void
    let onToggleSpeaker: () -> Void
    let onToggleRemoteVideo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Control buttons
            HStack(spacing: 16) {
                // Microphone button
                CallControlButton(
                    icon: isMicEnabled ? "mic.fill" : "mic.slash.fill",
                    isActive: isMicEnabled,
                    activeColor: .white.opacity(0.2),
                    inactiveColor: .white.opacity(0.2),
                    iconColor: isMicEnabled ? .white : .red,
                    action: onToggleMic
                )

                // Camera button
                CallControlButton(
                    icon: isCameraEnabled ? "video.fill" : "video.slash.fill",
                    isActive: isCameraEnabled,
                    activeColor: Color.blue,
                    inactiveColor: .white.opacity(0.2),
                    iconColor: .white,
                    action: onToggleCamera
                )

                // End call button
                CallControlButton(
                    icon: "phone.down.fill",
                    isActive: true,
                    activeColor: Color.red,
                    inactiveColor: Color.red,
                    iconColor: .white,
                    size: 60,
                    action: onEndCall
                )

                // Flip camera button
                CallControlButton(
                    icon: "arrow.triangle.2.circlepath.camera",
                    isActive: true,
                    activeColor: .white.opacity(0.2),
                    inactiveColor: .white.opacity(0.15),
                    iconColor: canSwitchCamera ? .white : .white.opacity(0.4),
                    action: onFlipCamera
                )
                .disabled(!canSwitchCamera)

                // Speaker button
                CallControlButton(
                    icon: isSpeakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    isActive: isSpeakerEnabled,
                    activeColor: .white.opacity(0.2),
                    inactiveColor: .white.opacity(0.2),
                    iconColor: isSpeakerEnabled ? .white : .orange,
                    action: onToggleSpeaker
                )

                // Remote video toggle button
                CallControlButton(
                    icon: isRemoteVideoVisible ? "eye.fill" : "eye.slash.fill",
                    isActive: isRemoteVideoVisible,
                    activeColor: .white.opacity(0.2),
                    inactiveColor: .white.opacity(0.2),
                    iconColor: isRemoteVideoVisible ? .white : .orange,
                    action: onToggleRemoteVideo
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }
}

struct CallControlButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    let iconColor: Color
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isActive ? activeColor : inactiveColor)
                )
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        VStack {
            Spacer()
            CallControlBar(
                isMicEnabled: true,
                isCameraEnabled: true,
                isSpeakerEnabled: true,
                isRemoteVideoVisible: true,
                canSwitchCamera: true,
                onToggleMic: {},
                onToggleCamera: {},
                onEndCall: {},
                onFlipCamera: {},
                onToggleSpeaker: {},
                onToggleRemoteVideo: {}
            )
        }
    }
}

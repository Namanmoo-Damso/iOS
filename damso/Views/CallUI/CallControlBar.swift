import SwiftUI

struct CallControlBar: View {
    let isMicEnabled: Bool
    let isSpeakerEnabled: Bool
    var isCameraEnabled: Bool = false
    var showCameraButton: Bool = true

    let onToggleMic: () -> Void
    let onEndCall: () -> Void
    let onToggleSpeaker: () -> Void
    var onToggleCamera: (() -> Void)? = nil

    // 배경색 (완전 불투명 블랙)
    private let backgroundColor = Color.black

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        // 버튼 크기
        let buttonSize = screenWidth * 0.14
        // 종료 버튼은 약간 더 크게
        let endButtonSize = screenWidth * 0.154
        // 버튼 간 간격
        let buttonSpacing = screenWidth * 0.03
        // 버튼 영역 패딩 (상하 동일하게)
        let buttonPadding = screenWidth * 0.024

        VStack(spacing: 0) {
            // 컨트롤 버튼 영역
            HStack(spacing: buttonSpacing) {
                // Microphone button
                LabeledCallButton(
                    icon: isMicEnabled ? "mic.fill" : "mic.slash.fill",
                    label: "마이크",
                    isActive: isMicEnabled,
                    activeColor: .white.opacity(0.2),
                    iconColor: isMicEnabled ? .white : .red,
                    size: buttonSize,
                    action: onToggleMic
                )

                // Speaker button (AI 음성)
                LabeledCallButton(
                    icon: isSpeakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    label: "AI 음성",
                    isActive: isSpeakerEnabled,
                    activeColor: .white.opacity(0.2),
                    iconColor: isSpeakerEnabled ? .white : .orange,
                    size: buttonSize,
                    action: onToggleSpeaker
                )

                // End call button
                LabeledCallButton(
                    icon: "phone.down.fill",
                    label: "종료",
                    isActive: true,
                    activeColor: Color.red,
                    iconColor: .white,
                    size: endButtonSize,
                    action: onEndCall
                )

                // Camera button
                if let onToggleCamera = onToggleCamera {
                    LabeledCallButton(
                        icon: isCameraEnabled ? "video.fill" : "video.slash.fill",
                        label: "카메라",
                        isActive: isCameraEnabled,
                        activeColor: .white.opacity(0.2),
                        iconColor: isCameraEnabled ? .white : .yellow,
                        size: buttonSize,
                        action: onToggleCamera
                    )
                }
            }
            .padding(.top, buttonPadding)
            .padding(.bottom, buttonPadding)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
        }
    }
}


/// 레이블이 있는 통화 컨트롤 버튼
struct LabeledCallButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let iconColor: Color
    var size: CGFloat = 48
    let action: () -> Void

    // 레이블 크기는 버튼 크기에 비례
    private var labelSize: CGFloat {
        max(size * 0.22, 10)  // 최소 10pt
    }

    // 아이콘과 레이블 간격도 비례
    private var spacing: CGFloat {
        size * 0.12
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: spacing) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.40, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(activeColor)
                    )

                Text(label)
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
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


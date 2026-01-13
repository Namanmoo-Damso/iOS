//
//  FullScreenIncomingCallView.swift
//  damso
//
//  Created by Claude Code on 2026-01-10.
//

import SwiftUI

/// 전체화면 수신 전화 UI (CallKit 대체용)
struct FullScreenIncomingCallView: View {
    let callerName: String
    let callerImageName: String?
    let hasVideo: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    // 애니메이션 상태
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var avatarScale: CGFloat = 1.0
    @State private var isAppearing: Bool = false

    // 배경 색상
    private let backgroundColor = Color(red: 0.33, green: 0.42, blue: 0.27)  // #556B45
    private let acceptButtonColor = Color(red: 0.42, green: 0.56, blue: 0.42)  // #6B8F6B
    private let declineButtonColor = Color.white.opacity(0.15)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 배경 그라디언트
                backgroundGradient

                // 중앙 Glow 효과
                centerGlow(geometry: geometry)

                // 메인 컨텐츠
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.safeAreaInsets.top + 60)

                    // 상단 뱃지
                    callTypeBadge
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : -20)

                    // 발신자 이름
                    Text(callerName)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : -10)

                    // 상태 텍스트
                    Text("연결을 기다리고 있어요...")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)
                        .opacity(isAppearing ? 1 : 0)

                    Spacer()

                    // 아바타
                    avatarView(size: min(geometry.size.width * 0.55, 240))
                        .scaleEffect(isAppearing ? 1 : 0.8)
                        .opacity(isAppearing ? 1 : 0)

                    Spacer()

                    // 하단 버튼
                    bottomButtons
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 60)
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 30)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            backgroundColor

            // 비네트 효과 (가장자리 어둡게)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.4)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
        }
    }

    private func centerGlow(geometry: GeometryProxy) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.5
                )
            )
            .frame(width: geometry.size.width, height: geometry.size.width)
            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.45)
    }

    // MARK: - Call Type Badge

    private var callTypeBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: hasVideo ? "video.fill" : "phone.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(hasVideo ? "영상통화 요청" : "음성통화 요청")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.25))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.85))
        )
    }

    // MARK: - Avatar

    private func avatarView(size: CGFloat) -> some View {
        ZStack {
            // Outer glow ring (pulsing)
            Circle()
                .stroke(acceptButtonColor.opacity(glowOpacity), lineWidth: 3)
                .frame(width: size + 30, height: size + 30)
                .scaleEffect(pulseScale)

            // Avatar container
            Circle()
                .fill(Color.white)
                .frame(width: size + 8, height: size + 8)
                .shadow(color: acceptButtonColor.opacity(0.3), radius: 20, x: 0, y: 0)

            // Avatar image
            if let imageName = callerImageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .scaleEffect(avatarScale)
            } else {
                // 기본 아바타 - 소담이 캐릭터 이미지 사용
                Image("damso")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .scaleEffect(avatarScale)
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 60) {
            // 거절 버튼
            VStack(spacing: 12) {
                Button(action: onDecline) {
                    ZStack {
                        // Glow background
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .blur(radius: 10)

                        Circle()
                            .fill(declineButtonColor)
                            .frame(width: 72, height: 72)

                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                Text("거절하기")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }

            // 수락 버튼
            VStack(spacing: 12) {
                Button(action: onAccept) {
                    ZStack {
                        // Pulse glow ring
                        Circle()
                            .stroke(acceptButtonColor.opacity(glowOpacity * 0.5), lineWidth: 2)
                            .frame(width: 90, height: 90)
                            .scaleEffect(pulseScale)

                        // Glow background
                        Circle()
                            .fill(acceptButtonColor.opacity(0.3))
                            .frame(width: 85, height: 85)
                            .blur(radius: 10)

                        Circle()
                            .fill(acceptButtonColor)
                            .frame(width: 72, height: 72)

                        Image(systemName: "phone.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                Text("통화 받기")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // 등장 애니메이션
        withAnimation(.easeOut(duration: 0.5)) {
            isAppearing = true
        }

        // Pulse glow 애니메이션
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.15
            glowOpacity = 0.6
        }

        // 아바타 breathing 애니메이션
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            avatarScale = 1.02
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
struct FullScreenIncomingCallView_Previews: PreviewProvider {
    static var previews: some View {
        FullScreenIncomingCallView(
            callerName: "소담이가",
            callerImageName: nil,
            hasVideo: true,
            onAccept: {},
            onDecline: {}
        )
    }
}
#endif

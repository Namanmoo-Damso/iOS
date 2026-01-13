//
//  CallBackgroundViews.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import SwiftUI
#if canImport(LiveKit)
import LiveKit

/// 연결 대기 중 배경 뷰
struct WaitingCallBackground: View {
    let isConnected: Bool
    let isBusy: Bool

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 20) {
                Image(systemName: isConnected ? "person.2.slash" : "network.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.5))
                    .symbolEffect(.pulse, isActive: isConnected)

                Text(isConnected ? "참가자 대기 중..." : "연결 중...")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))

                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
        }
    }
}

/// 원격 비디오 숨김 상태 배경 뷰
struct RemoteVideoHiddenBackground: View {
    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 12) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.5))

                Text("상대방 비디오 숨김")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))

                Text("하단 버튼을 눌러 다시 표시")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

/// AI 대사 전용 말풍선 (노인 배려 큰 글씨, 동적 높이 + 상한 시 폰트 축소)
struct AIChatBubbleView: View {
    let text: String
    let isFinal: Bool
    var screenWidth: CGFloat = 768
    var screenHeight: CGFloat = 1024

    private let baseWidth: CGFloat = 768
    private let baseHeight: CGFloat = 1024

    /// 캐릭터 비디오 높이 계산
    private var videoHeight: CGFloat {
        let videoWidth = screenWidth * 0.95
        let videoAspectRatio: CGFloat = 896.0 / 1024.0
        return videoWidth / videoAspectRatio
    }

    /// 최대 bubble 높이 (캐릭터 높이의 40%)
    private var maxBubbleHeight: CGFloat {
        videoHeight * 0.40
    }

    /// 폰트 크기 상대값 (0.8~1.3배 제한)
    private func relativeFontSize(_ baseSize: CGFloat) -> CGFloat {
        let scale = screenWidth / baseWidth
        let clampedScale = min(max(scale, 0.8), 1.3)
        return baseSize * clampedScale
    }

    /// 너비 기준 패딩 상대값
    private func relativeW(_ value: CGFloat) -> CGFloat {
        value * (screenWidth / baseWidth)
    }

    /// 높이 기준 패딩 상대값
    private func relativeH(_ value: CGFloat) -> CGFloat {
        value * (screenHeight / baseHeight)
    }

    var body: some View {
        // 대사 텍스트 (노인 배려 큰 글씨 - 64pt 기준)
        // 캐릭터 높이의 40%까지 동적 확장, 초과 시 폰트 축소
        Text(displayText)
            .font(.system(size: relativeFontSize(64), weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.3)
            .padding(.horizontal, relativeW(32))
            .padding(.vertical, relativeH(28))
            .frame(maxWidth: .infinity, maxHeight: maxBubbleHeight)
            .background(
                RoundedRectangle(cornerRadius: relativeW(24), style: .continuous)
                    .fill(Color(hex: "3A3B3C").opacity(0.75))
            )
            .opacity(isFinal ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: text)
    }

    private var displayText: String {
        // 따옴표로 감싸기
        let cleanText = isFinal ? text : "\(text)..."
        return "\"\(cleanText)\""
    }
}

/// 통화 화면 대사 말풍선
struct CallSubtitleBubble: View {
    let text: String
    let isAgent: Bool
    let isFinal: Bool
    var screenWidth: CGFloat = 768  // 기본값: iPad mini 6

    // 기준 화면 너비 (iPad mini 6)
    private let baseWidth: CGFloat = 768

    private var bubbleColor: Color {
        if isAgent {
            return Color(hex: "4A90D9")  // AI: 파란색
        } else {
            return Color(hex: "FF7B54")  // 사용자: 코랄 오렌지
        }
    }

    /// 상대값 계산
    private func relative(_ value: CGFloat) -> CGFloat {
        value * (screenWidth / baseWidth)
    }

    /// 폰트 크기 상대값 (0.7~1.5배 제한)
    private func relativeFontSize(_ baseSize: CGFloat) -> CGFloat {
        let scale = screenWidth / baseWidth
        let clampedScale = min(max(scale, 0.7), 1.5)
        return baseSize * clampedScale
    }

    var body: some View {
        // 말풍선만 표시 (이름 제거)
        Text(displayText)
            .font(.system(size: relativeFontSize(26), weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(isAgent ? .leading : .trailing)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, relative(18))
            .padding(.vertical, relative(14))
            .background(
                RoundedRectangle(cornerRadius: relative(20), style: .continuous)
                    .fill(bubbleColor)
            )
            .opacity(isFinal ? 1.0 : 0.8)
    }

    private var displayText: String {
        isFinal ? text : "\(text)..."
    }
}

/// 통화 화면 대사 뷰 (이전 호환성)
struct CallSubtitleView: View {
    let text: String
    let highlightText: String

    var body: some View {
        CallSubtitleBubble(text: text, isAgent: true, isFinal: true)
    }
}

/// 재연결 중 오버레이
struct ReconnectingOverlay: View {
    let timeRemaining: Int
    let onEndCall: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("연결 복구 중...")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("\(timeRemaining)초 후 자동 종료")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))

                Button("지금 종료") {
                    onEndCall()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.8))
                .clipShape(Capsule())
                .padding(.top, 8)
            }
        }
    }
}

/// 상대방 연결 끊김 오버레이
struct RemoteDisconnectedOverlay: View {
    let timeRemaining: Int
    let onEndCall: () -> Void

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "person.slash.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("상대방 연결이 불안정합니다")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text("\(timeRemaining)초 후 통화 종료")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Button("종료") {
                    onEndCall()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .clipShape(Capsule())
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
            .padding(.bottom, 140)
        }
    }
}

#endif

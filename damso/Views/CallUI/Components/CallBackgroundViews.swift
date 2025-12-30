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

/// 음성 통화 전용 배경 뷰
struct AudioOnlyCallBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "1C1C1E")

            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.gray)
                    .symbolEffect(.pulse)

                Text("음성 통화 중")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text("상대방 카메라가 꺼져 있습니다")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
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

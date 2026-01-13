import SwiftUI

/// 전체화면 전화 수신 UI
struct IncomingCallFullScreenView: View {
    let caller: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            ZStack {
                // 배경 그라데이션 (deepMoss 계열)
                LinearGradient(
                    colors: [
                        Color(hex: "4A5D4A"),
                        Color(hex: "3D4D3D"),
                        Color(hex: "2E3E2E")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: screenHeight * 0.08)

                    // 상단 배지
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 12))
                        Text("영상통화 요청")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )

                    // 이름
                    Text("소담이")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 16)

                    // 상태 텍스트
                    Text("연결을 기다리고 있어요...")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    Spacer()
                        .frame(height: screenHeight * 0.05)

                    // 캐릭터 이미지
                    ZStack {
                        // 글로우 효과
                        Circle()
                            .fill(Color.damsoGreen.opacity(0.3))
                            .frame(width: screenWidth * 0.6, height: screenWidth * 0.6)
                            .blur(radius: 30)

                        // 흰색 배경 원
                        Circle()
                            .fill(Color.white)
                            .frame(width: screenWidth * 0.55, height: screenWidth * 0.55)
                            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

                        // 캐릭터 이미지
                        Image("damso")
                            .resizable()
                            .scaledToFill()
                            .frame(width: screenWidth * 0.5, height: screenWidth * 0.5)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // 하단 버튼들
                    HStack(spacing: screenWidth * 0.2) {
                        // 거절 버튼
                        VStack(spacing: 12) {
                            Button(action: onDecline) {
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: "3A3A3C"))
                                    )
                            }

                            Text("거절하기")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // 수락 버튼
                        VStack(spacing: 12) {
                            Button(action: onAccept) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(
                                        Circle()
                                            .fill(Color.damsoGreen)
                                    )
                            }

                            Text("통화 받기")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.bottom, screenHeight * 0.1)
                }
            }
        }
    }
}

/// 배너 스타일 전화 수신 UI (하위 호환성)
struct IncomingCallBanner: View {
    let caller: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // 캐릭터 이미지
            Image("damso")
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("영상통화 요청")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("소담이")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Spacer()

            // 거절 버튼
            Button(action: onDecline) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(hex: "3A3A3C")))
            }

            // 수락 버튼
            Button(action: onAccept) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.damsoGreen))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "3D4D3D").opacity(0.95))
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .padding(.horizontal)
    }
}

#Preview("전체화면 전화 수신") {
    IncomingCallFullScreenView(
        caller: "소담이",
        onAccept: {},
        onDecline: {}
    )
}

#Preview("배너 전화 수신") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            IncomingCallBanner(
                caller: "소담이",
                onAccept: {},
                onDecline: {}
            )
            .padding(.top, 60)
            Spacer()
        }
    }
}

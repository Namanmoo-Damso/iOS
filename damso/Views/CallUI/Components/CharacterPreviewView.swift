//
//  CharacterPreviewView.swift
//  damso
//
//  캐릭터 위치/크기를 확인하기 위한 UI 테스트용 프리뷰 뷰
//  실제 통화 화면 UI와 함께 캐릭터를 표시
//

import SwiftUI
import AVFoundation

/// 실제 통화 화면 UI와 함께 캐릭터 프레임을 표시하는 프리뷰 뷰
struct CharacterPreviewView: View {
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    @State private var bottomOverlayHeight: CGFloat = 0

    let videoName: String
    let videoExtension: String

    init(videoName: String = "listening_final", videoExtension: String = "mov") {
        self.videoName = videoName
        self.videoExtension = videoExtension
    }

    var body: some View {
        ZStack {
            // 배경: 캐릭터 + 채팅 영역 (AudioOnlyCallBackground와 동일 레이아웃)
            characterBackground
                .ignoresSafeArea()

            // UI 오버레이 (FullScreenCallView와 동일)
            VStack(spacing: 0) {
                // 상단 영역
                ZStack(alignment: .top) {
                    // 중앙 - 이름 및 통화시간
                    CallTopBar(
                        callerName: "소담이",
                        callDuration: 125,  // 2:05 예시
                        isConnected: true,
                        remoteConnectionQuality: .excellent
                    )

                    // 좌상단 - 듣는중/말하는중 상태
                    HStack {
                        SpeakingStatusIndicator(status: .listening)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                        Spacer()
                    }

                    // 우상단 - 내 영상 PIP + 네트워크 상태
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            LocalVideoPIP(
                                track: nil,
                                isCameraEnabled: false,
                                isMicEnabled: true,
                                isCompact: true
                            )

                            // 내 네트워크 상태 표시 (테스트용 더미)
                            MyNetworkStatusView(
                                connectionQuality: .excellent,
                                connectionType: .wifi
                            )
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                }

                Spacer()

                // 하단 컨트롤 바
                CallControlBar(
                    isMicEnabled: true,
                    isSpeakerEnabled: true,
                    isCameraEnabled: false,
                    onToggleMic: {},
                    onEndCall: {},
                    onToggleSpeaker: {},
                    onToggleCamera: {}
                )
                .background(Color.black)
                .overlay(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: PreviewBottomHeightKey.self, value: proxy.size.height)
                    }
                )
            }
        }
        .statusBar(hidden: true)
        .onPreferenceChange(PreviewBottomHeightKey.self) { newValue in
            bottomOverlayHeight = newValue
        }
        .onAppear {
            extractThumbnail()
        }
    }

    // MARK: - 캐릭터 배경 (AudioOnlyCallBackground 레이아웃 재현)

    private var characterBackground: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            ZStack {
                // 배경색
                Color(hex: "E8E4DF")

                // 캐릭터 이미지 (하단을 dock 상단에 맞춤)
                VStack(spacing: 0) {
                    Spacer()

                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: screenWidth * 0.95, height: screenHeight * 0.70)
                            .clipped()
                    } else if isLoading {
                        ProgressView()
                            .frame(width: screenWidth * 0.95, height: screenHeight * 0.70)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: screenWidth * 0.95, height: screenHeight * 0.70)
                            .overlay(
                                Text("비디오 로드 실패")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .padding(.bottom, bottomOverlayHeight)

                // 예시 채팅 메시지
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        // AI 메시지
                        HStack {
                            sampleBubble(text: "안녕하세요, 소담이에요!", isAgent: true)
                            Spacer()
                        }

                        // 사용자 메시지
                        HStack {
                            Spacer()
                            sampleBubble(text: "안녕 소담아", isAgent: false)
                        }

                        // AI 진행 중
                        HStack {
                            sampleBubble(text: "오늘 하루는 어떠셨어요?", isAgent: true)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomOverlayHeight + 20)
                }
            }
        }
    }

    // MARK: - 샘플 말풍선

    private func sampleBubble(text: String, isAgent: Bool) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isAgent ? Color(hex: "4A90D9") : Color(hex: "FF7B54"))
            )
    }

    // MARK: - 비디오 썸네일 추출

    private func extractThumbnail() {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            isLoading = false
            return
        }

        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 0, preferredTimescale: 600)

        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                await MainActor.run {
                    thumbnailImage = UIImage(cgImage: cgImage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - PreferenceKey

private struct PreviewBottomHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
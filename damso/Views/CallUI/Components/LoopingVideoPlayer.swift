//
//  LoopingVideoPlayer.swift
//  damso
//
//  무한 반복 재생되는 비디오 플레이어
//

import SwiftUI
import AVFoundation
import AVKit

/// 듣기/말하기 두 상태의 비디오를 미리 로드하고 부드럽게 전환하는 플레이어
struct DualStateVideoPlayer: View {
    let isAISpeaking: Bool
    let listeningVideoName: String
    let talkingVideoName: String
    let videoExtension: String

    init(
        isAISpeaking: Bool,
        listeningVideoName: String = "listening_final",
        talkingVideoName: String = "talking_final",
        videoExtension: String = "mov"
    ) {
        self.isAISpeaking = isAISpeaking
        self.listeningVideoName = listeningVideoName
        self.talkingVideoName = talkingVideoName
        self.videoExtension = videoExtension
    }

    var body: some View {
        ZStack {
            // 배경색 (번쩍임 방지)
            Color(hex: "E8E4DF")

            // 듣기 비디오 (항상 로드됨)
            LoopingVideoPlayer(videoName: listeningVideoName, videoExtension: videoExtension)
                .opacity(isAISpeaking ? 0 : 1)

            // 말하기 비디오 (항상 로드됨)
            LoopingVideoPlayer(videoName: talkingVideoName, videoExtension: videoExtension)
                .opacity(isAISpeaking ? 1 : 0)
        }
    }
}

/// 무한 반복 비디오 플레이어 뷰
struct LoopingVideoPlayer: View {
    let videoName: String
    let videoExtension: String

    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var videoNotFound: Bool = false

    init(videoName: String, videoExtension: String = "mov") {
        self.videoName = videoName
        self.videoExtension = videoExtension
    }

    var body: some View {
        Group {
            if videoNotFound {
                // 비디오 없을 때 대체 뷰
                fallbackView
            } else {
                VideoPlayerView(player: player)
                    .background(Color.clear)
            }
        }
        .background(Color.clear)
        .onAppear {
            #if DEBUG
            print("🎬 [VideoPlayer] onAppear - videoName: \(videoName)")
            #endif
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "7B61FF"), Color(hex: "00D4FF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "waveform")
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private func setupPlayer() {
        // 기존 플레이어 정리
        cleanupPlayer()

        // 비디오 파일 찾기 (대소문자 모두 시도)
        var url = Bundle.main.url(forResource: videoName, withExtension: videoExtension)

        // 소문자 확장자도 시도
        if url == nil {
            url = Bundle.main.url(forResource: videoName, withExtension: videoExtension.lowercased())
        }

        // 대문자 파일명도 시도
        if url == nil {
            url = Bundle.main.url(forResource: videoName.capitalized, withExtension: videoExtension)
        }

        guard let videoURL = url else {
            print("❌ [VideoPlayer] Video not found: \(videoName).\(videoExtension)")
            print("❌ [VideoPlayer] Bundle path: \(Bundle.main.bundlePath)")
            // 번들 내 모든 MP4 파일 출력
            if let resourcePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                    let mp4Files = files.filter { $0.lowercased().hasSuffix(".mp4") }
                    print("❌ [VideoPlayer] Available MP4 files: \(mp4Files)")
                }
            }
            videoNotFound = true
            return
        }

        #if DEBUG
        print("🎬 [VideoPlayer] Loading video from: \(videoURL)")
        #endif

        videoNotFound = false
        let asset = AVURLAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)

        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = true  // 비디오 소리 음소거 (오디오는 별도)

        // 무한 반복 설정
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        self.player = queuePlayer
        self.playerLooper = looper

        queuePlayer.play()
    }

    private func cleanupPlayer() {
        player?.pause()
        player?.removeAllItems()
        playerLooper?.disableLooping()
        player = nil
        playerLooper = nil
    }
}

/// AVPlayer를 SwiftUI에서 표시하기 위한 UIViewRepresentable (알파 지원)
struct VideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer?

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

/// AVPlayerLayer를 호스팅하는 UIView (알파 채널 지원)
class PlayerUIView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupForAlphaVideo()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupForAlphaVideo() {
        // 뷰 투명 설정
        backgroundColor = .clear
        isOpaque = false

        // 레이어 투명 설정
        layer.isOpaque = false
        layer.backgroundColor = UIColor.clear.cgColor

        // AVPlayerLayer 설정 (원본 비율 유지)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.isOpaque = false
    }
}
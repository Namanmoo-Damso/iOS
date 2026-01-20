import SwiftUI
#if canImport(LiveKit)
import LiveKit

struct LocalVideoPIP: View {
    let track: VideoTrack?
    let isCameraEnabled: Bool
    let isMicEnabled: Bool
    var isCompact: Bool = false

    /// 확대 모드 바인딩 (nil이면 터치 비활성화)
    @Binding var isExpanded: Bool

    /// 메쉬 표시 여부 (확대 시에만 활성화)
    @Binding var showMesh: Bool

    /// Face Landmark Detector
    @ObservedObject private var landmarkDetector = FaceLandmarkDetector.shared

    // 기준 화면 너비 (iPad mini 6)
    private let baseWidth: CGFloat = 768

    /// 초기화 - 기본값 포함
    init(
        track: VideoTrack?,
        isCameraEnabled: Bool,
        isMicEnabled: Bool,
        isCompact: Bool = false,
        isExpanded: Binding<Bool> = .constant(false),
        showMesh: Binding<Bool> = .constant(false)
    ) {
        self.track = track
        self.isCameraEnabled = isCameraEnabled
        self.isMicEnabled = isMicEnabled
        self.isCompact = isCompact
        self._isExpanded = isExpanded
        self._showMesh = showMesh
    }

    /// 상대값 계산
    private func relative(_ value: CGFloat, screenWidth: CGFloat) -> CGFloat {
        value * (screenWidth / baseWidth)
    }

    /// PIP 크기 계산 (가로: 화면의 1/3 * 0.8, 세로: 4:3 비율)
    private func calculateSize(screenWidth: CGFloat, isExpanded: Bool) -> CGSize {
        if isExpanded {
            // 확대 시: 화면의 70% 너비, 4:3 비율
            let width = screenWidth * 0.7
            let height = width * 4 / 3
            return CGSize(width: width, height: height)
        } else {
            let width = screenWidth / 3 * 0.8  // 80%로 축소
            let height = width * 4 / 3  // 4:3 비율
            return CGSize(width: width, height: height)
        }
    }

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let pipSize = calculateSize(screenWidth: screenWidth, isExpanded: isExpanded)

        // PIP 영상
        ZStack(alignment: .topLeading) {
            if let track, isCameraEnabled {
                ZStack {
                    SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: .mirror)
                        .background(Color.black)

                    // 확대 모드 + 메쉬 활성화 시 오버레이
                    if isExpanded && showMesh && landmarkDetector.isFaceDetected {
                        FaceMeshOverlayView(
                            landmarks: landmarkDetector.currentLandmarks,
                            showMesh: false,  // 점만 표시해서 좌우 대칭 테스트
                            showPoints: true,
                            meshColor: .yellow,
                            pointColor: .yellow,
                            meshLineWidth: 1.5,
                            pointSize: 5,
                            videoFrameSize: landmarkDetector.videoFrameSize
                        )
                        // 비디오가 .mirror 모드이므로 오버레이도 미러링
                        .scaleEffect(x: -1, y: 1)
                        // 랜드마크 변경 시 Canvas 강제 리드로우
                        .id(landmarkDetector.updateCounter)
                    }
                }
            } else {
                // Camera off placeholder
                ZStack {
                    Color(hex: "2A3441")

                    Image(systemName: "person.fill")
                        .font(.system(size: pipSize.width * 0.3))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // 상단 오버레이
            VStack {
                HStack {
                    // Mute indicator
                    if !isMicEnabled {
                        HStack(spacing: relative(4, screenWidth: screenWidth)) {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: relative(10, screenWidth: screenWidth)))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, relative(6, screenWidth: screenWidth))
                        .padding(.vertical, relative(4, screenWidth: screenWidth))
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: relative(4, screenWidth: screenWidth)))
                    }

                    Spacer()

                    // 확대 모드에서 메쉬 상태 표시
                    if isExpanded && showMesh {
                        HStack(spacing: 4) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 12))
                            Text("MESH")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(relative(6, screenWidth: screenWidth))

                Spacer()

                // 확대 모드에서 FPS 표시
                if isExpanded && showMesh {
                    HStack {
                        Spacer()
                        Text("\(Int(landmarkDetector.currentFPS)) FPS")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                }
            }

            // 확대 모드에서 닫기/토글 안내
            if isExpanded {
                VStack {
                    Spacer()
                    HStack {
                        Text("탭하여 닫기")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: pipSize.width, height: pipSize.height)
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 20 : relative(12, screenWidth: screenWidth), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 20 : relative(12, screenWidth: screenWidth), style: .continuous)
                .stroke(isExpanded && showMesh ? Color.yellow.opacity(0.5) : Color.white.opacity(0.2), lineWidth: isExpanded ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.3), radius: isExpanded ? 20 : relative(8, screenWidth: screenWidth), x: 0, y: relative(4, screenWidth: screenWidth))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if isExpanded {
                    // 확대 → 축소: 메쉬 끄고 축소
                    showMesh = false
                    isExpanded = false
                    
                    // Note: 감정 분석을 위해 축소 상태에서도 랜드마크 검출은 유지합니다.
                } else {
                    // 축소 → 확대: 확대하고 메쉬 켜기
                    isExpanded = true
                    showMesh = true

                    // 랜드마크 검출 시작 (이미 켜져 있으면 내부에서 무시됨)
                    if let track {
                        landmarkDetector.startDetection(for: track)
                    }
                }
            }
        }
        .onAppear {
            // PIP가 표시되면 항상 랜드마크 검출 시작 (감정 분석용)
            if let track, !landmarkDetector.isDetectionEnabled {
                landmarkDetector.startDetection(for: track)
            }
        }
        .onDisappear {
            // 뷰 완전히 사라질 때만 검출 중지
            if let track, landmarkDetector.isDetectionEnabled {
                landmarkDetector.stopDetection(for: track)
            }
        }
    }
}#endif

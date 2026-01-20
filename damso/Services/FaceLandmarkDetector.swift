//
//  FaceLandmarkDetector.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//
//  VideoRenderer를 구현하여 LiveKit 비디오 프레임에서
//  Vision Framework로 얼굴 랜드마크를 실시간 검출
//

import Foundation
import Vision
import CoreImage
import Combine
import CoreGraphics

#if canImport(LiveKit)
import LiveKit

/// 얼굴 랜드마크 실시간 검출기
/// VideoRenderer 프로토콜을 구현하여 LiveKit 비디오 스트림에서 랜드마크 검출
@MainActor
final class FaceLandmarkDetector: ObservableObject {

    // MARK: - Singleton

    static let shared = FaceLandmarkDetector()

    // MARK: - Published Properties

    /// 현재 검출된 랜드마크 (정규화된 좌표)
    @Published private(set) var currentLandmarks: [CGPoint] = []

    /// 얼굴 검출 여부
    @Published private(set) var isFaceDetected: Bool = false

    /// 검출 활성화 상태
    @Published var isDetectionEnabled: Bool = false

    /// 현재 FPS
    @Published private(set) var currentFPS: Double = 0

    /// 업데이트 카운터 (SwiftUI 뷰 리드로우용)
    @Published private(set) var updateCounter: Int = 0

    /// 비디오 프레임 크기 (aspect ratio 계산용)
    @Published private(set) var videoFrameSize: CGSize = .zero

    // MARK: - Private Properties

    private let landmarksSubject = PassthroughSubject<[CGPoint], Never>()
    private var sequenceHandler = VNSequenceRequestHandler()

    // FPS 제한
    private var targetFPS: Int = 30
    private var lastProcessTime: Date = .distantPast
    private var frameCount: Int = 0
    private var fpsTimer: Timer?

    // 비디오 렌더러
    private var videoRenderer: FaceLandmarkVideoRenderer?

    // 스무딩을 위한 이전 랜드마크
    private var previousLandmarks: [CGPoint] = []
    private let smoothingFactor: CGFloat = 0.7  // 0 = 이전값 유지, 1 = 새값만 사용 (0.7로 빠른 반응)

    // MARK: - Public Properties

    var landmarksStream: AnyPublisher<[CGPoint], Never> {
        landmarksSubject.eraseToAnyPublisher()
    }

    // MARK: - Init

    private init() {
        videoRenderer = FaceLandmarkVideoRenderer { [weak self] buffer in
            // EmotionAnalyzer에 분석용 버퍼 전달 (MainActor에서 실행)
            // CVPixelBuffer는 Sendable이 아니지만, 읽기 전용 사용이므로 스레드 안전
            nonisolated(unsafe) let pixelBuffer = buffer
            Task { @MainActor in
                EmotionAnalyzer.shared.capturePixelBuffer(pixelBuffer)
            }
            
            // 백그라운드 스레드에서 Vision 처리 수행
            self?.processVideoFrameOnBackground(buffer)
        }
    }

    // MARK: - Public Methods

    /// 검출 시작 - VideoTrack에 연결
    func startDetection(for track: VideoTrack) {
        guard !isDetectionEnabled else {
            debugLog("⚠️ Detection already enabled, skipping")
            return
        }

        isDetectionEnabled = true
        startFPSCounter()

        if let renderer = videoRenderer {
            track.add(videoRenderer: renderer)
            debugLog("✅ VideoRenderer added to track: \(track)")
        } else {
            debugLog("❌ videoRenderer is nil!")
        }

        debugLog("🚀 Face landmark detection started")
    }

    /// 검출 중지
    func stopDetection(for track: VideoTrack) {
        guard isDetectionEnabled else { return }

        if let renderer = videoRenderer {
            track.remove(videoRenderer: renderer)
        }

        isDetectionEnabled = false
        stopFPSCounter()
        currentLandmarks = []
        previousLandmarks = []
        isFaceDetected = false

        debugLog("Face landmark detection stopped")
    }

    /// 검출 FPS 설정
    func setDetectionRate(_ fps: Int) {
        targetFPS = max(1, min(60, fps))
        debugLog("Detection rate set to \(targetFPS) FPS")
    }

    // MARK: - Private Methods

    /// 백그라운드 스레드에서 Vision 처리 수행 (nonisolated)
    nonisolated private func processVideoFrameOnBackground(_ pixelBuffer: CVPixelBuffer) {
        let frameWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let frameHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // 프레임이 가로(W > H)면 .right orientation 사용 → Vision 좌표는 회전된 기준
        // 따라서 저장할 크기도 회전된 크기 (width ↔ height swap)
        let isLandscapeFrame = frameWidth > frameHeight
        let effectiveSize = isLandscapeFrame
            ? CGSize(width: frameHeight, height: frameWidth)  // 회전된 크기
            : CGSize(width: frameWidth, height: frameHeight)

        // Face 로그 비활성화
        // #if DEBUG
        // print("[FaceLandmarkDetector] 📍 Processing frame - raw: \(Int(frameWidth))x\(Int(frameHeight)), effective: \(Int(effectiveSize.width))x\(Int(effectiveSize.height))")
        // #endif

        // 비디오 프레임 크기 업데이트 (Vision 좌표 기준 크기)
        Task { @MainActor [weak self] in
            self?.videoFrameSize = effectiveSize
        }

        // Vision 요청 생성
        let request = VNDetectFaceLandmarksRequest()

        // Neural Engine 가속 활성화
        #if !targetEnvironment(simulator)
        if #available(iOS 17.0, *) {
            request.revision = VNDetectFaceLandmarksRequestRevision3
        }
        #endif

        do {
            // iOS 카메라 프레임: Portrait 모드에서도 가로(landscape)로 캡처됨
            // 프레임이 가로(W > H)면 .right 사용하여 Vision이 세로로 인식하게 함
            let orientation: CGImagePropertyOrientation = frameWidth > frameHeight ? .right : .up
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
            try handler.perform([request])

            guard let observations = request.results,
                  let face = observations.first else {
                // Face 로그 비활성화
                // #if DEBUG
                // print("[FaceLandmarkDetector] 📍 No face detected")
                // #endif
                Task { @MainActor [weak self] in
                    self?.updateResults(landmarks: [], detected: false)
                }
                return
            }

            // Face 로그 비활성화
            // #if DEBUG
            // print("[FaceLandmarkDetector] 📍 Face detected! boundingBox: \(face.boundingBox)")
            // #endif

            // 랜드마크 추출 (nonisolated 함수에서 호출)
            let landmarks = extractLandmarksSync(from: face)

            // Face 로그 비활성화
            // #if DEBUG
            // print("[FaceLandmarkDetector] 📍 Extracted \(landmarks.count) landmarks")
            // #endif

            // 결과를 MainActor로 전달
            Task { @MainActor [weak self] in
                self?.updateResults(landmarks: landmarks, detected: !landmarks.isEmpty)
            }
        } catch {
            // Face 로그 비활성화
            // #if DEBUG
            // print("[FaceLandmarkDetector] Vision processing failed: \(error)")
            // #endif
        }
    }

    /// MainActor에서 결과 업데이트
    private func updateResults(landmarks: [CGPoint], detected: Bool) {
        // 스무딩 적용
        let smoothedLandmarks: [CGPoint]
        if detected && !landmarks.isEmpty {
            smoothedLandmarks = smoothLandmarks(new: landmarks)
            previousLandmarks = smoothedLandmarks
        } else {
            smoothedLandmarks = []
            previousLandmarks = []
        }

        // 명시적으로 SwiftUI에게 변경 알림 (ObservableObject)
        objectWillChange.send()

        currentLandmarks = smoothedLandmarks
        isFaceDetected = detected
        updateCounter += 1  // SwiftUI 뷰 리드로우용 카운터 증가
        if detected {
            landmarksSubject.send(smoothedLandmarks)
        }
        frameCount += 1
    }

    /// 랜드마크 스무딩 (지터 감소, 부드러운 전환)
    private func smoothLandmarks(new: [CGPoint]) -> [CGPoint] {
        guard !previousLandmarks.isEmpty,
              previousLandmarks.count == new.count else {
            return new
        }

        return zip(previousLandmarks, new).map { prev, curr in
            CGPoint(
                x: prev.x + (curr.x - prev.x) * smoothingFactor,
                y: prev.y + (curr.y - prev.y) * smoothingFactor
            )
        }
    }

    /// nonisolated 랜드마크 추출 (VNFaceObservation에서)
    nonisolated private func extractLandmarksSync(from face: VNFaceObservation) -> [CGPoint] {
        guard let landmarks = face.landmarks else { return [] }

        var points: [CGPoint] = []
        let boundingBox = face.boundingBox

        // 각 랜드마크 그룹 추출 (68개 포인트 순서)
        if let faceContour = landmarks.faceContour {
            points.append(contentsOf: convertPointsSync(faceContour.normalizedPoints, boundingBox: boundingBox))
        }
        if let leftEyebrow = landmarks.leftEyebrow {
            points.append(contentsOf: convertPointsSync(leftEyebrow.normalizedPoints, boundingBox: boundingBox))
        }
        if let rightEyebrow = landmarks.rightEyebrow {
            points.append(contentsOf: convertPointsSync(rightEyebrow.normalizedPoints, boundingBox: boundingBox))
        }
        if let noseCrest = landmarks.noseCrest {
            points.append(contentsOf: convertPointsSync(noseCrest.normalizedPoints, boundingBox: boundingBox))
        }
        if let nose = landmarks.nose {
            points.append(contentsOf: convertPointsSync(nose.normalizedPoints, boundingBox: boundingBox))
        }
        if let leftEye = landmarks.leftEye {
            points.append(contentsOf: convertPointsSync(leftEye.normalizedPoints, boundingBox: boundingBox))
        }
        if let rightEye = landmarks.rightEye {
            points.append(contentsOf: convertPointsSync(rightEye.normalizedPoints, boundingBox: boundingBox))
        }
        if let outerLips = landmarks.outerLips {
            points.append(contentsOf: convertPointsSync(outerLips.normalizedPoints, boundingBox: boundingBox))
        }
        if let innerLips = landmarks.innerLips {
            points.append(contentsOf: convertPointsSync(innerLips.normalizedPoints, boundingBox: boundingBox))
        }

        return points
    }

    /// nonisolated 좌표 변환
    /// Vision 좌표계 (0,0 = 좌하단) → 화면 좌표계 (0,0 = 좌상단)
    nonisolated private func convertPointsSync(_ points: [CGPoint], boundingBox: CGRect) -> [CGPoint] {
        points.map { point in
            // 랜드마크는 boundingBox 내의 상대 좌표 (0-1)
            // 절대 좌표로 변환
            let absoluteX = boundingBox.origin.x + point.x * boundingBox.width
            let absoluteY = boundingBox.origin.y + point.y * boundingBox.height

            // Vision 좌표계 → 화면 좌표계
            // Y만 플립 (Vision: 0,0=좌하단 → 화면: 0,0=좌상단)
            // X는 플립 안함 - SwiftUIVideoView .mirror가 뷰 자체를 미러링하므로
            // FaceMeshOverlayView도 같이 미러링되어야 함 (별도 처리)
            return CGPoint(x: absoluteX, y: 1.0 - absoluteY)
        }
    }

    // MARK: - FPS Counter

    private func startFPSCounter() {
        frameCount = 0
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentFPS = Double(self.frameCount)
                self.frameCount = 0
            }
        }
    }

    private func stopFPSCounter() {
        fpsTimer?.invalidate()
        fpsTimer = nil
        currentFPS = 0
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        // Face 로그 비활성화
        // #if DEBUG
        // print("[FaceLandmarkDetector] \(message)")
        // #endif
    }
}

// MARK: - Video Renderer

/// LiveKit VideoRenderer 구현
/// NSObject 상속 필수 - VideoRenderer의 @objc optional 메서드를 Objective-C 런타임이 인식해야 함
final class FaceLandmarkVideoRenderer: NSObject, VideoRenderer {

    private let onFrame: @Sendable (CVPixelBuffer) -> Void

    init(onFrame: @escaping @Sendable (CVPixelBuffer) -> Void) {
        self.onFrame = onFrame
        super.init()
    }

    // VideoRenderer 프로토콜 구현 (MainActor)
    @MainActor var isAdaptiveStreamEnabled: Bool { true }
    @MainActor var adaptiveStreamSize: CGSize { CGSize(width: 640, height: 480) }

    // @objc 필수 - VideoRenderer 프로토콜의 render(frame:)이 @objc optional이므로
    @objc nonisolated func render(frame: VideoFrame) {
        // Face 로그 비활성화
        // #if DEBUG
        // print("[FaceLandmarkVideoRenderer] 🎬 render() called - dimensions: \(frame.dimensions)")
        // #endif

        // VideoFrame에서 CVPixelBuffer 추출 (toCVPixelBuffer() 메서드 사용)
        guard let pixelBuffer = frame.toCVPixelBuffer() else {
            // Face 로그 비활성화
            // #if DEBUG
            // print("[FaceLandmarkVideoRenderer] ❌ Failed to get CVPixelBuffer from VideoFrame")
            // #endif
            return
        }

        // Face 로그 비활성화
        // #if DEBUG
        // print("[FaceLandmarkVideoRenderer] ✅ Got CVPixelBuffer, calling onFrame")
        // #endif
        onFrame(pixelBuffer)
    }
}

#else

// LiveKit이 없을 때 스텁
@MainActor
final class FaceLandmarkDetector: ObservableObject {
    static let shared = FaceLandmarkDetector()
    @Published private(set) var currentLandmarks: [CGPoint] = []
    @Published private(set) var isFaceDetected: Bool = false
    @Published var isDetectionEnabled: Bool = false
    private init() {}
}

#endif

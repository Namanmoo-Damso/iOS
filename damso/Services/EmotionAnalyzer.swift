//
//  EmotionAnalyzer.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//
//  CoreML 기반 감정 분석 서비스
//  얼굴 이미지에서 감정을 분석하고 주기적으로 결과 전송
//

import Foundation
@preconcurrency import CoreImage
import CoreML
@preconcurrency import Vision
import Combine
@preconcurrency import CoreVideo

#if canImport(LiveKit)
import LiveKit

/// 감정 분석 서비스
/// FaceLandmarkDetector와 연동하여 주기적으로 감정 분석 수행
@MainActor
final class EmotionAnalyzer: ObservableObject {

    // MARK: - Singleton

    static let shared = EmotionAnalyzer()

    // MARK: - Published Properties

    /// 현재 감지된 감정
    @Published private(set) var currentEmotion: EmotionAlertData.DetectedEmotion = .neutral

    /// 감정 신뢰도 (0.0 ~ 1.0)
    @Published private(set) var confidence: Float = 0

    /// 감정 강도 (0.0 ~ 1.0)
    @Published private(set) var intensity: Float = 0

    /// 분석 활성화 상태
    @Published private(set) var isActive: Bool = false

    /// 모델 로드 상태
    @Published private(set) var isModelLoaded: Bool = false

    // MARK: - Configuration

    /// 분석 주기 (초)
    var analysisInterval: Float = 3.0

    /// 최소 신뢰도 (이 이상이어야 알림 전송)
    var minimumConfidence: Float = 0.6

    /// 부정적 감정만 알림 전송 여부
    var onlyNegativeEmotions: Bool = true

    // MARK: - Private Properties

    private let faceLandmarkDetector = FaceLandmarkDetector.shared
    private let careAlertService = CareAlertService.shared

    private var cancellables = Set<AnyCancellable>()
    private var analysisTimer: Timer?
    private var lastAnalysisTime: Date = .distantPast
    private var previousEmotion: EmotionAlertData.DetectedEmotion?

    // CoreML 모델
    private var emotionModel: VNCoreMLModel?

    // 현재 분석 중 여부 (중복 분석 방지)
    private var isAnalyzing: Bool = false

    // 마지막으로 캡처한 픽셀 버퍼
    private var lastCapturedBuffer: CVPixelBuffer?

    // MARK: - Init

    private init() {
        loadModel()
    }

    // MARK: - Model Loading

    /// CoreML 모델 로드
    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            // Neural Engine + GPU + CPU 모두 활용 (자동 최적화)
            config.computeUnits = .all

            // EmotionClassifier.mlpackage 로드
            guard let modelURL = Bundle.main.url(
                forResource: "EmotionClassifier",
                withExtension: "mlmodelc"
            ) ?? Bundle.main.url(
                forResource: "EmotionClassifier",
                withExtension: "mlpackage"
            ) else {
                debugLog("⚠️ EmotionClassifier model not found in bundle - running in stub mode")
                isModelLoaded = false
                return
            }

            let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            emotionModel = try VNCoreMLModel(for: mlModel)
            isModelLoaded = true
            debugLog("✅ EmotionClassifier model loaded (Neural Engine optimized)")
        } catch {
            debugLog("❌ Failed to load EmotionClassifier: \(error)")
            isModelLoaded = false
        }
    }

    // MARK: - Public Methods

    /// 감정 분석 시작
    func start() {
        guard !isActive else {
            debugLog("Already active, skipping start")
            return
        }

        isActive = true
        previousEmotion = nil
        lastAnalysisTime = .distantPast

        setupSubscriptions()
        startAnalysisTimer()

        debugLog("✅ Emotion analyzer started (interval: \(analysisInterval)s)")
    }

    /// 감정 분석 중지
    func stop() {
        guard isActive else { return }

        isActive = false
        stopAnalysisTimer()
        cancellables.removeAll()
        currentEmotion = .neutral
        confidence = 0
        intensity = 0
        previousEmotion = nil
        lastCapturedBuffer = nil

        debugLog("Emotion analyzer stopped")
    }

    /// 수동으로 분석 실행 (테스트용)
    func analyzeNow() {
        guard isActive else { return }
        performAnalysis()
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // 얼굴 감지 상태 모니터링
        faceLandmarkDetector.$isFaceDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDetected in
                if !isDetected {
                    // 얼굴이 사라지면 neutral로 리셋
                    self?.currentEmotion = .neutral
                    self?.confidence = 0
                    self?.intensity = 0
                }
            }
            .store(in: &cancellables)
    }

    private func startAnalysisTimer() {
        stopAnalysisTimer()

        analysisTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(analysisInterval),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performAnalysis()
            }
        }
    }

    private func stopAnalysisTimer() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }

    /// 감정 분석 수행
    private func performAnalysis() {
        guard isActive else { return }
        guard !isAnalyzing else { return }
        guard faceLandmarkDetector.isFaceDetected else {
            debugLog("No face detected, skipping analysis")
            return
        }

        isAnalyzing = true
        lastAnalysisTime = Date()

        if isModelLoaded, emotionModel != nil {
            // CoreML 모델로 실제 분석
            performCoreMLAnalysis()
        } else {
            // 스텁 모드: Vision 프레임워크의 기본 얼굴 분석 사용
            performStubAnalysis()
        }
    }

    /// CoreML 모델을 사용한 감정 분석
    private func performCoreMLAnalysis() {
        guard let buffer = lastCapturedBuffer else {
            debugLog("No pixel buffer available for analysis")
            isAnalyzing = false
            return
        }

        guard let model = emotionModel else {
            performStubAnalysis()
            return
        }

        // CVPixelBuffer는 Sendable이 아니지만, 읽기 전용 사용이므로 스레드 안전
        // nonisolated(unsafe)로 @Sendable 클로저 캡처 허용
        nonisolated(unsafe) let pixelBuffer = buffer

        // Vision 분석을 백그라운드에서 실행
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 백그라운드에서 request 생성
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let self = self else { return }

                Task { @MainActor in
                    self.isAnalyzing = false

                    if let error = error {
                        self.debugLog("CoreML request failed: \(error)")
                        return
                    }

                    // VNCoreMLFeatureValueObservation에서 결과 추출
                    // EmotionClassifier 출력: emotionProbabilities [1, 7] 텐서
                    if let observations = request.results as? [VNCoreMLFeatureValueObservation],
                       let firstObservation = observations.first,
                       let multiArray = firstObservation.featureValue.multiArrayValue {
                        self.processEmotionProbabilities(multiArray)
                    }
                    // VNClassificationObservation 형식으로 결과가 올 수도 있음
                    else if let classifications = request.results as? [VNClassificationObservation],
                            let topResult = classifications.first {
                        let emotion = self.mapClassificationToEmotion(topResult.identifier)
                        let confidence = Float(topResult.confidence)
                        self.updateEmotion(emotion, confidence: confidence)
                    } else {
                        self.debugLog("Unexpected result format from CoreML model")
                    }
                }
            }

            // 이미지 리사이즈는 Vision에서 자동 처리
            request.imageCropAndScaleOption = .scaleFill

            // 핸들러 생성 및 실행
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

            do {
                try handler.perform([request])
            } catch {
                Task { @MainActor in
                    self.debugLog("VNImageRequestHandler failed: \(error)")
                    self.isAnalyzing = false
                }
            }
        }
    }

    /// 감정 확률 배열 처리 (EmotionClassifier 출력)
    /// 클래스 순서: anger, disgust, fear, happiness, neutral, sadness, surprise
    private func processEmotionProbabilities(_ multiArray: MLMultiArray) {
        // 클래스 순서 (EmotionClassifier 학습 시 순서)
        let classLabels: [EmotionAlertData.DetectedEmotion] = [
            .angry, .disgusted, .fearful, .happy, .neutral, .sad, .surprised
        ]

        // Softmax 적용하여 확률로 변환
        var maxValue: Float = -Float.infinity
        var probabilities: [Float] = []

        for i in 0..<classLabels.count {
            let value = Float(truncating: multiArray[i])
            maxValue = max(maxValue, value)
            probabilities.append(value)
        }

        // Softmax: exp(x - max) / sum(exp(x - max))
        var expSum: Float = 0
        for i in 0..<probabilities.count {
            probabilities[i] = exp(probabilities[i] - maxValue)
            expSum += probabilities[i]
        }

        for i in 0..<probabilities.count {
            probabilities[i] /= expSum
        }

        // 최대 확률 클래스 찾기
        var bestIndex = 0
        var bestConfidence: Float = 0
        for i in 0..<probabilities.count {
            if probabilities[i] > bestConfidence {
                bestConfidence = probabilities[i]
                bestIndex = i
            }
        }

        let detectedEmotion = classLabels[bestIndex]
        debugLog("📊 Emotion: \(detectedEmotion.rawValue) (\(Int(bestConfidence * 100))%)")

        updateEmotion(detectedEmotion, confidence: bestConfidence, intensity: bestConfidence)
    }

    /// 스텁 분석 (모델 없이 테스트용)
    private func performStubAnalysis() {
        // 스텁 모드에서는 neutral을 반환
        // 실제 앱에서는 모델이 로드되면 이 함수는 호출되지 않음

        let stubEmotion: EmotionAlertData.DetectedEmotion = .neutral
        let stubConfidence: Float = 0.8

        updateEmotion(stubEmotion, confidence: stubConfidence, intensity: 0.5)

        debugLog("📊 Stub analysis: \(stubEmotion.rawValue) (conf: \(stubConfidence))")
        isAnalyzing = false
    }

    /// 감정 업데이트 및 알림 전송
    private func updateEmotion(_ emotion: EmotionAlertData.DetectedEmotion, confidence: Float, intensity: Float? = nil) {
        let previousEmotion = self.currentEmotion

        self.previousEmotion = previousEmotion
        self.currentEmotion = emotion
        self.confidence = confidence
        self.intensity = intensity ?? confidence

        // 조건 확인: 신뢰도 충족 + (부정적 감정만 또는 모든 감정)
        let shouldSendAlert = confidence >= minimumConfidence &&
            (!onlyNegativeEmotions || isNegativeEmotion(emotion))

        if shouldSendAlert && emotion != .neutral {
            sendEmotionAlert(
                emotion: emotion,
                confidence: confidence,
                intensity: intensity,
                previousEmotion: previousEmotion
            )
        }
    }

    /// 부정적 감정 여부 확인
    private func isNegativeEmotion(_ emotion: EmotionAlertData.DetectedEmotion) -> Bool {
        switch emotion {
        case .sad, .angry, .fearful, .disgusted:
            return true
        case .neutral, .happy, .surprised:
            return false
        }
    }

    /// 감정 알림 전송
    private func sendEmotionAlert(
        emotion: EmotionAlertData.DetectedEmotion,
        confidence: Float,
        intensity: Float?,
        previousEmotion: EmotionAlertData.DetectedEmotion
    ) {
        debugLog("📤 Sending emotion alert: \(emotion.rawValue)")

        Task {
            do {
                try await careAlertService.sendEmotionAlert(
                    emotion: emotion,
                    confidence: confidence,
                    intensity: intensity,
                    previousEmotion: previousEmotion,
                    analysisInterval: analysisInterval
                )
            } catch {
                debugLog("Failed to send emotion alert: \(error)")
            }
        }
    }

    /// 분류 결과를 감정 enum으로 변환
    private func mapClassificationToEmotion(_ identifier: String) -> EmotionAlertData.DetectedEmotion {
        // AffectNet 또는 다른 모델의 클래스 이름에 맞게 매핑
        switch identifier.lowercased() {
        case "neutral":
            return .neutral
        case "happy", "happiness":
            return .happy
        case "sad", "sadness":
            return .sad
        case "angry", "anger":
            return .angry
        case "fear", "fearful":
            return .fearful
        case "disgust", "disgusted":
            return .disgusted
        case "surprise", "surprised":
            return .surprised
        default:
            return .neutral
        }
    }

    // MARK: - Pixel Buffer Capture

    /// FaceLandmarkDetector의 VideoRenderer에서 픽셀 버퍼 캡처
    /// 현재는 FaceLandmarkDetector가 내부적으로 처리하므로 별도 구현 필요
    func capturePixelBuffer(_ buffer: CVPixelBuffer) {
        lastCapturedBuffer = buffer
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[EmotionAnalyzer] \(message)")
        #endif
    }
}

#else

// LiveKit 미사용 시 스텁
@MainActor
final class EmotionAnalyzer: ObservableObject {
    static let shared = EmotionAnalyzer()
    @Published private(set) var currentEmotion: String = "neutral"
    @Published private(set) var isActive: Bool = false
    private init() {}
    func start() {}
    func stop() {}
}

#endif

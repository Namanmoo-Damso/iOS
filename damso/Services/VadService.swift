//
//  VadService.swift
//  damso
//
//  Created by Claude Code on 2025-01-12.
//

import Foundation
import Combine
import CoreML
import AVFoundation
import Accelerate

#if canImport(FluidAudio)
import FluidAudio
#endif

/// Voice Activity Detection 서비스
/// FluidAudio의 Silero VAD를 사용하여 실시간 음성 감지
@MainActor
final class VadService: ObservableObject {

    // MARK: - Singleton

    static let shared = VadService()

    // MARK: - Published Properties

    /// 현재 음성 감지 상태
    @Published private(set) var isSpeaking: Bool = false

    /// VAD 확률 (0.0 ~ 1.0)
    @Published private(set) var probability: Float = 0

    /// 서비스 활성화 상태
    @Published private(set) var isActive: Bool = false

    /// 모델 로드 상태
    @Published private(set) var isModelLoaded: Bool = false

    // MARK: - Streams

    /// 음성 시작/종료 이벤트 스트림
    let speechEventStream = PassthroughSubject<SpeechEvent, Never>()

    // MARK: - Configuration

    /// VAD 임계값 (기본: 0.5)
    var threshold: Float = 0.5

    // MARK: - Private Properties

    #if canImport(FluidAudio)
    private var vadManager: VadManager?
    private var streamState: VadStreamState?
    #endif

    /// 리샘플러 (48kHz → 16kHz)
    private var resampleBuffer: [Float] = []
    private let targetSampleRate: Double = 16000

    /// 음성 상태 추적
    private var lastSpeechStartTime: Date?
    private var speechDuration: TimeInterval = 0

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// VAD 모델 로드 (앱 시작 시 호출)
    func loadModel() async {
        guard !isModelLoaded else {
            debugLog("Model already loaded")
            return
        }

        #if canImport(FluidAudio)
        do {
            // 번들에서 모델 로드
            guard let modelURL = Bundle.main.url(
                forResource: "silero-vad-unified-256ms-v6.0.0",
                withExtension: "mlmodelc"
            ) else {
                debugLog("VAD model not found in bundle")
                return
            }

            let config = MLModelConfiguration()
            config.computeUnits = .all  // Neural Engine 활용

            let mlModel = try MLModel(contentsOf: modelURL, configuration: config)

            // VadManager 초기화 (번들 모델 사용)
            let vadConfig = VadConfig(defaultThreshold: threshold)
            vadManager = VadManager(config: vadConfig, vadModel: mlModel)
            streamState = await vadManager?.makeStreamState()

            isModelLoaded = true
            debugLog("✅ VAD model loaded successfully")

        } catch {
            debugLog("Failed to load VAD model: \(error)")
        }
        #else
        debugLog("FluidAudio not available")
        #endif
    }

    /// VAD 시작
    func start() {
        guard isModelLoaded else {
            debugLog("Model not loaded, cannot start")
            return
        }

        isActive = true
        resetState()
        debugLog("✅ VAD started")
    }

    /// VAD 중지
    func stop() {
        isActive = false
        resetState()
        debugLog("VAD stopped")
    }

    /// 오디오 샘플 처리 (48kHz Float32)
    /// - Parameter samples: 48kHz 오디오 샘플
    func processAudioSamples(_ samples: [Float], sampleRate: Double = 48000) async {
        guard isActive, isModelLoaded else { return }

        #if canImport(FluidAudio)
        guard let vadManager, var state = streamState else { return }

        // 16kHz로 리샘플링
        let samples16k = resampleTo16kHz(samples, fromRate: sampleRate)

        // 최소 청크 크기 확인 (256ms at 16kHz = 4096 samples)
        resampleBuffer.append(contentsOf: samples16k)

        // 4096 샘플 이상이면 처리
        while resampleBuffer.count >= 4096 {
            let chunk = Array(resampleBuffer.prefix(4096))
            resampleBuffer.removeFirst(4096)

            do {
                let result = try await vadManager.processStreamingChunk(
                    chunk,
                    state: state,
                    config: .default,
                    returnSeconds: true,
                    timeResolution: 2
                )

                state = result.state
                streamState = state

                // 확률 업데이트
                probability = result.probability

                // 음성 상태 업데이트
                let wasSpeaking = isSpeaking
                isSpeaking = result.probability > threshold

                // 이벤트 처리
                if let event = result.event {
                    handleSpeechEvent(event)
                }

                // 상태 변화 감지 (이벤트가 없어도)
                if !wasSpeaking && isSpeaking {
                    lastSpeechStartTime = Date()
                    speechEventStream.send(.started)
                    debugLog("🎙️ Speech started (prob: \(String(format: "%.2f", result.probability)))")
                } else if wasSpeaking && !isSpeaking {
                    if let startTime = lastSpeechStartTime {
                        speechDuration = Date().timeIntervalSince(startTime)
                    }
                    speechEventStream.send(.ended(duration: speechDuration))
                    debugLog("🔇 Speech ended (duration: \(String(format: "%.1f", speechDuration))s)")
                    lastSpeechStartTime = nil
                }

            } catch {
                debugLog("VAD processing error: \(error)")
            }
        }
        #endif
    }

    /// AVAudioPCMBuffer 처리 (LiveKit AudioRenderer용)
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard let floatData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Float 배열로 변환
        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: frameLength))
        let sampleRate = buffer.format.sampleRate

        await processAudioSamples(samples, sampleRate: sampleRate)
    }

    /// 스트림 상태 리셋
    func resetStreamState() async {
        #if canImport(FluidAudio)
        streamState = await vadManager?.makeStreamState()
        #endif
        resetState()
        debugLog("Stream state reset")
    }

    // MARK: - Private Methods

    private func resetState() {
        isSpeaking = false
        probability = 0
        resampleBuffer.removeAll()
        lastSpeechStartTime = nil
        speechDuration = 0
    }

    #if canImport(FluidAudio)
    private func handleSpeechEvent(_ event: VadStreamEvent) {
        switch event.kind {
        case .speechStart:
            debugLog("📢 VAD Event: Speech Start at \(event.time ?? 0)s")
        case .speechEnd:
            debugLog("📢 VAD Event: Speech End at \(event.time ?? 0)s")
        }
    }
    #endif

    /// 48kHz → 16kHz 다운샘플링 (간단한 선형 보간)
    private func resampleTo16kHz(_ samples: [Float], fromRate: Double) -> [Float] {
        guard fromRate != targetSampleRate else { return samples }

        let ratio = fromRate / targetSampleRate
        let outputLength = Int(Double(samples.count) / ratio)

        guard outputLength > 0 else { return [] }

        var output = [Float](repeating: 0, count: outputLength)

        for i in 0..<outputLength {
            let srcIndex = Double(i) * ratio
            let srcIndexInt = Int(srcIndex)
            let frac = Float(srcIndex - Double(srcIndexInt))

            if srcIndexInt + 1 < samples.count {
                output[i] = samples[srcIndexInt] * (1 - frac) + samples[srcIndexInt + 1] * frac
            } else if srcIndexInt < samples.count {
                output[i] = samples[srcIndexInt]
            }
        }

        return output
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[VadService] \(message)")
        #endif
    }
}

// MARK: - Speech Event

enum SpeechEvent {
    case started
    case ended(duration: TimeInterval)
}

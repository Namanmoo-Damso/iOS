import Foundation
import AVFoundation
import Accelerate
#if canImport(LiveKit)
import LiveKit

/// 오디오 시각화 관리자
/// RemoteAudioTrack에 연결하여 실시간 오디오 레벨 분석 결과를 제공
@MainActor
final class AudioVisualizerManager: NSObject, ObservableObject {
    static let shared = AudioVisualizerManager()

    // MARK: - Published Properties

    /// 정규화된 주파수 밴드 값 (0.0 ~ 1.0)
    @Published private(set) var bands: [Float] = []

    /// 단일 오디오 레벨 (0.0 ~ 1.0) - 글로우 원형 시각화용
    @Published private(set) var audioLevel: Float = 0

    /// 현재 활성화 상태
    @Published private(set) var isActive: Bool = false

    /// AI가 현재 말하고 있는지 여부
    @Published private(set) var isAISpeaking: Bool = false

    // MARK: - Private Properties

    private let bandsCount: Int = 32
    private var smoothedBands: [Float] = []
    private let smoothingFactor: Float = 0.3  // 부드러운 전환을 위한 계수

    // nonisolated 접근을 위한 상태
    private nonisolated(unsafe) var _isActiveUnsafe: Bool = false

    // MARK: - Initialization

    private override init() {
        self.smoothedBands = [Float](repeating: 0, count: bandsCount)
        super.init()
    }

    // MARK: - Public Methods

    /// 시각화 시작
    func start() {
        isActive = true
        _isActiveUnsafe = true
        bands = [Float](repeating: 0, count: bandsCount)
        smoothedBands = [Float](repeating: 0, count: bandsCount)
        audioLevel = 0
        #if DEBUG
        print("🎵 [AudioVisualizer] Started")
        #endif
    }

    /// 시각화 중지
    func stop() {
        isActive = false
        _isActiveUnsafe = false
        isSpeakingFallback = false
        speakingTimer?.invalidate()
        speakingTimer = nil
        bands = [Float](repeating: 0, count: bandsCount)
        smoothedBands = [Float](repeating: 0, count: bandsCount)
        audioLevel = 0
        #if DEBUG
        print("🎵 [AudioVisualizer] Stopped")
        #endif
    }

    // MARK: - VAD Fallback (원격 참가자 speaking 상태 기반)

    private var isSpeakingFallback: Bool = false
    private var speakingTimer: Timer?

    /// VAD로 AI가 말하고 있음 감지 시 시뮬레이션 시작
    func simulateSpeaking() {
        guard isActive else {
            #if DEBUG
            print("🎙️ [AudioVisualizer] simulateSpeaking called but not active")
            #endif
            return
        }
        #if DEBUG
        print("🎙️ [AudioVisualizer] AI Speaking → isAISpeaking = true")
        #endif
        isSpeakingFallback = true
        isAISpeaking = true

        // 기존 타이머 취소
        speakingTimer?.invalidate()

        // 부드러운 시뮬레이션을 위한 타이머
        speakingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isSpeakingFallback else { return }
                // 자연스러운 파동 효과
                let targetLevel = Float.random(in: 0.3...0.7)
                self.audioLevel = self.audioLevel * 0.6 + targetLevel * 0.4
            }
        }
    }

    /// VAD로 AI 말 멈춤 감지 시 시뮬레이션 중지 (듣기 모드로 전환)
    func simulateSilent() {
        #if DEBUG
        print("🎙️ [AudioVisualizer] AI Silent → isAISpeaking = false")
        #endif
        isSpeakingFallback = false
        isAISpeaking = false
        speakingTimer?.invalidate()
        speakingTimer = nil

        // 서서히 감소
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // 점진적 감소 애니메이션
            for _ in 1...10 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                self.audioLevel = self.audioLevel * 0.8
            }
            self.audioLevel = 0
        }
    }

    /// 밴드 값 업데이트 (MainActor에서 호출)
    private func updateBands(_ newBands: [Float]) {
        for i in 0..<min(newBands.count, smoothedBands.count) {
            smoothedBands[i] = smoothedBands[i] * (1 - smoothingFactor) + newBands[i] * smoothingFactor
        }
        self.bands = smoothedBands

        // 단일 오디오 레벨 계산 (밴드 평균)
        if !smoothedBands.isEmpty {
            let sum = smoothedBands.reduce(0, +)
            self.audioLevel = sum / Float(smoothedBands.count)
        }
    }
}

// MARK: - AudioRenderer Protocol

extension AudioVisualizerManager: AudioRenderer {
    nonisolated func render(pcmBuffer: AVAudioPCMBuffer) {
        // 활성화 상태가 아니면 조기 반환
        guard _isActiveUnsafe else { return }

        guard let floatData = pcmBuffer.floatChannelData else { return }
        let frameLength = Int(pcmBuffer.frameLength)
        guard frameLength > 0 else { return }

        // RMS (Root Mean Square) 계산
        var rms: Float = 0
        vDSP_rmsqv(floatData[0], 1, &rms, vDSP_Length(frameLength))

        // RMS를 0-1 범위로 정규화 (더 민감하게 조정)
        // 일반적인 음성은 0.01-0.3 범위이므로 증폭
        let normalizedLevel = min(1.0, rms * 5.0)

        #if DEBUG
        if rms > 0.005 {
            print("🎵 [AudioVisualizer] RMS: \(rms), normalized: \(normalizedLevel)")
        }
        #endif

        // 밴드 시뮬레이션
        let bandCount = 32
        var simulatedBands = [Float](repeating: 0, count: bandCount)

        for i in 0..<bandCount {
            let variation = Float.random(in: 0.7...1.3)
            let bandMultiplier: Float
            if i < bandCount / 4 {
                bandMultiplier = 0.6 + Float(i) / Float(bandCount) * 0.4
            } else if i < bandCount * 3 / 4 {
                bandMultiplier = 1.0
            } else {
                bandMultiplier = 1.0 - Float(i - bandCount * 3 / 4) / Float(bandCount / 4) * 0.3
            }
            simulatedBands[i] = min(1.0, normalizedLevel * variation * bandMultiplier)
        }

        // 메인 스레드에서 UI 업데이트
        let bandsToUpdate = simulatedBands
        let levelToUpdate = normalizedLevel
        Task { @MainActor [weak self] in
            self?.updateBands(bandsToUpdate)
            // 직접 audioLevel도 업데이트 (더 반응적으로)
            if let self = self {
                self.audioLevel = self.audioLevel * 0.7 + levelToUpdate * 0.3
            }
        }
    }
}

#endif
